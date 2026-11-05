# Resolución de problemas de Dozzle

## Configuración

### "faltan variables en el .env"
**Causa:** `DOZZLE_URL` no está exportada ni figura en el fichero de entorno

**Solución:**
1. Comprueba que el fichero existe: `ls -la ~/.claude/plex-crew/.env`
2. Comprueba que la variable está definida: `grep DOZZLE ~/.claude/plex-crew/.env`
3. La URL va sin barra final: `http://host:puerto`

## Problemas de conexión

### "no se pudo leer la lista de contenedores de Dozzle"
**Causa:** Dozzle no está en ejecución, la URL o el puerto son incorrectos, o Dozzle exige autenticación

**Solución:**
1. Abre la URL en un navegador y comprueba que carga la interfaz
2. Comprueba `GET <DOZZLE_URL>/api/version`: debe devolver la versión
3. Si Dozzle tiene autenticación activada (login), la skill no puede leerlo: el script no envía credenciales

### "AVISO: respuesta truncada"
**Causa:** el log del contenedor es muy largo y no llegó entero en `DOZZLE_MAX_TIME` segundos

**Solución:** acota con `--since AAAA-MM-DDTHH:MM:SSZ` o sube `DOZZLE_MAX_TIME`

## Problemas de uso

### "contenedor no encontrado"
**Causa:** el nombre no coincide con ninguno de la lista o coincide con varios trozos

**Solución:** ejecuta `containers` y usa el nombre exacto o el id

### "logs de <x> respondió HTTP 404/400/405"
**Causa:** la versión de Dozzle expone otra ruta para los logs. La skill está comprobada con Dozzle v11.4.0 (`POST /api/containers/logs`); versiones anteriores usan rutas distintas (por ejemplo `/api/hosts/<host>/containers/<id>/logs/stream`)

**Solución:** actualiza Dozzle o adapta el script a la ruta de tu versión (ver `api-endpoints.md`)

### Un log sale sin líneas
**Causa:** `--grep` o `--since` no coinciden con nada, o se eligió el flujo equivocado

**Solución:** repite sin filtros, o prueba `--stderr` y `--stdout` por separado (la mayoría de las aplicaciones escriben en `stderr` o en `stdout`, no en los dos)
