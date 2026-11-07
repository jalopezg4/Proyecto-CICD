"""Lógica de negocio de Gastico. No sabe nada de HTTP, por eso es fácil de probar."""
from datetime import datetime

from .models import Gasto, GastoCreate, Resumen


class GastoNoEncontrado(Exception):
    pass


class GastoService:
    def __init__(self) -> None:
        self._gastos: list[Gasto] = []
        self._siguiente_id = 1

    def agregar_gasto(self, datos: GastoCreate) -> Gasto:
        gasto = Gasto(id=self._siguiente_id, fecha=datetime.now(), **datos.model_dump())
        self._gastos.append(gasto)
        self._siguiente_id += 1
        return gasto

    def listar_gastos(self, categoria: str | None = None) -> list[Gasto]:
        gastos = self._gastos
        if categoria:
            gastos = [g for g in gastos if g.categoria.value == categoria]
        # Los más recientes primero
        return sorted(gastos, key=lambda g: g.id, reverse=True)

    def eliminar_gasto(self, gasto_id: int) -> Gasto:
        for gasto in self._gastos:
            if gasto.id == gasto_id:
                self._gastos.remove(gasto)
                return gasto
        raise GastoNoEncontrado(f"No existe un gasto con id {gasto_id}")

    def resumen(self) -> Resumen:
        por_categoria: dict[str, float] = {}
        for gasto in self._gastos:
            nombre = gasto.categoria.value
            por_categoria[nombre] = por_categoria.get(nombre, 0) + gasto.monto
        return Resumen(
            total=sum(g.monto for g in self._gastos),
            cantidad=len(self._gastos),
            por_categoria=por_categoria,
        )
