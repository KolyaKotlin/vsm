import { useEffect, useState } from 'react'

// Загрузка данных с отменой: если экран сменился, ответ старого запроса
// не должен перезаписывать состояние нового.
export function useApiData(loader, deps = []) {
  const [data, setData] = useState(null)
  const [error, setError] = useState(null)

  useEffect(() => {
    let active = true
    setError(null)

    loader()
      .then((result) => active && setData(result))
      .catch((problem) => active && setError(problem.message))

    return () => {
      active = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps)

  return { data, error }
}
