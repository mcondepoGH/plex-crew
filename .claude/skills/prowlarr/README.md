# prowlarr

Busca releases en todos los indexadores de Prowlarr y gestiona los propios indexadores: listar, probar, activar, desactivar, borrar y sincronizar con Radarr y Sonarr. Envuelve la API v1 de Prowlarr.

## Cuándo se usa

Cuando se pide buscar un torrent o release, ver el estado de los indexadores o enviar su configuración a las apps conectadas. La carga el agente `arr-acquisition`. Para entender por qué una búsqueda devuelve resultados raros (Torrentio sin `imdbid`) véase `arr-language-filters`.

## Comandos

Script: `.claude/skills/prowlarr/scripts/prowlarr-api.sh <comando> [args]`. En negrita, los que modifican estado o piden confirmación.

| Comando | Para qué sirve | Argumentos / opciones | Tipo |
|---------|----------------|-----------------------|------|
| `search` | Búsqueda de texto en todos los indexadores: título, indexador, tamaño en MB, seeders, leechers, edad y URLs. | `<texto> [--torrents\|--usenet] [--category\|-c N] [--limit\|-l N] [--type\|-t T]` | Lectura (JSON) |
| `tv-search` | Búsqueda de series por id (`type=tvsearch`). Al menos una opción. | `[--tvdb N] [--season\|-s N] [--episode\|-e N]` | Lectura (JSON) |
| `movie-search` | Búsqueda de películas por id (`type=moviesearch`). Al menos una opción. | `[--imdb ttN] [--tmdb N]` | Lectura (JSON) |
| `indexers` | Lista indexadores: id, nombre, protocolo, activo y prioridad. | `[--verbose\|-v]` (JSON completo) | Lectura (JSON) |
| `stats` | Estadísticas por indexador: consultas, grabs, fallos y tiempo medio. | Ninguno | Lectura (JSON) |
| `apps` | Aplicaciones conectadas: id, nombre, nivel de sync e implementación. | Ninguno | Lectura (JSON) |
| `status` | Estado del sistema (`/system/status`). | Ninguno | Lectura (JSON) |
| `health` | Avisos de salud: origen, tipo y mensaje. | Ninguno | Lectura (JSON) |
| `logs` | Últimas líneas de log, de más reciente a más antigua. | `[n]` (50 por defecto) `[nivel]` | Lectura (texto) |
| `test` | Prueba un indexador (`POST /indexer/test`). | `<id>` | Lectura (texto; lanza una prueba de conectividad) |
| `test-all` | Prueba todos los indexadores (`POST /indexer/testall`) y lista el resultado de cada uno. | Ninguno | Lectura (texto; lanza pruebas) |
| **`enable`** | Activa un indexador (PUT con `enable=true`). | `<id>` | Escritura (texto) |
| **`disable`** | Desactiva un indexador (PUT con `enable=false`). Confirmar antes con el usuario. | `<id>` | Escritura (texto) |
| **`delete`** | Borra un indexador de forma permanente. | `<id>` | Escritura, destructivo (texto) |
| **`sync`** | Lanza `ApplicationIndexerSync` para empujar los indexadores a las apps conectadas. Confirmar antes con el usuario. | Ninguno | Escritura (texto) |

## Variables de entorno

| Variable | Obligatoria | Uso |
|----------|-------------|-----|
| `PROWLARR_URL` | Sí | URL base de Prowlarr (se quita la barra final). |
| `PROWLARR_API_KEY` | Sí | Clave de API, enviada en la cabecera `X-Api-Key`. |
| `HOMELAB_ENV` | No | Ruta alternativa al fichero `.env` (la lee `_lib/load-env.sh`). |

## Ejemplos de uso

```bash
# Lectura: búsqueda por texto solo en torrents, categoría Movies
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh search "inception" --torrents --category 2000

# Lectura: búsqueda de un episodio por TVDB id
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh tv-search --tvdb 71663 --season 1 --episode 1

# Lectura: salud de los indexadores
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh stats
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh health

# ESCRITURA: desactivar un indexador (confirmar antes con el usuario)
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh disable 3
```

## Notas y límites

- Sin comando muestra la ayuda y sale con 0; un comando desconocido muestra la ayuda por stderr y sale con 1. Un argumento obligatorio que falta, una opción sin valor, un id o valor no numérico (`--limit`, `--category`, `--tvdb`, `--season`, `--episode`, `--tmdb`, `logs [n]`) o una opción desconocida imprimen el uso por stderr y salen con 1.
- Todos los errores salen por stderr con el prefijo `ERROR:`; ya no hay JSON de error. Lecturas y escrituras comprueban el código HTTP y salen con 1 si no es 2xx.
- Las escrituras imprimen texto solo cuando Prowlarr responde 2xx: eso confirma que aceptó la llamada, no que el efecto sea el esperado. `test` incluye el motivo en el error si Prowlarr lo da.
- `test-all` imprime una línea por indexador (`correcto` o `FALLA`) y sale con 0 aunque alguno falle.
- A diferencia de radarr y sonarr, `search` ya devuelve JSON y no existe `search-json`.
- El hook `confirm-destructive` exige la doble confirmación y el marcador `PLEX_CREW_CONFIRMED=1` solo para `delete`; `disable` y `sync` dependen de la confirmación previa con el usuario.
- `tv-search` y `movie-search` construyen el campo `query` con esta sintaxis:
  - `{TvdbId:..}`
  - `{Season:..}`
  - `{Episode:..}`
  - `{ImdbId:..}`
  - `{TmdbId:..}`
- `--torrents` equivale a `indexerIds=-2` y `--usenet` a `indexerIds=-1`.
- Categorías Newznab habituales:
  - 2000 Movies
  - 5000 TV
  - 3000 Audio
  - 7000 Books
  - 1000 Console
  - 4000 PC
  - 6000 XXX
- La búsqueda de texto de Torrentio sin `imdbid` devuelve resultados de un título de validación fijo; usar `movie-search --imdb` o `tv-search --tvdb` cuando se pueda.
- `logs` pasa el nivel como filtro, pero Prowlarr puede devolver registros de otros niveles.
- Cada búsqueda consulta indexadores externos: conviene no encadenar muchas seguidas.
