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
```

- `RADARR_URL`: URL de tu servidor Radarr (sin barra final)
- `RADARR_API_KEY`: clave de API de Radarr (Settings → General → API Key)

## Comandos

Solo `search-json` y `collection-info` devuelven JSON; el resto imprime texto (con emojis en los mensajes de resultado). Sin comando muestra la ayuda (código 0); un comando desconocido la muestra y sale con 1. Si falta un argumento obligatorio o un id no es numérico, imprime el uso y sale con 1.

### Buscar películas

```bash
bash .claude/skills/radarr/scripts/radarr.sh search "Inception"
bash .claude/skills/radarr/scripts/radarr.sh search "The Matrix"
```

**Salida:** texto, una línea por resultado: número, título, año, enlace a TMDB y, si la hay, la colección (`[Collection: ...]`). No incluye sinopsis (usa `search-json` si la necesitas) ni limita el número de resultados.

### Comprobar si existe una película

```bash
bash .claude/skills/radarr/scripts/radarr.sh exists <tmdbId>
```

**Salida:** texto. `not_found` si no está; si está, `exists` y una segunda línea con el id interno de Radarr, el título y si tiene fichero (`ID: 144, Title: ..., Has File: true`).

### Añadir una película

```bash
bash .claude/skills/radarr/scripts/radarr.sh add <tmdbId> <profileId>              # Busca de inmediato (por defecto)
bash .claude/skills/radarr/scripts/radarr.sh add <tmdbId> <profileId> --no-search  # Añade sin buscar
```

El `profileId` es obligatorio: si falta, el script imprime el uso, indica ejecutar `config` para ver los ids de perfil y sale con 1. Nunca se elige un perfil por defecto (el primero podría saltarse el filtro de español); consulta `config` y usa el que corresponda (p. ej. 7 Español, 8 VOSE). La carpeta raíz es siempre la primera. La película se añade monitorizada.

### Añadir una colección completa

```bash
bash .claude/skills/radarr/scripts/radarr.sh add-collection <collectionTmdbId> <profileId>
bash .claude/skills/radarr/scripts/radarr.sh add-collection <collectionTmdbId> <profileId> --no-search
```

Añade todas las películas de una colección (por ejemplo, toda la saga de El Señor de los Anillos) que aún no estén en la biblioteca. El `profileId` es obligatorio (mismo criterio que `add`; ids con `config`) y usa la primera carpeta raíz. Al terminar deja la colección monitorizada con `searchOnAdd` (las nuevas entregas se añaden y buscan solas), aunque se pase `--no-search`. Si Radarr no conoce la colección hay que pasar un texto de búsqueda: `add-collection <collectionTmdbId> <profileId> "<texto>"`.

### Quitar una película

```bash
bash .claude/skills/radarr/scripts/radarr.sh remove <tmdbId>                # Conserva los ficheros
bash .claude/skills/radarr/scripts/radarr.sh remove <tmdbId> --delete-files # Borra también los ficheros
```

**Importante:** pregunta siempre al usuario si quiere borrar los ficheros al quitar una película. El hook `confirm-destructive` exige la doble confirmación y el marcador `PLEX_CREW_CONFIRMED=1` para cualquier `remove`.

### Consultar la configuración

```bash
bash .claude/skills/radarr/scripts/radarr.sh config
```

**Salida:** carpetas raíz y perfiles de calidad disponibles, con sus ids.

### Otros comandos

```bash
bash .claude/skills/radarr/scripts/radarr.sh search-json "Inception"        # Igual que search, pero con salida JSON
bash .claude/skills/radarr/scripts/radarr.sh collection-info <collectionTmdbId>  # Detalle de una colección de la biblioteca (JSON)
bash .claude/skills/radarr/scripts/radarr.sh logs [n] [level]               # Últimas n líneas de log (nivel: info/warn/error)
bash .claude/skills/radarr/scripts/radarr.sh search-id <movieId>            # Lanza la búsqueda de una película (id interno de Radarr)
bash .claude/skills/radarr/scripts/radarr.sh search-all                     # Lanza la búsqueda de TODAS las películas que faltan
```

`search-all` afecta a toda la biblioteca: confirma con el usuario antes de lanzarlo.

## Flujo de trabajo

Cuando el usuario pregunte por películas:

1. **"Añade Inception a Radarr"** → ejecuta `search "Inception"`, presenta los resultados con enlaces a TMDB y ejecuta `config` para elegir el perfil (o pregúntalo) y luego `add <tmdbId> <profileId>`
2. **"¿Tengo Dune en la biblioteca?"** → ejecuta `exists <tmdbId>`
3. **"Añade todas las de Star Wars"** → busca la colección y luego `add-collection <collectionId> <profileId>`
4. **"Quita The Matrix"** → pregunta por el borrado de ficheros y ejecuta `remove <tmdbId>` con el flag adecuado
5. **"¿Qué perfiles de calidad tengo?"** → ejecuta `config`

### Presentar resultados de búsqueda

Incluye siempre enlaces a TMDB al presentar resultados:
- Formato: `[Título (Año)](https://themoviedb.org/movie/ID)`
- Muestra una lista numerada para que el usuario elija
- Incluye el año; la sinopsis solo está en `search-json`

### Añadir películas

1. Busca la película
2. Presenta los resultados con enlaces a TMDB
3. El usuario elige un número
4. **Comprobación de colección:** si la película pertenece a una colección, pregunta si quiere la colección entera
5. Añade la película o la colección (busca de inmediato por defecto)

## Parámetros

### Comando add
- `<tmdbId>`: id de TMDB de la película (obligatorio)
- `[profileId]`: id del perfil de calidad (opcional)
- `--no-search`: no buscar la película después de añadirla

### Comando add-collection
- `<collectionTmdbId>`: id de TMDB de la colección (obligatorio)
- `<profileId>`: id del perfil de calidad (obligatorio; ver `config`)
- `[searchTerm]`: texto para localizar las películas si Radarr no conoce la colección (opcional)
- `--no-search`: no buscar las películas después de añadirlas

### Comando remove
- `<tmdbId>`: id de TMDB de la película (obligatorio)
- `--delete-files`: borra también los ficheros multimedia (por defecto se conservan)

## Notas

- Requiere acceso de red al servidor de Radarr
- Usa la API v3 de Radarr
- Solo `search-json` y `collection-info` devuelven JSON; el resto es texto
- Los ids de perfil de calidad varían según la instalación: usa `config` para descubrir los tuyos
- No hay perfil por defecto: `add` y `add-collection` exigen el `profileId` explícito
- Las colecciones son propias de TMDB e incluyen películas relacionadas (secuelas, sagas)

## Referencia

- [Documentación de la API de Radarr](https://radarr.video/docs/api/)
- [TMDB](https://themoviedb.org/): The Movie Database
