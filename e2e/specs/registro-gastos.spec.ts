import { nuevoGasto } from '../data/gastos.data';
import { test } from '../fixtures/bdd.fixture';

/**
 * SPECS: solo nombran steps y parámetros. Se leen como un escenario BDD.
 * Dado = Arrange · Cuando = Act · Entonces = Assert
 */
test.describe('Funcionalidad: Registro de gastos', () => {

  test('Escenario: el usuario registra "Comprar pan" y lo ve en la lista', async ({ dado, cuando, entonces }) => {
    const gasto = nuevoGasto('Comprar pan', 5000, 'Comida');

    await dado.queElUsuarioAbreGastico();
    await cuando.registraElGasto(gasto);
    await entonces.veElGastoEnLaLista(gasto);
  });

  test('Escenario: el monto ignora símbolos y se muestra con puntos de miles', async ({ dado, cuando, entonces }) => {
    await dado.queElUsuarioAbreGastico();
    await cuando.escribeEnElMonto('-+e1250000');
    await entonces.elMontoSeMuestraComo('1.250.000');
  });

  test('Escenario: el botón Agregar solo se habilita con el formulario completo', async ({ dado, cuando, entonces }) => {
    const gasto = nuevoGasto('Taxi', 12000, 'Transporte');

    await dado.queElUsuarioAbreGastico();
    await entonces.elBotonAgregarEstaDeshabilitado();
    await cuando.llenaElFormularioCon(gasto);
    await entonces.elBotonAgregarEstaHabilitado();
  });
});

test.describe('Funcionalidad: Eliminar gastos', () => {

  test('Escenario: el usuario elimina un gasto y lo recupera con Deshacer', async ({ dado, cuando, entonces }) => {
    const gasto = nuevoGasto('Cine', 30000, 'Ocio');

    await dado.queElUsuarioAbreGastico();
    await dado.queYaRegistroElGasto(gasto);
    await cuando.eliminaElGasto(gasto);
    await entonces.noVeElGastoEnLaLista(gasto);
    await cuando.presionaDeshacer();
    await entonces.veElGastoEnLaLista(gasto);
    await entonces.laBarraDeDeshacerDesaparece();
  });
});
