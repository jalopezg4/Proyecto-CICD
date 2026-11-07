import { test } from '@playwright/test';
import { Gasto } from '../data/gastos.data';
import { GastosPage } from '../pages/gastos.page';

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
}
