import { useEffect, useMemo, useRef, useState } from 'react'

// Полоска считается от серверного дедлайна и едет линейно, без скачка раз в секунду.
// Истекло время или нет — по-прежнему решает сервер.
export default function Timer({ deadlineAt, serverTime, totalSeconds, onExpire }) {
  const localDeadline = useMemo(() => {
    const deadline = Date.parse(deadlineAt)
    const serverNow = Date.parse(serverTime)
    return Date.now() + (deadline - serverNow)
  }, [deadlineAt, serverTime])

  const fillRef = useRef(null)
  const fired = useRef(false)
  const [left, setLeft] = useState(() => Math.max(0, Math.ceil((localDeadline - Date.now()) / 1000)))

  useEffect(() => {
    const fill = fillRef.current
    if (!fill || !totalSeconds) return undefined

    const totalMs = totalSeconds * 1000
    const elapsed = Math.min(totalMs, Math.max(0, totalMs - (localDeadline - Date.now())))
    fill.style.animation = 'none'
    void fill.offsetWidth
    fill.style.animation = `timer-drain ${totalMs}ms linear -${elapsed}ms forwards`

    return undefined
  }, [localDeadline, totalSeconds])

  useEffect(() => {
    const tick = () => {
      const seconds = Math.max(0, Math.ceil((localDeadline - Date.now()) / 1000 - 1e-6))
      setLeft(seconds)
    }

    tick()
    const interval = setInterval(tick, 200)
    return () => clearInterval(interval)
  }, [localDeadline])

  useEffect(() => {
    const remaining = Math.max(0, localDeadline - Date.now())
    const timeout = setTimeout(() => {
      if (!fired.current) {
        fired.current = true
        onExpire()
      }
    }, remaining)

    return () => clearTimeout(timeout)
  }, [localDeadline, onExpire])

  const tone = left <= 5 ? 'bad' : left <= 10 ? 'warn' : 'good'

  return (
    <div className={left <= 5 ? 'timer urgent' : 'timer'}>
      <div className="timer-head">
        <span>Время на решение</span>
        <strong className={`timer-left ${tone}`}>{left} с</strong>
      </div>
      <div className="timer-track" aria-hidden="true">
        <div ref={fillRef} className={`timer-fill ${tone}`}>
          <span className="timer-thumb" />
        </div>
      </div>
    </div>
  )
}
