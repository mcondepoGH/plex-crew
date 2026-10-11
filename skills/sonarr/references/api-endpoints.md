# Endpoints de la API de Sonarr

Solo se documenta lo que usa el script. Documentación oficial: https://sonarr.tv/docs/api/

## Base y autenticación

- URL base: `${SONARR_URL}/api/v3`
- Autenticación: cabecera `X-Api-Key: ${SONARR_API_KEY}` en cada petición
- Las altas envían `Content-Type: application/json`
- Los ids de serie son de TVDB (`tvdbId`)

## Comandos y peticiones

| Comando | Método y ruta | Notas |
|---------|---------------|-------|
| `search <texto>` | `GET /series/lookup?term=<texto codificado>` | Timeout de 25 s; se muestran 10 resultados |
| `search-json <texto>` | `GET /series/lookup?term=<texto codificado>` | Imprime el cuerpo sin tocarlo |
| `exists <tvdbId>` | `GET /series?tvdbId=<N>` | `[]` si no está en la biblioteca |
| `config` | `GET /rootfolder` y `GET /qualityprofile` | |
| `status` | `GET /system/status` | Timeout de 25 s |
| `add <tvdbId> [perfilId] [--no-search]` | `GET /series/lookup?term=tvdb:<N>`, `GET /rootfolder`, `POST /series` | Sin consultar `/qualityprofile` |
| `remove <tvdbId> [--delete-files]` | `GET /series?tvdbId=<N>` y `DELETE /series/<id>?deleteFiles=<true\|false>` | `id` es el de Sonarr, no el de TVDB |

## Campos de respuesta usados

| Ruta | Campos |
|------|--------|
| `/series/lookup` | `title`, `year`, `tvdbId` (y el objeto completo, que `add` reenvía) |
| `/series` | `id`, `title`, `year`, `statistics.seasonCount` |
| `/rootfolder` | `id`, `path` |
| `/qualityprofile` | `id`, `name` |
| `/system/status` | `version`, `instanceName`, `osName`, `branch` |

## Cuerpo de `POST /series`

El primer resultado del lookup con estos campos añadidos o sobrescritos:

| Campo | Valor |
|-------|-------|
| `rootFolderPath` | `path` de la primera carpeta de `/rootfolder` |
| `qualityProfileId` | `perfilId` indicado, o `SONARR_DEFAULT_QUALITY_PROFILE`, o `1` |
| `monitored` | `true` |
| `seasonFolder` | `true` |
| `addOptions.monitor` | `"all"` |
| `addOptions.searchForMissingEpisodes` | `true`, salvo con `--no-search` |
| `addOptions.searchForCutoffUnmetEpisodes` | `false` |

Si la respuesta trae `id`, la alta tuvo éxito. Si no, el script imprime el campo `message` o el cuerpo completo.

## Códigos HTTP relevantes

| Código | Significado |
|--------|-------------|
| 200 / 201 | Correcto |
| 400 | Alta rechazada (serie ya existente, perfil o carpeta inválidos) |
| 401 | Clave de API incorrecta |
| 404 | Ruta inexistente (revisa la URL base) |

Solo `search` y `status` comprueban el código HTTP. El resto lo ignora y trabaja con el cuerpo.
