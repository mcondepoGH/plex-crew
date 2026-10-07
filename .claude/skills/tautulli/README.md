# tautulli

Consulta las analíticas de uso de Plex a través de Tautulli: actividad en curso, historial de reproducción, usuarios, bibliotecas, contenido popular y gráficas de reproducciones. Envuelve la API v2 y devuelve JSON con el sobre estándar de Tautulli (`response.result`, `response.data`).

## Cuándo se usa

Para preguntas sobre uso histórico: lo más visto, actividad de usuarios, horas punta, streams simultáneos. La carga el agente `arr-acquisition`. Complementa a `plex`, que ofrece el estado en tiempo real.

## Comandos

Script: `.claude/skills/tautulli/scripts/tautulli-api.sh <comando> [args]`. Todos son de lectura (peticiones GET a `/api/v2`); no hay comandos de escritura.

| Comando | Para qué sirve | Argumentos / opciones | Tipo |
|---------|----------------|-----------------------|------|
| `server-info` | Versión e información del servidor (`get_server_info`). | Ninguno | Lectura (JSON) |
| `activity` | Streams activos (`get_activity`). | Ninguno | Lectura (JSON) |
| `history` | Historial de reproducción (`get_history`). | `[--user U] [--section-id N] [--media-type T] [--days N] [--limit N] [--search S]` | Lectura (JSON) |
| `user-stats` | Sin opciones, usuarios (`get_users`); con opciones, tabla de usuarios (`get_users_table`). | `[--user S] [--sort-by plays\|duration\|last_seen] [--limit N]` | Lectura (JSON) |
| `libraries` | Secciones de biblioteca (`get_libraries`). | Ninguno | Lectura (JSON) |
| `library-stats` | Datos de una sección (`get_library`). | `--section-id N` (obligatoria) | Lectura (JSON) |
| `popular` | Contenido popular (`get_home_stats`, con `popular_movies`, `popular_tv` o `popular_music` según el tipo). | `[--media-type movie\|tv\|music] [--section-id N] [--days N] [--limit N]` | Lectura (JSON) |
| `recent` | Añadidos recientemente (`get_recently_added`); `--days` filtra en local. | `[--section-id N] [--media-type T] [--days N] [--limit N]` | Lectura (JSON) |
| `home-stats` | Estadísticas del panel principal (`get_home_stats`). | `[--days N]` | Lectura (JSON) |
| `plays-by-stream` | Reproducciones por tipo de stream. | `[--days N]` | Lectura (JSON) |
| `plays-by-platform` | Reproducciones por plataforma (top 10). | `[--days N]` | Lectura (JSON) |
| `plays-by-date` | Reproducciones por fecha. | `[--days N]` | Lectura (JSON) |
| `plays-by-hour` | Reproducciones por hora del día. | `[--days N]` | Lectura (JSON) |
| `plays-by-day` | Reproducciones por día de la semana. | `[--days N]` | Lectura (JSON) |
| `concurrent-streams` | Streams simultáneos por tipo y su máximo diario. | `[--days N] [--peak]` | Lectura (JSON) |
| `metadata` | Metadatos de un elemento (`get_metadata`). | `--rating-key N` o `--guid G` | Lectura (JSON) |
| `logs` | Log de Tautulli o del servidor Plex, recortado a un array con las primeras n entradas. | `[--limit N] [--plex]` | Lectura (JSON, array) |

## Variables de entorno

| Variable | Obligatoria | Uso |
|----------|-------------|-----|
| `TAUTULLI_URL` | Sí | URL base de Tautulli (se quita la barra final). |
| `TAUTULLI_API_KEY` | Sí | Clave de API, enviada como parámetro `apikey` en la URL. |
| `HOMELAB_ENV` | No | Ruta alternativa al fichero `.env`. |

## Ejemplos de uso

```bash
# Lectura: quién está viendo algo ahora
bash .claude/skills/tautulli/scripts/tautulli-api.sh activity | jq '.response.data'

# Lectura: historial de la última semana de películas
bash .claude/skills/tautulli/scripts/tautulli-api.sh history --days 7 --media-type movie --limit 50

# Lectura: series más vistas del último mes
bash .claude/skills/tautulli/scripts/tautulli-api.sh popular --media-type tv --days 30

# Lectura: pico diario de streams simultáneos
bash .claude/skills/tautulli/scripts/tautulli-api.sh concurrent-streams --days 7 --peak
```

## Notas y límites

- Sin comando muestra la ayuda y sale con 0; un comando desconocido muestra la ayuda por stderr y sale con 1. Un argumento obligatorio que falta, una opción sin valor, un valor no numérico o una opción desconocida imprimen el uso por stderr y salen con 1.
- Los errores salen por stderr con el prefijo `ERROR:` y código 1:
  - HTTP distinto de 2xx
  - Respuesta sin JSON válido
  - `result` igual a `error` (Tautulli lo devuelve con HTTP 200)
- `history --days` se envía como `start_date` (`AAAA-MM-DD`). `recent --days` no tiene equivalente en la API y se aplica con `jq` sobre `added_at`, después de limitar a `--limit`.
- `user-stats` no admite `--days`: para la actividad de un usuario en un periodo usa `history --user ... --days N`.
- `concurrent-streams --peak` devuelve solo la serie "Max. Concurrent Streams" de la misma consulta.
- `logs --plex` falla si Tautulli no tiene configurada la carpeta de logs de Plex.
- La clave de API va en la query string de la URL, por lo que no conviene copiar las URLs a logs o mensajes.
- Los datos dependen de la retención histórica configurada en Tautulli.
