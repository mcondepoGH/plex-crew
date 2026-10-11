# Resolución de problemas de Plex

## Problemas de autenticación

### El comando imprime texto o HTML (o "Unauthorized") y termina con 0
**Causa:** el token es inválido o no tiene permisos. El script no comprueba el código HTTP: imprime el cuerpo de Plex y termina con 0 (`refresh` imprime además su línea de "iniciado"). Se reconoce porque la salida no es JSON (`jq` falla) o menciona 401

**Solución:**
1. Obtén un token válido: en la web de Plex abre un elemento, elige Ver XML y copia `X-Plex-Token` de la URL
2. Actualiza `PLEX_TOKEN` en `~/.claude/plex-crew/.env`
3. Para `accounts` y `prefs` usa el token de un administrador
4. Si has exportado la variable en la shell, tiene prioridad sobre el fichero

### "faltan variables en el .env"
**Causa:** `PLEX_URL` o `PLEX_TOKEN` no están exportadas ni figuran en el fichero. Hasta `help` exige credenciales

**Solución:**
1. Comprueba que el fichero existe: `ls -la ~/.claude/plex-crew/.env`
2. Comprueba las variables: `grep -c PLEX ~/.claude/plex-crew/.env`
3. Para usar otro fichero, exporta `HOMELAB_ENV=/ruta/.env`

## Problemas de conexión

### "ERROR: no se pudo contactar con Plex en <URL>"
**Causa:** Plex no está en marcha, la URL o el puerto son incorrectos, o la petición superó el timeout de 30 s

**Solución:**
1. Comprueba que la URL incluye el puerto (32400 por defecto)
2. Prueba el acceso: `curl -s -o /dev/null -w '%{http_code}\n' "$PLEX_URL/identity"`
3. Revisa que el servidor de Plex está activo
4. Comprueba que el host es alcanzable desde donde ejecutas el script

## Problemas de uso

### "ERROR: '<valor>' no es un número entero positivo"
**Causa:** el id, `--limit` u `--offset` no es numérico

**Solución:**
1. Pasa un entero: `library 1`, `recent --limit 10`
2. Obtén los `section-id` con `libraries` y los `ratingKey` con `search` o `library`

### "ERROR: falta ..." o "ERROR: opción desconocida: ..."
**Causa:** falta el id o el texto, una opción está al final sin valor, o la opción no existe en ese comando. En `search` y `library` el primer argumento siempre es el posicional: `search --limit 5` busca el texto `--limit` y falla por la opción `5`

**Solución:**
1. Revisa la sintaxis con `help`
2. Pon primero el id o el texto y después las opciones
3. Entrecomilla los textos con espacios: `search "la casa de papel"`

### `library --limit` o `--offset` no pagina o responde 404
**Causa:** limitación conocida. El script compone la ruta como `/library/sections/<id>/all&X-Plex-Container-Size=<N>?X-Plex-Token=...` y Plex no la interpreta

**Solución:**
1. Ejecuta `library <id>` sin opciones y filtra con `jq`
2. Para lo último añadido, usa `recent --limit N`

### La salida de `refresh` dice "iniciado" pero no pasa nada
**Causa:** limitación conocida. La línea JSON sale siempre, aunque Plex haya rechazado la petición

**Solución:**
1. Mira lo que imprime Plex antes de esa línea (un 401 o 404 aparece ahí)
2. Comprueba el `section-id` con `libraries` y el token
