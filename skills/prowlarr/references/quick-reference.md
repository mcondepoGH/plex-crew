# Referencia rápida de Prowlarr

## Configuración

```bash
# ~/.claude/plex-crew/.env
PROWLARR_URL="http://localhost:9696"
PROWLARR_API_KEY="<your_api_key>"
# Opcional: PROWLARR_MAX_TIME=30
# Opcional: PROWLARR_TESTALL_MAX_TIME=120
```

```bash
PR="${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh"
```

## Comandos del script

```bash
bash "$PR" help
# Búsqueda (solo lectura)
bash "$PR" search "ubuntu 22.04"
bash "$PR" search "inception" --category 2000 --torrents --limit 10
bash "$PR" tv-search --tvdb 71663 --season 1 --episode 1
bash "$PR" movie-search --imdb tt0111161
bash "$PR" movie-search --tmdb 278
# Consulta
bash "$PR" indexers
bash "$PR" indexers --verbose
bash "$PR" stats
bash "$PR" apps
bash "$PR" status
bash "$PR" health
bash "$PR" logs
bash "$PR" logs 20 --level warn --grep "indexer"
bash "$PR" logs --files
# Pruebas (consultan indexadores externos; test-all puede tardar hasta 120 s)
bash "$PR" test 5
bash "$PR" test-all
# Modifican estado: confirma con el usuario antes
bash "$PR" disable 5
bash "$PR" enable 5
bash "$PR" sync
# Destructivo: doble confirmación y PLEX_CREW_CONFIRMED=1 (plex-crew-rules)
PLEX_CREW_CONFIRMED=1 bash "$PR" delete 5
```

## Filtros con jq

```bash
bash "$PR" search "ubuntu" | jq -r '.[] | "\(.seeders)\t\(.size)\t\(.title)"'
bash "$PR" search "ubuntu" | jq 'sort_by(-.seeders) | .[0:5]'
bash "$PR" indexers | jq -r '.[] | select(.enabled | not) | "\(.id) \(.name)"'
bash "$PR" stats | jq -r '.[] | select(.failures > 0) | "\(.name): \(.failures) fallos"'
```

## Categorías habituales

| Id | Categoría |
|----|-----------|
| 2000 | Películas (2040 HD, 2045 UHD, 2050 BluRay) |
| 5000 | TV (5040 HD, 5045 UHD, 5070 Anime) |
| 3000 | Audio |
| 4000 | PC |
| 7000 | Libros |

## curl directo (sin clave literal)

Prefiere siempre el script. Si necesitas curl, usa las variables y no imprimas la clave; ten en cuenta que así la clave sí queda visible en `ps`:

```bash
curl -s -H "X-Api-Key: $PROWLARR_API_KEY" "$PROWLARR_URL/api/v1/system/status" | jq '.version'
```

## Salidas habituales

| Comando | Salida |
|---------|--------|
| `test` | `{"status": "ok", "indexer": "5", "tested": true}` |
| `test-all` | `{"status": "ok", "tested": 3, "failed": 0}` |
| `enable` / `disable` | `{"status": "ok", "indexer": "5", "enabled": true}` |
| `delete` | `{"status": "ok", "indexer": "5", "deleted": true}` |
| `sync` | Cuerpo de Prowlarr y `{"status": "ok", "message": "Syncing indexers to applications"}` |
| `logs` | `2026-01-03T10:00:03Z  WARN  Indexer  mensaje` |

Códigos de salida: 0 correcto; 1 error de uso, fallo de conexión, HTTP no 2xx, o `test` y `test-all` con indexador fallido.
