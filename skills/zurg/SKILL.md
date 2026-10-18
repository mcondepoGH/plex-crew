---
name: zurg
description: Esta skill debe usarse cuando se opere sobre zurg (Real-Debrid) mediante sus tools MCP. Úsala cuando el usuario pida "zurg", "estado de zurg", "Season Fix", "corregir un emparejado de Plex", "set external id", "diagnosticar el montaje", "rutas de Radarr o Sonarr con zurg", "renombrar un release de zurg", "reparar releases rotas", o mencione __magic__, el mount de zurg o las tools mcp__zurg__.
---

# Skill de operación de zurg por MCP

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "zurg", "estado de zurg", "releases de zurg", "montaje de zurg", `__magic__`
- "Season Fix", "numeración absoluta", "renombrar episodios de zurg"
- "mal emparejado en Plex" cuando el contenido viva en zurg
- "fallan los imports de Radarr o Sonarr" con zurg de por medio

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Documenta los flujos y las reglas de uso de las tools `mcp__zurg__*`. No ejecuta nada por sí misma: no tiene scripts.

## Requisito

Detección: comprueba que tienes tools `mcp__zurg__*` (el MCP debe registrarse con el nombre `zurg`). Si no hay ninguna, di "MCP de zurg no configurado en tu perfil; debe registrarse con el nombre `zurg`" y para: no improvises con `curl` ni con el sistema de ficheros. `plex-naming` las declara en su `tools:`; si el usuario no tiene el MCP, el agente arranca igual pero sin ellas.

Los hooks cubren estas tools (ver `hooks/README.md`): las de solo lectura pasan, los renombrados se registran (y para `plex-naming` se comprueban contra `scope.conf`), y todo lo demás exige el marcador `PLEX_CREW_CONFIRMED=1` en algún campo de texto de los argumentos tras la doble confirmación.

**Regla: zurg siempre por MCP.** Nunca `curl` ni acceso a mano al sistema de ficheros para operar zurg. Solo se cae al sistema de ficheros si ninguna tool MCP cubre la operación y no hay alternativa, y se avisa al usuario.

## Tools (nombres verificados)

Los nombres reales llevan el prefijo `mcp__zurg__`. No inventes parámetros: consulta el esquema de la tool antes de llamarla.

| Uso | Tools |
|---|---|
| Estado general | `server_info`, `library_status`, `library_directories`, `provider_health` |
| Búsqueda | `zurg_library_search` |
| Emparejado | `zurg_plex_match_release`, `zurg_release_set_external_id`, `zurg_plex_match_all`, `zurg_plex_status`, `zurg_plex_scan_releases`, `zurg_plex_scan_section`, `zurg_plex_guard` |
| Renombrado | `zurg_release_rename`, `zurg_release_files_rename` |
| Reparación | `zurg_repair_status`, `zurg_repair_broken`, `zurg_repair_sweep` |
| Montaje y rutas | `zurg_mount_status`, `zurg_clients_paths` |
| Config | `zurg_config_set` (rechaza claves anidadas por diseño) |
| `__magic__` | `zurg_magic_move` (solo dentro del espacio `__magic__`) |

Nombre por confirmar: la tool de Season Fix. Solo consta el endpoint (`GET /torrents/season-fix/plan`, `POST /torrents/season-fix/apply` con `hashes`). Localízala en la lista de tools disponibles (busca `season`) antes de usarla.

Nombre por confirmar: `server_info`, `library_status`, `library_directories`, `provider_health` y `zurg_repair_sweep` no constan en la memoria del proyecto con el prefijo `zurg_`; comprueba el nombre exacto en tu sesión.

## Reglas duras

- En el montaje de zurg solo se renombra. Nunca se crean carpetas ni ficheros, ni copias, ni symlinks, ni estructura `Serie/Season 01/`. Esa estructura solo aplica a la biblioteca local de series.
- Renombrar está permitido: el montaje no es de solo lectura.
- Ignora las carpetas `.@*` (por ejemplo `.@__thumb`).
- Con patrón `SxxExx` en el nombre, zurg reclasifica el release a `shows` por sí solo. No es instantáneo: requiere una pasada de zurg. No muevas nada a mano entre `movies` y `shows`.
- Los duplicados de episodio o temporada no se tocan: Plex elige la mejor versión. Solo se informan si es relevante.
- Los renombrados masivos y las operaciones destructivas siguen la doble confirmación y el marcador `PLEX_CREW_CONFIRMED=1` de `plex-crew-rules`. Para un renombrado masivo, prueba antes con un solo elemento.
- Los nombres siguen `plex-naming-rules`. Esta skill no los redefine.

## Flujos

### Estado general
1. `server_info` para versión y estado del servidor.
2. `library_status` y `library_directories` para el estado de la biblioteca.
3. `provider_health` para el proveedor (Real-Debrid).

### Season Fix (antes de renombrar episodios a mano)
Corrige la numeración absoluta tipo fansub (`Show - 37.mkv`) a `S0XEYY` usando la forma real de temporadas del proveedor de metadatos.
1. Ejecuta el plan (solo lectura) y muéstralo al usuario.
2. Pide doble confirmación.
3. Aplica solo con los `hashes` confirmados.
4. Renombra a mano solo lo que Season Fix deja intacto: nombres que ya tienen token de temporada, extras (NCOP, NCED, OAD), ficheros sin número de episodio y series con emparejado sospechoso.

### Corregir un emparejado erróneo
1. Detecta: `zurg_plex_match_release` compara el título esperado con el que resolvió Plex. Marca solo discrepancias reales de identidad, no diferencias cosméticas de título.
2. Corrige el id: `zurg_release_set_external_id` sobre el hash del release, con el id correcto.
3. Reintenta: `zurg_plex_match_all`, espera con `zurg_plex_status` hasta `match_running: false`, y vuelve a comprobar con `zurg_plex_match_release`. Puedes probar `zurg_plex_scan_releases` dirigido a ese release.
4. Si Plex mantiene el emparejado antiguo (un escaneo no reidentifica una ruta sin cambios): renombra carpeta y fichero con `zurg_release_rename` y `zurg_release_files_rename`, con el id `{tmdb-...}` según `plex-naming-rules`. Una ruta nueva fuerza el reemparejado. Aplica el mismo patrón a todos los episodios de la temporada, no solo al roto.
5. Verifica: repite `match_all`, espera y comprueba que `plex_rating_key_stale` se limpia y que `plex_title` y `plex_year` coinciden.

Ninguna tool de zurg fuerza a Plex a reemparejar: los escaneos solo detectan ficheros nuevos o cambiados. Renombrar es el único disparador y no siempre es rápido. Si un renombrado tarda en detectarse, dilo; no lo repitas sin parar.

### Montaje y rutas
- `zurg_mount_status`: en este stack devuelve `enabled:false` y `state:stopped`. Es lo esperado: el montaje real lo hace el contenedor `rclone`, no zurg.
- Si Radarr o Sonarr fallan al importar con `path does not exist or is not accessible` sobre `__magic__/__all__/...`, usa `zurg_clients_paths` antes de sospechar de Plex o de las rutas de los arr.
- Causa conocida, ya resuelta (2026-10-06): `qbittorrent.save_path` vacío en el `config.yml` de zurg. `zurg_config_set` no puede arreglarlo porque es una clave anidada: se edita `config.yml` a mano y se reinician zurg y los contenedores relacionados.
- Tras el arreglo, `zurg_clients_paths` sigue devolviendo `computed_here: missing`. Es esperado. Para confirmar que está sano, mira `/api/v3/health` de Radarr y Sonarr con sus skills.

## Avisos operativos

- Zurg se actualiza y reinicia hacia las 12:00 de la hora local de la máquina donde corre el plugin. Las tools fallan con "Unable to connect. Is the computer able to access the url?". No es un incidente: espera unos minutos y reintenta, sin escalar. Si sigue fallando pasadas las 12:15 aproximadamente, trátalo como fallo real.
- `autoEmptyTrash` de Plex está desactivado a propósito (rclone es externo y un fallo del montaje con la papelera automática podría vaciar contenido). La papelera se vacía a mano con el comando `emptytrash` de la skill `plex`, que es destructivo y exige doble confirmación. `zurg_plex_guard` puede fallar mientras haya una sesión de reproducción activa: es normal.
- Nunca imprimas el token de zurg ni el contenido del `.env`.
- El rescan de Plex tras renombrar lo gestiona un script externo del usuario: no ofrezcas escaneos tras renombrar.

## Referencia

- [Documentación oficial de zurg](https://notes.debridmediamanager.com): contrástala (setup, providers, guides, reference, internals) antes de afirmar cómo se comporta zurg. Si la doc no cubre algo, dilo en lugar de suponer.
- `plex-crew-rules`: doble confirmación y marcador.
- `plex-naming-rules`: formato de nombres e ids.
