import { test as base } from "@playwright/test";
import { GastosPage } from "../pages/gastos.page";
import { Cuando } from "../steps/cuando.steps";
import { Dado } from "../steps/dado.steps";
import { Entonces } from "../steps/entonces.steps";

type FixturesBdd = {
  gastosPage: GastosPage;
  dado: Dado;
  cuando: Cuando;
  entonces: Entonces;
};

/**
 * Inyecta los steps en cada spec: test('...', async ({ dado, cuando, entonces }) => ...)
 * Las tres clases comparten la misma instancia de la Page.
 */
export const test = base.extend<FixturesBdd>({
  gastosPage: async ({ page }, use) => {
    await use(new GastosPage(page));
  },
  dado: async ({ gastosPage }, use) => {
    await use(new Dado(gastosPage));
  },
  cuando: async ({ gastosPage }, use) => {
    await use(new Cuando(gastosPage));
  },
  entonces: async ({ gastosPage }, use) => {
    await use(new Entonces(gastosPage));
  },
});
