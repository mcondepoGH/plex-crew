---
name: rutorrent
description: Esta skill debe usarse cuando se gestionen torrents en ruTorrent (rTorrent). Úsala cuando el usuario pida "torrents de ruTorrent", "listar los torrents", "añadir un torrent", "pausar o reanudar un torrent", "recomprobar un torrent", "crear un torrent", "quitar un torrent", "borrar un torrent con sus datos", "espacio en disco de ruTorrent", o mencione ruTorrent o rTorrent.
---

# Skill de gestión de torrents de ruTorrent

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "ruTorrent", "rTorrent", "torrents de ruTorrent", "lista de torrents"
- "añadir un torrent", "pausar", "reanudar", "recomprobar", "etiquetar un torrent"
- "crear un torrent", "quitar un torrent", "borrar un torrent con sus datos"
- "espacio en disco de ruTorrent", "tareas de creación de torrents"

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Lista, añade, controla, crea y quita torrents de ruTorrent con la API web de sus plugins, siempre por hash.

## Propósito

Esta skill permite operar ruTorrent:
- Listar torrents y ver su detalle, ficheros y el espacio en disco
- Añadir torrents por URL, magnet o fichero `.torrent`
- Iniciar, parar, recomprobar y etiquetar torrents
- Crear ficheros `.torrent` desde una ruta (sin empezar a sembrar)
- Quitar torrents, con o sin borrado de los datos

Las operaciones incluyen lectura, escritura y borrado. **Quitar un torrent (`remove`) y borrar sus datos (`remove-with-data`) son destructivos**: el hook `confirm-destructive` los deniega sin el marcador `PLEX_CREW_CONFIRMED=1`, que solo se pone tras la doble confirmación del usuario (ver `plex-crew-rules`). Confirma con el usuario antes de `add`, `create` y `label`, salvo que los haya pedido de forma explícita.

## Configuración

Añade las variables a `~/.claude/plex-crew/.env`. ruTorrent no tiene clave de API: solo la URL es obligatoria; usuario y contraseña (autenticación básica de nginx, `HTTP_AUTH=true` en `mondedie/rutorrent`) son opcionales y solo hacen falta si tu ruTorrent la tiene activada.

```bash
RUTORRENT_URL="http://<ip-del-QNAP>:8080"
# Opcionales: solo si ruTorrent tiene autenticación básica.
# RUTORRENT_USER="admin"
# RUTORRENT_PASSWORD="your-password"
# Opcional: prefijo (ruta del contenedor) permitido para crear torrents y borrar datos.
# RUTORRENT_ALLOWED_DIR="/data/downloads"
```

- `RUTORRENT_URL`: obligatoria; URL base de ruTorrent (sin barra final y sin prefijo de URL salvo que lo uses)
- `RUTORRENT_USER` y `RUTORRENT_PASSWORD`: opcionales si el host no pide autenticación; autenticación básica. Sin usuario no se envía autenticación
- `RUTORRENT_ALLOWED_DIR`: opcional; si existe, `create` y `remove-with-data` solo aceptan rutas bajo ese prefijo

## Ejecución del script

El script está en `${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh`. Llámalo con su ruta absoluta para no alterar el directorio de trabajo de la sesión. Si hay credenciales, se pasan a `curl` por stdin: nunca aparecen en argv ni en la salida.

## Rutas: contenedor frente a host

Las rutas que devuelve y acepta ruTorrent son las **del contenedor** (por ejemplo `/data/downloads/seed/X`), que no coinciden con las del host (por ejemplo `${STACK_LOCATION}/plex/multimedia/...`). Antes de comparar o tocar ficheros en el host, traduce la ruta con el montaje del volumen del contenedor. La skill no toca ficheros del host: solo habla con la API.

## Comandos

`list` imprime una tabla TSV (hash, nombre, tamaño, hecho, etiqueta); `list --raw` y el resto imprimen el JSON de ruTorrent tal cual. Sin comando muestra la ayuda (código 0); un comando desconocido la muestra y termina con 1. Un argumento ausente, un hash que no sean 40 caracteres hexadecimales o una ruta rechazada imprime `ERROR:` y termina con 1. Un HTTP no 2xx, un 401 o un fallo de conexión imprime `ERROR:` en stderr y termina con 1.

El formato de `mode=list` no está documentado oficialmente. Índices confirmados en vivo: 4 nombre, 5 tamaño, 8 bytes hechos, 14 etiqueta, 25 ruta de guardado. Si la tabla sale rara, usa `list --raw`. `info` devuelve la fila del torrent como array JSON posicional, sin claves (mismos índices).

### Consultar

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" list
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" info 0123456789ABCDEF0123456789ABCDEF01234567
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" files 0123456789ABCDEF0123456789ABCDEF01234567
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" diskspace
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" tasks
```

**Salida:** `list` la tabla de torrents, `info` los datos de uno, `files` sus ficheros, `diskspace` el espacio libre y `tasks` las tareas de creación de torrents.

### Añadir

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" add "magnet:?xt=urn:btih:..." --label Peliculas --stopped
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" add /ruta/al/fichero.torrent
```

**Confirma con el usuario antes de añadir.** Acepta URL `http(s)`, magnet o un fichero `.torrent` local. `--stopped` lo añade parado; `--label` le pone etiqueta. **Salida:** la respuesta de ruTorrent.

### Controlar y etiquetar

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" start HASH
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" stop HASH
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" recheck HASH
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" label HASH Peliculas
```

**Salida:** la respuesta de ruTorrent. Ninguno de estos comandos borra nada.

### Crear un torrent

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" create /data/downloads/seed/MiCarpeta --tracker http://tracker/announce --private --comment "texto"
```

**Confirma con el usuario antes de crear.** Requiere el plugin `create` de ruTorrent y `mktorrent`. No empieza a sembrar (`start_seeding=0`). La ruta debe ser absoluta (del contenedor), sin `..`, sin carpetas `.@*`, fuera de `*/movies*` y `*/shows*` (salvo `--allow-library`, solo si el usuario lo pide de forma expresa) y, si existe `RUTORRENT_ALLOWED_DIR`, bajo ese prefijo. **Salida:** el id de tarea; sigue su estado con `tasks`.

### Quitar un torrent (destructivo)

```bash
PLEX_CREW_CONFIRMED=1 bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" remove HASH
PLEX_CREW_CONFIRMED=1 bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" remove-with-data HASH
```

**Doble confirmación obligatoria** (dos mensajes distintos del usuario) antes de anteponer `PLEX_CREW_CONFIRMED=1`; sin marcador el hook lo deniega. `remove` quita el torrent y conserva los datos. `remove-with-data` **borra los datos del disco**: antes muestra `info`, `files` y la ruta de guardado (en stderr) y rechaza el borrado si la ruta no se puede determinar, queda fuera de `RUTORRENT_ALLOWED_DIR` o está en la biblioteca (`movies`/`shows`) salvo `--allow-library`. **Propón primero** (hash, nombre, ficheros y ruta) y espera las dos confirmaciones. **Salida:** la respuesta de ruTorrent.

## Flujo de trabajo

1. **"¿Qué torrents hay?"** → `list`; para el detalle, `info` y `files`
2. **"Añade este torrent"** → confirma y `add`
3. **"Quita este torrent"** → localiza el hash con `list`, propón con `info` y `files`, doble confirmación y `remove`
4. **"Borra el torrent y sus datos"** → igual, con `remove-with-data`; indica la ruta del contenedor y su equivalente en el host

## Notas

- Opera siempre por hash (40 hexadecimales), nunca por nombre
- No se usa `/RPC2` (XML-RPC por SCGI): sin autenticación permitiría `execute2` y ejecutar órdenes en el servidor; ver `references/troubleshooting.md`
- Si ruTorrent no responde, considera la skill inaccesible e infórmalo
- Requiere `curl` y `jq`
- No verificado en vivo: `getsavepath`, `setlabel` y `diskspace`

## Referencia

- [ruTorrent en GitHub](https://github.com/Novik/ruTorrent)
- [Imagen mondedie/rutorrent](https://github.com/crazy-max/docker-rtorrent-rutorrent)

Para la referencia local detallada, consulta:
- **[Endpoints de la API](./references/api-endpoints.md)** - Endpoints, campos y modos de httprpc
- **[Referencia rápida](./references/quick-reference.md)** - Operaciones habituales con ejemplos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Autenticación, conexión, rutas y errores
