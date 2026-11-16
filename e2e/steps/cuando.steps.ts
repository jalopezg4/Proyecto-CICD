import { test } from "@playwright/test";
import { Categoria, Gasto } from "../data/gastos.data";
import { GastosPage } from "../pages/gastos.page";

/**
 * CUANDO (When) = Act: la acción que realiza el usuario.
 */
export class Cuando {
  constructor(private readonly gastosPage: GastosPage) {}

  async registraElGasto(gasto: Gasto): Promise<void> {
    await test.step(`Cuando registra el gasto "${gasto.descripcion}" de ${gasto.montoEnPantalla} en ${gasto.categoria}`, async () => {
      await this.gastosPage.registrarGasto(gasto.monto, gasto.descripcion, gasto.categoria);
    });
  }

  async llenaElFormularioCon(gasto: Gasto): Promise<void> {
    await test.step(`Cuando llena el formulario con "${gasto.descripcion}"`, async () => {
      await this.gastosPage.completarFormulario(gasto.monto, gasto.descripcion, gasto.categoria);
    });
  }

  async escribeEnElMonto(texto: string): Promise<void> {
    await test.step(`Cuando escribe "${texto}" en el monto`, async () => {
      await this.gastosPage.escribirMonto(texto);
    });
  }

  async eliminaElGasto(gasto: Gasto): Promise<void> {
    await test.step(`Cuando elimina el gasto "${gasto.descripcion}"`, async () => {
      await this.gastosPage.eliminarGasto(gasto.descripcion);
    });
  }

  async presionaDeshacer(): Promise<void> {
    await test.step('Cuando presiona "Deshacer"', async () => {
      await this.gastosPage.presionarDeshacer();
    });
  }

  async escribeElMontoYLaDescripcion(monto: string, descripcion: string): Promise<void> {
    await test.step(`Cuando escribe el monto ${monto} y la descripción "${descripcion}"`, async () => {
      await this.gastosPage.escribirMonto(monto);
      await this.gastosPage.escribirDescripcion(descripcion);
    });
  }

  async presionaEnterEnLaDescripcion(): Promise<void> {
    await test.step("Cuando presiona Enter estando en la descripción", async () => {
      await this.gastosPage.presionarEnterEnDescripcion();
    });
  }

  async tocaElFiltro(categoria: Categoria): Promise<void> {
    await test.step(`Cuando toca "${categoria}" en el filtro de Movimientos`, async () => {
      await this.gastosPage.filtrarPor(categoria);
    });
  }

  async recargaLaPagina(): Promise<void> {
    await test.step("Cuando recarga la página", async () => {
      await this.gastosPage.recargar();
    });
  }
}
