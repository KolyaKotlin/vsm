import { api } from '../api.js'
import { useApiData } from '../useApiData.js'

const STATUS_TONE = {
  освоено: 'good',
  'в работе': 'warn',
  проседает: 'bad',
}

export default function Analytics({ employeeId, refreshKey }) {
  const { data, error } = useApiData(() => api.analytics(employeeId), [employeeId, refreshKey])

  if (error) return <p className="error">{error}</p>
  if (!data) return <p className="muted">Считаем аналитику…</p>

  return (
    <section>
      <h2>Разбор компетенций</h2>
      <p className="muted section-hint">
        Считается по каждому решению, а не только по итогу ситуации. Так видно, где регламент
        проседает ещё до финала.
      </p>

      <div className="metrics">
        <div className="metric">
          <strong>{data.attempts_finished}</strong>
          <span>смен завершено</span>
        </div>
        <div className="metric">
          <strong>{data.attempts_passed}</strong>
          <span>сдано успешно</span>
        </div>
        <div className="metric">
          <strong>{data.timeouts}</strong>
          <span>истёкших таймеров</span>
        </div>
        <div className="metric">
          <strong>{data.harmful_choices}</strong>
          <span>ошибочных решений</span>
        </div>
        <div className="metric">
          <strong>{data.average_loyalty ?? '—'}</strong>
          <span>средняя лояльность</span>
        </div>
        <div className="metric">
          <strong>{data.average_safety ?? '—'}</strong>
          <span>средняя безопасность</span>
        </div>
      </div>

      <div className="profile-grid">
        <div className="card">
          <h3>Состояние компетенций</h3>
          <ul className="competency-list">
            {data.competencies.map((item) => (
              <li key={item.competency}>
                <span>{item.title}</span>
                <span className={`status ${STATUS_TONE[item.status] || ''}`}>{item.status}</span>
                <strong>{item.points}</strong>
              </li>
            ))}
          </ul>
        </div>

        <div className="card">
          <h3>Что делать дальше</h3>
          <ul className="advice">
            {data.recommendations.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
          {data.gaps.length > 0 ? (
            <p className="muted">Проседают: {data.gaps.join(', ')}.</p>
          ) : (
            <p className="muted">Явных пробелов нет.</p>
          )}
        </div>
      </div>
    </section>
  )
}
