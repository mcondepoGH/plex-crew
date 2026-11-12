# plex-crew

Versión 1.4.1.

Conjunto de agentes y skills de Claude Code para operar un servidor Plex y su ecosistema. Un orquestador recibe cada petición y la delega en el especialista adecuado. Se asume que las horas que menciona el usuario son la hora local de la máquina donde corre el plugin (zona horaria del sistema).

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
- ruTorrent
- Agregarr (nueva en 0.3.0)

Este README es un índice: dice qué existe y dónde está documentado. Los comandos y herramientas de cada pieza viven en su propio README.

## Instalación

Skills opcionales: `caveman` (informes y síntesis tersos) y `superpowers` (depuración sistemática, verificación antes de dar algo por hecho, agentes en paralelo) mejoran el comportamiento de los agentes si están instaladas. No son requisito: sin ellas, el plugin funciona igual. Las reglas de plex-crew mandan sobre las suyas (ver `skills/plex-crew-rules`).

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

Una fila por variable. Se rellenan solo los servicios que uses. «Obligatoria: sí» significa obligatoria si usas esa skill.

#### Medios

| Variable | Obligatoria | Descripción | Skill |
|---|---|---|---|
| `PLEX_URL` | sí | URL base de Plex | `plex` |
| `PLEX_TOKEN` | sí | Token de autenticación de Plex | `plex` |
| `TAUTULLI_URL` | sí | URL base de Tautulli | `tautulli` |
| `TAUTULLI_API_KEY` | sí | Clave de API de Tautulli | `tautulli` |

#### Adquisición

| Variable | Obligatoria | Descripción | Skill |
|---|---|---|---|
| `PROWLARR_URL` | sí | URL base de Prowlarr | `prowlarr` |
| `PROWLARR_API_KEY` | sí | Clave de API de Prowlarr | `prowlarr` |
| `RADARR_URL` | sí | URL base de Radarr | `radarr` |
| `RADARR_API_KEY` | sí | Clave de API de Radarr | `radarr` |
| `SONARR_URL` | sí | URL base de Sonarr | `sonarr` |
| `SONARR_API_KEY` | sí | Clave de API de Sonarr | `sonarr` |
| `SEERR_URL` | sí | URL base de Seerr / Overseerr | `seerr` |
| `SEERR_API_KEY` | sí | Clave de API de Seerr / Overseerr | `seerr` |
| `CLI_DEBRID_URL` | sí | URL base de cli_debrid | `cli_debrid` |
| `CLI_DEBRID_USER` | sí | Usuario de cli_debrid | `cli_debrid` |
| `CLI_DEBRID_PASSWORD` | sí | Contraseña de cli_debrid | `cli_debrid` |
| `RUTORRENT_URL` | sí | URL base de ruTorrent | `rutorrent` |
| `RUTORRENT_USER` | no | Usuario de la autenticación básica, solo si ruTorrent la tiene | `rutorrent` |
| `RUTORRENT_PASSWORD` | no | Contraseña de la autenticación básica | `rutorrent` |
| `RUTORRENT_ALLOWED_DIR` | no | Prefijo (ruta del contenedor) permitido para crear torrents y borrar datos | `rutorrent` |
| `AGREGARR_URL` | sí | URL base de Agregarr (nueva en 0.3.0) | `agregarr` |
| `AGREGARR_API_KEY` | sí | Clave de API de Agregarr | `agregarr` |
| `DOZZLE_URL` | sí | URL base de Dozzle (no usa clave de API) | `dozzle` |

#### Ajustes opcionales

| Variable | Obligatoria | Descripción | Skill |
|---|---|---|---|
| `PLEX_CREW_CONFIG` | no | Ruta alternativa a `~/.claude/plex-crew/scope.conf`; la leen ambos hooks (`confirm-destructive` y `enforce-agent-scope`); se define en el entorno, no en el `.env` | ninguna (hooks) |
| `RADARR_DEFAULT_QUALITY_PROFILE` | no | ID del perfil de calidad al añadir películas (por defecto 1) | `radarr` |
| `SONARR_DEFAULT_QUALITY_PROFILE` | no | ID del perfil de calidad al añadir series (por defecto 1) | `sonarr` |

Las URL del `.env` van sin barra final (`http://host:puerto`).

## Skills

Cada skill tiene su `README.md` con el detalle. Todas son propias, siguen la misma estructura (`SKILL.md`, `README.md`, `scripts/` y `references/`) y su documentación está en español. La guía para crear o revisar skills está en [`skills/README.md`](skills/README.md).

### Skills propias

| Skill | Tipo | Propósito |
|---|---|---|
| [`prowlarr`](skills/prowlarr/README.md) | Servicio | Buscar en indexadores y gestionarlos (reescrita en sala limpia) |
| [`plex`](skills/plex/README.md) | Servicio | Explorar bibliotecas, buscar y ver sesiones (reescrita en sala limpia) |
| [`tautulli`](skills/tautulli/README.md) | Servicio | Estadísticas y actividad de Plex (reescrita en sala limpia) |
| [`sonarr`](skills/sonarr/README.md) | Servicio | Gestión de series (reescrita en sala limpia) |
| [`radarr`](skills/radarr/README.md) | Servicio | Gestión de películas (reescrita en sala limpia) |
| [`seerr`](skills/seerr/README.md) | Servicio | Buscar y gestionar solicitudes en Seerr / Overseerr |
| [`cli_debrid`](skills/cli_debrid/README.md) | Servicio | Estado, cola, descargas y logs de cli_debrid |
| [`rutorrent`](skills/rutorrent/README.md) | Servicio | Listar, añadir, crear y quitar torrents de ruTorrent |
| [`agregarr`](skills/agregarr/README.md) | Servicio | Listas y colecciones de Agregarr (nueva en 0.3.0) |
| [`dozzle`](skills/dozzle/README.md) | Servicio | Estado y logs de los contenedores a través de Dozzle (solo lectura) |
| [`plex-crew-rules`](skills/plex-crew-rules/README.md) | Reglas | Reglas globales: hora, doble confirmación, secretos, tareas programadas |
| [`plex-naming-rules`](skills/plex-naming-rules/README.md) | Reglas | Nombrado de Plex para series, películas, especiales e identificadores |
| [`arr-language-filters`](skills/arr-language-filters/README.md) | Reglas | Cómo filtran el idioma cli_debrid, Radarr/Sonarr y Prowlarr, y sus límites |

La carpeta [`_lib`](skills/_lib/README.md) no es una skill: contiene el código de shell compartido por los scripts.

## Agentes

Solo el orquestador lanza subagentes; los especialistas devuelven sus propuestas a él.

| Agente | Para qué sirve | Documentación |
|---|---|---|
| `orchestrator` | Sesión principal: clasifica, delega, pide confirmaciones, gestiona crons y artefactos | [README](docs/agents/orchestrator.md) |
| `plex-naming` | Renombra series y películas al formato de Plex y corrige emparejados | [README](docs/agents/plex-naming.md) |
| `arr-acquisition` | Búsqueda, adquisición y auditoría con Radarr, Sonarr, Prowlarr, Seerr, cli_debrid y ruTorrent | [README](docs/agents/arr-acquisition.md) |

## Hooks y seguridad

| Hook | Para qué sirve | Documentación |
|---|---|---|
| `confirm-destructive.js` | Bloquea comandos `Bash` destructivos sin doble confirmación (todos los agentes) | [hooks/README.md](hooks/README.md#confirm-destructivejs) |
| `enforce-agent-scope.js` | Limita las rutas donde escribe `plex-naming` según `scope.conf` (sin él, deniega todo a `plex-naming`) | [hooks/README.md](hooks/README.md#enforce-agent-scopejs) |

Son una red de seguridad, no un sandbox.

- Doble confirmación: toda operación destructiva exige dos mensajes distintos del usuario, incluso en modo automático, salvo la exención de retención de backups, si el usuario la ha concedido de forma explícita (ver `plex-crew-rules`). El subagente propone y el orquestador pide las confirmaciones.
- Las reglas globales del proyecto están en la skill [`plex-crew-rules`](skills/plex-crew-rules/README.md).

## Configuración

| Fichero | Para qué sirve |
|---|---|
| `.env` (en `~/.claude/plex-crew/`) | Credenciales de los servicios (ver [Modelo de credenciales](#modelo-de-credenciales)) |
| `.claude-plugin/plugin.json` | Manifiesto del plugin (metadatos) |
| `.claude-plugin/marketplace.json` | Catálogo del marketplace |
| `settings.json` | Agente de sesión por defecto (`orchestrator`), aportado por el plugin |
| `hooks/hooks.json` | Registro de los hooks `confirm-destructive` y `enforce-agent-scope` (plugin) |
| `~/.claude/plex-crew/scope.conf` | Raíces de medios: rutas donde puede escribir `plex-naming` y rutas que vigila `confirm-destructive` |

### Alcance de escritura (`scope.conf`)

La plantilla es `scope.conf.example`. Cópiala y ajusta las rutas:

```bash
mkdir -p ~/.claude/plex-crew
cp scope.conf.example ~/.claude/plex-crew/scope.conf
```

Una ruta absoluta por línea; se ignoran las líneas vacías y las que empiezan por `#`. El ejemplo usa rutas ficticias (`/ruta/a/plex/{movies,shows,anime,music}`): sustitúyelas por tus raíces reales. Para guardarlo en otro sitio, define `PLEX_CREW_CONFIG`.

`scope.conf` (o `PLEX_CREW_CONFIG`) lo leen **ambos** hooks y los dos fallan cerrados si falta o está vacío:

- `enforce-agent-scope`: deniega toda escritura a `plex-naming`.
- `confirm-destructive`: deniega las operaciones destructivas de fichero (no puede saber qué rutas son de medios).

Dos detalles de comportamiento:

- `mv` dentro de las raíces de medios está permitido a propósito: es la operación de renombrado de `plex-naming`.
- El marcador `PLEX_CREW_CONFIRMED=1` debe ir al inicio del mismo segmento del comando que la operación destructiva (`PLEX_CREW_CONFIRMED=1 <comando destructivo>`); un marcador en otro segmento no cuenta.

Detalle en [hooks/README.md](hooks/README.md#scopeconf).

## Desarrollo

- El `CLAUDE.md` de la raíz es solo la guía de desarrollo del repositorio: un plugin instalado no lo carga.
- `claude plugin validate .` emite un aviso por ese `CLAUDE.md`: es esperado y no indica un fallo.
- `tests/smoke.sh` ejecuta las comprobaciones estáticas (sintaxis, JSON, frontmatter, scripts sin red); también corre en CI (`.github/workflows/ci.yml`).

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
├── .env.example              Plantilla de credenciales
├── .claude-plugin/            plugin.json y marketplace.json
├── settings.json              Agente de sesión por defecto (orchestrator)
├── scope.conf.example         Plantilla del alcance de escritura
├── agents/                    Definiciones de los agentes
├── docs/agents/               Un .md de documentación por agente
├── skills/                    Una carpeta por skill (con su README.md, incluida dozzle) y _lib/
├── hooks/                     hooks.json, README.md y los dos .js
├── tests/                     smoke.sh (comprobaciones estáticas)
└── .github/workflows/         ci.yml
```

## Ficheros relacionados

- [`CLAUDE.md`](CLAUDE.md): guía de desarrollo y estructura del proyecto.
- [`.env.example`](.env.example): plantilla de credenciales.
- [`scope.conf.example`](scope.conf.example): plantilla del alcance de escritura.
- [`skills/README.md`](skills/README.md): estándar para crear skills.
- [`hooks/README.md`](hooks/README.md): hooks de seguridad.

