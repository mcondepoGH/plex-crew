---
name: seerr
description: Gestión de solicitudes en Overseerr/Seerr: buscar, pedir películas o series, listar solicitudes pendientes y consultar el estado. Úsala cuando el usuario diga "busca en seerr", "pide esta película/serie", "solicitudes pendientes", "overseerr", "seerr", o mencione la gestión de solicitudes.
---

# Gestor de solicitudes de Seerr (compatible con Overseerr)

Envoltorio de la API de Seerr (misma forma de API que Overseerr y Jellyseerr).

## Configuración

Requiere en el `.env` (raíz del repo):
```
SEERR_URL="http://localhost:5055"
SEERR_API_KEY="<clave de API de Seerr Settings > General>"
```

## Comandos

| Acción | Comando |
|--------|---------|
| Buscar | `bash .claude/skills/seerr/scripts/seerr.sh search "Título"` |
| Estado | `bash .claude/skills/seerr/scripts/seerr.sh status` |
| Listar solicitudes | `bash .claude/skills/seerr/scripts/seerr.sh requests [pending\|approved\|all]` |
| Pedir película | `bash .claude/skills/seerr/scripts/seerr.sh request-movie <tmdbId>` |
| Pedir serie (todas las temporadas) | `bash .claude/skills/seerr/scripts/seerr.sh request-tv <tmdbId>` |
| Pedir serie (temporadas concretas) | `bash .claude/skills/seerr/scripts/seerr.sh request-tv <tmdbId> <temporada1,temporada2,...>` |
| Ver logs de Seerr | `bash .claude/skills/seerr/scripts/seerr.sh logs [n] [level]` |

El comando `logs` muestra las últimas `n` entradas del log de Seerr (50 por defecto) con el formato `fecha [nivel] etiqueta: mensaje`. El parámetro opcional `level` filtra por nivel de log (por ejemplo `error`, `warn`, `info` o `debug`).

## Notas

- Los ids de películas y series son ids de TMDB, los mismos que usan las búsquedas de Radarr y Sonarr: encadena con el comando `search` de las skills `radarr` y `sonarr` para encontrar primero el id.
- `request-movie` y `request-tv` crean una solicitud real que, según la configuración de Seerr, puede aprobarse sola y enviarse directamente a Radarr o Sonarr. Confirma con el usuario antes de pedir, salvo que haya nombrado exactamente el título.
