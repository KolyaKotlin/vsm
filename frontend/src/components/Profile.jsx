import { api } from '../api.js'
import { useApiData } from '../useApiData.js'

export default function Profile({ employeeId, refreshKey }) {
  const { data: profile, error } = useApiData(() => api.profile(employeeId), [employeeId, refreshKey])
  const { data: history, error: historyError } = useApiData(
    () => api.attempts(employeeId),
    [employeeId, refreshKey],
  )

  if (error) return <p className="error">{error}</p>
  if (!profile) return <p className="muted">Загрузка профиля…</p>

  const maxPoints = Math.max(1, ...profile.competencies.map((item) => item.points))

  return (
    <section>
      <header className="profile-head">
        <div>
          <h2>{profile.display_name}</h2>
          <p className="muted">
            {profile.position} · {profile.brigade} · {profile.depot}
          </p>
        </div>
        <div className="level">
          <strong>Уровень {profile.level}</strong>
          <span className="muted">{profile.xp} опыта, до следующего {profile.xp_to_next_level}</span>
        </div>
      </header>

      <div className="profile-grid">
        <div className="card">
          <h3>Очки компетенций</h3>
          <ul className="competency-bars">
            {profile.competencies.map((item) => (
              <li key={item.competency}>
                <span>{item.title}</span>
                <div className="scale-track">
                  <div className="scale-fill good" style={{ width: `${(item.points / maxPoints) * 100}%` }} />
                </div>
                <strong>{item.points}</strong>
              </li>
            ))}
          </ul>
        </div>

        <div className="card">
          <h3>Достижения</h3>
          {profile.achievements.length > 0 ? (
            <ul className="achievements">
              {profile.achievements.map((item) => (
                <li key={item.code}>
                  <strong>{item.title}</strong>
                  <span className="muted">{item.description}</span>
                </li>
              ))}
            </ul>
          ) : (
            <p className="muted">Пока нет достижений: пройдите первый сценарий.</p>
          )}
        </div>
      </div>

      <h3 className="sheet-title">История смен</h3>
      {historyError ? (
        <p className="error">История смен недоступна: {historyError}</p>
      ) : !history ? (
        <p className="muted">Смотрим историю смен…</p>
      ) : history.length > 0 ? (
        <table className="table">
          <thead>
            <tr>
              <th>Ситуация</th>
              <th>Итог</th>
              <th>Лояльность</th>
              <th>Безопасность</th>
              <th>Опыт</th>
            </tr>
          </thead>
          <tbody>
            {history.map((item) => (
              <tr key={item.attempt_id}>
                <td>{item.scenario_title}</td>
                <td>
                  {item.status === 'in_progress'
                    ? 'не завершён'
                    : item.passed
                      ? 'закрыт'
                      : 'не сдан'}
                </td>
                <td>{item.loyalty}</td>
                <td>{item.safety}</td>
                <td>{item.xp_awarded ?? '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      ) : (
        <p className="muted">Смен ещё не было.</p>
      )}
    </section>
  )
}
