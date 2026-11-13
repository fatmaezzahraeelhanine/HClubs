import { createContext, useContext, useEffect, useMemo, useState } from 'react'
import { INITIAL_CLUBS, INITIAL_CLUB_REQUESTS, INITIAL_EVENTS, INITIAL_RESERVATIONS, INITIAL_TASKS } from '../data/mockData'
import { supabase, supabaseConfigured } from '../lib/supabase'
import { useAuth } from './AuthContext'

const DataContext = createContext(null)
const KEY = 'hestim_campus_data_v1'
const initial = { clubs: INITIAL_CLUBS, events: INITIAL_EVENTS, tasks: INITIAL_TASKS, reservations: INITIAL_RESERVATIONS, clubRequests: INITIAL_CLUB_REQUESTS, memberships: {}, members: [], projects: [], rooms: [], budgetRows: [], budgetYear: new Date().getFullYear(), globalBudget: 0 }
function readData() { try { const saved = JSON.parse(localStorage.getItem(KEY)); return saved && typeof saved === 'object' ? { ...initial, ...saved } : initial } catch { return initial } }
const normalize = value => value?.toLocaleLowerCase('fr') || ''

function mapClub(row, index) {
  const sample = INITIAL_CLUBS.find(item => normalize(item.name) === normalize(row.name))
  return { id: row.id, name: row.name, category: sample?.category || 'Association', description: sample?.description || `Communauté associative ${row.name}.`, members: null, color: sample?.color || ['blue', 'green', 'violet', 'orange', 'pink', 'amber'][index % 6], icon: sample?.icon || 'Users', room: sample?.room || '', budget: 0, spent: 0, lead: '', email: '', featured: false }
}
function mapEvent(row, clubs) {
  const date = new Date(row.event_date)
  const club = clubs.find(item => item.id === row.club_id)
  return { id: row.id, clubId: row.club_id, title: row.title, description: row.description || '', date: Number.isNaN(date.getTime()) ? '' : date.toISOString().slice(0, 10), time: Number.isNaN(date.getTime()) ? '' : date.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }), location: row.location || club?.room || 'Campus HESTIM', status: row.status || 'approved', maxPlaces: Number(row.max_places) || 30, attendees: [], category: row.category || club?.category || 'Campus' }
}
function mapTask(row, projects) {
  const project = projects.find(item => item.id === row.project_id)
  return { id: row.id, title: row.title, clubId: row.club_id, projectId: row.project_id, status: row.status === 'doing' ? 'progress' : row.status, priority: row.priority || 'medium', dueDate: row.due_date || new Date().toISOString().slice(0, 10), assignee: row.assignee || '', projectName: project?.name || '' }
}
function mapReservation(row, rooms, profiles) {
  const start = new Date(row.start_time)
  const end = new Date(row.end_time)
  const format = date => date.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })
  return { id: row.id, clubId: row.club_id, type: 'Salle', roomId: row.room_id, resource: rooms.find(room => room.id === row.room_id)?.name || 'Salle', date: Number.isNaN(start.getTime()) ? '' : start.toISOString().slice(0, 10), time: Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) ? '' : `${format(start)} – ${format(end)}`, purpose: row.purpose || 'Réservation de salle', status: row.status, requester: profiles.find(profile => profile.id === row.requested_by)?.name || row.requested_by, attendees: Number(row.attendees) || 1 }
}

async function fetchRemoteData() {
  const tables = ['clubs', 'events', 'rooms', 'projects', 'tasks', 'room_reservations', 'budgets', 'profiles', 'event_registrations', 'club_memberships']
  const results = await Promise.all(tables.map(table => supabase.from(table).select('*')))
  const failed = results.find(result => result.error)
  if (failed) throw failed.error
  const [clubRows, eventRows, roomRows, projectRows, taskRows, reservationRows, budgetRows, profiles, registrationRows, membershipRows] = results.map(result => result.data || [])
  const clubs = clubRows.map(mapClub)
  const projects = projectRows.map(row => ({ ...row, clubId: row.club_id }))
  const rooms = roomRows
  const memberCounts = membershipRows.reduce((counts, row) => ({ ...counts, [row.club_id]: (counts[row.club_id] || 0) + 1 }), {})
  const memberships = membershipRows.reduce((all, row) => ({ ...all, [row.club_id]: [...(all[row.club_id] || []), row.user_id] }), {})
  const budgetYear = budgetRows.reduce((latest, row) => Math.max(latest, Number(row.year) || 0), 0) || new Date().getFullYear()
  const spentByClub = new Map()
  const budgetByClub = new Map()
  for (const budget of budgetRows.filter(row => Number(row.year) === budgetYear)) {
    const key = budget.club_id || '__campus__'
    budgetByClub.set(key, (budgetByClub.get(key) || 0) + Number(budget.amount || 0))
  }
  return {
    ...initial,
    clubs: clubs.map(club => ({ ...club, members: memberCounts[club.id] || 0, budget: budgetByClub.get(club.id) || 0, spent: spentByClub.get(club.id) || 0 })),
    events: eventRows.map(row => ({ ...mapEvent(row, clubs), attendees: registrationRows.filter(registration => registration.event_id === row.id).map(registration => registration.user_id) })),
    projects,
    members: profiles.map(profile => ({ id: profile.id, name: profile.name, clubId: profile.club_id })),
    tasks: taskRows.map(row => mapTask(row, projects)),
    rooms,
    reservations: reservationRows.map(row => mapReservation(row, rooms, profiles)),
    clubRequests: [],
    memberships,
    budgetRows,
    budgetYear,
    globalBudget: budgetByClub.get('__campus__') || 0,
  }
}

function toIso(date, time) {
  const value = new Date(`${date}T${time}:00`)
  if (Number.isNaN(value.getTime())) throw new Error('Date ou hora invalide.')
  return value.toISOString()
}

export function DataProvider({ children }) {
  const { user } = useAuth()
  const [data, setData] = useState(readData)
  const [dbError, setDbError] = useState('')
  const [dataSynced, setDataSynced] = useState(false)

  const refreshRemote = async () => {
    if (!supabaseConfigured) return
    try { setData(await fetchRemoteData()); setDbError(''); setDataSynced(true) }
    catch (error) { setDataSynced(false); setDbError(`Erreur Supabase : ${error.message}`) }
  }
  useEffect(() => {
    if (!supabaseConfigured) return
    if (!user) { setData(initial); setDataSynced(false); return }
    refreshRemote()
    const channel = ['clubs', 'events', 'rooms', 'projects', 'tasks', 'room_reservations', 'budgets', 'profiles', 'event_registrations', 'club_memberships'].reduce((current, table) => current.on('postgres_changes', { event: '*', schema: 'public', table }, () => refreshRemote()), supabase.channel(`hclubs-data-${user.id}`)).subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [user?.id])

  const localUpdate = updater => setData(current => {
    const next = typeof updater === 'function' ? updater(current) : { ...current, ...updater }
    localStorage.setItem(KEY, JSON.stringify(next))
    return next
  })
  const warnUnsupported = message => { setDbError(message); return false }
  const runRemote = async operation => {
    try { await operation(); await refreshRemote(); return true }
    catch (error) { setDbError(`Supabase : ${error.message}`); return false }
  }

  const joinClub = (clubId, userId) => supabaseConfigured
    ? runRemote(async () => { const { error } = await supabase.from('club_memberships').insert({ club_id: clubId, user_id: userId }); if (error && error.code !== '23505') throw error })
    : localUpdate(d => {
      if ((d.memberships?.[clubId] || []).includes(email)) return d
      return { ...d, memberships: { ...d.memberships, [clubId]: [...(d.memberships?.[clubId] || []), email] }, clubs: d.clubs.map(club => club.id === clubId ? { ...club, members: club.members + 1 } : club) }
    })
  const joinEvent = (eventId, userId) => supabaseConfigured
    ? runRemote(async () => { const { error } = await supabase.rpc('register_for_event', { requested_event_id: eventId }); if (error) throw error })
    : localUpdate(d => ({ ...d, events: d.events.map(event => event.id === eventId && !event.attendees.includes(userId) && event.attendees.length < event.maxPlaces ? { ...event, attendees: [...event.attendees, userId] } : event) }))
  const addEvent = event => supabaseConfigured
    ? runRemote(async () => { const { error } = await supabase.from('events').insert({ club_id: event.clubId, title: event.title, description: event.description, event_date: toIso(event.date, event.time), location: event.location, category: event.category, max_places: Number(event.maxPlaces), status: 'pending' }); if (error) throw error })
    : localUpdate(d => ({ ...d, events: [{ ...event, id: crypto.randomUUID(), status: 'pending', attendees: [] }, ...d.events] }))
  const addClubRequest = request => supabaseConfigured
    ? warnUnsupported('Le schéma SQL ne contient pas de table de demandes de création de clubs.')
    : localUpdate(d => ({ ...d, clubRequests: [{ ...request, id: crypto.randomUUID(), status: 'pending' }, ...d.clubRequests] }))
  const setClubRequestStatus = (id, status) => supabaseConfigured
    ? warnUnsupported('Les demandes de clubs ne sont pas représentées dans le schéma SQL.')
    : localUpdate(d => {
      const request = d.clubRequests.find(item => item.id === id)
      const clubRequests = d.clubRequests.map(item => item.id === id ? { ...item, status } : item)
      if (status !== 'approved' || !request) return { ...d, clubRequests }
      const slug = request.name.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]+/g, '-')
      const colors = ['blue', 'green', 'violet', 'orange', 'pink', 'amber']
      return { ...d, clubRequests, clubs: [...d.clubs, { id: `${slug}-${Date.now()}`, name: request.name, category: request.category, description: request.description, members: 1, color: colors[d.clubs.length % colors.length], icon: 'Users', room: 'À définir', budget: 0, spent: 0, lead: request.proposedBy, email: request.email, featured: false }] }
    })

  const addTask = task => {
    if (!supabaseConfigured) return localUpdate(d => ({ ...d, tasks: [...d.tasks, { ...task, id: crypto.randomUUID() }] }))
    return runRemote(async () => {
      let project = data.projects.find(item => item.club_id === task.clubId)
      if (!project) {
        const { data: created, error } = await supabase.from('projects').insert({ club_id: task.clubId, name: 'Projets du club' }).select().single()
        if (error) throw error
        project = created
      }
      if (task.status === 'done') throw new Error('Une nouvelle tâche ne peut pas être créée directement comme terminée.')
      const { error } = await supabase.from('tasks').insert({ project_id: project.id, club_id: task.clubId, title: task.title, status: task.status === 'progress' ? 'doing' : 'todo', priority: task.priority || 'medium', due_date: task.dueDate, assignee: task.assignee || '' })
      if (error) throw error
    })
  }
  const moveTask = (id, status) => {
    if (!supabaseConfigured) return localUpdate(d => ({ ...d, tasks: d.tasks.map(task => task.id === id ? { ...task, status } : task) }))
    const dbStatus = status === 'progress' ? 'doing' : status
    return runRemote(async () => { const { error } = await supabase.from('tasks').update({ status: dbStatus }).eq('id', id); if (error) throw error })
  }
  const updateTask = (id, updates) => {
    if (!supabaseConfigured) return localUpdate(d => ({ ...d, tasks: d.tasks.map(task => task.id === id ? { ...task, ...updates } : task) }))
    const payload = { title: updates.title, status: updates.status === 'progress' ? 'doing' : updates.status, priority: updates.priority, due_date: updates.dueDate, assignee: updates.assignee }
    return runRemote(async () => { const { error } = await supabase.from('tasks').update(Object.fromEntries(Object.entries(payload).filter(([, value]) => value !== undefined))).eq('id', id); if (error) throw error })
  }
  const addReservation = reservation => {
    if (!supabaseConfigured) return localUpdate(d => ({ ...d, reservations: [{ ...reservation, id: crypto.randomUUID(), status: 'pending' }, ...d.reservations] }))
    return runRemote(async () => {
      if (reservation.type !== 'Salle') throw new Error('Le schéma SQL gère les salles, pas les réservations de matériel.')
      const room = data.rooms.find(item => item.name.toLowerCase() === reservation.resource.trim().toLowerCase())
      if (!room) throw new Error('Choisissez une salle existante dans la table rooms.')
      const match = reservation.time.match(/(\d{1,2}:\d{2})\s*[–-]\s*(\d{1,2}:\d{2})/)
      if (!match) throw new Error('Saisissez l’horaire au format 14:00 – 16:00.')
      if (room.capacity && Number(reservation.attendees) > room.capacity) throw new Error(`Cette salle est limitée à ${room.capacity} personnes.`)
      const { error } = await supabase.from('room_reservations').insert({ room_id: room.id, club_id: reservation.clubId, requested_by: user.id, start_time: toIso(reservation.date, match[1]), end_time: toIso(reservation.date, match[2]), purpose: reservation.purpose, attendees: Number(reservation.attendees), status: 'pending' })
      if (error) throw error
    })
  }
  const setReservationStatus = (id, status) => supabaseConfigured
    ? runRemote(async () => { const { error } = await supabase.from('room_reservations').update({ status }).eq('id', id); if (error) throw error })
    : localUpdate(d => ({ ...d, reservations: d.reservations.map(item => item.id === id ? { ...item, status } : item) }))
  const setEventStatus = (id, status) => supabaseConfigured
    ? runRemote(async () => { const { error } = await supabase.from('events').update({ status }).eq('id', id); if (error) throw error })
    : localUpdate(d => ({ ...d, events: d.events.map(event => event.id === id ? { ...event, status } : event) }))

  const value = useMemo(() => ({ ...data, joinClub, joinEvent, addEvent, addClubRequest, setClubRequestStatus, addTask, moveTask, updateTask, addReservation, setReservationStatus, setEventStatus, dbError, dataSynced, refreshData: refreshRemote, clearDbError: () => setDbError(''), usingSupabase: supabaseConfigured }), [data, dbError, dataSynced, user?.id])
  return <DataContext.Provider value={value}>{children}</DataContext.Provider>
}

export const useData = () => { const context = useContext(DataContext); if (!context) throw new Error('useData doit être utilisé dans DataProvider'); return context }
