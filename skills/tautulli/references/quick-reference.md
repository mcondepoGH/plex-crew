# Referencia rápida de Tautulli

## Configuración

```bash
# ~/.claude/plex-crew/.env
TAUTULLI_URL="http://localhost:8181"
TAUTULLI_API_KEY="<your_api_key>"
# Opcional: HOMELAB_ENV=/ruta/a/otro/.env
```

```bash
TA="${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh"
```

## Comandos del script

```bash
bash "$TA" server-info
bash "$TA" activity
bash "$TA" history --user ana --days 7 --limit 10
bash "$TA" history --media-type episode --search "dune"
bash "$TA" user-stats
bash "$TA" user-stats --sort-by plays --limit 5 --days 30
bash "$TA" libraries
bash "$TA" library-stats --section-id 1
bash "$TA" popular --days 30 --limit 10
bash "$TA" recent --section-id 2 --days 7 --limit 20
bash "$TA" home-stats --days 30
bash "$TA" plays-by-stream
bash "$TA" plays-by-platform --days 90
bash "$TA" plays-by-date --days 14
bash "$TA" plays-by-hour
bash "$TA" plays-by-day
bash "$TA" concurrent-streams --days 90 --peak
bash "$TA" metadata --rating-key 12345
bash "$TA" metadata --guid "plex://movie/..."
```

## Filtros con jq

```bash
bash "$TA" activity | jq -r '.response.data.sessions[] | "\(.friendly_name): \(.full_title)"'
bash "$TA" libraries | jq -r '.response.data[] | "\(.section_id) \(.section_name)"'
bash "$TA" history --days 7 | jq '.response.data.recordsFiltered'
```

## curl directo (sin clave literal)

Prefiere siempre el script. Si necesitas curl, usa las variables y no imprimas la clave:

```bash
curl -s -G --connect-timeout 10 --max-time 30 "$TAUTULLI_URL/api/v2" \
  --data-urlencode "apikey=$TAUTULLI_API_KEY" \
  --data-urlencode "cmd=get_server_info" | jq .
```
