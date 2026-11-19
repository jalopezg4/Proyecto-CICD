# Evidencias

Qué se probó en cada paso del plan y dónde está la prueba. Cada paso entró a `main` por un PR
revisado por el otro squad.

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
| — | Reporte Allure de las E2E | [#14](https://github.com/jalopezg4/Proyecto-CICD/pull/14) | https://jalopezg4.github.io/Proyecto-CICD/ |
| — | Monitoreo con CloudWatch | [#18](https://github.com/jalopezg4/Proyecto-CICD/pull/18) | [Release `v1.1.0`](https://github.com/jalopezg4/Proyecto-CICD/actions/runs/44565572252) (alarmas en el resumen del run) |
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

- **Botón de pánico (nivel 3): probado** en staging el 18 de noviembre
  ([run 44352676200](https://github.com/jalopezg4/Proyecto-CICD/actions/runs/44352676200)): sin
  versión, volvió al `last-good` (`sha-8462fd4`) y el smoke pasó.
- **Rollback automático de producción (nivel 2): pendiente de ensayar.** Es la demo del tag
  `v1.0.1` roto: el deploy queda estable pero el smoke falla, y `rollback-produccion` vuelve solo
  al `last-good` de producción. Lo corre el Squad Plataforma con una sesión de AWS activa, antes
  de la presentación.

## Antes de entregar

Al terminar la presentación, el Squad Plataforma corre `terraform destroy` en los dos
workspaces (ver [infra/README.md](../../infra/README.md)) para que el Learner Lab no siga cobrando.
