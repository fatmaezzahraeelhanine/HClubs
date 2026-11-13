import { createContext, useContext, useEffect, useMemo, useState } from 'react'
import { ALLOWED_ROLES } from '../data/mockData'
import { supabase, supabaseConfigured } from '../lib/supabase'

const AuthContext = createContext(null)
const SESSION_KEY = 'hestim_session_v1'
const ACCOUNTS_KEY = 'hestim_accounts_v1'
const read = (key, fallback) => { try { return JSON.parse(localStorage.getItem(key)) ?? fallback } catch { return fallback } }
function restoreSession() {
  try {
    const saved = JSON.parse(sessionStorage.getItem(SESSION_KEY))
    if (!saved?.email?.endsWith('@hestim.ma')) return null
    const allowed = ALLOWED_ROLES.find(item => item.email === saved.email)
    if (allowed) return saved.role === allowed.role && saved.clubId === allowed.clubId ? { ...allowed, name: saved.name || allowed.name } : null
    return saved.role === 'student' ? { name: saved.name, email: saved.email, role: 'student', bureauRole: 'Étudiant', clubId: null } : null
  } catch { return null }
}
async function hashPassword(password, salt = crypto.randomUUID()) {
  const encoded = new TextEncoder().encode(`${salt}:${password}`)
  const digest = await crypto.subtle.digest('SHA-256', encoded)
  return { salt, hash: Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('') }
}
function toProfile(row) {
  return { id: row.id, name: row.name, email: row.email, role: row.role, bureauRole: row.bureau_role || (row.role === 'student' ? 'Étudiant' : row.role), clubId: row.club_id }
}
async function fetchProfile(userId) {
  const { data, error } = await supabase.from('profiles').select('id,name,email,role,bureau_role,club_id').eq('id', userId).single()
  if (error) throw error
  return toProfile(data)
}

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => supabaseConfigured ? null : restoreSession())
  const [authError, setAuthError] = useState('')

  useEffect(() => {
    if (supabaseConfigured) {
      let active = true
      supabase.auth.getSession().then(async ({ data, error }) => {
        if (error) { if (active) setAuthError(error.message); return }
        if (data.session?.user) {
          try { const profile = await fetchProfile(data.session.user.id); if (active) setUser(profile) }
          catch (cause) { if (active) setAuthError(cause.message) }
        } else if (active) setUser(null)
      })
      const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
        if (!session?.user) { if (active) setUser(null); return }
        queueMicrotask(async () => {
          try { const profile = await fetchProfile(session.user.id); if (active) { setUser(profile); setAuthError('') } }
          catch (cause) { if (active) setAuthError(cause.message) }
        })
      })
      return () => { active = false; listener.subscription.unsubscribe() }
    }
  }, [])
  useEffect(() => {
    if (supabaseConfigured) return
    if (user) sessionStorage.setItem(SESSION_KEY, JSON.stringify(user)); else sessionStorage.removeItem(SESSION_KEY)
  }, [user])

  const register = async ({ name, email, password, requestedRole }) => {
    const normalizedEmail = email.trim().toLowerCase()
    if (!normalizedEmail.endsWith('@hestim.ma')) throw new Error('Utilisez votre adresse institutionnelle en @hestim.ma.')
    if (!name.trim() || password.length < 8) throw new Error('Renseignez votre nom et un mot de passe de 8 caractères minimum.')
    setAuthError('')

    if (supabaseConfigured) {
      const { data, error } = await supabase.auth.signUp({ email: normalizedEmail, password, options: { data: { name: name.trim() } } })
      if (error) throw error
      if (!data.session || !data.user) return { message: 'Compte créé. Confirmez votre adresse e-mail, puis connectez-vous.' }
      const profile = await fetchProfile(data.user.id)
      if (requestedRole === 'admin' && profile.role !== 'admin') {
        await supabase.auth.signOut()
        throw new Error('Email non autorisé pour l’administration. Le rôle est attribué par la whitelist Supabase.')
      }
      if (requestedRole === 'bureau' && profile.role !== 'bureau') {
        await supabase.auth.signOut()
        throw new Error('Email non répertorié dans la whitelist des responsables. Le rôle est attribué par Supabase.')
      }
      if (requestedRole === 'member' && profile.role !== 'member') {
        await supabase.auth.signOut()
        throw new Error('Email non répertorié dans la whitelist des membres actifs.')
      }
      setUser(profile)
      return { user: profile }
    }

    const accounts = read(ACCOUNTS_KEY, [])
    if (accounts.some(account => account.email === normalizedEmail)) throw new Error('Un compte existe déjà pour cette adresse.')
    let profile
    if (requestedRole !== 'student') {
      const allowed = ALLOWED_ROLES.find(item => item.email === normalizedEmail)
      if (!allowed) throw new Error('Email non répertorié dans la liste des responsables pré-autorisés.')
      if (requestedRole === 'admin' && allowed.role !== 'admin') throw new Error('Cette adresse ne dispose pas des droits administration.')
      if (requestedRole === 'bureau' && !['bureau', 'member'].includes(allowed.role)) throw new Error('Cette adresse ne figure pas dans la liste des responsables de club.')
      if (requestedRole === 'member' && allowed.role !== 'member') throw new Error('Cette adresse ne figure pas dans la liste des membres actifs.')
      profile = { ...allowed, name: name.trim() || allowed.name }
    } else {
      if (ALLOWED_ROLES.some(item => item.email === normalizedEmail)) throw new Error('Cette adresse est pré-autorisée comme responsable. Choisissez le rôle correspondant.')
      profile = { name: name.trim(), email: normalizedEmail, role: 'student', bureauRole: 'Étudiant', clubId: null }
    }
    const credentials = await hashPassword(password)
    localStorage.setItem(ACCOUNTS_KEY, JSON.stringify([...accounts, { ...profile, ...credentials }]))
    setUser(profile)
    return { user: profile }
  }

  const login = async ({ email, password }) => {
    const normalizedEmail = email.trim().toLowerCase()
    if (!normalizedEmail.endsWith('@hestim.ma')) throw new Error('Utilisez votre adresse institutionnelle en @hestim.ma.')
    setAuthError('')
    if (supabaseConfigured) {
      const { data, error } = await supabase.auth.signInWithPassword({ email: normalizedEmail, password })
      if (error) throw error
      const profile = await fetchProfile(data.user.id)
      setUser(profile)
      return { user: profile }
    }
    const account = read(ACCOUNTS_KEY, []).find(item => item.email === normalizedEmail)
    if (!account) throw new Error('Adresse ou mot de passe incorrect. Créez un compte si vous êtes nouveau.')
    const { hash } = await hashPassword(password, account.salt)
    if (hash !== account.hash) throw new Error('Adresse ou mot de passe incorrect. Créez un compte si vous êtes nouveau.')
    const allowed = ALLOWED_ROLES.find(item => item.email === normalizedEmail)
    if (allowed && account.role !== allowed.role) throw new Error('Les droits de ce compte ne correspondent pas à la liste autorisée.')
    if (!allowed && account.role !== 'student') throw new Error('Cette adresse n’est pas autorisée pour ce rôle.')
    const { salt: _salt, hash: _hash, ...profile } = allowed ? { ...allowed, name: account.name } : { ...account, role: 'student', bureauRole: 'Étudiant', clubId: null }
    setUser(profile)
    return { user: profile }
  }

  const logout = async () => {
    if (supabaseConfigured) {
      const { error } = await supabase.auth.signOut()
      if (error) throw error
    }
    setUser(null)
  }
  const value = useMemo(() => ({ user, register, login, logout, authError, clearAuthError: () => setAuthError(''), usingSupabase: supabaseConfigured }), [user, authError])
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export const useAuth = () => { const context = useContext(AuthContext); if (!context) throw new Error('useAuth doit être utilisé dans AuthProvider'); return context }
