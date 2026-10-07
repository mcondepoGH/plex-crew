# Nombrado de Plex (`plex-naming`)

Especialista en nombres de Plex: renombra series y películas con el formato de Plex y corrige emparejados erróneos.

## Cuándo se usa y qué no hace

Ejemplos:

- "Esta serie sale como otra en Plex."
- "Normaliza los nombres de la carpeta de esta serie a `SxxExx`."
- "Añade el id `{imdb-...}` a esta película."
- "Pon los especiales como `S00Exx`."

Límites:

- No borra nada. Si hace falta borrar, devuelve la propuesta al orquestador.
- En zurg solo renombra; nunca crea carpetas ni ficheros.
- No lanza escaneos de Plex tras renombrar; solo el emparejado de verificación cuando arregla un mismatch.
- No toca duplicados de episodio o temporada.
- Solo escribe bajo las rutas de `scope.conf`; si el hook deniega una ruta, no intenta rodearlo y lo devuelve al orquestador.

## Funciones

- Renombrar carpetas y ficheros de series y películas según `plex-naming-rules`: `SxxExx`, ids `{imdb-...}`, calidad, especiales `S00Exx`.
- Detectar y corregir emparejados erróneos (`match_release`, `set_external_id`).
- Descubrir rutas de zurg (biblioteca) y bibliotecas locales (skill `plex`), separando hallazgos locales y de Real-Debrid.
- Comprobar si Season Fix cubre el caso antes de renombrar episodios en zurg.
- Añadir la calidad al nombre solo si el nombre original ya la define; no se comprueba contra el fichero.
- Probar con un solo elemento y pedir segunda confirmación antes del resto en renombrados masivos.
- Terminar con una tabla: nombre anterior, nombre nuevo y ubicación (movies o shows).

## Tools

| Tool | Para qué sirve |
|---|---|
| `Read`, `Glob`, `Grep` | Leer y localizar ficheros |
| `Bash` | Comandos de shell (por ejemplo, renombrados locales); sujeto a ambos hooks |
| `Edit` | Editar ficheros; sujeto a `enforce-agent-scope` |

### Tools `mcp__zurg__*`

| Prefijo | Tool | Uso |
|---|---|---|
| `library` | `zurg_library_search` | Localizar releases por texto |
| `library` | `zurg_library_list` | Listar releases de la biblioteca |
| `library` | `zurg_library_directories` | Descubrir las carpetas de la biblioteca |
| `release` | `zurg_release_get` | Ver los datos de un release |
| `release` | `zurg_release_files` | Listar los ficheros de un release |
| `release` | `zurg_release_rename` | Renombrar un release |
| `release` | `zurg_release_files_rename` | Renombrar ficheros dentro de un release |
| `release` | `zurg_release_set_external_id` | Fijar el id externo (imdb, tmdb, tvdb) |
| `plex` | `zurg_plex_match_release` | Comprobar cómo empareja Plex un release |
| `plex` | `zurg_plex_match_all` | Comprobar el emparejado de todos los releases |
| `plex` | `zurg_plex_status` | Estado de la integración con Plex |
| `plex` | `zurg_plex_scan_releases` | Pedir a Plex el escaneo de releases concretos |

Los prefijos `clients`, `config`, `diagnostics`, `mount`, `provider`, `repair`, `server` y `system` no están declarados para este agente.

## Skills que usa

- [`plex-naming-rules`](../../skills/plex-naming-rules/README.md)
- [`zurg-rules`](../../skills/zurg-rules/README.md)
- [`plex`](../../skills/plex/README.md)

## Hooks y salvaguardas

| Salvaguarda | Efecto |
|---|---|
| [`confirm-destructive`](../../../hooks/README.md#confirm-destructivejs) | Deniega comandos `Bash` destructivos salvo que lleven `PLEX_CREW_CONFIRMED=1`, que solo se pone tras la doble confirmación |
| [`enforce-agent-scope`](../../../hooks/README.md#enforce-agent-scopejs) | Registrado en el frontmatter de este agente (`Edit`, `Write`, `NotebookEdit`, `Bash`); es el único agente que lo tiene. Solo deja escribir bajo las rutas de `scope.conf` |
| Doble confirmación | Dos mensajes distintos del usuario antes de cualquier operación destructiva, incluso en modo automático |

`scope.conf` se busca en `$PLEX_CREW_CONFIG` o, si no existe, en `~/.config/plex-crew/scope.conf` (plantilla: `scope.conf.example`). Admite una ruta absoluta por línea, comentarios con `#` y `~`. Sin rutas, el hook deniega toda escritura. Ante la duda (sustituciones, `eval`, `xargs`, intérpretes...) también deniega. No es un sandbox y no ve las tools MCP.

## Colaboración con otros agentes

- Lo invoca el orquestador con `Agent`; no lanza subagentes.
- Si necesita otro dominio (por ejemplo un problema de zurg o añadir contenido), lo devuelve al orquestador.
- Las operaciones destructivas las propone y el orquestador pide la doble confirmación.
