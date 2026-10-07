# plex-crew

Orquestador y subagentes de Claude Code para operar un homelab Plex (zurg, Radarr, Sonarr, Prowlarr, cli_debrid, Seerr).

## Arranque
1. Copia `.env.example` a `.env` y rellena URLs y claves. `.env` está ignorado por git.
2. Ejecuta `claude` en esta carpeta. `.claude/settings.json` fija `orchestrator` como agente de la sesión.
3. Pide lo que necesites; el orquestador elige especialista.

Alternativa: `claude --agent orchestrator`.

## Agentes
| Agente | Dominio |
|---|---|
| `orchestrator` | Enruta y sintetiza. No ejecuta. |
| `plex-naming` | Nombres, ids, especiales, emparejados erróneos. |
| `zurg-ops` | Estado, config, diagnóstico y backups de zurg. |
| `arr-acquisition` | Búsqueda y descarga, filtros de idioma, indexadores. |

Los subagentes no pueden lanzar otros subagentes: por eso el orquestador es el agente principal.

## Skills
- Reglas: `plex-naming-rules`, `zurg-rules`, `arr-language-filters`, `safety-conventions`.
- Servicios: `prowlarr`, `radarr`, `sonarr`, `plex`, `tautulli`, `seerr`, `cli_debrid`. Cargan credenciales con `scripts/load-env.sh` (`HOMELAB_ENV` permite usar otro `.env`).

## Hooks
- `hooks/confirm-destructive.js`: pide confirmación en comandos Bash destructivos.
- `hooks/enforce-agent-scope.js`: limita las rutas de escritura de un agente.

## Requisitos
- Zurg con su servidor MCP configurado (`mcp__zurg__*`).
- `node` para los hooks.
