# Endpoints de la API de Prowlarr

Solo se documenta lo que usa el script. Documentación oficial: https://prowlarr.com/docs/api/

## Base y autenticación

- URL base: `${PROWLARR_URL}/api/v1` (a `PROWLARR_URL` se le quita una barra final)
- Autenticación: cabecera `X-Api-Key: ${PROWLARR_API_KEY}` en cada petición
- Todas las peticiones envían `Content-Type: application/json`
- Todas las llamadas pasan por una sola función que entrega a curl la URL, las cabeceras y el cuerpo por stdin (`--config -`), de modo que ni la clave ni los cuerpos de indexador aparecen en `ps`
- Timeouts: `--connect-timeout 10` y `--max-time 30` (`PROWLARR_MAX_TIME`); `test-all` usa `--max-time 120` (`PROWLARR_TESTALL_MAX_TIME`)
- Solo un código HTTP 2xx cuenta como éxito

## Comandos y peticiones

| Comando | Método y ruta | Notas |
|---------|---------------|-------|
| `search <query>` | `GET /search?query=<q>&type=<tipo>[&indexerIds=-2\|-1][&categories=<c>][&limit=<n>]` | `type` es `search` salvo `--type`; `-2` con `--torrents`, `-1` con `--usenet`; `query` y `type` codificados |
| `tv-search` | `GET /search?query=<q>&type=tvsearch` | `q` = `{TvdbId:<n>} {Season:<n>} {Episode:<n>}`, solo las partes dadas, codificado |
| `movie-search` | `GET /search?query=<q>&type=moviesearch` | `q` = `{ImdbId:<id>}{TmdbId:<n>}`, solo las partes dadas, codificado |
| `indexers [--verbose]` | `GET /indexer` | Sin `--verbose`, se reducen los campos |
| `stats` | `GET /indexerstats` | Se usa `.indexers` |
| `test <id>` | `GET /indexer/<id>` y `POST /indexer/test` | El cuerpo del POST es la definición leída; se descarta la respuesta |
| `test-all` | `POST /indexer/testall` y, para los nombres, `GET /indexer` | Timeout propio de 120 s |
| `enable <id>` | `GET /indexer/<id>` y `PUT /indexer/<id>` | Cuerpo: la definición leída con `enable` en `true` |
| `disable <id>` | `GET /indexer/<id>` y `PUT /indexer/<id>` | Cuerpo: la definición leída con `enable` en `false` |
| `delete <id>` | `DELETE /indexer/<id>` | Permanente |
| `apps` | `GET /applications` | |
| `sync` | `POST /command` | Cuerpo: `{"name": "ApplicationIndexerSync"}` |
| `status` | `GET /system/status` | Se imprime el cuerpo sin tocarlo |
| `health` | `GET /health` | |
| `logs [N] [opciones]` | `GET /log?page=1&pageSize=<P>&sortKey=time&sortDirection=descending[&level=<nivel>]` o `GET /log/file` | Ver más abajo |

## Campos de respuesta usados

| Ruta | Campos |
|------|--------|
| `/search` | `title`, `indexer`, `size` (bytes; se muestra en MB, dividido entre 1048576 y redondeado hacia abajo), `seeders`, `leechers`, `age` (días), `downloadUrl`, `infoUrl` |
| `/indexer` | `id`, `name`, `protocol`, `enable`, `priority` (y el objeto completo con `--verbose`, `test`, `enable` y `disable`) |
| `/indexerstats` | `indexers[]` con `indexerName`, `numberOfQueries`, `numberOfGrabs`, `numberOfFailedQueries`, `averageResponseTime` |
| `/indexer/testall` | Array con `id`, `isValid` y `validationFailures[].errorMessage` |
| `/applications` | `id`, `name`, `syncLevel`, `implementation` |
| `/health` | `source`, `type`, `message` |
| `/system/status` | Se imprime entero |
| `/log` | `records[]` con `time`, `level`, `logger`, `message` |
| `/log/file` | Array con `lastWriteTime`, `filename` |

## `test-all`

Los indexadores con `isValid` igual a `false` cuentan como fallidos. Su nombre sale de `GET /indexer` (mapa id → nombre; si esa llamada falla, el nombre es `?`) y sus errores, de `validationFailures[].errorMessage`. Si hay alguno, el script imprime el array de fallidos por stderr, `{"status": "error", ...}` por stdout y termina con 1.

## Paginación de `/log`

`page=1`, `pageSize=<P>`, orden por `time` descendente. `P` es `N` (50 por defecto, máximo 1000); con `--grep`, `min(N*20, 1000)`, porque el filtro se aplica en el cliente. `level=<nivel>` se añade si se indicó `--level`; Prowlarr decide si filtra ese nivel exacto o ese nivel y superiores. `/log/file` no admite parámetros en el script.

## Categorías

`categories` admite ids numéricos de Newznab/Torznab separados por coma (1000 Consolas, 2000 Películas, 3000 Audio, 4000 PC, 5000 TV, 6000 XXX, 7000 Libros y sus subcategorías). El valor se envía tal cual.

## Códigos HTTP relevantes

| Código | Significado |
|--------|-------------|
| 200 / 201 / 202 | Correcto |
| 400 | Cuerpo rechazado (por ejemplo, indexador con errores de validación en `test`, `enable` o `disable`) |
| 401 | Clave de API incorrecta |
| 404 | Ruta o indexador inexistente |

Con un código distinto de 2xx el script imprime `ERROR: <MÉTODO> <ruta> respondió HTTP <código>` y, si el cuerpo trae `message` o `errorMessage`, `: <mensaje>`. Si curl falla (conexión, DNS, TLS o timeout): `ERROR: no se pudo contactar con Prowlarr en <URL>`.
