"""Formato de pesos colombianos (COP): sin decimales y con punto como separador de miles."""

MONTO_MAXIMO = 100_000_000  # cien millones, igual que en el backend


def solo_digitos(texto: str | None) -> str:
    return "".join(c for c in (texto or "") if c.isdigit())


def parsear_cop(texto: str | None) -> int | None:
    """'18.000' -> 18000. Devuelve None si no hay número."""
    digitos = solo_digitos(texto)
    return int(digitos) if digitos else None


def formatear_cop(valor: int | None) -> str:
    """18000 -> '18.000'."""
    if valor is None:
        return ""
    return f"{valor:,}".replace(",", ".")


def normalizar_monto(texto: str | None) -> tuple[str, bool]:
    """Limpia lo que escribió el usuario y le aplica el tope.

    Devuelve (texto_formateado, se_paso_del_tope).
    """
    valor = parsear_cop(texto)
    if valor is None:
        return "", False
    if valor > MONTO_MAXIMO:
        return formatear_cop(MONTO_MAXIMO), True
    return formatear_cop(valor), False
