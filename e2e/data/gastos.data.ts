/**
 * Datos de prueba. El backend guarda en memoria y se comparte entre pruebas,
 * por eso cada gasto lleva un sufijo único: ninguna prueba depende de otra.
 */
export type Categoria = "Comida" | "Transporte" | "Hogar" | "Ocio" | "Salud" | "Otros";

export interface Gasto {
  descripcion: string;
  monto: string; // tal como lo teclea el usuario: "5000"
  montoEnPantalla: string; // tal como lo muestra la app: "$ 5.000"
  categoria: Categoria;
}

const sufijo = () => Math.random().toString(36).slice(2, 7);

export function nuevoGasto(
  descripcion: string,
  monto: number,
  categoria: Categoria = "Comida",
): Gasto {
  return {
    descripcion: `${descripcion} ${sufijo()}`,
    monto: String(monto),
    montoEnPantalla: `$ ${monto.toLocaleString("de-DE")}`, // separador de miles con punto, como COP
    categoria,
  };
}
