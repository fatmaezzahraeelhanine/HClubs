const csvCell = value => `"${String(value ?? '').replaceAll('"', '""')}"`

export function downloadCsv(filename, headers, rows) {
  const content = [headers, ...rows].map(row => row.map(csvCell).join(';')).join('\r\n')
  const blob = new Blob([`\uFEFF${content}`], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  link.click()
  URL.revokeObjectURL(url)
}

export function downloadIcs(filename, events) {
  const escape = value => String(value || '').replaceAll('\\', '\\\\').replaceAll(';', '\\;').replaceAll(',', '\\,').replaceAll('\n', '\\n')
  const stamp = (date, time = '09:00') => `${String(date).replaceAll('-', '')}T${String(time).replace(':', '')}00`
  const entries = events.map(event => [
    'BEGIN:VEVENT', `UID:${event.id}@hclubs.hestim.ma`, `DTSTAMP:${stamp(new Date().toISOString().slice(0, 10), new Date().toISOString().slice(11, 16))}`,
    `DTSTART:${stamp(event.date, event.time)}`, `SUMMARY:${escape(event.title)}`, `LOCATION:${escape(event.location)}`,
    `DESCRIPTION:${escape(event.description)}`, 'END:VEVENT',
  ].join('\r\n'))
  const blob = new Blob([`BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//HESTIM//HClubs//FR\r\n${entries.join('\r\n')}\r\nEND:VCALENDAR`], { type: 'text/calendar;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  link.click()
  URL.revokeObjectURL(url)
}
