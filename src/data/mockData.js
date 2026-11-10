export const ALLOWED_ROLES = [
  { email: 'admin@hestim.ma', role: 'admin', bureauRole: 'Administration', clubId: null, name: 'Administration HESTIM' },
  { email: 'president.robotique@hestim.ma', role: 'bureau', bureauRole: 'Président', clubId: 'robotique', name: 'Yasmine El Mansouri' },
  { email: 'vice.robotique@hestim.ma', role: 'bureau', bureauRole: 'Vice-président', clubId: 'robotique', name: 'Amine Berrada' },
  { email: 'secretaire.civil@hestim.ma', role: 'bureau', bureauRole: 'Secrétaire', clubId: 'genie-civil', name: 'Salma Idrissi' },
  { email: 'membre.entrepreneuriat@hestim.ma', role: 'member', bureauRole: 'Membre actif', clubId: 'entrepreneuriat', name: 'Omar Alaoui' },
]

export const INITIAL_CLUBS = [
  { id: 'robotique', name: 'Club Robotique', category: 'Technologie', description: 'Imaginer, concevoir et donner vie à des robots. Rejoignez une communauté passionnée par l’innovation et la technologie.', members: 42, color: 'blue', icon: 'Cpu', room: 'Laboratoire A-12', budget: 18500, spent: 11200, lead: 'Yasmine El Mansouri', email: 'president.robotique@hestim.ma', featured: true },
  { id: 'genie-civil', name: 'Club Génie Civil', category: 'Ingénierie', description: 'Façonner la ville de demain à travers des projets concrets, des visites de chantier et des concours de construction.', members: 36, color: 'orange', icon: 'Construction', room: 'Atelier B-04', budget: 14200, spent: 7800, lead: 'Salma Idrissi', email: 'secretaire.civil@hestim.ma', featured: false },
  { id: 'entrepreneuriat', name: 'Club Entrepreneuriat', category: 'Business', description: 'De l’idée au projet : ateliers, rencontres inspirantes et accompagnement pour les entrepreneurs de demain.', members: 58, color: 'violet', icon: 'Lightbulb', room: 'Espace Coworking', budget: 22000, spent: 13600, lead: 'Omar Alaoui', email: 'membre.entrepreneuriat@hestim.ma', featured: true },
  { id: 'design', name: 'Club Design & Créativité', category: 'Créativité', description: 'Un espace pour créer, expérimenter et repousser les limites du design sous toutes ses formes.', members: 31, color: 'pink', icon: 'Palette', room: 'Studio C-02', budget: 12000, spent: 4900, lead: 'Lina Amrani', email: 'design@hestim.ma', featured: false },
  { id: 'enactus', name: 'Enactus HESTIM', category: 'Impact social', description: 'Entreprendre pour un monde meilleur : des projets à impact social, portés par l’action collective.', members: 47, color: 'green', icon: 'Sprout', room: 'Salle D-10', budget: 25000, spent: 16800, lead: 'Mehdi Tazi', email: 'enactus@hestim.ma', featured: false },
  { id: 'culture', name: 'Club Culture & Arts', category: 'Culture', description: 'Célébrer les cultures, ouvrir des horizons et partager des moments artistiques sur le campus.', members: 29, color: 'amber', icon: 'Music2', room: 'Amphithéâtre', budget: 11000, spent: 5400, lead: 'Sara Fassi', email: 'culture@hestim.ma', featured: false },
]

export const INITIAL_EVENTS = [
  { id: 'e1', title: 'Hackathon HESTIM 2026', clubId: 'robotique', date: '2026-11-06', time: '09:00', location: 'Campus HESTIM · Lab A', status: 'approved', maxPlaces: 80, attendees: ['sara@hestim.ma', 'amine@hestim.ma', 'nora@hestim.ma'], category: 'Technologie', description: '48 heures pour transformer vos idées en solutions concrètes.' },
  { id: 'e2', title: 'Construire la ville de demain', clubId: 'genie-civil', date: '2026-11-12', time: '14:30', location: 'Amphithéâtre principal', status: 'approved', maxPlaces: 120, attendees: ['youssef@hestim.ma', 'lina@hestim.ma'], category: 'Conférence', description: 'Une conversation autour des villes durables et des nouvelles pratiques.' },
  { id: 'e3', title: 'Pitch Night — Winter Edition', clubId: 'entrepreneuriat', date: '2026-11-19', time: '18:00', location: 'Espace Coworking', status: 'approved', maxPlaces: 60, attendees: ['aya@hestim.ma', 'hamza@hestim.ma', 'nabil@hestim.ma'], category: 'Networking', description: 'Présentez votre idée, trouvez votre équipe et faites le premier pas.' },
  { id: 'e4', title: 'Design Sprint : repenser le campus', clubId: 'design', date: '2026-11-24', time: '10:00', location: 'Studio C-02', status: 'pending', maxPlaces: 30, attendees: [], category: 'Atelier', description: 'Un atelier collaboratif pour imaginer une expérience campus améliorée.' },
  { id: 'e5', title: 'Forum des associations', clubId: 'enactus', date: '2026-12-02', time: '11:00', location: 'Esplanade HESTIM', status: 'approved', maxPlaces: 200, attendees: ['nora@hestim.ma'], category: 'Campus', description: 'Découvrez les clubs, leurs projets et comment vous engager.' },
  { id: 'e6', title: 'Soirée des talents', clubId: 'culture', date: '2026-12-10', time: '19:00', location: 'Amphithéâtre principal', status: 'pending', maxPlaces: 150, attendees: [], category: 'Culture', description: 'Une scène ouverte pour célébrer les talents de la communauté HESTIM.' },
]

export const INITIAL_TASKS = [
  { id: 't1', title: 'Prototype robot suiveur de ligne', clubId: 'robotique', status: 'todo', priority: 'high', dueDate: '2026-11-05', assignee: 'Amine Berrada' },
  { id: 't2', title: 'Préparer le matériel du hackathon', clubId: 'robotique', status: 'progress', priority: 'medium', dueDate: '2026-11-03', assignee: 'Yasmine El Mansouri' },
  { id: 't3', title: 'Contacter les mentors', clubId: 'robotique', status: 'done', priority: 'low', dueDate: '2026-10-28', assignee: 'Yasmine El Mansouri' },
  { id: 't4', title: 'Finaliser le dossier sponsor', clubId: 'genie-civil', status: 'todo', priority: 'high', dueDate: '2026-11-09', assignee: 'Salma Idrissi' },
  { id: 't5', title: 'Maquette du pont en bois', clubId: 'genie-civil', status: 'progress', priority: 'medium', dueDate: '2026-11-07', assignee: 'Salma Idrissi' },
  { id: 't6', title: 'Étude de faisabilité', clubId: 'genie-civil', status: 'done', priority: 'low', dueDate: '2026-10-25', assignee: 'Youssef Karim' },
  { id: 't7', title: 'Préparer les pitchs de la soirée', clubId: 'entrepreneuriat', status: 'todo', priority: 'medium', dueDate: '2026-11-17', assignee: 'Omar Alaoui' },
  { id: 't8', title: 'Inviter le jury', clubId: 'entrepreneuriat', status: 'progress', priority: 'high', dueDate: '2026-11-12', assignee: 'Omar Alaoui' },
]

export const INITIAL_RESERVATIONS = [
  { id: 'r1', clubId: 'robotique', type: 'Salle', resource: 'Salle A-12', date: '2026-11-06', time: '08:00 – 18:00', purpose: 'Hackathon HESTIM 2026', status: 'pending', requester: 'Yasmine El Mansouri', attendees: 80 },
  { id: 'r2', clubId: 'genie-civil', type: 'Matériel', resource: 'Kit maquette + vidéoprojecteur', date: '2026-11-12', time: '13:00 – 17:00', purpose: 'Conférence génie civil', status: 'approved', requester: 'Salma Idrissi', attendees: 50 },
  { id: 'r3', clubId: 'entrepreneuriat', type: 'Salle', resource: 'Espace Coworking', date: '2026-11-19', time: '17:00 – 21:00', purpose: 'Pitch Night', status: 'pending', requester: 'Omar Alaoui', attendees: 60 },
]

export const INITIAL_CLUB_REQUESTS = []
