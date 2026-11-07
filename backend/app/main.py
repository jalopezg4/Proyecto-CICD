from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .models import Gasto, GastoCreate, Resumen
from .service import GastoNoEncontrado, GastoService

app = FastAPI(title="Gastico API", description="Control de gastos personales")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

_service = GastoService()


def get_service() -> GastoService:
    return _service


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/gastos", response_model=Gasto, status_code=201)
def agregar_gasto(datos: GastoCreate, service: GastoService = Depends(get_service)):
    return service.agregar_gasto(datos)


@app.get("/gastos", response_model=list[Gasto])
def listar_gastos(categoria: str | None = None, service: GastoService = Depends(get_service)):
    return service.listar_gastos(categoria)


@app.delete("/gastos/{gasto_id}", response_model=Gasto)
def eliminar_gasto(gasto_id: int, service: GastoService = Depends(get_service)):
    try:
        return service.eliminar_gasto(gasto_id)
    except GastoNoEncontrado as error:
        raise HTTPException(status_code=404, detail=str(error))


@app.get("/gastos/resumen", response_model=Resumen)
def resumen(service: GastoService = Depends(get_service)):
    return service.resumen()
