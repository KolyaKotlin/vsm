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
        // Node успевает взять его для следующего запроса — это давало случайные
        // 500 в интерфейсе. Каждый запрос идёт по своему соединению.
        agent: new http.Agent({ keepAlive: false }),
      },
    },
  },
})
