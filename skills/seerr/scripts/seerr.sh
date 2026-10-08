#!/bin/bash
# Envoltorio de la API de Seerr (compatible con Overseerr)
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../../_lib/load-env.sh"
# shellcheck source=/dev/null
source "$_LOAD_ENV" || { echo "ERROR: no se encuentra load-env.sh" >&2; exit 1; }

load_service_credentials "seerr" "SEERR_URL" "SEERR_API_KEY"

API="${SEERR_URL%/}/api/v1"
AUTH="X-Api-Key: $SEERR_API_KEY"

_ARR_API="$SCRIPT_DIR/../../_lib/arr-api.sh"
# shellcheck source=/dev/null
source "$_ARR_API" || { echo "ERROR: no se encuentra arr-api.sh" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Uso: seerr.sh <comando> [args]

Comandos (los marcados JSON devuelven JSON; el resto, texto):
  status                              Estado y versión de Seerr (JSON)
  search <texto>                      Buscar títulos: tipo, id TMDB, título, año y estado (texto)
  requests [pending|approved|all]     Listar hasta 50 solicitudes; pending por defecto (texto)
  logs [n] [nivel]                    Últimas n entradas del log (50 por defecto);
                                      nivel: debug/info/warn/error (texto)
  request-movie <tmdbId>              Pedir una película (escritura, texto)
  request-tv <tmdbId> [temporadas]    Pedir una serie: todas las temporadas o una lista
                                      separada por comas, p. ej. 1,2 (escritura, texto)
USAGE
}

# Error de uso: mensaje + línea de uso y salida con código 1
usage_error() {
  echo "ERROR: $1" >&2
  echo "Uso: seerr.sh $2" >&2
  exit 1
}

require_number() {
  [[ "$1" =~ ^[0-9]+$ ]] || usage_error "'$1' no es un número válido" "$2"
}

# GET con comprobación HTTP: imprime el cuerpo; sale con 1 si no es 2xx
api_get() {
  arr_call GET "$1" || exit 1
  printf '%s\n' "$ARR_BODY"
}

# POST con comprobación HTTP: deja el cuerpo en ARR_BODY; sale con 1 si no es 2xx
api_post() {
  arr_call POST "$1" "$2" || exit 1
}

# Imprime el resultado de una solicitud creada
print_request() {
  jq -r '"Solicitud creada: id \(.id), tipo \(.media.mediaType // "?"), TMDB \(.media.tmdbId // "?"), estado \(.status)"' <<<"$ARR_BODY"
}

cmd="${1:-}"
shift || true

case "$cmd" in
  "")
    usage
    exit 0
    ;;

  -h|--help|help)
    usage
    exit 0
    ;;

  status)
    api_get "/status"
    ;;

  search)
    query="${1:-}"
    [[ -n "$query" ]] || usage_error "falta el texto de búsqueda" "search <texto>"
    api_get "/search?query=$(printf '%s' "$query" | jq -sRr @uri)" | jq -r '
      .results[] | "\(.mediaType | ascii_upcase) [\(.id)] \(.title // .name) (\(.releaseDate // .firstAirDate // "?" | .[0:4])) - mediaInfo: \(.mediaInfo.status // "none")"
    '
    ;;

  requests)
    filter="${1:-pending}"
    case "$filter" in
      pending|approved|all) ;;
      *) usage_error "filtro no válido: $filter (usa pending, approved o all)" "requests [pending|approved|all]" ;;
    esac
    api_get "/request?filter=$filter&take=50" | jq -r '
      .results[] | "[\(.id)] \(.media.mediaType) tmdb:\(.media.tmdbId) status:\(.status) requestedBy:\(.requestedBy.displayName // .requestedBy.email // "?")"
    '
    ;;

  request-movie)
    tmdbId="${1:-}"
    [[ -n "$tmdbId" ]] || usage_error "falta el tmdbId" "request-movie <tmdbId>"
    require_number "$tmdbId" "request-movie <tmdbId>"
    payload=$(jq -n --argjson id "$tmdbId" '{mediaType:"movie", mediaId:$id}')
    api_post "/request" "$payload"
    print_request
    ;;

  request-tv)
    tmdbId="${1:-}"
    seasons="${2:-}"
    [[ -n "$tmdbId" ]] || usage_error "falta el tmdbId" "request-tv <tmdbId> [temporadas]"
    require_number "$tmdbId" "request-tv <tmdbId> [temporadas]"
    if [[ -n "$seasons" ]]; then
      [[ "$seasons" =~ ^[0-9]+(,[0-9]+)*$ ]] || usage_error "temporadas no válidas: '$seasons' (usa una lista como 1,2)" "request-tv <tmdbId> [temporadas]"
      seasonsJson=$(jq -cR 'split(",") | map(tonumber)' <<<"$seasons")
      payload=$(jq -n --argjson id "$tmdbId" --argjson s "$seasonsJson" '{mediaType:"tv", mediaId:$id, seasons:$s}')
    else
      payload=$(jq -n --argjson id "$tmdbId" '{mediaType:"tv", mediaId:$id, seasons:"all"}')
    fi
    api_post "/request" "$payload"
    print_request
    ;;

  logs)
    n="${1:-50}"
    level="${2:-}"
    require_number "$n" "logs [n] [nivel]"
    if [[ -n "$level" ]]; then
      case "$level" in
        debug|info|warn|error) ;;
        *) usage_error "nivel no válido: $level (usa debug, info, warn o error)" "logs [n] [nivel]" ;;
      esac
    fi
    path="/settings/logs?take=$n&skip=0"
    [[ -n "$level" ]] && path+="&filter=$level"
    api_get "$path" | jq -r '.results[] | "\(.timestamp) [\(.level)] \(.label // ""): \(.message)"'
    ;;

  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
