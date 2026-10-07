# plex-crew

Orquestador y subagentes de Claude Code para operar un homelab Plex (zurg, Radarr, Sonarr, Prowlarr, cli_debrid, Seerr).

## Arranque
1. Un único `.env` como fuente de datos: copia `.env.example` a `.env` y rellena URLs, claves y `ZURG_MCP_URL`. `.env` está ignorado por git.
2. Arranca Claude Code con ese `.env` cargado en el entorno:
   - En Docker: el servicio apunta al `.env` con `env_file`, p. ej. `env_file: ./claude-code/plex-crew/.env` en el servicio `claude-code` de `compose.yml` (la ruta debe resolver al `.env` de este repo).
   - Fuera de Docker: `scripts/start.sh` (carga `.env`, o `$HOMELAB_ENV` si está definido, y lanza `claude`; falla si falta el fichero o `ZURG_MCP_URL`).
3. `.claude/settings.json` fija `orchestrator` como agente de la sesión.
4. Pide lo que necesites; el orquestador elige especialista.

Alternativa: `claude --agent orchestrator`.

## Agentes
| Agente | Dominio |
|---|---|
| `orchestrator` | Enruta y sintetiza. No ejecuta. |
| `plex-naming` | Nombres, ids, especiales, emparejados erróneos. |
| `zurg-ops` | Estado, config, diagnóstico y backups de zurg. |
| `arr-acquisition` | Búsqueda y descarga, filtros de idioma, indexadores. |

Los subagentes no pueden lanzar otros subagentes: por eso el orquestador es el agente principal.

## MCP Servers

La configuración de servidores MCP vive en `.mcp.json`, en la raíz de este repo. Usa `${ZURG_MCP_URL}`, que Claude Code expande desde el entorno del proceso `claude`; el valor se define en `.env` (ver `.env.example`). Claude Code no lee `.env` por sí mismo: hay que cargarlo en el entorno antes de arrancar. Rellena `ZURG_MCP_URL` en el único `.env` (copia de `.env.example`) y usa una de estas vías:

- Docker: `env_file` en el servicio `claude-code`, apuntando a ese `.env`:
  ```yaml
  env_file: ./claude-code/plex-crew/.env
  ```
- Fuera de Docker: `scripts/start.sh`.

Sin la variable, `zurg` no carga y no hay tools `mcp__zurg__*`. La primera vez, Claude Code pide aprobar el servidor `zurg` de `.mcp.json` (aprobación manual).

**zurg** — fuente: https://github.com/debridmediamanager/zurg. MCP nativo del binario oficial, activado vía `config.yml: mcp.enabled: true` (no es código propio de este repo). Tools `mcp__zurg__*` usadas por agente, agrupadas por prefijo funcional con descripción de una línea cada grupo:

- `zurg-ops` usa: `clients_*` (paths, status, qbittorrent_jobs, sabnzbd_jobs — estado de clientes conectados), `config_*` (drift, file, get, keys, set — lectura/edición de config.yml), `diagnostics_*` (logs, traffic, process, memory — diagnóstico del proceso), `library_list`, `library_search`, `library_status` (listado/búsqueda de releases), `mount_status` (estado del mount), `plex_status` (estado integración Plex), `provider_*` (account, health, list, test, traffic — estado de proveedores debrid), `release_get`, `release_files` (detalle de un release), `repair_status`, `repair_outlook` (reparación), `server_info`, `system_backups`, `system_backup_create`, `system_doctor` (sistema y backups).
- `plex-naming` usa: `library_search`, `library_list`, `library_directories` (búsqueda/listado), `release_get`, `release_files`, `release_rename`, `release_files_rename`, `release_set_external_id` (renombrar y fijar ids), `plex_match_release`, `plex_match_all`, `plex_status`, `plex_scan_releases` (emparejado con Plex).
- `arr-acquisition` usa: `library_search`, `clients_paths`, `clients_status` (búsqueda y verificación de rutas/clientes).

## Skills
- Reglas: `plex-naming-rules`, `zurg-rules`, `arr-language-filters`, `safety-conventions`.
- Servicios: `prowlarr`, `radarr`, `sonarr`, `plex`, `tautulli`, `seerr`, `cli_debrid`. Cargan credenciales con `scripts/load-env.sh` (`HOMELAB_ENV` permite usar otro `.env`).

## Hooks
- `hooks/confirm-destructive.js`: bloquea comandos Bash destructivos salvo que lleven el marcador `PLEX_CREW_CONFIRMED=1` tras la doble confirmación.
- `hooks/enforce-agent-scope.js`: limita las rutas de escritura de un agente.

**Permisos de Bash (opcional, local)**: para ejecutar Bash sin avisos de permiso, cada persona puede crear `.claude/settings.local.json` (ignorado por git, personal) con `{"permissions":{"allow":["Bash"]}}`. Aun así, el hook `confirm-destructive.js` bloquea los comandos destructivos y solo los deja pasar con el prefijo `PLEX_CREW_CONFIRMED=1 ` tras la doble confirmación del usuario en dos mensajes.

## Requisitos
- Servidores MCP configurados — ver sección "MCP Servers".
- `node` para los hooks.
