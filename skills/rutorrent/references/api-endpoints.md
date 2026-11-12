# Endpoints de ruTorrent usados por la skill

Versión de referencia: imagen `mondedie/rutorrent` (ruTorrent 5.2.10, rTorrent 0.15). nginx escucha en el puerto 8080 y, en principio, sin prefijo de URL (no verificado).

## Autenticación

Autenticación básica de nginx (`HTTP_AUTH=true`), que cubre la interfaz, `/plugins/...`, `/php/` y `/RPC2`. El script la pasa por stdin a curl (`-K -` con `user = "usuario:contraseña"`), nunca en argv. Un 401 indica credenciales incorrectas.

## Inicio rápido

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/rutorrent/scripts/rutorrent.sh" list --raw
```

## httprpc: `POST /plugins/httprpc/action.php`

Cuerpo `application/x-www-form-urlencoded` con `mode=<modo>`, `hash=<HASH>` (repetible) y `v=<valor>`.

| Modo | Uso en el script | Efecto |
|---|---|---|
| `list` | `list`, `info` | Lista de torrents. Formato JSON no documentado: `{"t":{"HASH":[campos...]}}`; el resumen usa los índices 4 (nombre), 5 (tamaño), 8 (bytes hechos) y 14 (etiqueta); ruta de guardado en 25, todo confirmado en vivo. `info` devuelve la fila como array JSON posicional, sin claves |
| `fls` | `files`, `remove-with-data` | Ficheros del torrent |
| `getsavepath` | `remove-with-data` | Ruta de guardado (ruta del contenedor; formato no verificado) |
| `start` / `stop` | `start`, `stop` | Inicia o para |
| `recheck` | `recheck` | Recomprueba |
| `setlabel` | `label` | Etiqueta (`s=label`, `v=<etiqueta>`; no verificado) |
| `remove` | `remove` | Quita el torrent y **conserva los datos** |
| `removewithdata` | `remove-with-data` | Quita el torrent y **borra los datos** (plugin `erasedata`) |

Modos que existen pero la skill no usa: `prs`, `trk`, `stg`, `ttl`, `opn`, `prp`, `trkstate`, `setprio`, `getsavepath`, `updatetracker`, `pause`, `unpause`, `dsetprio`, `trkall`, `setsettings`, `setprops`, `setul`, `setdl`.

## Añadir: `POST /php/addtorrent.php`

Multipart. Campos: `url` o `torrent_file[]`; opcionales `label`, `dir_edit`, `torrents_start_stopped`, `not_add_path`, `fast_resume`, `json`. El script usa `url` o `torrent_file[]`, `label`, `torrents_start_stopped`, `json=1` y, con `--dir`, `dir_edit` (y `not_add_path=1` con `--no-add-name`).

Según el código de ruTorrent (`php/addtorrent.php`, rama `master`): `dir_edit` se recorta y se valida con `correctDirectory` e `isInsideTopDirectory` (si falla, estado `FailedDirectory`); `torrents_start_stopped` y `not_add_path` se comprueban con `isset()`, así que cualquier valor los activa. `not_add_path` pasa a `rTorrent::sendTorrent()` como `$isAddPath = false`, y entonces rTorrent recibe `d.set_directory_base=<dir>` en vez de `d.set_directory=<dir>` (`php/rtorrent.php`). Con `dir_edit` vacío y `not_add_path`, ruTorrent usa su directorio por defecto. Para sembrar un torrent de un solo fichero ya existente en `<dir>/<nombre>.ext` se envía `dir_edit=<dir>` y `not_add_path=1`.

## Crear: `POST /plugins/create/action.php`

Requiere el plugin `create` y `mktorrent`. `cmd=create` con `path_edit`, `trackers` (separados por `\r`), `comment`, `source`, `piece_size`, `private`, `start_seeding`, `hybrid`. Devuelve un id de tarea. El script envía `start_seeding=1` por defecto y `start_seeding=0` con `--no-seed`. Según el código (`plugins/create/createtorrent.php`, ruTorrent `master` 5609c62), con `start_seeding` verdadero la tarea, al guardar el `.torrent`, lo guarda también con nombre único en la carpeta de subidas, y llama a `rTorrent::sendTorrent($torrent, true, true, dirname(path_edit), null, true, ...)` (líneas 88-102): `load_raw_start` (o `load_start` si el torrent supera el límite de paquete) con `d.set_directory=<carpeta padre de RUTA>`, previo `fastResume` si hay datos, solo si `correctDirectory` acepta la ruta. En `sendTorrent` (`php/rtorrent.php` 175-263) la directory se valida (`prepareDirectory`, dentro del `topDirectory`) y se hace `mkdir -p`. No se verifica sin instancia real: el efecto con un hash ya cargado (el código no lo comprueba; lo decide rTorrent), ni que el seed quede 100% al terminar, ni que la tarea falle de forma visible si `correctDirectory` rechaza la ruta (en ese caso el código no carga nada y sale con 0). Seguimiento con `tasks`. Descarga del `.torrent`: `cmd=getfile&no=ID` (comando `getfile` del script). En `plugins/create/action.php`, la rama `getfile` hace `rTask::formatPath($_REQUEST['no'])`, abre `<carpeta de la tarea>/result.torrent` y, si es válido, lo envía con `Torrent::send()` (cuerpo bencode, `Content-Type: application/x-bittorrent`, `Content-Disposition: attachment`); si no, responde `404`. El id de tarea que reconoce `rTask::formatId` (`plugins/_task/task.php`) cumple `^[0-9a-f]+\.[0-9]+$`. `cmd=rtget` (trackers recientes) no se usa.

## Tareas: `POST /plugins/_task/action.php`

`cmd=list|check|kill|remove`. El script solo usa `cmd=list` (`tasks`).

## Otros

- Datos: `/plugins/data/action.php` (no usado)
- Espacio: `GET /plugins/diskspace/action.php` (`diskspace`; no verificado)
- Borrado directo: `/plugins/erasedata/action.php` (no usado; el hook lo trata como destructivo)

## `/RPC2` (no usado)

XML-RPC directo por SCGI, sin el filtro de `xmlrpc_proxy.php`. Si no hay autenticación, permite `execute2` y por tanto ejecutar órdenes en el servidor. La skill no lo usa; el hook trata como destructivas las llamadas manuales con `d.erase` o `execute`.

## Códigos HTTP

| Código | Significado |
|---|---|
| 200 | Correcto (ruTorrent puede devolver 200 con un error en el cuerpo: revisa la salida) |
| 401 | Credenciales incorrectas |
| 404 | Plugin no instalado o prefijo de URL distinto |
| 5xx | Error del servidor |
