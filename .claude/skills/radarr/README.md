# radarr

Gestiona la biblioteca de películas de Radarr: buscar, comprobar si existe, añadir (sueltas o colecciones), quitar, lanzar búsquedas y leer logs. Envuelve la API v3. Es una de las dos skills modelo del estándar descrito en [`../README.md`](../README.md).

## Cuándo se usa

Cuando se pide añadir, buscar, comprobar o quitar una película, o añadir una colección. La carga el agente `arr-acquisition`. Antes de añadir se comprueba con `exists`. Los ids son siempre de **TMDB**.

## Comandos

Script: `.claude/skills/radarr/scripts/radarr.sh <comando> [args]`. En negrita, los que modifican estado o piden confirmación.

| Comando | Para qué sirve | Argumentos / opciones | Tipo |
|---------|----------------|-----------------------|------|
| `search` | Busca películas (`/movie/lookup`). Texto: lista numerada con título, año, enlace TMDB y colección si la hay; sin sinopsis y sin límite de resultados. | `<consulta>` | Lectura (texto) |
| `search-json` | Lo mismo con el JSON completo del lookup. | `<consulta>` | Lectura (JSON) |
| `exists` | Imprime `exists` (más id interno, título y si tiene fichero) o `not_found`. | `<tmdbId>` | Lectura (texto) |
| `config` | Carpetas raíz y perfiles de calidad con sus ids. | Ninguno | Lectura (texto) |
| `collection-info` | Detalle de una colección de la biblioteca de Radarr. | `<collectionTmdbId>` | Lectura (JSON) |
| `logs` | Últimas líneas de log, de más reciente a más antigua. | `[n]` (50 por defecto), `[nivel]` (`info`, `warn`, `error`) | Lectura (texto) |
| **`add`** | Añade una película, monitorizada, en la primera carpeta raíz. Busca al añadir salvo `--no-search`. | `<tmdbId> <profileId> [--no-search]` | Escritura |
| **`add-collection`** | Añade todas las películas de una colección que aún no estén y deja la colección monitorizada con `searchOnAdd`. Confirma antes con el usuario. | `<collectionTmdbId> <profileId> [searchTerm] [--no-search]` | Escritura masiva |
| **`remove`** | Quita una película de la biblioteca. Con `--delete-files` borra también los ficheros. | `<tmdbId> [--delete-files]` | Escritura, destructivo (hook) |
| **`search-id`** | Lanza la búsqueda (`MoviesSearch`) de una película. | `<movieId>` (id interno de Radarr, no TMDB) | Escritura (dispara descargas) |
| **`search-all`** | Lanza `MissingMoviesSearch` sobre toda la biblioteca. Confirma antes con el usuario. | Ninguno | Escritura masiva |

## Variables de entorno

| Variable | Obligatoria | Uso |
|----------|-------------|-----|
| `RADARR_URL` | Sí | URL base de Radarr; la API se llama en `$RADARR_URL/api/v3`. |
| `RADARR_API_KEY` | Sí | Clave de API, cabecera `X-Api-Key`. |
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

# ESCRITURA destructiva: exige doble confirmación y el marcador del hook
PLEX_CREW_CONFIRMED=1 bash .claude/skills/radarr/scripts/radarr.sh remove 27205
```

## Notas y límites

- Sin comando muestra la ayuda y sale con 0. Un comando desconocido escribe `ERROR: comando desconocido: ...` y la ayuda por stderr y sale con 1. Si falta un argumento obligatorio o un id no es numérico, escribe `ERROR: ...` y `Uso: radarr.sh ...` por stderr y sale con 1; nunca falla con `unbound variable`. Los flags `--no-search` y `--delete-files` se aceptan en cualquier posición.
- `add` y `add-collection` exigen el perfil y nunca eligen uno por defecto; si falta, indican ejecutar `config` para ver los ids (p. ej. 7 Español, 8 VOSE). Siempre usan la primera carpeta raíz (`/rootfolder`).
- `add-collection` localiza las películas buscando por el nombre de la colección (sin el sufijo "Collection") y filtrando por `collection.tmdbId`. Si Radarr no conoce la colección y no se da `searchTerm`, aborta con código 1. Al terminar deja la colección monitorizada aunque se use `--no-search`. Si falla el alta de alguna película, sigue con las demás y sale con 1 al final.
- `remove` busca la película por `tmdbId` y llama a `DELETE /movie/<id>?deleteFiles=...`. Está registrado en `DESTRUCTIVE` de `hooks/confirm-destructive.js` (véase [`hooks/README.md`](../../../hooks/README.md)): exige la doble confirmación y el marcador `PLEX_CREW_CONFIRMED=1`.
- `search-id` espera el id interno de Radarr (el de `exists`), no el de TMDB. `search-all` afecta a toda la biblioteca.
- Devuelven JSON `search-json` y `collection-info`. Imprimen texto:
  - `search`
  - `exists`
  - `config`
  - `logs`
  - los comandos de escritura
- Las escrituras (`add`, `add-collection`, `remove`, `search-id`, `search-all`) usan `arr_call` de [`_lib/arr-api.sh`](../_lib/README.md) y comprueban el código HTTP: si no es 2xx, escriben `ERROR: <método> <ruta> respondió HTTP <código>: <mensaje>` por stderr y salen con 1, sin imprimir un falso éxito. Los mensajes no llevan emojis.
