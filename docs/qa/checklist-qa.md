# Checklist de QA de Gastico

Paso 4 del plan (Squad Producto y Calidad). Se usa dos veces:

- **Paso 10: QA en staging.** Se completan las secciones A, B, C y D.
- **Paso 12: aprobación de producción.** Se completan la sección E y la decisión final (F).

Los escenarios a los que se refiere cada punto están en [escenarios-bdd.md](escenarios-bdd.md).

## Cómo usarlo

1. Copiar este archivo (o hacer una copia en el PR del paso 14) y llenar los datos de la corrida.
2. Marcar cada punto con `[x]` cuando pasa. Si falla, dejarlo en `[ ]` y anotarlo en la tabla de defectos.
3. Guardar evidencia: una captura de pantalla por sección, o el enlace al run de GitHub Actions.
4. **En producción solo se mira, no se escribe.** No registrar ni eliminar gastos.

## Datos de la corrida

| Campo | Valor |
|---|---|
| Ambiente | staging / producción (tachar el que no aplica) |
| Versión (tag o `sha-xxxxxxx`) | |
| Enlace al run de GitHub Actions | |
| URL de la app (ALB) | |
| Quién hizo la QA | |
| Fecha y hora | |

---

## A. Antes de empezar

- [ ] El run del pipeline terminó en verde (CI, release y deploy)
- [ ] La URL de la app abre sin errores de red
  - El ALB es solo HTTP (no hay dominio ni certificado en el Learner Lab). Que el navegador muestre
    **"No es seguro"** es lo esperado: **no es un defecto** y no es motivo para rechazar la QA.
- [ ] `/health` responde 200 con estado "ok"
- [ ] La versión que informa `/health` es el commit que se quería desplegar en staging (`sha-xxxxxxx`) (8.1). La versión de producción (`vX.Y.Z`) se revisa en la sección E, en el paso 12
- [ ] Se anotó si el ambiente está recién desplegado (si es así, debe estar sin gastos; ver 6.1)

## B. Funcionalidad (staging)

Hacerla en un navegador normal, como lo haría un usuario. Anotar con qué navegador se hizo.

**Registrar**
- [ ] Registrar un gasto con monto, descripción y categoría: aparece en la lista (0.1)
- [ ] Aparece el aviso verde "Gasto '...' agregado"
- [ ] El formulario queda limpio y el cursor vuelve al monto
- [ ] Presionar Enter en la descripción también registra el gasto (3.4)

**Monto y validaciones**
- [ ] Escribir `-+e1250000` deja `1.250.000` (0.2)
- [ ] Escribir `150000000` queda en `100.000.000` y avisa del máximo (3.3)
- [ ] El botón "Agregar gasto" está deshabilitado con el formulario vacío, con monto 0 y con descripción de solo espacios (0.3, 3.1, 3.2)

**Vista previa**
- [ ] Sin monto dice "Escribe cuánto gastaste para empezar"; con monto dice "Vas a registrar $ X en <categoría>" y cambia al elegir otra categoría (4.1)

**Resumen y filtro**
- [ ] El total y la cantidad suben al registrar un gasto (1.1)
- [ ] El resumen por categoría muestra la categoría, el monto y el porcentaje (1.2)
- [ ] Tocar una categoría filtra la lista; tocarla otra vez (o "Todas") quita el filtro (2.1, 2.2)
- [ ] Una categoría sin gastos muestra "No tienes gastos en ..." y "Ver todos" (2.3)

**Eliminar y deshacer**
- [ ] Eliminar un gasto lo quita de la lista y del total
- [ ] "Deshacer" lo devuelve (0.4)
- [ ] Si no se presiona nada, la barra de Deshacer desaparece a los 6 segundos y el gasto sigue eliminado (5.1)

**Primer uso**
- [ ] Justo después de un despliegue, la app dice "Aún no registras gastos" y ofrece "Registrar mi primer gasto" (6.1)

## C. Comportamiento en AWS (staging)

Esto no se puede probar en el computador: depende de la red de AWS.

- [ ] Recargar la página (F5) conserva los gastos (7.1)
- [ ] Dejar la pestaña abierta 2 minutos y volver a registrar un gasto: sigue funcionando (WebSocket vivo)
- [ ] Abrir la app en dos pestañas y registrar un gasto en cada una: ambas funcionan sin errores (sticky sessions)
- [ ] Cambiar de categoría, filtrar y eliminar varias veces seguidas no deja la pantalla trabada
- [ ] No hay mensajes de error rojos inesperados (mirar también la consola del navegador, F12)
- [ ] Con el backend en 0 tareas, `/health` del frontend responde 503 con `{"status": "degraded", "backend": "down"}`; al volverlo a 1 tarea responde 200 "ok" (8.3, una sola vez)

## D. Cosas que hay que mirar en la consola de AWS y en GitHub

Estas son las evidencias que se muestran en la presentación.

- [ ] ECS: los dos servicios (frontend y backend) están en estado estable, con 1 tarea corriendo cada uno
- [ ] Target group del ALB: el frontend está "healthy"
- [ ] El backend **no tiene IP pública** y no responde desde internet
- [ ] ECR: se revisaron los hallazgos del escaneo de la imagen y no hay críticos sin justificar
- [ ] SonarCloud: Quality Gate en "Passed"
- [ ] `/docs` del backend no está expuesto (decisión del plan para producción)
- [ ] SSM: existen `current` y `last-good` del ambiente (sin esto no hay rollback posible)

## E. Aprobación de producción (paso 12)

**Solo lectura. No crear ni borrar gastos.**

Antes de aprobar el environment `production` en GitHub:

- [ ] La misma versión pasó por staging y la QA de staging (secciones A a D) está completa y firmada
- [ ] No hay defectos abiertos de severidad Bloqueante o Alta (ver tabla de abajo)
- [ ] El tag es el correcto (`vX.Y.Z`) y apunta al commit que se probó en staging
- [ ] Ya existe un `last-good` en SSM al cual volver si algo sale mal
- [ ] Alguien del Squad Plataforma está disponible para el rollback si hace falta

Después del deploy a producción:

- [ ] `/health` responde 200 "ok" con la versión exactamente igual al tag, con la `v` (por ejemplo `v1.0.0`) (8.1)
- [ ] La página principal carga con el título "Gastico" y el formulario (8.2)
- [ ] El smoke del pipeline terminó en verde
- [ ] No quedaron gastos de prueba en producción

## F. Decisión

| Condición | Decisión |
|---|---|
| Todo lo marcado y ningún defecto Bloqueante o Alto abierto | **Aprobado** |
| Defectos Medios o Bajos abiertos, anotados con responsable | **Aprobado con observaciones** |
| Cualquier punto de A, C o E sin pasar, o un defecto Bloqueante o Alto | **Rechazado**: no se aprueba el environment `production` |

| Resultado | Aprobado / Aprobado con observaciones / Rechazado |
|---|---|
| Firma de quien hizo la QA | |
| Fecha y hora | |

## Tabla de defectos

Severidad: **Bloqueante** (no se puede usar la app), **Alta** (falla una función principal),
**Media** (falla algo secundario o hay un workaround), **Baja** (detalle visual o de texto).

| # | Qué pasó | Cómo repetirlo | Severidad | Evidencia | Quién lo arregla |
|---|---|---|---|---|---|
| | | | | | |
