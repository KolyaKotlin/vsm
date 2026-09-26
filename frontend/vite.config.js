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
      },
    },
  },
})
