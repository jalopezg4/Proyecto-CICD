import pytest
from fastapi.testclient import TestClient

from app.main import app, get_service
from app.models import Categoria, GastoCreate
from app.service import GastoService


@pytest.fixture
def service() -> GastoService:
    """Un servicio nuevo y vacío para cada prueba (aislamiento)."""
    return GastoService()


@pytest.fixture
def nuevo_gasto():
    """Fábrica de datos válidos para crear gastos."""
    def _crear(descripcion="Almuerzo", monto=18000, categoria=Categoria.COMIDA) -> GastoCreate:
        return GastoCreate(descripcion=descripcion, monto=monto, categoria=categoria)
    return _crear


@pytest.fixture
def client(service):
    """Cliente HTTP de la API que usa un servicio aislado en vez del global."""
    app.dependency_overrides[get_service] = lambda: service
    yield TestClient(app)
    app.dependency_overrides.clear()
