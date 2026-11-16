import { Page } from "@playwright/test";

/** Lo común a todas las páginas: navegar a su ruta. */
export abstract class BasePage {
  protected constructor(
    protected readonly page: Page,
    private readonly ruta: string,
  ) {}

  async navegar(): Promise<void> {
    await this.page.goto(this.ruta);
  }
}
