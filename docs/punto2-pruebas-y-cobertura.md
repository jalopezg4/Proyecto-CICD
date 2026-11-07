# Punto 2: Pruebas unitarias y cobertura de código

## 1. Pruebas unitarias (pytest + AAA)

Todas las pruebas siguen la estrategia **AAA**:

```python
def test_agregar_gasto_lo_guarda_en_la_lista_interna(service, nuevo_gasto):
    # Arrange: preparar los datos
    datos = nuevo_gasto(descripcion="Comprar pan", monto=5000)
    # Act: ejecutar el método bajo prueba
    gasto = service.agregar_gasto(datos)
    # Assert: verificar el resultado Y el estado interno
    assert gasto in service._gastos
```

**Aislamiento:** cada prueba recibe un `GastoService` nuevo (fixture `service` en
[conftest.py](../backend/tests/conftest.py)). Las pruebas de la API usan
`app.dependency_overrides` para inyectar ese servicio limpio en lugar del global, así
ninguna prueba depende de otra ni de datos previos.

| Archivo | Qué prueba | Pruebas |
|---|---|---|
| [backend/tests/test_service.py](../backend/tests/test_service.py) | Lógica de negocio pura (sin HTTP) | 10 |
| [backend/tests/test_api.py](../backend/tests/test_api.py) | Los endpoints con `TestClient` de FastAPI, incluidas validaciones (422) y 404 | 17 |
| [frontend/tests/test_formato.py](../frontend/tests/test_formato.py) | Formato COP: limpiar símbolos, puntos de miles, tope | 14 |

Cobertura por endpoint/método del backend:

| Método | Caso feliz | Casos de error / borde |
|---|---|---|
| `agregar_gasto` / `POST /gastos` | ✅ guarda en la lista interna, ids consecutivos | ✅ monto 0, negativo, decimal, > 100M, descripción vacía o con solo espacios, categoría inválida; ✅ monto exacto de 100M |
| `listar_gastos` / `GET /gastos` | ✅ orden (más reciente primero) | ✅ lista vacía, filtro por categoría |
| `eliminar_gasto` / `DELETE /gastos/{id}` | ✅ lo quita de la lista interna | ✅ id inexistente (excepción / 404), solo borra el indicado |
| `resumen` / `GET /gastos/resumen` | ✅ total y por categoría | ✅ sin gastos = 0 |

## 2. Investigación: ¿cómo se mide la cobertura en Python?

- **coverage.py** es la herramienta estándar: instrumenta el código y registra qué
  líneas (y ramas) se ejecutan mientras corren las pruebas.
- **pytest-cov** es el plugin que integra coverage.py con pytest: basta con agregar
  `--cov` al comando.
- **Cobertura de líneas vs. de ramas:** la de líneas solo mira si cada línea se ejecutó.
  La de ramas (`branch = True` en `.coveragerc`) además verifica que cada `if` o ciclo se
  haya tomado por **todos** sus caminos (verdadero y falso). Es más exigente y la activamos.

### Implementación

```bash
pip install pytest pytest-cov
cd backend
python -m pytest --cov --cov-report=term-missing --cov-report=html
```

- `--cov-report=term-missing` imprime en consola las líneas sin cubrir.
- `--cov-report=html` genera un reporte navegable en `htmlcov/index.html`, con las líneas
  sin cubrir resaltadas en rojo y las ramas parciales en amarillo.
- La configuración (qué medir, ramas, carpeta del HTML) está en `backend/.coveragerc`.

## 3. Análisis del reporte

### Primera corrida: 98 %

```
Name             Stmts   Miss Branch BrPart  Cover   Missing
app\main.py         27      1      0      0    96%   14
app\models.py       29      0      2      0   100%
app\service.py      30      0      8      1    97%   31->30
TOTAL               86      1     10      1    98%
```

El reporte encontró dos huecos que no eran evidentes a simple vista:

1. **`main.py` línea 14 (`get_service`) sin ejecutar.** En las pruebas reemplazamos esa
   función por un servicio aislado, así que la original nunca corría. Se agregó una prueba
   que verifica que siempre devuelve la misma instancia.
2. **Rama parcial `31->30` en `service.py`.** Es el `for` de `eliminar_gasto`: todas las
   pruebas borraban el *primer* gasto de la lista, así que el ciclo nunca pasaba por un
   gasto que **no** coincidiera para seguir buscando. Ojo: la cobertura de líneas decía
   100 % en ese archivo; solo la **cobertura de ramas** lo detectó. Se agregó
   `test_eliminar_gasto_solo_quita_el_indicado`, que borra el segundo de dos gastos.

### Corrida final: 100 %

```
Name             Stmts   Miss Branch BrPart  Cover
app\main.py         27      0      0      0   100%
app\models.py       29      0      2      0   100%
app\service.py      30      0      8      0   100%
TOTAL               86      0     10      0   100%      (27 passed)

formato.py          17      0      6      0   100%      (14 passed)
```

### Conclusiones

- **100 % de cobertura no significa cero bugs.** Solo dice que cada línea y rama se
  ejecutó al menos una vez, no que se verificó todo lo importante. Por eso las pruebas
  también revisan el **estado interno** (`service._gastos`) y casos borde (monto exacto
  de 100M, descripción con solo espacios).
- **Lo que no se mide aquí:** la interfaz (`frontend/main.py`) y el cliente HTTP
  (`frontend/api_client.py`) se excluyeron de la cobertura unitaria a propósito. Dependen
  de un navegador y de un backend corriendo, así que se validan con la **prueba de
  aceptación E2E** (punto 3).
- Separar la lógica (`service.py`, `formato.py`) de la parte HTTP y de la UI fue lo que
  permitió probarla de forma aislada y rápida (menos de 1 segundo).
