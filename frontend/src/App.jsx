import { useCallback, useEffect, useState } from 'react'
import { api } from './api.js'
import Analytics from './components/Analytics.jsx'
import Leaderboard from './components/Leaderboard.jsx'
import Notifications from './components/Notifications.jsx'
import Login from './components/Login.jsx'
import PlayScreen from './components/PlayScreen.jsx'
import Profile from './components/Profile.jsx'
import ScenarioList from './components/ScenarioList.jsx'

const SESSION_KEY = 'vsm-employee'

const TABS = [
  { id: 'scenarios', label: 'Ситуации' },
  { id: 'profile', label: 'Профиль' },
  { id: 'rating', label: 'Рейтинг' },
  { id: 'analytics', label: 'Аналитика' },
  { id: 'notifications', label: 'Уведомления' },
]

const readSession = () => {
  try {
    const raw = sessionStorage.getItem(SESSION_KEY)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

export default function App() {
  const [employee, setEmployee] = useState(readSession)
  const [tab, setTab] = useState('scenarios')
  const [attempt, setAttempt] = useState(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(null)
  // Ключ обновления: после завершённого сценария профиль, рейтинг и аналитика
  // должны перечитаться, иначе игрок не увидит начисленные очки.
  const [refreshKey, setRefreshKey] = useState(0)
  const [unread, setUnread] = useState(0)

  const employeeId = employee?.id ?? null

  const enter = (next) => {
    sessionStorage.setItem(SESSION_KEY, JSON.stringify(next))
    setEmployee(next)
    setAttempt(null)
    setTab('scenarios')
    setError(null)
  }

  const leaveAccount = () => {
    sessionStorage.removeItem(SESSION_KEY)
    setEmployee(null)
    setAttempt(null)
  }

  useEffect(() => {
    if (!employeeId) return
    api
      .profile(employeeId)
      .then((profile) => setUnread(profile.unread_notifications))
      // Счётчик непрочитанных — не повод показывать ошибку на весь экран, но и
      // обнулять его нельзя: это выдумало бы «уведомлений нет».
      .catch((problem) => console.warn('Не удалось обновить счётчик уведомлений', problem))
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

  return (
    <div className="app">
      <header className="topbar">
        <div className="brand">
          <span className="brand-mark">ВСМ</span>
          <div>
            <p className="eyebrow">Учебный тренажёр</p>
            <h1>Проводник пассажирского поезда</h1>
          </div>
        </div>

        {employee ? (
          <div className="who">
            <span>Проводник</span>
            <strong>{employee.display_name}</strong>
            <button type="button" onClick={leaveAccount}>
              Выйти
            </button>
          </div>
        ) : null}
      </header>

      <div className="sheet">
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
      ) : !employee ? (
        <main>
          <Login onEnter={enter} />
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
            {tab === 'scenarios' ? (
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
        Демо-среда на синтетических данных: {employee ? employee.display_name : 'профиль не выбран'}.
        Реальные персональные данные пассажиров и сотрудников не используются.
      </footer>
      </div>
    </div>
  )
}
