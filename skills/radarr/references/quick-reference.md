# Referencia rápida de Radarr

Operaciones comunes para copiar y pegar rápidamente.

## Configuración

```bash
export RADARR_URL="http://localhost:7878"
export RADARR_API_KEY="your-api-key"
```

## Información del sistema

### Obtener el estado del sistema

```bash
curl -s "$RADARR_URL/api/v3/system/status" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq
```

### Obtener el espacio en disco

```bash
curl -s "$RADARR_URL/api/v3/diskspace" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq
```

## Gestión de películas

### Obtener todas las películas

```bash
curl -s "$RADARR_URL/api/v3/movie" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq '.[] | {id, title, year, hasFile, monitored}'
```

### Obtener una película por ID

```bash
curl -s "$RADARR_URL/api/v3/movie/1" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq
```

### Buscar una película

```bash
curl -s "$RADARR_URL/api/v3/movie/lookup?term=inception" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq '.[] | {title, tmdbId, year}'
```

### Añadir una película

```bash
curl -X POST "$RADARR_URL/api/v3/movie" \
  -H "X-Api-Key: $RADARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Inception",
    "qualityProfileId": 1,
    "titleSlug": "inception-2010",
    "tmdbId": 27205,
    "path": "/movies/Inception (2010)",
    "monitored": true,
    "addOptions": {
      "searchForMovie": true
    }
  }'
```

### Actualizar una película (activar/desactivar monitorización)

```bash
curl -X PUT "$RADARR_URL/api/v3/movie/1" \
  -H "X-Api-Key: $RADARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "id": 1,
    "monitored": false
  }'
```

### Eliminar una película

```bash
curl -X DELETE "$RADARR_URL/api/v3/movie/1?deleteFiles=false&addImportExclusion=false" \
  -H "X-Api-Key: $RADARR_API_KEY"
```

## Cola y descargas

### Obtener la cola (descargas activas)

```bash
curl -s "$RADARR_URL/api/v3/queue" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq '.records[] | {title, status, sizeleft, timeleft}'
```

### Eliminar un elemento de la cola

```bash
curl -X DELETE "$RADARR_URL/api/v3/queue/1?removeFromClient=true&blocklist=false" \
  -H "X-Api-Key: $RADARR_API_KEY"
```

## Búsqueda y descarga

### Buscar una película

```bash
curl -X POST "$RADARR_URL/api/v3/command" \
  -H "X-Api-Key: $RADARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "MoviesSearch",
    "movieIds": [1]
  }'
```

### Búsqueda manual (obtener la lista de releases)

```bash
curl -s "$RADARR_URL/api/v3/release?movieId=1" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq '.[] | {title, size, quality, indexer}'
```

### Descargar un release

```bash
curl -X POST "$RADARR_URL/api/v3/release" \
  -H "X-Api-Key: $RADARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "guid": "release-guid-from-manual-search",
    "indexerId": 1
  }'
```

## Calendario

### Obtener los próximos estrenos (en cines)

```bash
START=$(date -u +%Y-%m-%d)
END=$(date -u -d '+30 days' +%Y-%m-%d)
curl -s "$RADARR_URL/api/v3/calendar?start=$START&end=$END" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq '.[] | {title, inCinemas, physicalRelease}'
```

## Historial

### Obtener el historial reciente

```bash
curl -s "$RADARR_URL/api/v3/history?page=1&pageSize=20" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq '.records[] | {date, eventType, movie: .movie.title}'
```

## Perfiles de calidad

### Obtener todos los perfiles de calidad

```bash
curl -s "$RADARR_URL/api/v3/qualityprofile" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq '.[] | {id, name}'
```

## Carpetas raíz

### Obtener las carpetas raíz

```bash
curl -s "$RADARR_URL/api/v3/rootfolder" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq '.[] | {id, path, freeSpace}'
```

## Listas de importación

### Obtener todas las listas de importación

```bash
curl -s "$RADARR_URL/api/v3/importlist" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq '.[] | {id, name, enabled}'
```

### Lanzar la sincronización de listas de importación

```bash
curl -X POST "$RADARR_URL/api/v3/command" \
  -H "X-Api-Key: $RADARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ImportListSync"
  }'
```

## Colecciones

### Obtener todas las colecciones

```bash
curl -s "$RADARR_URL/api/v3/collection" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq '.[] | {id, title, monitored}'
```

### Actualizar una colección

```bash
curl -X PUT "$RADARR_URL/api/v3/collection/1" \
  -H "X-Api-Key: $RADARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "id": 1,
    "monitored": true,
    "searchOnAdd": true
  }'
```

## Flujos de trabajo

### Flujo de trabajo: añadir una película y buscarla

1. **Buscar la película:**
   ```bash
   curl -s "$RADARR_URL/api/v3/movie/lookup?term=inception" \
     -H "X-Api-Key: $RADARR_API_KEY" | jq '.[0] | {title, tmdbId, year}'
   ```

2. **Añadir la película con búsqueda:**
   ```bash
   curl -X POST "$RADARR_URL/api/v3/movie" \
     -H "X-Api-Key: $RADARR_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "title": "Inception",
       "qualityProfileId": 1,
       "titleSlug": "inception-2010",
       "tmdbId": 27205,
       "path": "/movies/Inception (2010)",
       "monitored": true,
       "addOptions": {
         "searchForMovie": true
       }
     }' | jq '.id'
   ```

3. **Comprobar la cola para ver la descarga:**
   ```bash
   curl -s "$RADARR_URL/api/v3/queue" \
     -H "X-Api-Key: $RADARR_API_KEY" | jq '.records[] | {title, status}'
   ```

### Flujo de trabajo: actualizar todas las películas

```bash
curl -X POST "$RADARR_URL/api/v3/command" \
  -H "X-Api-Key: $RADARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "RefreshMovie"}'
```

### Flujo de trabajo: añadir películas en lote desde una lista

```bash
# Example: Add all movies from a TMDB list
curl -s "https://api.themoviedb.org/3/list/<your_list_id>?api_key=<your_tmdb_key>" | \
  jq -r '.items[] | @json' | \
  while read movie; do
    tmdb_id=$(echo "$movie" | jq -r '.id')
    title=$(echo "$movie" | jq -r '.title')
    year=$(echo "$movie" | jq -r '.release_date' | cut -d'-' -f1)

    echo "Adding: $title ($year)"

    curl -X POST "$RADARR_URL/api/v3/movie" \
      -H "X-Api-Key: $RADARR_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{
        \"title\": \"$title\",
        \"qualityProfileId\": 1,
        \"titleSlug\": \"$(echo $title | tr '[:upper:]' '[:lower:]' | tr ' ' '-')-$year\",
        \"tmdbId\": $tmdb_id,
        \"path\": \"/movies/$title ($year)\",
        \"monitored\": true,
        \"addOptions\": {
          \"searchForMovie\": false
        }
      }"
    sleep 1
  done
```

### Flujo de trabajo: monitorizar una colección completa

```bash
# Get collection ID
collection_id=$(curl -s "$RADARR_URL/api/v3/collection" \
  -H "X-Api-Key: $RADARR_API_KEY" | \
  jq -r '.[] | select(.title == "The Matrix Collection") | .id')

# Monitor collection
curl -X PUT "$RADARR_URL/api/v3/collection/$collection_id" \
  -H "X-Api-Key: $RADARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": $collection_id,
    \"monitored\": true,
    \"searchOnAdd\": true
  }"
```

### Flujo de trabajo: limpiar descargas fallidas

```bash
# Get failed items from queue
curl -s "$RADARR_URL/api/v3/queue" \
  -H "X-Api-Key: $RADARR_API_KEY" | \
  jq -r '.records[] | select(.status == "failed") | .id' | \
  while read queue_id; do
    echo "Removing failed item $queue_id"
    curl -X DELETE "$RADARR_URL/api/v3/queue/$queue_id?removeFromClient=true&blocklist=true" \
      -H "X-Api-Key: $RADARR_API_KEY"
  done
```

### Flujo de trabajo: mejorar películas por debajo del corte de calidad

```bash
# Get movies that can be upgraded
curl -s "$RADARR_URL/api/v3/wanted/cutoff?pageSize=100" \
  -H "X-Api-Key: $RADARR_API_KEY" | \
  jq -r '.records[].id' | \
  while read movie_id; do
    echo "Searching for upgrades for movie ID $movie_id"
    curl -X POST "$RADARR_URL/api/v3/command" \
      -H "X-Api-Key: $RADARR_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{
        \"name\": \"MoviesSearch\",
        \"movieIds\": [$movie_id]
      }"
    sleep 2
  done
```
