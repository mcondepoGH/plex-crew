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

Cinco funciones `curl -s` para APIs estilo Arr. El script que la carga debe definir antes `API` (URL base de la API, p. ej. `http://localhost:7878/api/v3`) y `AUTH` (cabecera completa, p. ej. `X-Api-Key: ...`).

| Función | Petición |
|---------|----------|
| `arr_get <ruta>` | GET `$API<ruta>` |
| `arr_post <ruta> <json>` | POST con `Content-Type: application/json` |
| `arr_put <ruta> <json>` | PUT con `Content-Type: application/json` |
| `arr_delete <ruta>` | DELETE |
| `arr_call <MÉTODO> <ruta> [json]` | Petición con comprobación del código HTTP (ver abajo) |

### arr_call

Es la función que deben usar las escrituras (regla 19 del estándar de [`../README.md`](../README.md)). Deja el cuerpo de la respuesta en `ARR_BODY` y el código HTTP en `ARR_CODE`, y devuelve 0 solo si el código es 2xx. En cualquier otro caso (4xx, 5xx o sin conexión) imprime por stderr `ERROR: <MÉTODO> <ruta> respondió HTTP <código>: <mensaje>` (el mensaje se extrae de `message` o `errorMessage` si existe) y devuelve 1. Se llama sin `$(...)` para conservar las variables:

```bash
arr_call POST "/movie" "$addRequest" || exit 1
echo "$ARR_BODY" | jq -r '.title'
```

## Qué skills los usan

- `load-env.sh`
  - `prowlarr`: vía `load_service_credentials`
  - `radarr`: vía `load_service_credentials`
  - `sonarr`: vía `load_service_credentials`
  - `plex`: vía `load_service_credentials`
  - `tautulli`: vía `load_service_credentials`
  - `seerr`: vía `load_service_credentials`
  - `cli_debrid`: vía `load_env_file` y `validate_env_vars`
- `arr-api.sh`
  - `radarr`
  - `sonarr`

## Notas

- `arr_get`, `arr_post`, `arr_put` y `arr_delete` no comprueban códigos HTTP: devuelven lo que responda el servicio. Solo `arr_call` falla (rc 1, mensaje por stderr) si el código no es 2xx.
- Los ficheros de entorno nunca se imprimen; los errores solo nombran la ruta o las variables que faltan.
