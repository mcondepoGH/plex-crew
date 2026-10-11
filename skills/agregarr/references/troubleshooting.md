# Resolución de problemas de la API de Agregarr

## Problemas de autenticación

### "401 Unauthorized" o "Clave de API: NO VÁLIDA"
**Causa:** la clave de API no es válida o falta (`/status` es público y responde igualmente, por eso `status` valida la clave con `/collections`)

**Solución:**
1. Copia la API Key de la interfaz web de Agregarr (ajustes generales; también se puede regenerar)
2. Añádela a `~/.claude/plex-crew/.env`: `AGREGARR_API_KEY="<your_api_key>"`
3. Comprueba la clave: `curl -s -o /dev/null -w '%{http_code}\n' "$AGREGARR_URL/api/v1/collections" -H "X-Api-Key: $AGREGARR_API_KEY"`
4. Asegúrate de que la cabecera es `X-Api-Key`

### "faltan variables en el .env"
**Causa:** `AGREGARR_URL` o `AGREGARR_API_KEY` no están exportadas ni figuran en el fichero de entorno

**Solución:**
1. Comprueba que el fichero existe: `ls -la ~/.claude/plex-crew/.env`
2. Comprueba que ambas variables están definidas: `grep -c AGREGARR ~/.claude/plex-crew/.env`
3. Para usar otro fichero, exporta `HOMELAB_ENV=/path/to/.env`

## Problemas de conexión

### "DESCONECTADO" o "no se pudo conectar"
**Causa:** Agregarr no está en ejecución o el puerto es incorrecto

**Solución:**
1. Comprueba el servicio: `curl http://localhost:7171/api/v1/status`
2. Verifica que la URL no tiene barra final y que el puerto es el correcto (7171 por defecto)

## Problemas de uso

### `sync` responde 400
**Causa:** falta configuración (Plex u otro origen) o Agregarr no conecta con Plex

**Solución:**
1. Revisa `logs 50 error`
2. Comprueba la conexión a Plex en la interfaz web de Agregarr

### `sync-collection` responde 404
**Causa:** el id no existe

**Solución:**
1. Lista los ids con `collections`

### Una sincronización no avanza
**Causa:** sigue en curso o se quedó con error global

**Solución:**
1. `sync-status` y revisa `En curso` y `Error global`
2. `logs 50 error`

## Pendiente (no verificado)

Esta skill se escribió contra `agregarr-api.yml` sin un Agregarr accesible, así que **ningún endpoint está verificado en vivo**. Queda pendiente:

1. Ejecutar `status` y `collections` contra el servidor real y confirmar las formas de respuesta (sobre todo `libraryName` y `mediaType` en `collections`)
2. Confirmar que `/settings/jobs` y `/settings/logs` aceptan `X-Api-Key` (en la especificación no tienen restricción propia)
3. Valorar comandos de escritura de configuración (`POST /collections/create`, `POST /collections/{id}/settings`) y de borrado (`DELETE /collections/{id}`, que requeriría doble confirmación y `PLEX_CREW_CONFIRMED=1`) cuando se pueda probar contra el servicio
