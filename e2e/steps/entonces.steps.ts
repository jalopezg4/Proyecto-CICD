import { expect, test } from "@playwright/test";
import { Gasto } from "../data/gastos.data";
import { GastosPage } from "../pages/gastos.page";

/**
 * ENTONCES (Then) = Assert: lo que el usuario debe ver.
 * Aquí (y solo aquí) viven las aserciones con expect().
 */
export class Entonces {
  constructor(private readonly gastosPage: GastosPage) {}

  async veElGastoEnLaLista(gasto: Gasto): Promise<void> {
    await test.step(`Entonces ve "${gasto.descripcion}" en la lista con ${gasto.montoEnPantalla}`, async () => {
      // Se busca DENTRO de la lista: la notificación también trae el texto (evita falsos positivos)
      const item = this.gastosPage.gastoEnLista(gasto.descripcion);
      await expect(item).toBeVisible();
      await expect(item).toContainText(gasto.montoEnPantalla);
      await expect(item).toContainText(gasto.categoria);
    });
  }

  async noVeElGastoEnLaLista(gasto: Gasto): Promise<void> {
    await test.step(`Entonces ya no ve "${gasto.descripcion}" en la lista`, async () => {
      await expect(this.gastosPage.gastoEnLista(gasto.descripcion)).toHaveCount(0);
    });
  }

  async elMontoSeMuestraComo(valorEsperado: string): Promise<void> {
    await test.step(`Entonces el monto se muestra como "${valorEsperado}"`, async () => {
      await expect(this.gastosPage.campoMonto()).toHaveValue(valorEsperado);
    });
  }

  async elBotonAgregarEstaDeshabilitado(): Promise<void> {
    await test.step('Entonces el botón "Agregar gasto" está deshabilitado', async () => {
      await expect(this.gastosPage.botonAgregar()).toBeDisabled();
    });
  }

  async elBotonAgregarEstaHabilitado(): Promise<void> {
    await test.step('Entonces el botón "Agregar gasto" está habilitado', async () => {
      await expect(this.gastosPage.botonAgregar()).toBeEnabled();
    });
  }

  async laBarraDeDeshacerDesaparece(): Promise<void> {
    await test.step('Entonces la barra de "Deshacer" desaparece', async () => {
      await expect(this.gastosPage.barraDeshacer()).toBeHidden();
    });
  }
}
