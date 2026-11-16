# Gastico 💸

Control de gastos personales. Backend y frontend separados, ambos en Python.

| Pieza | Tecnología | Puerto |
|---|---|---|
| `backend/` | FastAPI (API REST) | 8000 |
| `frontend/` | NiceGUI (UI en Python) | 8080 |
| `e2e/` | Playwright + TypeScript (Locators → Pages → Steps BDD → Specs) | 8101 / 8181 (propios) |

## Endpoints

| Método | Ruta | Qué hace |
|---|---|---|
| POST | `/gastos` | Agrega un gasto |
| GET | `/gastos?categoria=` | Lista gastos (filtro opcional) |
| DELETE | `/gastos/{id}` | Elimina un gasto |
| GET | `/gastos/resumen` | Total y totales por categoría |

Documentación interactiva: http://localhost:8000/docs

## Cómo correrla

```bash
python -m venv .venv
.venv\Scripts\pip install -r backend/requirements.txt -r frontend/requirements.txt
```

Terminal 1 (backend):
```bash
cd backend
..\.venv\Scripts\python -m uvicorn app.main:app --port 8000
```

Terminal 2 (frontend):
```bash
cd frontend
..\.venv\Scripts\python main.py
```

Abrir http://localhost:8080

## Pruebas unitarias y cobertura

```bash
cd backend
..\.venv\Scripts\python -m pytest --cov --cov-report=term-missing --cov-report=html
```

```bash
cd frontend
..\.venv\Scripts\python -m pytest --cov --cov-report=term-missing --cov-report=html
```

El reporte HTML queda en `htmlcov/index.html` dentro de cada carpeta.
Análisis completo: [docs/punto2-pruebas-y-cobertura.md](docs/punto2-pruebas-y-cobertura.md)

## Pruebas de aceptación E2E (Playwright + TypeScript)

Requiere Node.js y el `.venv` de Python ya creado (las pruebas lo usan para levantar la app).

Instalación (una sola vez):
```bash
cd e2e
npm install
npx playwright install chromium
```

Las pruebas levantan solas el backend y el frontend en los puertos 8101/8181:
```bash
npm test
```

Otras opciones: `npm run test:headed` (ver el navegador), `npm run test:ui` (modo paso a paso)
y `npm run report` (reporte HTML con los pasos Dado/Cuando/Entonces).
Detalle: [docs/punto3-prueba-de-aceptacion-e2e.md](docs/punto3-prueba-de-aceptacion-e2e.md)

Contra una app que ya está arriba (docker compose o el ALB de staging), sin levantar nada:
```bash
E2E_BASE_URL=http://127.0.0.1:8080 npm test
```

Hay 10 escenarios: los 4 originales y los 6 marcados `automatizar` en
[docs/qa/escenarios-bdd.md](docs/qa/escenarios-bdd.md) (1.1, 2.1, 3.1, 3.3, 3.4 y 7.1).
El 1.1 compara el total antes y después, así que corre al final y solo (proyecto `resumen`).

## Smoke (staging y producción, solo lectura)

Escenarios 8.1 y 8.2: `/health` responde "ok" con la versión desplegada y la página principal
carga. Solo hacen GET, así que se pueden correr en producción.

```bash
pip install pytest
SMOKE_BASE_URL=http://127.0.0.1:8080 SMOKE_VERSION=dev python -m pytest smoke -v
```

`SMOKE_VERSION` es la versión que se acaba de desplegar: `sha-xxxxxxx` en staging y `vX.Y.Z` en producción.

## Prueba de carga (k6, solo staging)

10 usuarios durante 1 minuto pidiendo la página principal y `/health`. Falla si el p95 pasa de
500 ms o si los errores pasan del 1 %. No escribe datos.

```bash
k6 run -e BASE_URL=http://127.0.0.1:8080 k6/carga.js
# sin instalar k6, con Docker (contra compose):
docker run --rm -v "$PWD/k6:/scripts:ro" grafana/k6:1.4.2 run -e BASE_URL=http://host.docker.internal:8080 /scripts/carga.js
```

## Pre-commit

Requisitos antes del primer commit:

- `pip install pre-commit`.
- `cd e2e && npm ci`: los hooks de eslint y prettier son `language: system`, corren con el Node
  local y necesitan `node_modules` ya instalado.
- Terraform instalado, solo cuando exista `infra/` (los hooks `terraform_fmt`/`terraform_validate`
  no hacen nada mientras esa carpeta no tenga archivos `.tf`).

Instalar los hooks (una sola vez):

```bash
pre-commit install
```

Desde ahí, cada `git commit` corre automáticamente ruff (Python) y eslint/prettier (`e2e/`),
además de gitleaks y validaciones básicas de formato, y cada mensaje de commit se valida contra
Conventional Commits (ver [CONTRIBUTING.md](CONTRIBUTING.md)). Para correrlo manualmente sobre todo el repo:

```bash
pre-commit run --all-files
```

## Cómo contribuir

Ramas, formato de commits, Pull Requests y versiones: [CONTRIBUTING.md](CONTRIBUTING.md).
