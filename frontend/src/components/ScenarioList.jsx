import { useMemo, useState } from 'react'
import { api } from '../api.js'
import { COMPETENCY_TITLES, competencyTitle } from '../competencies.js'
import { useApiData } from '../useApiData.js'

const pad = (value) => String(value || 0).padStart(2, '0')

export default function ScenarioList({ employeeId, onStart, refreshKey }) {
  const { data: scenarios, error } = useApiData(() => api.scenarios(), [])
  const { data: history, error: historyError } = useApiData(
    () => api.attempts(employeeId),
    [employeeId, refreshKey],
  )
  const [query, setQuery] = useState('')
  const [competency, setCompetency] = useState('all')

  const finishedByScenario = useMemo(() => {
    return (history || [])
      .filter((item) => item.status === 'finished')
      .reduce((accumulator, item) => {
        const current = accumulator[item.scenario_id]
        if (!current || (item.passed && !current.passed)) accumulator[item.scenario_id] = item
        return accumulator
      }, {})
  }, [history])

  if (error) return <p className="error">{error}</p>
  if (!scenarios) return <p className="muted">Загрузка журнала…</p>

  const needle = query.trim().toLowerCase()
  const visible = scenarios.filter((scenario) => {
    if (competency !== 'all' && scenario.primary_competency !== competency) return false
    if (!needle) return true
    const haystack = `${pad(scenario.number)} ${scenario.title} ${scenario.summary} ${scenario.section} ${scenario.car}`.toLowerCase()
    return haystack.includes(needle)
  })

  const groups = []
  for (const scenario of visible) {
    const title = scenario.section || 'Прочие'
    const last = groups[groups.length - 1]
    if (!last || last.title !== title) groups.push({ title, rows: [scenario] })
    else last.rows.push(scenario)
  }

  return (
    <section>
      <h2>Журнал ситуаций</h2>
      <p className="muted section-hint">
        {scenarios.length} рабочих ситуаций. На решение отведено время. Итог смотрите по двум
        показателям: как ситуацию воспринял пассажир и соблюдён ли регламент.
      </p>

      <div className="toolbar">
        <label>
          Найти
          <input
            type="search"
            value={query}
            placeholder="Номер, тема или вагон"
            onChange={(event) => setQuery(event.target.value)}
          />
        </label>
        <label>
          Компетенция
          <select value={competency} onChange={(event) => setCompetency(event.target.value)}>
            <option value="all">Все</option>
            {Object.entries(COMPETENCY_TITLES)
              .filter(([code]) => code !== 'time_pressure')
              .map(([code, title]) => (
                <option key={code} value={code}>
                  {title}
                </option>
              ))}
          </select>
        </label>
      </div>

      {historyError ? <p className="error">История прохождений недоступна: {historyError}</p> : null}
      {!history && !historyError ? <p className="muted">Смотрим историю прохождений…</p> : null}

      {visible.length === 0 ? (
        <p className="muted">По этому запросу ситуаций нет.</p>
      ) : (
        <div className="register">
          <div className="register-head">
            <span>№</span>
            <span>Ситуация</span>
            <span>Где</span>
            <span>Компетенция</span>
            <span>Итог</span>
          </div>
          {groups.map((group) => (
            <div key={group.title}>
              <h3 className="register-section">{group.title}</h3>
              {group.rows.map((scenario) => {
                const best = history ? finishedByScenario[scenario.id] : null
                return (
                  <button
                    key={scenario.id}
                    type="button"
                    className="register-row"
                    onClick={() => onStart(scenario.id)}
                  >
                    <span className="num">{pad(scenario.number)}</span>
                    <span>
                      <span className="register-title">{scenario.title}</span>
                      <span className="register-summary">{scenario.summary}</span>
                    </span>
                    <span>{scenario.car}</span>
                    <span>{competencyTitle(scenario.primary_competency)}</span>
                    <span className={best ? `result ${best.passed ? 'passed' : 'failed'}` : 'muted'}>
                      {!history ? '…' : best ? (best.passed ? 'Сдан' : 'Не сдан') : 'Не проходили'}
                    </span>
                  </button>
                )
              })}
            </div>
          ))}
        </div>
      )}
    </section>
  )
}
