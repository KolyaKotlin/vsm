import { useState } from 'react'
import { api } from '../api.js'

const DEMO_CODES = [
  ['2401', 'Соколова Мария Ильинична'],
  ['2402', 'Морозов Артём Сергеевич'],
  ['2403', 'Лебедева Ирина Павловна'],
  ['2404', 'Ким Сергей Андреевич'],
  ['2405', 'Саидов Руслан Тимурович'],
  ['2406', 'Новикова Елена Викторовна'],
  ['2407', 'Орлов Дмитрий Олегович'],
]

export default function Login({ onEnter, onDesk }) {
  const [code, setCode] = useState('')
  const [error, setError] = useState(null)
  const [busy, setBusy] = useState(false)

  const submit = async (event) => {
    event.preventDefault()
    setBusy(true)
    setError(null)
    try {
      onEnter(await api.enter(code.trim()))
    } catch (problem) {
      setError(problem.message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="login">
      <h2>Вход по коду доступа</h2>
      <p className="muted">
        Код с учебной карточки открывает профиль проводника. Это не пароль и не настоящий пропуск.
      </p>
      <form onSubmit={submit}>
        <label>
          Код
          <input
            value={code}
            onChange={(event) => setCode(event.target.value)}
            inputMode="numeric"
            autoComplete="off"
            autoFocus
            placeholder="2401"
          />
        </label>
        {error ? <p className="error">{error}</p> : null}
        <button type="submit" className="primary" disabled={busy || code.trim() === ''}>
          Войти
        </button>
      </form>
      <button type="button" className="login-desk" onClick={onDesk}>Кабинет методиста</button>
      <details>
        <summary>Учебные коды для демонстрации</summary>
        <ul>
          {DEMO_CODES.map(([item, name]) => (
            <li key={item}>
              <strong>{item}</strong>
              <span>{name}</span>
            </li>
          ))}
        </ul>
      </details>
    </section>
  )
}
