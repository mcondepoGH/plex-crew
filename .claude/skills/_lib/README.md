# _lib

Librerías de shell compartidas por los scripts de las skills de servicios. Se cargan con `source`; ejecutarlas directamente termina con error.

## load-env.sh

Carga de credenciales desde el fichero de entorno. Por defecto lee `.env` en la raíz del repositorio (tres niveles por encima de `_lib`); si `HOMELAB_ENV` está definida, usa esa ruta.

| Elemento | Qué hace |
|----------|----------|
| `HOMELAB_ENV` | Variable opcional con la ruta a otro fichero de entorno. |
| `load_env_file [ruta]` | Exporta (`set -a`) el contenido del fichero indicado, o `HOMELAB_ENV`, o `<raíz>/.env`. Devuelve 1 y avisa si no existe. |
| `validate_env_vars VAR...` | Comprueba que cada variable nombrada esté definida y no vacía; si falta alguna, lista los nombres y devuelve 1. |
| `load_service_credentials <servicio> <VAR_URL> <VAR_CLAVE>` | Si falta alguna de las dos variables, carga el fichero de entorno; después las valida. El primer argumento (nombre del servicio) no se usa. |

Gracias a `load_service_credentials`, las variables ya exportadas en el entorno tienen prioridad: si ambas existen, no se lee el fichero.

## arr-api.sh

Cuatro funciones `curl -s` para APIs estilo Arr. El script que la carga debe definir antes `API` (URL base de la API, p. ej. `http://localhost:7878/api/v3`) y `AUTH` (cabecera completa, p. ej. `X-Api-Key: ...`).

| Función | Petición |
|---------|----------|
| `arr_get <ruta>` | GET `$API<ruta>` |
| `arr_post <ruta> <json>` | POST con `Content-Type: application/json` |
| `arr_put <ruta> <json>` | PUT con `Content-Type: application/json` |
| `arr_delete <ruta>` | DELETE |

## Qué skills los usan

| Librería | Skills |
|----------|--------|
| `load-env.sh` | `prowlarr`, `radarr`, `sonarr`, `plex`, `tautulli`, `seerr` (vía `load_service_credentials`) y `cli_debrid` (vía `load_env_file` y `validate_env_vars`) |
| `arr-api.sh` | `radarr` y `sonarr` |

## Notas

- Las funciones de `arr-api.sh` no comprueban códigos HTTP: devuelven lo que responda el servicio.
- Los ficheros de entorno nunca se imprimen; los errores solo nombran la ruta o las variables que faltan.
