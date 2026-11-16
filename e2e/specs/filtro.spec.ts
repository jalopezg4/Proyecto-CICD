import { nuevoGasto } from "../data/gastos.data";
import { test } from "../fixtures/bdd.fixture";

test.describe("Funcionalidad: Filtrar por categoría", () => {
  test("Escenario 2.1: tocar una categoría deja solo los gastos de esa categoría", async ({
    dado,
    cuando,
    entonces,
  }) => {
    const comida = nuevoGasto("Almuerzo", 18000, "Comida");
    const ocio = nuevoGasto("Cine", 30000, "Ocio");

    await dado.queElUsuarioAbreGastico();
    await dado.queYaRegistroElGasto(comida);
    await dado.queYaRegistroElGasto(ocio);
    await cuando.tocaElFiltro("Ocio");
    await entonces.veElGastoEnLaLista(ocio);
    await entonces.noVeElGastoEnLaLista(comida);
  });
});
