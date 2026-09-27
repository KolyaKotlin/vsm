import { useState } from 'react'
import { competencyTitle } from '../competencies.js'
import { qualityLabel, qualityOf } from './StepFeedback.jsx'

const SHORT_QUALITY = {
  optimal: 'Оптимально',
  acceptable: 'Допустимо',
  harmful: 'Ошибка',
  timeout: 'Время вышло',
}

const formatDelta = (delta) => (delta > 0 ? `+${delta}` : `${delta}`)

function Hint({ label, children }) {
  const [open, setOpen] = useState(false)

  return (
    <span className="hint">
      <button
        type="button"
        className="hint-btn"
        aria-expanded={open}
        aria-label={label}
        onClick={() => setOpen((value) => !value)}
      >
        ?
      </button>
      {open ? <span className="hint-pop">{children}</span> : null}
    </span>
  )
}

function StepRow({ step, index }) {
  const [open, setOpen] = useState(false)
  const tone = qualityOf(step)
  const gains = Object.entries(step.competency_gain || {})

  return (
    <li className={open ? `step open ${tone}` : `step ${tone}`}>
      <button
        type="button"
        className="step-summary"
        aria-expanded={open}
        onClick={() => setOpen((value) => !value)}
      >
        <span className="step-num">{index + 1}</span>
        <span className={`step-mark ${tone}`}>{SHORT_QUALITY[tone] || qualityLabel(step)}</span>
        <span className="step-choice">{step.choice_text}</span>
        <span className="step-deltas">
          <em className={step.loyalty_delta >= 0 ? 'up' : 'down'}>Л {formatDelta(step.loyalty_delta)}</em>
          <em className={step.safety_delta >= 0 ? 'up' : 'down'}>Б {formatDelta(step.safety_delta)}</em>
        </span>
        <span className="chevron" aria-hidden="true" />
      </button>

      <div className="step-more" aria-hidden={open ? undefined : true}>
        <div>
          <p className="step-why">{step.debrief}</p>
          {step.branch_note ? <p className="feedback-branch">{step.branch_note}</p> : null}
          <p className="step-context">{step.narration}</p>
          {step.passenger ? <p className="step-context">Пассажир: {step.passenger}</p> : null}
          {gains.length > 0 ? (
            <p className="step-context">
              {gains.map(([code, points]) => `${competencyTitle(code)} +${points}`).join(' · ')}
            </p>
          ) : null}
        </div>
      </div>
    </li>
  )
}

export default function Debrief({ debrief, onRestart, onLeave }) {
  const clean = debrief.timeouts === 0 && debrief.harmful_choices === 0

  return (
    <section className="debrief">
      <header className={`verdict ${debrief.passed ? 'passed' : 'failed'}`}>
        <div className="verdict-kicker">
          <span>{debrief.passed ? 'Сдан' : 'Не сдан'}</span>
          <Hint label="Как ставится итог">
            Сдано, если лояльность не ниже 60, безопасность не ниже 70 и не было
            критического нарушения регламента.
          </Hint>
        </div>
        <h2>{debrief.verdict}</h2>
        <div className="verdict-metrics">
          <div>
            <strong>{debrief.loyalty}</strong>
            <span>Лояльность</span>
          </div>
          <div>
            <strong>{debrief.safety}</strong>
            <span>Безопасность</span>
          </div>
          <div>
            <strong>+{debrief.xp_awarded}</strong>
            <span>Опыт</span>
          </div>
        </div>
      </header>

      <p className={clean ? 'debrief-note' : 'debrief-note warn'}>
        {clean
          ? 'Без ошибок и без опозданий'
          : `Ошибочных решений ${debrief.harmful_choices} · истёкших таймеров ${debrief.timeouts}`}
        {debrief.competency_gain.length > 0
          ? ` · ${debrief.competency_gain.map((item) => `${item.title} +${item.points}`).join(' · ')}`
          : ''}
      </p>

      {debrief.unlocked_achievements.length > 0 ? (
        <ul className="award-list">
          {debrief.unlocked_achievements.map((item) => (
            <li key={item.code}>
              <strong>{item.title}</strong>
              <Hint label={`Что значит достижение «${item.title}»`}>{item.description}</Hint>
            </li>
          ))}
        </ul>
      ) : null}

      <h3 className="path-title">Путь решений</h3>
      <ol className="steps">
        {debrief.steps.map((step, index) => (
          <StepRow key={`${step.node_id}-${index}`} step={step} index={index} />
        ))}
      </ol>

      <div className="row">
        <button type="button" className="primary" onClick={onRestart}>
          Пройти заново
        </button>
        <button type="button" onClick={onLeave}>
          К журналу ситуаций
        </button>
      </div>
    </section>
  )
}
