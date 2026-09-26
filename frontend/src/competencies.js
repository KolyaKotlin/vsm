// Названия компетенций для интерфейса. Коды приходят с бэкенда как есть
// (engine.COMPETENCY_TITLES), человеку показываем русские названия.
export const COMPETENCY_TITLES = {
  conflict: 'Работа с конфликтом',
  medical: 'Медицинский протокол',
  regulations: 'Регламент безопасности',
  service: 'Сервис и эмпатия',
  time_pressure: 'Решение в дефиците времени',
}

export const competencyTitle = (code) => COMPETENCY_TITLES[code] || code
