"""Pruebas de los endpoints HTTP con el TestClient de FastAPI (AAA).

Cada prueba usa un servicio nuevo gracias al fixture `client` (ver conftest.py).
"""
import pytest

from app.main import get_service
from app.service import GastoService

GASTO_VALIDO = {"descripcion": "Almuerzo", "monto": 18000, "categoria": "Comida"}


def test_get_service_devuelve_siempre_la_misma_instancia():
    # Act
    primero = get_service()
    segundo = get_service()

    # Assert: la app comparte un único servicio (los datos viven en memoria)
    assert isinstance(primero, GastoService)
    assert primero is segundo


def test_health_responde_ok(client):
    # Act
    respuesta = client.get("/health")

    # Assert
    assert respuesta.status_code == 200
    assert respuesta.json() == {"status": "ok"}


# ---------- POST /gastos ----------

def test_post_gastos_crea_el_gasto(client, service):
    # Arrange
    datos = GASTO_VALIDO

    # Act
    respuesta = client.post("/gastos", json=datos)

    # Assert
    assert respuesta.status_code == 201
    cuerpo = respuesta.json()
    assert cuerpo["id"] == 1
    assert cuerpo["descripcion"] == "Almuerzo"
    assert len(service._gastos) == 1


def test_post_gastos_quita_espacios_de_la_descripcion(client):
    # Arrange
    datos = {**GASTO_VALIDO, "descripcion": "   Bus   "}

    # Act
    respuesta = client.post("/gastos", json=datos)

    # Assert
    assert respuesta.json()["descripcion"] == "Bus"


@pytest.mark.parametrize("cambio", [
    {"monto": 0},                   # monto debe ser > 0
    {"monto": -5000},               # sin negativos
    {"monto": 100_000_001},         # tope de cien millones
    {"monto": 1500.5},              # COP no usa decimales
    {"descripcion": ""},            # vacía
    {"descripcion": "    "},        # solo espacios
    {"categoria": "Viajes"},        # categoría que no existe
])
def test_post_gastos_rechaza_datos_invalidos(client, service, cambio):
    # Arrange
    datos = {**GASTO_VALIDO, **cambio}

    # Act
    respuesta = client.post("/gastos", json=datos)

    # Assert
    assert respuesta.status_code == 422
    assert service._gastos == []


def test_post_gastos_acepta_el_monto_maximo(client):
    # Arrange
    datos = {**GASTO_VALIDO, "monto": 100_000_000}

    # Act
    respuesta = client.post("/gastos", json=datos)

    # Assert
    assert respuesta.status_code == 201


# ---------- GET /gastos ----------

def test_get_gastos_lista_los_gastos(client):
    # Arrange
    client.post("/gastos", json=GASTO_VALIDO)
    client.post("/gastos", json={**GASTO_VALIDO, "descripcion": "Bus", "categoria": "Transporte"})

    # Act
    respuesta = client.get("/gastos")

    # Assert
    assert respuesta.status_code == 200
    assert [g["descripcion"] for g in respuesta.json()] == ["Bus", "Almuerzo"]


def test_get_gastos_filtra_por_categoria(client):
    # Arrange
    client.post("/gastos", json=GASTO_VALIDO)
    client.post("/gastos", json={**GASTO_VALIDO, "descripcion": "Bus", "categoria": "Transporte"})

    # Act
    respuesta = client.get("/gastos", params={"categoria": "Transporte"})

    # Assert
    assert [g["descripcion"] for g in respuesta.json()] == ["Bus"]


# ---------- DELETE /gastos/{id} ----------

def test_delete_gastos_elimina_el_gasto(client, service):
    # Arrange
    gasto_id = client.post("/gastos", json=GASTO_VALIDO).json()["id"]

    # Act
    respuesta = client.delete(f"/gastos/{gasto_id}")

    # Assert
    assert respuesta.status_code == 200
    assert service._gastos == []


def test_delete_gastos_inexistente_responde_404(client):
    # Act
    respuesta = client.delete("/gastos/999")

    # Assert
    assert respuesta.status_code == 404


# ---------- GET /gastos/resumen ----------

def test_get_resumen_calcula_totales(client):
    # Arrange
    client.post("/gastos", json={**GASTO_VALIDO, "monto": 20000})
    client.post("/gastos", json={**GASTO_VALIDO, "monto": 5000, "categoria": "Ocio"})

    # Act
    respuesta = client.get("/gastos/resumen")

    # Assert
    assert respuesta.status_code == 200
    assert respuesta.json() == {"total": 25000, "cantidad": 2,
                                "por_categoria": {"Comida": 20000, "Ocio": 5000}}
