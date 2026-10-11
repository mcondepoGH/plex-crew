# Referencia de la API de Agregarr

**Versión de la API:** v1
**URL base:** `http://localhost:7171/api/v1`
**Autenticación:** cabecera `X-Api-Key` (o cookie de sesión `agregarr.sid`)
**Fuente:** `agregarr-api.yml` del repositorio https://github.com/agregarr/agregarr (rama `develop`)

Aquí solo se documentan los endpoints que usa `scripts/agregarr.sh`. Ninguno se ha verificado contra un servidor real en este entorno (no hay Agregarr configurado); las formas de respuesta vienen de la especificación OpenAPI.

## Autenticación

```bash
-H "X-Api-Key: <your_api_key>"
```

## Inicio rápido

```bash
export AGREGARR_URL="http://localhost:7171"
export AGREGARR_API_KEY="your-api-key"
curl -s "$AGREGARR_URL/api/v1/status" | jq
curl -s "$AGREGARR_URL/api/v1/collections" -H "X-Api-Key: $AGREGARR_API_KEY" | jq
```

## Endpoints por categoría

### Sistema

**GET `/status`** (público, sin clave) — `version`, `commitTag`, `updateAvailable`, `commitsBehind`, `restartRequired`.

**GET `/settings/logs?take=&skip=&filter=`** — array de `{label, level, message, timestamp}`. `filter`: `debug|info|warn|error`.

**GET `/settings/jobs`** — array de tareas: `id`, `name`, `type`, `interval`, `cronSchedule`, `nextExecutionTime`, `running`.

**POST `/settings/jobs/{jobId}/run`** (escritura) — ejecuta la tarea y devuelve su estado.

### Colecciones

**GET `/collections`** — `{ "collectionConfigs": [...] }`. Campos usados de cada colección: `id` (cadena, desde "10000"), `name`, `type` (`overseerr`, `tautulli`, `trakt`, `tmdb`, `imdb`, `mdblist`, `letterboxd`, `networks`, `originals`, `plex`, `multi-source`, `anilist`, `myanimelist`, `radarrtag`, `sonarrtag`, `comingsoon`, `filtered_hub`), `subtype`, `mediaType`, `libraryName`.

**GET `/collections/sync`** — `{running, message}` (resumen).

**GET `/collections/sync/status`** — `running`, `currentStage`, `totalCollections`, `processedCollections`, `progress`, `lastGlobalSyncAt`, `globalSyncError`, `collectionsNeedingSync`.

**POST `/collections/sync`** (escritura) — inicia la sincronización global en segundo plano. 200 `{status, message}`; 400 si falta configuración; 500 si falla el arranque.

**POST `/collections/{id}/sync`** (escritura) — sincroniza una colección. 200 `{status, message, collectionId, collectionName}`; 404 si no existe.

## Endpoints documentados y no implementados

| Endpoint | Motivo |
|----------|--------|
| `POST /collections`, `POST /collections/create`, `POST /collections/{id}/settings` | Escritura de configuración compleja (esquema `CollectionConfig` grande); sin verificación contra servidor |
| `DELETE /collections/{id}` | Destructivo (borra también las colecciones enlazadas) |
| `POST /collections/cleanup-missing`, `POST /settings/reset` | Destructivos o masivos |
| `GET /settings/plex`, `/settings/radarr`, `/settings/sonarr`, `/settings/overseerr`, `/settings/main` | Devuelven claves de otros servicios |
| `GET /preexisting`, `/defaulthubs`, `/collections/preexisting` | Lectura sin caso de uso aún |

## Códigos de respuesta

| Código | Significado |
|--------|-------------|
| 200 | Correcto |
| 400 | Falta configuración o petición incorrecta |
| 401 / 403 | Clave de API no válida o sin permisos |
| 404 | Colección o tarea inexistente |
| 500 | Error interno de Agregarr |
