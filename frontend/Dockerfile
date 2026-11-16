# Paso 5 del plan: imagen del frontend (NiceGUI), detrás del ALB con sticky sessions.
FROM python:3.13-slim AS base
# Aplica los parches de seguridad de Debian publicados después de la imagen base
# (Trivy en el CI falla si quedan vulnerabilidades HIGH/CRITICAL con arreglo disponible).
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

FROM base AS builder
WORKDIR /app
# Solo dependencias de ejecución, con versiones fijas y verificadas por hash
COPY requirements.txt .
RUN pip install --no-cache-dir --user --require-hashes --only-binary=:all: -r requirements.txt

FROM base AS runtime
# pip solo hace falta para instalar (etapa builder); en la imagen final sobra y trae librerías
# vendorizadas que Trivy reporta como vulnerables.
RUN python -m pip uninstall -y pip \
    && groupadd --system app && useradd --system --gid app --no-create-home app
WORKDIR /app
COPY --from=builder --chown=app:app /root/.local /home/app/.local
COPY --chown=app:app main.py api_client.py formato.py ./
COPY --chown=app:app static ./static
ENV PATH=/home/app/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

USER app
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health/live')" || exit 1

CMD ["python", "main.py"]
