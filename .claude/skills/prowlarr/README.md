# prowlarr

Busca releases en todos los indexadores de Prowlarr y gestiona los propios indexadores (listar, probar, activar, desactivar, borrar, sincronizar con Radarr/Sonarr). Envuelve la API v1 de Prowlarr.

## Cuándo se usa

Cuando se pide buscar un torrent o release, ver el estado de los indexadores o enviar su configuración a las apps conectadas. La carga el agente `arr-acquisition`. Para entender por qué una búsqueda devuelve resultados raros (Torrentio sin `imdbid`) véase `arr-language-filters`.

## Comandos

Script: `.claude/skills/prowlarr/scripts/prowlarr-api.sh <comando> [opciones]`. En negrita, los que modifican estado o piden confirmación.

| Comando | Para qué sirve | Argumentos / opciones | Tipo |
|---------|----------------|-----------------------|------|
| `search` | Búsqueda de texto en todos los indexadores. Devuelve título, indexador, tamaño en MB, seeders, leechers, edad y URLs. | `<consulta>` (obligatoria), `--torrents`, `--usenet`, `--category\|-c <id>`, `--limit\|-l <n>`, `--type\|-t <tipo>` (por defecto `search`; p. ej. `tvsearch`, `moviesearch`) | Lectura |
| `tv-search` | Búsqueda de series por id con `type=tvsearch`. | `--tvdb <id>`, `--season\|-s <n>`, `--episode\|-e <n>` | Lectura |
| `movie-search` | Búsqueda de películas por id con `type=moviesearch`. | `--imdb <id>` o `--tmdb <id>` (al menos uno) | Lectura |
| `indexers` | Lista indexadores (id, nombre, protocolo, activo, prioridad). | `--verbose\|-v` devuelve el JSON completo | Lectura |
| `stats` | Estadísticas por indexador: consultas, grabs, fallos, tiempo medio de respuesta. | Ninguno | Lectura |
| `apps` | Lista las aplicaciones conectadas (id, nombre, nivel de sync, implementación). | Ninguno | Lectura |
| `status` | Estado del sistema (`/system/status`). | Ninguno | Lectura |
| `health` | Avisos de salud (origen, tipo, mensaje). | Ninguno | Lectura |
| `logs` | Últimas líneas de log, de más reciente a más antigua. | `[n]` (50 por defecto), `[nivel]` (`info`, `warn`, `error`); imprime texto, no JSON | Lectura |
| `test` | Prueba un indexador (POST `/indexer/test` con su definición). | `<id>` | Lectura (lanza una prueba de conectividad) |
| `test-all` | Prueba todos los indexadores (POST `/indexer/testall`). | Ninguno | Lectura (lanza pruebas) |
| **`enable`** | Activa un indexador (PUT con `enable=true`). | `<id>` | Escritura |
| **`disable`** | Desactiva un indexador (PUT con `enable=false`). | `<id>` | Escritura |
| **`delete`** | Borra un indexador de forma permanente. | `<id>` | Escritura, destructivo |
| **`sync`** | Lanza el comando `ApplicationIndexerSync` para empujar los indexadores a las apps conectadas. | Ninguno | Escritura |

Sin argumentos, `-h`, `--help` o `help` muestran la ayuda.

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

- `test`, `enable`, `disable` y `delete` sin `<id>` imprimen el uso y salen con 1.
- `enable`, `disable`, `delete`, `test`, `test-all` y `sync` comprueban solo el código HTTP: si no es 2xx imprimen el error por stderr y salen con 1; si lo es, imprimen un `status: ok` fijo (no verifican el efecto, solo que Prowlarr aceptó la llamada). El hook `confirm-destructive` exige la doble confirmación y el marcador `PLEX_CREW_CONFIRMED=1` para `delete`.
- `tv-search` y `movie-search` construyen la consulta con la sintaxis `{TvdbId:..}`, `{Season:..}`, `{Episode:..}`, `{ImdbId:..}` y `{TmdbId:..}` del campo `query`. `tv-search` exige al menos uno de `--tvdb`, `--season` o `--episode`; `movie-search` al menos `--imdb` o `--tmdb`.
- `--torrents` equivale a `indexerIds=-2` y `--usenet` a `indexerIds=-1`.
- Categorías Newznab habituales: 2000 Movies, 5000 TV, 3000 Audio, 7000 Books, 1000 Console, 4000 PC, 6000 XXX.
- La búsqueda de texto de Torrentio sin `imdbid` devuelve resultados de un título de validación fijo; usar `movie-search --imdb` o `tv-search --tvdb` cuando se pueda.
- Cada búsqueda consulta indexadores externos: conviene no encadenar muchas seguidas.
