import { createContext, useContext, useEffect, useMemo, useRef, useState } from 'react'
import { supabase, supabaseConfigured } from '../lib/supabase'

const AuthContext = createContext(null)
const AUTH_REDIRECT_URL = import.meta.env.VITE_AUTH_REDIRECT_URL?.trim() || 'https://h-clubs.vercel.app'
function friendlyAuthError(error, context = 'login') {
  const code = error?.code || error?.error_code || ''
  const message = `${code} ${error?.message || ''}`.toLowerCase()
  if (message.includes('over_email_send_rate_limit') || message.includes('email rate limit exceeded')) {
    return 'Supabase a atteint sa limite d’envoi d’e-mails (2 par heure avec le service intégré). L’administrateur doit configurer un SMTP personnalisé dans Supabase pour envoyer les confirmations aux étudiants.'
  }
  if (message.includes('email_address_not_authorized')) {
    return 'Le service e-mail Supabase de test n’envoie qu’aux adresses autorisées de l’équipe du projet. Configurez un SMTP personnalisé pour envoyer les confirmations aux étudiants.'
  }
  if (message.includes('database error saving new user')) {
    if (context === 'register') return 'Supabase n’a pas terminé la création du compte. Vérifiez que la migration « Inscription simple HClubs » est appliquée et que la table profiles existe.'
    return 'Supabase n’a pas chargé le profil HClubs. Vérifiez la configuration de la base puis réessayez.'
  }
  if (message.includes('invalid login credentials')) return 'Adresse ou mot de passe incorrect. Si vous venez de créer votre compte, confirmez d’abord votre e-mail et vérifiez que l’inscription a bien été terminée.'
  if (context === 'register' && message.includes('already registered')) return 'Cette adresse possède déjà un compte. Connectez-vous ou demandez un nouveau mail de confirmation.'
  return error?.message || 'Une erreur est survenue.'
}
function toProfile(row) {
  const defaultBureauRole = { student: 'Étudiant', bureau: 'Bureau du club', member: 'Membre actif', admin: 'Administration' }[row.role] || row.role
  return { id: row.id, name: row.name, email: row.email, role: row.role, bureauRole: row.bureau_role || defaultBureauRole, clubId: row.club_id }
}
async function fetchProfile(userId) {
  const { data, error } = await supabase.from('profiles').select('id,name,email,role,bureau_role,club_id').eq('id', userId).single()
  if (error?.code === 'PGRST116') throw new Error('Profil HESTIM introuvable. Exécutez la migration Supabase des profils existants, puis reconnectez-vous.')
  if (error) throw error
  return toProfile(data)
}

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [authError, setAuthError] = useState('')
  const loginInProgress = useRef(false)

  useEffect(() => {
    if (typeof window !== 'undefined' && window.location.hash) {
      const params = new URLSearchParams(window.location.hash.slice(1))
      const code = params.get('error_code')
      if (code === 'otp_expired') setAuthError('Ce lien de confirmation a expiré ou a déjà été utilisé. Renvoyez un nouveau lien avec votre adresse HESTIM.')
      else if (params.get('error')) setAuthError(params.get('error_description') || 'La confirmation du compte a échoué. Demandez un nouveau lien.')
      if (params.has('error')) window.history.replaceState({}, document.title, `${window.location.pathname}${window.location.search}`)
    }
    if (supabaseConfigured) {
      let active = true
      supabase.auth.getSession().then(async ({ data, error }) => {
        if (error) { if (active) setAuthError(error.message); return }
        if (data.session?.user) {
          try { const profile = await fetchProfile(data.session.user.id); if (active && !loginInProgress.current) setUser(profile) }
          catch (cause) { if (active) setAuthError(cause.message) }
        } else if (active) setUser(null)
      })
      const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
        if (loginInProgress.current) return
        if (!session?.user) { if (active) setUser(null); return }
        queueMicrotask(async () => {
          try { const profile = await fetchProfile(session.user.id); if (active && !loginInProgress.current) { setUser(profile); setAuthError('') } }
          catch (cause) { if (active) setAuthError(cause.message) }
        })
      })
      return () => { active = false; listener.subscription.unsubscribe() }
    }
  }, [])
  const register = async ({ name, email, password, signupType = 'student' }) => {
    const normalizedEmail = email.trim().toLowerCase()
    if (!normalizedEmail.endsWith('@hestim.ma')) throw new Error('Utilisez votre adresse institutionnelle en @hestim.ma.')
    if (!['student', 'admin'].includes(signupType)) throw new Error('Choisissez un type de compte valide.')
    if (!name.trim() || password.length < 8) throw new Error('Renseignez votre nom et un mot de passe de 8 caractères minimum.')
    setAuthError('')
    if (!supabaseConfigured) throw new Error('La connexion Supabase doit être configurée.')

    const { data, error } = await supabase.auth.signUp({
      email: normalizedEmail,
      password,
      options: {
        data: { name: name.trim(), requested_role: signupType },
        emailRedirectTo: AUTH_REDIRECT_URL,
      },
    })
    if (error) {
      // Auth errors inherit from Error; message is non-enumerable and is lost
      // by object spread unless it is copied explicitly.
      throw new Error(friendlyAuthError({
        message: error.message,
        code: error.code,
        error_code: error.error_code,
        status: error.status,
        details: error.details,
        hint: error.hint,
        email: normalizedEmail,
      }, 'register'))
    }
    if (!data.session || !data.user) return { message: signupType === 'admin' ? 'Compte créé. Confirmez votre e-mail. Votre demande administrateur doit être autorisée par l’administration avant de recevoir ces droits.' : 'Compte créé. Confirmez votre adresse e-mail, puis connectez-vous.', pendingConfirmation: true, email: normalizedEmail }
    const profile = await fetchProfile(data.user.id)
    setUser(profile)
    return { user: profile }
  }

  const login = async ({ email, password }) => {
    const normalizedEmail = email.trim().toLowerCase()
    if (!normalizedEmail.endsWith('@hestim.ma')) throw new Error('Utilisez votre adresse institutionnelle en @hestim.ma.')
    if (!supabaseConfigured) throw new Error('La connexion Supabase doit être configurée.')
    setAuthError('')
    loginInProgress.current = true
    try {
      const { data, error } = await supabase.auth.signInWithPassword({ email: normalizedEmail, password })
      if (error) throw new Error(friendlyAuthError(error, 'login'))
      const profile = await fetchProfile(data.user.id)
      setUser(profile)
      return { user: profile }
    } catch (cause) {
      setUser(null)
      await supabase.auth.signOut({ scope: 'local' })
      throw cause
    } finally {
      loginInProgress.current = false
    }
  }

  const resendConfirmation = async email => {
    const normalizedEmail = email.trim().toLowerCase()
    if (!normalizedEmail.endsWith('@hestim.ma')) throw new Error('Utilisez votre adresse institutionnelle en @hestim.ma.')
    if (!supabaseConfigured) throw new Error('Le renvoi du mail est disponible uniquement avec Supabase.')
    const { error } = await supabase.auth.resend({
      type: 'signup',
      email: normalizedEmail,
      options: { emailRedirectTo: AUTH_REDIRECT_URL },
    })
    if (error) throw new Error(friendlyAuthError(error, 'register'))
  }

  const logout = async () => {
    if (supabaseConfigured) {
      const { error } = await supabase.auth.signOut()
      if (error) throw error
    }
    setUser(null)
  }
  const value = useMemo(() => ({ user, register, login, logout, resendConfirmation, authError, clearAuthError: () => setAuthError(''), usingSupabase: supabaseConfigured }), [user, authError])
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export const useAuth = () => { const context = useContext(AuthContext); if (!context) throw new Error('useAuth doit être utilisé dans AuthProvider'); return context }
