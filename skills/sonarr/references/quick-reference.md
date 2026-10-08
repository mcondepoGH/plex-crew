# Referencia rápida de Sonarr

Operaciones habituales para copiar y pegar.

## Configuración

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
SONARR_URL="http://localhost:8989"
SONARR_API_KEY="<your_api_key>"
```

Cárgalas en los scripts:

```bash
source ~/.claude/plex-crew/.env
```

## Información del sistema

### Obtener el estado del sistema

```bash
curl -s "$SONARR_URL/api/v3/system/status" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq
```

### Obtener el espacio en disco

```bash
curl -s "$SONARR_URL/api/v3/diskspace" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq
```

## Gestión de series

### Obtener todas las series

```bash
curl -s "$SONARR_URL/api/v3/series" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq '.[] | {id, title, status, monitored}'
```

### Obtener una serie por ID

```bash
curl -s "$SONARR_URL/api/v3/series/1" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq
```

### Buscar una serie

```bash
curl -s "$SONARR_URL/api/v3/series/lookup?term=breaking%20bad" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq '.[] | {title, tvdbId, year}'
```

### Añadir una serie

```bash
curl -X POST "$SONARR_URL/api/v3/series" \
  -H "X-Api-Key: $SONARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Breaking Bad",
    "qualityProfileId": 1,
    "titleSlug": "breaking-bad",
    "tvdbId": 81189,
    "path": "/tv/Breaking Bad",
    "monitored": true,
    "seasonFolder": true,
    "addOptions": {
      "searchForMissingEpisodes": true
    }
  }'
```

### Actualizar una serie (activar/desactivar monitorización)

```bash
curl -X PUT "$SONARR_URL/api/v3/series/1" \
  -H "X-Api-Key: $SONARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "id": 1,
    "monitored": false
  }'
```

### Eliminar una serie

```bash
curl -X DELETE "$SONARR_URL/api/v3/series/1?deleteFiles=false" \
  -H "X-Api-Key: $SONARR_API_KEY"
```

## Gestión de episodios

### Obtener todos los episodios de una serie

```bash
curl -s "$SONARR_URL/api/v3/episode?seriesId=1" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq '.[] | {id, seasonNumber, episodeNumber, title, hasFile}'
```

### Obtener un episodio por ID

```bash
curl -s "$SONARR_URL/api/v3/episode/100" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq
```

### Monitorizar/dejar de monitorizar un episodio

```bash
curl -X PUT "$SONARR_URL/api/v3/episode/100" \
  -H "X-Api-Key: $SONARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "id": 100,
    "monitored": true
  }'
```

## Cola y descargas

### Obtener la cola (descargas activas)

```bash
curl -s "$SONARR_URL/api/v3/queue" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq '.records[] | {title, status, sizeleft, timeleft}'
```

### Eliminar un elemento de la cola

```bash
curl -X DELETE "$SONARR_URL/api/v3/queue/1?removeFromClient=true&blocklist=false" \
  -H "X-Api-Key: $SONARR_API_KEY"
```

## Búsqueda y descarga

### Buscar los episodios de una serie

```bash
curl -X POST "$SONARR_URL/api/v3/command" \
  -H "X-Api-Key: $SONARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "SeriesSearch",
    "seriesId": 1
  }'
```

### Buscar un episodio concreto

```bash
curl -X POST "$SONARR_URL/api/v3/command" \
  -H "X-Api-Key: $SONARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "EpisodeSearch",
    "episodeIds": [100]
  }'
```

### Búsqueda manual (obtener la lista de releases)

```bash
curl -s "$SONARR_URL/api/v3/release?episodeId=100" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq '.[] | {title, size, quality, indexer}'
```

### Descargar un release

```bash
curl -X POST "$SONARR_URL/api/v3/release" \
  -H "X-Api-Key: $SONARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "guid": "release-guid-from-manual-search",
    "indexerId": 1
  }'
```

## Calendario

### Obtener los próximos episodios (próximos 7 días)

```bash
START=$(date -u +%Y-%m-%d)
END=$(date -u -d '+7 days' +%Y-%m-%d)
curl -s "$SONARR_URL/api/v3/calendar?start=$START&end=$END" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq '.[] | {series: .series.title, episode: .title, airDate}'
```

## Historial

### Obtener el historial reciente

```bash
curl -s "$SONARR_URL/api/v3/history?page=1&pageSize=20" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq '.records[] | {date, eventType, series: .series.title, episode: .episode.title}'
```

## Perfiles de calidad

### Obtener todos los perfiles de calidad

```bash
curl -s "$SONARR_URL/api/v3/qualityprofile" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq '.[] | {id, name}'
```

## Carpetas raíz

### Obtener las carpetas raíz

```bash
curl -s "$SONARR_URL/api/v3/rootfolder" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq '.[] | {id, path, freeSpace}'
```

## Flujos de trabajo

### Flujo de trabajo: añadir una serie y buscarla

1. **Busca la serie:**
   ```bash
   curl -s "$SONARR_URL/api/v3/series/lookup?term=breaking%20bad" \
     -H "X-Api-Key: $SONARR_API_KEY" | jq '.[0] | {title, tvdbId, year}'
   ```

2. **Añade la serie con búsqueda:**
   ```bash
   curl -X POST "$SONARR_URL/api/v3/series" \
     -H "X-Api-Key: $SONARR_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "title": "Breaking Bad",
       "qualityProfileId": 1,
       "titleSlug": "breaking-bad",
       "tvdbId": 81189,
       "path": "/tv/Breaking Bad",
       "monitored": true,
       "seasonFolder": true,
       "addOptions": {
         "searchForMissingEpisodes": true
       }
     }' | jq '.id'
   ```

3. **Comprueba la cola de descargas:**
   ```bash
   curl -s "$SONARR_URL/api/v3/queue" \
     -H "X-Api-Key: $SONARR_API_KEY" | jq '.records[] | {title, status}'
   ```

### Flujo de trabajo: actualizar todas las series

```bash
curl -X POST "$SONARR_URL/api/v3/command" \
  -H "X-Api-Key: $SONARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "RefreshSeries"}'
```

### Flujo de trabajo: monitorizar temporadas en lote

```bash
# Monitorizar todos los episodios de la temporada 1 de la serie con ID 1
curl -s "$SONARR_URL/api/v3/episode?seriesId=1" \
  -H "X-Api-Key: $SONARR_API_KEY" | \
  jq -r '.[] | select(.seasonNumber == 1) | .id' | \
  while read episode_id; do
    curl -X PUT "$SONARR_URL/api/v3/episode/$episode_id" \
      -H "X-Api-Key: $SONARR_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"id\": $episode_id, \"monitored\": true}"
    sleep 0.5
  done
```

### Flujo de trabajo: limpiar descargas fallidas

```bash
# Obtener los elementos fallidos de la cola
curl -s "$SONARR_URL/api/v3/queue" \
  -H "X-Api-Key: $SONARR_API_KEY" | \
  jq -r '.records[] | select(.status == "failed") | .id' | \
  while read queue_id; do
    echo "Removing failed item $queue_id"
    curl -X DELETE "$SONARR_URL/api/v3/queue/$queue_id?removeFromClient=true&blocklist=true" \
      -H "X-Api-Key: $SONARR_API_KEY"
  done
```
