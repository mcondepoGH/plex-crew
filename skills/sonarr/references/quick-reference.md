# Referencia rápida de Sonarr

## Configuración

```bash
# ~/.claude/plex-crew/.env
SONARR_URL="http://localhost:8989"
SONARR_API_KEY="<your_api_key>"
# Opcional: SONARR_DEFAULT_QUALITY_PROFILE=1
```

```bash
SO="${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh"
```

## Comandos del script

```bash
bash "$SO" help
bash "$SO" search "breaking bad"
bash "$SO" search-json "breaking bad"
bash "$SO" exists 81189
bash "$SO" config
bash "$SO" status
bash "$SO" logs
bash "$SO" logs 20 --level error --grep "rootfolder"
bash "$SO" logs --files
bash "$SO" health
bash "$SO" queue
bash "$SO" indexers
bash "$SO" downloadclients
bash "$SO" customformats
bash "$SO" qualityprofiles
# Modifican estado: confirma con el usuario antes de añadir
bash "$SO" add 81189
bash "$SO" add 81189 5
bash "$SO" add 81189 5 --no-search
# Destructivo: doble confirmación y PLEX_CREW_CONFIRMED=1 (plex-crew-rules)
PLEX_CREW_CONFIRMED=1 bash "$SO" remove 81189
PLEX_CREW_CONFIRMED=1 bash "$SO" remove 81189 --delete-files
```

## Filtros con jq

```bash
bash "$SO" search-json "breaking bad" | jq -r '.[] | "\(.tvdbId) \(.title) (\(.year))"'
bash "$SO" search-json "breaking bad" | jq -r '.[0].overview'
```

## curl directo (sin clave literal)

Prefiere siempre el script. Si necesitas curl, usa las variables y no imprimas la clave:

```bash
curl -s -H "X-Api-Key: $SONARR_API_KEY" "$SONARR_URL/api/v3/system/status" | jq '.version'
```

## Salidas habituales

| Comando | Salida |
|---------|--------|
| `search` | `1. Breaking Bad (2008) - https://thetvdb.com/dereferrer/series/81189` |
| `exists` | `not_found`, o `exists` y `ID: 12, Title: Breaking Bad, Seasons: 5` |
| `status` | `Sonarr 4.0.9.2244 - Sonarr (debian, branch main)` |
| `add` | `✅ Added: Breaking Bad (2008) - 5 seasons` y `🔍 Search started` |
| `remove` | `🗑️ Removed: Breaking Bad (2008) (files kept)` |
| `logs` | `2026-01-03T10:00:03Z  ERROR  Api  mensaje` |
| `health` | `Sin avisos de salud`, o `[warning] IndexerStatusCheck: mensaje` |
| `queue` | `En cola: 2` y `[123] Título del release - downloading/downloading - 45% - restante: 00:10:00 - torrent (cliente)` |
| `indexers` | `[1] Nombre (Torznab) - torrent - prioridad 25 - rss: true, auto: true, interactiva: true` |
| `downloadclients` | `[1] Nombre (QBittorrent) - torrent - prioridad 1 - activo: true` |
| `customformats` | `[1] <formato> - 1 condiciones` |
| `qualityprofiles` | `[<id>] <perfil> - minFormatScore: <n>, cutoffFormatScore: <n>` y debajo `    <formato>: <puntuación>` |

Códigos de salida: 0 correcto; 1 error de uso, serie no encontrada o fallo de conexión.
