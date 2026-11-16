# Escenarios BDD nuevos de Gastico

Paso 4 del plan (Squad Producto y Calidad). Aquí se describe, en lenguaje natural, **qué debe hacer
la app desde el punto de vista del usuario**. No es código: es el contrato que después se convierte
en pruebas de Playwright (paso 6) y se revisa a mano en staging (paso 10).

## Cómo leer este documento

Cada escenario sigue la misma forma que ya usan las pruebas E2E del proyecto:

- **Dado** = el contexto inicial (lo que ya pasó antes).
- **Cuando** = la acción que hace el usuario.
- **Entonces** = lo que el usuario debe ver.

Cada escenario tiene una etiqueta que dice qué hacer con él:

| Etiqueta | Significa |
|---|---|
| `automatizar` | Se convierte en prueba de Playwright en el paso 6 |
| `manual` | Lo revisa una persona en staging (paso 10) con el [checklist de QA](checklist-qa.md) |
| `smoke` | Prueba rápida de **solo lectura** para producción (paso 6 y paso 12) |

Y un campo **Corre en**: `compose` (CI, contenedores locales), `staging` o `producción`.

> Regla de oro: en **producción nunca se escribe nada**. Solo se pueden usar escenarios `smoke`.

---

## 0. Lo que ya está cubierto (no repetir)

Estos 4 escenarios ya existen en `e2e/specs/registro-gastos.spec.ts` y corren en compose y en staging:

| # | Escenario |
|---|---|
| 0.1 | El usuario registra "Comprar pan" y lo ve en la lista |
| 0.2 | El monto ignora símbolos y se muestra con puntos de miles |
| 0.3 | El botón Agregar solo se habilita con el formulario completo |
| 0.4 | El usuario elimina un gasto y lo recupera con Deshacer |

---

## 1. Funcionalidad: Resumen de gastos

### 1.1 El total y la cantidad suben al registrar un gasto

**Etiqueta:** `automatizar` · **Corre en:** compose y staging

- **Dado** que el usuario abre Gastico y anota el total y la cantidad que muestra el resumen
- **Cuando** registra el gasto "Almuerzo" de $ 18.000 en Comida
- **Entonces** el total sube exactamente $ 18.000
- **Y** la cantidad de gastos sube en 1

> Ojo: el backend guarda en memoria y lo comparten todas las pruebas. Por eso el escenario compara
> contra el total que había **antes**, no contra un número fijo.

### 1.2 El resumen muestra cuánto se gastó en cada categoría

**Etiqueta:** `manual` · **Corre en:** staging

- **Dado** que el usuario registró un gasto de $ 12.000 en Transporte
- **Cuando** mira la tarjeta "¿En qué se va tu plata?"
- **Entonces** ve una fila "Transporte" con su monto y su porcentaje del total

---

## 2. Funcionalidad: Filtrar por categoría

### 2.1 Tocar una categoría deja solo los gastos de esa categoría

**Etiqueta:** `automatizar` · **Corre en:** compose y staging

- **Dado** que el usuario registró un gasto de Comida y uno de Ocio
- **Cuando** toca "Ocio" en el filtro de Movimientos
- **Entonces** ve el gasto de Ocio en la lista
- **Y** ya no ve el gasto de Comida

### 2.2 Tocar otra vez el filtro activo lo quita

**Etiqueta:** `manual` · **Corre en:** staging

- **Dado** que el usuario tiene activo el filtro "Ocio"
- **Cuando** toca "Ocio" otra vez (o toca "Todas")
- **Entonces** vuelve a ver los gastos de todas las categorías

### 2.3 Una categoría sin gastos muestra un mensaje amable

**Etiqueta:** `manual` · **Corre en:** staging, justo después de un despliegue

- **Dado** que no hay gastos de Salud
- **Cuando** el usuario toca "Salud" en el filtro
- **Entonces** ve el mensaje "No tienes gastos en Salud"
- **Y** ve un botón "Ver todos" que lo devuelve a la lista completa

> No se automatiza porque otras pruebas pueden haber creado gastos de Salud en el mismo ambiente.

---

## 3. Funcionalidad: Validaciones del formulario

### 3.1 Una descripción con solo espacios no permite agregar

**Etiqueta:** `automatizar` · **Corre en:** compose y staging

- **Dado** que el usuario abre Gastico
- **Cuando** escribe un monto de 5000 y una descripción que son solo espacios
- **Entonces** el botón "Agregar gasto" sigue deshabilitado

### 3.2 Un monto en cero no permite agregar

**Etiqueta:** `manual` · **Corre en:** staging

- **Dado** que el usuario abre Gastico
- **Cuando** escribe un monto de 0 y una descripción válida
- **Entonces** el botón "Agregar gasto" sigue deshabilitado

### 3.3 El monto máximo se limita a cien millones

**Etiqueta:** `automatizar` · **Corre en:** compose y staging

- **Dado** que el usuario abre Gastico
- **Cuando** escribe un monto de 150000000
- **Entonces** el campo muestra "100.000.000"
- **Y** aparece el aviso "El monto máximo es $ 100.000.000"

### 3.4 Presionar Enter registra el gasto

**Etiqueta:** `automatizar` · **Corre en:** compose y staging

- **Dado** que el usuario llenó el monto, la descripción y la categoría
- **Cuando** presiona Enter estando en la descripción
- **Entonces** ve el gasto en la lista
- **Y** el formulario queda limpio

---

## 4. Funcionalidad: Vista previa del gasto

### 4.1 La vista previa sigue lo que el usuario va eligiendo

**Etiqueta:** `manual` · **Corre en:** staging

- **Dado** que el usuario abre Gastico sin escribir nada
- **Entonces** ve "Escribe cuánto gastaste para empezar"
- **Cuando** escribe un monto de 5000
- **Entonces** ve "Vas a registrar $ 5.000 en Comida" (Comida es la categoría por defecto)
- **Cuando** elige la categoría Ocio
- **Entonces** la vista previa dice "en Ocio"

---

## 5. Funcionalidad: Deshacer eliminación

### 5.1 La barra de Deshacer desaparece sola a los 6 segundos

**Etiqueta:** `manual` · **Corre en:** staging

- **Dado** que el usuario eliminó un gasto
- **Cuando** pasan 6 segundos sin presionar nada
- **Entonces** la barra de Deshacer desaparece
- **Y** el gasto sigue eliminado

> Es manual porque depende del tiempo y volvería lenta y frágil la prueba automática.

---

## 6. Funcionalidad: Primer uso

### 6.1 Sin gastos, la app invita a registrar el primero

**Etiqueta:** `manual` · **Corre en:** staging, justo después de un despliegue

- **Dado** que el ambiente se acaba de desplegar y no tiene gastos
- **Cuando** el usuario abre Gastico
- **Entonces** ve "Aún no registras gastos"
- **Y** ve el botón "Registrar mi primer gasto", que lleva el cursor al campo del monto
- **Y** el resumen dice "Cuando registres gastos verás aquí en qué se te va el dinero."

> Es una buena revisión para confirmar que un despliegue nuevo arranca limpio (los datos viven en
> memoria y se reinician en cada despliegue; es la limitación conocida del proyecto).

---

## 7. Funcionalidad: Los datos viven en el servidor, no en el navegador

### 7.1 Los gastos siguen ahí después de recargar la página

**Etiqueta:** `automatizar` · **Corre en:** compose y staging

- **Dado** que el usuario registró el gasto "Taxi" de $ 12.000 en Transporte
- **Cuando** recarga la página
- **Entonces** sigue viendo "Taxi" en la lista con $ 12.000

> En staging esto prueba más de lo que parece: la página pasa por el ALB (con sticky sessions y
> WebSocket) hasta el frontend, y el frontend llega al backend por Service Connect.

---

## 8. Funcionalidad: Salud del sistema (smoke, solo lectura)

Dependen de que el paso 5 deje listo `/health` con `status` y `version` en el frontend y en el backend.
Este es el contrato que el paso 5 implementa y que el smoke verifica:

| Situación | Código HTTP | Respuesta de `/health` del frontend |
|---|---|---|
| Todo bien | 200 | `{"status": "ok", "version": "<versión>"}` |
| El backend no responde | 503 | `{"status": "degraded", "backend": "down"}` |

La `<versión>` es el mismo tag de la imagen en ECR y depende del ambiente:

| Ambiente | Qué versión informa `/health` | Ejemplo |
|---|---|---|
| Staging | El commit, porque en staging no hay tag | `sha-1a2b3c4` |
| Producción | El tag, exactamente igual y **con la `v`** | `v1.0.0` |

### 8.1 El sistema responde con la versión correcta

**Etiqueta:** `smoke` · **Corre en:** staging y producción

- **Dado** que se acaba de desplegar una versión: el commit `sha-xxxxxxx` en staging o el tag `vX.Y.Z` en producción
- **Cuando** se consulta `/health` del frontend
- **Entonces** responde con código 200 y estado "ok"
- **Y** la versión que informa es exactamente la desplegada: `sha-xxxxxxx` en staging y `vX.Y.Z` (con la `v`) en producción

### 8.2 La página principal carga

**Etiqueta:** `smoke` · **Corre en:** staging y producción

- **Dado** que la versión está desplegada
- **Cuando** el usuario abre la página principal
- **Entonces** ve el título "Gastico" y el formulario "Registrar gasto"
- **Y** no se registró ni se borró ningún gasto durante la prueba

### 8.3 El `/health` del frontend avisa si el backend no responde

**Etiqueta:** `manual` · **Corre en:** staging

- **Dado** que el frontend está arriba pero el servicio del backend está en 0 tareas
- **Cuando** se consulta `/health` del frontend
- **Entonces** responde con código **503**
- **Y** el cuerpo es exactamente `{"status": "degraded", "backend": "down"}`
- **Cuando** el servicio del backend vuelve a 1 tarea
- **Entonces** `/health` vuelve a responder 200 con estado "ok"

> Es manual porque hay que tumbar el backend a propósito. Se hace una sola vez y **solo en staging**.
> Cómo tumbarlo sin romper nada: bajar el servicio del backend de staging a 0 tareas en ECS (desired
> count = 0), hacer la prueba y después volverlo a 1. No se borra ni se cambia nada más. Mientras el
> backend está en 0, el ALB puede marcar el frontend como "unhealthy": es lo esperado. Al volver a 1,
> todo debe recuperarse solo. Los gastos que había se pierden, porque viven en memoria.

---

## Resumen: qué se hace con cada escenario

| # | Escenario | Etiqueta | Corre en |
|---|---|---|---|
| 1.1 | Total y cantidad suben al registrar | `automatizar` | compose, staging |
| 1.2 | Resumen por categoría | `manual` | staging |
| 2.1 | Filtro deja solo una categoría | `automatizar` | compose, staging |
| 2.2 | Quitar el filtro activo | `manual` | staging |
| 2.3 | Categoría sin gastos | `manual` | staging |
| 3.1 | Descripción solo con espacios | `automatizar` | compose, staging |
| 3.2 | Monto en cero | `manual` | staging |
| 3.3 | Monto máximo de cien millones | `automatizar` | compose, staging |
| 3.4 | Enter registra el gasto | `automatizar` | compose, staging |
| 4.1 | Vista previa | `manual` | staging |
| 5.1 | Deshacer desaparece a los 6 s | `manual` | staging |
| 6.1 | Primer uso | `manual` | staging |
| 7.1 | Los gastos sobreviven a recargar | `automatizar` | compose, staging |
| 8.1 | `/health` con la versión correcta | `smoke` | staging, producción |
| 8.2 | La página principal carga | `smoke` | staging, producción |
| 8.3 | `/health` avisa si el backend falla | `manual` | staging |

Total: **16 escenarios nuevos**. Se automatizan 6 en el paso 6, más 2 de smoke. Los 4 de la sección 0 se
mantienen. Los demás los revisa una persona con el checklist.

---

## Notas para quien haga el paso 6 (Playwright, smoke y k6)

Cosas que se vieron al leer el código y que conviene saber antes de automatizar:

1. **Faltan `data-testid` en algunos elementos.** Existen para el formulario, la lista, el total, la
   cantidad, el estado vacío y la barra de Deshacer. **No existen** en los chips del filtro de
   Movimientos (solo el contenedor `filtro-categoria`), en las filas del resumen por categoría ni en
   las notificaciones (por ejemplo, el aviso del monto máximo). Para los escenarios 2.1 y 3.3 hay
   que pedirle al Squad Plataforma que los agregue en `frontend/main.py`, o usar el texto visible.
2. **Datos compartidos.** Todas las pruebas comparten el mismo backend en memoria. Seguir usando
   `nuevoGasto(...)` (sufijo aleatorio) y comparar valores **relativos** (antes y después), como en 1.1.
3. **Los escenarios nuevos van en los mismos archivos de siempre:** pasos nuevos en `dado.steps.ts`,
   `cuando.steps.ts` y `entonces.steps.ts`, y el escenario en `specs/`. Los `expect` solo en `Entonces`.
4. **Producción solo recibe los smoke (8.1 y 8.2).** Ningún escenario que cree o borre gastos puede
   apuntar a producción.
