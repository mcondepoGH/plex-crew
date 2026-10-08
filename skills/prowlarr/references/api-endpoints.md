# Referencia de la API de Prowlarr

**Versión de la API:** v1
**URL base:** `http://localhost:9696/api/v1`
**Autenticación:** cabecera X-Api-Key
**Última actualización:** 2026-02-01

## Autenticación

Prowlarr usa autenticación mediante clave de API. Encuentra tu clave de API en Settings → General → Security.

```bash
-H "X-Api-Key: <your_api_key>"
```

## Inicio rápido

Añade a `~/.claude/plex-crew/.env`:

```bash
PROWLARR_URL="http://localhost:9696"
PROWLARR_API_KEY="your-api-key"
```

Después prueba la conexión:

```bash
# Carga el .env (o reinicia tu shell)
source ~/.claude/plex-crew/.env

# Prueba la conexión: obtener el estado del sistema
curl -s "$PROWLARR_URL/api/v1/system/status" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

## Endpoints por categoría

### Sistema

#### GET /system/status

Obtiene el estado del sistema y la información de versión.

**Ejemplo de petición:**
```bash
curl -s "$PROWLARR_URL/api/v1/system/status" \
  -H "X-Api-Key: $PROWLARR_API_KEY"
```

**Ejemplo de respuesta:**
```json
{
  "version": "1.11.4.4173",
  "buildTime": "2024-01-15T10:30:00Z",
  "isDebug": false,
  "isProduction": true,
  "isAdmin": true,
  "isUserInteractive": false,
  "startupPath": "/app/prowlarr/bin",
  "appData": "/config",
  "osName": "ubuntu",
  "osVersion": "22.04",
  "isMonoRuntime": false,
  "isMono": false,
  "isLinux": true,
  "runtimeVersion": "6.0.25"
}
```

**Códigos de respuesta:**
- `200`: Correcto
- `401`: No autorizado

---

### Indexadores

#### GET /indexer

Obtiene todos los indexadores configurados.

**Ejemplo de petición:**
```bash
curl -s "$PROWLARR_URL/api/v1/indexer" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

**Ejemplo de respuesta:**
```json
[
  {
    "id": 1,
    "name": "The Pirate Bay",
    "fields": [],
    "implementationName": "ThePirateBay",
    "implementation": "ThePirateBay",
    "configContract": "ThePirateBaySettings",
    "infoLink": "https://wiki.servarr.com/prowlarr/supported#thepiratebay",
    "protocol": "torrent",
    "priority": 25,
    "enable": true,
    "redirect": false,
    "supportsRss": true,
    "supportsSearch": true,
    "tags": [],
    "added": "2024-01-01T00:00:00Z",
    "capabilities": {
      "categories": [],
      "supportsRawSearch": true
    }
  }
]
```

**Códigos de respuesta:**
- `200`: Correcto

---

#### GET /indexer/{id}

Obtiene un indexador concreto por su ID.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| id (path) | integer | Sí | ID del indexador |

**Ejemplo de petición:**
```bash
curl -s "$PROWLARR_URL/api/v1/indexer/1" \
  -H "X-Api-Key: $PROWLARR_API_KEY"
```

**Códigos de respuesta:**
- `200`: Correcto
- `404`: Indexador no encontrado

---

#### PUT /indexer/{id}

Actualiza la configuración de un indexador.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| id (path) | integer | Sí | ID del indexador |

**Ejemplo de petición:**
```bash
curl -X PUT "$PROWLARR_URL/api/v1/indexer/1" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "id": 1,
    "enable": false,
    "priority": 50
  }'
```

**Códigos de respuesta:**
- `202`: Actualizado
- `404`: No encontrado

---

#### DELETE /indexer/{id}

Elimina un indexador.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| id (path) | integer | Sí | ID del indexador |

**Ejemplo de petición:**
```bash
curl -X DELETE "$PROWLARR_URL/api/v1/indexer/1" \
  -H "X-Api-Key: $PROWLARR_API_KEY"
```

**Códigos de respuesta:**
- `200`: Eliminado
- `404`: No encontrado

---

#### POST /indexer/test

Prueba la configuración de un indexador.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| id (body) | integer | Sí | ID del indexador a probar |

**Ejemplo de petición:**
```bash
curl -X POST "$PROWLARR_URL/api/v1/indexer/test" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"id": 1}'
```

**Códigos de respuesta:**
- `200`: Prueba correcta
- `400`: La prueba falló (revisa la respuesta para ver los errores)

---

### Búsqueda

#### GET /search

Busca en todos los indexadores habilitados.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| query (query) | string | No | Consulta de búsqueda |
| type (query) | string | No | search, tvsearch, movie |
| categories (query) | string | No | IDs de categoría separados por comas |
| indexerIds (query) | string | No | IDs de indexador separados por comas |
| limit (query) | integer | No | Máximo de resultados por indexador |
| offset (query) | integer | No | Desplazamiento de los resultados |

**Ejemplo de petición:**
```bash
# Buscar en todos los indexadores
curl -s "$PROWLARR_URL/api/v1/search?query=ubuntu&type=search" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq

# Buscar en indexadores concretos
curl -s "$PROWLARR_URL/api/v1/search?query=inception&indexerIds=1,2,3" \
  -H "X-Api-Key: $PROWLARR_API_KEY"
```

**Ejemplo de respuesta:**
```json
[
  {
    "guid": "https://example.com/torrent/123",
    "indexerId": 1,
    "indexer": "The Pirate Bay",
    "title": "Ubuntu 22.04 Desktop ISO",
    "publishDate": "2024-01-01T00:00:00Z",
    "size": 3500000000,
    "grabs": 1500,
    "files": 1,
    "seeders": 250,
    "leechers": 15,
    "categories": [8000, 8010],
    "downloadUrl": "magnet:?xt=urn:btih:...",
    "infoUrl": "https://example.com/torrent/123",
    "indexerFlags": [],
    "protocol": "torrent"
  }
]
```

**Códigos de respuesta:**
- `200`: Correcto (devuelve un array, vacío si no hay resultados)

---

### Aplicaciones

#### GET /applications

Obtiene todas las aplicaciones conectadas (Sonarr, Radarr, etc.).

**Ejemplo de petición:**
```bash
curl -s "$PROWLARR_URL/api/v1/applications" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

**Ejemplo de respuesta:**
```json
[
  {
    "id": 1,
    "name": "Sonarr",
    "fields": [],
    "implementationName": "Sonarr",
    "implementation": "Sonarr",
    "configContract": "SonarrSettings",
    "infoLink": "https://wiki.servarr.com/prowlarr/supported#sonarr",
    "tags": [],
    "syncLevel": "addAndRemove"
  }
]
```

**Códigos de respuesta:**
- `200`: Correcto

---

#### POST /applications

Añade una aplicación nueva.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| name (body) | string | Sí | Nombre de la aplicación |
| implementation (body) | string | Sí | Sonarr, Radarr, Lidarr, Readarr |
| fields (body) | array | Sí | Campos de configuración |

**Ejemplo de petición:**
```bash
curl -X POST "$PROWLARR_URL/api/v1/applications" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sonarr",
    "implementation": "Sonarr",
    "configContract": "SonarrSettings",
    "fields": [
      {
        "name": "baseUrl",
        "value": "http://localhost:8989"
      },
      {
        "name": "apiKey",
        "value": "your-sonarr-api-key"
      }
    ],
    "syncLevel": "addAndRemove"
  }'
```

**Códigos de respuesta:**
- `201`: Aplicación añadida
- `400`: Petición incorrecta

---

#### POST /applications/test

Prueba la conexión con una aplicación.

**Ejemplo de petición:**
```bash
curl -X POST "$PROWLARR_URL/api/v1/applications/test" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sonarr",
    "implementation": "Sonarr",
    "fields": [
      {"name": "baseUrl", "value": "http://localhost:8989"},
      {"name": "apiKey", "value": "test-key"}
    ]
  }'
```

**Códigos de respuesta:**
- `200`: Prueba correcta
- `400`: La prueba falló

---

### Historial

#### GET /history

Obtiene el historial de búsquedas de los indexadores.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| page (query) | integer | No | Número de página |
| pageSize (query) | integer | No | Elementos por página |
| sortKey (query) | string | No | Campo por el que ordenar |
| sortDirection (query) | string | No | ascending, descending |

**Ejemplo de petición:**
```bash
curl -s "$PROWLARR_URL/api/v1/history?page=1&pageSize=20" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

**Ejemplo de respuesta:**
```json
{
  "page": 1,
  "pageSize": 20,
  "sortKey": "date",
  "sortDirection": "descending",
  "totalRecords": 150,
  "records": [
    {
      "id": 1,
      "indexerId": 1,
      "eventType": "indexerQuery",
      "date": "2026-02-01T10:00:00Z",
      "data": {
        "query": "ubuntu",
        "queryType": "search",
        "categories": [],
        "successful": true,
        "results": 50
      }
    }
  ]
}
```

**Códigos de respuesta:**
- `200`: Correcto

---

### Estadísticas

#### GET /indexerstats

Obtiene las estadísticas de los indexadores.

**Ejemplo de petición:**
```bash
curl -s "$PROWLARR_URL/api/v1/indexerstats" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

**Ejemplo de respuesta:**
```json
{
  "indexers": [
    {
      "indexerId": 1,
      "indexerName": "The Pirate Bay",
      "averageResponseTime": 250,
      "numberOfQueries": 1500,
      "numberOfGrabs": 75,
      "numberOfRssQueries": 300,
      "numberOfAuthQueries": 0,
      "numberOfFailedQueries": 5,
      "numberOfFailedGrabs": 2,
      "numberOfFailedRssQueries": 1
    }
  ]
}
```

**Códigos de respuesta:**
- `200`: Correcto

---

### Clientes de descarga

#### GET /downloadclient

Obtiene todos los clientes de descarga configurados.

**Ejemplo de petición:**
```bash
curl -s "$PROWLARR_URL/api/v1/downloadclient" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

**Códigos de respuesta:**
- `200`: Correcto

---

#### POST /downloadclient

Añade un cliente de descarga nuevo.

**Ejemplo de petición:**
```bash
curl -X POST "$PROWLARR_URL/api/v1/downloadclient" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "qBittorrent",
    "implementation": "QBittorrent",
    "configContract": "QBittorrentSettings",
    "fields": [
      {"name": "host", "value": "localhost"},
      {"name": "port", "value": "8080"},
      {"name": "username", "value": "admin"},
      {"name": "password", "value": "adminpass"}
    ],
    "enable": true,
    "protocol": "torrent",
    "priority": 1
  }'
```

**Códigos de respuesta:**
- `201`: Cliente de descarga añadido
- `400`: Petición incorrecta

---

### Etiquetas

#### GET /tag

Obtiene todas las etiquetas.

**Ejemplo de petición:**
```bash
curl -s "$PROWLARR_URL/api/v1/tag" \
  -H "X-Api-Key: $PROWLARR_API_KEY"
```

**Ejemplo de respuesta:**
```json
[
  {
    "id": 1,
    "label": "public"
  },
  {
    "id": 2,
    "label": "private"
  }
]
```

**Códigos de respuesta:**
- `200`: Correcto

---

#### POST /tag

Crea una etiqueta nueva.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| label (body) | string | Sí | Nombre de la etiqueta |

**Ejemplo de petición:**
```bash
curl -X POST "$PROWLARR_URL/api/v1/tag" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"label": "new-tag"}'
```

**Códigos de respuesta:**
- `201`: Etiqueta creada
- `400`: La etiqueta ya existe

---

## Tipos de búsqueda

- `search` - Búsqueda de texto general
- `tvsearch` - Búsqueda de series
- `movie` - Búsqueda de películas
- `music` - Búsqueda de música
- `book` - Búsqueda de libros

## Niveles de sincronización (aplicaciones)

- `disabled` - No sincronizar
- `addOnly` - Solo añadir indexadores nuevos
- `addAndRemove` - Añadir y eliminar indexadores (recomendado)
- `fullSync` - Sincronización bidireccional completa

## Paginación

Los endpoints de listado admiten paginación:
- `page`: número de página (empieza en 1)
- `pageSize`: elementos por página
- `sortKey`: campo por el que ordenar
- `sortDirection`: `ascending` o `descending`

## Historial de versiones

| Versión de la API | Versión del documento | Fecha | Cambios |
|-------------|-------------|------|---------|
| v1 | 1.0.0 | 2026-02-01 | Documentación inicial |

## Recursos adicionales

- [Wiki oficial](https://wiki.servarr.com/prowlarr)
- [Repositorio de GitHub](https://github.com/Prowlarr/Prowlarr)
- [Indexadores compatibles](https://wiki.servarr.com/prowlarr/supported)
- [Aplicaciones compatibles](https://wiki.servarr.com/prowlarr/supported-applications)
