# Referencia rápida de Plex

## Configuración

```bash
# ~/.claude/plex-crew/.env
PLEX_URL="http://localhost:32400"
PLEX_TOKEN="your-plex-token"
```

## Script

```bash
PLEX="${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh"

bash "$PLEX" info
bash "$PLEX" identity
bash "$PLEX" libraries
bash "$PLEX" library 1
bash "$PLEX" recent --limit 30
bash "$PLEX" ondeck -l 5
bash "$PLEX" search "dune" --limit 5
bash "$PLEX" metadata 12345
bash "$PLEX" children 12345
bash "$PLEX" sessions
bash "$PLEX" clients
bash "$PLEX" playlists
bash "$PLEX" accounts
bash "$PLEX" prefs
bash "$PLEX" refresh 1   # confirma antes con el usuario
bash "$PLEX" setpref autoEmptyTrash 1   # confirma antes con el usuario
```

## Filtros con jq

```bash
bash "$PLEX" libraries | jq '.MediaContainer.Directory[] | {key, title, type}'
bash "$PLEX" recent | jq -r '.MediaContainer.Metadata[] | "\(.ratingKey)\t\(.title)"'
bash "$PLEX" sessions | jq '.MediaContainer.Metadata[]? | {title, user: .User.title}'
```

## curl directo (solo con variables, nunca con el token escrito)

```bash
curl -s -H "Accept: application/json" -H "X-Plex-Token: $PLEX_TOKEN" "$PLEX_URL/library/sections"
```

Prefiere el script: así el token no queda en el historial ni en `ps`.
