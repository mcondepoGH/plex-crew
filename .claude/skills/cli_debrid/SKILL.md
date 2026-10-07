---
name: cli_debrid
description: Monitor cli_debrid (godver3/cli_debrid) — program status, queue contents, active downloads, logs, library size. Use when the user says "cli_debrid", "estado del programa", "cola de cli_debrid", "logs de cli_debrid", or mentions cli_debrid monitoring.
---

# cli_debrid Monitor

Wrapper for cli_debrid's web API. Unlike Radarr/Sonarr/Prowlarr, cli_debrid has **no API key header** — it uses a Flask-Login username/password session (cookie), same login as its web UI.

## Setup

Requires in `.env` (raíz del repo):
```
CLI_DEBRID_URL="http://localhost:5000"
CLI_DEBRID_USER="admin"
CLI_DEBRID_PASSWORD="<tu contraseña del panel>"
```

## Commands

| Action | Command |
|--------|---------|
| Program status (running/stopped, uptime) | `bash .claude/skills/cli_debrid/scripts/cli_debrid.sh status` |
| Dashboard stats (counts por estado) | `bash .claude/skills/cli_debrid/scripts/cli_debrid.sh dashboard` |
| Cola actual (contenido en cada queue) | `bash .claude/skills/cli_debrid/scripts/cli_debrid.sh queue` |
| Descargas activas | `bash .claude/skills/cli_debrid/scripts/cli_debrid.sh downloads` |
| Tamaño de librería | `bash .claude/skills/cli_debrid/scripts/cli_debrid.sh library-size` |
| Últimas N líneas de log | `bash .claude/skills/cli_debrid/scripts/cli_debrid.sh logs [n]` |
| Forzar ejecución de una tarea | `bash .claude/skills/cli_debrid/scripts/cli_debrid.sh trigger-task <nombre>` |

## Notes

- El login crea una cookie temporal en `/tmp`, reutilizada mientras sea válida; si expira, el script reautentica solo.
- `trigger-task` ejecuta de inmediato una tarea del scheduler (ej. `Scraping`) — confirmar con el usuario antes de forzarla si no la pidió explícitamente por nombre.
