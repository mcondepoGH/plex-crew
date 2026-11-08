---
name: plex-crew-rules
description: Esta skill debe usarse en cualquier tarea de plex-crew. Contiene las reglas globales que aplican a todos los agentes. Úsala cuando se opere sobre el stack Plex, y cuando el usuario pida "reglas globales", "doble confirmación", "zona horaria", o mencione el marcador PLEX_CREW_CONFIRMED, secretos, tareas programadas o carpetas .@*.
---

# Skill de reglas globales de plex-crew

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) en cualquier tarea de plex-crew.** Los agentes la cargan al arrancar (campo `skills:`).

**Si no aplicas estas reglas, incumples tus requisitos operativos.**

Reúne las reglas que aplican al orquestador y a los dos especialistas, con independencia del servicio sobre el que operen.

## Propósito

Esta skill fija las reglas transversales del proyecto:
- Zona horaria de las horas que menciona el usuario
- Doble confirmación de las operaciones destructivas y uso del marcador
- Manejo de secretos
- Tareas programadas
- Carpetas que se ignoran
- Log de progreso en tareas largas

## Configuración

Sin configuración ni variables de entorno. Los secretos viven en `~/.claude/plex-crew/.env`.

## Reglas

### Hora
- Las horas que menciona el usuario sin zona se interpretan en la hora local de la máquina donde corre el plugin (zona horaria del sistema). No preguntes la zona horaria.

### Doble confirmación y marcador
- Toda operación destructiva exige dos mensajes distintos del usuario, incluso en modo automático. Una sola respuesta no basta.
- Solo después de esa doble confirmación, antepón `PLEX_CREW_CONFIRMED=1 ` al comando. Si el comando usa `cd`, el marcador va justo antes del comando destructivo, después del `&&`: `(cd "..." && PLEX_CREW_CONFIRMED=1 "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" remove 123)`.
- El hook `confirm-destructive` bloquea el comando sin el marcador. No lo añadas nunca por iniciativa propia ni tras una sola respuesta.
- Un subagente no pide la confirmación: devuelve la propuesta (qué se borra o modifica, con rutas exactas) al orquestador, que es quien pregunta al usuario.

### Borrados masivos en modo automático
En modo automático, el clasificador de Claude Code puede denegar el lanzamiento en segundo plano de agentes o scripts que borran en masa (motivos observados: «dangerous», «Auto-Mode Bypass»).
- Ejecuta el borrado masivo por tramos (lotes), en primer plano y visibles, solo tras la doble confirmación ya dada. Cada tramo lleva el marcador `PLEX_CREW_CONFIRMED=1` como en cualquier operación destructiva.
- No uses agentes ni scripts en segundo plano para borrar, y no intentes rodear el bloqueo.
- Si aun así se deniega, para y díselo al usuario.

### Secretos
- No los imprimas, no los registres en logs ni los escribas en ficheros versionados. No muestres el contenido del `.env`.
- Opera los servicios con las skills (`radarr`, `sonarr`, `prowlarr`, `plex`, `tautulli`, `seerr`, `cli_debrid`, `rutorrent`), no con `curl` y claves en línea.

### Tareas programadas
No uses `schedule` ni `RemoteTrigger` para tareas que necesiten la red local: se ejecutan en la nube y no alcanzan el stack Plex. Las tareas programadas del orquestador usan `CronCreate`.

### Carpetas ignoradas
Ignora cualquier carpeta `.@*` (por ejemplo `.@__thumb`): son caché del NAS. No las listes, no las renombres ni las incluyas en los resultados. Un hook (`protected-paths.js`) lo hace cumplir, también con `@Recycle`, `@Recently-Snapshot` y otras carpetas de sistema del NAS, y no hay confirmación que lo salte.

### Log de progreso en tareas largas
Para que se vea desde fuera por dónde va un agente, el plugin lleva un log automático. No tienes que escribirlo ni purgarlo.
- Log automático: unos hooks del plugin (`PostToolUse` y `PostToolUseFailure`) anotan cada acción de `Bash`, `Edit`, `Write` y `NotebookEdit` de cualquier agente en `~/.claude/plex-crew/logs/<AAAA-MM-DD>-auto.log`, una línea por acción: `HH:MM:SS (<zona de la máquina>) | agente o main | herramienta | comando o ruta | OK|FALLO`. Los secretos se redactan solos (`***`). Está fuera del repositorio.
- Retención: un hook de `SessionStart` borra al arrancar la sesión los `*.log` de más de 7 días de esa carpeta. Los agentes no purgan nada.
- Opcional, línea de hito: en una tarea larga puedes añadir una línea de hito (fase terminada, resumen final) a `~/.claude/plex-crew/logs/<AAAA-MM-DD>-<tarea-corta>.log`, con `HH:MM:SS (<zona de la máquina>) | fase | elemento | OK|FALLO|SALTADO|PARADO | nota`, sin secretos. Hazlo solo si puedes con tus herramientas y sin esquivar ningún hook. Si no puedes (por ejemplo, el hook de ámbito bloquea la escritura a `plex-naming`), no pasa nada: sigue sin el hito y no lo evites.
- El orquestador da al usuario la ruta del log automático del día para que haga `tail -f`.

### Skills opcionales (caveman y superpowers)
Mejoran el comportamiento, pero no son requisito. Si una skill no está disponible, sigue sin ella: no la menciones ni pidas instalarla. Si alguna regla de estas skills choca con las de plex-crew, mandan las de plex-crew (doble confirmación y marcador, secretos, carpetas `.@*`, hooks).
- `caveman`: si está disponible, úsala en lo que se dice en el chat: informes de los subagentes al orquestador y síntesis del orquestador al usuario (respuesta primero, sin relleno, tablas solo si aportan). Prosa normal y completa en: propuestas y confirmaciones destructivas (qué se borra o modifica, rutas exactas, las dos confirmaciones), avisos de seguridad, pasos donde el orden importa, preguntas al usuario, y todo lo que se persiste fuera del chat (ficheros, nombres, líneas de log, mensajes de commit, documentación, prompts de delegación). Comandos, rutas, ids y cifras, siempre literales.
- `superpowers:systematic-debugging`: si está disponible, úsala al depurar (un rechazo o descarga extraña, un indexador que falla, un emparejado erróneo): causa raíz con evidencia antes de proponer cambios. No se aplica a peticiones rutinarias.
- `superpowers:verification-before-completion`: si está disponible, úsala antes de dar una operación por hecha: comprueba el estado real (por ejemplo `exists`, `libraries`, `search` o `metadata`, o listar la carpeta) y afirma el éxito con esa evidencia, no por suposición.
- `superpowers:dispatching-parallel-agents`: si está disponible, la usa el orquestador con peticiones mixtas de partes independientes.
- `superpowers:writing-plans`: si está disponible, útil en lotes grandes (renombrado o sincronización masiva): plan por escrito antes de ejecutar, sin sustituir a la doble confirmación.
- Ni `using-superpowers`, `brainstorming` ni las skills de proceso pesado se usan al operar el stack: los subagentes son ejecutores acotados y no deben alargar peticiones simples.

## Flujo de trabajo

1. **El subagente encuentra algo destructivo** → No lo ejecutes; devuelve la propuesta al orquestador
2. **Orquestador** → Pide al usuario dos confirmaciones en dos mensajes distintos
3. **Tras las dos confirmaciones** → Delega la orden de forma explícita; el comando se ejecuta con `PLEX_CREW_CONFIRMED=1`
4. **El usuario indica una hora** → Se interpreta en la hora local de la máquina donde corre el plugin (zona horaria del sistema); no preguntes

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
- No dejes que una skill opcional salte una regla de esta lista
- No escribas secretos en los logs ni los uses para esquivar un hook
- No autolimpies backups: solo se borran cuando el usuario lo pida, con doble confirmación
