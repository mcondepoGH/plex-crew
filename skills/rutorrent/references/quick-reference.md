# Referencia rápida de ruTorrent

## Configuración

```bash
RUTORRENT_URL="http://localhost:8080"
RUTORRENT_USER="admin"
RUTORRENT_PASSWORD="your-password"
# RUTORRENT_ALLOWED_DIR="/data/downloads/seed"
```

## Comandos del script

Base: `bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh"`

| Comando | Efecto |
|---|---|
| `list [--raw]` | Torrents (tabla o JSON) |
| `info HASH` | Datos de un torrent |
| `files HASH` | Ficheros |
| `diskspace` | Espacio en disco |
| `tasks` | Tareas de creación |
| `add URL\|FICHERO [--label X] [--stopped]` | Añadir |
| `start HASH` / `stop HASH` / `recheck HASH` | Control |
| `label HASH ETIQUETA` | Etiquetar |
| `create RUTA [--tracker U] [--private] [--comment C] [--allow-library]` | Crear `.torrent` sin sembrar |
| `remove HASH` | Quitar conservando datos (destructivo) |
| `remove-with-data HASH [--allow-library]` | Quitar y borrar datos (destructivo) |

## Equivalencia de rutas

| Contenedor ruTorrent | Host |
|---|---|
| `/data/downloads/...` | Carpeta montada en `/data` (por ejemplo bajo `${STACK_LOCATION}/plex/multimedia/...`); consulta el volumen del contenedor |

## Peticiones manuales (solo para depurar; prefiere el script)

El hook deniega sin marcador las que quitan o borran. No pongas credenciales en la línea de comandos.

```bash
# Con las credenciales en un fichero de configuración de curl (-K)
curl -sS -K ~/.claude/plex-crew/curl-rutorrent.conf --data-urlencode mode=list "$RUTORRENT_URL/plugins/httprpc/action.php"
```
