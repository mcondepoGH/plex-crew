---
name: cli_debrid
description: Monitor de cli_debrid (godver3/cli_debrid): estado del programa, contenido de la cola, descargas activas, logs y tamaño de la biblioteca. Úsala cuando el usuario diga "cli_debrid", "estado del programa", "cola de cli_debrid", "logs de cli_debrid", o mencione la monitorización de cli_debrid.
---

# Monitor de cli_debrid

Envoltorio de la API web de cli_debrid. A diferencia de Radarr, Sonarr y Prowlarr, cli_debrid **no usa cabecera de API key**: autentica con usuario y contraseña mediante una sesión Flask-Login (cookie), el mismo login que su interfaz web.

## Configuración

Requiere en el `.env` (raíz del repo):
```
CLI_DEBRID_URL="http://localhost:5000"
CLI_DEBRID_USER="admin"
CLI_DEBRID_PASSWORD="<tu contraseña del panel>"
```

## Comandos

| Acción | Comando |
|--------|---------|
| Estado del programa (en marcha o parado, tiempo activo) | `bash .claude/skills/cli_debrid/scripts/cli_debrid.sh status` |
| Estadísticas del panel (recuentos por estado) | `bash .claude/skills/cli_debrid/scripts/cli_debrid.sh dashboard` |
| Cola actual (contenido de cada cola) | `bash .claude/skills/cli_debrid/scripts/cli_debrid.sh queue` |
| Descargas activas | `bash .claude/skills/cli_debrid/scripts/cli_debrid.sh downloads` |
| Tamaño de la biblioteca | `bash .claude/skills/cli_debrid/scripts/cli_debrid.sh library-size` |
| Últimas N líneas de log | `bash .claude/skills/cli_debrid/scripts/cli_debrid.sh logs [n]` |
| Forzar la ejecución de una tarea | `bash .claude/skills/cli_debrid/scripts/cli_debrid.sh trigger-task <nombre>` |

## Notas

- El login crea una cookie temporal en `/tmp`, que se reutiliza mientras sea válida; si caduca, el script vuelve a autenticarse solo.
- `trigger-task` ejecuta de inmediato una tarea del planificador (por ejemplo `Scraping`). Confirma con el usuario antes de forzarla si no la pidió explícitamente por su nombre.
