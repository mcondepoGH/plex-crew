#!/bin/bash
set -euo pipefail

# Wrapper de la API v3 de Radarr: películas, colecciones, búsquedas y logs.

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../../_lib/load-env.sh"
# shellcheck source=/dev/null
source "$_LOAD_ENV" || { echo "ERROR: no se pudo cargar load-env.sh. Copia .env.example a .env" >&2; exit 1; }

# Carga las credenciales desde el .env
load_service_credentials "radarr" "RADARR_URL" "RADARR_API_KEY"

API="$RADARR_URL/api/v3"
AUTH="X-Api-Key: $RADARR_API_KEY"

_ARR_API="$SCRIPT_DIR/../../_lib/arr-api.sh"
# shellcheck source=/dev/null
source "$_ARR_API" || { echo "ERROR: no se pudo cargar arr-api.sh" >&2; exit 1; }

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
      (if .value.collection.tmdbId then " [Colección: \(.value.collection.title)]" else "" end)
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
      echo "$result" | jq -r '.[0] | "ID: \(.id), Título: \(.title), Con fichero: \(.hasFile)"'
    fi
    ;;

  config)
    echo "=== Carpetas raíz ==="
    arr_get "/rootfolder" | jq -r '.[] | "\(.id): \(.path)"'
    echo ""
    echo "=== Perfiles de calidad ==="
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

    # Detalles de la película desde el lookup
    arr_call GET "/movie/lookup/tmdb?tmdbId=$tmdbId" || exit 1
    movie="$ARR_BODY"

    # Carpeta raíz por defecto (la primera)
    arr_call GET "/rootfolder" || exit 1
    rootFolder=$(echo "$ARR_BODY" | jq -r '.[0].path // empty')
    [[ -n "$rootFolder" ]] || { echo "ERROR: Radarr no tiene carpetas raíz configuradas" >&2; exit 1; }

    qualityProfile="$qualityProfileId"

    # Petición de alta
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

    arr_call POST "/movie" "$addRequest" || exit 1

    if ! echo "$ARR_BODY" | jq -e '.id' > /dev/null 2>&1; then
      echo "ERROR: Radarr respondió HTTP $ARR_CODE pero sin id de película; no se confirma el alta" >&2
      exit 1
    fi
    echo "Añadida: $(echo "$ARR_BODY" | jq -r '.title') ($(echo "$ARR_BODY" | jq -r '.year'))"
    if [ "$searchFlag" = "true" ]; then
      echo "Búsqueda lanzada"
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

    echo "Buscando las películas de la colección..."

    # Primero intenta obtener el nombre de la colección desde la lista de Radarr
    arr_call GET "/collection" || exit 1
    collection=$(echo "$ARR_BODY" | jq --argjson tid "$collectionTmdbId" '.[] | select(.tmdbId == $tid)')

    if [ -n "$collection" ] && [ "$collection" != "null" ]; then
      collectionTitle=$(echo "$collection" | jq -r '.title')
      # Quita el sufijo "Collection" para buscar mejor
      searchTerm=$(echo "$collectionTitle" | sed 's/ Collection$//')
    fi

    # Sin texto de búsqueda no se puede continuar
    if [ -z "$searchTerm" ]; then
      echo "ERROR: no se pudo determinar el nombre de la colección; indica un texto de búsqueda" >&2
      echo "Uso: radarr.sh add-collection <collectionTmdbId> <profileId> <searchTerm> [--no-search]" >&2
      exit 1
    fi

    # Busca las películas
    arr_call GET "/movie/lookup?term=$(echo "$searchTerm" | jq -sRr @uri)" || exit 1
    allMovies="$ARR_BODY"

    # Se queda solo con las de nuestra colección
    moviesToAdd=$(echo "$allMovies" | jq --argjson cid "$collectionTmdbId" '[.[] | select(.collection.tmdbId == $cid)]')
    movieCount=$(echo "$moviesToAdd" | jq 'length')

    if [ "$movieCount" = "0" ]; then
      echo "ERROR: no se encontraron películas para la colección $collectionTmdbId" >&2
      exit 1
    fi

    echo "Encontradas $movieCount películas en la colección"

    # Carpeta raíz por defecto (la primera); el perfil es el indicado
    arr_call GET "/rootfolder" || exit 1
    rootFolder=$(echo "$ARR_BODY" | jq -r '.[0].path // empty')
    [[ -n "$rootFolder" ]] || { echo "ERROR: Radarr no tiene carpetas raíz configuradas" >&2; exit 1; }
    qualityProfile="$qualityProfileId"

    # Añade cada película
    added=0
    skipped=0
    failed=0
    for i in $(seq 0 $((movieCount - 1))); do
      movie=$(echo "$moviesToAdd" | jq ".[$i]")
      tmdbId=$(echo "$movie" | jq -r '.tmdbId')
      title=$(echo "$movie" | jq -r '.title')
      year=$(echo "$movie" | jq -r '.year')

      # Comprueba si ya está en la biblioteca
      if ! arr_call GET "/movie?tmdbId=$tmdbId"; then
        failed=$((failed + 1))
        continue
      fi
      if [ "$ARR_BODY" != "[]" ]; then
        echo "Omitida: $title ($year) - ya está en la biblioteca"
        skipped=$((skipped + 1))
        continue
      fi

      # Añade la película
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

      if arr_call POST "/movie" "$addRequest" && echo "$ARR_BODY" | jq -e '.id' > /dev/null 2>&1; then
        echo "Añadida: $title ($year)"
        added=$((added + 1))
      else
        echo "ERROR: no se pudo añadir $title ($year)" >&2
        failed=$((failed + 1))
      fi
    done

    echo ""
    echo "Resumen: añadidas $added | omitidas $skipped | fallidas $failed"
    if [ "$searchFlag" = "true" ] && [ "$added" -gt 0 ]; then
      echo "Búsqueda lanzada para las películas nuevas"
    fi

    # Deja la colección monitorizada para futuras entregas
    arr_call GET "/collection" || exit 1
    collection=$(echo "$ARR_BODY" | jq --argjson tid "$collectionTmdbId" '.[] | select(.tmdbId == $tid)')

    if [ -n "$collection" ] && [ "$collection" != "null" ]; then
      collectionId=$(echo "$collection" | jq -r '.id')

      # Obtiene la colección completa y la actualiza con monitorización
      if arr_call GET "/collection/$collectionId"; then
        updatePayload=$(echo "$ARR_BODY" | jq '. + {monitored: true, searchOnAdd: true}')
        if arr_call PUT "/collection/$collectionId" "$updatePayload"; then
          echo "Colección monitorizada (las nuevas entregas se añaden solas)"
        else
          echo "ERROR: no se pudo dejar la colección monitorizada" >&2
          failed=$((failed + 1))
        fi
      else
        failed=$((failed + 1))
      fi
    fi

    [ "$failed" -eq 0 ] || exit 1
    ;;

  remove)
    parse_args "$@"
    tmdbId="${POSITIONAL[0]:-}"
    [[ -n "$tmdbId" ]] || usage_error "falta el tmdbId" "remove <tmdbId> [--delete-files]"
    require_number "$tmdbId" "remove <tmdbId> [--delete-files]"
    deleteFiles="$DELETE_FILES"

    # Obtiene el id interno de la biblioteca
    arr_call GET "/movie?tmdbId=$tmdbId" || exit 1
    movie="$ARR_BODY"

    if [ "$movie" = "[]" ]; then
      echo "ERROR: la película no está en la biblioteca" >&2
      exit 1
    fi

    movieId=$(echo "$movie" | jq -r '.[0].id')
    title=$(echo "$movie" | jq -r '.[0].title')
    year=$(echo "$movie" | jq -r '.[0].year')

    arr_call DELETE "/movie/$movieId?deleteFiles=$deleteFiles" || exit 1

    if [ "$deleteFiles" = "true" ]; then
      echo "Quitada: $title ($year) + ficheros borrados"
    else
      echo "Quitada: $title ($year) (ficheros conservados)"
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
    arr_call POST "/command" '{"name":"MissingMoviesSearch"}' || exit 1
    echo "$ARR_BODY" | jq -r '"Lanzado: \(.name) (comando \(.id), estado \(.status))"'
    ;;

  search-id)
    movieId="${1:-}"
    [[ -n "$movieId" ]] || usage_error "falta el id interno de la película" "search-id <movieId>"
    require_number "$movieId" "search-id <movieId>"
    arr_call POST "/command" "{\"name\":\"MoviesSearch\",\"movieIds\":[$movieId]}" || exit 1
    echo "$ARR_BODY" | jq -r --arg mid "$movieId" '"Lanzado: \(.name) para la película \($mid) (comando \(.id), estado \(.status))"'
    ;;

  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
