# Referencia rápida de Radarr

## Configuración

```bash
# ~/.claude/plex-crew/.env
RADARR_URL="http://localhost:7878"
RADARR_API_KEY="<your_api_key>"
# Opcional: RADARR_DEFAULT_QUALITY_PROFILE=1
```

```bash
RA="${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh"
```

## Comandos del script

```bash
bash "$RA" help
bash "$RA" search "the matrix"
bash "$RA" search-json "the matrix"
bash "$RA" exists 603
bash "$RA" config
bash "$RA" status
bash "$RA" collection-info 2344
bash "$RA" logs
bash "$RA" logs 20 --level error --grep "rootfolder"
bash "$RA" logs --files
# Modifican estado: confirma con el usuario antes de añadir
bash "$RA" add 603
bash "$RA" add 603 5
bash "$RA" add 603 5 --no-search
bash "$RA" add-collection 2344
bash "$RA" add-collection 2344 "The Matrix" --no-search
# Destructivo: doble confirmación y PLEX_CREW_CONFIRMED=1 (plex-crew-rules)
PLEX_CREW_CONFIRMED=1 bash "$RA" remove 603
PLEX_CREW_CONFIRMED=1 bash "$RA" remove 603 --delete-files
```

## Filtros con jq

```bash
bash "$RA" search-json "the matrix" | jq -r '.[] | "\(.tmdbId) \(.title) (\(.year))"'
bash "$RA" search-json "the matrix" | jq -r '.[0].overview'
bash "$RA" search-json "the matrix" | jq -r '.[] | select(.collection) | "\(.collection.tmdbId) \(.collection.title)"'
```

## curl directo (sin clave literal)

Prefiere siempre el script. Si necesitas curl, usa las variables y no imprimas la clave:

```bash
curl -s -H "X-Api-Key: $RADARR_API_KEY" "$RADARR_URL/api/v3/system/status" | jq '.version'
```

## Salidas habituales

| Comando | Salida |
|---------|--------|
| `search` | `1. The Matrix (1999) - https://themoviedb.org/movie/603 [Collection: The Matrix Collection]` |
| `exists` | `not_found`, o `exists` y `ID: 12, Title: The Matrix, Has File: true` |
| `status` | `Radarr 5.14.0.9383 - Radarr (debian, branch master)` |
| `add` | `✅ Added: The Matrix (1999)` y `🔍 Search started` |
| `add-collection` | `📦 Found 3 movies in collection`, una línea por película y `📊 Added: 2 \| Skipped: 1` |
| `remove` | `🗑️ Removed: The Matrix (1999) (files kept)` |
| `logs` | `2026-01-03T10:00:03Z  ERROR  Api  mensaje` |

Códigos de salida: 0 correcto; 1 error de uso, película o colección no encontrada, o fallo de conexión.
