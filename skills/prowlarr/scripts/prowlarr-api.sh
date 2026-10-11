#!/bin/bash
# Envoltorio de la API v1 de Prowlarr: buscar en indexadores, gestionarlos, sincronizar y consultar el log.
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../../_lib/load-env.sh" || { echo "ERROR: no se encuentra load-env.sh" >&2; exit 1; }
load_service_credentials "prowlarr" "PROWLARR_URL" "PROWLARR_API_KEY"

# Solo se quita UNA barra final
PROWLARR_URL="${PROWLARR_URL%/}"
API_BASE="$PROWLARR_URL/api/v1"
ME="$(basename "$0")"

LOGS_USE="logs [N] [--level warn|error|info] [--grep texto] [--files]"

usage() {
  cat <<USAGE
Prowlarr - búsqueda en indexadores y gestión de Prowlarr

Uso: $ME <comando> [args]

Búsqueda:
  search <query> [--torrents] [--usenet] [--category <id>] [--limit <n>]
                              Buscar en los indexadores (texto libre)
  tv-search --tvdb <id> [--season <n>] [--episode <n>]
                              Buscar un episodio por id de TVDB
  movie-search --imdb <id> [--tmdb <id>]
                              Buscar una película por id de IMDb o TMDB

Indexadores:
  indexers [--verbose]        Listar indexadores (--verbose: JSON completo)
  stats                       Estadísticas por indexador
  test <id>                   Probar un indexador
  test-all                    Probar todos los indexadores (hasta 120 s)
  enable <id>                 Activar un indexador
  disable <id>                Desactivar un indexador
  delete <id>                 Eliminar un indexador (destructivo)

Sincronización:
  apps                        Listar las aplicaciones conectadas
  sync                        Sincronizar los indexadores con las aplicaciones

Sistema:
  status                      Estado y versión de Prowlarr
  health                      Avisos de salud
  logs [N] [--level <nivel>] [--grep <texto>] [--files]
                              Últimas N entradas del log (solo lectura, 50 por defecto)
                              Niveles: trace, debug, info, warn, error, fatal
                              --files lista los ficheros de log

Ejemplos:
  $ME search "ubuntu 22.04"
  $ME search "inception" --category 2000 --torrents
  $ME tv-search --tvdb 71663 --season 1 --episode 1
  $ME movie-search --imdb tt0111161
  $ME stats
  $ME logs 20 --level warn
USAGE
}

# Error de uso: mensaje + línea de uso por stderr, salida con código 1
usage_error() {
  echo "ERROR: $1" >&2
  echo "Uso: $ME $2" >&2
  exit 1
}

# Exige un valor tras una opción. Uso: need_value <opción> <valor> <uso>
need_value() {
  [[ -n "$2" ]] || usage_error "$1 requiere un valor" "$3"
}

# Exige un entero no negativo. Uso: need_int <opción> <valor> <uso>
need_int() {
  [[ "$2" =~ ^[0-9]+$ ]] || usage_error "$1 debe ser un número entero: $2" "$3"
}

# Valida el id de test, enable, disable y delete. Uso: need_id <comando> <id>
need_id() {
  local use="$1 <id>"
  [[ -n "$2" ]] || usage_error "falta id" "$use"
  [[ "$2" =~ ^[0-9]+$ ]] || usage_error "id debe ser un número entero: $2" "$use"
}

# Entrecomilla un valor para una línea de configuración de curl
curl_quote() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}

# Única vía de petición. Uso: api <MÉTODO> <ruta> [cuerpo-json]
# Imprime el cuerpo y devuelve 0 solo con HTTP 2xx. URL, clave y cuerpo viajan por stdin de curl.
api() {
  local method="$1" path="$2" body="${3:-}"
  local conf out code resp msg xtrace=0
  if [[ $- == *x* ]]; then
    xtrace=1
    set +x
  fi
  conf="globoff"$'\n'
  conf+="url = $(curl_quote "$API_BASE$path")"$'\n'
  conf+="request = $(curl_quote "$method")"$'\n'
  conf+="header = $(curl_quote "X-Api-Key: $PROWLARR_API_KEY")"$'\n'
  conf+='header = "Content-Type: application/json"'$'\n'
  if [[ -n "$body" ]]; then
    conf+="data-raw = $(curl_quote "$body")"$'\n'
  fi
  if ! out="$(printf '%s' "$conf" | curl -s --connect-timeout 10 \
        --max-time "${API_MAX_TIME_OVERRIDE:-${PROWLARR_MAX_TIME:-30}}" \
        -w $'\n%{http_code}' --config - 2>/dev/null)"; then
    if [[ $xtrace -eq 1 ]]; then set -x; fi
    echo "ERROR: no se pudo contactar con Prowlarr en $PROWLARR_URL" >&2
    return 1
  fi
  if [[ $xtrace -eq 1 ]]; then set -x; fi
  code="${out##*$'\n'}"
  resp="${out%$'\n'*}"
  if [[ ! "$code" =~ ^2[0-9][0-9]$ ]]; then
    msg="$(jq -r 'if type == "array" then [.[] | objects | (.errorMessage // .message // empty)] | join("; ")
                  elif type == "object" then (.message // .errorMessage // empty)
                  else empty end' <<<"$resp" 2>/dev/null || true)"
    if [[ -n "$msg" ]]; then
      echo "ERROR: $method $path respondió HTTP $code: $msg" >&2
    else
      echo "ERROR: $method $path respondió HTTP $code" >&2
    fi
    return 1
  fi
  printf '%s\n' "$resp"
}

# Codifica un texto para usarlo en una URL
urlencode() {
  printf '%s' "$1" | jq -sRr @uri
}

cmd_search() {
  local query="" type="search" indexer_ids="" categories="" limit="" path body
  local use="search <query> [--torrents|--usenet] [--category <id>] [--limit <n>]"

  if [[ "${1:-}" != --* ]]; then
    query="${1:-}"
    shift || true
  fi
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --torrents) indexer_ids="-2"; shift ;;
      --usenet) indexer_ids="-1"; shift ;;
      --category|-c)
        need_value "$1" "${2:-}" "$use"
        categories="$2"
        shift 2
        ;;
      --limit|-l)
        need_value "$1" "${2:-}" "$use"
        need_int "$1" "$2" "$use"
        limit="$2"
        shift 2
        ;;
      --type|-t)
        need_value "$1" "${2:-}" "$use"
        type="$2"
        shift 2
        ;;
      *)
        [[ -n "$query" ]] || query="$1"
        shift
        ;;
    esac
  done
  [[ -n "$query" ]] || usage_error "falta el texto de búsqueda" "$use"

  path="/search?query=$(urlencode "$query")&type=$(urlencode "$type")"
  [[ -z "$indexer_ids" ]] || path+="&indexerIds=$indexer_ids"
  [[ -z "$categories" ]] || path+="&categories=$categories"
  [[ -z "$limit" ]] || path+="&limit=$limit"

  body="$(api GET "$path")" || exit 1
  jq '[.[] | {
        title: .title,
        indexer: .indexer,
        size: "\((.size / 1048576) | floor) MB",
        seeders: .seeders,
        leechers: .leechers,
        age: .age,
        downloadUrl: .downloadUrl,
        infoUrl: .infoUrl
      }]' <<<"$body"
}

# Formato común de tv-search y movie-search
print_media_results() {
  jq '[.[] | {
        title: .title,
        indexer: .indexer,
        size: "\((.size / 1048576) | floor) MB",
        seeders: .seeders,
        age: .age,
        downloadUrl: .downloadUrl
      }]' <<<"$1"
}

cmd_tv_search() {
  local tvdb="" season="" episode="" query="" body
  local use="tv-search --tvdb <id> [--season <n>] [--episode <n>]"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tvdb)
        need_value "$1" "${2:-}" "$use"
        need_int "$1" "$2" "$use"
        tvdb="$2"
        shift 2
        ;;
      --season|-s)
        need_value "$1" "${2:-}" "$use"
        need_int "$1" "$2" "$use"
        season="$2"
        shift 2
        ;;
      --episode|-e)
        need_value "$1" "${2:-}" "$use"
        need_int "$1" "$2" "$use"
        episode="$2"
        shift 2
        ;;
      *) shift ;;
    esac
  done

  [[ -n "$tvdb" ]] && query+="{TvdbId:$tvdb} "
  [[ -n "$season" ]] && query+="{Season:$season} "
  [[ -n "$episode" ]] && query+="{Episode:$episode}"
  [[ -n "$query" ]] || usage_error "falta al menos --tvdb" "$use"

  body="$(api GET "/search?query=$(urlencode "$query")&type=tvsearch")" || exit 1
  print_media_results "$body"
}

cmd_movie_search() {
  local imdb="" tmdb="" query="" body
  local use="movie-search --imdb <id> | --tmdb <id>"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --imdb)
        need_value "$1" "${2:-}" "$use"
        imdb="$2"
        shift 2
        ;;
      --tmdb)
        need_value "$1" "${2:-}" "$use"
        need_int "$1" "$2" "$use"
        tmdb="$2"
        shift 2
        ;;
      *) shift ;;
    esac
  done

  [[ -n "$imdb" ]] && query+="{ImdbId:$imdb}"
  [[ -n "$tmdb" ]] && query+="{TmdbId:$tmdb}"
  [[ -n "$query" ]] || usage_error "falta --imdb o --tmdb" "$use"

  body="$(api GET "/search?query=$(urlencode "$query")&type=moviesearch")" || exit 1
  print_media_results "$body"
}

cmd_indexers() {
  local verbose=false arg body
  for arg in "$@"; do
    case "$arg" in
      --verbose|-v) verbose=true ;;
    esac
  done
  body="$(api GET /indexer)" || exit 1
  if [[ "$verbose" == true ]]; then
    printf '%s\n' "$body"
    return 0
  fi
  jq '[.[] | {id: .id, name: .name, protocol: .protocol, enabled: .enable, priority: .priority}]' <<<"$body"
}

cmd_stats() {
  local body
  body="$(api GET /indexerstats)" || exit 1
  jq '[.indexers[] | {
        name: .indexerName,
        queries: .numberOfQueries,
        grabs: .numberOfGrabs,
        failures: .numberOfFailedQueries,
        avgResponseTime: .averageResponseTime
      }]' <<<"$body"
}

cmd_test() {
  local id="${1:-}" indexer
  need_id "test" "$id"
  indexer="$(api GET "/indexer/$id")" || exit 1
  if ! api POST /indexer/test "$indexer" >/dev/null; then
    echo "{\"status\": \"error\", \"indexer\": \"$id\", \"tested\": false}" >&2
    exit 1
  fi
  echo "{\"status\": \"ok\", \"indexer\": \"$id\", \"tested\": true}"
}

cmd_test_all() {
  local resp names map failed total nfailed
  resp="$(API_MAX_TIME_OVERRIDE="${PROWLARR_TESTALL_MAX_TIME:-${PROWLARR_MAX_TIME:-120}}" api POST /indexer/testall)" || exit 1
  if ! jq -e 'type == "array"' >/dev/null 2>&1 <<<"$resp"; then
    echo "ERROR: respuesta inesperada de Prowlarr en testall" >&2
    exit 1
  fi

  names="$(api GET /indexer 2>/dev/null)" || names="[]"
  map="$(jq -c 'if type == "array" then map({key: (.id | tostring), value: .name}) | from_entries else {} end' \
    <<<"$names" 2>/dev/null)" || map="{}"
  [[ -n "$map" ]] || map="{}"

  total="$(jq 'length' <<<"$resp")"
  failed="$(jq --argjson m "$map" '[.[] | select(.isValid == false) | {
      id: .id,
      name: ($m[(.id | tostring)] // "?"),
      errors: [(.validationFailures // [])[] | .errorMessage]
    }]' <<<"$resp")"
  nfailed="$(jq 'length' <<<"$failed")"

  if [[ "$nfailed" -eq 0 ]]; then
    echo "{\"status\": \"ok\", \"tested\": $total, \"failed\": 0}"
    return 0
  fi
  echo "ERROR: indexers con fallo:" >&2
  printf '%s\n' "$failed" >&2
  echo "{\"status\": \"error\", \"tested\": $total, \"failed\": $nfailed}"
  exit 1
}

# Activa o desactiva un indexador. Uso: set_enabled <comando> <id> <true|false>
set_enabled() {
  local cmd="$1" id="${2:-}" flag="$3" indexer body
  need_id "$cmd" "$id"
  indexer="$(api GET "/indexer/$id")" || exit 1
  body="$(jq -c --argjson e "$flag" '.enable = $e' <<<"$indexer")"
  api PUT "/indexer/$id" "$body" >/dev/null || exit 1
  echo "{\"status\": \"ok\", \"indexer\": \"$id\", \"enabled\": $flag}"
}

cmd_delete() {
  local id="${1:-}"
  need_id "delete" "$id"
  api DELETE "/indexer/$id" >/dev/null || exit 1
  echo "{\"status\": \"ok\", \"indexer\": \"$id\", \"deleted\": true}"
}

cmd_apps() {
  local body
  body="$(api GET /applications)" || exit 1
  jq '[.[] | {id: .id, name: .name, syncLevel: .syncLevel, implementation: .implementation}]' <<<"$body"
}

cmd_sync() {
  api POST /command '{"name": "ApplicationIndexerSync"}' || exit 1
  echo '{"status": "ok", "message": "Syncing indexers to applications"}'
}

cmd_status() {
  api GET /system/status || exit 1
}

cmd_health() {
  local body
  body="$(api GET /health)" || exit 1
  jq '[.[] | {source: .source, type: .type, message: .message}]' <<<"$body"
}

cmd_logs() {
  local n=50 level="" grep_text="" files=false
  local page_size path body

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --level)
        [[ -n "${2:-}" ]] || usage_error "--level requiere un valor" "$LOGS_USE"
        level="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
        shift 2
        ;;
      --grep)
        [[ -n "${2:-}" ]] || usage_error "--grep requiere un texto" "$LOGS_USE"
        grep_text="$2"
        shift 2
        ;;
      --files)
        files=true
        shift
        ;;
      -*)
        usage_error "opción desconocida para logs: $1" "$LOGS_USE"
        ;;
      *)
        if [[ "$1" =~ ^[0-9]{1,4}$ ]] && (( 10#$1 >= 1 && 10#$1 <= 1000 )); then
          n=$((10#$1))
        else
          usage_error "N debe ser un entero entre 1 y 1000: $1" "$LOGS_USE"
        fi
        shift
        ;;
    esac
  done

  case "$level" in
    ""|trace|debug|info|warn|error|fatal) ;;
    *)
      echo "ERROR: nivel no válido: $level (usa trace, debug, info, warn, error o fatal)" >&2
      exit 1
      ;;
  esac

  if [[ "$files" == true ]]; then
    body="$(api GET /log/file)" || exit 1
    jq -r 'if type == "array" then .[] | "\(.lastWriteTime // "?")  \(.filename // "?")" else empty end' <<<"$body"
    return 0
  fi

  page_size="$n"
  if [[ -n "$grep_text" ]]; then
    page_size=$((n * 20))
    if [[ "$page_size" -gt 1000 ]]; then
      page_size=1000
    fi
  fi
  path="/log?page=1&pageSize=$page_size&sortKey=time&sortDirection=descending"
  if [[ -n "$level" ]]; then
    path+="&level=$level"
  fi
  body="$(api GET "$path")" || exit 1

  if ! jq -e '(.records | type) == "array"' >/dev/null 2>&1 <<<"$body"; then
    echo "ERROR: respuesta inesperada de /log (¿el servicio no expone el endpoint?)" >&2
    exit 1
  fi

  jq -r --arg g "$grep_text" --argjson n "$n" '
    def mask: gsub("(?<k>api_key|apikey|token|passkey|password|secret)=[^& \t\n\r]*"; "\(.k)=***"; "i");
    def first_line: (split("\n")[0] // "");
    def clip: if length > 200 then .[:200] + "..." else . end;
    def hit: ($g | ascii_downcase) as $q
      | ((.message // "") | ascii_downcase | contains($q))
        or ((.logger // "") | ascii_downcase | contains($q));
    [ .records[] | select($g == "" or hit) ] | .[:$n] | reverse | .[]
    | "\(.time // "?")  \((.level // "?") | ascii_upcase | .[:5])  \(.logger // "?")  \((.message // "") | first_line | mask | clip)"
  ' <<<"$body"
}

cmd="${1:-}"
shift || true

case "$cmd" in
  ""|help|-h|--help) usage ;;
  search) cmd_search "$@" ;;
  tv-search) cmd_tv_search "$@" ;;
  movie-search) cmd_movie_search "$@" ;;
  indexers) cmd_indexers "$@" ;;
  stats) cmd_stats ;;
  test) cmd_test "${1:-}" ;;
  test-all) cmd_test_all ;;
  enable) set_enabled "enable" "${1:-}" true ;;
  disable) set_enabled "disable" "${1:-}" false ;;
  delete) cmd_delete "${1:-}" ;;
  apps) cmd_apps ;;
  sync) cmd_sync ;;
  status) cmd_status ;;
  health) cmd_health ;;
  logs) cmd_logs "$@" ;;
  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    echo "Usa: prowlarr-api.sh help" >&2
    exit 1
    ;;
esac
