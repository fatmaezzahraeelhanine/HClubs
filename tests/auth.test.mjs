import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { test } from 'node:test'
import vm from 'node:vm'

const source = readFileSync(new URL('../src/context/AuthContext.jsx', import.meta.url), 'utf8')
  .replace(/^import [^\n]*\n/gm, '')
  .replaceAll('export ', '')
  .replace('import.meta.env.VITE_AUTH_REDIRECT_URL', 'undefined')
  .replace('return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>', 'return value')

function setup(role, authError = null) {
  let user = null
  let listener
  let signInCalls = 0
  let signOutCalls = 0
  const effects = []
  const profile = { id: 'user-1', email: 'person@hestim.ma', role, name: 'Test' }
  const supabase = {
    from: () => ({ select: () => ({ eq: () => ({ single: async () => ({ data: profile }) }) }) }),
    auth: {
      getSession: async () => ({ data: { session: null } }),
      onAuthStateChange: callback => { listener = callback; return { data: { subscription: { unsubscribe() {} } } } },
      signInWithPassword: async () => {
        signInCalls++
        // Supabase emits SIGNED_IN before signInWithPassword completes.
        listener('SIGNED_IN', { user: { id: profile.id } })
        await Promise.resolve()
        return { data: { user: profile }, error: authError }
      },
      signOut: async () => { signOutCalls++; listener('SIGNED_OUT', null); return {} },
    },
  }
  let stateIndex = 0
  const context = vm.createContext({
    supabase, supabaseConfigured: true, queueMicrotask,
    createContext: () => ({}), useContext: () => ({}),
    useEffect: callback => effects.push(callback),
    useMemo: callback => callback(), useRef: value => ({ current: value }),
    useState: initial => { const index = stateIndex++; return [initial, value => { if (index === 0) user = value }] },
  })
  const auth = vm.runInContext(`${source}\nAuthProvider({ children: null })`, context)
  effects.forEach(effect => effect())
  return { auth, user: () => user, signInCalls: () => signInCalls, signOutCalls: () => signOutCalls }
}

for (const role of ['student', 'member', 'bureau', 'admin']) {
  test(`${role} can log in through its matching entry`, async () => {
    const app = setup(role)
    await app.auth.login({ email: 'person@hestim.ma', password: 'real-password', loginType: role === 'admin' ? 'admin' : 'student' })
    assert.equal(app.user()?.role, role)
    assert.equal(app.signOutCalls(), 0)
  })
}
for (const [role, loginType] of [['student', 'admin'], ['admin', 'student']]) {
  test(`${role} is rejected through ${loginType}, including the auth callback`, async () => {
    const app = setup(role)
    await assert.rejects(app.auth.login({ email: 'person@hestim.ma', password: 'real-password', loginType }))
    assert.equal(app.user(), null)
    assert.equal(app.signOutCalls(), 1)
  })
}
test('former demo credentials go to Supabase and cannot bypass invalid credentials', async () => {
  const app = setup('admin', { message: 'Invalid login credentials' })
  await assert.rejects(app.auth.login({ email: 'demo.admin@hestim.ma', password: 'HClubsDemo2026!', loginType: 'admin' }))
  assert.equal(app.signInCalls(), 1)
  assert.equal(app.user(), null)
})
test('invalid login selection is rejected before authentication', async () => {
  const app = setup('student')
  await assert.rejects(app.auth.login({ email: 'person@hestim.ma', password: 'secret', loginType: 'owner' }))
  assert.equal(app.signInCalls(), 0)
})
