from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field, field_validator


class Categoria(str, Enum):
    COMIDA = "Comida"
    TRANSPORTE = "Transporte"
    HOGAR = "Hogar"
    OCIO = "Ocio"
    SALUD = "Salud"
    OTROS = "Otros"


MONTO_MAXIMO = 100_000_000  # cien millones de pesos


class GastoCreate(BaseModel):
    descripcion: str = Field(min_length=1, max_length=100)
    monto: int = Field(gt=0, le=MONTO_MAXIMO)  # COP no usa decimales
    categoria: Categoria = Categoria.OTROS

    @field_validator("descripcion")
    @classmethod
    def descripcion_no_vacia(cls, valor: str) -> str:
        valor = valor.strip()
        if not valor:
            raise ValueError("La descripción no puede estar vacía")
        return valor


class Gasto(GastoCreate):
    id: int
    fecha: datetime


class Resumen(BaseModel):
    total: float
    cantidad: int
    por_categoria: dict[str, float]
