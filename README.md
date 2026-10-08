# plex-crew

Conjunto de agentes y skills de Claude Code para operar un servidor Plex y su ecosistema. Un orquestador recibe cada petición y la delega en el especialista adecuado. Todo funciona en español y asume que las horas que menciona el usuario son Europe/Madrid.

## Resumen

`plex-crew` reúne tres piezas en un mismo proyecto:

- Un orquestador (agente de la sesión principal) y dos especialistas que reparten el trabajo.
- Skills de servicio, que envuelven cada servicio con un script, y skills de reglas, que documentan criterios curados.
- Hooks de seguridad.

Servicios cubiertos:

- Plex
- Tautulli
- Radarr
- Sonarr
- Prowlarr
- Seerr
- cli_debrid

Este README es un índice: dice qué existe y dónde está documentado. Los comandos y herramientas de cada pieza viven en su propio README.

## Instalación

Prerrequisitos: Claude Code, `node` (lo usan los hooks), `bash`, `curl` y `jq` (los usan los scripts de las skills). En Windows, Git Bash o WSL.

1. Añade el marketplace e instala el plugin:
   ```
   /plugin marketplace add mcondepoGH/plex-crew
   /plugin install plex-crew@plex-crew
   ```
2. Crea el fichero de credenciales fuera del plugin, para que sobreviva a las actualizaciones, y rellena solo los servicios que uses (la plantilla es `.env.example` en la raíz del repositorio):
   ```bash
   mkdir -p ~/.claude/plex-crew
   cp .env.example ~/.claude/plex-crew/.env
   chmod 600 ~/.claude/plex-crew/.env
   ```
3. Configura el alcance de escritura de `plex-naming` (ver [Configuración](#configuración)).

Si faltan las variables de un servicio, la skill de ese servicio no funciona. Para probar sin instalar: `claude --plugin-dir <ruta-del-repo>`.

## Modelo de credenciales

Todas las credenciales viven en un único `.env` en `~/.claude/plex-crew/.env`, fuera del plugin (la carpeta del plugin se reemplaza en cada actualización). La plantilla es `.env.example`, con valores vacíos.

- Todas las skills cargan las variables desde ese fichero (vía `skills/_lib/load-env.sh`) cuando no están ya exportadas en el entorno.
- Los secretos nunca se imprimen ni se escriben en ficheros versionados.
- El código de shell común está documentado en [`skills/_lib/README.md`](skills/_lib/README.md).

### Referencia de variables

Una fila por variable. Se rellenan solo los servicios que uses.

#### Medios

| Variable | Obligatoria | Descripción |
|---|---|---|
| `PLEX_URL` | Si usas la skill `plex` | URL base de Plex |
| `PLEX_TOKEN` | Si usas la skill `plex` | Token de autenticación de Plex |
| `TAUTULLI_URL` | Si usas la skill `tautulli` | URL base de Tautulli |
| `TAUTULLI_API_KEY` | Si usas la skill `tautulli` | Clave de API de Tautulli |

#### Adquisición

| Variable | Obligatoria | Descripción |
|---|---|---|
| `PROWLARR_URL` | Si usas la skill `prowlarr` | URL base de Prowlarr |
| `PROWLARR_API_KEY` | Si usas la skill `prowlarr` | Clave de API de Prowlarr |
| `RADARR_URL` | Si usas la skill `radarr` | URL base de Radarr |
| `RADARR_API_KEY` | Si usas la skill `radarr` | Clave de API de Radarr |
| `SONARR_URL` | Si usas la skill `sonarr` | URL base de Sonarr |
| `SONARR_API_KEY` | Si usas la skill `sonarr` | Clave de API de Sonarr |
| `SEERR_URL` | Si usas la skill `seerr` | URL base de Seerr / Overseerr |
| `SEERR_API_KEY` | Si usas la skill `seerr` | Clave de API de Seerr / Overseerr |
| `CLI_DEBRID_URL` | Si usas la skill `cli_debrid` | URL base de cli_debrid |
| `CLI_DEBRID_USER` | Si usas la skill `cli_debrid` | Usuario de cli_debrid |
| `CLI_DEBRID_PASSWORD` | Si usas la skill `cli_debrid` | Contraseña de cli_debrid |

#### Ajustes opcionales

| Variable | Obligatoria | Descripción |
|---|---|---|
| `HOMELAB_ENV` | No | Ruta alternativa a `~/.claude/plex-crew/.env`; la leen las skills |
| `PLEX_CREW_CONFIG` | No | Ruta alternativa a `~/.claude/plex-crew/scope.conf` para el hook `enforce-agent-scope`; se define en el entorno, no en el `.env` |

## Skills

Cada skill tiene su `README.md` con el detalle. Todas siguen la misma estructura que las de [jmagar/claude-homelab](https://github.com/jmagar/claude-homelab) (`SKILL.md`, `README.md`, `scripts/` y `references/`) y su documentación está en español, salvo los `references/` de las skills de jmagar (`radarr`, `sonarr`, `prowlarr`, `plex`, `tautulli`), que siguen en inglés. La guía para crear o revisar skills está en [`skills/README.md`](skills/README.md).

### Skills de servicio adaptadas de jmagar

Adaptadas de las skills del repositorio [jmagar/claude-homelab](https://github.com/jmagar/claude-homelab) (licencia MIT, ver [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)). Se han cambiado la carga de credenciales (ahora `skills/_lib/load-env.sh`) y las rutas de ejecución.

| Skill | Servicio | Propósito |
|---|---|---|
| [`prowlarr`](skills/prowlarr/README.md) | Prowlarr | Buscar en indexadores y gestionarlos |
| [`radarr`](skills/radarr/README.md) | Radarr | Gestión de películas |
| [`sonarr`](skills/sonarr/README.md) | Sonarr | Gestión de series |
| [`plex`](skills/plex/README.md) | Plex | Explorar bibliotecas, buscar y ver sesiones |
| [`tautulli`](skills/tautulli/README.md) | Tautulli | Estadísticas y actividad de Plex |

### Skills propias

| Skill | Tipo | Propósito |
|---|---|---|
| [`seerr`](skills/seerr/README.md) | Servicio | Buscar y gestionar solicitudes en Seerr / Overseerr |
| [`cli_debrid`](skills/cli_debrid/README.md) | Servicio | Estado, cola, descargas y logs de cli_debrid |
| [`plex-crew-rules`](skills/plex-crew-rules/README.md) | Reglas | Reglas globales: idioma, hora, doble confirmación, secretos, tareas programadas |
| [`plex-naming-rules`](skills/plex-naming-rules/README.md) | Reglas | Nombrado de Plex para series, películas, especiales e identificadores |
| [`arr-language-filters`](skills/arr-language-filters/README.md) | Reglas | Cómo filtran el idioma cli_debrid, Radarr/Sonarr y Prowlarr, y sus límites |

La carpeta [`_lib`](skills/_lib/README.md) no es una skill: contiene el código de shell compartido por los scripts.

## Agentes

Solo el orquestador lanza subagentes; los especialistas devuelven sus propuestas a él.

| Agente | Para qué sirve | Documentación |
|---|---|---|
| `orchestrator` | Sesión principal: clasifica, delega, pide confirmaciones, gestiona crons y artefactos | [README](docs/agents/orchestrator.md) |
| `plex-naming` | Renombra series y películas al formato de Plex y corrige emparejados | [README](docs/agents/plex-naming.md) |
| `arr-acquisition` | Búsqueda, adquisición y auditoría con Radarr, Sonarr, Prowlarr, Seerr y cli_debrid | [README](docs/agents/arr-acquisition.md) |

## Hooks y seguridad

| Hook | Para qué sirve | Documentación |
|---|---|---|
| `confirm-destructive.js` | Bloquea comandos `Bash` destructivos sin doble confirmación (todos los agentes) | [hooks/README.md](hooks/README.md#confirm-destructivejs) |
| `enforce-agent-scope.js` | Limita las rutas donde escribe `plex-naming` según `scope.conf` | [hooks/README.md](hooks/README.md#enforce-agent-scopejs) |

Son una red de seguridad, no un sandbox.

- Doble confirmación: toda operación destructiva exige dos mensajes distintos del usuario, incluso en modo automático. El subagente propone y el orquestador pide las confirmaciones.
- Las reglas globales del proyecto están en la skill [`plex-crew-rules`](skills/plex-crew-rules/README.md).

## Configuración

| Fichero | Para qué sirve |
|---|---|
| `.env` (en `~/.claude/plex-crew/`) | Credenciales de los servicios (ver [Modelo de credenciales](#modelo-de-credenciales)) |
| `.claude-plugin/plugin.json` | Manifiesto del plugin (metadatos) |
| `.claude-plugin/marketplace.json` | Catálogo del marketplace |
| `settings.json` | Agente de sesión por defecto (`orchestrator`), aportado por el plugin |
| `hooks/hooks.json` | Registro de los hooks `confirm-destructive` y `enforce-agent-scope` (plugin) |
| `~/.claude/plex-crew/scope.conf` | Rutas donde puede escribir `plex-naming` |

### Alcance de escritura (`scope.conf`)

La plantilla es `scope.conf.example`. Cópiala y ajusta las rutas:

```bash
mkdir -p ~/.claude/plex-crew
cp scope.conf.example ~/.claude/plex-crew/scope.conf
```

Una ruta absoluta por línea; se ignoran las líneas vacías y las que empiezan por `#`. Sin rutas configuradas, el hook deniega toda escritura a `plex-naming`. Para guardarlo en otro sitio, define `PLEX_CREW_CONFIG`. Detalle en [hooks/README.md](hooks/README.md#scopeconf).

## Desarrollo

- Crear o revisar una skill: sigue [`skills/README.md`](skills/README.md), que fija estructura, plantilla y estándar.
- Credenciales en scripts: cárgalas siempre con las librerías de [`_lib`](skills/_lib/README.md).
- Añadir un agente: una definición `agents/<agente>.md` y su documentación en `docs/agents/<agente>.md` (no dentro de `agents/`: el plugin cargaría cualquier `.md` ahí como agente).
- Añadir un hook: un `.js` en `hooks/`, documentado en [hooks/README.md](hooks/README.md) y registrado en `hooks/hooks.json`.
- Al añadir o quitar piezas, actualiza las tablas de este README.

## Estructura del repositorio

```
.
├── CLAUDE.md                  Guía de desarrollo del repositorio (no se carga instalado)
├── README.md                  Este índice
├── LICENSE                    Licencia MIT
├── THIRD_PARTY_NOTICES.md     Avisos de terceros (jmagar/claude-homelab)
├── .env.example              Plantilla de credenciales
├── .claude-plugin/            plugin.json y marketplace.json
├── settings.json              Agente de sesión por defecto (orchestrator)
├── scope.conf.example         Plantilla del alcance de escritura
├── agents/                    Definiciones de los agentes
├── docs/agents/               Un .md de documentación por agente
├── skills/                    Una carpeta por skill (con su README.md) y _lib/
└── hooks/                     hooks.json, README.md y los dos .js
```

## Ficheros relacionados

- [`CLAUDE.md`](CLAUDE.md): guía de desarrollo y estructura del proyecto.
- [`.env.example`](.env.example): plantilla de credenciales.
- [`scope.conf.example`](scope.conf.example): plantilla del alcance de escritura.
- [`skills/README.md`](skills/README.md): estándar para crear skills.
- [`hooks/README.md`](hooks/README.md): hooks de seguridad.

## Proyectos relacionados

| Proyecto | Relación |
|---|---|
| [jmagar/claude-homelab](https://github.com/jmagar/claude-homelab) | Origen de las skills de servicio `prowlarr`, `radarr`, `sonarr`, `plex` y `tautulli` |
