# Resolución de problemas de la API de Seerr

## Problemas de autenticación

### "401 Unauthorized"
**Causa:** la clave de API no es válida o falta

**Solución:**
1. Obtén la clave de API en Settings → General
2. Añádela a `~/.claude/plex-crew/.env`: `SEERR_API_KEY="<your_api_key>"`
3. Verifica la clave en la petición: `curl -v "$SEERR_URL/api/v1/status" -H "X-Api-Key: $KEY"`
4. Comprueba que la clave no tenga espacios ni caracteres de más
5. Asegúrate de que el nombre de la cabecera es `X-Api-Key` (distingue mayúsculas y minúsculas)

### "faltan variables en el .env"
**Causa:** `SEERR_URL` o `SEERR_API_KEY` no están exportadas ni figuran en el fichero de entorno

**Solución:**
1. Comprueba que el fichero existe: `ls -la ~/.claude/plex-crew/.env`
2. Comprueba que ambas variables están definidas: `grep SEERR ~/.claude/plex-crew/.env`
3. Para usar otro fichero, exporta `HOMELAB_ENV=/path/to/.env`

## Problemas de conexión

### "ECONNREFUSED" o timeout
**Causa:** Seerr no está en ejecución o el puerto es incorrecto

**Solución:**
1. Comprueba el servicio: `curl http://localhost:5055/api/v1/status`
2. Verifica que la URL no tiene barra final y que el puerto es el correcto (por defecto: 5055)
3. Revisa los logs de Docker: `docker logs seerr`

## Problemas con las solicitudes

### "409 Conflict" al solicitar
**Causa:** ya existe una solicitud para ese título

**Solución:**
1. Ejecuta `search "<title>"` y comprueba el estado en Seerr del resultado
2. Indica al usuario que es un duplicado; no reintentes

### "ERROR: ... respondió HTTP 4xx"
**Causa:** Seerr rechazó la solicitud (id incorrecto, sin permiso o cuota alcanzada)

**Solución:**
1. Verifica el id de TMDB con `search`
2. Comprueba que el usuario de la clave de API puede crear solicitudes
3. Lee el mensaje impreso después del código HTTP
4. Revisa `logs 50 error` para ver el motivo en el servidor

### La solicitud se crea pero no se descarga nada
**Causa:** la solicitud está pendiente de aprobación o Seerr no está conectado a Radarr/Sonarr

**Solución:**
1. Lista las solicitudes pendientes: `requests pending`
2. Aprueba la solicitud en la interfaz de Seerr si la aprobación automática está desactivada
3. Revisa la conexión con Radarr/Sonarr en Seerr → Settings → Services

## Problemas con los argumentos

### "no es un número válido"
**Causa:** el id, `n` o la lista de temporadas no son numéricos

**Solución:**
1. Usa solo ids de TMDB numéricos
2. Las temporadas deben ser una lista separada por comas, como `1,2`
3. Los niveles de `logs` son `debug`, `info`, `warn` o `error`
