import { useEffect, useMemo, useRef, useState } from 'react'

// Таймер на экране только показывает время. Решение о том, истекло ли оно,
// принимает сервер: у попытки есть серверный дедлайн, и поздний выбор
// превращается в таймаут даже если браузер считает иначе.
export default function Timer({ deadlineAt, serverTime, totalSeconds, onExpire }) {
  const localDeadline = useMemo(() => {
    const deadline = Date.parse(deadlineAt)
    const serverNow = Date.parse(serverTime)
    // Часы браузера могут расходиться с сервером, поэтому считаем остаток
    // от разницы между дедлайном и временем сервера.
    return Date.now() + (deadline - serverNow)
  }, [deadlineAt, serverTime])

  const [left, setLeft] = useState(() => Math.max(0, Math.round((localDeadline - Date.now()) / 1000)))
  const fired = useRef(false)

  useEffect(() => {
    const tick = () => {
      const remaining = Math.max(0, Math.round((localDeadline - Date.now()) / 1000))
      setLeft(remaining)

      if (remaining === 0 && !fired.current) {
        fired.current = true
        onExpire()
      }
    }

    tick()
    const interval = setInterval(tick, 250)
    return () => clearInterval(interval)
  }, [localDeadline, onExpire])

  const share = totalSeconds ? Math.min(100, (left / totalSeconds) * 100) : 0
  const tone = left <= 5 ? 'bad' : left <= 10 ? 'warn' : 'good'

  return (
    <div className="timer">
      <div className="timer-head">
        <span>Время на решение</span>
        <strong className={tone}>{left} с</strong>
      </div>
      <div className="timer-track">
        <div className={`timer-fill ${tone}`} style={{ width: `${share}%` }} />
      </div>
    </div>
  )
}
