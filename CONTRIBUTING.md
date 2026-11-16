# Cómo contribuir a Gastico

Normas del equipo para ramas, commits, Pull Requests y versiones. Las revisan automáticamente
los hooks de pre-commit y, más adelante, el pipeline de CI.

## 1. Estrategia de ramas: trunk-based

- `main` siempre está lista para desplegar y está **protegida**: nadie hace push directo.
- Todo cambio entra por **Pull Request** desde una rama corta, que vive horas o pocos días.
- La rama se borra cuando se hace el merge.

| Prefijo | Para qué | Ejemplo |
|---|---|---|
| `feat/` | Funcionalidad nueva | `feat/health-frontend` |
| `fix/` | Corrección de un error | `fix/monto-negativo` |
| `chore/` | Configuración, dependencias, herramientas | `chore/pre-commit` |
| `ci/` | Workflows de GitHub Actions | `ci/job-pruebas-unitarias` |
| `infra/` | Terraform y AWS | `infra/ecs-staging` |
| `docs/` | Documentación | `docs/plan-proyecto-final` |
| `test/` | Pruebas nuevas o ajustes de pruebas | `test/smoke-produccion` |

Nombres en minúscula, con guiones y cortos.

## 2. Commits: Conventional Commits

Formato:

```
<tipo>(<alcance opcional>): <descripción>
```

- **El tipo va en inglés**, porque lo exige el estándar y la herramienta que lo valida.
- **La descripción va en español**, en minúscula, en infinitivo y sin punto final, igual que el resto del proyecto.
- Un hook `commit-msg` de pre-commit valida el formato y rechaza el commit si no cumple.

### Tipos

| Tipo | Cuándo usarlo | Efecto en la versión |
|---|---|---|
| `feat` | Funcionalidad nueva para el usuario | Sube la versión **menor** (1.**2**.0) |
| `fix` | Corrección de un error | Sube el **parche** (1.2.**1**) |
| `docs` | Solo documentación | Ninguno |
| `test` | Agregar o ajustar pruebas | Ninguno |
| `ci` | Workflows y pipeline | Ninguno |
| `build` | Docker, dependencias, empaquetado | Ninguno |
| `chore` | Configuración y tareas de mantenimiento | Ninguno |
| `refactor` | Cambio de código que no cambia el comportamiento | Ninguno |
| `style` | Formato, sin cambios de lógica | Ninguno |
| `perf` | Mejora de rendimiento | Parche |
| `revert` | Revierte un commit anterior | Depende de lo revertido |

Un cambio que rompe compatibilidad lleva `!` después del tipo (`feat!:`) o una línea `BREAKING CHANGE:`
en el cuerpo. Eso sube la versión **mayor** (**2**.0.0).

### Alcances sugeridos

`backend`, `frontend`, `e2e`, `infra`, `ci`, `docs`. Son opcionales, pero ayudan a saber qué parte se tocó.

### Ejemplos

Bien:

```
feat(frontend): agregar endpoint /health con la versión
fix(backend): devolver 404 al eliminar un gasto inexistente
ci: agregar job de pruebas unitarias en cada PR
build(backend): agregar Dockerfile multi-stage
chore(e2e): agregar .prettierignore
docs: explicar la convención de commits
```

Mal (el hook los rechaza o no siguen la norma):

```
Agregar pre-commit                    ← falta el tipo
feat: Agregar health                  ← la descripción va en minúscula
fix(backend): arreglé el error.       ← infinitivo y sin punto final
update stuff                          ← sin tipo y en inglés
```

## 3. Pull Requests

1. Crear la rama desde `main` actualizado.
2. Hacer commits pequeños, con la convención.
3. Abrir el PR hacia `main`:
   - el **título del PR** sigue la misma convención (`feat(frontend): ...`), porque será el mensaje del commit final;
   - completar la plantilla: qué cambia, por qué y cómo se probó.
4. Para hacer merge se necesita:
   - **1 aprobación de alguien del otro squad**: así todo el equipo conoce todo el proyecto;
   - **CI en verde**, cuando exista el workflow.
5. El merge se hace con **Squash and merge**: a `main` entra un solo commit con el título del PR.
6. Borrar la rama después del merge.

Squads:
- **Plataforma:** Jennifer y Santiago.
- **Producto y Calidad:** Danna y Samuel.

## 4. Versiones: SemVer con tags

- Las versiones siguen `vMAYOR.MENOR.PARCHE` (por ejemplo `v1.2.0`).
- Crear un tag `vX.Y.Z` sobre `main` es lo que **promueve a producción**: la misma imagen que ya pasó por staging.
- Qué número subir depende de los commits desde el último tag (ver la tabla de tipos):
  - hay un `feat!` o un `BREAKING CHANGE` → versión mayor;
  - hay algún `feat` → versión menor;
  - solo hay `fix` o `perf` → parche.

## 5. Antes del primer commit

Instalar los hooks de pre-commit siguiendo la sección [Pre-commit del README](README.md#pre-commit).
