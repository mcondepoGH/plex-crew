# Referencia de la API de Seerr

**Versión de la API:** v1
**URL base:** `http://localhost:5055/api/v1`
**Autenticación:** cabecera X-Api-Key

Aquí solo se documentan los endpoints que usa `scripts/seerr.sh`.

## Autenticación

Seerr usa autenticación mediante clave de API. Encuentra tu clave de API en Settings → General.

```bash
-H "X-Api-Key: <your_api_key>"
```

## Inicio rápido

```bash
# Define las variables de entorno
export SEERR_URL="http://localhost:5055"
export SEERR_API_KEY="your-api-key"

# Prueba la conexión - obtén el estado
curl -s "$SEERR_URL/api/v1/status" \
  -H "X-Api-Key: $SEERR_API_KEY" | jq
```

## Endpoints por categoría

### Sistema

#### GET /status

Obtiene la información de versión de Seerr. Lo usa el comando `status`.

**Ejemplo de petición:**
```bash
curl -s "$SEERR_URL/api/v1/status" \
  -H "X-Api-Key: $SEERR_API_KEY"
```

**Códigos de respuesta:**
- `200`: Correcto
- `401`: No autorizado

---

#### GET /settings/logs

Obtiene las últimas entradas del log. Lo usa el comando `logs`.

**Parámetros de consulta:**
- `take`: número de entradas
- `skip`: entradas que se omiten (el script usa `0`)
- `filter`: filtro por nivel (`debug`, `info`, `warn`, `error`); opcional

**Ejemplo de petición:**
```bash
curl -s "$SEERR_URL/api/v1/settings/logs?take=20&skip=0&filter=error" \
  -H "X-Api-Key: $SEERR_API_KEY"
```

**Campos de la respuesta que se usan:** `results[].timestamp`, `results[].level`, `results[].label`, `results[].message`

---

### Búsqueda

#### GET /search

Busca películas y series. Lo usa el comando `search`.

**Parámetros de consulta:**
- `query`: texto de búsqueda codificado como URL

**Ejemplo de petición:**
```bash
curl -s "$SEERR_URL/api/v1/search?query=Dune" \
  -H "X-Api-Key: $SEERR_API_KEY"
```

**Campos de la respuesta que se usan:** `results[].mediaType`, `results[].id` (id de TMDB), `results[].title` o `.name`, `results[].releaseDate` o `.firstAirDate`, `results[].mediaInfo.status`

---

### Solicitudes

#### GET /request

Lista las solicitudes. Lo usa el comando `requests`.

**Parámetros de consulta:**
- `filter`: `pending`, `approved` o `all`
- `take`: número de solicitudes (el script usa `50`)

**Ejemplo de petición:**
```bash
curl -s "$SEERR_URL/api/v1/request?filter=pending&take=50" \
  -H "X-Api-Key: $SEERR_API_KEY"
```

**Campos de la respuesta que se usan:** `results[].id`, `results[].media.mediaType`, `results[].media.tmdbId`, `results[].status`, `results[].requestedBy.displayName` o `.email`

---

#### POST /request

Crea una solicitud. Lo usan `request-movie` y `request-tv`.

**Cuerpo de la petición (película):**
```json
{
  "mediaType": "movie",
  "mediaId": 438631
}
```

**Cuerpo de la petición (serie, todas las temporadas):**
```json
{
  "mediaType": "tv",
  "mediaId": 1396,
  "seasons": "all"
}
```

**Cuerpo de la petición (serie, temporadas concretas):**
```json
{
  "mediaType": "tv",
  "mediaId": 1396,
  "seasons": [1, 2]
}
```

**Ejemplo de petición:**
```bash
curl -s -X POST "$SEERR_URL/api/v1/request" \
  -H "X-Api-Key: $SEERR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"mediaType":"movie","mediaId":438631}'
```

**Códigos de respuesta:**
- `201`: Solicitud creada
- `401`: No autorizado
- `409`: Ya existe una solicitud para ese título
