import { expect, Locator, Page } from '@playwright/test';
import { Categoria } from '../data/gastos.data';
import { GastosLocators } from '../locators/gastos.locators';
import { BasePage } from './base.page';

/**
 * PAGE: los MÉTODOS de la pantalla (cómo interactuar con ella).
 * Usa los Locators; no hace aserciones (eso es de los steps "Entonces").
 */
export class GastosPage extends BasePage {
  private readonly locators: GastosLocators;

  constructor(page: Page) {
    super(page, '/');
    this.locators = new GastosLocators(page);
  }

  // ---------- Acciones ----------
  async abrir(): Promise<void> {
    await this.navegar();
    await this.locators.inputMonto.waitFor({ state: 'visible' });
  }

  async escribirMonto(monto: string): Promise<void> {
    await this.locators.inputMonto.click();
    await this.locators.inputMonto.pressSequentially(monto); // tecla por tecla, como un usuario
  }

  async escribirDescripcion(descripcion: string): Promise<void> {
    await this.locators.inputDescripcion.fill(descripcion);
  }

  async elegirCategoria(categoria: Categoria): Promise<void> {
    await this.locators.chipCategoria(categoria).click();
  }

  async presionarAgregar(): Promise<void> {
    await this.locators.botonAgregar.click();
  }

  async completarFormulario(monto: string, descripcion: string, categoria: Categoria): Promise<void> {
    await this.escribirMonto(monto);
    await this.escribirDescripcion(descripcion);
    await this.elegirCategoria(categoria);
  }

  async registrarGasto(monto: string, descripcion: string, categoria: Categoria): Promise<void> {
    await this.completarFormulario(monto, descripcion, categoria);
    await this.presionarAgregar();
    await this.esperarFormularioLimpio();
  }

  /** Sincronización (no es una aserción del escenario): el formulario se limpia
   *  cuando el backend confirmó el registro. */
  async esperarFormularioLimpio(): Promise<void> {
    await expect(this.locators.inputDescripcion).toHaveValue('');
  }

  async eliminarGasto(descripcion: string): Promise<void> {
    await this.locators.botonEliminarDe(descripcion).click();
  }

  async presionarDeshacer(): Promise<void> {
    await this.locators.botonDeshacer.click();
  }

  // ---------- Elementos que los steps "Entonces" necesitan verificar ----------
  campoMonto(): Locator { return this.locators.inputMonto; }
  campoDescripcion(): Locator { return this.locators.inputDescripcion; }
  botonAgregar(): Locator { return this.locators.botonAgregar; }
  gastoEnLista(descripcion: string): Locator { return this.locators.itemPorDescripcion(descripcion); }
  barraDeshacer(): Locator { return this.locators.barraDeshacer; }
}
