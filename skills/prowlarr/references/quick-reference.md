# Referencia rápida de Prowlarr

Operaciones habituales para copiar y pegar.

## Configuración

Añade a `~/.claude/plex-crew/.env`:

```bash
PROWLARR_URL="http://localhost:9696"
PROWLARR_API_KEY="your-api-key"
```

Los ejemplos siguientes usan estas variables de entorno.

## Información del sistema

### Obtener el estado del sistema

```bash
curl -s "$PROWLARR_URL/api/v1/system/status" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

## Gestión de indexadores

### Obtener todos los indexadores

```bash
curl -s "$PROWLARR_URL/api/v1/indexer" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq '.[] | {id, name, enable, protocol}'
```

### Obtener un indexador por ID

```bash
curl -s "$PROWLARR_URL/api/v1/indexer/1" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

### Obtener el esquema de indexadores (indexadores disponibles)

```bash
curl -s "$PROWLARR_URL/api/v1/indexer/schema" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq '.[] | {implementationName, protocol}'
```

### Añadir un indexador

```bash
curl -X POST "$PROWLARR_URL/api/v1/indexer" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "1337x",
    "implementationName": "1337x",
    "implementation": "1337x",
    "configContract": "1337xSettings",
    "protocol": "torrent",
    "priority": 25,
    "enable": true,
    "fields": []
  }'
```

### Actualizar un indexador

```bash
curl -X PUT "$PROWLARR_URL/api/v1/indexer/1" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "id": 1,
    "enable": false
  }'
```

### Probar un indexador

```bash
curl -X POST "$PROWLARR_URL/api/v1/indexer/test" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "id": 1
  }'
```

### Eliminar un indexador

```bash
curl -X DELETE "$PROWLARR_URL/api/v1/indexer/1" \
  -H "X-Api-Key: $PROWLARR_API_KEY"
```

## Búsqueda

### Buscar en todos los indexadores

```bash
curl -s "$PROWLARR_URL/api/v1/search?query=ubuntu&type=search" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq '.[] | {title, indexer, seeders, size}'
```

### Buscar en un indexador concreto

```bash
curl -s "$PROWLARR_URL/api/v1/search?query=ubuntu&indexerIds=1" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

### Búsqueda de películas (TMDB)

```bash
curl -s "$PROWLARR_URL/api/v1/search?query=inception&type=movie&tmdbId=27205" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

### Búsqueda de series (TVDB)

```bash
curl -s "$PROWLARR_URL/api/v1/search?query=breaking%20bad&type=tvsearch&tvdbId=81189" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

## Aplicaciones (sincronización con Sonarr/Radarr)

### Obtener todas las aplicaciones

```bash
curl -s "$PROWLARR_URL/api/v1/applications" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq '.[] | {id, name, implementation, syncLevel}'
```

### Añadir una aplicación (Sonarr)

```bash
curl -X POST "$PROWLARR_URL/api/v1/applications" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sonarr",
    "implementation": "Sonarr",
    "configContract": "SonarrSettings",
    "syncLevel": "fullSync",
    "fields": [
      {"name": "baseUrl", "value": "http://sonarr:8989"},
      {"name": "apiKey", "value": "SONARR_API_KEY"},
      {"name": "syncCategories", "value": [5000, 5030, 5040]}
    ]
  }'
```

### Añadir una aplicación (Radarr)

```bash
curl -X POST "$PROWLARR_URL/api/v1/applications" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Radarr",
    "implementation": "Radarr",
    "configContract": "RadarrSettings",
    "syncLevel": "fullSync",
    "fields": [
      {"name": "baseUrl", "value": "http://radarr:7878"},
      {"name": "apiKey", "value": "RADARR_API_KEY"},
      {"name": "syncCategories", "value": [2000, 2040, 2050]}
    ]
  }'
```

### Probar una aplicación

```bash
curl -X POST "$PROWLARR_URL/api/v1/applications/test" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "id": 1
  }'
```

### Sincronizar las aplicaciones

```bash
curl -X POST "$PROWLARR_URL/api/v1/command" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ApplicationSync"
  }'
```

## Clientes de descarga

### Obtener todos los clientes de descarga

```bash
curl -s "$PROWLARR_URL/api/v1/downloadclient" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq '.[] | {id, name, implementation, protocol}'
```

### Añadir un cliente de descarga (qBittorrent)

```bash
curl -X POST "$PROWLARR_URL/api/v1/downloadclient" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "qBittorrent",
    "implementation": "QBittorrent",
    "configContract": "QBittorrentSettings",
    "protocol": "torrent",
    "fields": [
      {"name": "host", "value": "qbittorrent"},
      {"name": "port", "value": 8080},
      {"name": "username", "value": "admin"},
      {"name": "password", "value": "adminpass"}
    ]
  }'
```

## Estadísticas

### Obtener las estadísticas de los indexadores

```bash
curl -s "$PROWLARR_URL/api/v1/indexerstats" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq '.indexers[] | {indexerName, averageResponseTime, numberOfQueries, numberOfGrabs}'
```

## Historial

### Obtener el historial reciente

```bash
curl -s "$PROWLARR_URL/api/v1/history?page=1&pageSize=20" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq '.records[] | {date, eventType, indexer: .indexer.name}'
```

### Obtener el historial por indexador

```bash
curl -s "$PROWLARR_URL/api/v1/history?indexerId=1" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

## Etiquetas

### Obtener todas las etiquetas

```bash
curl -s "$PROWLARR_URL/api/v1/tag" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

### Crear una etiqueta

```bash
curl -X POST "$PROWLARR_URL/api/v1/tag" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "public-trackers"
  }'
```

## Notificaciones

### Obtener todas las notificaciones

```bash
curl -s "$PROWLARR_URL/api/v1/notification" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq '.[] | {id, name, implementation}'
```

## Flujos de trabajo

### Flujo de trabajo: añadir un indexador y sincronizarlo con las aplicaciones

1. **Obtener los esquemas de indexadores disponibles:**
   ```bash
   curl -s "$PROWLARR_URL/api/v1/indexer/schema" \
     -H "X-Api-Key: $PROWLARR_API_KEY" | \
     jq '.[] | select(.implementationName == "1337x")'
   ```

2. **Añadir el indexador:**
   ```bash
   curl -X POST "$PROWLARR_URL/api/v1/indexer" \
     -H "X-Api-Key: $PROWLARR_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "1337x",
       "implementationName": "1337x",
       "implementation": "1337x",
       "configContract": "1337xSettings",
       "protocol": "torrent",
       "priority": 25,
       "enable": true,
       "fields": []
     }' | jq '.id'
   ```

3. **Sincronizar con las aplicaciones:**
   ```bash
   curl -X POST "$PROWLARR_URL/api/v1/command" \
     -H "X-Api-Key: $PROWLARR_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"name": "ApplicationSync"}'
   ```

### Flujo de trabajo: probar todos los indexadores

```bash
curl -s "$PROWLARR_URL/api/v1/indexer" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | \
  jq -r '.[].id' | \
  while read indexer_id; do
    echo "Testing indexer ID $indexer_id"
    curl -X POST "$PROWLARR_URL/api/v1/indexer/test" \
      -H "X-Api-Key: $PROWLARR_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"id\": $indexer_id}" 2>&1 | \
      grep -q "200" && echo "  ✓ Passed" || echo "  ✗ Failed"
    sleep 1
  done
```

### Flujo de trabajo: deshabilitar todos los indexadores con fallos

```bash
# Obtener las estadísticas de los indexadores y deshabilitar los que tengan errores
curl -s "$PROWLARR_URL/api/v1/indexerstats" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | \
  jq -r '.indexers[] | select(.numberOfFailures > 5) | .indexerId' | \
  while read indexer_id; do
    echo "Disabling indexer ID $indexer_id due to failures"

    # Obtener la configuración actual del indexador
    indexer=$(curl -s "$PROWLARR_URL/api/v1/indexer/$indexer_id" \
      -H "X-Api-Key: $PROWLARR_API_KEY")

    # Actualizar para deshabilitarlo
    echo "$indexer" | jq '.enable = false' | \
    curl -X PUT "$PROWLARR_URL/api/v1/indexer/$indexer_id" \
      -H "X-Api-Key: $PROWLARR_API_KEY" \
      -H "Content-Type: application/json" \
      -d @-
  done
```

### Flujo de trabajo: importación masiva de indexadores desde una lista

```bash
# Ejemplo: importar varios trackers públicos
INDEXERS=("1337x" "EZTV" "ThePirateBay" "RARBG")

for indexer_name in "${INDEXERS[@]}"; do
  echo "Adding $indexer_name"

  curl -X POST "$PROWLARR_URL/api/v1/indexer" \
    -H "X-Api-Key: $PROWLARR_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"$indexer_name\",
      \"implementationName\": \"$indexer_name\",
      \"implementation\": \"$indexer_name\",
      \"configContract\": \"${indexer_name}Settings\",
      \"protocol\": \"torrent\",
      \"priority\": 25,
      \"enable\": true,
      \"fields\": []
    }"

  sleep 1
done

# Sincronizar con las aplicaciones
curl -X POST "$PROWLARR_URL/api/v1/command" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "ApplicationSync"}'
```

### Flujo de trabajo: comparación de búsquedas entre indexadores

```bash
QUERY="ubuntu"

# Obtener todos los indexadores habilitados
indexers=$(curl -s "$PROWLARR_URL/api/v1/indexer" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | \
  jq -r '.[] | select(.enable == true) | .id')

# Buscar en cada indexador
for indexer_id in $indexers; do
  indexer_name=$(curl -s "$PROWLARR_URL/api/v1/indexer/$indexer_id" \
    -H "X-Api-Key: $PROWLARR_API_KEY" | jq -r '.name')

  echo "Searching $indexer_name (ID: $indexer_id)"

  results=$(curl -s "$PROWLARR_URL/api/v1/search?query=$QUERY&indexerIds=$indexer_id" \
    -H "X-Api-Key: $PROWLARR_API_KEY" | jq 'length')

  echo "  Found $results results"
  echo ""
done
```
