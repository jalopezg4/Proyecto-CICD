# Paso 5 del plan: imagen del backend (API FastAPI), privada y sin IP pública en AWS.
FROM python:3.13-slim AS base

FROM base AS builder
WORKDIR /app
# Solo dependencias de ejecución, con versiones fijas y verificadas por hash (sin pytest ni httpx)
COPY requirements.txt .
RUN pip install --no-cache-dir --user --require-hashes --only-binary=:all: -r requirements.txt

FROM base AS runtime
RUN groupadd --system app && useradd --system --gid app --no-create-home app
WORKDIR /app
COPY --from=builder --chown=app:app /root/.local /home/app/.local
COPY --chown=app:app app ./app
ENV PATH=/home/app/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

USER app
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
