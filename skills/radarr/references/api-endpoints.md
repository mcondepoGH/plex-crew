# Endpoints de la API de Radarr

Solo se documenta lo que usa el script. Documentación oficial: https://radarr.video/docs/api/

## Base y autenticación

- URL base: `${RADARR_URL}/api/v3`
- Autenticación: cabecera `X-Api-Key: ${RADARR_API_KEY}` en cada petición
- Las peticiones con cuerpo (`POST`, `PUT`) envían `Content-Type: application/json`
- Los ids de película y de colección son de TMDB (`tmdbId`)
- Las llamadas directas pasan URL y cabeceras a curl por stdin (`--config -`), con `--connect-timeout 10 --max-time 30`; `search`, `status` y `logs` usan la librería compartida (25 s)

## Comandos y peticiones

| Comando | Método y ruta | Notas |
|---------|---------------|-------|
| `search <query>` | `GET /movie/lookup?term=<texto codificado>` | Timeout de 25 s; se muestran todos los resultados |
| `search-json <query>` | `GET /movie/lookup?term=<texto codificado>` | Imprime el cuerpo sin tocarlo |
| `exists <tmdbId>` | `GET /movie?tmdbId=<N>` | `[]` si no está en la biblioteca |
| `config` | `GET /rootfolder` y `GET /qualityprofile` | |
| `status` | `GET /system/status` | Timeout de 25 s |
| `add <tmdbId> [profileId] [--no-search]` | `GET /movie/lookup/tmdb?tmdbId=<N>`, `GET /rootfolder`, `POST /movie` | Sin consultar `/qualityprofile` |
| `add-collection <id> [término] [--no-search]` | `GET /collection`, `GET /movie/lookup?term=<término>`, `GET /rootfolder`, `GET /qualityprofile`, por película `GET /movie?tmdbId=<N>` y `POST /movie`, después `GET /collection`, `GET /collection/<idInterno>` y `PUT /collection/<idInterno>` | Ver más abajo |
| `remove <tmdbId> [--delete-files]` | `GET /movie?tmdbId=<N>` y `DELETE /movie/<id>?deleteFiles=<true\|false>` | `id` es el de Radarr, no el de TMDB |
| `collection-info <id>` | `GET /collection` | Se filtra en el cliente por `tmdbId` |
| `logs [N] [opciones]` | `GET /log?page=1&pageSize=<P>&sortKey=time&sortDirection=descending[&level=<nivel>]` o `GET /log/file` | Timeout de 25 s |

## Campos de respuesta usados

| Ruta | Campos |
|------|--------|
| `/movie/lookup` | `title`, `year`, `tmdbId`, `collection.tmdbId`, `collection.title` (y el objeto completo, que `add-collection` reenvía) |
| `/movie/lookup/tmdb` | El objeto película completo, que `add` reenvía |
| `/movie` | `id`, `title`, `year`, `hasFile` |
| `/collection` | `id` (interno), `tmdbId`, `title`, `monitored` |
| `/rootfolder` | `id`, `path` |
| `/qualityprofile` | `id`, `name` |
| `/system/status` | `version`, `instanceName`, `osName`, `branch` |
| `/log` | `records[]` con `time`, `level`, `logger`, `message` |
| `/log/file` | `lastWriteTime`, `filename` |

## Cuerpo de `POST /movie`

El objeto del lookup con estos campos añadidos o sobrescritos:

| Campo | Valor |
|-------|-------|
| `rootFolderPath` | `path` de la primera carpeta de `/rootfolder` |
| `qualityProfileId` | En `add`, `profileId` indicado, o `RADARR_DEFAULT_QUALITY_PROFILE`, o `1`. En `add-collection`, el `id` del primer perfil de `/qualityprofile` |
| `monitored` | `true` |
| `addOptions.searchForMovie` | `true`, salvo con `--no-search` |

Si la respuesta trae `id`, la alta tuvo éxito. Si no, el script imprime el campo `message` (en `add`, o la respuesta completa si no hay) o la palabra `failed` (en `add-collection`).

## `add-collection`

1. El término de búsqueda es el `title` de la colección en `/collection` sin el sufijo ` Collection`; si la colección no está, el segundo argumento.
2. Del lookup se conservan las películas con `collection.tmdbId` igual al id dado.
3. Cada película se omite si `GET /movie?tmdbId=<N>` no devuelve `[]`; si no, se da de alta con `POST /movie`.
4. Al final, `GET /collection/<idInterno>` se fusiona con `monitored: true` y `searchOnAdd: true` y se envía con `PUT /collection/<idInterno>`. La línea `👁️` sale si la respuesta trae `monitored` verdadero.

## Paginación de `/log`

`page=1`, `pageSize=<P>`, orden por `time` descendente. `P` es `N`; con `--grep`, `min(N*20, 1000)`, porque el filtro se aplica en el cliente. `level=<nivel>` se añade si se indicó `--level`.

## Códigos HTTP relevantes

| Código | Significado |
|--------|-------------|
| 200 / 201 / 202 | Correcto |
| 400 | Alta rechazada (película ya existente, perfil o carpeta inválidos) |
| 401 | Clave de API incorrecta |
| 404 | Ruta inexistente (revisa la URL base) |

Solo `search`, `status` y `logs` comprueban el código HTTP. El resto lo ignora y trabaja con el cuerpo.
