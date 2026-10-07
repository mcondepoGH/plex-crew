---
name: safety-conventions
description: Reglas de seguridad y convenciones de ficheros del stack: doble confirmación en operaciones destructivas, permisos, rutas, descompresión y carpetas a ignorar. Úsala antes de cualquier borrado, sobrescritura, movimiento masivo o cambio de permisos.
---

# Seguridad y convenciones

## Doble confirmación
Antes de cualquier operación destructiva, pide confirmación explícita **dos veces**, en dos mensajes distintos, incluso en modo automático.
1. Primer mensaje: di la acción y sus consecuencias y pregunta si procede.
2. Solo tras el sí, segunda confirmación final ("seguro, no se puede deshacer").

Destructivo incluye: borrar, parar o reiniciar contenedores, `rm`/`rm -rf`, sobrescribir ficheros, `git reset --hard`, force-push, `chown`/`chmod` masivo, borrar datos, borrar releases de zurg (se eliminan de todas las cuentas del proveedor, sin deshacer) y cualquier acción difícil de revertir. Los renombrados masivos también: prueba con un elemento y pide la segunda confirmación antes del resto.

## Permisos
- Todo fichero tocado acaba con propietario `mcondepo:docker-stacker` y modo `770`. En contenedores usa los ids numéricos: `chown 1000:1003 <fichero>` y `chmod 770 <fichero>`. Verifica con `stat -c '%u:%g %a'`, no solo con el código de salida.
- **Excepción:** nunca `chown`/`chmod` bajo el mount de zurg. Es root por rclone FUSE.
- Tampoco toques `.@*` (`.@__thumb`, caché del NAS, además de root).

## Rutas del stack
- Local: `plex-stack/plex/multimedia/{movies,shows,animes,music}` y `downloads` (en inglés, zona de entrada sin organizar).
- Real-Debrid: mount de zurg (rclone) montado en el contenedor como `/workspace/zurg-mnt`, con la biblioteca en `/workspace/zurg-mnt/zurg/{shows,movies}`. Es la biblioteca remota del usuario: busca ahí primero ("busca la serie X").
- Separa siempre los hallazgos por origen: local y Real-Debrid no se mezclan.
- El stack de adquisición (prowlarr, jackett, seerr, cli_debrid, agregarr) es un proyecto compose aparte (`arr-stack`), no comparte compose ni red con `plex-stack`.
- El contenedor del agente no tiene red hasta el contenedor de Plex ni acceso a su base de datos: usa las skills y las tools de zurg.

## Herramientas
- Extracción de archivos: `unar` por defecto (rar, zip, 7z, etc.), no unrar ni 7z. Tras extraer, aplica los permisos de arriba.
- Servicios homelab (prowlarr, radarr, sonarr, plex, tautulli, seerr, cli_debrid): usa siempre las skills del repo para gestión, logs y estadísticas, no curl a mano con claves en línea.

## Secretos
- Nunca imprimas, registres ni subas `.env`, tokens ni claves. Las credenciales viven en `.env` (ignorado por git).
- No uses `schedule`/`RemoteTrigger` para nada que necesite la red local del usuario: corren en la nube, sin acceso al homelab.
