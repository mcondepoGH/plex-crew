# plex-crew

Conjunto de agentes y skills de Claude Code para operar un servidor Plex y su ecosistema (zurg, Radarr, Sonarr, Prowlarr, Seerr, Tautulli, cli_debrid). Un orquestador recibe cada petición y la delega en el especialista adecuado. Todo funciona en español y asume que las horas que menciona el usuario son Europe/Madrid.

## Instalación y arranque

1. Clona el repositorio y entra en la carpeta.
2. Copia la plantilla de credenciales y rellena solo los servicios que uses:
   ```bash
   cp .env.example .env
   ```
3. Define `ZURG_MCP_URL` en el `.env` (si arrancas con `scripts/start.sh`) o expórtala en tu shell.
4. Arranca el orquestador:
   ```bash
   scripts/start.sh               # carga el .env y ejecuta claude
   claude --agent orchestrator    # con ZURG_MCP_URL ya exportada
   ```
5. La primera vez Claude Code pide aprobar el servidor MCP `zurg` (definido en `.mcp.json`). Apruébalo.
6. Configura el alcance de escritura de `plex-naming`:
   ```bash
   mkdir -p ~/.claude/plex-crew
   cp scope.conf.example ~/.claude/plex-crew/scope.conf
   ```
   Edita el fichero con las rutas absolutas donde puede escribir (una por línea). Sin él, el hook deniega toda escritura a ese agente.

## Variables del `.env`

El `.env` no se versiona. Plantilla: `.env.example`.

| Variable | Servicio | Obligatoria |
|---|---|---|
| `ZURG_MCP_URL` | zurg (MCP) | Sí, para usar zurg |
| `PROWLARR_URL` | Prowlarr | Si usas la skill |
| `PROWLARR_API_KEY` | Prowlarr | Si usas la skill |
| `RADARR_URL` | Radarr | Si usas la skill |
| `RADARR_API_KEY` | Radarr | Si usas la skill |
| `SONARR_URL` | Sonarr | Si usas la skill |
| `SONARR_API_KEY` | Sonarr | Si usas la skill |
| `PLEX_URL` | Plex | Si usas la skill |
| `PLEX_TOKEN` | Plex | Si usas la skill |
| `TAUTULLI_URL` | Tautulli | Si usas la skill |
| `TAUTULLI_API_KEY` | Tautulli | Si usas la skill |
| `SEERR_URL` | Seerr / Overseerr | Si usas la skill |
| `SEERR_API_KEY` | Seerr / Overseerr | Si usas la skill |
| `CLI_DEBRID_URL` | cli_debrid | Si usas la skill |
| `CLI_DEBRID_USER` | cli_debrid | Si usas la skill |
| `CLI_DEBRID_PASSWORD` | cli_debrid | Si usas la skill |
| `HOMELAB_ENV` | Skills y `scripts/start.sh` | No: ruta alternativa al `.env` de la raíz |
| `PLEX_CREW_CONFIG` | Hook `enforce-agent-scope` | No: ruta alternativa a `~/.claude/plex-crew/scope.conf`; se define en el entorno, no en el `.env` |

## Agentes

Solo el orquestador lanza subagentes; los especialistas devuelven sus propuestas a él.

| Agente | Para qué sirve | Documentación |
|---|---|---|
| `orchestrator` | Sesión principal: clasifica, delega, pide confirmaciones, gestiona crons y artefactos | [README](.claude/agents/orchestrator/README.md) |
| `plex-naming` | Renombra series y películas al formato de Plex y corrige emparejados | [README](.claude/agents/plex-naming/README.md) |
| `zurg-ops` | Diagnóstico y operación de zurg y del mount de Real-Debrid | [README](.claude/agents/zurg-ops/README.md) |
| `arr-acquisition` | Búsqueda, adquisición y auditoría con Radarr, Sonarr, Prowlarr, Seerr y cli_debrid | [README](.claude/agents/arr-acquisition/README.md) |

## Skills

### Reglas

| Skill | Propósito |
|---|---|
| [`plex-naming-rules`](.claude/skills/plex-naming-rules/README.md) | Reglas de nombrado de Plex para series, películas, especiales e identificadores |
| [`zurg-rules`](.claude/skills/zurg-rules/README.md) | Reglas de operación sobre zurg y el mount de Real-Debrid |
| [`arr-language-filters`](.claude/skills/arr-language-filters/README.md) | Cómo filtran el idioma cli_debrid, Radarr/Sonarr y Prowlarr y sus límites |

### Servicios

| Skill | Propósito |
|---|---|
| [`prowlarr`](.claude/skills/prowlarr/README.md) | Buscar en indexadores y gestionarlos |
| [`radarr`](.claude/skills/radarr/README.md) | Gestión de películas |
| [`sonarr`](.claude/skills/sonarr/README.md) | Gestión de series |
| [`plex`](.claude/skills/plex/README.md) | Explorar bibliotecas, buscar y ver sesiones de Plex |
| [`tautulli`](.claude/skills/tautulli/README.md) | Estadísticas y actividad de Plex |
| [`seerr`](.claude/skills/seerr/README.md) | Buscar y gestionar solicitudes en Seerr/Overseerr |
| [`cli_debrid`](.claude/skills/cli_debrid/README.md) | Estado, cola, descargas y logs de cli_debrid |

La carpeta [`_lib`](.claude/skills/_lib/README.md) no es una skill: contiene el código de shell compartido por los scripts.

## Hooks y seguridad

| Hook | Para qué sirve | Documentación |
|---|---|---|
| `confirm-destructive.js` | Bloquea comandos `Bash` destructivos sin doble confirmación (todos los agentes) | [hooks/README.md](hooks/README.md#confirm-destructivejs) |
| `enforce-agent-scope.js` | Limita las rutas donde escribe `plex-naming` según `scope.conf` | [hooks/README.md](hooks/README.md#enforce-agent-scopejs) |

Son una red de seguridad, no un sandbox.

- Doble confirmación: toda operación destructiva exige dos mensajes distintos del usuario, incluso en modo automático. El subagente propone y el orquestador pide las confirmaciones.
- Los secretos viven en `.env` (ignorado por git); nunca se imprimen ni se escriben en ficheros versionados.

## Estructura de carpetas

```
.
├── CLAUDE.md                  Reglas globales del proyecto
├── README.md                  Este índice
├── .env.example               Plantilla de credenciales
├── .mcp.json                  Servidor MCP de zurg
├── scope.conf.example         Plantilla del alcance de escritura
├── .claude/
│   ├── settings.json          Agente por defecto y hook confirm-destructive
│   ├── agents/                Definiciones de los agentes y un README.md por agente
│   └── skills/                Una carpeta por skill (con su README.md) y _lib/
├── hooks/                     Hooks de seguridad (README.md y los dos .js)
└── scripts/                   start.sh
```
