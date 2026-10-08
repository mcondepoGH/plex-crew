# Referencia de la API de Radarr

**Versión de la API:** v3
**URL base:** `http://localhost:7878/api/v3`
**Autenticación:** cabecera X-Api-Key
**Última actualización:** 2026-02-01

## Autenticación

Radarr usa autenticación mediante clave de API. Encuentra tu clave de API en Settings → General → Security.

```bash
-H "X-Api-Key: <your_api_key>"
```

## Inicio rápido

```bash
# Set environment variables
export RADARR_URL="http://localhost:7878"
export RADARR_API_KEY="your-api-key"

# Test connection - get system status
curl -s "$RADARR_URL/api/v3/system/status" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq
```

## Endpoints por categoría

### Sistema

#### GET /system/status

Obtiene el estado del sistema y la información de versión.

**Ejemplo de petición:**
```bash
curl -s "$RADARR_URL/api/v3/system/status" \
  -H "X-Api-Key: $RADARR_API_KEY"
```

**Ejemplo de respuesta:**
```json
{
  "version": "5.2.6.8376",
  "buildTime": "2024-01-15T10:30:00Z",
  "isDebug": false,
  "isProduction": true,
  "isAdmin": true,
  "isUserInteractive": false,
  "startupPath": "/app/radarr/bin",
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

### Películas

#### GET /movie

Obtiene todas las películas de la biblioteca.

**Ejemplo de petición:**
```bash
curl -s "$RADARR_URL/api/v3/movie" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq
```

**Ejemplo de respuesta:**
```json
[
  {
    "id": 1,
    "title": "Inception",
    "originalTitle": "Inception",
    "sortTitle": "inception",
    "sizeOnDisk": 15000000000,
    "status": "released",
    "overview": "A thief who steals corporate secrets...",
    "inCinemas": "2010-07-16T00:00:00Z",
    "physicalRelease": "2010-12-07T00:00:00Z",
    "digitalRelease": "2010-11-30T00:00:00Z",
    "images": [],
    "website": "http://www.inceptionmovie.com/",
    "year": 2010,
    "hasFile": true,
    "youTubeTrailerId": "8hP9D6kZseM",
    "studio": "Warner Bros.",
    "path": "/movies/Inception (2010)",
    "qualityProfileId": 1,
    "monitored": true,
    "minimumAvailability": "released",
    "isAvailable": true,
    "folderName": "Inception (2010)",
    "runtime": 148,
    "cleanTitle": "inception",
    "imdbId": "tt1375666",
    "tmdbId": 27205,
    "titleSlug": "inception-2010",
    "certification": "PG-13",
    "genres": ["Action", "Science Fiction", "Thriller"],
    "tags": [],
    "added": "2024-01-01T00:00:00Z",
    "ratings": {
      "imdb": {
        "votes": 2300000,
        "value": 8.8
      },
      "tmdb": {
        "votes": 35000,
        "value": 8.4
      }
    }
  }
]
```

**Códigos de respuesta:**
- `200`: Correcto

---

#### GET /movie/{id}

Obtiene una película concreta por su ID.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| id (path) | integer | Sí | ID de la película |

**Ejemplo de petición:**
```bash
curl -s "$RADARR_URL/api/v3/movie/1" \
  -H "X-Api-Key: $RADARR_API_KEY"
```

**Códigos de respuesta:**
- `200`: Correcto
- `404`: Película no encontrada

---

#### POST /movie

Añade una película nueva a la biblioteca.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| tmdbId (body) | integer | Sí | ID de TMDB |
| title (body) | string | Sí | Título de la película |
| qualityProfileId (body) | integer | Sí | ID del perfil de calidad |
| path (body) | string | Sí | Ruta de la carpeta raíz |
| monitored (body) | boolean | No | Monitorizar la película (por defecto: true) |
| minimumAvailability (body) | string | No | announced, inCinemas, released (por defecto) |
| addOptions (body) | object | No | Opciones de importación |

**Ejemplo de petición:**
```bash
curl -X POST "$RADARR_URL/api/v3/movie" \
  -H "X-Api-Key: $RADARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "tmdbId": 27205,
    "title": "Inception",
    "year": 2010,
    "qualityProfileId": 1,
    "path": "/movies/Inception (2010)",
    "monitored": true,
    "minimumAvailability": "released",
    "addOptions": {
      "searchForMovie": true
    }
  }'
```

**Códigos de respuesta:**
- `201`: Película añadida
- `400`: Petición incorrecta
- `409`: La película ya existe

---

#### PUT /movie/{id}

Actualiza la información de una película.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| id (path) | integer | Sí | ID de la película |

**Ejemplo de petición:**
```bash
curl -X PUT "$RADARR_URL/api/v3/movie/1" \
  -H "X-Api-Key: $RADARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "id": 1,
    "monitored": false,
    "qualityProfileId": 2,
    "minimumAvailability": "inCinemas"
  }'
```

**Códigos de respuesta:**
- `202`: Actualizada
- `404`: No encontrada

---

#### DELETE /movie/{id}

Elimina una película de la biblioteca.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| id (path) | integer | Sí | ID de la película |
| deleteFiles (query) | boolean | No | Eliminar los archivos (por defecto: false) |
| addImportExclusion (query) | boolean | No | Añadir a las exclusiones de importación (por defecto: false) |

**Ejemplo de petición:**
```bash
# Delete movie but keep files
curl -X DELETE "$RADARR_URL/api/v3/movie/1" \
  -H "X-Api-Key: $RADARR_API_KEY"

# Delete movie and files
curl -X DELETE "$RADARR_URL/api/v3/movie/1?deleteFiles=true" \
  -H "X-Api-Key: $RADARR_API_KEY"
```

**Códigos de respuesta:**
- `200`: Eliminada
- `404`: No encontrada

---

### Cola

#### GET /queue

Obtiene la cola de descargas actual.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| page (query) | integer | No | Número de página |
| pageSize (query) | integer | No | Elementos por página |
| includeUnknownMovieItems (query) | boolean | No | Incluir elementos sin película asociada |

**Ejemplo de petición:**
```bash
curl -s "$RADARR_URL/api/v3/queue" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq
```

**Ejemplo de respuesta:**
```json
{
  "page": 1,
  "pageSize": 10,
  "sortKey": "timeleft",
  "sortDirection": "ascending",
  "totalRecords": 3,
  "records": [
    {
      "id": 1,
      "movieId": 1,
      "movie": {
        "title": "Inception"
      },
      "quality": {
        "quality": {
          "name": "Bluray-1080p"
        }
      },
      "size": 15000000000,
      "title": "Inception.2010.1080p.BluRay.x264",
      "sizeleft": 7500000000,
      "timeleft": "00:25:30",
      "estimatedCompletionTime": "2026-02-01T12:00:00Z",
      "status": "downloading",
      "trackedDownloadStatus": "ok",
      "downloadId": "abc123",
      "protocol": "torrent",
      "downloadClient": "qBittorrent"
    }
  ]
}
```

**Códigos de respuesta:**
- `200`: Correcto

---

#### DELETE /queue/{id}

Elimina un elemento de la cola.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| id (path) | integer | Sí | ID del elemento de la cola |
| removeFromClient (query) | boolean | No | Eliminar del cliente de descargas |
| blocklist (query) | boolean | No | Añadir a la lista de bloqueo |

**Ejemplo de petición:**
```bash
curl -X DELETE "$RADARR_URL/api/v3/queue/1?removeFromClient=true&blocklist=false" \
  -H "X-Api-Key: $RADARR_API_KEY"
```

**Códigos de respuesta:**
- `200`: Eliminado

---

### Comandos

#### POST /command

Ejecuta un comando.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| name (body) | string | Sí | Nombre del comando |

**Comandos comunes:**
- `RefreshMovie`: Actualiza la información de la película
- `RescanMovie`: Vuelve a escanear la carpeta de la película
- `MoviesSearch`: Busca todas las películas que faltan
- `RssSync`: Sincroniza los feeds RSS
- `DownloadedMoviesScan`: Escanea la carpeta de descargas

**Ejemplo de petición (buscar película):**
```bash
curl -X POST "$RADARR_URL/api/v3/command" \
  -H "X-Api-Key: $RADARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "MoviesSearch",
    "movieIds": [1, 2, 3]
  }'
```

**Ejemplo de petición (actualizar película):**
```bash
curl -X POST "$RADARR_URL/api/v3/command" \
  -H "X-Api-Key: $RADARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "RefreshMovie",
    "movieId": 1
  }'
```

**Códigos de respuesta:**
- `201`: Comando en cola

---

### Perfiles de calidad

#### GET /qualityprofile

Obtiene todos los perfiles de calidad.

**Ejemplo de petición:**
```bash
curl -s "$RADARR_URL/api/v3/qualityprofile" \
  -H "X-Api-Key: $RADARR_API_KEY"
```

**Ejemplo de respuesta:**
```json
[
  {
    "id": 1,
    "name": "HD-1080p",
    "upgradeAllowed": true,
    "cutoff": 7,
    "items": [
      {
        "quality": {
          "id": 7,
          "name": "Bluray-1080p"
        },
        "allowed": true
      }
    ]
  }
]
```

**Códigos de respuesta:**
- `200`: Correcto

---

### Carpetas raíz

#### GET /rootfolder

Obtiene todas las carpetas raíz.

**Ejemplo de petición:**
```bash
curl -s "$RADARR_URL/api/v3/rootfolder" \
  -H "X-Api-Key: $RADARR_API_KEY"
```

**Ejemplo de respuesta:**
```json
[
  {
    "id": 1,
    "path": "/movies",
    "accessible": true,
    "freeSpace": 500000000000,
    "totalSpace": 1000000000000,
    "unmappedFolders": []
  }
]
```

**Códigos de respuesta:**
- `200`: Correcto

---

### Calendario

#### GET /calendar

Obtiene los próximos estrenos de películas.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| start (query) | string | No | Fecha de inicio (ISO 8601) |
| end (query) | string | No | Fecha de fin (ISO 8601) |
| unmonitored (query) | boolean | No | Incluir no monitorizadas (por defecto: false) |

**Ejemplo de petición:**
```bash
curl -s "$RADARR_URL/api/v3/calendar?start=2026-02-01&end=2026-02-28" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq
```

**Códigos de respuesta:**
- `200`: Correcto

---

### Búsqueda

#### GET /movie/lookup

Busca películas.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| term (query) | string | Sí | Término de búsqueda o tmdb:ID o imdb:ID |

**Ejemplo de petición:**
```bash
# Search by name
curl -s "$RADARR_URL/api/v3/movie/lookup?term=inception" \
  -H "X-Api-Key: $RADARR_API_KEY" | jq

# Search by TMDB ID
curl -s "$RADARR_URL/api/v3/movie/lookup?term=tmdb:27205" \
  -H "X-Api-Key: $RADARR_API_KEY"

# Search by IMDB ID
curl -s "$RADARR_URL/api/v3/movie/lookup?term=imdb:tt1375666" \
  -H "X-Api-Key: $RADARR_API_KEY"
```

**Códigos de respuesta:**
- `200`: Correcto (devuelve un array, vacío si no hay coincidencias)

---

### Historial

#### GET /history/movie

Obtiene el historial de una película concreta.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| movieId (query) | integer | Sí | ID de la película |

**Ejemplo de petición:**
```bash
curl -s "$RADARR_URL/api/v3/history/movie?movieId=1" \
  -H "X-Api-Key: $RADARR_API_KEY"
```

**Códigos de respuesta:**
- `200`: Correcto

---

### Listas de importación

#### GET /importlist

Obtiene todas las listas de importación.

**Ejemplo de petición:**
```bash
curl -s "$RADARR_URL/api/v3/importlist" \
  -H "X-Api-Key: $RADARR_API_KEY"
```

**Códigos de respuesta:**
- `200`: Correcto

---

## Opciones de disponibilidad mínima

- `announced` - Cuando se anuncia por primera vez
- `inCinemas` - Cuando está en cines
- `released` - Cuando se estrena en formato físico/digital (recomendado)
- `preDB` - Cuando está disponible en preDB

## Paginación

Los endpoints de listado admiten paginación:
- `page`: Número de página (empieza en 1)
- `pageSize`: Elementos por página
- `sortKey`: Campo por el que ordenar
- `sortDirection`: `ascending` o `descending`

## Historial de versiones

| Versión de la API | Versión del documento | Fecha | Cambios |
|-------------|-------------|------|---------|
| v3 | 1.0.0 | 2026-02-01 | Documentación inicial |

## Recursos adicionales

- [Official API Documentation](https://radarr.video/docs/api/)
- [GitHub Repository](https://github.com/Radarr/Radarr)
- [Wiki](https://wiki.servarr.com/radarr)
