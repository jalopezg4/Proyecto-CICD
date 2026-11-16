import os

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .models import Gasto, GastoCreate, Resumen
from .service import GastoNoEncontrado, GastoService

APP_VERSION = os.getenv("APP_VERSION", "dev")
# En Learner Lab el backend es privado (sin IP pública): solo lo llama el frontend
# desde el servidor, nunca el navegador. El origen por defecto es el frontend local.
ALLOWED_ORIGINS = [
    origen.strip()
    for origen in os.getenv("GASTICO_ALLOWED_ORIGINS", "http://127.0.0.1:8080").split(",")
    if origen.strip()
]
# /docs y /openapi.json quedan apagados en producción (decisión del plan)
ES_PRODUCCION = os.getenv("APP_ENV", "development") == "production"

app = FastAPI(
    title="Gastico API",
    description="Control de gastos personales",
    docs_url=None if ES_PRODUCCION else "/docs",
    redoc_url=None if ES_PRODUCCION else "/redoc",
    openapi_url=None if ES_PRODUCCION else "/openapi.json",
)
app.add_middleware(CORSMiddleware, allow_origins=ALLOWED_ORIGINS, allow_methods=["*"], allow_headers=["*"])

_service = GastoService()


def get_service() -> GastoService:
    return _service


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "version": APP_VERSION}


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
        raise HTTPException(status_code=404, detail=str(error)) from error


@app.get("/gastos/resumen", response_model=Resumen)
def resumen(service: GastoService = Depends(get_service)):
    return service.resumen()
