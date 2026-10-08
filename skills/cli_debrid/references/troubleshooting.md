# Resolución de problemas de la API de cli_debrid

## Problemas de autenticación

### "el login en cli_debrid ha fallado (HTTP ...)"
**Causa:** usuario o contraseña incorrectos, o el endpoint de login no es accesible

**Solución:**
1. Inicia sesión en la interfaz web con las mismas credenciales
2. Revisa `CLI_DEBRID_USER` y `CLI_DEBRID_PASSWORD` en `~/.claude/plex-crew/.env`
3. Evita los espacios finales; entrecomilla los valores que contengan caracteres especiales
4. El script elimina la cookie tras un login fallido; vuelve a ejecutar el comando

### "faltan variables en el .env"
**Causa:** una de las tres variables no está exportada ni figura en el fichero de entorno

**Solución:**
1. Comprueba que el fichero existe: `ls -la ~/.claude/plex-crew/.env`
2. Comprueba las variables: `grep CLI_DEBRID ~/.claude/plex-crew/.env`
3. Para usar otro fichero, exporta `HOMELAB_ENV=/path/to/.env`

### La sesión caduca entre llamadas
**Causa:** la cookie de `/tmp` está obsoleta

**Solución:**
1. El script sondea `program_status` antes de cada petición y vuelve a iniciar sesión por sí mismo
2. Para forzar un login nuevo, elimina la cookie: `rm -f /tmp/.cli_debrid_cookie_*`

## Problemas de conexión

### "no se pudo conectar con cli_debrid"
**Causa:** cli_debrid no está en ejecución o la URL es incorrecta (código de salida 7 de curl)

**Solución:**
1. Comprueba el panel en un navegador en `CLI_DEBRID_URL`
2. Verifica el host y el puerto
3. Revisa los logs del contenedor: `docker logs cli_debrid`
4. Si el panel no responde, informa de que la skill es inaccesible

## Problemas con las peticiones

### "ERROR: <METHOD> <path> respondió HTTP <code>"
**Causa:** cli_debrid respondió con un código no 2xx

**Solución:**
1. Ejecuta `status` para comprobar la sesión y el programa
2. Lee los logs: `logs 200`
3. Comprueba que el endpoint existe en tu versión de cli_debrid

### El título no avanza por la cola
**Causa:** filtrado, a la espera de una pasada del planificador o atascado

**Solución:**
1. Ejecuta `queue` y busca el título
2. Ejecuta `logs 200` y busca errores
3. Si el título nunca aparece, revisa los filtros de idioma en `arr-language-filters`
4. Con la confirmación del usuario, fuerza la tarea: `trigger-task Scraping`

## Problemas con los argumentos

### "no es un número válido"
**Causa:** se llamó a `logs` con un `n` no numérico

**Solución:**
1. Usa un número: `logs 200`

### "falta el nombre de la tarea"
**Causa:** se llamó a `trigger-task` sin nombre

**Solución:**
1. Pasa el nombre de la tarea del planificador: `trigger-task Scraping`
