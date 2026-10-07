#!/bin/bash
set -euo pipefail

# Wrapper de la API v1 de Prowlarr

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../../_lib/load-env.sh"
# shellcheck source=/dev/null
source "$_LOAD_ENV" || { echo "ERROR: no se encuentra load-env.sh. Copia .env.example a .env" >&2; exit 1; }

# Credenciales desde el .env
load_service_credentials "prowlarr" "PROWLARR_URL" "PROWLARR_API_KEY"

# Quita la barra final de la URL
PROWLARR_URL="${PROWLARR_URL%/}"

usage() {
  cat <<'USAGE'
Uso: prowlarr-api.sh <comando> [args]

Devuelven JSON: search, tv-search, movie-search, indexers, stats, apps, status y health.
Devuelven texto: logs, test, test-all, enable, disable, delete y sync.

Búsqueda:
  search <texto> [--torrents | --usenet] [--category <id>] [--limit <n>] [--type <tipo>]
                                        Buscar en todos los indexadores (tipo: search por defecto,
                                        tvsearch, moviesearch...; categorías: 2000 Movies, 5000 TV...)
  tv-search [--tvdb <id>] [--season <n>] [--episode <n>]
                                        Buscar episodios (al menos una opción)
  movie-search [--imdb <ttid>] [--tmdb <id>]
                                        Buscar películas (al menos una opción)

Indexadores:
  indexers [--verbose]                  Listar indexadores (con --verbose, JSON completo)
  stats                                 Estadísticas de uso por indexador
  test <id>                             Probar un indexador
  test-all                              Probar todos los indexadores
  enable <id>                           ESCRITURA: activar un indexador
  disable <id>                          ESCRITURA: desactivar un indexador
  delete <id>                           ESCRITURA DESTRUCTIVA: borrar un indexador (irreversible)

Aplicaciones:
  apps                                  Listar las aplicaciones conectadas (Sonarr, Radarr...)
  sync                                  ESCRITURA: sincronizar los indexadores con las aplicaciones

Sistema:
  status                                Estado del sistema
  health                                Avisos de salud
  logs [n] [nivel]                      Últimas n líneas de log (50 por defecto); nivel: info, warn, error...

Opciones cortas: -c categoría, -l límite, -t tipo, -s temporada, -e episodio, -v verbose.
Sin comando se muestra esta ayuda.
USAGE
}

# Error de uso: mensaje + línea de uso y salida con código 1
usage_error() {
  echo "ERROR: $1" >&2
  echo "Uso: prowlarr-api.sh $2" >&2
  exit 1
}

require_number() {
  [[ "$1" =~ ^[0-9]+$ ]] || usage_error "'$1' no es un número válido ($3)" "$2"
}

# Comprueba que la opción $1 tiene valor; $2 es el número de argumentos restantes
# y $3 el siguiente argumento. Uso: need_value "$1" "$#" "${2:-}" "<uso>"
need_value() {
  if [[ "$2" -lt 2 || "$3" == -* ]]; then
    usage_error "falta el valor de $1" "$4"
  fi
}

unknown_option() {
  usage_error "opción desconocida: $1" "$2"
}

# Valida y devuelve el id de un indexador. Uso: id=$(require_id "${1:-}" "<uso>")
require_id() {
  [[ -n "$1" ]] || usage_error "falta el id del indexador" "$2"
  require_number "$1" "$2" "id del indexador"
}

# Llamada cruda a la API (el caller añade -w/-o si los necesita)
api() {
  local method="$1"
  local endpoint="$2"
  shift 2

  curl -sS -X "$method" \
    -H "X-Api-Key: ${PROWLARR_API_KEY}" \
    -H "Content-Type: application/json" \
    "$@" \
    "${PROWLARR_URL}/api/v1${endpoint}"
}

# Lectura: imprime el cuerpo solo si el HTTP es 2xx; si no, ERROR por stderr y salida 1.
api_get() {
  local resp code body
  resp=$(api GET "$1" -w $'\n%{http_code}') \
    || { echo "ERROR: no se pudo conectar con Prowlarr" >&2; exit 1; }
  code="${resp##*$'\n'}"
  body="${resp%$'\n'*}"
  if [[ ! "$code" =~ ^2 ]]; then
    echo "ERROR: Prowlarr respondió HTTP $code en GET $1" >&2
    exit 1
  fi
  printf '%s\n' "$body"
}

# Escritura: comprueba el código HTTP. Deja el cuerpo en API_BODY.
# Devuelve 0 si es 2xx; si no, avisa por stderr (con el motivo si Prowlarr lo da) y devuelve 1.
API_BODY=""
api_ok() {
  local resp code detail
  resp=$(api "$@" -w $'\n%{http_code}') \
    || { echo "ERROR: no se pudo conectar con Prowlarr" >&2; return 1; }
  code="${resp##*$'\n'}"
  API_BODY="${resp%$'\n'*}"
  if [[ ! "$code" =~ ^2 ]]; then
    detail=$(jq -r 'if type == "array" then .[0] else . end | .errorMessage // .message // empty' 2>/dev/null <<<"$API_BODY" || true)
    echo "ERROR: Prowlarr respondió HTTP $code${detail:+: $detail}" >&2
    return 1
  fi
}

# Comando sin argumentos: $1 es el nombre, el resto lo recibido
no_args() {
  local name="$1"
  shift
  [[ $# -eq 0 ]] || unknown_option "$1" "$name"
}

cmd_search() {
  local u="search <texto> [--torrents | --usenet] [--category <id>] [--limit <n>] [--type <tipo>]"
  local query=""
  local type="search"
  local indexer_ids=""
  local categories=""
  local limit=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --torrents) indexer_ids="-2"; shift ;;
      --usenet) indexer_ids="-1"; shift ;;
      --category|-c)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--category"
        categories="$2"; shift 2 ;;
      --limit|-l)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--limit"
        limit="$2"; shift 2 ;;
      --type|-t)
        need_value "$1" "$#" "${2:-}" "$u"
        [[ "$2" =~ ^[A-Za-z]+$ ]] || usage_error "valor no válido para --type: '$2'" "$u"
        type="$2"; shift 2 ;;
      -*) unknown_option "$1" "$u" ;;
      *)
        [[ -z "$query" ]] || usage_error "sobra el argumento: $1 (usa comillas para el texto)" "$u"
        query="$1"; shift ;;
    esac
  done

  [[ -n "$query" ]] || usage_error "falta el texto de búsqueda" "$u"

  local params
  params="query=$(jq -rn --arg q "$query" '$q | @uri')"
  params+="&type=$type"
  [[ -n "$indexer_ids" ]] && params+="&indexerIds=$indexer_ids"
  [[ -n "$categories" ]] && params+="&categories=$categories"
  [[ -n "$limit" ]] && params+="&limit=$limit"

  api_get "/search?$params" | jq '[.[] | {
    title: .title,
    indexer: .indexer,
    size: (.size | . / 1048576 | floor | tostring + " MB"),
    seeders: .seeders,
    leechers: .leechers,
    age: .age,
    downloadUrl: .downloadUrl,
    infoUrl: .infoUrl
  }]'
}

cmd_tv_search() {
  local u="tv-search [--tvdb <id>] [--season <n>] [--episode <n>]"
  local tvdb="" season="" episode=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tvdb)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--tvdb"
        tvdb="$2"; shift 2 ;;
      --season|-s)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--season"
        season="$2"; shift 2 ;;
      --episode|-e)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--episode"
        episode="$2"; shift 2 ;;
      *) unknown_option "$1" "$u" ;;
    esac
  done

  local query=""
  [[ -n "$tvdb" ]] && query+="{TvdbId:$tvdb} "
  [[ -n "$season" ]] && query+="{Season:$season} "
  [[ -n "$episode" ]] && query+="{Episode:$episode}"

  [[ -n "$query" ]] || usage_error "falta al menos una de --tvdb, --season o --episode" "$u"

  local encoded_query
  encoded_query=$(jq -rn --arg q "$query" '$q | @uri')

  api_get "/search?query=$encoded_query&type=tvsearch" | jq '[.[] | {
    title: .title,
    indexer: .indexer,
    size: (.size | . / 1048576 | floor | tostring + " MB"),
    seeders: .seeders,
    age: .age,
    downloadUrl: .downloadUrl
  }]'
}

cmd_movie_search() {
  local u="movie-search [--imdb <ttid>] [--tmdb <id>]"
  local imdb="" tmdb=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --imdb)
        need_value "$1" "$#" "${2:-}" "$u"
        [[ "$2" =~ ^tt[0-9]+$ ]] || usage_error "'$2' no es un id de IMDB válido (--imdb, p. ej. tt0111161)" "$u"
        imdb="$2"; shift 2 ;;
      --tmdb)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--tmdb"
        tmdb="$2"; shift 2 ;;
      *) unknown_option "$1" "$u" ;;
    esac
  done

  local query=""
  [[ -n "$imdb" ]] && query+="{ImdbId:$imdb}"
  [[ -n "$tmdb" ]] && query+="{TmdbId:$tmdb}"

  [[ -n "$query" ]] || usage_error "falta --imdb o --tmdb" "$u"

  local encoded_query
  encoded_query=$(jq -rn --arg q "$query" '$q | @uri')

  api_get "/search?query=$encoded_query&type=moviesearch" | jq '[.[] | {
    title: .title,
    indexer: .indexer,
    size: (.size | . / 1048576 | floor | tostring + " MB"),
    seeders: .seeders,
    age: .age,
    downloadUrl: .downloadUrl
  }]'
}

cmd_indexers() {
  local u="indexers [--verbose]"
  local verbose=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verbose|-v) verbose=true; shift ;;
      *) unknown_option "$1" "$u" ;;
    esac
  done

  if [[ "$verbose" == "true" ]]; then
    api_get "/indexer"
  else
    api_get "/indexer" | jq '[.[] | {
      id: .id,
      name: .name,
      protocol: .protocol,
      enabled: .enable,
      priority: .priority
    }]'
  fi
}

cmd_stats() {
  no_args stats "$@"
  api_get "/indexerstats" | jq '.indexers | [.[] | {
    name: .indexerName,
    queries: .numberOfQueries,
    grabs: .numberOfGrabs,
    failures: .numberOfFailedQueries,
    avgResponseTime: .averageResponseTime
  }]'
}

cmd_test() {
  local u="test <id>"
  local id="${1:-}"
  require_id "$id" "$u"
  [[ $# -le 1 ]] || unknown_option "$2" "$u"
  local indexer
  indexer=$(api_get "/indexer/$id")
  api_ok POST "/indexer/test" -d "$indexer" || exit 1
  echo "Indexador $id: prueba de conectividad superada"
}

cmd_test_all() {
  no_args test-all "$@"
  api_ok POST "/indexer/testall" || exit 1
  # Prowlarr responde con una lista de resultados por indexador (isValid)
  if [[ -n "$API_BODY" ]] && jq -e 'type == "array"' >/dev/null 2>&1 <<<"$API_BODY"; then
    jq -r '.[] | "Indexador \(.id): \(if .isValid then "correcto" else "FALLA" end)"' <<<"$API_BODY"
  else
    echo "Pruebas de todos los indexadores lanzadas"
  fi
}

cmd_enable() {
  local u="enable <id>"
  local id="${1:-}"
  require_id "$id" "$u"
  [[ $# -le 1 ]] || unknown_option "$2" "$u"
  local indexer
  indexer=$(api_get "/indexer/$id" | jq '.enable = true')
  api_ok PUT "/indexer/$id" -d "$indexer" || exit 1
  echo "Indexador $id activado"
}

cmd_disable() {
  local u="disable <id>"
  local id="${1:-}"
  require_id "$id" "$u"
  [[ $# -le 1 ]] || unknown_option "$2" "$u"
  local indexer
  indexer=$(api_get "/indexer/$id" | jq '.enable = false')
  api_ok PUT "/indexer/$id" -d "$indexer" || exit 1
  echo "Indexador $id desactivado"
}

cmd_delete() {
  local u="delete <id>"
  local id="${1:-}"
  require_id "$id" "$u"
  [[ $# -le 1 ]] || unknown_option "$2" "$u"
  api_ok DELETE "/indexer/$id" || exit 1
  echo "Indexador $id borrado"
}

cmd_apps() {
  no_args apps "$@"
  api_get "/applications" | jq '[.[] | {
    id: .id,
    name: .name,
    syncLevel: .syncLevel,
    implementation: .implementation
  }]'
}

cmd_sync() {
  no_args sync "$@"
  api_ok POST "/command" -d '{"name": "ApplicationIndexerSync"}' || exit 1
  echo "Sincronización de indexadores con las aplicaciones solicitada"
}

cmd_status() {
  no_args status "$@"
  api_get "/system/status"
}

cmd_health() {
  no_args health "$@"
  api_get "/health" | jq '[.[] | {
    source: .source,
    type: .type,
    message: .message
  }]'
}

cmd_logs() {
  local u="logs [n] [nivel]"
  local n="${1:-50}"
  local level="${2:-}"
  require_number "$n" "$u" "n"
  [[ -z "$level" || "$level" =~ ^[A-Za-z]+$ ]] || usage_error "nivel no válido: '$level'" "$u"
  [[ $# -le 2 ]] || unknown_option "$3" "$u"
  local url="/log?pageSize=$n&sortKey=time&sortDirection=descending"
  [[ -n "$level" ]] && url+="&filterKey=level&filterValue=$level"
  api_get "$url" | jq -r '.records[] | "\(.time) [\(.level)] \(.logger): \(.message // .exception // "")"'
}

# Despacho
cmd="${1:-}"
shift || true

case "$cmd" in
  "") usage; exit 0 ;;
  -h|--help|help) usage; exit 0 ;;
  search) cmd_search "$@" ;;
  tv-search) cmd_tv_search "$@" ;;
  movie-search) cmd_movie_search "$@" ;;
  indexers) cmd_indexers "$@" ;;
  stats) cmd_stats "$@" ;;
  test) cmd_test "$@" ;;
  test-all) cmd_test_all "$@" ;;
  enable) cmd_enable "$@" ;;
  disable) cmd_disable "$@" ;;
  delete) cmd_delete "$@" ;;
  apps) cmd_apps "$@" ;;
  sync) cmd_sync "$@" ;;
  status) cmd_status "$@" ;;
  health) cmd_health "$@" ;;
  logs) cmd_logs "$@" ;;
  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
