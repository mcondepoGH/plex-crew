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
- No renombra nombres de Plex ni opera dentro de zurg más allá de consultar.

## Funciones

- Comprobar antes de añadir si ya existe (`exists` en Radarr o Sonarr) y si ya está en la biblioteca de zurg.
- Buscar y añadir películas, colecciones y series; lanzar búsquedas.
- Buscar en indexadores y gestionar Prowlarr.
- Gestionar solicitudes de Seerr.
- Monitorizar cli_debrid, Plex y Tautulli.
- Auditar un grab: indexador de Prowlarr, Custom Format que coincidió e idioma real. Objetivo: audio en español; un subtitulado no cuenta.
- Presentar resultados en tablas markdown.

## Tools

| Tool | Para qué sirve |
|---|---|
| `Read`, `Glob`, `Grep` | Leer y localizar ficheros |
| `Bash` | Ejecutar los scripts de las skills (`.claude/skills/<skill>/scripts/`); nunca curl con claves |

### Tools `mcp__zurg__*`

| Prefijo | Tool | Uso |
|---|---|---|
| `library` | `zurg_library_search` | Comprobar si algo ya está en la biblioteca |
| `clients` | `zurg_clients_paths` | Diagnosticar rutas de import de Radarr y Sonarr |
| `clients` | `zurg_clients_status` | Estado de la integración con los clientes |

## Skills que usa

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
| [`enforce-agent-scope`](../../../hooks/README.md#enforce-agent-scopejs) | No está registrado en este agente (solo en `plex-naming`) |
| Doble confirmación | Quitar series o películas con borrado de ficheros, y borrar indexadores, se propone al orquestador antes de ejecutarse |

## Colaboración con otros agentes

- Lo invoca el orquestador con `Agent`; no lanza subagentes.
- Si tras añadir algo hace falta ajustar el nombre en Plex o revisar zurg, lo indica y el orquestador delega en `plex-naming` o `zurg-ops`.
- Propone las operaciones destructivas; el orquestador pide la doble confirmación.
