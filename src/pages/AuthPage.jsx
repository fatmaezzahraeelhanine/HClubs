import { useState } from 'react'
import { ArrowRight, ArrowUpRight, CalendarDays, Check, ChevronRight, CircleHelp, Cpu, Eye, EyeOff, LockKeyhole, Mail, ShieldCheck, Sparkles, Users, X } from 'lucide-react'
import { useAuth } from '../context/AuthContext'

const features = [
  { icon: Users, title: 'Une communauté, mille idées', detail: 'Découvrez les clubs qui vous ressemblent.' },
  { icon: CalendarDays, title: 'Tout le campus en mouvement', detail: 'Les événements HESTIM, au même endroit.' },
  { icon: ShieldCheck, title: 'Un espace fait pour vous', detail: 'Chaque accès pensé selon votre rôle.' },
]

export default function AuthPage() {
  const { login, register, authError, usingSupabase } = useAuth()
  const [mode, setMode] = useState('login')
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [loading, setLoading] = useState(false)
  const [form, setForm] = useState({ name: '', email: '', password: '', requestedRole: 'student' })
  const isRegister = mode === 'register'
  const changeMode = next => { setMode(next); setError(''); setSuccess('') }
  const change = event => setForm(current => ({ ...current, [event.target.name]: event.target.value }))
  const submit = async event => {
    event.preventDefault(); setError(''); setSuccess(''); setLoading(true)
    try {
      if (isRegister) {
        const result = await register(form)
        if (result?.message) setSuccess(result.message)
      } else await login(form)
    } catch (cause) { setError(cause.message || 'Une erreur est survenue.') }
    finally { setLoading(false) }
  }
  const demoLogin = (role, email, name) => {
    setMode('register'); setError(''); setForm({ name, email, password: 'HESTIM2025!', requestedRole: role })
    setSuccess('Identifiants de démonstration préremplis. Créez le compte pour entrer.')
  }

  return <main className="auth-page">
    <section className="auth-hero">
      <div className="hero-grain" />
      <div className="hero-inner">
        <a className="brand brand-light" href="#accueil" aria-label="HClubs — Vie associative HESTIM"><span className="brand-mark"><span /></span><span className="brand-word">HClubs<span>·</span></span><span className="brand-divider" /><span className="brand-product">Vie associative<br />HESTIM</span></a>
        <div className="hero-copy">
          <span className="eyebrow"><Sparkles size={13} /> LA VIE ASSOCIATIVE, AUTREMENT</span>
          <h1>Le campus<br />est à <span>vous.</span></h1>
          <p>Les clubs, les projets et les rencontres qui font votre expérience HESTIM. Un espace pensé pour vous aider à aller plus loin, ensemble.</p>
          <div className="hero-features">{features.map(({ icon: Icon, title, detail }) => <div className="hero-feature" key={title}><div className="hero-feature-icon"><Icon size={17} /></div><div><strong>{title}</strong><span>{detail}</span></div><ChevronRight size={15} className="feature-chevron" /></div>)}</div>
          <div className="hero-note"><div className="avatar-stack"><i>Y</i><i>A</i><i>S</i><i>+</i></div><span><strong>243 étudiants</strong> font déjà partie d’un club</span></div>
        </div>
        <div className="hero-footer"><span>© 2026 HESTIM · Casablanca</span><a href="mailto:clubs@hestim.ma">Besoin d’aide ? <ArrowUpRight size={12} /></a></div>
      </div>
      <div className="hero-shape shape-one" /><div className="hero-shape shape-two" />
    </section>
    <section className="auth-panel" id="accueil">
      <div className="mobile-brand"><span className="brand-mark"><span /></span><span className="brand-word">HClubs<span>·</span></span></div>
      <div className="auth-card-wrap">
        <div className="auth-top-note"><span className="secure-label"><LockKeyhole size={12} /> ESPACE SÉCURISÉ</span><a className="help-button" href="mailto:clubs@hestim.ma" title="Contacter l’aide" aria-label="Contacter l’aide"><CircleHelp size={18} /></a></div>
        <div className="auth-heading"><p className="auth-kicker">BIENVENUE SUR LE CAMPUS</p><h2>{isRegister ? 'Créer votre compte' : 'Ravi de vous revoir.'}</h2><p>{isRegister ? 'Rejoignez la communauté associative HESTIM.' : 'Connectez-vous pour retrouver votre espace.'}</p></div>
        <div className="auth-tabs"><button onClick={() => changeMode('login')} className={!isRegister ? 'active' : ''}>Se connecter</button><button onClick={() => changeMode('register')} className={isRegister ? 'active' : ''}>Créer un compte</button></div>
        {(error || authError) && <div className="form-alert error-alert"><X size={16} /><span>{error || authError}</span></div>}
        {success && <div className="form-alert success-alert"><Check size={16} /><span>{success}</span></div>}
        <form className="auth-form" onSubmit={submit}>
          {isRegister && <label className="field-label">Nom complet<div className="input-wrap"><Users size={17} /><input name="name" value={form.name} onChange={change} placeholder="Ex. Yasmine El Mansouri" autoComplete="name" required /></div></label>}
          <label className="field-label">Adresse e-mail HESTIM<div className="input-wrap"><Mail size={17} /><input name="email" type="email" value={form.email} onChange={change} placeholder="nom@hestim.ma" autoComplete="email" required /></div></label>
          {isRegister && <label className="field-label">Vous êtes<div className="input-wrap select-wrap"><Users size={17} /><select name="requestedRole" value={form.requestedRole} onChange={change}><option value="student">Étudiant·e</option><option value="bureau">Membre du bureau</option><option value="member">Membre actif de club</option><option value="admin">Administration HESTIM</option></select><ChevronRight size={15} className="select-chevron" /></div></label>}
          <label className="field-label">Mot de passe<div className="input-wrap"><LockKeyhole size={17} /><input name="password" type={showPassword ? 'text' : 'password'} value={form.password} onChange={change} placeholder={isRegister ? '8 caractères minimum' : 'Votre mot de passe'} autoComplete={isRegister ? 'new-password' : 'current-password'} minLength={isRegister ? 8 : undefined} required /><button className="password-toggle" type="button" onClick={() => setShowPassword(value => !value)} aria-label={showPassword ? 'Masquer le mot de passe' : 'Afficher le mot de passe'}>{showPassword ? <EyeOff size={17} /> : <Eye size={17} />}</button></div></label>
          {!isRegister && <div className="forgot-row"><span className="institution-note"><Check size={12} /> Compte institutionnel</span><button type="button" onClick={() => setError('Pour réinitialiser votre mot de passe, contactez clubs@hestim.ma.')}>Mot de passe oublié ?</button></div>}
          <button className="submit-button" disabled={loading} type="submit">{loading ? 'Un instant…' : isRegister ? 'Créer mon compte' : 'Accéder à mon espace'}<ArrowRight size={17} /></button>
        </form>
        <div className="form-bottom"><span>{isRegister ? 'Déjà membre ?' : 'Vous n’avez pas encore de compte ?'}</span><button onClick={() => changeMode(isRegister ? 'login' : 'register')}>{isRegister ? 'Se connecter' : 'Créer un compte'} <ArrowUpRight size={12} /></button></div>
        {isRegister && <div className="access-note"><ShieldCheck size={16} /><span>Les responsables de club et l’administration doivent figurer sur la liste d’accès HESTIM.</span></div>}
        {usingSupabase ? <div className="access-note"><ShieldCheck size={16} /><span>Connexion à Supabase activée. Le rôle et l’accès au club sont définis par la whitelist SQL lors de l’inscription.</span></div> : <div className="demo-access"><div className="demo-heading"><span>Explorer la démo</span><span>ACCÈS DE TEST</span></div><div className="demo-actions"><button type="button" onClick={() => demoLogin('student', 'etudiant@hestim.ma', 'Étudiant Démo')}><Users size={14} /> Étudiant</button><button type="button" onClick={() => demoLogin('bureau', 'president.robotique@hestim.ma', 'Yasmine El Mansouri')}><Cpu size={14} /> Bureau</button><button type="button" onClick={() => demoLogin('admin', 'admin@hestim.ma', 'Administration HESTIM')}><ShieldCheck size={14} /> Admin</button></div><p><LockKeyhole size={11} /> Pour les accès de test, créez un compte depuis l’onglet ci-dessus.</p></div>}
      </div>
      <div className="auth-legal"><span>En continuant, vous acceptez les conditions d’utilisation de HESTIM.</span><a href="mailto:clubs@hestim.ma">Confidentialité</a></div>
    </section>
  </main>
}
