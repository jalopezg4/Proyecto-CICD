"""Arma la portada de GitHub Pages con todos los reportes Allure publicados.

Se corre dentro de la rama gh-pages. Lee e2e/<nombre>/<run>/summary.json y escribe index.html
con una tabla por tipo de reporte (CI o staging), del más reciente al más viejo.
"""

import html
import json
import os
from pathlib import Path

REPO = os.environ.get("GITHUB_REPOSITORY", "")


def filas(carpeta: Path) -> list[str]:
    salida = []
    corridas = sorted(
        (c for c in carpeta.iterdir() if (c / "summary.json").exists()),
        key=lambda c: [int(p) for p in c.name.split("-")],
        reverse=True,
    )
    for corrida in corridas:
        datos = json.loads((corrida / "summary.json").read_text(encoding="utf-8"))
        s = datos.get("stats", {})
        mal = s.get("failed", 0) + s.get("broken", 0)
        estado = "✅" if mal == 0 else "❌"
        run_id = corrida.name.split("-")[0]
        meta = datos.get("meta", {})
        version = html.escape(str(meta.get("version", "")))
        salida.append(
            f"<tr><td>{estado}</td>"
            f'<td><a href="{carpeta.name}/{corrida.name}/">Run {html.escape(corrida.name)}</a></td>'
            f"<td>{version}</td>"
            f"<td>{s.get('passed', 0)}</td><td>{mal}</td><td>{s.get('skipped', 0)}</td>"
            f'<td><a href="https://github.com/{REPO}/actions/runs/{run_id}">ver run</a></td></tr>'
        )
    return salida


def main() -> None:
    raiz = Path("e2e")
    secciones = []
    for carpeta in sorted(raiz.iterdir() if raiz.exists() else []):
        if carpeta.is_dir():
            cuerpo = "\n".join(filas(carpeta))
            secciones.append(
                f"<h2>{html.escape(carpeta.name)}</h2>"
                "<table><tr><th></th><th>Reporte</th><th>Versión</th><th>Pasaron</th>"
                f"<th>Fallaron</th><th>No corrieron</th><th>GitHub Actions</th></tr>{cuerpo}</table>"
            )
    Path("index.html").write_text(
        f"""<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Gastico · Reportes E2E</title>
<style>
  body {{ font-family: system-ui, sans-serif; max-width: 960px; margin: 2rem auto; padding: 0 1rem;
         background: #fafafa; color: #222; }}
  table {{ border-collapse: collapse; width: 100%; margin-bottom: 2rem; background: #fff; }}
  th, td {{ padding: .5rem .75rem; border-bottom: 1px solid #ddd; text-align: left; }}
  th {{ background: #f0f0f0; }}
  a {{ color: #0b6bcb; }}
</style></head>
<body>
<h1>Gastico · Reportes E2E (Allure)</h1>
<p>Un reporte por cada ejecución de las pruebas E2E: <b>reporte-e2e-ci</b> corre contra docker compose
en el CI, y <b>reporte-e2e-staging</b> contra el ambiente de staging en AWS. Si algo falló, el
escenario trae pantallazo, video y trace.</p>
{"".join(secciones)}
</body></html>
""",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
