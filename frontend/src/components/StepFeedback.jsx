import { competencyTitle } from '../competencies.js'

export const QUALITY_LABELS = {
  optimal: 'Оптимальное решение',
  acceptable: 'Допустимое решение',
  harmful: 'Ошибочное решение',
}

export const qualityOf = (step) => (step.timed_out ? 'timeout' : step.quality)

export const qualityLabel = (step) =>
  step.timed_out ? 'Время вышло' : QUALITY_LABELS[step.quality] || step.quality

const formatDelta = (delta) => (delta > 0 ? `+${delta}` : `${delta}`)

// Разбор одного шага: что выбрано, как это сдвинуло шкалы и почему.
export default function StepFeedback({ step, compact = false }) {
  return (
    <article className={`feedback ${qualityOf(step)}`}>
      <header>
        <span className="badge">{qualityLabel(step)}</span>
        <span className="deltas">
          <em className={step.loyalty_delta >= 0 ? 'delta up' : 'delta down'}>
            лояльность {formatDelta(step.loyalty_delta)}
          </em>
          <em className={step.safety_delta >= 0 ? 'delta up' : 'delta down'}>
            безопасность {formatDelta(step.safety_delta)}
          </em>
        </span>
      </header>

      <p className="feedback-choice">{step.choice_text}</p>
      <p className="feedback-debrief">{step.debrief}</p>

      {!compact && Object.keys(step.competency_gain || {}).length > 0 ? (
        <p className="feedback-gain">
          Очки компетенций:{' '}
          {Object.entries(step.competency_gain)
            .map(([code, points]) => `${competencyTitle(code)} +${points}`)
            .join(', ')}
        </p>
      ) : null}
    </article>
  )
}
