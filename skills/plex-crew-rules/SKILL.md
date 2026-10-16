---
name: plex-crew-rules
description: Esta skill debe usarse en cualquier tarea de plex-crew. Contiene las reglas globales que aplican a todos los agentes. Úsala cuando se opere sobre el stack Plex, y cuando el usuario pida "reglas globales", "doble confirmación", "idioma", "zona horaria", o mencione el marcador PLEX_CREW_CONFIRMED, secretos, tareas programadas o carpetas .@*.
---

# Skill de reglas globales de plex-crew

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) en cualquier tarea de plex-crew.** Los agentes la cargan al arrancar (campo `skills:`).

**Si no aplicas estas reglas, incumples tus requisitos operativos.**

Reúne las reglas que aplican al orquestador y a los dos especialistas, con independencia del servicio sobre el que operen.

## Propósito

Esta skill fija las reglas transversales del proyecto:
- Idioma y zona horaria de las respuestas
- Doble confirmación de las operaciones destructivas y uso del marcador
- Manejo de secretos
- Tareas programadas
- Carpetas que se ignoran
- Log de progreso en tareas largas

## Configuración

Sin configuración ni variables de entorno. Los secretos viven en `~/.claude/plex-crew/.env`.

## Reglas

### Idioma y hora
- Responde siempre en español.
- Las horas que menciona el usuario son Europe/Madrid (Sevilla). No preguntes la zona horaria.

### Doble confirmación y marcador
- Toda operación destructiva exige dos mensajes distintos del usuario, incluso en modo automático. Una sola respuesta no basta.
- Solo después de esa doble confirmación, antepón `PLEX_CREW_CONFIRMED=1 ` al comando. Si el comando usa `cd`, el marcador va justo antes del comando destructivo, después del `&&`: `(cd "..." && PLEX_CREW_CONFIRMED=1 "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" remove 123)`.
- El hook `confirm-destructive` bloquea el comando sin el marcador. No lo añadas nunca por iniciativa propia ni tras una sola respuesta.
- Un subagente no pide la confirmación: devuelve la propuesta (qué se borra o modifica, con rutas exactas) al orquestador, que es quien pregunta al usuario.

### Secretos
- No los imprimas, no los registres en logs ni los escribas en ficheros versionados. No muestres el contenido del `.env`.
- Opera los servicios con las skills (`radarr`, `sonarr`, `prowlarr`, `plex`, `tautulli`, `seerr`, `cli_debrid`, `rutorrent`), no con `curl` y claves en línea.

### Tareas programadas
No uses `schedule` ni `RemoteTrigger` para tareas que necesiten la red local: se ejecutan en la nube y no alcanzan el stack Plex. Las tareas programadas del orquestador usan `CronCreate`.

### Carpetas ignoradas
Ignora cualquier carpeta `.@*` (por ejemplo `.@__thumb`): son caché del NAS. No las listes, no las renombres ni las incluyas en los resultados.

### Log de progreso en tareas largas
Para que se vea desde fuera por dónde va un agente, el plugin lleva un log automático. No tienes que escribirlo ni purgarlo.
- Log automático: unos hooks del plugin (`PostToolUse` y `PostToolUseFailure`) anotan cada acción de `Bash`, `Edit`, `Write` y `NotebookEdit` de cualquier agente en `~/.claude/plex-crew/logs/<AAAA-MM-DD>-auto.log`, una línea por acción: `HH:MM:SS (Europe/Madrid) | agente o main | herramienta | comando o ruta | OK|FALLO`. Los secretos se redactan solos (`***`). Está fuera del repositorio.
- Retención: un hook de `SessionStart` borra al arrancar la sesión los `*.log` de más de 7 días de esa carpeta. Los agentes no purgan nada.
- Opcional, línea de hito: en una tarea larga puedes añadir una línea de hito (fase terminada, resumen final) a `~/.claude/plex-crew/logs/<AAAA-MM-DD>-<tarea-corta>.log`, con `HH:MM:SS (Europe/Madrid) | fase | elemento | OK|FALLO|SALTADO|PARADO | nota`, sin secretos. Hazlo solo si puedes con tus herramientas y sin esquivar ningún hook. Si no puedes (por ejemplo, el hook de ámbito bloquea la escritura a `plex-naming`), no pasa nada: sigue sin el hito y no lo evites.
- El orquestador da al usuario la ruta del log automático del día para que haga `tail -f`.

## Flujo de trabajo

1. **El subagente encuentra algo destructivo** → No lo ejecutes; devuelve la propuesta al orquestador
2. **Orquestador** → Pide al usuario dos confirmaciones en dos mensajes distintos
3. **Tras las dos confirmaciones** → Delega la orden de forma explícita; el comando se ejecuta con `PLEX_CREW_CONFIRMED=1`
4. **El usuario indica una hora** → Es Europe/Madrid; no preguntes

## Notas

- El hook `confirm-destructive` es una red de seguridad, no un sandbox
- Estas reglas sustituyen al `CLAUDE.md` del repositorio, que un plugin instalado no carga como contexto
- Las reglas específicas de cada servicio viven en sus propias skills (`plex-naming-rules`, `arr-language-filters`)

## Referencia

Para la referencia local detallada, consulta:
- **[Referencia rápida](./references/quick-reference.md)** - Reglas de un vistazo
- **[Resolución de problemas](./references/troubleshooting.md)** - Comandos bloqueados y errores habituales
- Documentación del hook: `hooks/README.md`

## Lo que NO hay que hacer

- No ejecutes una operación destructiva sin dos confirmaciones en mensajes distintos
- No antepongas `PLEX_CREW_CONFIRMED=1` sin esa doble confirmación
- No imprimas credenciales ni el contenido del `.env`
- No programes con `schedule` ni `RemoteTrigger` nada que necesite la red local
- No toques las carpetas `.@*`
- No escribas secretos en los logs ni los uses para esquivar un hook
- No autolimpies backups: solo se borran cuando el usuario lo pida, con doble confirmación
