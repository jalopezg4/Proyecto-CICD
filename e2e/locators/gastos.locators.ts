import { Locator, Page } from '@playwright/test';
import { Categoria } from '../data/gastos.data';

/**
 * LOCATORS: solo DÓNDE está cada elemento de la pantalla.
 * Si cambia el HTML, este es el único archivo que se toca.
 * Se usan exclusivamente desde las Pages.
 */
export class GastosLocators {
  constructor(private readonly page: Page) {}

  // ---------- Formulario ----------
  get inputMonto(): Locator { return this.page.getByTestId('input-monto'); }
  get inputDescripcion(): Locator { return this.page.getByTestId('input-descripcion'); }
  get botonAgregar(): Locator { return this.page.getByTestId('btn-agregar'); }
  chipCategoria(categoria: Categoria): Locator {
    return this.page.getByTestId(`chip-${categoria.toLowerCase()}`);
  }

  // ---------- Lista de movimientos ----------
  get listaGastos(): Locator { return this.page.getByTestId('lista-gastos'); }
  get itemsGasto(): Locator { return this.page.getByTestId('gasto-item'); }
  itemPorDescripcion(descripcion: string): Locator {
    return this.itemsGasto.filter({ hasText: descripcion });
  }
  botonEliminarDe(descripcion: string): Locator {
    return this.itemPorDescripcion(descripcion).getByTestId('btn-eliminar');
  }

  // ---------- Resumen y deshacer ----------
  get total(): Locator { return this.page.getByTestId('total'); }
  get barraDeshacer(): Locator { return this.page.getByTestId('barra-deshacer'); }
  get botonDeshacer(): Locator { return this.page.getByTestId('btn-deshacer'); }
}
