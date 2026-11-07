"""Pruebas unitarias de la lógica de negocio (GastoService), sin HTTP.

Cada prueba sigue la estrategia AAA: Arrange (preparar), Act (actuar), Assert (verificar).
"""
import pytest

from app.models import Categoria
from app.service import GastoNoEncontrado


# ---------- agregar_gasto ----------

def test_agregar_gasto_lo_guarda_en_la_lista_interna(service, nuevo_gasto):
    # Arrange
    datos = nuevo_gasto(descripcion="Comprar pan", monto=5000)

    # Act
    gasto = service.agregar_gasto(datos)

    # Assert
    assert gasto in service._gastos
    assert len(service._gastos) == 1
    assert gasto.descripcion == "Comprar pan"
    assert gasto.monto == 5000


def test_agregar_gasto_asigna_ids_consecutivos(service, nuevo_gasto):
    # Arrange
    datos = nuevo_gasto()

    # Act
    primero = service.agregar_gasto(datos)
    segundo = service.agregar_gasto(datos)

    # Assert
    assert (primero.id, segundo.id) == (1, 2)


# ---------- listar_gastos ----------

def test_listar_gastos_vacio_devuelve_lista_vacia(service):
    # Arrange: servicio sin gastos

    # Act
    gastos = service.listar_gastos()

    # Assert
    assert gastos == []


def test_listar_gastos_devuelve_los_mas_recientes_primero(service, nuevo_gasto):
    # Arrange
    service.agregar_gasto(nuevo_gasto(descripcion="Primero"))
    service.agregar_gasto(nuevo_gasto(descripcion="Segundo"))

    # Act
    gastos = service.listar_gastos()

    # Assert
    assert [g.descripcion for g in gastos] == ["Segundo", "Primero"]


def test_listar_gastos_filtra_por_categoria(service, nuevo_gasto):
    # Arrange
    service.agregar_gasto(nuevo_gasto(descripcion="Bus", categoria=Categoria.TRANSPORTE))
    service.agregar_gasto(nuevo_gasto(descripcion="Pizza", categoria=Categoria.COMIDA))

    # Act
    gastos = service.listar_gastos(categoria="Transporte")

    # Assert
    assert [g.descripcion for g in gastos] == ["Bus"]


# ---------- eliminar_gasto ----------

def test_eliminar_gasto_lo_quita_de_la_lista_interna(service, nuevo_gasto):
    # Arrange
    gasto = service.agregar_gasto(nuevo_gasto())

    # Act
    eliminado = service.eliminar_gasto(gasto.id)

    # Assert
    assert eliminado == gasto
    assert gasto not in service._gastos


def test_eliminar_gasto_solo_quita_el_indicado(service, nuevo_gasto):
    # Arrange (cubre la rama donde el ciclo pasa por gastos que NO coinciden)
    primero = service.agregar_gasto(nuevo_gasto(descripcion="Primero"))
    segundo = service.agregar_gasto(nuevo_gasto(descripcion="Segundo"))

    # Act
    service.eliminar_gasto(segundo.id)

    # Assert
    assert service._gastos == [primero]


def test_eliminar_gasto_inexistente_lanza_error(service):
    # Arrange: servicio sin gastos

    # Act / Assert
    with pytest.raises(GastoNoEncontrado):
        service.eliminar_gasto(999)


# ---------- resumen ----------

def test_resumen_sin_gastos_es_cero(service):
    # Arrange: servicio sin gastos

    # Act
    resumen = service.resumen()

    # Assert
    assert resumen.total == 0
    assert resumen.cantidad == 0
    assert resumen.por_categoria == {}


def test_resumen_suma_total_y_por_categoria(service, nuevo_gasto):
    # Arrange
    service.agregar_gasto(nuevo_gasto(monto=10000, categoria=Categoria.COMIDA))
    service.agregar_gasto(nuevo_gasto(monto=5000, categoria=Categoria.COMIDA))
    service.agregar_gasto(nuevo_gasto(monto=3000, categoria=Categoria.TRANSPORTE))

    # Act
    resumen = service.resumen()

    # Assert
    assert resumen.total == 18000
    assert resumen.cantidad == 3
    assert resumen.por_categoria == {"Comida": 15000, "Transporte": 3000}
