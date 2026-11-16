"""Smoke de Gastico (escenarios 8.1 y 8.2 de docs/qa/escenarios-bdd.md).

Corren después de cada deploy, en staging y en producción. SOLO LECTURA: únicamente hacen GET,
nunca crean ni borran gastos.

Variables de entorno (las dos son obligatorias):
- SMOKE_BASE_URL: URL del frontend (el ALB del ambiente o http://127.0.0.1:8080 con compose).
- SMOKE_VERSION: la versión que se acaba de desplegar (sha-xxxxxxx en staging, vX.Y.Z en producción).
"""

import json
import os
import urllib.error
import urllib.request

import pytest

TIMEOUT_SEGUNDOS = 10


def _variable(nombre: str) -> str:
    valor = os.getenv(nombre, "").strip()
    if not valor:
        pytest.fail(f"Falta la variable de entorno {nombre}", pytrace=False)
    return valor


@pytest.fixture(scope="session")
def base_url() -> str:
    return _variable("SMOKE_BASE_URL").rstrip("/")


@pytest.fixture(scope="session")
def version_esperada() -> str:
    return _variable("SMOKE_VERSION")


def _get(url: str) -> tuple[int, str]:
    try:
        # B310: la URL es la del ambiente (variable del pipeline), no viene de un usuario
        with urllib.request.urlopen(url, timeout=TIMEOUT_SEGUNDOS) as respuesta:  # nosec B310
            return respuesta.status, respuesta.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode("utf-8")


def test_8_1_health_responde_ok_con_la_version_desplegada(base_url, version_esperada):
    # Act
    codigo, cuerpo = _get(f"{base_url}/health")

    # Assert
    assert codigo == 200, f"/health respondió {codigo}: {cuerpo}"
    datos = json.loads(cuerpo)
    assert datos["status"] == "ok"
    assert datos["version"] == version_esperada, f"Está desplegada {datos['version']}, se esperaba {version_esperada}"


def test_8_2_la_pagina_principal_carga(base_url):
    # Act
    codigo, html = _get(f"{base_url}/")

    # Assert
    assert codigo == 200, f"La página principal respondió {codigo}"
    assert "<title>Gastico</title>" in html
    assert "Registrar gasto" in html
