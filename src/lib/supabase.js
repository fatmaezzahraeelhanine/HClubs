import { createClient } from '@supabase/supabase-js'

// The publishable key is meant to be exposed in browser apps. RLS remains the
// security boundary; never put a Supabase service_role key in this file.
const url = import.meta.env.VITE_SUPABASE_URL?.trim() || 'https://tpatppstlkslhqzmayir.supabase.co'
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim() || 'sb_publishable_Xxy_81hjMOgqFqbhegsM_w_PQf7J80X'

export const supabaseConfigured = Boolean(url && anonKey)
export const supabase = supabaseConfigured ? createClient(url, anonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    storage: typeof window === 'undefined' ? undefined : window.sessionStorage,
  },
}) : null
