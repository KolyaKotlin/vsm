import { api } from '../api.js'
import { competencyTitle } from '../competencies.js'
import { useApiData } from '../useApiData.js'

export default function ScenarioList({ employeeId, onStart, refreshKey }) {
  const { data: scenarios, error } = useApiData(() => api.scenarios(), [])
  const { data: history } = useApiData(() => api.attempts(employeeId), [employeeId, refreshKey])

  if (error) return <p className="error">{error}</p>
  if (!scenarios) return <p className="muted">Загрузка сценариев…</p>

  const finishedByScenario = (history || [])
    .filter((item) => item.status === 'finished')
    .reduce((accumulator, item) => {
      const current = accumulator[item.scenario_id]
      if (!current || (item.passed && !current.passed)) accumulator[item.scenario_id] = item
      return accumulator
    }, {})

  return (
    <section>
      <h2>Рабочие ситуации</h2>
      <p className="muted section-hint">
        В каждой ситуации несколько вариантов развития. Время на решение ограничено, а последствия
        видны сразу на двух шкалах.
      </p>

      <div className="cards">
        {scenarios.map((scenario) => {
          const best = finishedByScenario[scenario.id]

          return (
            <article className="card scenario" key={scenario.id}>
              <header>
                <h3>{scenario.title}</h3>
                <span className="tag">{scenario.service_class}</span>
              </header>
              <p>{scenario.summary}</p>
              <p className="muted">
                {scenario.car} · основная компетенция: {competencyTitle(scenario.primary_competency)}
              </p>

              {best ? (
                <p className={`result ${best.passed ? 'passed' : 'failed'}`}>
                  {best.passed ? 'Закрыт' : 'Не сдан'}: лояльность {best.loyalty}, безопасность {best.safety}
                </p>
              ) : (
                <p className="muted">Ещё не проходили</p>
              )}

              <button type="button" className="primary" onClick={() => onStart(scenario.id)}>
                {best ? 'Пройти снова' : 'Начать смену'}
              </button>
            </article>
          )
        })}
      </div>
    </section>
  )
}
