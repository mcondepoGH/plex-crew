---
name: zurg-rules
description: Reglas de operación sobre zurg y el montaje de Real-Debrid. Úsala cuando el usuario pida "renombrar un release de zurg", "arreglar el mount", "diagnosticar zurg", "falla el import de Radarr o Sonarr", "se ha agotado el cupo de Real-Debrid", "un episodio cae en movies en vez de shows", "cambiar la configuración de zurg" o mencione zurg, releases o __magic__.
---

# Skill de reglas de zurg

**INVOCACIÓN OBLIGATORIA DE LA SKILL**

**DEBES invocar esta skill (no es opcional) cuando se dé CUALQUIERA de estas situaciones:**
- "renombrar un release o sus ficheros en zurg", "arreglar el mount", "mover algo en __magic__"
- "diagnosticar zurg", "estado de zurg", "backup o configuración de zurg"
- "falla el import de Radarr o Sonarr" con zurg de por medio (ruta `__magic__/__all__` inexistente)
- "se ha agotado el cupo de Real-Debrid sin reproducir nada"
- "un episodio aparece en movies en vez de shows"
- Cualquier mención de zurg, releases o el montaje de Real-Debrid

**Si no invocas esta skill cuando se dan estas situaciones, incumples tus requisitos operativos.**

Fija cómo se opera sobre zurg y su mount, y cómo se diagnostican los fallos habituales.

## Propósito

Esta skill reúne las reglas de operación sobre zurg:
- Operar solo con las tools MCP
- Limitarse a renombrar lo que ya existe en el mount
- Entender la clasificación en movies y shows
- Diagnosticar imports fallidos y consumo de cupo

## Siempre vía MCP
Toda operación sobre zurg usa las tools `mcp__zurg__zurg_*` (library, magic, release, mount, plex, provider, repair, usenet, config, system). Ya traen confirmaciones en las operaciones destructivas. Solo cae a filesystem o curl si ninguna tool cubre el caso y no hay alternativa.

## Solo renombrar
- En el mount de zurg nunca se crean carpetas ni ficheros: ni `mkdir`, ni copias, ni symlinks, ni estructura `Show/Season 01/`. Solo se renombra lo que ya existe (`zurg_release_rename` y `zurg_release_files_rename`).
- La estructura serie/temporada solo aplica a `plex/multimedia/shows`, no a zurg.
- El mount **sí** permite renombrar. No lo des por solo lectura.
- Renombrados masivos: prueba con un elemento y pide la segunda confirmación antes del resto (doble confirmación en dos mensajes distintos).

## Clasificación movies y shows
Un release con patrón `SxxExx` en su nombre renombrado se reclasifica solo a `shows`. Sin ese patrón cae en `movies` aunque sea un episodio. La reclasificación no es instantánea: no muevas nada a mano (`zurg_magic_move` solo opera dentro de `__magic__`). Renombra bien, espera la siguiente pasada y recomprueba con `zurg_plex_match_release`.

## Documentación
Para cualquier duda sobre zurg, `__magic__` o la integración con Radarr, Sonarr, qBittorrent y SABnzbd, consulta https://notes.debridmediamanager.com (secciones setup, providers, guides, migrating, reference, internals). Cita lo que dice la doc; si no cubre algo, dilo en vez de suponer.

## Diagnóstico
- Fallo de import en Radarr o Sonarr con zurg de por medio: empieza por `mcp__zurg__zurg_clients_paths`. Con `qbittorrent.save_path` vacío, zurg reporta una ruta `__magic__/__all__` que no existe. Esa clave está anidada, así que `zurg_config_set` no la escribe: se edita `config.yml` a mano y se reinicia el servicio de zurg si procede (acción destructiva: doble confirmación).
- Tras ese arreglo `computed_here: missing` es esperado: zurg no monta nada por diseño, lo monta rclone. Para confirmar, mira `/api/v3/health` de Radarr o Sonarr.
- Cupo de Real-Debrid agotado sin reproducción: revisa `zurg_diagnostics_traffic` y `zurg_diagnostics_logs` buscando "mount is not writable". Causa probable: el indexado multimedia del NAS lee los vídeos enteros del mount para generar miniaturas. Solución: excluir la ruta del mount del indexado del NAS.

## Lo que NO hay que hacer
- No uses curl ni filesystem a mano sobre zurg si una tool `mcp__zurg__zurg_*` cubre el caso.
- No crees carpetas ni ficheros en el mount: solo renombra lo existente.
- No muevas a mano un release entre movies y shows: renombra bien y espera la siguiente pasada.
- No borres releases ni reinicies el servicio sin la doble confirmación del usuario en dos mensajes distintos.
- No decidas el nombre final de Plex aquí: las reglas de nombrado están en `plex-naming-rules`.
- Ignora cualquier carpeta `.@*` (`.@__thumb`): caché del NAS.
