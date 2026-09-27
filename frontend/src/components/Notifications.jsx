import { useState } from 'react'
import { api } from '../api.js'
import { useApiData } from '../useApiData.js'

const KIND_LABELS = {
  new_scenario: 'Новый сценарий',
  challenge: 'Челлендж',
  expiring_points: 'Сгорающие баллы',
  achievement: 'Достижение',
}

const formatDate = (value) =>
  new Date(value).toLocaleString('ru-RU', { day: '2-digit', month: 'long', hour: '2-digit', minute: '2-digit' })

export default function Notifications({ employeeId, refreshKey, onRead }) {
  const [localKey, setLocalKey] = useState(0)
  const { data, error } = useApiData(
    () => api.notifications(employeeId),
    [employeeId, refreshKey, localKey],
  )

  const markRead = async (notificationId) => {
    await api.markNotificationRead(notificationId)
    setLocalKey((value) => value + 1)
    onRead?.()
  }

  if (error) return <p className="error">{error}</p>
  if (!data) return <p className="muted">Загрузка уведомлений…</p>

  return (
    <section>
      <h2>Уведомления</h2>
      <p className="muted section-hint">
        Новые ситуации, задания на смену и компетенции, баллы по которым скоро сгорят.
      </p>

      <ul className="notifications">
        {data.map((item) => (
          <li key={item.id} className={item.read_at ? 'read' : 'unread'}>
            <header>
              <span className="tag">{KIND_LABELS[item.kind] || item.kind}</span>
              <time className="muted">{formatDate(item.created_at)}</time>
            </header>
            <strong>{item.title}</strong>
            <p>{item.body}</p>
            {item.read_at ? (
              <span className="muted">Прочитано</span>
            ) : (
              <button type="button" onClick={() => markRead(item.id)}>
                Отметить прочитанным
              </button>
            )}
          </li>
        ))}
      </ul>
    </section>
  )
}
