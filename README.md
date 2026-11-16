# Gastico 💸

Control de gastos personales. Backend y frontend separados, ambos en Python.

| Pieza | Tecnología | Puerto |
|---|---|---|
| `backend/` | FastAPI (API REST) | 8000 |
| `frontend/` | NiceGUI (UI en Python) | 8080 |
| `e2e/` | Playwright + TypeScript (Locators → Pages → Steps BDD → Specs) | 8001 / 8081 (propios) |

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

Las pruebas levantan solas el backend y el frontend en los puertos 8001/8081:
```bash
npm test
```

Otras opciones: `npm run test:headed` (ver el navegador), `npm run test:ui` (modo paso a paso)
y `npm run report` (reporte HTML con los pasos Dado/Cuando/Entonces).
Detalle: [docs/punto3-prueba-de-aceptacion-e2e.md](docs/punto3-prueba-de-aceptacion-e2e.md)

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
