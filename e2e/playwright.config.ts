import path from 'node:path';
import { defineConfig, devices } from '@playwright/test';

// Puertos propios para las pruebas: no tocan la app de desarrollo (8000 / 8080)
const PUERTO_BACKEND = 8001;
const PUERTO_FRONTEND = 8081;

const RAIZ = path.resolve(__dirname, '..');
const PYTHON = process.platform === 'win32'
  ? path.join(RAIZ, '.venv', 'Scripts', 'python.exe')
  : path.join(RAIZ, '.venv', 'bin', 'python');

export default defineConfig({
  testDir: './specs',
  fullyParallel: true,
  retries: process.env.CI ? 2 : 0,
  reporter: [['list'], ['html', { open: 'never' }]],

  use: {
    baseURL: `http://127.0.0.1:${PUERTO_FRONTEND}`,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },

  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],

  // Paso 1 de la prueba de aceptación: iniciar la aplicación (back + front)
  webServer: [
    {
      name: 'backend',
      command: `"${PYTHON}" -m uvicorn app.main:app --port ${PUERTO_BACKEND}`,
      cwd: path.join(RAIZ, 'backend'),
      url: `http://127.0.0.1:${PUERTO_BACKEND}/health`,
      reuseExistingServer: false,
      timeout: 30_000,
    },
    {
      name: 'frontend',
      command: `"${PYTHON}" main.py`,
      cwd: path.join(RAIZ, 'frontend'),
      url: `http://127.0.0.1:${PUERTO_FRONTEND}`,
      env: {
        GASTICO_API_URL: `http://127.0.0.1:${PUERTO_BACKEND}`,
        GASTICO_FRONT_PORT: String(PUERTO_FRONTEND),
      },
      reuseExistingServer: false,
      timeout: 30_000,
    },
  ],
});
