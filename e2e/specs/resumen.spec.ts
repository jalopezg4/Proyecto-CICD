import { nuevoGasto } from "../data/gastos.data";
import { test } from "../fixtures/bdd.fixture";

/**
 * Compara el total ANTES y DESPUÉS de registrar. Como el backend en memoria es compartido,
 * este spec corre en su propio proyecto ("resumen"), después de los demás y sin nada en
 * paralelo que cambie el total en medio (ver playwright.config.ts).
 */
test.describe("Funcionalidad: Resumen de gastos", () => {
  test("Escenario 1.1: el total y la cantidad suben al registrar un gasto", async ({
    dado,
    cuando,
    entonces,
  }) => {
    const gasto = nuevoGasto("Almuerzo", 18000, "Comida");

    await dado.queElUsuarioAbreGastico();
    const antes = await dado.queAnotaElResumen();
    await cuando.registraElGasto(gasto);
    await entonces.elResumenSumaElGasto(antes, gasto);
  });
});
