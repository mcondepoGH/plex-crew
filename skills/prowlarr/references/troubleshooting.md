# Resolución de problemas de Prowlarr

## Problemas de autenticación

### "ERROR: GET /system/status respondió HTTP 401"
**Causa:** la clave de API es incorrecta o ha cambiado

**Solución:**
1. Copia la clave de Prowlarr → Settings → General → Security → API Key
2. Actualiza `PROWLARR_API_KEY` en `~/.claude/plex-crew/.env`
3. Comprueba que no hay espacios ni comillas de más
4. Si has exportado la variable en la shell, recuerda que tiene prioridad sobre el fichero

### "faltan variables en el .env"
**Causa:** `PROWLARR_URL` o `PROWLARR_API_KEY` no están exportadas ni figuran en el fichero de entorno (incluso `help` las exige)

**Solución:**
1. Comprueba que el fichero existe: `ls -la ~/.claude/plex-crew/.env`
2. Comprueba las variables: `grep -c PROWLARR ~/.claude/plex-crew/.env`
3. Para usar otro fichero, exporta `HOMELAB_ENV=/ruta/.env`

## Problemas de conexión

### "ERROR: no se pudo contactar con Prowlarr en <URL>"
**Causa:** Prowlarr no está en marcha, la URL o el puerto son incorrectos, o la petición superó el timeout (10 s de conexión y 30 s en total; 120 s en `test-all`). El mensaje no distingue la causa

**Solución:**
1. Comprueba que la URL incluye el puerto (9696 por defecto)
2. Prueba el acceso: `curl -s -o /dev/null -w '%{http_code}\n' "$PROWLARR_URL/ping"`
3. Revisa que el contenedor o servicio de Prowlarr está activo
4. Si solo falla `test-all` o una búsqueda lenta, amplía el tiempo con `PROWLARR_TESTALL_MAX_TIME` o `PROWLARR_MAX_TIME` (en segundos)

### "Not Found" o rutas con `//api`
**Causa:** `PROWLARR_URL` termina en más de una barra, o Prowlarr usa una ruta base (URL Base) que falta en la URL

**Solución:**
1. Deja como máximo una barra final (el script quita solo una)
2. Si Prowlarr tiene URL Base (Settings → General), inclúyela: `http://host:9696/prowlarr`

## Problemas de uso

### "ERROR: id debe ser un número entero" o "ERROR: falta id"
**Causa:** `test`, `enable`, `disable` y `delete` exigen el id numérico del indexador; falta o contiene otros caracteres

**Solución:**
1. Obtén el id con `indexers` (campo `id`)
2. Pasa solo dígitos, sin nombre del indexador

### "ERROR: GET /indexer/9 respondió HTTP 404"
**Causa:** el indexador no existe (id equivocado o ya eliminado)

**Solución:**
1. Ejecuta `indexers` y usa un `id` de la lista

### "ERROR: POST /indexer/test respondió HTTP 400" o un `test` que falla
**Causa:** Prowlarr rechazó la prueba: credenciales o cookies del tracker caducadas, tracker caído, o la definición del indexador tiene errores de validación. El script solo informa del mensaje HTTP

**Solución:**
1. Lee el mensaje que sigue al código
2. Revisa `logs 20 --level warn --grep "<nombre del indexador>"`
3. Corrige el indexador desde la interfaz de Prowlarr y repite `test <id>`

### "ERROR: PUT /indexer/<id> respondió HTTP 400" al activar o desactivar
**Causa:** `enable` y `disable` reenvían la definición completa del indexador y Prowlarr la rechaza si tiene errores de validación

**Solución:**
1. Lee el mensaje de validación
2. Corrige el indexador desde la interfaz de Prowlarr, que es donde se editan
3. Repite el comando

### `test-all` indica indexadores con fallo
**Causa:** `ERROR: indexers con fallo:` y la lista `[{id, name, errors}]` indican qué indexadores no pasaron la prueba y por qué

**Solución:**
1. Revisa `errors` de cada uno
2. Repite con `test <id>` para confirmar
3. Si el indexador no tiene arreglo, propón `disable <id>` (tras confirmar con el usuario) y `sync`

### `sync` no tiene efecto
**Causa:** `sync` solo encola el comando `ApplicationIndexerSync` y no espera ni comprueba el resultado; la aplicación destino puede estar caída o tener un nivel de sincronización que no aplica el cambio

**Solución:**
1. Ejecuta `apps` y revisa `syncLevel` de cada aplicación
2. Ejecuta `health` para ver avisos de aplicaciones no alcanzables
3. Revisa `logs 30 --grep "sync"`

### Una búsqueda devuelve `[]`
**Causa:** ningún indexador activo tiene resultados para esa consulta, la categoría no encaja, o los indexadores están caídos

**Solución:**
1. Comprueba `indexers` (que haya activos), `health` y `stats`
2. Quita `--category` o prueba otra categoría
3. Para películas y series, usa `movie-search --imdb` o `tv-search --tvdb`; con Torrentio el texto libre devuelve un título fijo (ver la skill `arr-language-filters`)

### Una búsqueda falla con un error de jq
**Causa:** algún resultado tiene `size` nulo, o el servicio devolvió algo que no es un array

**Solución:**
1. Repite con `--limit` o con otra consulta
2. Revisa `health` por si un indexador devuelve respuestas inválidas

### "ERROR: falta al menos --tvdb" o "ERROR: falta --imdb o --tmdb"
**Causa:** `tv-search` o `movie-search` sin ningún id

**Solución:**
1. Pasa `--tvdb <id>` o `--imdb <id>` / `--tmdb <id>`
2. Para texto libre, usa `search "<texto>"`

### "ERROR: respuesta inesperada de /log"
**Causa:** el servicio no expone el endpoint `/log`, o la respuesta no trae `records`

**Solución:**
1. Comprueba la versión con `status`
2. Prueba `logs --files`, que usa otro endpoint
3. Revisa los logs desde la interfaz de Prowlarr (System → Logs)

### "ERROR: N debe ser un entero entre 1 y 1000" u otro error de `logs`
**Causa:** argumento no válido en `logs`: N fuera de rango, opción desconocida, `--level` o `--grep` sin valor, o nivel no válido

**Solución:**
1. Usa un N de 1 a 1000
2. Usa niveles `trace`, `debug`, `info`, `warn`, `error` o `fatal`
3. Pon el texto de `--grep` y el nivel de `--level` justo después de la opción
