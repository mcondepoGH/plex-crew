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

Busca y añade series a la biblioteca de Sonarr, con soporte para opciones de monitorización, perfiles de calidad y búsqueda al añadir.

## Propósito

Esta skill permite gestionar la biblioteca de series de Sonarr:
- Buscar series por nombre
- Añadir series a la biblioteca con opciones configurables
- Comprobar si una serie ya existe
- Quitar series (con borrado opcional de ficheros)
- Consultar perfiles de calidad y carpetas raíz

Hay operaciones de lectura y de escritura. **Confirma siempre antes de quitar series con borrado de ficheros.**

## Configuración

Añade las credenciales al `.env` (raíz del repo):

```bash
SONARR_URL="http://localhost:8989"
SONARR_API_KEY="<tu_api_key>"
SONARR_DEFAULT_QUALITY_PROFILE="1"  # Opcional: por defecto 1 si no se define
```

**Variables de configuración:**
- `SONARR_URL`: URL de tu servidor Sonarr (sin barra final)
- `SONARR_API_KEY`: clave de API de Sonarr (Settings → General → API Key)
- `SONARR_DEFAULT_QUALITY_PROFILE`: id del perfil de calidad (opcional, por defecto 1)

## Comandos

Todos los comandos devuelven JSON.

### Buscar series

```bash
bash .claude/skills/sonarr/scripts/sonarr.sh search "Breaking Bad"
bash .claude/skills/sonarr/scripts/sonarr.sh search "The Office"
```

**Salida:** lista numerada con ids de TVDB, títulos, años y sinopsis.

### Comprobar si existe una serie

```bash
bash .claude/skills/sonarr/scripts/sonarr.sh exists <tvdbId>
```

**Salida:** booleano que indica si la serie está en la biblioteca.

### Añadir una serie

```bash
bash .claude/skills/sonarr/scripts/sonarr.sh add <tvdbId>              # Busca de inmediato (por defecto)
bash .claude/skills/sonarr/scripts/sonarr.sh add <tvdbId> --no-search  # Añade sin buscar
```

### Quitar una serie

```bash
bash .claude/skills/sonarr/scripts/sonarr.sh remove <tvdbId>                # Conserva los ficheros
bash .claude/skills/sonarr/scripts/sonarr.sh remove <tvdbId> --delete-files # Borra también los ficheros
```

**Importante:** pregunta siempre al usuario si quiere borrar los ficheros al quitar una serie. Con `--delete-files` aplica la doble confirmación.

### Consultar la configuración

```bash
bash .claude/skills/sonarr/scripts/sonarr.sh config
```

**Salida:** carpetas raíz y perfiles de calidad disponibles, con sus ids.

### Otros comandos

```bash
bash .claude/skills/sonarr/scripts/sonarr.sh search-json "Breaking Bad"     # Igual que search, pero con salida JSON
bash .claude/skills/sonarr/scripts/sonarr.sh add <tvdbId> <profileId>       # Añade con un perfil de calidad concreto
bash .claude/skills/sonarr/scripts/sonarr.sh logs [n] [level]               # Últimas n líneas de log (nivel: info/warn/error)
bash .claude/skills/sonarr/scripts/sonarr.sh search-id <seriesId>           # Lanza la búsqueda de una serie (id interno de Sonarr)
bash .claude/skills/sonarr/scripts/sonarr.sh search-all                     # Lanza la búsqueda de TODOS los episodios que faltan
```

`search-all` afecta a toda la biblioteca: confirma con el usuario antes de lanzarlo.

## Flujo de trabajo

Cuando el usuario pregunte por series:

1. **"Añade Breaking Bad a Sonarr"** → ejecuta `search "Breaking Bad"`, presenta los resultados con enlaces a TVDB y luego `add <tvdbId>`
2. **"¿Tengo The Office en la biblioteca?"** → ejecuta `exists <tvdbId>`
3. **"Quita Game of Thrones"** → pregunta por el borrado de ficheros y ejecuta `remove <tvdbId>` con el flag adecuado
4. **"¿Qué perfiles de calidad tengo?"** → ejecuta `config`

### Presentar resultados de búsqueda

Incluye siempre enlaces a TVDB al presentar resultados:
- Formato: `[Título (Año)](https://thetvdb.com/series/SLUG)`
- Muestra una lista numerada para que el usuario elija
- Incluye el año y una breve sinopsis

### Añadir series

1. Busca la serie
2. Presenta los resultados con enlaces a TVDB
3. El usuario elige un número
4. Añade la serie (busca los episodios por defecto)

## Parámetros

### Comando add
- `<tvdbId>`: id de TVDB de la serie (obligatorio)
- `--no-search`: no buscar episodios después de añadirla

### Comando remove
- `<tvdbId>`: id de TVDB de la serie (obligatorio)
- `--delete-files`: borra también los ficheros multimedia (por defecto se conservan)

## Notas

- Requiere acceso de red al servidor de Sonarr
- Usa la API v3 de Sonarr
- Todas las operaciones de datos devuelven JSON
- Los ids de perfil de calidad varían según la instalación: usa `config` para descubrir los tuyos
- El valor de `SONARR_DEFAULT_QUALITY_PROFILE` del `.env` se usa al añadir series (por defecto 1)

## Referencia

- [Documentación de la API de Sonarr](https://sonarr.tv/docs/api/)
- [TVDB](https://thetvdb.com/): base de datos de series
