import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./frontend/src/test/setup.ts'],
    include: ['frontend/src/**/*.{test,spec}.{ts,tsx}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      include: ['frontend/src/**/*.{ts,tsx}'],
      exclude: ['frontend/src/test/**', 'frontend/src/**/*.d.ts'],
      thresholds: {
        statements: 70,
        branches: 70,
        functions: 70,
        lines: 70,
      }
    }
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './frontend/src')
    }
  }
})
