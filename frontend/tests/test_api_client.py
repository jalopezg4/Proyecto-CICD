"""Pruebas de componente del cliente HTTP del frontend (api_client.py).

El backend se simula con respx: no hace falta levantarlo. Así se prueba el contrato con la API
(rutas, métodos, cuerpo y manejo de errores) sin red.
"""

import httpx
import pytest
import respx
from api_client import ApiError, GastosApi

BASE = "http://backend:8000"


@pytest.fixture
async def api():
    cliente = GastosApi(BASE + "/")  # la barra final se debe ignorar
    yield cliente
    await cliente.cerrar()


@pytest.mark.anyio
@respx.mock
async def test_agregar_envia_post_con_el_gasto(api):
    # Arrange
    ruta = respx.post(f"{BASE}/gastos").mock(return_value=httpx.Response(201, json={"id": 1}))

    # Act
    respuesta = await api.agregar("Pan", 5000, "Comida")

    # Assert
    assert respuesta == {"id": 1}
    assert ruta.called
    assert ruta.calls.last.request.read() == b'{"descripcion":"Pan","monto":5000,"categoria":"Comida"}'


@pytest.mark.anyio
@respx.mock
async def test_listar_sin_categoria_no_envia_filtro(api):
    # Arrange
    ruta = respx.get(f"{BASE}/gastos").mock(return_value=httpx.Response(200, json=[]))

    # Act
    respuesta = await api.listar()

    # Assert
    assert respuesta == []
    assert "categoria" not in str(ruta.calls.last.request.url)


@pytest.mark.anyio
@respx.mock
async def test_listar_con_categoria_envia_el_filtro(api):
    # Arrange
    ruta = respx.get(f"{BASE}/gastos", params={"categoria": "Ocio"}).mock(return_value=httpx.Response(200, json=[]))

    # Act
    await api.listar("Ocio")

    # Assert
    assert ruta.called


@pytest.mark.anyio
@respx.mock
async def test_eliminar_resumen_y_health_usan_sus_rutas(api):
    # Arrange
    eliminar = respx.delete(f"{BASE}/gastos/7").mock(return_value=httpx.Response(200, json={"id": 7}))
    resumen = respx.get(f"{BASE}/gastos/resumen").mock(return_value=httpx.Response(200, json={"total": 0}))
    salud = respx.get(f"{BASE}/health").mock(return_value=httpx.Response(200, json={"status": "ok"}))

    # Act
    await api.eliminar(7)
    await api.resumen()
    await api.health()

    # Assert
    assert eliminar.called and resumen.called and salud.called


@pytest.mark.anyio
@respx.mock
async def test_un_error_http_del_backend_se_convierte_en_api_error(api):
    # Arrange
    respx.delete(f"{BASE}/gastos/99").mock(return_value=httpx.Response(404, text="no existe"))

    # Act / Assert
    with pytest.raises(ApiError, match="Error 404"):
        await api.eliminar(99)


@pytest.mark.anyio
@respx.mock
async def test_si_el_backend_no_responde_se_lanza_api_error(api):
    # Arrange
    respx.get(f"{BASE}/health").mock(side_effect=httpx.ConnectError("caído"))

    # Act / Assert
    with pytest.raises(ApiError, match="No se pudo conectar"):
        await api.health()


@pytest.mark.anyio
@respx.mock
async def test_reutiliza_un_solo_cliente_y_cerrar_lo_libera(api):
    # Arrange
    respx.get(f"{BASE}/health").mock(return_value=httpx.Response(200, json={"status": "ok"}))

    # Act
    await api.health()
    primero = api._client
    await api.health()

    # Assert
    assert api._client is primero
    await api.cerrar()
    assert api._client is None
    await api.cerrar()  # cerrar dos veces no falla


@pytest.fixture
def anyio_backend():
    return "asyncio"
