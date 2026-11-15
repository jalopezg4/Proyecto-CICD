import { test } from "@playwright/test";
import { Gasto } from "../data/gastos.data";
import { GastosPage } from "../pages/gastos.page";

/**
 * DADO (Given) = Arrange: el contexto inicial del escenario.
 * Los steps solo usan métodos de las Pages, nunca locators directamente.
 */
export class Dado {
  constructor(private readonly gastosPage: GastosPage) {}

  async queElUsuarioAbreGastico(): Promise<void> {
    await test.step("Dado que el usuario abre Gastico", async () => {
      await this.gastosPage.abrir();
    });
  }

  async queYaRegistroElGasto(gasto: Gasto): Promise<void> {
    await test.step(`Dado que ya registró el gasto "${gasto.descripcion}"`, async () => {
      await this.gastosPage.registrarGasto(gasto.monto, gasto.descripcion, gasto.categoria);
    });
  }
}
