"""Frontend de Gastico hecho 100% en Python con NiceGUI.

La UX sigue modelos mentales de apps de finanzas conocidas:
- Primero "¿cuánto?", luego "¿en qué?" (como Nequi / apps de bancos).
- Categorías visibles como chips con icono (reconocer > recordar).
- Gastos agrupados por día ("Hoy", "Ayer") con el total del día, como un extracto.
- Eliminar se puede deshacer (como Gmail), en vez de pedir confirmación.
- Tocar una categoría del resumen filtra la lista.
"""

import os
import time
from datetime import date, datetime, timedelta
from pathlib import Path

from api_client import ApiError, GastosApi
from formato import MONTO_MAXIMO, formatear_cop, normalizar_monto, parsear_cop, solo_digitos
from nicegui import ui

API_URL = os.getenv("GASTICO_API_URL", "http://127.0.0.1:8000")
PUERTO = int(os.getenv("GASTICO_FRONT_PORT", "8080"))
SEGUNDOS_DESHACER = 6

api = GastosApi(API_URL)

# categoría -> (icono, color)
CATEGORIAS = {
    "Comida": ("restaurant", "#f97316"),
    "Transporte": ("directions_bus", "#3b82f6"),
    "Hogar": ("home", "#8b5cf6"),
    "Ocio": ("sports_esports", "#ec4899"),
    "Salud": ("favorite", "#ef4444"),
    "Otros": ("category", "#64748b"),
}
# Bloquea en el navegador cualquier tecla que no sea un dígito (+, -, e, comas...),
# dejando pasar teclas de edición y atajos como Ctrl+C / Ctrl+V.
SOLO_DIGITOS_JS = """(e) => {
  const permitidas = ['Backspace', 'Delete', 'ArrowLeft', 'ArrowRight', 'Tab', 'Enter', 'Home', 'End'];
  if (e.ctrlKey || e.metaKey || permitidas.includes(e.key)) return;
  if (!/^[0-9]$/.test(e.key)) e.preventDefault();
}"""

MESES = [
    "enero",
    "febrero",
    "marzo",
    "abril",
    "mayo",
    "junio",
    "julio",
    "agosto",
    "septiembre",
    "octubre",
    "noviembre",
    "diciembre",
]

ESTILOS = """
<style>
  html, body { background: linear-gradient(160deg, #ecfdf5 0%, #f1f5f9 45%, #eef2ff 100%) fixed;
               background-color: #f1f5f9; min-height: 100vh; }
  .tarjeta { background: white; border-radius: 20px; box-shadow: 0 10px 30px -12px rgba(15, 23, 42, .18); }
  .kpi-total { background: linear-gradient(135deg, #059669, #10b981); color: white; border-radius: 20px;
               box-shadow: 0 14px 30px -12px rgba(5, 150, 105, .55); }
  .gasto-item { border-radius: 14px; transition: background .15s ease; }
  .gasto-item:hover { background: #f8fafc; }
  .gasto-item .btn-borrar { opacity: .35; transition: opacity .15s ease; }
  .gasto-item:hover .btn-borrar { opacity: 1; }
  .chip { border-radius: 999px; border: 1.5px solid #e2e8f0; padding: 6px 14px; cursor: pointer;
          display: flex; align-items: center; gap: 6px; font-size: 14px; color: #334155;
          transition: all .15s ease; user-select: none; background: white; }
  .chip:hover { border-color: #94a3b8; }
  .fila-categoria { border-radius: 12px; padding: 6px 8px; cursor: pointer; transition: background .15s ease; }
  .fila-categoria:hover { background: #f1f5f9; }
  .campo .q-field__control, .campo .q-field__native, .campo .q-field__prefix { height: 60px; min-height: 60px; }
  .campo .q-field__bottom { display: none; }
  .monto-grande input { font-size: 28px !important; font-weight: 800; color: #0f172a; -moz-appearance: textfield; }
  .monto-grande input::placeholder { color: #cbd5e1; opacity: 1; }
  .monto-grande input::-webkit-inner-spin-button,
  .monto-grande input::-webkit-outer-spin-button { -webkit-appearance: none; margin: 0; }
</style>
"""


def pesos(valor: float) -> str:
    return "$ " + f"{valor:,.0f}".replace(",", ".")


def etiqueta_dia(dia: date) -> str:
    hoy = date.today()
    if dia == hoy:
        return "Hoy"
    if dia == hoy - timedelta(days=1):
        return "Ayer"
    return f"{dia.day} de {MESES[dia.month - 1]}"


def saludo() -> str:
    hora = datetime.now().hour
    if hora < 12:
        return "Buenos días"
    if hora < 19:
        return "Buenas tardes"
    return "Buenas noches"


@ui.page("/")
async def index():
    ui.colors(primary="#10b981")
    ui.add_head_html(ESTILOS)
    estado = {"categoria": "Comida", "filtro": None, "eliminado": None, "expira": 0.0}

    # ---------- Encabezado ----------
    with (
        ui.header()
        .classes("text-slate-800 px-8 py-4 backdrop-blur-md border-b border-slate-200/60")
        .style("background: rgba(255,255,255,.75)")
    ):
        with ui.row().classes("w-full max-w-6xl mx-auto items-center justify-between"):
            with ui.row().classes("items-center gap-3"):
                ui.icon("savings", size="38px").classes("text-emerald-600")
                with ui.column().classes("gap-0"):
                    ui.label("Gastico").classes("text-3xl font-extrabold tracking-tight")
                    ui.label("Tu plata, bajo control").classes("text-sm text-slate-500")
            hoy = date.today()
            ui.label(f"{saludo()} 👋 · {hoy.day} de {MESES[hoy.month - 1]}").classes("text-slate-500 max-sm:hidden")

    # ---------- Acciones ----------
    def valor_monto() -> int | None:
        return parsear_cop(monto.value)

    def formulario_valido() -> bool:
        return bool(descripcion.value and descripcion.value.strip()) and bool(valor_monto())

    def al_cambiar_monto(e):
        # Los puntos de miles y el bloqueo de símbolos los hace la máscara en el navegador
        # (sin ida y vuelta al servidor, que se "comía" teclas al escribir rápido).
        # Aquí solo se aplica el tope, que es lo único que debe decidir el servidor.
        texto, se_paso = normalizar_monto(e.value)
        if se_paso:
            ui.notify(f"El monto máximo es $ {formatear_cop(MONTO_MAXIMO)}", type="warning")
            monto.value = solo_digitos(texto)
            # Dentro del evento de escritura NiceGUI no reenvía el valor al navegador: lo forzamos
            monto.update()
            monto.run_method("updateValue")
        actualizar_formulario()

    def actualizar_formulario():
        boton_agregar.set_enabled(formulario_valido())
        vista_previa.refresh()

    def elegir_categoria(nombre: str):
        estado["categoria"] = nombre
        chips_categoria.refresh()
        vista_previa.refresh()

    async def agregar():
        if not formulario_valido():
            ui.notify("Completa el monto y la descripción", type="warning")
            return
        texto = descripcion.value.strip()
        try:
            await api.agregar(texto, valor_monto(), estado["categoria"])
        except ApiError as error:
            ui.notify(str(error), type="negative")
            return
        # Primero se redibuja la lista y DESPUÉS se limpia el formulario: así "formulario limpio"
        # significa "ya puedes interactuar con la lista nueva" (si no, un clic rápido caía
        # sobre un elemento que estaba siendo reemplazado y se perdía).
        await refrescar()
        ui.notify(f"Gasto '{texto}' agregado", type="positive", position="top")
        descripcion.value = ""
        monto.value = ""
        monto.run_method("focus")

    async def eliminar(gasto: dict):
        try:
            await api.eliminar(gasto["id"])
        except ApiError as error:
            ui.notify(str(error), type="negative")
            return
        estado["eliminado"] = gasto
        estado["expira"] = time.time() + SEGUNDOS_DESHACER
        texto_deshacer.set_text(f"Eliminaste '{gasto['descripcion']}'")
        barra_deshacer.set_visibility(True)
        await refrescar()

    async def deshacer():
        gasto = estado["eliminado"]
        if not gasto:
            return
        barra_deshacer.set_visibility(False)
        estado["eliminado"] = None
        try:
            await api.agregar(gasto["descripcion"], gasto["monto"], gasto["categoria"])
        except ApiError as error:
            ui.notify(str(error), type="negative")
            return
        ui.notify(f"'{gasto['descripcion']}' recuperado", type="positive", position="top")
        await refrescar()

    def vigilar_deshacer():
        if estado["eliminado"] and time.time() > estado["expira"]:
            estado["eliminado"] = None
            barra_deshacer.set_visibility(False)

    async def filtrar(categoria: str | None):
        # Tocar el filtro activo lo quita (como un interruptor)
        estado["filtro"] = None if estado["filtro"] == categoria else categoria
        chips_filtro.refresh()
        await lista.refresh()

    async def refrescar():
        await resumen.refresh()
        await lista.refresh()

    # ---------- Piezas que se recargan ----------
    @ui.refreshable
    def chips_categoria():
        with ui.row().classes("gap-2 flex-wrap").props("data-testid=chips-categoria"):
            for nombre, (icono, color) in CATEGORIAS.items():
                activa = estado["categoria"] == nombre
                estilo = f"background:{color};border-color:{color};color:white" if activa else ""
                with (
                    ui.element("div")
                    .classes("chip")
                    .style(estilo)
                    .props(f"data-testid=chip-{nombre.lower()}")
                    .on("click", lambda n=nombre: elegir_categoria(n))
                ):
                    ui.icon(icono, size="18px").style("" if activa else f"color:{color}")
                    ui.label(nombre)

    @ui.refreshable
    def vista_previa():
        icono, color = CATEGORIAS[estado["categoria"]]
        if valor_monto():
            with ui.row().classes("items-center gap-2 text-slate-500 text-sm"):
                ui.icon(icono, size="18px").style(f"color:{color}")
                ui.label("Vas a registrar")
                ui.label(pesos(valor_monto())).classes("font-bold text-slate-800")
                ui.label("en")
                ui.label(estado["categoria"]).classes("font-bold").style(f"color:{color}")
        else:
            ui.label("Escribe cuánto gastaste para empezar").classes("text-slate-400 text-sm")

    @ui.refreshable
    def chips_filtro():
        with ui.row().classes("gap-2 flex-wrap").props("data-testid=filtro-categoria"):
            activo = estado["filtro"] is None
            with (
                ui.element("div")
                .classes("chip")
                .style("background:#0f172a;border-color:#0f172a;color:white" if activo else "")
                .on("click", lambda: filtrar(None))
            ):
                ui.label("Todas")
            for nombre, (icono, color) in CATEGORIAS.items():
                activo = estado["filtro"] == nombre
                estilo = f"background:{color};border-color:{color};color:white" if activo else ""
                with ui.element("div").classes("chip").style(estilo).on("click", lambda n=nombre: filtrar(n)):
                    ui.icon(icono, size="16px").style("" if activo else f"color:{color}")
                    ui.label(nombre)

    @ui.refreshable
    async def resumen():
        try:
            datos = await api.resumen()
        except ApiError as error:
            ui.label(str(error)).classes("text-red-500")
            return
        promedio = datos["total"] / datos["cantidad"] if datos["cantidad"] else 0
        with ui.column().classes("kpi-total w-full p-6 gap-1"):
            ui.label("Total gastado").classes("text-emerald-50 text-sm uppercase tracking-wider")
            ui.label(pesos(datos["total"])).classes("text-4xl font-extrabold").props("data-testid=total")
            ui.label(f"{datos['cantidad']} gasto(s) · promedio {pesos(promedio)}").classes(
                "text-emerald-50 text-sm"
            ).props("data-testid=cantidad")

        with ui.column().classes("tarjeta w-full p-6 gap-2"):
            ui.label("¿En qué se va tu plata?").classes("text-lg font-bold text-slate-700")
            if not datos["por_categoria"]:
                ui.label("Cuando registres gastos verás aquí en qué se te va el dinero.").classes(
                    "text-slate-400 text-sm"
                )
                return
            ui.label("Toca una categoría para ver solo esos gastos").classes("text-xs text-slate-400 -mt-1")
            for nombre, valor in sorted(datos["por_categoria"].items(), key=lambda x: -x[1]):
                icono, color = CATEGORIAS.get(nombre, CATEGORIAS["Otros"])
                porcentaje = valor / datos["total"]
                fondo = "background:#f1f5f9" if estado["filtro"] == nombre else ""
                with (
                    ui.column()
                    .classes("fila-categoria w-full gap-1")
                    .style(fondo)
                    .on("click", lambda n=nombre: filtrar(n))
                ):
                    with ui.row().classes("w-full items-center justify-between"):
                        with ui.row().classes("items-center gap-2"):
                            ui.icon(icono).style(f"color:{color}")
                            ui.label(nombre).classes("text-slate-700")
                            ui.label(f"{porcentaje:.0%}").classes("text-xs text-slate-400")
                        ui.label(pesos(valor)).classes("font-semibold text-slate-800")
                    ui.linear_progress(value=porcentaje, show_value=False, size="8px", color=None).props(
                        'rounded track-color="grey-3"'
                    ).style(f"color:{color}")

    @ui.refreshable
    async def lista():
        try:
            gastos = await api.listar(estado["filtro"])
            todos = gastos if estado["filtro"] is None else await api.listar()
        except ApiError as error:
            ui.label(str(error)).classes("text-red-500")
            return

        # Sugerencias de descripciones ya usadas (autocompletar)
        descripcion.set_autocomplete(sorted({g["descripcion"] for g in todos}))

        if not gastos:
            with ui.column().classes("w-full items-center py-10 gap-2 text-slate-400"):
                ui.icon("receipt_long", size="48px")
                if estado["filtro"]:
                    ui.label(f"No tienes gastos en {estado['filtro']}").props("data-testid=lista-vacia")
                    ui.button("Ver todos", on_click=lambda: filtrar(None)).props("flat no-caps")
                else:
                    ui.label("Aún no registras gastos").props("data-testid=lista-vacia")
                    ui.button(
                        "Registrar mi primer gasto", icon="add", on_click=lambda: monto.run_method("focus")
                    ).props("flat no-caps")
            return

        # Agrupar por día, como un extracto bancario
        grupos: dict[date, list[dict]] = {}
        for gasto in gastos:
            dia = datetime.fromisoformat(gasto["fecha"]).date()
            grupos.setdefault(dia, []).append(gasto)

        for dia, gastos_dia in grupos.items():
            with ui.row().classes("w-full items-center justify-between px-2 pt-3"):
                ui.label(etiqueta_dia(dia)).classes("text-xs font-bold uppercase tracking-wider text-slate-400")
                ui.label(f"Total del día {pesos(sum(g['monto'] for g in gastos_dia))}").classes(
                    "text-xs text-slate-400"
                )
            for gasto in gastos_dia:
                icono, color = CATEGORIAS.get(gasto["categoria"], CATEGORIAS["Otros"])
                hora = datetime.fromisoformat(gasto["fecha"]).strftime("%I:%M %p").lower()
                with (
                    ui.row()
                    .classes("gasto-item w-full items-center px-3 py-2 gap-4 no-wrap")
                    .props("data-testid=gasto-item")
                ):
                    with ui.element("div").classes("rounded-full p-2").style(f"background:{color}22"):
                        ui.icon(icono, size="22px").style(f"color:{color}")
                    with ui.column().classes("gap-0 grow min-w-0"):
                        ui.label(gasto["descripcion"]).classes("font-semibold text-slate-800 truncate").props(
                            "data-testid=gasto-descripcion"
                        )
                        ui.label(f"{gasto['categoria']} · {hora}").classes("text-xs text-slate-500")
                    ui.label(pesos(gasto["monto"])).classes("font-bold text-slate-800 whitespace-nowrap").props(
                        "data-testid=gasto-monto"
                    )
                    ui.button(icon="delete_outline", on_click=lambda g=gasto: eliminar(g)).props(
                        "flat round dense color=red-5 data-testid=btn-eliminar"
                    ).classes("btn-borrar").tooltip("Eliminar (podrás deshacerlo)")

    # ---------- Layout ----------
    with ui.row().classes("w-full max-w-6xl mx-auto px-6 pt-4 pb-24 gap-6 items-start no-wrap max-md:flex-wrap"):
        with ui.column().classes("w-full md:w-2/3 gap-6"):
            with ui.column().classes("tarjeta w-full p-6 gap-4"):
                ui.label("Registrar gasto").classes("text-lg font-bold text-slate-700")
                with ui.row().classes("w-full gap-3 items-start max-sm:flex-col no-wrap"):
                    with ui.column().classes("gap-1 w-64 max-sm:w-full"):
                        with ui.row().classes("w-full items-baseline justify-between"):
                            ui.label("¿Cuánto gastaste?").classes("text-sm text-slate-500")
                            ui.label(f"máx. $ {formatear_cop(MONTO_MAXIMO)}").classes("text-xs text-slate-400")
                        monto = (
                            ui.input(placeholder="0", on_change=al_cambiar_monto)
                            .props(
                                "outlined autofocus prefix=$ inputmode=numeric autocomplete=off "
                                'mask="###.###.###" reverse-fill-mask unmasked-value '
                                "data-testid=input-monto"
                            )
                            .classes("campo monto-grande w-full")
                            .on("keydown", js_handler=SOLO_DIGITOS_JS)
                            .on("keydown.enter", agregar)
                        )
                    with ui.column().classes("gap-1 grow max-sm:w-full"):
                        ui.label("¿En qué?").classes("text-sm text-slate-500")
                        descripcion = (
                            ui.input(
                                placeholder="Ej: Almuerzo, bus, Netflix…", on_change=lambda: actualizar_formulario()
                            )
                            .props("outlined clearable data-testid=input-descripcion")
                            .classes("campo w-full")
                            .on("keydown.enter", agregar)
                        )
                ui.label("Categoría").classes("text-sm text-slate-500 -mb-2")
                chips_categoria()
                with ui.row().classes("w-full items-center justify-between gap-3 pt-2"):
                    vista_previa()
                    boton_agregar = (
                        ui.button("Agregar gasto", icon="add", on_click=agregar)
                        .props("unelevated rounded size=lg no-caps data-testid=btn-agregar")
                        .classes("px-6")
                    )
                boton_agregar.set_enabled(False)

            with ui.column().classes("tarjeta w-full p-6 gap-3"):
                ui.label("Movimientos").classes("text-lg font-bold text-slate-700")
                chips_filtro()
                with ui.column().classes("w-full gap-1").props("data-testid=lista-gastos"):
                    await lista()

        with ui.column().classes("w-full md:w-1/3 gap-6 md:sticky md:top-28"):
            await resumen()

    # Barra para deshacer (aparece abajo al eliminar)
    with (
        ui.row()
        .classes(
            "fixed bottom-6 left-1/2 -translate-x-1/2 z-50 items-center gap-4 no-wrap "
            "bg-slate-800 text-white rounded-full pl-6 pr-2 py-2 shadow-xl"
        )
        .props("data-testid=barra-deshacer") as barra_deshacer
    ):
        texto_deshacer = ui.label()
        ui.button("Deshacer", on_click=deshacer).props("flat rounded no-caps color=green-3 data-testid=btn-deshacer")
    barra_deshacer.set_visibility(False)
    ui.timer(0.5, vigilar_deshacer)


if __name__ in {"__main__", "__mp_main__"}:
    # Mismo marranito ("savings") del encabezado, en el verde de la app
    ui.run(
        title="Gastico", port=PUERTO, favicon=Path(__file__).parent / "static" / "favicon.svg", reload=False, show=False
    )
