# Evidencias

Qué se probó en cada paso del plan y dónde está la prueba. Cada cambio entró a `main` por un PR
aprobado por otra persona del equipo (ver [CONTRIBUTING.md](../../CONTRIBUTING.md)); el paso 2,
las normas, se configuró directo en GitHub.

## Por paso

| Paso | Qué | PR | Evidencia |
|---|---|---|---|
| 1 | Pre-commit | [#1](https://github.com/jalopezg4/Proyecto-CICD/pull/1) | [README, Pre-commit](../../README.md#pre-commit) |
| 2 | Normas de GitHub | — | [CONTRIBUTING.md](../../CONTRIBUTING.md), ruleset `proteger-main` y la [demo 1](#demo-1-el-ci-bloquea-un-error) |
| 3 | Actions base | [#2](https://github.com/jalopezg4/Proyecto-CICD/pull/2) | `.github/workflows/ci.yml` |
| 4 | Escenarios BDD y checklist de QA | [#4](https://github.com/jalopezg4/Proyecto-CICD/pull/4) | [escenarios-bdd.md](../qa/escenarios-bdd.md), [checklist-qa.md](../qa/checklist-qa.md) |
| 5 | `/health` con versión, Docker y compose | [#5](https://github.com/jalopezg4/Proyecto-CICD/pull/5) | `Dockerfile`, `docker-compose.yml` |
| 6 | E2E, smoke y k6 | [#6](https://github.com/jalopezg4/Proyecto-CICD/pull/6) | [punto3-prueba-de-aceptacion-e2e.md](../punto3-prueba-de-aceptacion-e2e.md) |
| 7 | CI completo: seguridad, imágenes, Trivy y E2E en contenedores | [#7](https://github.com/jalopezg4/Proyecto-CICD/pull/7) | [punto2-pruebas-y-cobertura.md](../punto2-pruebas-y-cobertura.md) |
| 8 | Terraform de staging y producción | [#8](https://github.com/jalopezg4/Proyecto-CICD/pull/8) | [infra/README.md](../../infra/README.md) |
| 9 | CD a staging | [#10](https://github.com/jalopezg4/Proyecto-CICD/pull/10), [#11](https://github.com/jalopezg4/Proyecto-CICD/pull/11) | [paso-09-staging](paso-09-staging/README.md) |
| 10 | QA en staging | [#12](https://github.com/jalopezg4/Proyecto-CICD/pull/12) | [paso-10-qa-staging](paso-10-qa-staging/README.md) |
| 11 | Release a producción por tag | [#13](https://github.com/jalopezg4/Proyecto-CICD/pull/13) | [Release `v1.0.0`](https://github.com/jalopezg4/Proyecto-CICD/actions/runs/44220690767) |
| 12 | Aprobación de producción | [#16](https://github.com/jalopezg4/Proyecto-CICD/pull/16) | [paso-12-aprobacion-produccion](paso-12-aprobacion-produccion/paso-12-README.md) |
| 13 | Rollback automático y botón de pánico | [#17](https://github.com/jalopezg4/Proyecto-CICD/pull/17) | [Botón de pánico en staging](https://github.com/jalopezg4/Proyecto-CICD/actions/runs/44352676200) |
| — | Reporte Allure de las E2E | [#14](https://github.com/jalopezg4/Proyecto-CICD/pull/14) | Link **Allure report** en el resumen de cada run del CI y del CD. Ejemplo: [reporte del run 44228872687](https://jalopezg4.github.io/Proyecto-CICD/e2e/reporte-e2e-ci/44228872687-1/) |
| — | Monitoreo con CloudWatch | [#18](https://github.com/jalopezg4/Proyecto-CICD/pull/18) | [Prueba de las alarmas en staging](#monitoreo) y [release `v1.1.0`](https://github.com/jalopezg4/Proyecto-CICD/actions/runs/44565572252) (alarmas en el resumen del run) |
| 14 | README y evidencias | este PR | Este archivo y el [README](../../README.md) |

## Releases a producción

| Versión | Commit | Run | Resultado |
|---|---|---|---|
| `v1.0.0` | `3acc9ae` | [44220690767](https://github.com/jalopezg4/Proyecto-CICD/actions/runs/44220690767) | Verde en el intento 2; el intento 1 falló por credenciales vencidas ([detalle](paso-12-aprobacion-produccion/paso-12-README.md#intento-1-del-run)) |
| `v1.1.0` | `a4f3069` | [44565572252](https://github.com/jalopezg4/Proyecto-CICD/actions/runs/44565572252) | Verde: `verificar`, `promover`, `desplegar-produccion` y `smoke-produccion`; el rollback no hizo falta |

## Demos

Las 3 demos del plan, cómo correrlas y si ya se probaron.

### Demo 1: el CI bloquea un error

**Probada.** [PR #3](https://github.com/jalopezg4/Proyecto-CICD/pull/3): un import sin usar
commiteado con `--no-verify` (saltando pre-commit). El check `ci` falló por lint y el ruleset no
dejó hacer merge. Se cerró sin merge.

Para repetirla: rama nueva, el mismo error, `git commit --no-verify`, PR a `main`, y mostrar el
check `ci` en rojo con el botón de merge bloqueado. Cerrar el PR al terminar.

### Demo 2: release por tag

**Probada.** Tag `v1.0.0` → `verificar` → `promover` (mismo digest de staging) → aprobación del
environment `production` → deploy → smoke. `/health` de producción respondió `v1.0.0`
([paso 12](paso-12-aprobacion-produccion/paso-12-README.md)). Se repitió con `v1.1.0`.

Para repetirla: `git tag vX.Y.Z <commit last-good de staging> && git push origin vX.Y.Z`, aprobar
en Actions con otra persona del equipo, y abrir `/health` de producción.

### Demo 3: rollback

**Rollback automático (nivel 2): va en staging.** Una versión rota no puede llegar a producción
por tag: primero pasa por staging, ahí falla, no queda como `last-good` y el job `verificar` del
release bloquea el tag. Esa protección es parte de lo que se muestra.

La demo: un PR con un cambio que pase el CI pero falle después del deploy (por ejemplo, que
`/health` reporte una versión falsa). Al hacer merge, el CD despliega, falla "Wait for the new
version" y el job `rollback` vuelve solo al `last-good`. El run queda en rojo como evidencia, y
después se revierte con otro PR. Usa el mismo `rollback.sh` que producción.

- **Estado: pendiente.** La corre el Squad Plataforma; aquí va el run cuando esté.

**Botón de pánico (nivel 3).** Probado en staging el 18 de noviembre
([run 44352676200](https://github.com/jalopezg4/Proyecto-CICD/actions/runs/44352676200)): sin
versión, usó el `last-good` (`sha-8462fd4`) y el smoke pasó. Era la misma versión que ya estaba
arriba (Terraform: `0 added, 0 changed, 0 destroyed`), así que prueba que el workflow funciona,
pero no muestra un cambio de versión.

- **Estado: pendiente una corrida con cambio real** (staging → una versión anterior → y de
  vuelta). La corre el Squad Plataforma; aquí va el run cuando esté.

## Monitoreo

Prueba del 19 de noviembre en staging: carga con k6 (pico de 50 usuarios) y una caída simulada del
backend. Se dispararon 3 alarmas de verdad y todas volvieron solas a OK:

| Hora (Colombia) | Alarma | Cambio |
|---|---|---|
| 11:55 | `latencia-p95` (llegó a 4,8 s) | ALARM |
| 11:55 | `errores-5xx` (202 por minuto en el pico) | ALARM |
| 11:57 a 11:58 | las dos | OK |
| 12:00 | `errores-5xx` (backend caído, `/health` en 503) | ALARM |
| 12:05 | `backend-sin-tareas-sanas` | ALARM |
| 12:09 | `backend-sin-tareas-sanas` | OK |

- **Pantallazos del dashboard: pendientes.** Jennifer los toma con la sesión del Learner Lab (rango
  de 1 h o 3 h del 19 de noviembre) y los sube a `docs/evidencias/monitoreo/`.

## Antes de entregar

Al terminar la presentación, el Squad Plataforma corre `terraform destroy` en los dos
workspaces (ver [infra/README.md](../../infra/README.md)) para que el Learner Lab no siga cobrando.
