"""Cliente HTTP del frontend: la única pieza que habla con el backend."""
import httpx


class ApiError(Exception):
    pass


class GastosApi:
    def __init__(self, base_url: str) -> None:
        self.base_url = base_url.rstrip("/")

    async def _request(self, method: str, path: str, **kwargs):
        try:
            async with httpx.AsyncClient(base_url=self.base_url, timeout=5) as client:
                respuesta = await client.request(method, path, **kwargs)
        except httpx.HTTPError as error:
            raise ApiError("No se pudo conectar con el backend") from error
        if respuesta.is_error:
            raise ApiError(f"Error {respuesta.status_code}: {respuesta.text}")
        return respuesta.json()

    async def agregar(self, descripcion: str, monto: float, categoria: str) -> dict:
        datos = {"descripcion": descripcion, "monto": monto, "categoria": categoria}
        return await self._request("POST", "/gastos", json=datos)

    async def listar(self, categoria: str | None = None) -> list[dict]:
        params = {"categoria": categoria} if categoria else None
        return await self._request("GET", "/gastos", params=params)

    async def eliminar(self, gasto_id: int) -> dict:
        return await self._request("DELETE", f"/gastos/{gasto_id}")

    async def resumen(self) -> dict:
        return await self._request("GET", "/gastos/resumen")
