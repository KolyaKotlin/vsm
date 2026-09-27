import http from 'node:http'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Запросы к /api уходят на бэкенд: в разработке фронтенд и API работают на
// разных портах, в Docker адрес задаётся переменной VSM_API_URL.
export default defineConfig({
  plugins: [react()],
  server: {
    // Без явного хоста Vite на Windows слушает только IPv6, и обращение к
    // 127.0.0.1:5173 не проходит. В Docker адрес переопределяется переменной.
    host: process.env.VSM_HOST || '127.0.0.1',
    port: 5173,
    proxy: {
      '/api': {
        target: process.env.VSM_API_URL || 'http://127.0.0.1:8000',
        changeOrigin: true,
        // Uvicorn закрывает простаивающее соединение через пять секунд, а пул
        // Node успевает взять его для следующего запроса — это давало пустой
        // ответ 500, хотя сам сервер запрос не видел. Соединение не переиспользуем
        // и явно закрываем его после ответа.
        agent: new http.Agent({ keepAlive: false }),
        configure: (proxy) => {
          proxy.on('proxyReq', (proxyReq) => {
            proxyReq.setHeader('Connection', 'close')
          })
          proxy.on('error', (_err, _req, res) => {
            if (!res || res.headersSent || !res.writeHead) return
            res.writeHead(502, { 'Content-Type': 'application/json' })
            res.end(JSON.stringify({ detail: 'Связь с сервером оборвалась. Повторите ещё раз.' }))
          })
        },
      },
    },
  },
})
