# Adquisición de contenido (`arr-acquisition`)

Especialista en buscar, añadir y auditar contenido con Radarr, Sonarr, Prowlarr, Seerr y cli_debrid, con foco en audio en español.

## Cuándo se usa y qué no hace

Ejemplos:

- "Añade esta película a Radarr."
- "Busca esta serie en los indexadores."
- "¿Por qué se descargó esta release en inglés?" (indexador, Custom Format e idioma real).
- "Pide esta serie en Seerr" o "¿cómo va la cola de cli_debrid?"
- "¿Quién está viendo algo ahora?" (Plex/Tautulli).

Límites:

- Quitar series o películas con borrado de ficheros requiere doble confirmación: devuelve la propuesta al orquestador.
- No imprime credenciales ni el contenido de `.env`.
- No repite el arreglo de `search: [q]` de Torrentio (ver `arr-language-filters`).
- No renombra nombres de Plex.

## Funciones

- Comprobar antes de añadir si ya existe (`exists` en Radarr o Sonarr).
- Buscar y añadir películas, colecciones y series; lanzar búsquedas.
- Buscar en indexadores y gestionar Prowlarr.
- Gestionar solicitudes de Seerr.
- Monitorizar cli_debrid, Plex y Tautulli.
- Auditar un grab: indexador de Prowlarr, Custom Format que coincidió e idioma real. Objetivo: audio en español; un subtitulado no cuenta.
- Presentar resultados en tablas markdown.

## Tools

- Lectura de ficheros:
  - `Read`: leer ficheros
  - `Glob`: localizar ficheros por patrón
  - `Grep`: buscar contenido
- Shell:
  - `Bash`: ejecutar los scripts de las skills (`${CLAUDE_PLUGIN_ROOT}/skills/<skill>/scripts/`); nunca curl con claves

## Skills que usa

- [`plex-crew-rules`](../../skills/plex-crew-rules/README.md)
- [`arr-language-filters`](../../skills/arr-language-filters/README.md)
- [`radarr`](../../skills/radarr/README.md)
- [`sonarr`](../../skills/sonarr/README.md)
- [`prowlarr`](../../skills/prowlarr/README.md)
- [`seerr`](../../skills/seerr/README.md)
- [`cli_debrid`](../../skills/cli_debrid/README.md)
- [`plex`](../../skills/plex/README.md)
- [`tautulli`](../../skills/tautulli/README.md)

## Hooks y salvaguardas

| Salvaguarda | Efecto |
|---|---|
| `confirm-destructive` | Deniega comandos `Bash` destructivos (incluido `curl -X DELETE`) salvo con `PLEX_CREW_CONFIRMED=1`, que solo se pone tras la doble confirmación |
| [`enforce-agent-scope`](../../hooks/README.md#enforce-agent-scopejs) | No le afecta (solo restringe a `plex-naming` por `agent_type`) |
| Doble confirmación | Quitar series o películas con borrado de ficheros, y borrar indexadores, se propone al orquestador antes de ejecutarse |

## Colaboración con otros agentes

- Lo invoca el orquestador con `Agent`; no lanza subagentes.
- Si tras añadir algo hace falta ajustar el nombre en Plex, lo indica y el orquestador delega en `plex-naming`.
- Propone las operaciones destructivas; el orquestador pide la doble confirmación.
