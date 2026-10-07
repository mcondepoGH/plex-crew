---
name: sonarr
description: Gestión de series en Sonarr. Úsala cuando el usuario pida "añadir una serie", "buscar en Sonarr", "buscar una serie", "quitar una serie", "comprobar si existe una serie", "biblioteca de Sonarr", "búsqueda en TVDB", o mencione gestión de series u operaciones de Sonarr.
---

# Skill de gestión de series en Sonarr

**INVOCACIÓN OBLIGATORIA DE LA SKILL**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "añadir una serie", "buscar en Sonarr", "buscar una serie", "añadir a Sonarr"
- "quitar una serie", "borrar serie", "comprobar si existe una serie"
- "biblioteca de Sonarr", "gestión de series", "añadir serie"
- Cualquier mención de Sonarr o de la gestión de series

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Busca y añade series a la biblioteca de Sonarr, con soporte para perfiles de calidad y búsqueda de episodios al añadir.

## Propósito

Esta skill permite gestionar la biblioteca de series de Sonarr:
- Buscar series por nombre
- Añadir series a la biblioteca con opciones configurables
- Comprobar si una serie ya existe
- Quitar series (con borrado opcional de ficheros)
- Consultar perfiles de calidad y carpetas raíz
- Lanzar búsquedas de descarga y leer los logs

Hay operaciones de lectura y de escritura. **Confirma siempre antes de quitar series con borrado de ficheros.**

## Configuración

Añade las credenciales al `.env` (raíz del repo; la plantilla es `.env.example`):

```bash
SONARR_URL="http://localhost:8989"      # URL de Sonarr, sin barra final
SONARR_API_KEY="<tu_api_key>"           # Sonarr: Settings → General → API Key
# HOMELAB_ENV=/ruta/a/otro.env          # Opcional: fichero de entorno alternativo
```

- `SONARR_URL`: URL de tu servidor Sonarr (sin barra final)
- `SONARR_API_KEY`: clave de API de Sonarr (Settings → General → API Key)
- `HOMELAB_ENV`: ruta alternativa al fichero `.env` (opcional)

## Comandos

Solo `search-json` devuelve JSON; el resto imprime texto. Sin comando muestra la ayuda (código 0); un comando desconocido escribe el error y la ayuda por stderr y sale con 1. Si falta un argumento obligatorio o un id no es numérico, imprime el uso por stderr y sale con 1. Los errores van siempre por stderr, en español y con el prefijo `ERROR:`. Las escrituras comprueban el código HTTP: si Sonarr no responde con 2xx, el script imprime el error por stderr y sale con 1.

### Buscar series

```bash
bash .claude/skills/sonarr/scripts/sonarr.sh search "Breaking Bad"
bash .claude/skills/sonarr/scripts/sonarr.sh search "The Office"
```

**Salida:** texto, una línea por resultado con número, título, año y enlace a TVDB. Muestra como máximo los 10 primeros resultados y no incluye sinopsis (`search-json` devuelve todos los resultados y los datos completos).

### Buscar series en JSON

```bash
bash .claude/skills/sonarr/scripts/sonarr.sh search-json "Breaking Bad"
```

**Salida:** JSON completo del lookup de Sonarr, sin límite de 10 resultados.

### Comprobar si existe una serie

```bash
bash .claude/skills/sonarr/scripts/sonarr.sh exists <tvdbId>
```

**Salida:** texto. `not_found` si no está; si está, `exists` y una segunda línea con el id interno de Sonarr, el título y el número de temporadas (`ID: 49, Título: ..., Temporadas: 5`).

### Consultar la configuración

```bash
bash .claude/skills/sonarr/scripts/sonarr.sh config
```

**Salida:** texto con las carpetas raíz y los perfiles de calidad disponibles, con sus ids.

### Añadir una serie

```bash
bash .claude/skills/sonarr/scripts/sonarr.sh add <tvdbId> <profileId>              # Busca de inmediato (por defecto)
bash .claude/skills/sonarr/scripts/sonarr.sh add <tvdbId> <profileId> --no-search  # Añade sin buscar
```

El `profileId` es obligatorio: si falta, el script imprime el uso por stderr, indica ejecutar `config` para ver los ids de perfil y sale con 1. Nunca se elige un perfil por defecto (el primero podría saltarse el filtro de español); consulta `config` y usa el que corresponda (p. ej. 7 Español, 8 VOSE). La carpeta raíz es siempre la primera. La serie se añade monitorizada (`monitor: all`, carpetas por temporada). Al añadir con búsqueda se disparan descargas de todos los episodios que faltan: confirma con el usuario antes de añadir si no la ha pedido de forma explícita.

**Salida:** texto, `Añadida: <título> (<año>) - N temporadas` y, salvo `--no-search`, `Búsqueda lanzada`. Si no existe la serie en TVDB, o Sonarr responde con un código que no es 2xx (por ejemplo, la serie ya existe), imprime `ERROR: ...` con el código y el mensaje por stderr y sale con 1.

### Quitar una serie

```bash
bash .claude/skills/sonarr/scripts/sonarr.sh remove <tvdbId>                # Conserva los ficheros
bash .claude/skills/sonarr/scripts/sonarr.sh remove <tvdbId> --delete-files # Borra también los ficheros
```

**Importante:** pregunta siempre al usuario si quiere borrar los ficheros al quitar una serie. El hook `confirm-destructive` exige la doble confirmación y el marcador `PLEX_CREW_CONFIRMED=1` para cualquier `remove`.

**Salida:** texto, `Quitada: <título> (<año>)` indicando si los ficheros se conservan o se borran. Si la serie no está en la biblioteca o Sonarr no responde con 2xx al `DELETE`, imprime `ERROR: ...` por stderr y sale con 1.

### Leer los logs

```bash
bash .claude/skills/sonarr/scripts/sonarr.sh logs [n] [nivel]
```

**Salida:** texto, las últimas `n` líneas de log (50 por defecto), de la más reciente a la más antigua, con hora, nivel, logger y mensaje. El nivel puede ser `info`, `warn` o `error`.

### Lanzar la búsqueda de una serie

```bash
bash .claude/skills/sonarr/scripts/sonarr.sh search-id <seriesId>
```

`<seriesId>` es el id interno de Sonarr (el de `exists`), no el de TVDB. Dispara descargas: confirma con el usuario antes de lanzarlo.

**Salida:** texto, `Lanzado: SeriesSearch para la serie <id> (comando N, estado ...)`. Si Sonarr no responde con 2xx, `ERROR: ...` por stderr y rc 1.

### Lanzar la búsqueda de todos los episodios que faltan

```bash
bash .claude/skills/sonarr/scripts/sonarr.sh search-all
```

`search-all` afecta a toda la biblioteca: confirma con el usuario antes de lanzarlo.

**Salida:** texto, `Lanzado: MissingEpisodeSearch (comando N, estado ...)`. Si Sonarr no responde con 2xx, `ERROR: ...` por stderr y rc 1.

## Flujo de trabajo

Cuando el usuario pregunte por series:

1. **"Añade Breaking Bad a Sonarr"** → ejecuta `search "Breaking Bad"`, presenta los resultados con enlaces a TVDB, ejecuta `config` para elegir el perfil (o pregúntalo) y luego `add <tvdbId> <profileId>`
2. **"¿Tengo The Office en la biblioteca?"** → ejecuta `exists <tvdbId>`
3. **"Quita Game of Thrones"** → pregunta por el borrado de ficheros y ejecuta `remove <tvdbId>` con el flag adecuado
4. **"¿Qué perfiles de calidad tengo?"** → ejecuta `config`

### Presentar resultados de búsqueda

Incluye siempre enlaces a TVDB al presentar resultados:
- Formato: `[Título (Año)](https://thetvdb.com/series/SLUG)`
- Muestra una lista numerada para que el usuario elija
- Incluye el año; la sinopsis solo está en `search-json`

### Añadir series

1. Busca la serie
2. Presenta los resultados con enlaces a TVDB
3. El usuario elige un número
4. Añade la serie (busca los episodios por defecto)

## Parámetros

### Comando add
- `<tvdbId>`: id de TVDB de la serie (obligatorio)
- `<profileId>`: id del perfil de calidad (obligatorio; ver `config`)
- `--no-search`: no buscar episodios después de añadirla

### Comando remove
- `<tvdbId>`: id de TVDB de la serie (obligatorio)
- `--delete-files`: borra también los ficheros multimedia (por defecto se conservan)

### Comandos logs y search-id
- `logs [n] [nivel]`: número de líneas (por defecto 50) y nivel (`info`, `warn` o `error`), ambos opcionales
- `search-id <seriesId>`: id interno de Sonarr (obligatorio)

## Notas

- Requiere acceso de red al servidor de Sonarr
- Usa la API v3 de Sonarr
- Solo `search-json` devuelve JSON; el resto es texto
- Los flags `--no-search` y `--delete-files` se aceptan en cualquier posición
- Los ids de perfil de calidad varían según la instalación: usa `config` para descubrir los tuyos
- No hay perfil por defecto: `add` exige el `profileId` explícito
- Sonarr no tiene `add-collection` (es un comando solo de Radarr)
- Los mensajes no llevan emojis; los errores salen por stderr con el prefijo `ERROR:`

## Referencia

- [Documentación de la API de Sonarr](https://sonarr.tv/docs/api/)
- [TVDB](https://thetvdb.com/): base de datos de series
- [Cómo crear una skill](../README.md): estándar que sigue esta skill
- [Librerías compartidas](../_lib/README.md): `load-env.sh` y `arr-api.sh` (`arr_call`)
