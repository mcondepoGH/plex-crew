# Referencia de la API de Plex Media Server

**Versión de la API:** N/A (versionada según la versión del servidor)
**URL base:** `http://localhost:32400` (o la dirección de tu servidor Plex)
**Autenticación:** cabecera X-Plex-Token
**Última actualización:** 2026-02-01

## Autenticación

Plex usa autenticación basada en token. Puedes obtener tu token de estas formas:
- Plex Web App → Settings → Account → desplázate hasta el final → Show Advanced → "Get Token"
- O iniciando sesión mediante la API y extrayéndolo de la respuesta

```bash
-H "X-Plex-Token: <your_plex_token>"
```

### Obtener el token mediante la API

```bash
# Inicia sesión para obtener el token de autenticación
curl -X POST "https://plex.tv/users/sign_in.json" \
  -H "X-Plex-Client-Identifier: unique-client-id" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "user[login]=your-email@example.com&user[password]=yourpassword"
```

## Inicio rápido

```bash
# Define las variables de entorno
export PLEX_URL="http://localhost:32400"
export PLEX_TOKEN="your-plex-token"

# Prueba la conexión: obtiene la identidad del servidor
curl -s "$PLEX_URL/identity" \
  -H "X-Plex-Token: $PLEX_TOKEN" | jq
```

## Cabeceras obligatorias

Todas las peticiones deben incluir:
```bash
-H "X-Plex-Token: $PLEX_TOKEN"
-H "X-Plex-Client-Identifier: unique-client-id"
-H "Accept: application/json"
```

## Endpoints por categoría

### Información del servidor

#### GET /

Obtiene las capacidades y los detalles del servidor.

**Ejemplo de petición:**
```bash
curl -s "$PLEX_URL/?X-Plex-Token=$PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

**Códigos de respuesta:**
- `200`: correcto
- `401`: no autorizado

---

#### GET /identity

Obtiene la información de identidad del servidor.

**Ejemplo de petición:**
```bash
curl -s "$PLEX_URL/identity" \
  -H "X-Plex-Token: $PLEX_TOKEN" | jq
```

**Ejemplo de respuesta:**
```json
{
  "MediaContainer": {
    "size": 0,
    "claimed": true,
    "machineIdentifier": "abc123",
    "version": "1.40.0.8157"
  }
}
```

**Códigos de respuesta:**
- `200`: correcto

---

### Bibliotecas

#### GET /library/sections

Obtiene todas las secciones de biblioteca.

**Ejemplo de petición:**
```bash
curl -s "$PLEX_URL/library/sections" \
  -H "X-Plex-Token: $PLEX_TOKEN" | jq
```

**Ejemplo de respuesta:**
```json
{
  "MediaContainer": {
    "size": 3,
    "Directory": [
      {
        "key": "1",
        "type": "movie",
        "title": "Movies",
        "agent": "tv.plex.agents.movie",
        "scanner": "Plex Movie",
        "language": "en-US",
        "Location": [{"path": "/data/movies"}]
      },
      {
        "key": "2",
        "type": "show",
        "title": "TV Shows",
        "agent": "tv.plex.agents.series",
        "scanner": "Plex TV Series"
      }
    ]
  }
}
```

**Códigos de respuesta:**
- `200`: correcto

---

#### GET /library/sections/{id}/all

Obtiene todos los elementos de una sección de biblioteca.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| id (path) | integer | Sí | ID de la sección de biblioteca |
| X-Plex-Container-Start (query) | integer | No | Inicio de la paginación |
| X-Plex-Container-Size (query) | integer | No | Tamaño de página |

**Ejemplo de petición:**
```bash
# Obtiene todas las películas de la biblioteca 1
curl -s "$PLEX_URL/library/sections/1/all" \
  -H "X-Plex-Token: $PLEX_TOKEN" | jq
```

**Códigos de respuesta:**
- `200`: correcto
- `404`: biblioteca no encontrada

---

#### GET /library/sections/{id}/refresh

Actualiza una sección de biblioteca (busca contenido nuevo).

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| id (path) | integer | Sí | ID de la sección de biblioteca |

**Ejemplo de petición:**
```bash
curl -X GET "$PLEX_URL/library/sections/1/refresh" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

**Códigos de respuesta:**
- `200`: actualización iniciada

---

#### GET /library/recentlyAdded

Obtiene el contenido añadido recientemente en todas las bibliotecas.

**Ejemplo de petición:**
```bash
curl -s "$PLEX_URL/library/recentlyAdded" \
  -H "X-Plex-Token: $PLEX_TOKEN" | jq
```

**Códigos de respuesta:**
- `200`: correcto

---

### Contenido multimedia

#### GET /library/metadata/{ratingKey}

Obtiene los metadatos de un elemento multimedia concreto.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| ratingKey (path) | integer | Sí | Clave de valoración (rating key) del elemento |

**Ejemplo de petición:**
```bash
curl -s "$PLEX_URL/library/metadata/12345" \
  -H "X-Plex-Token: $PLEX_TOKEN" | jq
```

**Códigos de respuesta:**
- `200`: correcto
- `404`: contenido no encontrado

---

#### GET /library/metadata/{ratingKey}/children

Obtiene los hijos de un elemento multimedia (p. ej., las temporadas de una serie).

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| ratingKey (path) | integer | Sí | Clave de valoración (rating key) del elemento padre |

**Ejemplo de petición:**
```bash
# Obtiene las temporadas de una serie
curl -s "$PLEX_URL/library/metadata/12345/children" \
  -H "X-Plex-Token: $PLEX_TOKEN" | jq
```

**Códigos de respuesta:**
- `200`: correcto

---

#### PUT /library/metadata/{ratingKey}

Actualiza los metadatos de un elemento multimedia.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| ratingKey (path) | integer | Sí | Clave de valoración (rating key) del elemento |
| title.value (query) | string | No | Nuevo título |
| summary.value (query) | string | No | Nueva sinopsis |

**Ejemplo de petición:**
```bash
curl -X PUT "$PLEX_URL/library/metadata/12345?title.value=New%20Title" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

**Códigos de respuesta:**
- `200`: actualizado
- `404`: contenido no encontrado

---

#### DELETE /library/metadata/{ratingKey}

Elimina un elemento multimedia de la biblioteca.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| ratingKey (path) | integer | Sí | Clave de valoración (rating key) del elemento |

**Ejemplo de petición:**
```bash
curl -X DELETE "$PLEX_URL/library/metadata/12345" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

**Códigos de respuesta:**
- `200`: eliminado

---

### Reproducción

#### GET /status/sessions

Obtiene las sesiones de reproducción en curso.

**Ejemplo de petición:**
```bash
curl -s "$PLEX_URL/status/sessions" \
  -H "X-Plex-Token: $PLEX_TOKEN" | jq
```

**Ejemplo de respuesta:**
```json
{
  "MediaContainer": {
    "size": 1,
    "Metadata": [
      {
        "ratingKey": "12345",
        "key": "/library/metadata/12345",
        "type": "movie",
        "title": "Inception",
        "Player": {
          "address": "192.168.1.100",
          "device": "Chrome",
          "state": "playing",
          "title": "Living Room"
        },
        "Session": {
          "id": "abc123",
          "bandwidth": 4000,
          "location": "lan"
        },
        "User": {
          "title": "JohnDoe"
        }
      }
    ]
  }
}
```

**Códigos de respuesta:**
- `200`: correcto

---

#### POST /player/playback/stop

Detiene la reproducción en un cliente.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| sessionId (query) | string | Sí | ID de sesión obtenido de /status/sessions |

**Ejemplo de petición:**
```bash
curl -X POST "$PLEX_URL/player/playback/stop?sessionId=abc123" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

**Códigos de respuesta:**
- `200`: reproducción detenida

---

### Búsqueda

#### GET /search

Busca en todas las bibliotecas.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| query (query) | string | Sí | Consulta de búsqueda |
| limit (query) | integer | No | Máximo de resultados por tipo |

**Ejemplo de petición:**
```bash
curl -s "$PLEX_URL/search?query=inception" \
  -H "X-Plex-Token: $PLEX_TOKEN" | jq
```

**Códigos de respuesta:**
- `200`: correcto

---

#### GET /hubs/search

Busca con resultados clasificados por categorías.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| query (query) | string | Sí | Consulta de búsqueda |

**Ejemplo de petición:**
```bash
curl -s "$PLEX_URL/hubs/search?query=avengers" \
  -H "X-Plex-Token: $PLEX_TOKEN" | jq
```

**Códigos de respuesta:**
- `200`: correcto

---

### Listas de reproducción

#### GET /playlists

Obtiene todas las listas de reproducción.

**Ejemplo de petición:**
```bash
curl -s "$PLEX_URL/playlists" \
  -H "X-Plex-Token: $PLEX_TOKEN" | jq
```

**Códigos de respuesta:**
- `200`: correcto

---

#### POST /playlists

Crea una lista de reproducción nueva.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| type (query) | string | Sí | Tipo de lista (video, audio, photo) |
| title (query) | string | Sí | Título de la lista |
| uri (query) | string | Sí | Claves de valoración (rating keys) separadas por comas |

**Ejemplo de petición:**
```bash
curl -X POST "$PLEX_URL/playlists?type=video&title=Favorites&uri=server://12345/com.plexapp.plugins.library/library/metadata/123,456,789" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

**Códigos de respuesta:**
- `200`: lista creada

---

### Usuarios

#### GET /accounts

Obtiene todas las cuentas de usuario con acceso a este servidor.

**Ejemplo de petición:**
```bash
curl -s "$PLEX_URL/accounts" \
  -H "X-Plex-Token: $PLEX_TOKEN" | jq
```

**Códigos de respuesta:**
- `200`: correcto
- `401`: no autorizado (solo administrador)

---

### Preferencias

#### GET /:/prefs

Obtiene las preferencias del servidor.

**Ejemplo de petición:**
```bash
curl -s "$PLEX_URL/:/prefs" \
  -H "X-Plex-Token: $PLEX_TOKEN" | jq
```

**Códigos de respuesta:**
- `200`: correcto

---

#### PUT /:/prefs

Actualiza las preferencias del servidor.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| {key} (query) | string | Sí | Pares clave=valor de las preferencias |

**Ejemplo de petición:**
```bash
# Desactiva DLNA
curl -X PUT "$PLEX_URL/:/prefs?DlnaEnabled=0" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

**Códigos de respuesta:**
- `200`: actualizado

---

### Webhooks

#### POST /:/webhooks

Configura la URL de un webhook.

**Parámetros:**
| Nombre | Tipo | Obligatorio | Descripción |
|------|------|----------|-------------|
| url (query) | string | Sí | URL del webhook |

**Ejemplo de petición:**
```bash
curl -X POST "$PLEX_URL/:/webhooks?url=https://example.com/webhook" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

**Códigos de respuesta:**
- `200`: webhook configurado

---

## Formato de respuesta

La API de Plex devuelve XML por defecto. Para obtener respuestas JSON:
- Añade la cabecera `Accept: application/json`
- Todos los ejemplos anteriores incluyen esta cabecera

## Parámetros de consulta comunes

- `X-Plex-Container-Start`: desplazamiento de la paginación (por defecto: 0)
- `X-Plex-Container-Size`: tamaño de página (por defecto: varía según el endpoint)
- `includeGuids`: incluye los ID externos (TMDB, IMDB, etc.)
- `includeFields`: lista de campos a incluir, separados por comas

## Límite de peticiones

La API de Plex.tv (no el servidor local) tiene límites de peticiones:
- ~100 peticiones por minuto
- Devuelve HTTP 429 al superarlo

El servidor local no tiene límites de peticiones.

## Historial de versiones

| Versión de la API | Versión de la doc. | Fecha | Cambios |
|-------------|-------------|------|---------|
| N/A (versionada por el servidor) | 1.0.0 | 2026-02-01 | Documentación inicial |

## Recursos adicionales

- [Official API Documentation](https://www.plex.tv/api-documentation/)
- [Unofficial API Documentation](https://github.com/Arcanemagus/plex-api/wiki)
- [Python Plex API](https://github.com/pkkid/python-plexapi)
- [Plex Forum API Category](https://forums.plex.tv/c/api/19)
