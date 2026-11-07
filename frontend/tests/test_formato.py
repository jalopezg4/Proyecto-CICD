"""Pruebas unitarias del formato de pesos colombianos del frontend (AAA)."""
import pytest

from formato import MONTO_MAXIMO, formatear_cop, normalizar_monto, parsear_cop, solo_digitos


@pytest.mark.parametrize("entrada, esperado", [
    ("18.000", "18000"),
    ("-+e18000.5", "180005"),
    ("abc", ""),
    (None, ""),
])
def test_solo_digitos_descarta_simbolos(entrada, esperado):
    # Act
    resultado = solo_digitos(entrada)

    # Assert
    assert resultado == esperado


def test_parsear_cop_convierte_texto_con_puntos_a_entero():
    # Arrange
    texto = "1.250.000"

    # Act
    valor = parsear_cop(texto)

    # Assert
    assert valor == 1_250_000


def test_parsear_cop_sin_numeros_devuelve_none():
    # Act / Assert
    assert parsear_cop("") is None


@pytest.mark.parametrize("valor, esperado", [
    (0, "0"),
    (999, "999"),
    (18000, "18.000"),
    (100_000_000, "100.000.000"),
    (None, ""),
])
def test_formatear_cop_pone_puntos_de_miles(valor, esperado):
    # Act
    resultado = formatear_cop(valor)

    # Assert
    assert resultado == esperado


def test_normalizar_monto_limpia_y_formatea():
    # Arrange
    escrito_por_usuario = "-18000+"

    # Act
    texto, se_paso = normalizar_monto(escrito_por_usuario)

    # Assert
    assert texto == "18.000"
    assert se_paso is False


def test_normalizar_monto_aplica_el_tope():
    # Arrange
    demasiado = str(MONTO_MAXIMO + 1)

    # Act
    texto, se_paso = normalizar_monto(demasiado)

    # Assert
    assert texto == "100.000.000"
    assert se_paso is True


def test_normalizar_monto_vacio():
    # Act
    texto, se_paso = normalizar_monto("")

    # Assert
    assert (texto, se_paso) == ("", False)
