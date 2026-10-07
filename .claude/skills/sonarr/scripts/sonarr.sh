#!/bin/bash
set -euo pipefail

# Sonarr API wrapper

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../../_lib/load-env.sh"
# shellcheck source=/dev/null
source "$_LOAD_ENV" || { echo "ERROR: load-env.sh not found. Copia .env.example a .env" >&2; exit 1; }

# Load credentials from .env
load_service_credentials "sonarr" "SONARR_URL" "SONARR_API_KEY"

API="$SONARR_URL/api/v3"
AUTH="X-Api-Key: $SONARR_API_KEY"

_ARR_API="$SCRIPT_DIR/../../_lib/arr-api.sh"
# shellcheck source=/dev/null
source "$_ARR_API" || { echo "ERROR: arr-api.sh not found" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Uso: sonarr.sh <comando> [args]

Comandos (los marcados JSON devuelven JSON; el resto, texto):
  search <texto>                          Buscar series (texto; muestra como máximo 10 resultados)
  search-json <texto>                     Igual que search, salida JSON (sin límite de 10)
  exists <tvdbId>                         Comprobar si la serie está en la biblioteca (texto)
  config                                  Carpetas raíz y perfiles de calidad (texto)
  add <tvdbId> <profileId> [--no-search]  Añadir serie; el perfil es obligatorio (ids con config);
                                          busca episodios al añadir salvo --no-search
  remove <tvdbId> [--delete-files]        Quitar una serie (con --delete-files borra también los ficheros)
  logs [n] [nivel]                        Últimas n líneas de log (50 por defecto); nivel: info/warn/error
  search-all                              Lanzar búsqueda de todos los episodios que faltan (toda la biblioteca)
  search-id <seriesId>                    Lanzar búsqueda de una serie por su id interno de Sonarr
USAGE
}

# Error de uso: mensaje + línea de uso y salida con código 1
usage_error() {
  echo "ERROR: $1" >&2
  echo "Uso: sonarr.sh $2" >&2
  exit 1
}

require_number() {
  [[ "$1" =~ ^[0-9]+$ ]] || usage_error "'$1' no es un id numérico" "$2"
}

# El perfil de calidad es siempre explícito: nunca se elige uno por defecto
require_profile() {
  if [[ -z "$1" ]]; then
    echo "ERROR: falta el profileId (perfil de calidad obligatorio)" >&2
    echo "Uso: sonarr.sh $2" >&2
    echo "Ejecuta 'sonarr.sh config' para ver los ids de perfil (p. ej. 7 Español, 8 VOSE)." >&2
    exit 1
  fi
  require_number "$1" "$2"
}

# Separa flags de posicionales: deja POSITIONAL=() y NO_SEARCH / DELETE_FILES
parse_args() {
  POSITIONAL=()
  NO_SEARCH="false"
  DELETE_FILES="false"
  local a
  for a in "$@"; do
    case "$a" in
      --no-search) NO_SEARCH="true" ;;
      --delete-files) DELETE_FILES="true" ;;
      *) POSITIONAL+=("$a") ;;
    esac
  done
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

  search)
    query="${1:-}"
    [[ -n "$query" ]] || usage_error "falta el texto de búsqueda" "search <texto>"
    arr_get "/series/lookup?term=$(echo "$query" | jq -sRr @uri)" | jq -r '
      to_entries | .[:10] | .[] |
      "\(.key + 1). \(.value.title) (\(.value.year)) - https://thetvdb.com/dereferrer/series/\(.value.tvdbId)"
    '
    ;;

  search-json)
    query="${1:-}"
    [[ -n "$query" ]] || usage_error "falta el texto de búsqueda" "search-json <texto>"
    arr_get "/series/lookup?term=$(echo "$query" | jq -sRr @uri)"
    ;;

  exists)
    tvdbId="${1:-}"
    [[ -n "$tvdbId" ]] || usage_error "falta el tvdbId" "exists <tvdbId>"
    require_number "$tvdbId" "exists <tvdbId>"
    result=$(arr_get "/series?tvdbId=$tvdbId")
    if [ "$result" = "[]" ]; then
      echo "not_found"
    else
      echo "exists"
      echo "$result" | jq -r '.[0] | "ID: \(.id), Title: \(.title), Seasons: \(.statistics.seasonCount)"'
    fi
    ;;

  config)
    echo "=== Root Folders ==="
    arr_get "/rootfolder" | jq -r '.[] | "\(.id): \(.path)"'
    echo ""
    echo "=== Quality Profiles ==="
    arr_get "/qualityprofile" | jq -r '.[] | "\(.id): \(.name)"'
    ;;

  add)
    parse_args "$@"
    tvdbId="${POSITIONAL[0]:-}"
    qualityProfileId="${POSITIONAL[1]:-}"
    [[ -n "$tvdbId" ]] || usage_error "falta el tvdbId" "add <tvdbId> <profileId> [--no-search]"
    require_number "$tvdbId" "add <tvdbId> <profileId> [--no-search]"
    require_profile "$qualityProfileId" "add <tvdbId> <profileId> [--no-search]"
    searchFlag="true"
    [[ "$NO_SEARCH" = "true" ]] && searchFlag="false"

    # Get series details from lookup
    series=$(arr_get "/series/lookup?term=tvdb:$tvdbId" | jq '.[0]')

    if [ "$series" = "null" ] || [ -z "$series" ]; then
      echo "❌ Show not found with TVDB ID: $tvdbId"
      exit 1
    fi

    # Get default root folder
    rootFolder=$(arr_get "/rootfolder" | jq -r '.[0].path')

    qualityProfile="$qualityProfileId"

    # Build add request
    addRequest=$(echo "$series" | jq --arg rf "$rootFolder" --argjson qp "$qualityProfile" --argjson search "$searchFlag" '
      . + {
        rootFolderPath: $rf,
        qualityProfileId: $qp,
        monitored: true,
        seasonFolder: true,
        addOptions: {
          monitor: "all",
          searchForMissingEpisodes: $search,
          searchForCutoffUnmetEpisodes: false
        }
      }
    ')

    result=$(arr_post "/series" "$addRequest")

    if echo "$result" | jq -e '.id' > /dev/null 2>&1; then
      title=$(echo "$result" | jq -r '.title')
      year=$(echo "$result" | jq -r '.year')
      seasons=$(echo "$result" | jq -r '.statistics.seasonCount // "?"')
      echo "✅ Added: $title ($year) - $seasons seasons"
      if [ "$searchFlag" = "true" ]; then
        echo "🔍 Search started"
      fi
    else
      echo "❌ Failed to add show"
      echo "$result" | jq -r '.message // .'
    fi
    ;;

  remove)
    parse_args "$@"
    tvdbId="${POSITIONAL[0]:-}"
    [[ -n "$tvdbId" ]] || usage_error "falta el tvdbId" "remove <tvdbId> [--delete-files]"
    require_number "$tvdbId" "remove <tvdbId> [--delete-files]"
    deleteFiles="$DELETE_FILES"

    # Get series ID from library
    series=$(arr_get "/series?tvdbId=$tvdbId")

    if [ "$series" = "[]" ]; then
      echo "❌ Show not found in library"
      exit 1
    fi

    seriesId=$(echo "$series" | jq -r '.[0].id')
    title=$(echo "$series" | jq -r '.[0].title')
    year=$(echo "$series" | jq -r '.[0].year')

    arr_delete "/series/$seriesId?deleteFiles=$deleteFiles" > /dev/null

    if [ "$deleteFiles" = "true" ]; then
      echo "🗑️ Removed: $title ($year) + deleted files"
    else
      echo "🗑️ Removed: $title ($year) (files kept)"
    fi
    ;;

  logs)
    n="${1:-50}"
    level="${2:-}"
    require_number "$n" "logs [n] [nivel]"
    url="/log?pageSize=$n&sortKey=time&sortDirection=descending"
    [[ -n "$level" ]] && url+="&filterKey=level&filterValue=$level"
    arr_get "$url" | jq -r '.records[] | "\(.time) [\(.level)] \(.logger): \(.message // .exception // "")"'
    ;;

  search-all)
    result=$(arr_post "/command" '{"name":"MissingEpisodeSearch"}')
    echo "$result" | jq -r '"🔍 Started: \(.name) (command id \(.id), status \(.status))"'
    ;;

  search-id)
    seriesId="${1:-}"
    [[ -n "$seriesId" ]] || usage_error "falta el id interno de la serie" "search-id <seriesId>"
    require_number "$seriesId" "search-id <seriesId>"
    result=$(arr_post "/command" "{\"name\":\"SeriesSearch\",\"seriesId\":$seriesId}")
    echo "$result" | jq -r --arg sid "$seriesId" '"🔍 Started: \(.name) for series \($sid) (command id \(.id), status \(.status))"'
    ;;

  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
