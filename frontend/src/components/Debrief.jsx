import StepFeedback from './StepFeedback.jsx'

// Итоговый разбор: вердикт, очки, достижения и путь решений целиком.
export default function Debrief({ debrief, onRestart, onLeave }) {
  return (
    <section className="debrief">
      <header className={`debrief-head ${debrief.passed ? 'passed' : 'failed'}`}>
        <span className="badge">{debrief.passed ? 'Сценарий закрыт' : 'Сценарий не сдан'}</span>
        <h2>{debrief.verdict}</h2>
        <p className="debrief-scales">
          Лояльность {debrief.loyalty} · Безопасность {debrief.safety} · Опыт +{debrief.xp_awarded}
        </p>
      </header>

      {debrief.unlocked_achievements.length > 0 ? (
        <div className="achievements-unlocked">
          <h3>Новые достижения</h3>
          <ul>
            {debrief.unlocked_achievements.map((item) => (
              <li key={item.code}>
                <strong>{item.title}</strong>
                <span>{item.description}</span>
              </li>
            ))}
          </ul>
        </div>
      ) : null}

      <div className="debrief-grid">
        <div className="card">
          <h3>Очки компетенций</h3>
          {debrief.competency_gain.length > 0 ? (
            <ul className="competency-list">
              {debrief.competency_gain.map((item) => (
                <li key={item.competency}>
                  <span>{item.title}</span>
                  <strong>+{item.points}</strong>
                </li>
              ))}
            </ul>
          ) : (
            <p className="muted">За этот проход очки компетенций не начислены.</p>
          )}
        </div>

        <div className="card">
          <h3>Что пошло не так</h3>
          <ul className="competency-list">
            <li>
              <span>Истёкшие таймеры</span>
              <strong>{debrief.timeouts}</strong>
            </li>
            <li>
              <span>Ошибочные решения</span>
              <strong>{debrief.harmful_choices}</strong>
            </li>
          </ul>
        </div>
      </div>

      <h3 className="debrief-path">Путь решений</h3>
      <ol className="steps">
        {debrief.steps.map((step, index) => (
          <li key={`${step.node_id}-${index}`}>
            <p className="step-situation">{step.narration}</p>
            {step.passenger ? <p className="step-passenger">{step.passenger}</p> : null}
            <StepFeedback step={step} />
          </li>
        ))}
      </ol>

      <div className="row">
        <button type="button" className="primary" onClick={onRestart}>
          Пройти заново
        </button>
        <button type="button" onClick={onLeave}>
          К списку сценариев
        </button>
      </div>
    </section>
  )
}
