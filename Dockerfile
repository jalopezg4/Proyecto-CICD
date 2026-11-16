# Imágenes de Gastico: un solo Dockerfile con una etapa base compartida y un target por servicio.
#   docker build --target backend  -t gastico-backend  .
#   docker build --target frontend -t gastico-frontend .
# Así el endurecimiento (parches del sistema, sin pip, usuario no root) vive en un solo lugar y las
# dos imágenes no se pueden desincronizar.

# --- Base común: Python 3.13 con los parches de seguridad de Debian ---
FROM python:3.13-slim AS base
# Aplica los parches publicados después de la imagen base
# (Trivy en el CI falla si quedan vulnerabilidades HIGH/CRITICAL con arreglo disponible).
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# --- Base de ejecución común: sin pip y con usuario no root ---
FROM base AS runtime-base
# pip solo hace falta para instalar (etapas builder); en la imagen final sobra y trae librerías
# vendorizadas que Trivy reporta como vulnerables.
RUN python -m pip uninstall -y pip \
    && groupadd --system app && useradd --system --gid app --no-create-home app
WORKDIR /app
ENV PATH=/home/app/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# --- Dependencias de ejecución (versiones fijas y verificadas por hash, sin pytest) ---
FROM base AS builder-backend
WORKDIR /build
COPY backend/requirements.txt .
RUN pip install --no-cache-dir --user --require-hashes --only-binary=:all: -r requirements.txt

FROM base AS builder-frontend
WORKDIR /build
COPY frontend/requirements.txt .
RUN pip install --no-cache-dir --user --require-hashes --only-binary=:all: -r requirements.txt

# --- Backend: API FastAPI, privada y sin IP pública en AWS ---
FROM runtime-base AS backend
COPY --from=builder-backend --chown=app:app /root/.local /home/app/.local
COPY --chown=app:app backend/app ./app
USER app
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')" || exit 1
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

# --- Frontend: NiceGUI, detrás del ALB con sticky sessions ---
FROM runtime-base AS frontend
COPY --from=builder-frontend --chown=app:app /root/.local /home/app/.local
COPY --chown=app:app frontend/main.py frontend/api_client.py frontend/formato.py ./
COPY --chown=app:app frontend/static ./static
USER app
EXPOSE 8080
# Liveness: /health/live no depende del backend (ver PR #5)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health/live')" || exit 1
CMD ["python", "main.py"]
