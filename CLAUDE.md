# plex-crew

Sistema de agentes y skills para operar el homelab Plex. Un orquestador (agente de la sesión principal) enruta cada petición al especialista adecuado.

## Reglas globales
- Responde siempre en español.
- Las horas que mencione el usuario son Europe/Madrid (Sevilla). No preguntes la zona.
- Doble confirmación antes de cualquier operación destructiva: son dos mensajes distintos del usuario, incluso en modo automático. El marcador `PLEX_CREW_CONFIRMED=1` solo se antepone al comando tras esa doble confirmación; el hook `confirm-destructive` lo exige y bloquea el comando sin él.
- Zurg se opera solo con tools `mcp__zurg__*`. Nunca curl ni filesystem a mano.
- Servicios homelab: usa las skills de `.claude/skills/` (prowlarr, radarr, sonarr, plex, tautulli, seerr, cli_debrid), no curl con claves en línea.
- Secretos: viven en `.env` (ignorado por git, plantilla en `.env.example`). Nunca los imprimas, los registres ni los escribas en ficheros versionados.
- No uses `schedule` ni `RemoteTrigger` para tareas que necesiten la red local: corren en la nube, sin acceso al homelab.
- Ignora carpetas `.@*` en toda operación.

## Estructura
- `.claude/agents/`: `orchestrator` (sesión principal), `plex-naming`, `zurg-ops`, `arr-acquisition`.
- `.claude/skills/`: reglas curadas (`plex-naming-rules`, `zurg-rules`, `arr-language-filters`) y skills de servicios homelab. `_lib/` contiene las librerías de shell compartidas (`load-env.sh`, `arr-api.sh`) y no es una skill.
- `hooks/`: `confirm-destructive.js` (bloquea comandos destructivos sin marcador de confirmación) y `enforce-agent-scope.js` (limita las rutas de escritura de un agente según `scope.conf`, ver `scope.conf.example`).
- `scripts/`: solo `start.sh`, que arranca Claude Code cargando el `.env`.

## Arranque
`claude` en esta carpeta arranca el orquestador (`"agent": "orchestrator"` en `.claude/settings.json`).
