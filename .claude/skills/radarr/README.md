# radarr

Gestiona la biblioteca de películas de Radarr: buscar, comprobar si existe, añadir (sueltas o colecciones), quitar, lanzar búsquedas y leer logs. Envuelve la API v3.

## Cuándo se usa

Cuando se pide añadir, buscar, comprobar o quitar una película, o añadir una colección. La carga el agente `arr-acquisition`. Antes de añadir se comprueba con `exists`. Los ids son siempre de **TMDB**.

## Comandos

Script: `.claude/skills/radarr/scripts/radarr.sh <comando> [args]`. En negrita, los que modifican estado o piden confirmación.

| Comando | Para qué sirve | Argumentos / opciones | Tipo |
|---------|----------------|-----------------------|------|
| `search` | Busca películas (`/movie/lookup`). Lista numerada con título, año, enlace TMDB y colección si la hay. | `<consulta>` | Lectura |
| `search-json` | Lo mismo con el JSON completo del lookup. | `<consulta>` | Lectura |
| `exists` | Imprime `exists` (más id interno, título y si tiene fichero) o `not_found`. | `<tmdbId>` | Lectura |
| `config` | Carpetas raíz y perfiles de calidad con sus ids. | Ninguno | Lectura |
| `collection-info` | Detalle de una colección de la biblioteca de Radarr. | `<collectionTmdbId>` | Lectura |
| `logs` | Últimas líneas de log, de más reciente a más antigua. | `[n]` (50 por defecto), `[nivel]` (`info`, `warn`, `error`) | Lectura |
| **`add`** | Añade una película, monitorizada, en la primera carpeta raíz. Busca al añadir salvo `--no-search`. | `<tmdbId> [profileId] [--no-search]` | Escritura |
| **`add-collection`** | Añade todas las películas de una colección que aún no estén, y deja la colección monitorizada con `searchOnAdd`. | `<collectionTmdbId> [searchTerm] [--no-search]` | Escritura |
| **`remove`** | Quita una película de la biblioteca. Con `--delete-files` borra también los ficheros. | `<tmdbId> [--delete-files]` | Escritura, destructivo con `--delete-files` |
| **`search-id`** | Lanza la búsqueda (`MoviesSearch`) de una película. | `<movieId>` (id interno de Radarr, no TMDB) | Escritura (dispara descargas) |
| **`search-all`** | Lanza `MissingMoviesSearch` sobre toda la biblioteca. | Ninguno | Escritura masiva |

## Variables de entorno

| Variable | Obligatoria | Uso |
|----------|-------------|-----|
| `RADARR_URL` | Sí | URL base de Radarr; la API se llama en `$RADARR_URL/api/v3`. |
| `RADARR_API_KEY` | Sí | Clave de API, cabecera `X-Api-Key`. |
| `RADARR_DEFAULT_QUALITY_PROFILE` | No | Id del perfil usado en `add`; si no se define, se usa `1`. |
| `HOMELAB_ENV` | No | Ruta alternativa al fichero `.env`. |

## Ejemplos de uso

```bash
# Lectura: buscar y comprobar si ya está
bash .claude/skills/radarr/scripts/radarr.sh search "Inception"
bash .claude/skills/radarr/scripts/radarr.sh exists 27205

# Lectura: ver carpetas raíz y perfiles de calidad
bash .claude/skills/radarr/scripts/radarr.sh config

# ESCRITURA: añadir sin lanzar búsqueda, con un perfil concreto
bash .claude/skills/radarr/scripts/radarr.sh add 27205 7 --no-search
```

## Notas y límites

- El script usa `set -euo pipefail` y lee `$1`, `$2` directamente: sin comando falla con "unbound variable" (no muestra la ayuda), y `add <tmdbId>` o `remove <tmdbId>` con un solo argumento también fallan por `$2` sin definir. Para añadir sin más argumentos hay que pasar `profileId` o `--no-search`; para quitar conservando ficheros hay que pasar un segundo argumento distinto de `--delete-files` (por ejemplo una cadena vacía).
- `add`: el perfil sale de `profileId`, si no de `RADARR_DEFAULT_QUALITY_PROFILE` y si no de `1`. Siempre usa la primera carpeta raíz (`/rootfolder`).
- `add-collection` ignora el perfil por defecto: usa el primer perfil de `/qualityprofile` y la primera carpeta raíz. Localiza las películas buscando por el nombre de la colección (sin el sufijo "Collection") y filtrando por `collection.tmdbId`; si Radarr no conoce la colección y no se da `searchTerm`, aborta.
- `remove` busca la película por `tmdbId` en la biblioteca y llama a `DELETE /movie/<id>?deleteFiles=...`. El script no pide confirmación: la doble confirmación con `--delete-files` es responsabilidad del agente.
- `search-id` espera el id interno de Radarr (el de `exists`), no el de TMDB; `search-all` afecta a toda la biblioteca.
- Los comandos de lectura de texto (`search`, `exists`, `config`) no devuelven JSON; solo `search-json` y `collection-info` lo hacen.
- Los mensajes de `add`, `add-collection` y `remove` llevan emojis y no se comprueba el código HTTP: el éxito se deduce de que la respuesta tenga `id`.
- Un comando desconocido imprime la ayuda con código de salida 0 (y la ayuda no lista `search-id`).
