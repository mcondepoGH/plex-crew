# tautulli

Consulta las analíticas de uso de Plex a través de Tautulli: actividad en curso, historial de reproducción, estadísticas por usuario y biblioteca, y gráficas de reproducciones. Devuelve JSON con la estructura estándar de Tautulli (`response.result`, `response.data`).

## Cuándo se usa

Para preguntas sobre uso histórico: lo más visto, actividad de usuarios, horas punta, streams simultáneos. La carga el agente `arr-acquisition`. Complementa a `plex`, que ofrece el estado en tiempo real.

## Comandos

Script: `.claude/skills/tautulli/scripts/tautulli-api.sh <comando> [opciones]`. Todos son de lectura (peticiones GET a `/api/v2`).

| Comando | Para qué sirve (comando de la API) | Opciones | Tipo |
|---------|------------------------------------|----------|------|
| `server-info` | Versión e información del servidor (`get_server_info`). | Ninguna | Lectura |
| `activity` | Streams activos (`get_activity`). | `--details` (aceptada, sin efecto) | Lectura |
| `history` | Historial de reproducción (`get_history`). | `--user`, `--section-id`, `--media-type`, `--days N`, `--limit N` (25 por defecto), `--search` | Lectura |
| `user-stats` | Sin opciones: lista de usuarios (`get_users`). Con opciones: `get_user_stats`. | `--user`, `--sort-by`, `--limit`, `--days` | Lectura |
| `libraries` | Secciones de biblioteca (`get_libraries`). | Ninguna | Lectura |
| `library-stats` | Datos de una sección (`get_library`). | `--section-id <id>` (obligatoria) | Lectura |
| `popular` | Contenido popular (`get_home_stats` con `stat_id=popular_movies`). | `--section-id`, `--media-type`, `--days N` (30), `--limit N` (10) | Lectura |
| `recent` | Añadidos recientemente (`get_recently_added`). | `--section-id`, `--media-type`, `--days N`, `--limit N` (25) | Lectura |
| `home-stats` | Estadísticas del panel principal (`get_home_stats`). | `--days N` (30) | Lectura |
| `plays-by-stream` | Reproducciones por tipo de stream (`get_plays_by_stream_type`). | `--days N` (30) | Lectura |
| `plays-by-platform` | Por plataforma, top 10 (`get_plays_by_top_10_platforms`). | `--days N` (30) | Lectura |
| `plays-by-date` | Por fecha (`get_plays_by_date`). | `--days N` (30) | Lectura |
| `plays-by-hour` | Por hora del día (`get_plays_by_hourofday`). | `--days N` (30) | Lectura |
| `plays-by-day` | Por día de la semana (`get_plays_by_dayofweek`). | `--days N` (30) | Lectura |
| `concurrent-streams` | Streams simultáneos por tipo (`get_concurrent_streams_by_stream_type`); con `--peak` usa `get_plays_per_month` con `y_axis=concurrent`. | `--days N` (30), `--peak` | Lectura |
| `metadata` | Metadatos de un elemento (`get_metadata`). | `--rating-key <key>` o `--guid <guid>` | Lectura |
| `logs` | Log de Tautulli (`get_logs`) o del servidor Plex (`get_plex_log`), recortado con `jq`. | `--limit N` (25), `--plex` | Lectura |

Sin argumentos, `-h`, `--help` o `help` muestran la ayuda.

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

# Lectura: horas con más reproducciones en el último mes
bash .claude/skills/tautulli/scripts/tautulli-api.sh plays-by-hour --days 30

# Lectura: pico de streams simultáneos
bash .claude/skills/tautulli/scripts/tautulli-api.sh concurrent-streams --days 7 --peak
```

No hay comandos de escritura en esta skill.

## Notas y límites

- `--days` en `history` y `user-stats` se convierte con `date -d "N days ago" +%s` (GNU date) y se envía como `start_date` en epoch; en `recent` se envía como `start`.
- `popular` pide siempre `stat_id=popular_movies`; `--media-type` y `--section-id` se pasan como parámetros pero el script no cambia la estadística según el tipo.
- `activity --details` se acepta pero no cambia la petición.
- `user-stats --sort-by` se envía como `order_column`.
- La clave de API va en la query string de la URL, por lo que no conviene copiar las URLs a logs o mensajes.
- Opciones desconocidas abortan con "Unknown option". Con `set -u`, una opción con valor sin valor (`--days` al final) falla con "unbound variable".
- Para varios servidores Tautulli se pueden sobrescribir `TAUTULLI_URL` y `TAUTULLI_API_KEY` en el entorno antes de llamar al script.
- Los datos dependen de la retención histórica configurada en Tautulli.
