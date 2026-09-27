import Debrief from './Debrief.jsx'
import Scales from './Scales.jsx'
import StepFeedback from './StepFeedback.jsx'
import Timer from './Timer.jsx'

export default function PlayScreen({ attempt, busy, onChoose, onTimeout, onRestart, onLeave }) {
  const { node, last_step: lastStep } = attempt

  if (attempt.finished && attempt.debrief) {
    return <Debrief debrief={attempt.debrief} onRestart={onRestart} onLeave={onLeave} />
  }

  return (
    <section className="play">
      <header className="play-head">
        <div>
          <p className="play-kicker">
            Ситуация {String(attempt.scenario.number).padStart(2, '0')}
            {attempt.scenario.section ? ` · ${attempt.scenario.section}` : ''}
          </p>
          <h2>{attempt.scenario.title}</h2>
          <p className="muted">
            {attempt.scenario.car} · решение {attempt.steps_taken + 1}
          </p>
          {attempt.steps_taken === 0 ? <p className="brief">{attempt.scenario.summary}</p> : null}
        </div>
        <button type="button" onClick={onLeave}>
          Выйти
        </button>
      </header>

      <Scales loyalty={attempt.loyalty} safety={attempt.safety} lastStep={lastStep} />

      {lastStep ? <StepFeedback step={lastStep} compact /> : null}

      <div className="situation">
        <p className="narration">{node.narration}</p>
        {node.passenger ? <blockquote className="passenger">{node.passenger}</blockquote> : null}
      </div>

      {node.deadline_at ? (
        <Timer
          key={node.id}
          deadlineAt={node.deadline_at}
          serverTime={attempt.server_time}
          totalSeconds={node.timer_seconds}
          onExpire={onTimeout}
        />
      ) : null}

      <div className="options">
        {node.options.map((option, index) => (
          <button
            key={option.id}
            type="button"
            className="option"
            disabled={busy}
            onClick={() => onChoose(option.id)}
          >
            <span className="option-index">{index + 1}</span>
            <span>{option.text}</span>
          </button>
        ))}
      </div>
    </section>
  )
}
