# Resolución de problemas de Tautulli

## Problemas de autenticación

### "ERROR: Tautulli devolvió error: Invalid apikey"
**Causa:** la clave de API es incorrecta o ha cambiado

**Solución:**
1. Copia la clave de Tautulli → Settings → Web Interface → API
2. Actualiza `TAUTULLI_API_KEY` en `~/.claude/plex-crew/.env`
3. Comprueba que no hay espacios ni comillas de más
4. Si has exportado la variable en la shell, recuerda que tiene prioridad sobre el fichero

### "faltan variables en el .env"
**Causa:** `TAUTULLI_URL` o `TAUTULLI_API_KEY` no están exportadas ni figuran en el fichero de entorno

**Solución:**
1. Comprueba que el fichero existe: `ls -la ~/.claude/plex-crew/.env`
2. Comprueba las variables: `grep -c TAUTULLI ~/.claude/plex-crew/.env`

## Problemas de conexión

### "ERROR: no se pudo contactar con Tautulli en <URL>"
**Causa:** Tautulli no está en marcha, la URL o el puerto son incorrectos, o la petición superó el timeout de 30 s

**Solución:**
1. Comprueba que la URL incluye el puerto (8181 por defecto) y no lleva ruta de más
2. Prueba el acceso: `curl -s -o /dev/null -w '%{http_code}\n' "$TAUTULLI_URL/status"`
3. Revisa que el contenedor o servicio de Tautulli está activo
4. Comprueba que el host es alcanzable desde donde ejecutas el script

### "ERROR: Tautulli respondió HTTP <código>"
**Causa:** un proxy inverso o Tautulli devuelve un error (por ejemplo 502 o 404 por una ruta base incorrecta)

**Solución:**
1. Si Tautulli usa una ruta base (HTTP root), inclúyela en `TAUTULLI_URL`
2. Revisa los logs del proxy y de Tautulli

## Problemas de uso

### "ERROR: '<valor>' no es un número entero positivo"
**Causa:** `--days`, `--limit`, `--section-id` o `--rating-key` recibieron un valor no numérico (o `0` en `--days` y `--limit`)

**Solución:**
1. Pasa un entero: `--days 7`
2. Obtén los `section_id` con `libraries`

### "ERROR: falta el valor de <opción>" o "ERROR: opción desconocida"
**Causa:** la opción está al final sin valor, o no existe en ese comando

**Solución:**
1. Revisa la sintaxis con `help`
2. Entrecomilla los valores con espacios: `--user "ana b"`

### "ERROR: falta --section-id" o "falta --rating-key o --guid"
**Causa:** `library-stats` o `metadata` sin su argumento obligatorio

**Solución:**
1. Añade `--section-id N`, `--rating-key N` o `--guid TEXTO`

### `popular` devuelve siempre películas
**Causa:** limitación conocida: el script envía fijo `stat_id=popular_movies`

**Solución:**
1. Usa `home-stats` y filtra con `jq` la estadística que necesites
