---
name: zurg-rules
description: Reglas de operación sobre zurg y el montaje de Real-Debrid. Úsala para cualquier tarea que toque zurg, releases, el mount o la configuración.
---

# Reglas de zurg

## Siempre vía MCP
Toda operación sobre zurg usa las tools `mcp__zurg__zurg_*` (library, magic, release, mount, plex, provider, repair, usenet, config, system). Ya traen confirmaciones en las operaciones destructivas. Solo cae a filesystem o curl si ninguna tool cubre el caso y no hay alternativa.

## Solo renombrar
- En el mount de zurg nunca se crean carpetas ni ficheros: ni `mkdir`, ni copias, ni symlinks, ni estructura `Show/Season 01/`. Solo se renombra lo que ya existe (`zurg_release_rename` y `zurg_release_files_rename`).
- La estructura serie/temporada solo aplica a `plex/multimedia/shows`, no a zurg.
- El mount **sí** permite renombrar. No lo des por solo lectura.
- Nunca `chown`/`chmod` bajo el mount de zurg (siempre root por rclone FUSE). Renombrar sí está permitido.
- Renombrados masivos: prueba con un elemento y pide la segunda confirmación antes del resto (ver `safety-conventions`).

## Clasificación movies y shows
Un release con patrón `SxxExx` en su nombre renombrado se reclasifica solo a `shows`. Sin ese patrón cae en `movies` aunque sea un episodio. La reclasificación no es instantánea: no muevas nada a mano (`zurg_magic_move` solo opera dentro de `__magic__`). Renombra bien, espera la siguiente pasada y recomprueba con `zurg_plex_match_release`.

## Documentación
Para cualquier duda sobre zurg, `__magic__` o la integración con Radarr, Sonarr, qBittorrent y SABnzbd, consulta https://notes.debridmediamanager.com (secciones setup, providers, guides, migrating, reference, internals). Cita lo que dice la doc; si no cubre algo, dilo en vez de suponer.

## Reinicio diario
El servidor zurg se actualiza y reinicia sobre las 12:00 (Europe/Madrid). Si una tool falla con "Unable to connect. Is the computer able to access the url?" cerca de esa hora, no es un incidente: espera unos minutos y reintenta. Si sigue fallando pasadas las 12:15 aprox., trátalo como fallo real.

## Diagnóstico
- Fallo de import en Radarr o Sonarr con zurg de por medio: empieza por `mcp__zurg__zurg_clients_paths`. Con `qbittorrent.save_path` vacío, zurg reporta una ruta `__magic__/__all__` que no existe. Esa clave está anidada, así que `zurg_config_set` no la escribe: se edita `config.yml` a mano y se reinician los contenedores relacionados.
- Tras ese arreglo `computed_here: missing` es esperado: zurg no monta nada por diseño, lo monta rclone. Para confirmar, mira `/api/v3/health` de Radarr o Sonarr.
- Cupo de Real-Debrid agotado sin reproducción: revisa `zurg_diagnostics_traffic` y `zurg_diagnostics_logs` buscando "mount is not writable". Causa probable: el indexado multimedia del NAS lee los vídeos enteros del mount para generar miniaturas. Solución: excluir la ruta del mount del indexado del NAS.
