---
name: sonarr
description: Esta skill debe usarse cuando se gestionan series de TV en Sonarr. Úsala cuando el usuario pida "añadir una serie", "buscar en Sonarr", "encontrar una serie", "añadir a Sonarr", "eliminar una serie", "comprobar si una serie existe", "biblioteca de Sonarr", "buscar en TVDB", o mencione la gestión de series de TV u operaciones de Sonarr.
---

# Skill de gestión de series de Sonarr

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "añadir una serie", "añadir a Sonarr", "eliminar una serie"
- "buscar en Sonarr", "encontrar una serie", "buscar en TVDB"
- "comprobar si una serie existe", "biblioteca de Sonarr"
- Cualquier mención de la gestión de series de TV o de operaciones de Sonarr

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Busca series en TVDB, comprueba si están en la biblioteca de Sonarr y las añade o las quita.

## Propósito

Esta skill usa la API v3 de Sonarr para:
- Buscar series por texto (resultados con enlace a TVDB)
- Comprobar si una serie ya está en la biblioteca
- Mostrar las carpetas raíz, los perfiles de calidad y el estado de Sonarr
- Añadir una serie (modifica estado; por defecto lanza la búsqueda de episodios)
- Quitar una serie, con o sin borrado de ficheros (destructivo)

Los identificadores son de TVDB (`tvdbId`), no de TMDB: `radarr` y `seerr` usan TMDB.

## Configuración

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
SONARR_URL="http://localhost:8989"
SONARR_API_KEY="your-api-key"
# Opcional: perfil de calidad por defecto de `add` (1 si falta o está vacía)
# SONARR_DEFAULT_QUALITY_PROFILE=1
```

- `SONARR_URL`: URL de Sonarr con el puerto (8989 por defecto), sin barra final
- `SONARR_API_KEY`: clave de API, en Sonarr → Settings → General → Security → API Key
- `SONARR_DEFAULT_QUALITY_PROFILE`: id del perfil que usa `add` si no se indica otro
- Las variables ya exportadas en el entorno tienen prioridad sobre `~/.claude/plex-crew/.env` (si `SONARR_URL` y `SONARR_API_KEY` ya están exportadas, el fichero no se lee y `SONARR_DEFAULT_QUALITY_PROFILE` solo se toma del entorno)

## Ejecución del script

El script está en `${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh`. Llámalo siempre con esa ruta y con `bash`, sin cambiar el directorio de trabajo de la sesión. Necesita `curl` y `jq`. Hasta `help` exige credenciales cargadas.

## Comandos

`search-json` devuelve JSON (el array completo de Sonarr); el resto de comandos imprime texto. Sin comando, o con `help`, `-h` o `--help`, se muestra la ayuda por stdout (código de salida 0). Un comando desconocido imprime `ERROR: comando desconocido: <x>` y `Usa: sonarr.sh help` por stderr y termina con 1. `search` sin texto, y `exists`, `add` y `remove` con un `tvdbId` ausente o no numérico (o `add` con un perfil no numérico) imprimen `ERROR:` y el uso por stderr y terminan con 1. Si no se puede contactar con Sonarr, imprime `ERROR: no se pudo contactar con Sonarr en <URL>` (en `search` y `status`, los mensajes de la librería compartida) y termina con 1.

### Buscar series

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh" search "breaking bad"
bash "${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh" search-json "breaking bad"
```

**Salida:** `search` imprime hasta 10 líneas, una por resultado: `1. Breaking Bad (2008) - https://thetvdb.com/dereferrer/series/81189`. Sin resultados no imprime nada. Si falta el año o el id, aparece `null`. Solo se usa el primer argumento: entrecomilla el texto. `search-json` devuelve el JSON crudo, sin límite de 10 y con sinopsis, `titleSlug` y demás campos; úsalo cuando necesites más datos.

Presenta los resultados al usuario en una lista numerada con el enlace a TVDB.

### Comprobar si una serie existe

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh" exists 81189
```

**Salida:** `not_found` si no está en la biblioteca. Si está, dos líneas: `exists` y `ID: 12, Title: Breaking Bad, Seasons: 5`.

Ejecútalo siempre antes de `add`.

### Carpetas raíz y perfiles de calidad

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh" config
```

**Salida:** `=== Root Folders ===`, una línea `<id>: <ruta>` por carpeta, una línea en blanco, `=== Quality Profiles ===` y una línea `<id>: <nombre>` por perfil.

Úsalo para elegir el `profileId` de `add`.

### Estado de Sonarr

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh" status
```

**Salida:** una línea: `Sonarr 4.0.9.2244 - Sonarr (debian, branch main)`. Sin nombre de instancia sale `Sonarr`; sin sistema operativo o rama, `?`.

### Añadir una serie

**Modifica estado: confirma con el usuario antes de añadir** (la serie elegida y el perfil de calidad). Avisa de que, salvo con `--no-search`, Sonarr busca los episodios que faltan y puede iniciar descargas. Comprueba antes con `exists`.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh" add 81189
bash "${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh" add 81189 5
bash "${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh" add 81189 5 --no-search
```

**Salida:** en éxito, `✅ Added: Breaking Bad (2008) - 5 seasons` y, si la búsqueda estaba activa, `🔍 Search started` (código 0). Si TVDB no tiene la serie: `❌ Show not found with TVDB ID: <id>` (código 1). Si Sonarr responde con un HTTP que no es 2xx (serie ya existente, perfil inexistente), imprime por stderr `ERROR: POST /series respondió HTTP <código>: <mensaje>` y termina con 1; si responde 2xx sin `id`: `❌ Failed to add show` y, en otra línea, su mensaje (código 1).

`add` toma la primera carpeta raíz, monitoriza todos los episodios (`monitor: all`) y crea carpeta por temporada. `--no-search` desactiva la búsqueda y se reconoce en cualquier posición, pero el id va siempre primero y el perfil, de haberlo, segundo: en `add 81189 --no-search 5` el `5` se ignora y se usa el perfil por defecto.

### Quitar una serie

**Destructivo.** Según la skill `plex-crew-rules`, exige doble confirmación del usuario en dos mensajes distintos y anteponer `PLEX_CREW_CONFIRMED=1` al comando; el hook `confirm-destructive` bloquea cualquier `sonarr.sh remove` sin ese marcador, con o sin `--delete-files`. Pregunta siempre si se borran también los ficheros.

```bash
PLEX_CREW_CONFIRMED=1 bash "${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh" remove 81189
PLEX_CREW_CONFIRMED=1 bash "${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh" remove 81189 --delete-files
```

**Salida:** `🗑️ Removed: Breaking Bad (2008) (files kept)` o, con la opción, `🗑️ Removed: Breaking Bad (2008) + deleted files` (código 0, solo con HTTP 2xx; si no, `ERROR: DELETE /series/<id>... respondió HTTP <código>: <mensaje>` por stderr y código 1). Si la serie no está en la biblioteca: `❌ Show not found in library` (código 1). La opción solo se reconoce como segundo argumento.

## Flujo de trabajo

1. **"Añade X a Sonarr"** → `search "X"`, muestra la lista numerada y deja elegir
2. Toma el `tvdbId` del enlace elegido y ejecuta `exists <tvdbId>`; si ya existe, avisa y no añadas
3. Ejecuta `config` para ver los perfiles y confirma con el usuario perfil y búsqueda
4. Tras la confirmación, ejecuta `add <tvdbId> [perfilId] [--no-search]`
5. **"Quita X"** → `exists`, doble confirmación, pregunta por los ficheros y `PLEX_CREW_CONFIRMED=1 ... remove`

## Parámetros

| Argumento | Comandos | Notas |
|-----------|----------|-------|
| `<texto>` | search, search-json | Solo el primer argumento; entrecomíllalo |
| `<tvdbId>` | exists, add, remove | Entero de TVDB |
| `[perfilId]` | add | Entero; segundo argumento; por defecto `SONARR_DEFAULT_QUALITY_PROFILE` o 1 |
| `--no-search` | add | En cualquier posición; no lanza la búsqueda |
| `--delete-files` | remove | Solo como segundo argumento; borra los ficheros del disco |

## Notas

- Nunca imprimas `SONARR_API_KEY` ni uses `curl` con la clave en línea: usa siempre el script.
- Timeouts: `search` y `status` 25 s (librería compartida); el resto, 10 s de conexión y 30 s en total, sin reintentos.
- El usuario trabaja en Europe/Madrid (regla global en `plex-crew-rules`).

### Limitaciones conocidas

- `add` usa siempre la primera carpeta raíz de `/rootfolder`, `monitor: all` y carpeta por temporada; no se pueden elegir carpeta, tipo de serie ni monitorización.
- El perfil por defecto no se valida contra `/qualityprofile`; si no existe, Sonarr rechaza la alta.
- `exists` compara el cuerpo con `[]` exacto, de modo que una respuesta de error (por ejemplo HTTP 401) cuenta como `exists` y la línea de datos falla o sale vacía. Tampoco indica el estado de la serie.
- `search` muestra solo 10 resultados, sin sinopsis ni slug; `search-json` devuelve todos.
- Todos los comandos pasan la clave a curl por stdin (`--config -`), sin que aparezca en `ps`, y con `--connect-timeout` de 10 s (`ARR_CONNECT_TIMEOUT`).
- La barra final de `SONARR_URL` no se quita y da `//api/v3`.
- No hay comandos de episodios, calendario, cola, historial, logs, refresh ni búsqueda de episodios.

## Referencia

- [API de Sonarr](https://sonarr.tv/docs/api/)
- [TVDB](https://thetvdb.com/)

Para la referencia local detallada, consulta:
- **[Endpoints de la API](./references/api-endpoints.md)** - Comando del script, método, ruta y cuerpo de la alta
- **[Referencia rápida](./references/quick-reference.md)** - Configuración y ejemplos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Autenticación, conexión y uso
