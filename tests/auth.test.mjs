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
  let signupPayload
  const effects = []
  const profile = { id: 'user-1', email: 'person@hestim.ma', role, name: 'Test' }
  const supabase = {
    from: () => ({ select: () => ({ eq: () => ({ single: async () => ({ data: profile }) }) }) }),
    auth: {
      signUp: async payload => { signupPayload = payload; return { data: { user: profile, session: null } } },
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
  return { auth, signupPayload: () => signupPayload, user: () => user, signInCalls: () => signInCalls, signOutCalls: () => signOutCalls }
}

for (const role of ['student', 'member', 'bureau', 'admin']) {
  test(`${role} can log in through the shared form`, async () => {
    const app = setup(role)
    await app.auth.login({ email: 'person@hestim.ma', password: 'real-password' })
    assert.equal(app.user()?.role, role)
    assert.equal(app.signOutCalls(), 0)
  })
}
test('former demo credentials go to Supabase and cannot bypass invalid credentials', async () => {
  const app = setup('admin', { message: 'Invalid login credentials' })
  await assert.rejects(app.auth.login({ email: 'demo.admin@hestim.ma', password: 'HClubsDemo2026!', loginType: 'admin' }))
  assert.equal(app.signInCalls(), 1)
  assert.equal(app.user(), null)
})
for (const signupType of ['student', 'admin']) {
  test(`${signupType} signup records a request without assigning a role`, async () => {
    const app = setup('student')
    const result = await app.auth.register({ name: 'New User', email: 'new@hestim.ma', password: 'password123', signupType })
    assert.equal(app.signupPayload().options.data.requested_role, signupType)
    assert.equal(app.signupPayload().options.data.role, undefined)
    assert.equal(app.user(), null)
    assert.equal(result.pendingConfirmation, true)
  })
}
test('invalid signup selection is rejected before account creation', async () => {
  const app = setup('student')
  await assert.rejects(app.auth.register({ name: 'New', email: 'new@hestim.ma', password: 'password123', signupType: 'owner' }))
  assert.equal(app.signupPayload(), undefined)
})
