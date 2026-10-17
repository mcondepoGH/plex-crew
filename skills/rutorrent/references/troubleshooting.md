# Resolución de problemas de ruTorrent

## Problemas de autenticación

### "ruTorrent respondió HTTP 401"
**Causa:** ruTorrent tiene autenticación básica de nginx y faltan o son incorrectos `RUTORRENT_USER`/`RUTORRENT_PASSWORD` (son opcionales si no la tiene)

**Solución:**
1. Abre la interfaz web con las mismas credenciales
2. Revisa `RUTORRENT_USER` y `RUTORRENT_PASSWORD` en `~/.claude/plex-crew/.env`
3. Evita espacios finales; los caracteres `"` y `\` se escapan solos

### "faltan variables en el .env"
**Causa:** falta `RUTORRENT_URL` (única variable obligatoria)

**Solución:**
1. Comprueba que existe `~/.claude/plex-crew/.env`
2. Comprueba las variables: `grep -c RUTORRENT ~/.claude/plex-crew/.env`

## Problemas de conexión

### "no se pudo conectar con ruTorrent"
**Causa:** URL incorrecta, contenedor parado o sin ruta de red entre el entorno de Claude y el host

**Solución:**
1. Comprueba `RUTORRENT_URL` (sin barra final)
2. Comprueba que el contenedor de ruTorrent está en marcha
3. Si Claude corre en otro contenedor, usa una dirección alcanzable desde él (no `localhost`)

### "tiempo de espera agotado"
**Causa:** ruTorrent o rTorrent no responden (por ejemplo, recomprobando muchos torrents)

**Solución:** reintenta más tarde; sube `RUTORRENT_MAX_TIME` (segundos, 30 por defecto) si es una operación lenta.

### HTTP 404
**Causa:** plugin no instalado (`create`, `erasedata`, `diskspace`) o ruTorrent está bajo un prefijo de URL

**Solución:** activa el plugin en ruTorrent o incluye el prefijo en `RUTORRENT_URL`.

## Problemas de uso

### "ruta rechazada" o "borrado rechazado"
**Causa:** la ruta es relativa, contiene `..` o una carpeta `.@*`, está en `movies`/`shows` o queda fuera de `RUTORRENT_ALLOWED_DIR`

**Solución:**
1. Usa la ruta del contenedor, no la del host
2. Ajusta `RUTORRENT_ALLOWED_DIR` si el destino es legítimo
3. `--allow-library` solo si el usuario lo pide de forma expresa

### "no se pudo determinar la ruta de guardado"
**Causa:** `getsavepath` devolvió un formato no esperado (no verificado en vivo)

**Solución:** mira la ruta con `info` y `files`; no se borra nada hasta que se pueda validar.

### La tabla de `list` sale con columnas incorrectas
**Causa:** el formato de fila cambió; índices confirmados en vivo: 4 nombre, 5 tamaño, 8 bytes hechos, 14 etiqueta, 25 ruta de guardado

**Solución:** usa `list --raw` y ajusta el script con el formato real.

## Seguridad

### `/RPC2` expuesto sin autenticación
**Causa:** el endpoint XML-RPC por SCGI no pasa por el filtro de `xmlrpc_proxy.php` y permite `execute2`

**Solución:** mantén `HTTP_AUTH=true` y no expongas el puerto fuera de la red local. La skill no usa `/RPC2`.
