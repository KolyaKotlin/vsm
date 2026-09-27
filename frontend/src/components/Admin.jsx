import { useState } from 'react'
import { api } from '../api.js'

const EMPTY_SCENARIO = {
  title: '',
  summary: '',
  section: 'Добавленные',
  car: 'Вагон 1',
  service_class: 'стандарт',
  primary_competency: 'service',
  scene: '',
  passenger: '',
  rule: '',
  refusal: '',
  critical: false,
}

export default function Admin({ onBack }) {
  const [code, setCode] = useState('')
  const [ready, setReady] = useState(false)
  const [error, setError] = useState(null)
  const [employees, setEmployees] = useState([])
  const [scenarios, setScenarios] = useState([])
  const [person, setPerson] = useState({ display_name: '', position: 'Проводник', brigade: 'Бригада 1', depot: 'Депо Москва-Восточное' })
  const [scenario, setScenario] = useState(EMPTY_SCENARIO)
  const [issued, setIssued] = useState(null)

  const load = async (adminCode) => {
    const [people, situations] = await Promise.all([
      api.adminEmployees(adminCode),
      api.adminScenarios(adminCode),
    ])
    setEmployees(people)
    setScenarios(situations)
  }

  const enter = async (event) => {
    event.preventDefault()
    setError(null)
    try {
      await api.adminSession(code.trim())
      await load(code.trim())
      setReady(true)
    } catch (problem) {
      setError(problem.message)
    }
  }

  const addPerson = async (event) => {
    event.preventDefault()
    setError(null)
    try {
      const created = await api.adminCreateEmployee(code.trim(), person)
      setIssued(created)
      setPerson({ ...person, display_name: '' })
      await load(code.trim())
    } catch (problem) {
      setError(problem.message)
    }
  }

  const reissue = async (employeeId) => {
    setError(null)
    try {
      const updated = await api.adminReissue(code.trim(), employeeId)
      setIssued(updated)
      await load(code.trim())
    } catch (problem) {
      setError(problem.message)
    }
  }

  const addScenario = async (event) => {
    event.preventDefault()
    setError(null)
    try {
      await api.adminCreateScenario(code.trim(), scenario)
      setScenario(EMPTY_SCENARIO)
      await load(code.trim())
    } catch (problem) {
      setError(problem.message)
    }
  }

  if (!ready) {
    return (
      <section className="login">
        <h2>Кабинет методиста</h2>
        <p className="muted">Отсюда заводят проводников, выдают коды и добавляют ситуации. Этот код не пускает в тренажёр.</p>
        <form onSubmit={enter}>
          <label>
            Код методиста
            <input value={code} onChange={(event) => setCode(event.target.value)} autoFocus />
          </label>
          {error ? <p className="error">{error}</p> : null}
          <div className="row">
            <button type="submit" className="primary" disabled={code.trim() === ''}>Войти</button>
            <button type="button" onClick={onBack}>К проводникам</button>
          </div>
        </form>
      </section>
    )
  }

  return (
    <section className="desk">
      <header className="profile-head">
        <h2>Кабинет методиста</h2>
        <button type="button" onClick={onBack}>Закрыть</button>
      </header>
      {error ? <p className="error">{error}</p> : null}
      {issued ? (
        <p className="desk-issued">
          Код для {issued.display_name}: <strong>{issued.access_code}</strong>
        </p>
      ) : null}

      <div className="profile-grid">
        <form className="card desk-form" onSubmit={addPerson}>
          <h3>Новый проводник</h3>
          <label>ФИО<input value={person.display_name} onChange={(event) => setPerson({ ...person, display_name: event.target.value })} required /></label>
          <label>Должность<input value={person.position} onChange={(event) => setPerson({ ...person, position: event.target.value })} /></label>
          <label>Бригада<input value={person.brigade} onChange={(event) => setPerson({ ...person, brigade: event.target.value })} /></label>
          <label>Депо<input value={person.depot} onChange={(event) => setPerson({ ...person, depot: event.target.value })} /></label>
          <button type="submit" className="primary">Завести и выдать код</button>
        </form>

        <form className="card desk-form" onSubmit={addScenario}>
          <h3>Новая ситуация</h3>
          <label>Название<input value={scenario.title} onChange={(event) => setScenario({ ...scenario, title: event.target.value })} required /></label>
          <label>О чём ситуация<textarea value={scenario.summary} onChange={(event) => setScenario({ ...scenario, summary: event.target.value })} required /></label>
          <label>Что происходит<textarea value={scenario.scene} onChange={(event) => setScenario({ ...scenario, scene: event.target.value })} required /></label>
          <label>Реплика пассажира<input value={scenario.passenger} onChange={(event) => setScenario({ ...scenario, passenger: event.target.value })} required /></label>
          <label>Правило, которое нужно назвать<textarea value={scenario.rule} onChange={(event) => setScenario({ ...scenario, rule: event.target.value })} required /></label>
          <label>Как правило обходят<input value={scenario.refusal} onChange={(event) => setScenario({ ...scenario, refusal: event.target.value })} required /></label>
          <label className="desk-check">
            <input type="checkbox" checked={scenario.critical} onChange={(event) => setScenario({ ...scenario, critical: event.target.checked })} />
            Нарушение нельзя закрыть удачной фразой в конце
          </label>
          <button type="submit" className="primary">Добавить в каталог</button>
        </form>
      </div>

      <h3 className="sheet-title">Проводники</h3>
      <table className="table">
        <thead>
          <tr>
            <th>ФИО</th>
            <th>Бригада</th>
            <th>Код</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {employees.map((item) => (
            <tr key={item.id}>
              <td>{item.display_name}</td>
              <td>{item.brigade}</td>
              <td>{item.access_code || '—'}</td>
              <td><button type="button" onClick={() => reissue(item.id)}>Новый код</button></td>
            </tr>
          ))}
        </tbody>
      </table>

      <h3 className="sheet-title">Ситуации в каталоге: {scenarios.length}</h3>
      <ul className="desk-list">
        {scenarios.map((item) => (
          <li key={item.id}>{String(item.number).padStart(2, '0')} {item.title}</li>
        ))}
      </ul>
    </section>
  )
}
