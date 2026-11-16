# Punto 3: Prueba de aceptación E2E (Playwright + TypeScript + BDD)

## 1. Investigación: ¿cómo automatizar a un usuario real?

**Pregunta:** ¿cómo escribir una prueba que abra un navegador, interactúe con la app en
ejecución y verifique el resultado en la página?

**Respuesta:** con una herramienta de automatización de navegadores. La prueba de
aceptación **no tiene que estar en el mismo lenguaje que la app**: habla con ella por el
navegador, así que la app está en Python y las E2E en TypeScript.

| | Selenium | Playwright (elegida) |
|---|---|---|
| Lenguajes | Java, Python, C#, JS... | TypeScript/JS (principal), Python, Java, .NET |
| Esperas | Manuales (`WebDriverWait`) | **Automáticas**: espera a que el elemento esté listo antes de actuar |
| Aserciones | `assert` sin reintento | `expect(...)` reintenta hasta que se cumple o se acaba el tiempo |
| Herramientas | Externas | Runner propio, modo UI, trace viewer, reporte HTML |

**¿Por qué TypeScript y no Python?** Playwright existe en ambos, pero TypeScript es su
versión principal: `@playwright/test` trae runner, paralelismo, `webServer` (levanta la
app sola), fixtures, `test.step` para BDD, modo UI y reporte HTML, todo sin plugins.

## 2. Arquitectura: Locators → Pages → Steps (BDD) → Specs

```
e2e/
├── playwright.config.ts        # Levanta backend (8101) y frontend (8181) con webServer
├── data/gastos.data.ts         # Datos de prueba (nuevoGasto con sufijo único)
├── locators/gastos.locators.ts # DÓNDE está cada elemento (data-testid)
├── pages/
│   ├── base.page.ts
│   └── gastos.page.ts          # MÉTODOS de la pantalla, usan los locators
├── steps/
│   ├── dado.steps.ts           # Given  = Arrange
│   ├── cuando.steps.ts         # When   = Act
│   └── entonces.steps.ts       # Then   = Assert (único lugar con expect)
├── fixtures/bdd.fixture.ts     # Inyecta dado / cuando / entonces en los specs
└── specs/registro-gastos.spec.ts  # Solo steps + parámetros
```

| Capa | Responsabilidad | Puede usar | Ejemplo |
|---|---|---|---|
| **Locators** | Ubicar elementos | `page.getByTestId` | `inputMonto`, `botonEliminarDe(descripcion)` |
| **Pages** | Acciones sobre la pantalla | Locators | `escribirMonto()`, `registrarGasto()` |
| **Steps** | Lenguaje de negocio Dado/Cuando/Entonces | Pages (+ `expect` solo en Entonces) | `cuando.registraElGasto(gasto)` |
| **Specs** | El escenario | Solo steps y parámetros | ver abajo |

Cada step se envuelve en `test.step(...)`, así el reporte HTML muestra el escenario
completo en español: *"Dado que el usuario abre Gastico → Cuando registra el gasto... →
Entonces ve... en la lista"*.

## 3. La prueba pedida en la actividad

```ts
test('Escenario: el usuario registra "Comprar pan" y lo ve en la lista', async ({ dado, cuando, entonces }) => {
  const gasto = nuevoGasto('Comprar pan', 5000, 'Comida');

  await dado.queElUsuarioAbreGastico();   // Arrange
  await cuando.registraElGasto(gasto);    // Act
  await entonces.veElGastoEnLaLista(gasto); // Assert
});
```

| Paso de la actividad | Dónde ocurre |
|---|---|
| 1. Inicia la aplicación | `webServer` en `playwright.config.ts` (backend y frontend) |
| 2. Abre un navegador y navega a localhost | Fixture `page` + `dado.queElUsuarioAbreGastico()` |
| 3. Encuentra el campo y el botón "Agregar" | `GastosLocators`: `input-descripcion`, `btn-agregar` |
| 4. Escribe "Comprar pan" y hace clic | `cuando.registraElGasto(gasto)` → `GastosPage.registrarGasto()` |
| 5. Verifica que el texto aparece | `entonces.veElGastoEnLaLista(gasto)` → `expect(item).toBeVisible()` |

### Escenarios adicionales

| Escenario | Qué valida |
|---|---|
| El monto ignora símbolos y se muestra con puntos de miles | Teclear `-+e1250000` deja `1.250.000` |
| El botón Agregar solo se habilita con el formulario completo | Deshabilitado al inicio, habilitado al llenar |
| El usuario elimina un gasto y lo recupera con Deshacer | Eliminar lo quita; "Deshacer" lo devuelve |

## 4. Bugs que encontraron las E2E

Corriendo la suite muchas veces en paralelo (`--repeat-each`), las pruebas encontraron
**dos bugs de la app** que a mano no se veían:

1. **Se perdían teclas en el monto.** Al escribir `30000` rápido, se guardaba `3.000`. El
   formato con puntos lo hacía el servidor: con cada tecla iba y volvía, y la respuesta
   pisaba la tecla que el usuario ya había escrito. **Arreglo:** el formato lo hace ahora
   el navegador con la máscara de Quasar (`mask="###.###.###" reverse-fill-mask`). El
   servidor solo aplica el tope de 100M.
2. **Se perdían clics justo después de agregar.** El formulario se limpiaba *antes* de
   redibujar la lista; un clic rápido en "Eliminar" caía sobre un elemento que estaba
   siendo reemplazado. **Arreglo:** primero se redibuja la lista y después se limpia el
   formulario.

Resultado tras los arreglos: **96 de 96** corridas en verde (8 repeticiones × 3 rondas,
6 navegadores en paralelo).

Otras decisiones:
- **Puertos separados (8101/8181):** las E2E levantan su propia copia de la app y no tocan
  la de desarrollo (8000/8080).
- **Datos únicos:** el backend guarda en memoria, así que cada gasto lleva un sufijo
  aleatorio (`Comprar pan k3x9a`) y las pruebas pueden correr en paralelo.
- **Aserción dentro de la lista:** la notificación "Gasto 'Comprar pan' agregado" también
  tiene el texto. Buscar en toda la página daría un falso positivo.

## 5. Cómo correrlas

Instalación (una sola vez):
```bash
cd e2e
npm install
npx playwright install chromium
```

```bash
npm test               # todas, sin ver el navegador
npm run test:headed    # viendo el navegador
npm run test:ui        # modo UI de Playwright: paso a paso, ideal para la demo
npm run report         # abre el reporte HTML con los pasos Dado/Cuando/Entonces
```
