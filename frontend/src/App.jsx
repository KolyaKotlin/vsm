import { useCallback, useEffect, useState } from 'react'
import { api } from './api.js'
import Analytics from './components/Analytics.jsx'
import Leaderboard from './components/Leaderboard.jsx'
import Notifications from './components/Notifications.jsx'
import PlayScreen from './components/PlayScreen.jsx'
import Profile from './components/Profile.jsx'
import ScenarioList from './components/ScenarioList.jsx'

const TABS = [
  { id: 'scenarios', label: 'Ситуации' },
  { id: 'profile', label: 'Профиль' },
  { id: 'rating', label: 'Рейтинг' },
  { id: 'analytics', label: 'Аналитика' },
  { id: 'notifications', label: 'Уведомления' },
]

export default function App() {
  const [employees, setEmployees] = useState([])
  const [employeeId, setEmployeeId] = useState(null)
  const [tab, setTab] = useState('scenarios')
  const [attempt, setAttempt] = useState(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(null)
  // Ключ обновления: после завершённого сценария профиль, рейтинг и аналитика
  // должны перечитаться, иначе игрок не увидит начисленные очки.
  const [refreshKey, setRefreshKey] = useState(0)
  const [unread, setUnread] = useState(0)

  useEffect(() => {
    api
      .employees()
      .then((list) => {
        setEmployees(list)
        const trainee = list.find((item) => item.login === 'demo.trainee') || list[0]
        setEmployeeId(trainee?.id ?? null)
      })
      .catch((problem) => setError(problem.message))
  }, [])

  useEffect(() => {
    if (!employeeId) return
    api
      .profile(employeeId)
      .then((profile) => setUnread(profile.unread_notifications))
      .catch(() => setUnread(0))
  }, [employeeId, refreshKey])

  const refresh = () => setRefreshKey((value) => value + 1)

  const startScenario = async (scenarioId) => {
    setBusy(true)
    setError(null)
    try {
      setAttempt(await api.startAttempt(employeeId, scenarioId))
    } catch (problem) {
      setError(problem.message)
    } finally {
      setBusy(false)
    }
  }

  const handleAttemptUpdate = (next) => {
    setAttempt(next)
    if (next.finished) refresh()
  }

  const choose = async (optionId) => {
    setBusy(true)
    try {
      handleAttemptUpdate(await api.choose(attempt.attempt_id, optionId))
    } catch (problem) {
      setError(problem.message)
    } finally {
      setBusy(false)
    }
  }

  const reportTimeout = useCallback(async () => {
    if (!attempt || attempt.finished) return
    try {
      const next = await api.reportTimeout(attempt.attempt_id)
      setAttempt(next)
      if (next.finished) refresh()
    } catch (problem) {
      setError(problem.message)
    }
  }, [attempt])

  const leavePlay = () => {
    setAttempt(null)
    refresh()
  }

  const currentEmployee = employees.find((item) => item.id === employeeId)

  return (
    <div className="app">
      <header className="app-head">
        <div className="brand">
          <span className="brand-mark">ВСМ</span>
          <div>
            <h1>Тренажёр проводников</h1>
            <p className="muted">Нештатные ситуации на борту высокоскоростного поезда</p>
          </div>
        </div>

        <label className="employee-picker">
          <span className="muted">Профиль проводника</span>
          <select
            value={employeeId ?? ''}
            onChange={(event) => {
              setEmployeeId(Number(event.target.value))
              setAttempt(null)
            }}
          >
            {employees.map((item) => (
              <option key={item.id} value={item.id}>
                {item.display_name} · уровень {item.level}
              </option>
            ))}
          </select>
        </label>
      </header>

      {error ? (
        <p className="error banner">
          {error}
          <button type="button" onClick={() => setError(null)}>
            Скрыть
          </button>
        </p>
      ) : null}

      {attempt ? (
        <main>
          <PlayScreen
            attempt={attempt}
            busy={busy}
            onChoose={choose}
            onTimeout={reportTimeout}
            onRestart={() => startScenario(attempt.scenario.id)}
            onLeave={leavePlay}
          />
        </main>
      ) : (
        <>
          <nav className="tabs">
            {TABS.map((item) => (
              <button
                key={item.id}
                type="button"
                className={tab === item.id ? 'active' : ''}
                onClick={() => setTab(item.id)}
              >
                {item.label}
                {item.id === 'notifications' && unread > 0 ? <em className="counter">{unread}</em> : null}
              </button>
            ))}
          </nav>

          <main>
            {!employeeId ? (
              <p className="muted">Загрузка демо-профилей…</p>
            ) : tab === 'scenarios' ? (
              <ScenarioList employeeId={employeeId} refreshKey={refreshKey} onStart={startScenario} />
            ) : tab === 'profile' ? (
              <Profile employeeId={employeeId} refreshKey={refreshKey} />
            ) : tab === 'rating' ? (
              <Leaderboard employeeId={employeeId} refreshKey={refreshKey} />
            ) : tab === 'analytics' ? (
              <Analytics employeeId={employeeId} refreshKey={refreshKey} />
            ) : (
              <Notifications employeeId={employeeId} refreshKey={refreshKey} onRead={refresh} />
            )}
          </main>
        </>
      )}

      <footer className="app-foot muted">
        Демо-среда на синтетических данных: {currentEmployee ? currentEmployee.display_name : 'профиль не выбран'}.
        Реальные персональные данные пассажиров и сотрудников не используются.
      </footer>
    </div>
  )
}
