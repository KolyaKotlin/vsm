// Единственное место, где фронтенд знает адреса бэкенда.

const request = async (path, options = {}) => {
  const response = await fetch(`/api${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  })

  if (!response.ok) {
    const problem = await response.json().catch(() => ({}))
    throw new Error(problem.detail || `Запрос ${path} завершился ошибкой ${response.status}`)
  }

  return response.json()
}

const post = (path, body) => request(path, { method: 'POST', body: body ? JSON.stringify(body) : undefined })

export const api = {
  health: () => request('/health'),
  enter: (code) => post('/access', { code }),
  employees: () => request('/employees'),
  profile: (employeeId) => request(`/employees/${employeeId}/profile`),
  analytics: (employeeId) => request(`/employees/${employeeId}/analytics`),
  attempts: (employeeId) => request(`/employees/${employeeId}/attempts`),
  notifications: (employeeId) => request(`/employees/${employeeId}/notifications`),
  markNotificationRead: (notificationId) => post(`/notifications/${notificationId}/read`),
  scenarios: () => request('/scenarios'),
  leaderboard: (scope, employeeId) => {
    const params = new URLSearchParams({ scope })
    if (employeeId) params.set('employee_id', employeeId)
    return request(`/leaderboard?${params}`)
  },
  startAttempt: (employeeId, scenarioId) => post('/attempts', { employee_id: employeeId, scenario_id: scenarioId }),
  choose: (attemptId, optionId) => post(`/attempts/${attemptId}/choice`, { option_id: optionId }),
  reportTimeout: (attemptId) => post(`/attempts/${attemptId}/timeout`),
  adminSession: (code) => post('/admin/session', { code }),
  adminEmployees: (code) => request('/admin/employees', { headers: { 'Content-Type': 'application/json', 'X-Admin-Code': code } }),
  adminCreateEmployee: (code, body) =>
    request('/admin/employees', { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Admin-Code': code }, body: JSON.stringify(body) }),
  adminReissue: (code, employeeId) =>
    request(`/admin/employees/${employeeId}/code`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Admin-Code': code } }),
  adminScenarios: (code) => request('/admin/scenarios', { headers: { 'Content-Type': 'application/json', 'X-Admin-Code': code } }),
  adminCreateScenario: (code, body) =>
    request('/admin/scenarios', { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Admin-Code': code }, body: JSON.stringify(body) }),
}
