import { expect, test } from "@playwright/test";
import { enPesos, Gasto, ResumenAnotado } from "../data/gastos.data";
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

  async elResumenSumaElGasto(antes: ResumenAnotado, gasto: Gasto): Promise<void> {
    await test.step(`Entonces el total sube ${gasto.montoEnPantalla} y la cantidad sube en 1`, async () => {
      await expect(this.gastosPage.total()).toHaveText(enPesos(antes.total + Number(gasto.monto)));
      await expect(this.gastosPage.cantidad()).toContainText(`${antes.cantidad + 1} gasto(s)`);
    });
  }

  async veElAviso(texto: string): Promise<void> {
    await test.step(`Entonces aparece el aviso "${texto}"`, async () => {
      await expect(this.gastosPage.notificacion(texto)).toBeVisible();
    });
  }

  async elFormularioQuedaLimpio(): Promise<void> {
    await test.step("Entonces el formulario queda limpio", async () => {
      await expect(this.gastosPage.campoMonto()).toHaveValue("");
      await expect(this.gastosPage.campoDescripcion()).toHaveValue("");
    });
  }

  async laBarraDeDeshacerDesaparece(): Promise<void> {
    await test.step('Entonces la barra de "Deshacer" desaparece', async () => {
      await expect(this.gastosPage.barraDeshacer()).toBeHidden();
    });
  }
}
