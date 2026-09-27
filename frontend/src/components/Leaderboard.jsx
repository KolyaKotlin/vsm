import { useState } from 'react'
import { api } from '../api.js'
import { useApiData } from '../useApiData.js'

const SCOPES = [
  { id: 'brigade', label: 'Бригада' },
  { id: 'depot', label: 'Депо' },
  { id: 'company', label: 'Компания' },
]

export default function Leaderboard({ employeeId, refreshKey }) {
  const [scope, setScope] = useState('brigade')
  const { data: rows, error } = useApiData(
    () => api.leaderboard(scope, employeeId),
    [scope, employeeId, refreshKey],
  )

  return (
    <section>
      <h2>Рейтинг</h2>
      <p className="muted section-hint">
        Место считается по накопленному опыту: сданные ситуации его поднимают, ошибочные решения снижают.
      </p>

      <div className="tabs small">
        {SCOPES.map((item) => (
          <button
            key={item.id}
            type="button"
            className={scope === item.id ? 'active' : ''}
            onClick={() => setScope(item.id)}
          >
            {item.label}
          </button>
        ))}
      </div>

      {error ? <p className="error">{error}</p> : null}
      {!rows ? (
        <p className="muted">Загрузка рейтинга…</p>
      ) : (
        <table className="table">
          <thead>
            <tr>
              <th>#</th>
              <th>Проводник</th>
              <th>Бригада</th>
              <th>Депо</th>
              <th>Уровень</th>
              <th>Опыт</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.employee_id} className={row.employee_id === employeeId ? 'me' : ''}>
                <td>{row.place}</td>
                <td>{row.display_name}</td>
                <td>{row.brigade}</td>
                <td>{row.depot}</td>
                <td>{row.level}</td>
                <td>{row.xp}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  )
}
