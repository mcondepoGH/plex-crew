#!/bin/bash
# Envoltorio de la API v3 de Radarr: buscar, consultar, añadir y quitar películas y colecciones.
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../../_lib/load-env.sh" || { echo "ERROR: no se encuentra load-env.sh" >&2; exit 1; }
load_service_credentials "radarr" "RADARR_URL" "RADARR_API_KEY"

API="$RADARR_URL/api/v3"
AUTH="X-Api-Key: $RADARR_API_KEY"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../../_lib/arr-api.sh" || { echo "ERROR: no se encuentra arr-api.sh" >&2; exit 1; }

DEFAULT_PROFILE="${RADARR_DEFAULT_QUALITY_PROFILE:-}"
[[ -n "$DEFAULT_PROFILE" ]] || DEFAULT_PROFILE=1

LOGS_USE="logs [N] [--level warn|error|info] [--grep texto] [--files]"

usage() {
  cat <<'USAGE'
Uso: radarr.sh <comando> [args]

Comandos:
  search <query>              Buscar películas
  search-json <query>         Buscar (salida JSON)
  exists <tmdbId>             Comprobar si la película está en la biblioteca
  config                      Mostrar carpetas raíz y perfiles de calidad
  status                      Mostrar versión y estado de Radarr
  add <tmdbId> [profileId] [--no-search]  Añadir una película (busca por defecto)
  add-collection <idColeccionTmdb> [término] [--no-search]  Añadir una colección completa
  remove <tmdbId> [--delete-files]  Quitar una película de la biblioteca
  collection-info <idColeccionTmdb>  Detalles de una colección (JSON)
  logs [N] [--level warn|error|info] [--grep texto] [--files]
                              Últimas N entradas del log (solo lectura, 50 por defecto)
USAGE
}

# Error de uso: mensaje + línea de uso por stderr, salida con código 1
usage_error() {
  echo "ERROR: $1" >&2
  echo "Uso: radarr.sh $2" >&2
  exit 1
}

# Exige un entero no negativo. Uso: require_number <nombre> <valor> <uso>
require_number() {
  if [[ -z "$2" ]]; then
    usage_error "falta el $1" "$3"
  fi
  if [[ ! "$2" =~ ^[0-9]+$ ]]; then
    usage_error "$1 debe ser un número entero: $2" "$3"
  fi
}

# Quita los ceros a la izquierda de un entero ya validado (para pasarlo a jq como número)
norm_id() {
  local v="$1"
  v="${v#"${v%%[!0]*}"}"
  printf '%s' "${v:-0}"
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
  local conf out xtrace=0
  if [[ $- == *x* ]]; then
    xtrace=1
    set +x
  fi
  conf="url = $(curl_quote "$API$2")"$'\n'
  conf+="request = $(curl_quote "$1")"$'\n'
  conf+="header = $(curl_quote "$AUTH")"$'\n'
  if [[ -n "${3:-}" ]]; then
    conf+='header = "Content-Type: application/json"'$'\n'
    conf+="data-raw = $(curl_quote "$3")"$'\n'
  fi
  if ! out="$(printf '%s' "$conf" | curl -s --connect-timeout 10 --max-time 30 --config - 2>/dev/null)"; then
    echo "ERROR: no se pudo contactar con Radarr en $RADARR_URL" >&2
    exit 1
  fi
  if [[ $xtrace -eq 1 ]]; then
    set -x
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
  arr_call GET "/movie/lookup?term=$enc" || exit 1
  jq -r 'to_entries[]
    | "\(.key + 1). \(.value.title) (\(.value.year)) - https://themoviedb.org/movie/\(.value.tmdbId)"
      + (if .value.collection.tmdbId then " [Collection: \(.value.collection.title)]" else "" end)' <<<"$ARR_BODY"
}

cmd_search_json() {
  local enc body
  enc="$(urlencode "${1:-}")"
  body="$(http GET "/movie/lookup?term=$enc")"
  printf '%s\n' "$body"
}

cmd_exists() {
  local tmdb="${1:-}" body
  require_number "tmdbId" "$tmdb" "exists <tmdbId>"
  tmdb="$(norm_id "$tmdb")"
  body="$(http GET "/movie?tmdbId=$tmdb")"
  if [[ "$body" == "[]" ]]; then
    echo "not_found"
  else
    echo "exists"
    jq -r '.[0] | "ID: \(.id), Title: \(.title), Has File: \(.hasFile)"' <<<"$body"
  fi
}

cmd_config() {
  local roots profiles
  roots="$(http GET /rootfolder)"
  echo "=== Root Folders ==="
  jq -r '.[] | "\(.id): \(.path)"' <<<"$roots"
  echo
  profiles="$(http GET /qualityprofile)"
  echo "=== Quality Profiles ==="
  jq -r '.[] | "\(.id): \(.name)"' <<<"$profiles"
}

cmd_status() {
  arr_call GET /system/status || exit 1
  jq -r '"Radarr \(.version) - \(.instanceName // "Radarr") (\(.osName // "?"), branch \(.branch // "?"))"' <<<"$ARR_BODY"
}

cmd_add() {
  local tmdb="${1:-}" profile="${2:-}" search=true arg
  local lookup roots root_path body resp id
  local use="add <tmdbId> [profileId] [--no-search]"

  for arg in "$@"; do
    if [[ "$arg" == "--no-search" ]]; then
      search=false
    fi
  done

  require_number "tmdbId" "$tmdb" "$use"
  if [[ -z "$profile" || "$profile" == "--no-search" ]]; then
    profile="$DEFAULT_PROFILE"
    if [[ ! "$profile" =~ ^[0-9]+$ ]]; then
      usage_error "RADARR_DEFAULT_QUALITY_PROFILE debe ser un número entero: $profile" "$use"
    fi
  else
    require_number "profileId" "$profile" "$use"
  fi
  tmdb="$(norm_id "$tmdb")"
  profile="$(norm_id "$profile")"

  lookup="$(http GET "/movie/lookup/tmdb?tmdbId=$tmdb")"
  roots="$(http GET /rootfolder)"
  root_path="$(jq -r '.[0].path // ""' <<<"$roots")"

  body="$(jq -c --arg root "$root_path" --argjson profile "$profile" --argjson search "$search" \
    '. + {
       rootFolderPath: $root,
       qualityProfileId: $profile,
       monitored: true,
       addOptions: { searchForMovie: $search }
     }' <<<"$lookup")"

  resp="$(http POST /movie "$body")"
  id="$(jq -r 'if type == "object" then (.id // empty) else empty end' <<<"$resp" 2>/dev/null || true)"
  if [[ -n "$id" ]]; then
    jq -r '"✅ Added: \(.title) (\(.year))"' <<<"$resp"
    if [[ "$search" == true ]]; then
      echo "🔍 Search started"
    fi
  else
    echo "❌ Failed to add movie"
    jq -r 'if type == "object" and .message then .message else tostring end' <<<"$resp" 2>/dev/null \
      || printf '%s\n' "$resp"
  fi
}

cmd_add_collection() {
  local cid="${1:-}" term="${2:-}" search=true arg
  local colls coll movies count roots root_path profiles profile
  local movie label tid existing body resp added=0 skipped=0 msg iid cdata cresp
  local use="add-collection <collectionTmdbId> [searchTerm] [--no-search]"

  for arg in "$@"; do
    if [[ "$arg" == "--no-search" ]]; then
      search=false
    fi
  done

  require_number "collectionTmdbId" "$cid" "$use"
  cid="$(norm_id "$cid")"

  echo "🔍 Finding movies in collection..."
  colls="$(http GET /collection)"
  coll="$(jq -c --argjson id "$cid" '[.[] | select(.tmdbId == $id)][0] // empty' <<<"$colls")"
  if [[ -n "$coll" ]]; then
    term="$(jq -r '.title // "" | sub(" Collection$"; "")' <<<"$coll")"
  fi
  if [[ -z "$term" ]]; then
    echo "❌ Could not determine collection name. Please provide search term."
    echo "Uso: radarr.sh $use" >&2
    exit 1
  fi

  movies="$(http GET "/movie/lookup?term=$(urlencode "$term")")"
  movies="$(jq -c --argjson id "$cid" '[.[] | select(.collection.tmdbId == $id)]' <<<"$movies")"
  count="$(jq 'length' <<<"$movies")"
  if [[ "$count" -eq 0 ]]; then
    echo "❌ No movies found for collection $cid"
    exit 1
  fi
  echo "📦 Found $count movies in collection"

  roots="$(http GET /rootfolder)"
  root_path="$(jq -r '.[0].path // ""' <<<"$roots")"
  profiles="$(http GET /qualityprofile)"
  profile="$(jq -c '.[0].id' <<<"$profiles")"

  while IFS= read -r movie; do
    label="$(jq -r '"\(.title) (\(.year))"' <<<"$movie")"
    tid="$(jq -r '.tmdbId' <<<"$movie")"
    existing="$(http GET "/movie?tmdbId=$tid")"
    if [[ "$existing" != "[]" ]]; then
      echo "⏭️  $label - already in library"
      skipped=$((skipped + 1))
      continue
    fi
    body="$(jq -c --arg root "$root_path" --argjson profile "$profile" --argjson search "$search" \
      '. + {
         rootFolderPath: $root,
         qualityProfileId: $profile,
         monitored: true,
         addOptions: { searchForMovie: $search }
       }' <<<"$movie")"
    resp="$(http POST /movie "$body")"
    if [[ -n "$(jq -r 'if type == "object" then (.id // empty) else empty end' <<<"$resp" 2>/dev/null || true)" ]]; then
      echo "✅ $label"
      added=$((added + 1))
    else
      msg="$(jq -r '(if type == "object" then .message else null end) // "failed"' <<<"$resp" 2>/dev/null || true)"
      echo "❌ $label - ${msg:-failed}"
    fi
  done < <(jq -c '.[]' <<<"$movies")

  echo
  echo "📊 Added: $added | Skipped: $skipped"
  if [[ "$search" == true && "$added" -gt 0 ]]; then
    echo "🔍 Search started for new movies"
  fi

  colls="$(http GET /collection)"
  iid="$(jq -r --argjson id "$cid" '[.[] | select(.tmdbId == $id)][0].id // empty' <<<"$colls")"
  if [[ -n "$iid" ]]; then
    cdata="$(http GET "/collection/$iid")"
    body="$(jq -c '. + {monitored: true, searchOnAdd: true}' <<<"$cdata")"
    cresp="$(http PUT "/collection/$iid" "$body")"
    if [[ "$(jq -r 'if type == "object" then (.monitored == true) else false end' <<<"$cresp" 2>/dev/null || true)" == true ]]; then
      echo "👁️ Collection monitored (new releases auto-added)"
    fi
  fi
}

cmd_remove() {
  local tmdb="${1:-}" delete=false body id title year
  local use="remove <tmdbId> [--delete-files]"
  if [[ "${2:-}" == "--delete-files" ]]; then
    delete=true
  fi
  require_number "tmdbId" "$tmdb" "$use"
  tmdb="$(norm_id "$tmdb")"

  body="$(http GET "/movie?tmdbId=$tmdb")"
  if [[ "$body" == "[]" ]]; then
    echo "❌ Movie not found in library"
    exit 1
  fi
  id="$(jq -r '.[0].id' <<<"$body")"
  title="$(jq -r '.[0].title' <<<"$body")"
  year="$(jq -r '.[0].year' <<<"$body")"

  http DELETE "/movie/$id?deleteFiles=$delete" >/dev/null
  if [[ "$delete" == true ]]; then
    echo "🗑️ Removed: $title ($year) + deleted files"
  else
    echo "🗑️ Removed: $title ($year) (files kept)"
  fi
}

cmd_collection_info() {
  local cid="${1:-}" body
  require_number "collectionTmdbId" "$cid" "collection-info <collectionTmdbId>"
  cid="$(norm_id "$cid")"
  body="$(http GET /collection)"
  jq --argjson id "$cid" '.[] | select(.tmdbId == $id)' <<<"$body"
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
  add-collection) cmd_add_collection "$@" ;;
  remove) cmd_remove "$@" ;;
  collection-info) cmd_collection_info "${1:-}" ;;
  logs) cmd_logs "$@" ;;
  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    echo "Usa: radarr.sh help" >&2
    exit 1
    ;;
esac
