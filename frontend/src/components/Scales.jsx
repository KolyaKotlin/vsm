const scaleTone = (value) => {
  if (value >= 70) return 'good'
  if (value >= 45) return 'warn'
  return 'bad'
}

const formatDelta = (delta) => (delta > 0 ? `+${delta}` : `${delta}`)

function Scale({ label, hint, value, delta }) {
  return (
    <div className="scale">
      <div className="scale-head">
        <span className="scale-label">{label}</span>
        <span className="scale-value">
          {value}
          {delta ? <em className={delta > 0 ? 'delta up' : 'delta down'}>{formatDelta(delta)}</em> : null}
        </span>
      </div>
      <div className="scale-track">
        <div className={`scale-fill ${scaleTone(value)}`} style={{ width: `${value}%` }} />
      </div>
      <p className="scale-hint">{hint}</p>
    </div>
  )
}

export default function Scales({ loyalty, safety, lastStep }) {
  return (
    <div className="scales">
      <Scale
        label="Лояльность пассажира"
        hint="Как пассажир воспринимает вашу помощь"
        value={loyalty}
        delta={lastStep?.loyalty_delta}
      />
      <Scale
        label="Рейтинг безопасности"
        hint="Соблюдение регламента и безопасность на борту"
        value={safety}
        delta={lastStep?.safety_delta}
      />
    </div>
  )
}
