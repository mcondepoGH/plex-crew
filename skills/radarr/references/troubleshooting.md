# Resolución de problemas de Radarr

## Problemas de autenticación

### "ERROR: GET /system/status respondió HTTP 401"
**Causa:** la clave de API es incorrecta o ha cambiado

**Solución:**
1. Copia la clave de Radarr → Settings → General → Security → API Key
2. Actualiza `RADARR_API_KEY` en `~/.claude/plex-crew/.env`
3. Comprueba que no hay espacios ni comillas de más
4. Si has exportado la variable en la shell, recuerda que tiene prioridad sobre el fichero

Con una clave incorrecta, `exists` y `config` no muestran el 401: `exists` imprime `exists` y su línea de datos falla o sale vacía, y `config` falla con un error de jq. Ejecuta `status` para confirmar.

### "faltan variables en el .env"
**Causa:** `RADARR_URL` o `RADARR_API_KEY` no están exportadas ni figuran en el fichero de entorno

**Solución:**
1. Comprueba que el fichero existe: `ls -la ~/.claude/plex-crew/.env`
2. Comprueba las variables: `grep -c RADARR ~/.claude/plex-crew/.env`
3. Para usar otro fichero, exporta `HOMELAB_ENV=/ruta/.env`

## Problemas de conexión

### "ERROR: no se pudo contactar con Radarr en <URL>"
**Causa:** Radarr no está en marcha, la URL o el puerto son incorrectos, o la petición superó el timeout de 30 s (10 s de conexión). El mensaje no distingue la causa

**Solución:**
1. Comprueba que la URL incluye el puerto (7878 por defecto) y no lleva barra final
2. Prueba el acceso: `curl -s -o /dev/null -w '%{http_code}\n' "$RADARR_URL/ping"`
3. Revisa que el contenedor o servicio de Radarr está activo
4. Comprueba que el host es alcanzable desde donde ejecutas el script

### "ERROR: timeout tras 25s" o "ERROR: no se pudo conectar con el servicio"
**Causa:** el mismo fallo en `search`, `status` o `logs`, que usan los mensajes de la librería compartida

**Solución:**
1. Sigue los pasos del apartado anterior
2. Para ampliar el timeout de esos comandos, exporta `ARR_MAX_TIME` con más segundos

### "Not Found" o rutas con `//api/v3`
**Causa:** `RADARR_URL` termina en barra, o Radarr usa una ruta base (URL Base) que falta en la URL

**Solución:**
1. Quita la barra final de `RADARR_URL`
2. Si Radarr tiene URL Base (Settings → General), inclúyela: `http://host:7878/radarr`

## Problemas de uso

### "ERROR: tmdbId debe ser un número entero" o "ERROR: falta el tmdbId"
**Causa:** el id falta o no es un número entero; el id de TMDB va como primer argumento

**Solución:**
1. Obtén el id del enlace de `search` (`.../movie/603`)
2. No uses ids de TVDB: `sonarr` los usa, Radarr no
3. En `remove`, el id va antes de `--delete-files`

### "❌ Failed to add movie"
**Causa:** Radarr rechazó el alta: la película ya está en la biblioteca, el perfil no existe, la carpeta raíz no es válida o el `tmdbId` no existe en TMDB. `add` no comprueba el código HTTP y termina con 0

**Solución:**
1. Lee el mensaje de la línea siguiente
2. Ejecuta `exists <tmdbId>` para ver si ya estaba
3. Ejecuta `config` y usa un `profileId` de la lista
4. Comprueba el `tmdbId` con `search`

### "❌ Could not determine collection name. Please provide search term."
**Causa:** `add-collection` no encuentra la colección en `/collection` y no se dio término de búsqueda

**Solución:**
1. Indica el término como segundo argumento: `add-collection 2344 "The Matrix"`
2. No pongas `--no-search` en segunda posición: se tomaría como término
3. Comprueba el id de la colección (`collection.tmdbId` en `search-json`)

### "❌ No movies found for collection <id>"
**Causa:** el lookup de Radarr con ese término no devolvió películas de esa colección (término demasiado vago, id equivocado o colección grande)

**Solución:**
1. Busca con `search-json "<término>"` y revisa `collection.tmdbId`
2. Repite con un término más concreto, como el título de la colección
3. Si el problema persiste, añade las películas una a una con `add`

### "🗑️ Removed" pero la película sigue en Radarr
**Causa:** `remove` no comprueba el código HTTP del borrado e imprime éxito aunque Radarr lo rechace

**Solución:**
1. Ejecuta `exists <tmdbId>`; si sigue, el borrado falló
2. Revisa `logs 20 --level error` para ver el motivo
3. Si la clave no tiene permisos o hay otro fallo, corrígelo y repite el borrado con la doble confirmación

### "❌ Movie not found in library"
**Causa:** el `tmdbId` no corresponde a ninguna película de la biblioteca de Radarr

**Solución:**
1. Comprueba el id con `exists <tmdbId>`
2. Usa el `tmdbId` de TMDB, no el `ID` interno que muestra `exists`

### "ERROR: respuesta inesperada de /log"
**Causa:** el servicio no expone el endpoint `/log`, o la respuesta no trae `records`

**Solución:**
1. Comprueba la versión con `status`
2. Prueba `logs --files`, que usa otro endpoint
3. Revisa los logs desde la interfaz de Radarr (System → Logs)

### "ERROR: N debe ser un entero entre 1 y 1000" u otro error de `logs`
**Causa:** argumento no válido en `logs`: N fuera de rango, opción desconocida, `--level` sin valor o nivel no válido

**Solución:**
1. Usa un N de 1 a 1000
2. Usa niveles `trace`, `debug`, `info`, `warn`, `error` o `fatal`
3. Pon el texto de `--grep` y el nivel de `--level` justo después de la opción
