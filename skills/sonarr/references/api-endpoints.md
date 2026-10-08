# Referencia de la API de Sonarr

**Versión de la API:** v3
**URL base:** `http://localhost:8989/api/v3`
**Autenticación:** cabecera X-Api-Key
**Última actualización:** 2026-02-01

## Autenticación

Sonarr usa autenticación mediante clave de API. Encuentra tu clave de API en Settings → General → Security.

```bash
-H "X-Api-Key: <your_api_key>"
```

## Inicio rápido

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
SONARR_URL="http://localhost:8989"
SONARR_API_KEY="<your_api_key>"
```

Después úsalas en los scripts:

```bash
# Cargar las credenciales desde .env
source ~/.claude/plex-crew/.env

# Probar la conexión: obtener el estado del sistema
curl -s "$SONARR_URL/api/v3/system/status" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq
```

## Endpoints por categoría

### Sistema

#### GET /system/status

Obtiene el estado del sistema y la información de versión.

**Ejemplo de petición:**
```bash
curl -s "$SONARR_URL/api/v3/system/status" \
  -H "X-Api-Key: $SONARR_API_KEY"
```

**Ejemplo de respuesta:**
```json
{
  "version": "4.0.0.746",
  "buildTime": "2024-01-15T10:30:00Z",
  "isDebug": false,
  "isProduction": true,
  "isAdmin": true,
  "isUserInteractive": false,
  "startupPath": "/app/sonarr/bin",
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

### Series

#### GET /series

Obtiene todas las series de la biblioteca.

**Ejemplo de petición:**
```bash
curl -s "$SONARR_URL/api/v3/series" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq
```

**Ejemplo de respuesta:**
```json
[
  {
    "id": 1,
    "title": "Breaking Bad",
    "sortTitle": "breaking bad",
    "status": "ended",
    "ended": true,
    "overview": "A high school chemistry teacher...",
    "network": "AMC",
    "airTime": "21:00",
    "images": [],
    "seasons": [],
    "year": 2008,
    "path": "/tv/Breaking Bad",
    "qualityProfileId": 1,
    "seasonFolder": true,
    "monitored": true,
    "useSceneNumbering": false,
    "runtime": 45,
    "tvdbId": 81189,
    "tvRageId": 18164,
    "tvMazeId": 169,
    "firstAired": "2008-01-20T00:00:00Z",
    "seriesType": "standard",
    "cleanTitle": "breakingbad",
    "imdbId": "tt0903747",
    "titleSlug": "breaking-bad",
    "certification": "TV-MA",
    "genres": ["Crime", "Drama", "Thriller"],
    "tags": [],
    "added": "2024-01-01T00:00:00Z",
    "ratings": {
      "votes": 1500000,
      "value": 9.5
    }
  }
]
```

**Códigos de respuesta:**
- `200`: Correcto

---

#### GET /series/{id}

Obtiene una serie concreta por ID.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| id (path) | integer | Sí | ID de la serie |

**Ejemplo de petición:**
```bash
curl -s "$SONARR_URL/api/v3/series/1" \
  -H "X-Api-Key: $SONARR_API_KEY"
```

**Códigos de respuesta:**
- `200`: Correcto
- `404`: Serie no encontrada

---

#### POST /series

Añade una nueva serie a la biblioteca.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| tvdbId (body) | integer | Sí | ID de TVDB |
| title (body) | string | Sí | Título de la serie |
| qualityProfileId (body) | integer | Sí | ID del perfil de calidad |
| path (body) | string | Sí | Ruta de la carpeta raíz |
| seasonFolder (body) | boolean | No | Usar carpetas de temporada (por defecto: true) |
| monitored (body) | boolean | No | Monitorizar la serie (por defecto: true) |
| addOptions (body) | object | No | Opciones de importación |

**Ejemplo de petición:**
```bash
curl -X POST "$SONARR_URL/api/v3/series" \
  -H "X-Api-Key: $SONARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "tvdbId": 81189,
    "title": "Breaking Bad",
    "qualityProfileId": 1,
    "languageProfileId": 1,
    "path": "/tv/Breaking Bad",
    "seasonFolder": true,
    "monitored": true,
    "addOptions": {
      "searchForMissingEpisodes": true
    }
  }'
```

**Códigos de respuesta:**
- `201`: Serie añadida
- `400`: Petición incorrecta (datos no válidos)
- `409`: La serie ya existe

---

#### PUT /series/{id}

Actualiza la información de una serie.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| id (path) | integer | Sí | ID de la serie |

**Ejemplo de petición:**
```bash
curl -X PUT "$SONARR_URL/api/v3/series/1" \
  -H "X-Api-Key: $SONARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "id": 1,
    "monitored": false,
    "qualityProfileId": 2
  }'
```

**Códigos de respuesta:**
- `202`: Actualizada
- `404`: No encontrada

---

#### DELETE /series/{id}

Elimina una serie de la biblioteca.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| id (path) | integer | Sí | ID de la serie |
| deleteFiles (query) | boolean | No | Eliminar los archivos (por defecto: false) |

**Ejemplo de petición:**
```bash
# Eliminar la serie conservando los archivos
curl -X DELETE "$SONARR_URL/api/v3/series/1" \
  -H "X-Api-Key: $SONARR_API_KEY"

# Eliminar la serie y los archivos
curl -X DELETE "$SONARR_URL/api/v3/series/1?deleteFiles=true" \
  -H "X-Api-Key: $SONARR_API_KEY"
```

**Códigos de respuesta:**
- `200`: Eliminada
- `404`: No encontrada

---

### Episodios

#### GET /episode

Obtiene todos los episodios.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| seriesId (query) | integer | No | Filtrar por ID de serie |

**Ejemplo de petición:**
```bash
curl -s "$SONARR_URL/api/v3/episode?seriesId=1" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq
```

**Códigos de respuesta:**
- `200`: Correcto

---

#### GET /episode/{id}

Obtiene un episodio concreto.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| id (path) | integer | Sí | ID del episodio |

**Ejemplo de petición:**
```bash
curl -s "$SONARR_URL/api/v3/episode/123" \
  -H "X-Api-Key: $SONARR_API_KEY"
```

**Códigos de respuesta:**
- `200`: Correcto
- `404`: Episodio no encontrado

---

#### PUT /episode/{id}

Actualiza un episodio (p. ej., marcarlo como monitorizado).

**Ejemplo de petición:**
```bash
curl -X PUT "$SONARR_URL/api/v3/episode/123" \
  -H "X-Api-Key: $SONARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"id": 123, "monitored": true}'
```

**Códigos de respuesta:**
- `202`: Actualizado

---

### Cola

#### GET /queue

Obtiene la cola de descargas actual.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| page (query) | integer | No | Número de página |
| pageSize (query) | integer | No | Elementos por página |

**Ejemplo de petición:**
```bash
curl -s "$SONARR_URL/api/v3/queue" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq
```

**Ejemplo de respuesta:**
```json
{
  "page": 1,
  "pageSize": 10,
  "sortKey": "timeleft",
  "sortDirection": "ascending",
  "totalRecords": 5,
  "records": [
    {
      "id": 1,
      "seriesId": 1,
      "episodeId": 123,
      "series": {
        "title": "Breaking Bad"
      },
      "episode": {
        "seasonNumber": 1,
        "episodeNumber": 1,
        "title": "Pilot"
      },
      "quality": {
        "quality": {
          "name": "Bluray-1080p"
        }
      },
      "size": 1500000000,
      "title": "Breaking.Bad.S01E01.1080p.BluRay.x264",
      "sizeleft": 750000000,
      "timeleft": "00:15:30",
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
| removeFromClient (query) | boolean | No | Eliminar del cliente de descargas (por defecto: true) |
| blocklist (query) | boolean | No | Añadir a la lista de bloqueo (por defecto: true) |

**Ejemplo de petición:**
```bash
curl -X DELETE "$SONARR_URL/api/v3/queue/1?removeFromClient=true&blocklist=false" \
  -H "X-Api-Key: $SONARR_API_KEY"
```

**Códigos de respuesta:**
- `200`: Eliminado

---

### Comando

#### POST /command

Ejecuta un comando.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| name (body) | string | Sí | Nombre del comando |

**Comandos comunes:**
- `RefreshSeries`: actualiza la información de la serie
- `RescanSeries`: vuelve a escanear la carpeta de la serie
- `SeriesSearch`: busca todos los episodios que faltan
- `SeasonSearch`: busca una temporada
- `EpisodeSearch`: busca un episodio concreto
- `RssSync`: sincroniza los feeds RSS
- `DownloadedEpisodesScan`: escanea la carpeta de descargas

**Ejemplo de petición (buscar un episodio):**
```bash
curl -X POST "$SONARR_URL/api/v3/command" \
  -H "X-Api-Key: $SONARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "EpisodeSearch",
    "episodeIds": [123, 124, 125]
  }'
```

**Ejemplo de petición (actualizar una serie):**
```bash
curl -X POST "$SONARR_URL/api/v3/command" \
  -H "X-Api-Key: $SONARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "RefreshSeries",
    "seriesId": 1
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
curl -s "$SONARR_URL/api/v3/qualityprofile" \
  -H "X-Api-Key: $SONARR_API_KEY"
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
curl -s "$SONARR_URL/api/v3/rootfolder" \
  -H "X-Api-Key: $SONARR_API_KEY"
```

**Ejemplo de respuesta:**
```json
[
  {
    "id": 1,
    "path": "/tv",
    "accessible": true,
    "freeSpace": 500000000000,
    "totalSpace": 1000000000000
  }
]
```

**Códigos de respuesta:**
- `200`: Correcto

---

### Calendario

#### GET /calendar

Obtiene los próximos episodios.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| start (query) | string | No | Fecha de inicio (ISO 8601) |
| end (query) | string | No | Fecha de fin (ISO 8601) |

**Ejemplo de petición:**
```bash
curl -s "$SONARR_URL/api/v3/calendar?start=2026-02-01&end=2026-02-07" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq
```

**Códigos de respuesta:**
- `200`: Correcto

---

### Búsqueda

#### GET /series/lookup

Busca series.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| term (query) | string | Sí | Término de búsqueda o tvdb:ID |

**Ejemplo de petición:**
```bash
# Buscar por nombre
curl -s "$SONARR_URL/api/v3/series/lookup?term=breaking%20bad" \
  -H "X-Api-Key: $SONARR_API_KEY" | jq

# Buscar por ID de TVDB
curl -s "$SONARR_URL/api/v3/series/lookup?term=tvdb:81189" \
  -H "X-Api-Key: $SONARR_API_KEY"
```

**Códigos de respuesta:**
- `200`: Correcto (devuelve un array, vacío si no hay coincidencias)

---

## Paginación

Los endpoints de listado admiten paginación:
- `page`: número de página (empieza en 1)
- `pageSize`: elementos por página
- `sortKey`: campo por el que ordenar
- `sortDirection`: `ascending` o `descending`

## Historial de versiones

| Versión de la API | Versión del documento | Fecha | Cambios |
|-------------|-------------|------|---------|
| v3 | 1.0.0 | 2026-02-01 | Documentación inicial |

## Recursos adicionales

- [Documentación oficial de la API](https://sonarr.tv/docs/api/)
- [Repositorio de GitHub](https://github.com/Sonarr/Sonarr)
- [Wiki](https://wiki.servarr.com/sonarr)
