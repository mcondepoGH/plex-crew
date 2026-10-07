#!/bin/bash
set -euo pipefail

# Radarr API wrapper

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../../_lib/load-env.sh"
# shellcheck source=/dev/null
source "$_LOAD_ENV" || { echo "ERROR: load-env.sh not found. Copia .env.example a .env" >&2; exit 1; }

# Load credentials from .env
load_service_credentials "radarr" "RADARR_URL" "RADARR_API_KEY"

API="$RADARR_URL/api/v3"
AUTH="X-Api-Key: $RADARR_API_KEY"

_ARR_API="$SCRIPT_DIR/../../_lib/arr-api.sh"
# shellcheck source=/dev/null
source "$_ARR_API" || { echo "ERROR: arr-api.sh not found" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Uso: radarr.sh <comando> [args]

Comandos (los marcados JSON devuelven JSON; el resto, texto):
  search <texto>                          Buscar películas (lista numerada en texto, sin límite propio)
  search-json <texto>                     Igual que search, salida JSON
  exists <tmdbId>                         Comprobar si la película está en la biblioteca (texto)
  config                                  Carpetas raíz y perfiles de calidad (texto)
  add <tmdbId> <profileId> [--no-search]  Añadir película; el perfil es obligatorio (ids con config);
                                          busca al añadir salvo --no-search
  add-collection <collectionTmdbId> <profileId> [searchTerm] [--no-search]
                                          Añadir todas las películas de una colección con ese perfil
                                          (primera carpeta raíz); deja la colección monitorizada
  remove <tmdbId> [--delete-files]        Quitar una película (con --delete-files borra también los ficheros)
  collection-info <collectionTmdbId>      Detalles de la colección (JSON)
  logs [n] [nivel]                        Últimas n líneas de log (50 por defecto); nivel: info/warn/error
  search-all                              Lanzar búsqueda de todas las películas que faltan (toda la biblioteca)
  search-id <movieId>                     Lanzar búsqueda de una película por su id interno de Radarr
USAGE
}

# Error de uso: mensaje + línea de uso y salida con código 1
usage_error() {
  echo "ERROR: $1" >&2
  echo "Uso: radarr.sh $2" >&2
  exit 1
}

require_number() {
  [[ "$1" =~ ^[0-9]+$ ]] || usage_error "'$1' no es un id numérico" "$2"
}

# El perfil de calidad es siempre explícito: nunca se elige uno por defecto
require_profile() {
  if [[ -z "$1" ]]; then
    echo "ERROR: falta el profileId (perfil de calidad obligatorio)" >&2
    echo "Uso: radarr.sh $2" >&2
    echo "Ejecuta 'radarr.sh config' para ver los ids de perfil (p. ej. 7 Español, 8 VOSE)." >&2
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
    arr_get "/movie/lookup?term=$(echo "$query" | jq -sRr @uri)" | jq -r '
      to_entries | .[] |
      "\(.key + 1). \(.value.title) (\(.value.year)) - https://themoviedb.org/movie/\(.value.tmdbId)" +
      (if .value.collection.tmdbId then " [Collection: \(.value.collection.title)]" else "" end)
    '
    ;;

  search-json)
    query="${1:-}"
    [[ -n "$query" ]] || usage_error "falta el texto de búsqueda" "search-json <texto>"
    arr_get "/movie/lookup?term=$(echo "$query" | jq -sRr @uri)"
    ;;

  exists)
    tmdbId="${1:-}"
    [[ -n "$tmdbId" ]] || usage_error "falta el tmdbId" "exists <tmdbId>"
    require_number "$tmdbId" "exists <tmdbId>"
    result=$(arr_get "/movie?tmdbId=$tmdbId")
    if [ "$result" = "[]" ]; then
      echo "not_found"
    else
      echo "exists"
      echo "$result" | jq -r '.[0] | "ID: \(.id), Title: \(.title), Has File: \(.hasFile)"'
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
    tmdbId="${POSITIONAL[0]:-}"
    qualityProfileId="${POSITIONAL[1]:-}"
    [[ -n "$tmdbId" ]] || usage_error "falta el tmdbId" "add <tmdbId> <profileId> [--no-search]"
    require_number "$tmdbId" "add <tmdbId> <profileId> [--no-search]"
    require_profile "$qualityProfileId" "add <tmdbId> <profileId> [--no-search]"
    searchFlag="true"
    [[ "$NO_SEARCH" = "true" ]] && searchFlag="false"

    # Get movie details from lookup
    movie=$(arr_get "/movie/lookup/tmdb?tmdbId=$tmdbId")

    # Get default root folder
    rootFolder=$(arr_get "/rootfolder" | jq -r '.[0].path')

    qualityProfile="$qualityProfileId"

    # Build add request
    addRequest=$(echo "$movie" | jq --arg rf "$rootFolder" --argjson qp "$qualityProfile" --argjson search "$searchFlag" '
      . + {
        rootFolderPath: $rf,
        qualityProfileId: $qp,
        monitored: true,
        addOptions: {
          searchForMovie: $search
        }
      }
    ')

    result=$(arr_post "/movie" "$addRequest")

    if echo "$result" | jq -e '.id' > /dev/null 2>&1; then
      echo "✅ Added: $(echo "$result" | jq -r '.title') ($(echo "$result" | jq -r '.year'))"
      if [ "$searchFlag" = "true" ]; then
        echo "🔍 Search started"
      fi
    else
      echo "❌ Failed to add movie"
      echo "$result" | jq -r '.message // .'
    fi
    ;;

  add-collection)
    parse_args "$@"
    collectionTmdbId="${POSITIONAL[0]:-}"
    qualityProfileId="${POSITIONAL[1]:-}"
    searchTerm="${POSITIONAL[2]:-}"
    [[ -n "$collectionTmdbId" ]] || usage_error "falta el tmdbId de la colección" "add-collection <collectionTmdbId> <profileId> [searchTerm] [--no-search]"
    require_number "$collectionTmdbId" "add-collection <collectionTmdbId> <profileId> [searchTerm] [--no-search]"
    require_profile "$qualityProfileId" "add-collection <collectionTmdbId> <profileId> [searchTerm] [--no-search]"
    searchFlag="true"
    [[ "$NO_SEARCH" = "true" ]] && searchFlag="false"

    echo "🔍 Finding movies in collection..."

    # Try getting collection name from Radarr's collection list first
    collections=$(arr_get "/collection")
    collection=$(echo "$collections" | jq --argjson tid "$collectionTmdbId" '.[] | select(.tmdbId == $tid)')

    if [ -n "$collection" ] && [ "$collection" != "null" ]; then
      collectionTitle=$(echo "$collection" | jq -r '.title')
      # Remove "Collection" suffix for better search
      searchTerm=$(echo "$collectionTitle" | sed 's/ Collection$//')
    fi

    # If no search term yet, use the provided one or fail
    if [ -z "$searchTerm" ]; then
      echo "❌ Could not determine collection name. Please provide search term."
      echo "Usage: add-collection <collectionTmdbId> <profileId> <searchTerm> [--no-search]"
      exit 1
    fi

    # Search for movies
    allMovies=$(arr_get "/movie/lookup?term=$(echo "$searchTerm" | jq -sRr @uri)")

    # Filter to only movies in our collection
    moviesToAdd=$(echo "$allMovies" | jq --argjson cid "$collectionTmdbId" '[.[] | select(.collection.tmdbId == $cid)]')
    movieCount=$(echo "$moviesToAdd" | jq 'length')

    if [ "$movieCount" = "0" ]; then
      echo "❌ No movies found for collection $collectionTmdbId"
      exit 1
    fi

    echo "📦 Found $movieCount movies in collection"

    # Carpeta raíz por defecto (la primera); el perfil es el indicado
    rootFolder=$(arr_get "/rootfolder" | jq -r '.[0].path')
    qualityProfile="$qualityProfileId"

    # Add each movie
    added=0
    skipped=0
    for i in $(seq 0 $((movieCount - 1))); do
      movie=$(echo "$moviesToAdd" | jq ".[$i]")
      tmdbId=$(echo "$movie" | jq -r '.tmdbId')
      title=$(echo "$movie" | jq -r '.title')
      year=$(echo "$movie" | jq -r '.year')

      # Check if already exists
      existing=$(arr_get "/movie?tmdbId=$tmdbId")
      if [ "$existing" != "[]" ]; then
        echo "⏭️  $title ($year) - already in library"
        skipped=$((skipped + 1))
        continue
      fi

      # Add movie
      addRequest=$(echo "$movie" | jq --arg rf "$rootFolder" --argjson qp "$qualityProfile" --argjson search "$searchFlag" '
        . + {
          rootFolderPath: $rf,
          qualityProfileId: $qp,
          monitored: true,
          addOptions: {
            searchForMovie: $search
          }
        }
      ')

      result=$(arr_post "/movie" "$addRequest")

      if echo "$result" | jq -e '.id' > /dev/null 2>&1; then
        echo "✅ $title ($year)"
        added=$((added + 1))
      else
        echo "❌ $title ($year) - $(echo "$result" | jq -r '.message // "failed"')"
      fi
    done

    echo ""
    echo "📊 Added: $added | Skipped: $skipped"
    if [ "$searchFlag" = "true" ] && [ "$added" -gt 0 ]; then
      echo "🔍 Search started for new movies"
    fi

    # Monitor the collection for future movies
    collections=$(arr_get "/collection")
    collection=$(echo "$collections" | jq --argjson tid "$collectionTmdbId" '.[] | select(.tmdbId == $tid)')

    if [ -n "$collection" ] && [ "$collection" != "null" ]; then
      collectionId=$(echo "$collection" | jq -r '.id')

      # Get full collection details and update with monitoring
      fullCollection=$(arr_get "/collection/$collectionId")
      updatePayload=$(echo "$fullCollection" | jq '. + {monitored: true, searchOnAdd: true}')

      updateResult=$(arr_put "/collection/$collectionId" "$updatePayload")

      if echo "$updateResult" | jq -e '.monitored' > /dev/null 2>&1; then
        echo "👁️ Collection monitored (new releases auto-added)"
      fi
    fi
    ;;

  remove)
    parse_args "$@"
    tmdbId="${POSITIONAL[0]:-}"
    [[ -n "$tmdbId" ]] || usage_error "falta el tmdbId" "remove <tmdbId> [--delete-files]"
    require_number "$tmdbId" "remove <tmdbId> [--delete-files]"
    deleteFiles="$DELETE_FILES"

    # Get movie ID from library
    movie=$(arr_get "/movie?tmdbId=$tmdbId")

    if [ "$movie" = "[]" ]; then
      echo "❌ Movie not found in library"
      exit 1
    fi

    movieId=$(echo "$movie" | jq -r '.[0].id')
    title=$(echo "$movie" | jq -r '.[0].title')
    year=$(echo "$movie" | jq -r '.[0].year')

    arr_delete "/movie/$movieId?deleteFiles=$deleteFiles" > /dev/null

    if [ "$deleteFiles" = "true" ]; then
      echo "🗑️ Removed: $title ($year) + deleted files"
    else
      echo "🗑️ Removed: $title ($year) (files kept)"
    fi
    ;;

  collection-info)
    tmdbId="${1:-}"
    [[ -n "$tmdbId" ]] || usage_error "falta el tmdbId de la colección" "collection-info <collectionTmdbId>"
    require_number "$tmdbId" "collection-info <collectionTmdbId>"
    arr_get "/collection" | jq --argjson tid "$tmdbId" '.[] | select(.tmdbId == $tid)'
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
    result=$(arr_post "/command" '{"name":"MissingMoviesSearch"}')
    echo "$result" | jq -r '"🔍 Started: \(.name) (command id \(.id), status \(.status))"'
    ;;

  search-id)
    movieId="${1:-}"
    [[ -n "$movieId" ]] || usage_error "falta el id interno de la película" "search-id <movieId>"
    require_number "$movieId" "search-id <movieId>"
    result=$(arr_post "/command" "{\"name\":\"MoviesSearch\",\"movieIds\":[$movieId]}")
    echo "$result" | jq -r --arg mid "$movieId" '"🔍 Started: \(.name) for movie \($mid) (command id \(.id), status \(.status))"'
    ;;

  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
