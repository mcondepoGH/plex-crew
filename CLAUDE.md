# plex-crew

Plugin de Claude Code con agentes y skills para operar el stack Plex. Un orquestador (agente de la sesión principal) enruta cada petición al especialista adecuado.

Un plugin instalado no carga este `CLAUDE.md` como contexto: es solo la guía para trabajar en el repositorio. Las reglas globales que aplican en ejecución (idioma, hora, doble confirmación y marcador `PLEX_CREW_CONFIRMED=1`, secretos, tareas programadas, carpetas `.@*`) viven en la skill `skills/plex-crew-rules`, que cargan los cuatro agentes. Si cambias una regla global, cámbiala allí.

## Reglas de desarrollo
- Servicios del stack: usa las skills de `skills/` (prowlarr, radarr, sonarr, plex, tautulli, seerr, cli_debrid), no curl con claves en línea.
- Las credenciales viven en `~/.claude/plex-crew/.env` (plantilla en `.env.example`), nunca en el repositorio.
- En los `SKILL.md`, los scripts se invocan con `${CLAUDE_PLUGIN_ROOT}`: es la única ruta válida una vez instalado el plugin.

## Estructura
- `agents/`: `orchestrator` (sesión principal), `plex-naming`, `arr-acquisition`.
- `skills/`: reglas curadas (`plex-crew-rules`, `plex-naming-rules`, `arr-language-filters`) y skills de servicios del stack. `_lib/` contiene las librerías de shell compartidas (`load-env.sh`, `arr-api.sh`) y no es una skill.
- `hooks/`: `confirm-destructive.js` (PreToolUse: bloquea comandos destructivos sin marcador de confirmación) y `enforce-agent-scope.js` (PreToolUse: limita las rutas de escritura del agente `plex-naming`, detectado por `agent_type`, según `scope.conf`, ver `scope.conf.example`); `log-action.js` (PostToolUse/PostToolUseFailure: añade una línea por acción, con secretos redactados, a `~/.claude/plex-crew/logs/<fecha>-auto.log`) y `purge-logs.js` (SessionStart: borra los `*.log` de más de 7 días de esa carpeta). Los dos últimos nunca bloquean (siempre exit 0).

## Arranque
Al instalar el plugin, la sesión principal arranca como el orquestador (`"agent": "orchestrator"` en `settings.json`; hooks registrados en `hooks/hooks.json`). Para probarlo sin instalar: `claude --plugin-dir .`.
