---
name: radarr
description: Gestión de películas en Radarr. Úsala cuando el usuario pida "añadir una película", "buscar en Radarr", "buscar un film", "quitar una película", "añadir una colección", "comprobar si existe una película", "biblioteca de Radarr", o mencione gestión de películas, TMDB u operaciones de Radarr.
---

# Skill de gestión de películas en Radarr

**INVOCACIÓN OBLIGATORIA DE LA SKILL**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "añadir una película", "buscar en Radarr", "buscar un film", "añadir a Radarr"
- "quitar una película", "borrar película", "comprobar si existe una película"
- "añadir colección de películas", "biblioteca de Radarr", "gestión de películas"
- Cualquier mención de Radarr o de la gestión de películas

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Busca y añade películas a la biblioteca de Radarr, con soporte para colecciones, perfiles de calidad y búsqueda al añadir.

## Propósito

Esta skill permite gestionar la biblioteca de películas de Radarr:
- Buscar películas por nombre
- Añadir películas sueltas o colecciones completas
- Comprobar si una película ya existe
- Quitar películas (con borrado opcional de ficheros)
- Consultar perfiles de calidad y carpetas raíz

Hay operaciones de lectura y de escritura. **Confirma siempre antes de quitar películas con borrado de ficheros.**

## Configuración

Añade las credenciales al `.env` (raíz del repo):

```bash
RADARR_URL="http://localhost:7878"
RADARR_API_KEY="tu-api-key"
RADARR_DEFAULT_QUALITY_PROFILE="1"  # Opcional (por defecto 1)
```

- `RADARR_URL`: URL de tu servidor Radarr (sin barra final)
- `RADARR_API_KEY`: clave de API de Radarr (Settings → General → API Key)
- `RADARR_DEFAULT_QUALITY_PROFILE`: id del perfil de calidad (opcional; ejecuta `config` para ver las opciones)

## Comandos

Todos los comandos devuelven JSON.

### Buscar películas

```bash
bash .claude/skills/radarr/scripts/radarr.sh search "Inception"
bash .claude/skills/radarr/scripts/radarr.sh search "The Matrix"
```

**Salida:** lista numerada con ids de TMDB, títulos, años y sinopsis.

### Comprobar si existe una película

```bash
bash .claude/skills/radarr/scripts/radarr.sh exists <tmdbId>
```

**Salida:** booleano que indica si la película está en la biblioteca.

### Añadir una película

```bash
bash .claude/skills/radarr/scripts/radarr.sh add <tmdbId>              # Busca de inmediato (por defecto)
bash .claude/skills/radarr/scripts/radarr.sh add <tmdbId> --no-search  # Añade sin buscar
```

### Añadir una colección completa

```bash
bash .claude/skills/radarr/scripts/radarr.sh add-collection <collectionTmdbId>
bash .claude/skills/radarr/scripts/radarr.sh add-collection <collectionTmdbId> --no-search
```

Añade todas las películas de una colección (por ejemplo, toda la saga de El Señor de los Anillos).

### Quitar una película

```bash
bash .claude/skills/radarr/scripts/radarr.sh remove <tmdbId>                # Conserva los ficheros
bash .claude/skills/radarr/scripts/radarr.sh remove <tmdbId> --delete-files # Borra también los ficheros
```

**Importante:** pregunta siempre al usuario si quiere borrar los ficheros al quitar una película. Con `--delete-files` aplica la doble confirmación.

### Consultar la configuración

```bash
bash .claude/skills/radarr/scripts/radarr.sh config
```

**Salida:** carpetas raíz y perfiles de calidad disponibles, con sus ids.

### Otros comandos

```bash
bash .claude/skills/radarr/scripts/radarr.sh search-json "Inception"        # Igual que search, pero con salida JSON
bash .claude/skills/radarr/scripts/radarr.sh add <tmdbId> <profileId>       # Añade con un perfil de calidad concreto
bash .claude/skills/radarr/scripts/radarr.sh collection-info <tmdbId>       # Detalle de una colección
bash .claude/skills/radarr/scripts/radarr.sh logs [n] [level]               # Últimas n líneas de log (nivel: info/warn/error)
bash .claude/skills/radarr/scripts/radarr.sh search-id <movieId>            # Lanza la búsqueda de una película (id interno de Radarr)
bash .claude/skills/radarr/scripts/radarr.sh search-all                     # Lanza la búsqueda de TODAS las películas que faltan
```

`search-all` afecta a toda la biblioteca: confirma con el usuario antes de lanzarlo.

## Flujo de trabajo

Cuando el usuario pregunte por películas:

1. **"Añade Inception a Radarr"** → ejecuta `search "Inception"`, presenta los resultados con enlaces a TMDB y luego `add <tmdbId>`
2. **"¿Tengo Dune en la biblioteca?"** → ejecuta `exists <tmdbId>`
3. **"Añade todas las de Star Wars"** → busca la colección y luego `add-collection <collectionId>`
4. **"Quita The Matrix"** → pregunta por el borrado de ficheros y ejecuta `remove <tmdbId>` con el flag adecuado
5. **"¿Qué perfiles de calidad tengo?"** → ejecuta `config`

### Presentar resultados de búsqueda

Incluye siempre enlaces a TMDB al presentar resultados:
- Formato: `[Título (Año)](https://themoviedb.org/movie/ID)`
- Muestra una lista numerada para que el usuario elija
- Incluye el año y una breve sinopsis

### Añadir películas

1. Busca la película
2. Presenta los resultados con enlaces a TMDB
3. El usuario elige un número
4. **Comprobación de colección:** si la película pertenece a una colección, pregunta si quiere la colección entera
5. Añade la película o la colección (busca de inmediato por defecto)

## Parámetros

### Comando add
- `<tmdbId>`: id de TMDB de la película (obligatorio)
- `--no-search`: no buscar la película después de añadirla

### Comando add-collection
- `<collectionTmdbId>`: id de TMDB de la colección (obligatorio)
- `--no-search`: no buscar las películas después de añadirlas

### Comando remove
- `<tmdbId>`: id de TMDB de la película (obligatorio)
- `--delete-files`: borra también los ficheros multimedia (por defecto se conservan)

## Notas

- Requiere acceso de red al servidor de Radarr
- Usa la API v3 de Radarr
- Todas las operaciones de datos devuelven JSON
- Los ids de perfil de calidad varían según la instalación: usa `config` para descubrir los tuyos
- El perfil por defecto (`RADARR_DEFAULT_QUALITY_PROFILE`) se usa al añadir películas
- Las colecciones son propias de TMDB e incluyen películas relacionadas (secuelas, sagas)

## Referencia

- [Documentación de la API de Radarr](https://radarr.video/docs/api/)
- [TMDB](https://themoviedb.org/): The Movie Database
