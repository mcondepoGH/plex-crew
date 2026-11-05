#!/bin/bash
# Envoltorio de la API v3 de Sonarr: buscar, consultar, añadir y quitar series.
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../../_lib/load-env.sh" || { echo "ERROR: no se encuentra load-env.sh" >&2; exit 1; }
load_service_credentials "sonarr" "SONARR_URL" "SONARR_API_KEY"

API="$SONARR_URL/api/v3"
AUTH="X-Api-Key: $SONARR_API_KEY"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../../_lib/arr-api.sh" || { echo "ERROR: no se encuentra arr-api.sh" >&2; exit 1; }

DEFAULT_PROFILE="${SONARR_DEFAULT_QUALITY_PROFILE:-}"
[[ -n "$DEFAULT_PROFILE" ]] || DEFAULT_PROFILE=1

LOGS_USE="logs [N] [--level warn|error|info] [--grep texto] [--files]"

usage() {
  cat <<'USAGE'
Uso: sonarr.sh <comando> [args]

Comandos:
  search <texto>                          Busca series (texto, hasta 10 resultados)
  search-json <texto>                     Busca series (JSON crudo de Sonarr)
  exists <tvdbId>                         Indica si la serie está en la biblioteca
  config                                  Carpetas raíz y perfiles de calidad
  status                                  Versión y estado de Sonarr
  add <tvdbId> [perfilId] [--no-search]   Añade una serie (busca episodios por defecto)
  remove <tvdbId> [--delete-files]        Quita una serie de la biblioteca (destructivo)
  logs [N] [--level warn|error|info] [--grep texto] [--files]
                                          Últimas N entradas del log (solo lectura, 50 por defecto)
  health                      Avisos de salud de Sonarr (solo lectura)
  queue                       Cola de descargas (solo lectura)
  indexers                    Indexadores configurados, sin credenciales (solo lectura)
  downloadclients             Clientes de descarga, sin credenciales (solo lectura)
  customformats               Formatos personalizados (solo lectura)
  qualityprofiles             Perfiles de calidad: minFormatScore, cutoffFormatScore y formatos con puntuación (solo lectura)
  help                                    Muestra esta ayuda

El tvdbId y el perfilId son números enteros.
USAGE
}

# Error de uso: mensaje + línea de uso, salida con código 1
usage_error() {
  echo "ERROR: $1" >&2
  echo "Uso: sonarr.sh $2" >&2
  exit 1
}

# Exige que $2 sea un entero no negativo; $1 es el nombre del dato, $3 la línea de uso
require_number() {
  if [[ -z "$2" ]]; then
    usage_error "falta $1" "$3"
  fi
  if [[ ! "$2" =~ ^[0-9]+$ ]]; then
    usage_error "$1 no válido: '$2' (debe ser un número entero)" "$3"
  fi
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

# Petición directa sin comprobar el código HTTP. Uso: http <MÉTODO> <ruta> [json]
# Imprime el cuerpo; sale con 1 si curl falla. URL y clave viajan por stdin (no salen en ps).
http() {
  local conf out
  conf="url = $(curl_quote "$API$2")"$'\n'
  conf+="request = $(curl_quote "$1")"$'\n'
  conf+="header = $(curl_quote "$AUTH")"$'\n'
  if [[ -n "${3:-}" ]]; then
    conf+='header = "Content-Type: application/json"'$'\n'
    conf+="data-raw = $(curl_quote "$3")"$'\n'
  fi
  if ! out="$(printf '%s' "$conf" | curl -s --connect-timeout 10 --max-time 30 --config - 2>/dev/null)"; then
    echo "ERROR: no se pudo contactar con Sonarr en $SONARR_URL" >&2
    exit 1
  fi
  printf '%s' "$out"
}

# Codifica un texto para usarlo en una URL
urlencode() {
  printf '%s' "$1" | jq -sRr @uri
}

cmd_search() {
  local query="${1:-}" enc
  [[ -n "$query" ]] || usage_error "falta el texto de búsqueda" "search <query>"
  enc="$(urlencode "$query")"
  arr_call GET "/series/lookup?term=$enc" || exit 1
  jq -r '.[:10] | to_entries[] | "\(.key + 1). \(.value.title) (\(.value.year)) - https://thetvdb.com/dereferrer/series/\(.value.tvdbId)"' <<<"$ARR_BODY"
}

cmd_search_json() {
  local enc
  enc="$(urlencode "${1:-}")"
  printf '%s\n' "$(http GET "/series/lookup?term=$enc")"
}

cmd_exists() {
  local tvdb="${1:-}" body
  require_number "tvdbId" "$tvdb" "exists <tvdbId>"
  body="$(http GET "/series?tvdbId=$tvdb")"
  if [[ "$body" == "[]" ]]; then
    echo "not_found"
  else
    echo "exists"
    jq -r '.[0] | "ID: \(.id), Title: \(.title), Seasons: \(.statistics.seasonCount)"' <<<"$body"
  fi
}

cmd_config() {
  local roots profiles
  roots="$(http GET /rootfolder)"
  profiles="$(http GET /qualityprofile)"
  echo "=== Root Folders ==="
  jq -r '.[] | "\(.id): \(.path)"' <<<"$roots"
  echo
  echo "=== Quality Profiles ==="
  jq -r '.[] | "\(.id): \(.name)"' <<<"$profiles"
}

cmd_status() {
  arr_call GET /system/status || exit 1
  jq -r '"Sonarr \(.version) - \(.instanceName // "Sonarr") (\(.osName // "?"), branch \(.branch // "?"))"' <<<"$ARR_BODY"
}

cmd_add() {
  local tvdb="${1:-}" profile="${2:-}" search=true arg
  local lookup show roots root_path body resp id
  local use="add <tvdbId> [perfilId] [--no-search]"

  for arg in "$@"; do
    if [[ "$arg" == "--no-search" ]]; then
      search=false
    fi
  done

  require_number "tvdbId" "$tvdb" "$use"
  if [[ -z "$profile" || "$profile" == "--no-search" ]]; then
    profile="$DEFAULT_PROFILE"
    if [[ ! "$profile" =~ ^[0-9]+$ ]]; then
      usage_error "SONARR_DEFAULT_QUALITY_PROFILE no válido: '$profile' (debe ser un número entero)" "$use"
    fi
  else
    require_number "perfilId" "$profile" "$use"
  fi

  lookup="$(http GET "/series/lookup?term=tvdb:$tvdb")"
  show="$(jq -c 'if type == "array" then (.[0] // empty) else empty end' <<<"$lookup" 2>/dev/null || true)"
  if [[ -z "$show" || "$show" == "null" ]]; then
    echo "❌ Show not found with TVDB ID: $tvdb"
    exit 1
  fi

  roots="$(http GET /rootfolder)"
  root_path="$(jq -r '.[0].path // ""' <<<"$roots")"

  body="$(jq -c --arg root "$root_path" --argjson profile "$profile" --argjson search "$search" \
    '. + {
       rootFolderPath: $root,
       qualityProfileId: $profile,
       monitored: true,
       seasonFolder: true,
       addOptions: {
         monitor: "all",
         searchForMissingEpisodes: $search,
         searchForCutoffUnmetEpisodes: false
       }
     }' <<<"$show")"

  arr_call POST /series "$body" || exit 1
  resp="$ARR_BODY"
  id="$(jq -r 'if type == "object" then (.id // empty) else empty end' <<<"$resp" 2>/dev/null || true)"
  if [[ -n "$id" ]]; then
    jq -r '"✅ Added: \(.title) (\(.year)) - \(.statistics.seasonCount // "?") seasons"' <<<"$resp"
    if [[ "$search" == true ]]; then
      echo "🔍 Search started"
    fi
  else
    echo "❌ Failed to add show"
    jq -r 'if type == "object" and .message then .message else tostring end' <<<"$resp" 2>/dev/null \
      || printf '%s\n' "$resp"
    exit 1
  fi
}

cmd_remove() {
  local tvdb="${1:-}" delete=false body id title year
  local use="remove <tvdbId> [--delete-files]"
  if [[ "${2:-}" == "--delete-files" ]]; then
    delete=true
  fi
  require_number "tvdbId" "$tvdb" "$use"

  body="$(http GET "/series?tvdbId=$tvdb")"
  if [[ "$body" == "[]" ]]; then
    echo "❌ Show not found in library"
    exit 1
  fi
  id="$(jq -r '.[0].id' <<<"$body")"
  title="$(jq -r '.[0].title' <<<"$body")"
  year="$(jq -r '.[0].year' <<<"$body")"

  arr_call DELETE "/series/$id?deleteFiles=$delete" || exit 1
  if [[ "$delete" == true ]]; then
    echo "🗑️ Removed: $title ($year) + deleted files"
  else
    echo "🗑️ Removed: $title ($year) (files kept)"
  fi
}

cmd_logs() {
  local n=50 level="" grep_text="" files=false
  local pageSize path

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
    arr_call GET /log/file || exit 1
    jq -r 'if type == "array" then .[] | "\(.lastWriteTime // "?")  \(.filename // "?")" else empty end' <<<"$ARR_BODY"
    return 0
  fi

  pageSize="$n"
  if [[ -n "$grep_text" ]]; then
    pageSize=$((n * 20))
    if [[ "$pageSize" -gt 1000 ]]; then
      pageSize=1000
    fi
  fi
  path="/log?page=1&pageSize=$pageSize&sortKey=time&sortDirection=descending"
  if [[ -n "$level" ]]; then
    path+="&level=$level"
  fi
  arr_call GET "$path" || exit 1

  if ! jq -e '(.records | type) == "array"' >/dev/null 2>&1 <<<"$ARR_BODY"; then
    echo "ERROR: respuesta inesperada de /log (¿el servicio no expone el endpoint?)" >&2
    exit 1
  fi

  jq -r --arg g "$grep_text" --argjson n "$n" '
    def mask: gsub("(?<k>api_key|apikey|token|passkey|password|secret)=[^& ]*"; "\(.k)=***"; "i");
    def first_line: (split("\n")[0] // "");
    def clip: if length > 200 then .[:200] + "..." else . end;
    def hit: ($g | ascii_downcase) as $q
      | ((.message // "") | ascii_downcase | contains($q))
        or ((.logger // "") | ascii_downcase | contains($q));
    [ .records[] | select($g == "" or hit) ] | .[:$n] | reverse | .[]
    | "\(.time // "?")  \((.level // "?") | ascii_upcase | .[:5])  \(.logger // "?")  \((.message // "") | first_line | mask | clip)"
  ' <<<"$ARR_BODY"
}

# Definiciones jq compartidas: enmascarar secretos en texto libre y quitar campos sensibles
JQ_SAFE='
  def mask: gsub("(?<k>api_?key|token|passkey|password|secret)=[^& ]*"; "\(.k)=***"; "i");
  def secretkey: test("api_?key|password|token|username|secret|passkey|authorization|cookie"; "i");
  def scrub: walk(if type == "object" then with_entries(select(.key | secretkey | not)) else . end);
'

# Comandos sin argumentos: rechaza cualquier argumento sobrante. Uso: no_args <comando> [args...]
no_args() {
  local c="$1"
  shift
  [[ $# -eq 0 ]] || usage_error "$c no admite argumentos: $1" "$c"
}

cmd_health() {
  no_args health "$@"
  arr_call GET /health || exit 1
  if [[ "$(jq 'length' <<<"$ARR_BODY")" == "0" ]]; then
    echo "Sin avisos de salud"
    return 0
  fi
  jq -r "$JQ_SAFE"'scrub | .[] | "[\(.type // "?")] \(.source // "?"): \((.message // "") | mask)"' <<<"$ARR_BODY"
}

cmd_queue() {
  no_args queue "$@"
  arr_call GET "/queue?page=1&pageSize=100" || exit 1
  if ! jq -e '(.records | type) == "array"' >/dev/null 2>&1 <<<"$ARR_BODY"; then
    echo "ERROR: respuesta inesperada de /queue" >&2
    exit 1
  fi
  jq -r "$JQ_SAFE"'scrub | "En cola: \(.totalRecords // (.records | length))",
    (.records[] | "[\(.id)] \((.title // "?") | mask) - \(.status // "?")/\(.trackedDownloadState // "?")"
      + " - \(if (.size // 0) > 0 then ((100 * (.size - (.sizeleft // 0)) / .size) | floor | tostring) + "%" else "?" end)"
      + " - restante: \(.timeleft // "?") - \(.protocol // "?") (\(.downloadClient // "?"))")' <<<"$ARR_BODY"
}

cmd_indexers() {
  no_args indexers "$@"
  arr_call GET /indexer || exit 1
  jq -r "$JQ_SAFE"'scrub | if length == 0 then "No hay indexadores" else .[]
    | "[\(.id)] \(.name // "?") (\(.implementation // "?")) - \(.protocol // "?") - prioridad \(.priority // "?")"
      + " - rss: \(.enableRss // false), auto: \(.enableAutomaticSearch // false), interactiva: \(.enableInteractiveSearch // false)" end' <<<"$ARR_BODY"
}

cmd_downloadclients() {
  no_args downloadclients "$@"
  arr_call GET /downloadclient || exit 1
  jq -r "$JQ_SAFE"'scrub | if length == 0 then "No hay clientes de descarga" else .[]
    | "[\(.id)] \(.name // "?") (\(.implementation // "?")) - \(.protocol // "?") - prioridad \(.priority // "?") - activo: \(.enable // false)" end' <<<"$ARR_BODY"
}

cmd_customformats() {
  no_args customformats "$@"
  arr_call GET /customformat || exit 1
  jq -r "$JQ_SAFE"'scrub | if length == 0 then "No hay formatos personalizados" else .[]
    | "[\(.id)] \(.name // "?") - \((.specifications // []) | length) condiciones" end' <<<"$ARR_BODY"
}

cmd_qualityprofiles() {
  no_args qualityprofiles "$@"
  arr_call GET /qualityprofile || exit 1
  jq -r "$JQ_SAFE"'scrub | if length == 0 then "No hay perfiles de calidad" else .[]
    | "[\(.id)] \(.name // "?") - minFormatScore: \(.minFormatScore // 0), cutoffFormatScore: \(.cutoffFormatScore // 0)",
      ((.formatItems // []) | map(select((.score // 0) != 0)) | if length == 0 then "    (sin formatos puntuados)" else .[] | "    \(.name // "?"): \(.score)" end)
    end' <<<"$ARR_BODY"
}

cmd="${1:-}"
shift || true

case "$cmd" in
  ""|help|-h|--help) usage ;;
  search) cmd_search "${1:-}" ;;
  search-json) cmd_search_json "${1:-}" ;;
  exists) cmd_exists "${1:-}" ;;
  config) cmd_config ;;
  status) cmd_status ;;
  add) cmd_add "$@" ;;
  remove) cmd_remove "$@" ;;
  logs) cmd_logs "$@" ;;
  health) cmd_health "$@" ;;
  queue) cmd_queue "$@" ;;
  indexers) cmd_indexers "$@" ;;
  downloadclients) cmd_downloadclients "$@" ;;
  customformats) cmd_customformats "$@" ;;
  qualityprofiles) cmd_qualityprofiles "$@" ;;
  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    echo "Usa: sonarr.sh help" >&2
    exit 1
    ;;
esac
