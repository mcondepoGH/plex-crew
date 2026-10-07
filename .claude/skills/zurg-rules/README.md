# zurg-rules

Reglas de operación sobre zurg y el montaje de Real-Debrid. No tiene scripts: toda la operación pasa por las tools MCP `mcp__zurg__zurg_*`.

## Cuándo se usa

Para cualquier tarea que toque zurg, releases, el mount o su configuración. La cargan el agente `zurg-ops` (`skills: zurg-rules`) y el agente `plex-naming`.

## Reglas

| Regla | Qué obliga | Cuándo aplica |
|-------|------------|---------------|
| Siempre vía MCP | Toda operación usa las tools `mcp__zurg__zurg_*` (library, magic, release, mount, plex, provider, repair, usenet, config, system), que ya traen confirmaciones en lo destructivo. Solo se cae a filesystem o curl si ninguna tool cubre el caso y no hay alternativa. | Siempre. |
| Solo renombrar | En el mount nunca se crean carpetas ni ficheros (ni `mkdir`, ni copias, ni symlinks, ni `Show/Season 01/`). Solo se renombra lo existente con `zurg_release_rename` y `zurg_release_files_rename`. | Cualquier cambio en el mount. |
| Estructura serie/temporada | Solo aplica a la biblioteca local `shows`, no a zurg. | Al organizar. |
| El mount permite renombrar | No se da por solo lectura. | Siempre. |
| Renombrados masivos | Se prueba con un elemento y se pide la segunda confirmación (en mensajes distintos) antes del resto. | Lotes. |
| Clasificación movies/shows | Un release con patrón `SxxExx` en su nombre se reclasifica solo a `shows`; sin él cae en `movies`. No es instantáneo y no se mueve nada a mano (`zurg_magic_move` solo opera dentro de `__magic__`). Se renombra bien, se espera la siguiente pasada y se recomprueba con `zurg_plex_match_release`. | Episodios mal clasificados. |
| Documentación | Dudas sobre zurg, `__magic__` o la integración con Radarr, Sonarr, qBittorrent y SABnzbd: consultar https://notes.debridmediamanager.com y citar lo que dice; si no cubre algo, decirlo. | Dudas de configuración. |
| Reinicio diario | El servidor se actualiza y reinicia sobre las 12:00 (Europe/Madrid). Un "Unable to connect" cerca de esa hora no es un incidente: esperar y reintentar; si sigue pasadas las 12:15 aprox., es fallo real. | Fallos de conexión. |

## Diagnósticos descritos

- **Fallo de import en Radarr o Sonarr con zurg de por medio.** Empezar por `mcp__zurg__zurg_clients_paths`. Con `qbittorrent.save_path` vacío, zurg reporta una ruta `__magic__/__all__` que no existe. Esa clave está anidada, así que `zurg_config_set` no la escribe: se edita `config.yml` a mano y se reinicia el servicio de zurg si procede (acción destructiva, con doble confirmación). Tras el arreglo, `computed_here: missing` es esperado, porque zurg no monta nada por diseño (lo hace rclone); para confirmar se mira `/api/v3/health` de Radarr o Sonarr.
- **Cupo de Real-Debrid agotado sin reproducción.** Revisar `mcp__zurg__zurg_diagnostics_traffic` y `mcp__zurg__zurg_diagnostics_logs` buscando "mount is not writable". Causa probable: el indexado multimedia del NAS lee los vídeos enteros del mount para generar miniaturas. Solución: excluir la ruta del mount del indexado.

## Tools que menciona la skill

`zurg_release_rename`, `zurg_release_files_rename`, `zurg_magic_move`, `zurg_plex_match_release`, `zurg_clients_paths`, `zurg_config_set`, `zurg_diagnostics_traffic`, `zurg_diagnostics_logs` (todas con prefijo `mcp__zurg__`).

## Variables de entorno

La skill no usa variables. Las tools MCP se conectan a través de `.mcp.json`, que lee `ZURG_MCP_URL` de `.env.example` (obligatoria para que el MCP de zurg funcione; sin valor por defecto).

## Ejemplos de uso

Son llamadas a tools, no scripts:

- Lectura: `mcp__zurg__zurg_clients_paths` para diagnosticar un import fallido de Radarr o Sonarr.
- Lectura: `mcp__zurg__zurg_plex_match_release` para comprobar cómo resuelve Plex un release tras renombrarlo.
- Lectura: `mcp__zurg__zurg_diagnostics_logs` buscando "mount is not writable" cuando se agota el cupo.
- Escritura (con confirmación): `mcp__zurg__zurg_release_rename` sobre un único release de prueba antes de un lote.

## Notas y límites

- Es documentación de reglas: no hay comprobaciones automáticas en la skill.
- Las operaciones destructivas (borrar releases, reiniciar el servicio) requieren la doble confirmación descrita en `CLAUDE.md`.
- La skill no cubre el nombrado de Plex; para eso véase `plex-naming-rules`.
