import path from "node:path";
import { defineConfig, devices } from "@playwright/test";

// Puertos propios para las pruebas: no tocan la app de desarrollo (8000 / 8080)
const PUERTO_BACKEND = 8101;
const PUERTO_FRONTEND = 8181;

const RAIZ = path.resolve(__dirname, "..");
const PYTHON =
  process.platform === "win32"
    ? path.join(RAIZ, ".venv", "Scripts", "python.exe")
    : path.join(RAIZ, ".venv", "bin", "python");

// Con E2E_BASE_URL las pruebas van contra una app que ya está arriba (docker compose o el ALB
// de staging) y no levantan nada. Sin ella, levantan su propia copia con el .venv (local).
const URL_EXTERNA = process.env.E2E_BASE_URL;

export default defineConfig({
  testDir: "./specs",
  fullyParallel: true,
  retries: process.env.CI ? 2 : 0,
  reporter: [["list"], ["html", { open: "never" }]],

  use: {
    baseURL: URL_EXTERNA ?? `http://127.0.0.1:${PUERTO_FRONTEND}`,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },

  projects: [
    {
      name: "chromium",
      testIgnore: /resumen\.spec\.ts/,
      use: { ...devices["Desktop Chrome"] },
    },
    // El escenario 1.1 compara el total antes y después; corre al final y de a uno (incluso con
    // --repeat-each), para que ningún otro gasto registrado en paralelo cambie el total en medio.
    // Ojo al leer el reporte: si falla cualquier escenario de "chromium", el 1.1 sale como
    // "skipped" (no se corrió), no como fallido.
    {
      name: "resumen",
      testMatch: /resumen\.spec\.ts/,
      dependencies: ["chromium"],
      workers: 1,
      use: { ...devices["Desktop Chrome"] },
    },
  ],

  // Paso 1 de la prueba de aceptación: iniciar la aplicación (back + front)
  webServer: URL_EXTERNA
    ? undefined
    : [
        {
          name: "backend",
          command: `"${PYTHON}" -m uvicorn app.main:app --port ${PUERTO_BACKEND}`,
          cwd: path.join(RAIZ, "backend"),
          url: `http://127.0.0.1:${PUERTO_BACKEND}/health`,
          reuseExistingServer: false,
          timeout: 30_000,
        },
        {
          name: "frontend",
          command: `"${PYTHON}" main.py`,
          cwd: path.join(RAIZ, "frontend"),
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
