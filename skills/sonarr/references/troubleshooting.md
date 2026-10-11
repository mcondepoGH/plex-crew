# Resolución de problemas de Sonarr

## Problemas de autenticación

### "ERROR: GET /system/status respondió HTTP 401"
**Causa:** la clave de API es incorrecta o ha cambiado

**Solución:**
1. Copia la clave de Sonarr → Settings → General → Security → API Key
2. Actualiza `SONARR_API_KEY` en `~/.claude/plex-crew/.env`
3. Comprueba que no hay espacios ni comillas de más
4. Si has exportado la variable en la shell, recuerda que tiene prioridad sobre el fichero

Con una clave incorrecta, `exists` y `config` no muestran el 401: `exists` imprime `exists` y su línea de datos falla o sale vacía, y `config` falla con un error de jq. Ejecuta `status` para confirmar.

### "faltan variables en el .env"
**Causa:** `SONARR_URL` o `SONARR_API_KEY` no están exportadas ni figuran en el fichero de entorno

**Solución:**
1. Comprueba que el fichero existe: `ls -la ~/.claude/plex-crew/.env`
2. Comprueba las variables: `grep -c SONARR ~/.claude/plex-crew/.env`
3. Para usar otro fichero, exporta `HOMELAB_ENV=/ruta/.env`

## Problemas de conexión

### "ERROR: no se pudo contactar con Sonarr en <URL>"
**Causa:** Sonarr no está en marcha, la URL o el puerto son incorrectos, o la petición superó el timeout de 30 s (10 s de conexión)

**Solución:**
1. Comprueba que la URL incluye el puerto (8989 por defecto) y no lleva barra final
2. Prueba el acceso: `curl -s -o /dev/null -w '%{http_code}\n' "$SONARR_URL/ping"`
3. Revisa que el contenedor o servicio de Sonarr está activo
4. Comprueba que el host es alcanzable desde donde ejecutas el script

### "ERROR: timeout tras 25s" o "ERROR: no se pudo conectar con el servicio"
**Causa:** el mismo fallo en `search` o `status`, que usan los mensajes de la librería compartida

**Solución:**
1. Sigue los pasos del apartado anterior
2. Para ampliar el timeout de esos dos comandos, exporta `ARR_MAX_TIME` con más segundos

### "Not Found" o rutas con `//api/v3`
**Causa:** `SONARR_URL` termina en barra, o Sonarr usa una ruta base (URL Base) que falta en la URL

**Solución:**
1. Quita la barra final de `SONARR_URL`
2. Si Sonarr tiene URL Base (Settings → General), inclúyela: `http://host:8989/sonarr`

## Problemas de uso

### "ERROR: tvdbId no válido" o "ERROR: falta tvdbId"
**Causa:** el id falta o no es un número entero; el id de TVDB va como primer argumento

**Solución:**
1. Obtén el id del enlace de `search` (`.../series/81189`)
2. No uses ids de TMDB: `radarr` y `seerr` los usan, Sonarr no
3. En `remove`, el id va antes de `--delete-files`

### "❌ Show not found with TVDB ID: <id>"
**Causa:** TVDB no tiene ninguna serie con ese id, o el id es de otro servicio

**Solución:**
1. Busca de nuevo con `search "<título>"` y toma el id del enlace
2. Comprueba el id en https://thetvdb.com/

### "ERROR: perfilId no válido"
**Causa:** el perfil de `add` no es un número entero

**Solución:**
1. Ejecuta `config` y usa el número de la sección `=== Quality Profiles ===`
2. Si el valor viene de `SONARR_DEFAULT_QUALITY_PROFILE`, corrígelo en el `.env`

### "❌ Failed to add show"
**Causa:** Sonarr rechazó la alta; el mensaje de la línea siguiente dice por qué (serie ya existente, perfil inexistente o carpeta raíz no válida). El código de salida es 0

**Solución:**
1. Ejecuta `exists <tvdbId>` para ver si la serie ya está
2. Ejecuta `config` y comprueba que el perfil existe y que hay una carpeta raíz: `add` usa siempre la primera
3. Si el mensaje es una lista JSON, lee el campo `errorMessage`

### "🗑️ Removed" pero la serie sigue en Sonarr
**Causa:** `remove` no comprueba la respuesta del borrado e imprime éxito aunque Sonarr lo rechace

**Solución:**
1. Ejecuta `exists <tvdbId>`: si responde `exists`, el borrado no se hizo
2. Comprueba el estado con `status` y repite el comando con las confirmaciones correspondientes

### "exists" sin serie, o `search` sin salida
**Causa:** `exists` solo reconoce `[]` exacto como `not_found`; `search` no imprime nada si no hay resultados

**Solución:**
1. Para `search`, prueba otro texto o usa `search-json` y revisa el JSON
2. Si `exists` imprime `exists` sin datos, revisa la clave de API con `status`
