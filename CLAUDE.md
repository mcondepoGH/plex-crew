# plex-crew

Sistema de agentes y skills para operar el homelab Plex. Un orquestador (agente de la sesión principal) enruta cada petición al especialista adecuado.

## Reglas globales
- Responde siempre en español.
- Las horas que mencione el usuario son Europe/Madrid (Sevilla). No preguntes la zona.
- Doble confirmación antes de cualquier operación destructiva (skill `safety-conventions`).
- Permisos: todo fichero tocado acaba `mcondepo:docker-stacker` (1000:1003) modo 770, salvo bajo el mount de zurg.
- Zurg se opera solo con tools `mcp__zurg__*`. Nunca curl ni filesystem a mano.
- Servicios homelab: usa las skills de `.claude/skills/` (prowlarr, radarr, sonarr, plex, tautulli, seerr, cli_debrid), no curl con claves en línea.
- Secretos: viven en `.env` (ignorado por git, plantilla en `.env.example`). Nunca los imprimas ni los escribas en ficheros versionados.
- Ignora carpetas `.@*` en toda operación.

## Estructura
- `.claude/agents/`: `orchestrator` (sesión principal), `plex-naming`, `zurg-ops`, `arr-acquisition`.
- `.claude/skills/`: reglas curadas (`plex-naming-rules`, `zurg-rules`, `arr-language-filters`, `safety-conventions`) y skills de servicios homelab.
- `hooks/`: `confirm-destructive.js` (avisa en comandos destructivos) y `enforce-agent-scope.js` (limita rutas de escritura por agente).
- `scripts/load-env.sh`: carga común de credenciales desde `.env`.

## Arranque
`claude` en esta carpeta arranca el orquestador (`"agent": "orchestrator"` en `.claude/settings.json`).
