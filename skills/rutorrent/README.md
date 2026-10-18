# Skill de ruTorrent

Lista, añade, controla, crea y quita torrents de ruTorrent (rTorrent) con su API web, siempre por hash.

## Qué hace

- **Listar** — Torrents, detalle, ficheros, espacio en disco y tareas
- **Añadir** — Por URL, magnet o fichero `.torrent`, con etiqueta y opción de añadir parado
- **Controlar** — Iniciar, parar, recomprobar y etiquetar
- **Crear** — Genera un `.torrent` desde una ruta, sin empezar a sembrar
- **Quitar** — Quita el torrent o también borra sus datos (destructivo, doble confirmación)

## Configuración

### 1. Obtén las credenciales

Solo necesitas la URL. Si tu ruTorrent tiene autenticación básica de nginx (`HTTP_AUTH=true` en `mondedie/rutorrent`), añade también usuario y contraseña. La interfaz suele estar en el puerto 8080.

### 2. Configura las variables de entorno

Añade las variables a `~/.claude/plex-crew/.env`:

```bash
RUTORRENT_URL="http://<ip-del-servidor>:8080"
# Opcionales, solo con autenticación básica:
# RUTORRENT_USER="admin"
# RUTORRENT_PASSWORD="<your_password>"
# RUTORRENT_ALLOWED_DIR="/data/downloads"
```

**Opciones de configuración:**
- `RUTORRENT_URL`: obligatoria; URL base de ruTorrent (sin barra final)
- `RUTORRENT_USER`: opcional (si el host no pide auth no se envía); usuario de la autenticación básica
- `RUTORRENT_PASSWORD`: opcional; contraseña
- `RUTORRENT_ALLOWED_DIR`: opcional; prefijo (ruta del contenedor) permitido para `create` y `remove-with-data`

### 3. Pruébalo

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" list
```

### Cómo invocar el script

En los `SKILL.md` el script se llama con `${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh`. Fuera de una sesión de Claude Code esa variable no existe: usa la ruta real del plugin. Los ejemplos de abajo usan la ruta completa con la variable.

## Ejemplos de uso

### Consultar

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" list
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" info HASH
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" files HASH
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" diskspace
```

### Añadir, controlar y crear

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" add "magnet:?xt=urn:btih:..." --label Peliculas --stopped
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" stop HASH
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" create /data/downloads/seed/MiCarpeta --private
```

### Quitar (destructivo)

```bash
PLEX_CREW_CONFIRMED=1 bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" **remove** HASH
PLEX_CREW_CONFIRMED=1 bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" **remove-with-data** HASH
```

(Quita los asteriscos al ejecutar; marcan los comandos que borran.) El marcador solo se pone tras la doble confirmación; el hook `confirm-destructive` deniega estos comandos sin él.

## Referencia de la API

- [Endpoints de la API](references/api-endpoints.md)
- [Referencia rápida](references/quick-reference.md)
- [Resolución de problemas](references/troubleshooting.md)

## Flujo de trabajo

1. Localiza el torrent con `list` y usa su hash en el resto de comandos
2. Para quitar o borrar, propón con `info` y `files` y espera la doble confirmación
3. Las rutas son las del contenedor, no las del host

## Resolución de problemas

**ERROR: ... HTTP 401** → ruTorrent exige autenticación: define `RUTORRENT_USER` y `RUTORRENT_PASSWORD`.

**ERROR: no se pudo conectar con ruTorrent** → comprueba `RUTORRENT_URL` y que el contenedor que ejecuta Claude llegue al host.

**ruta rechazada** → la ruta es relativa, contiene `..` o `.@*`, está en `movies`/`shows` o queda fuera de `RUTORRENT_ALLOWED_DIR`.

Más casos en [troubleshooting](references/troubleshooting.md).

## Notas

- Formato de `list` confirmado en vivo (índices 4 nombre, 5 tamaño, 8 bytes hechos, 14 etiqueta, 25 ruta de guardado); `info` devuelve la fila como array JSON posicional, sin claves
- No verificado en vivo: `getsavepath`, `setlabel` y `diskspace`
- No se usa `/RPC2`
- Las credenciales no aparecen nunca en argv ni en la salida

## Licencia

MIT
