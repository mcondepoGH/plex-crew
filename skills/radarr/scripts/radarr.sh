#!/bin/bash
set -euo pipefail

# Radarr API wrapper

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../../_lib/load-env.sh"
# shellcheck source=/dev/null
source "$_LOAD_ENV" || { echo "ERROR: no se encuentra load-env.sh" >&2; exit 1; }
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../../_lib/arr-api.sh" || { echo "ERROR: no se encuentra arr-api.sh" >&2; exit 1; }

# Load credentials from .env
load_service_credentials "radarr" "RADARR_URL" "RADARR_API_KEY"

# Optional quality profile (with default fallback)
DEFAULT_QUALITY_PROFILE="${RADARR_DEFAULT_QUALITY_PROFILE:-1}"

API="$RADARR_URL/api/v3"
AUTH="X-Api-Key: $RADARR_API_KEY"

cmd="${1:-}"
shift || true

case "$cmd" in
  search)
    query="${1:-}"
    if [ -z "$query" ]; then
      echo "ERROR: falta el texto de búsqueda" >&2
      echo "Uso: radarr.sh search <query>" >&2
      exit 1
    fi
    arr_call GET "/movie/lookup?term=$(printf '%s' "$query" | jq -sRr @uri)" || exit 1
    jq -r '
      to_entries | .[] |
      "\(.key + 1). \(.value.title) (\(.value.year)) - https://themoviedb.org/movie/\(.value.tmdbId)" +
      (if .value.collection.tmdbId then " [Collection: \(.value.collection.title)]" else "" end)
    ' <<<"$ARR_BODY"
    ;;

  status)
    arr_call GET "/system/status" || exit 1
    jq -r '"Radarr \(.version) - \(.instanceName // "Radarr") (\(.osName // "?"), branch \(.branch // "?"))"' <<<"$ARR_BODY"
    ;;
    
  search-json)
    query="${1:-}"
    curl -s -H "$AUTH" "$API/movie/lookup?term=$(printf '%s' "$query" | jq -sRr @uri)"
    ;;
    
  exists)
    tmdbId="${1:-}"
    result=$(curl -s -H "$AUTH" "$API/movie?tmdbId=$tmdbId")
    if [ "$result" = "[]" ]; then
      echo "not_found"
    else
      echo "exists"
      echo "$result" | jq -r '.[0] | "ID: \(.id), Title: \(.title), Has File: \(.hasFile)"'
    fi
    ;;
    
  config)
    echo "=== Root Folders ==="
    curl -s -H "$AUTH" "$API/rootfolder" | jq -r '.[] | "\(.id): \(.path)"'
    echo ""
    echo "=== Quality Profiles ==="
    curl -s -H "$AUTH" "$API/qualityprofile" | jq -r '.[] | "\(.id): \(.name)"'
    ;;
    
  add)
    tmdbId="${1:-}"
    qualityProfileId="${2:-}"
    searchFlag="true"
    
    # Check for --no-search flag
    for arg in "$@"; do
      if [ "$arg" = "--no-search" ]; then
        searchFlag="false"
      fi
    done
    
    # Get movie details from lookup
    movie=$(curl -s -H "$AUTH" "$API/movie/lookup/tmdb?tmdbId=$tmdbId")
    
    # Get default root folder
    rootFolder=$(curl -s -H "$AUTH" "$API/rootfolder" | jq -r '.[0].path')
    
    # Use provided quality profile ID, config default, or first available
    if [ -z "$qualityProfileId" ] || [ "$qualityProfileId" = "--no-search" ]; then
      if [ -n "$DEFAULT_QUALITY_PROFILE" ]; then
        qualityProfile="$DEFAULT_QUALITY_PROFILE"
      else
        qualityProfile=$(curl -s -H "$AUTH" "$API/qualityprofile" | jq -r '.[0].id')
      fi
    else
      qualityProfile="$qualityProfileId"
    fi
    
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
    
    result=$(curl -s -X POST -H "$AUTH" -H "Content-Type: application/json" -d "$addRequest" "$API/movie")
    
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
    collectionTmdbId="${1:-}"
    searchTerm="${2:-}"
    searchFlag="true"
    
    # Check for --no-search flag
    for arg in "$@"; do
      if [ "$arg" = "--no-search" ]; then
        searchFlag="false"
      fi
    done
    
    echo "🔍 Finding movies in collection..."
    
    # Try getting collection name from Radarr's collection list first
    collections=$(curl -s -H "$AUTH" "$API/collection")
    collection=$(echo "$collections" | jq --argjson tid "$collectionTmdbId" '.[] | select(.tmdbId == $tid)')
    
    if [ -n "$collection" ] && [ "$collection" != "null" ]; then
      collectionTitle=$(echo "$collection" | jq -r '.title')
      # Remove "Collection" suffix for better search
      searchTerm=$(echo "$collectionTitle" | sed 's/ Collection$//')
    fi
    
    # If no search term yet, use the provided one or fail
    if [ -z "$searchTerm" ]; then
      echo "❌ Could not determine collection name. Please provide search term."
      echo "Usage: add-collection <collectionTmdbId> <searchTerm> [--no-search]"
      exit 1
    fi
    
    # Search for movies
    allMovies=$(curl -s -H "$AUTH" "$API/movie/lookup?term=$(printf '%s' "$searchTerm" | jq -sRr @uri)")
    
    # Filter to only movies in our collection
    moviesToAdd=$(echo "$allMovies" | jq --argjson cid "$collectionTmdbId" '[.[] | select(.collection.tmdbId == $cid)]')
    movieCount=$(echo "$moviesToAdd" | jq 'length')
    
    if [ "$movieCount" = "0" ]; then
      echo "❌ No movies found for collection $collectionTmdbId"
      exit 1
    fi
    
    echo "📦 Found $movieCount movies in collection"
    
    # Get default root folder and quality profile
    rootFolder=$(curl -s -H "$AUTH" "$API/rootfolder" | jq -r '.[0].path')
    qualityProfile=$(curl -s -H "$AUTH" "$API/qualityprofile" | jq -r '.[0].id')
    
    # Add each movie
    added=0
    skipped=0
    for i in $(seq 0 $((movieCount - 1))); do
      movie=$(echo "$moviesToAdd" | jq ".[$i]")
      tmdbId=$(echo "$movie" | jq -r '.tmdbId')
      title=$(echo "$movie" | jq -r '.title')
      year=$(echo "$movie" | jq -r '.year')
      
      # Check if already exists
      existing=$(curl -s -H "$AUTH" "$API/movie?tmdbId=$tmdbId")
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
      
      result=$(curl -s -X POST -H "$AUTH" -H "Content-Type: application/json" -d "$addRequest" "$API/movie")
      
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
    collections=$(curl -s -H "$AUTH" "$API/collection")
    collection=$(echo "$collections" | jq --argjson tid "$collectionTmdbId" '.[] | select(.tmdbId == $tid)')
    
    if [ -n "$collection" ] && [ "$collection" != "null" ]; then
      collectionId=$(echo "$collection" | jq -r '.id')
      
      # Get full collection details and update with monitoring
      fullCollection=$(curl -s -H "$AUTH" "$API/collection/$collectionId")
      updatePayload=$(echo "$fullCollection" | jq '. + {monitored: true, searchOnAdd: true}')
      
      updateResult=$(curl -s -X PUT -H "$AUTH" -H "Content-Type: application/json" -d "$updatePayload" "$API/collection/$collectionId")
      
      if echo "$updateResult" | jq -e '.monitored' > /dev/null 2>&1; then
        echo "👁️ Collection monitored (new releases auto-added)"
      fi
    fi
    ;;
    
  remove)
    tmdbId="${1:-}"
    deleteFiles="false"
    if [ "${2:-}" = "--delete-files" ]; then
      deleteFiles="true"
    fi
    
    # Get movie ID from library
    movie=$(curl -s -H "$AUTH" "$API/movie?tmdbId=$tmdbId")
    
    if [ "$movie" = "[]" ]; then
      echo "❌ Movie not found in library"
      exit 1
    fi
    
    movieId=$(echo "$movie" | jq -r '.[0].id')
    title=$(echo "$movie" | jq -r '.[0].title')
    year=$(echo "$movie" | jq -r '.[0].year')
    hasFile=$(echo "$movie" | jq -r '.[0].hasFile')
    
    curl -s -X DELETE -H "$AUTH" "$API/movie/$movieId?deleteFiles=$deleteFiles" > /dev/null
    
    if [ "$deleteFiles" = "true" ]; then
      echo "🗑️ Removed: $title ($year) + deleted files"
    else
      echo "🗑️ Removed: $title ($year) (files kept)"
    fi
    ;;
    
  collection-info)
    tmdbId="${1:-}"
    curl -s -H "$AUTH" "$API/collection" | jq --argjson tid "$tmdbId" '.[] | select(.tmdbId == $tid)'
    ;;
    
  logs)
    # Solo lectura: GET /log (o /log/file con --files). Nunca imprime claves ni cabeceras.
    logUso="Uso: radarr.sh logs [N] [--level warn|error|info] [--grep texto] [--files]"
    logN=50; logLevel=""; logGrep=""; logFiles="false"
    while [ $# -gt 0 ]; do
      case "$1" in
        --level)
          [ $# -ge 2 ] || { echo "ERROR: --level requiere un valor" >&2; echo "$logUso" >&2; exit 1; }
          logLevel="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"; shift 2 ;;
        --grep)
          [ $# -ge 2 ] || { echo "ERROR: --grep requiere un texto" >&2; echo "$logUso" >&2; exit 1; }
          logGrep="$2"; shift 2 ;;
        --files) logFiles="true"; shift ;;
        -*) echo "ERROR: opción desconocida para logs: $1" >&2
            echo "$logUso" >&2; exit 1 ;;
        *)  if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 1000 ]; then
              logN="$1"; shift
            else
              echo "ERROR: N debe ser un entero entre 1 y 1000: $1" >&2
              echo "$logUso" >&2; exit 1
            fi ;;
      esac
    done
    case "$logLevel" in
      ""|trace|debug|info|warn|error|fatal) ;;
      *) echo "ERROR: nivel no válido: $logLevel (usa trace, debug, info, warn, error o fatal)" >&2; exit 1 ;;
    esac
    if [ "$logFiles" = "true" ]; then
      arr_call GET "/log/file" || exit 1
      jq -r 'if type == "array" then (.[] | "\(.lastWriteTime // "?")  \(.filename // "?")") else empty end' <<<"$ARR_BODY"
      exit 0
    fi
    # Con --grep se pide una página mayor y se filtra en cliente.
    logPage="$logN"
    if [ -n "$logGrep" ]; then logPage=$(( logN * 20 > 1000 ? 1000 : logN * 20 )); fi
    logQuery="page=1&pageSize=$logPage&sortKey=time&sortDirection=descending"
    if [ -n "$logLevel" ]; then logQuery+="&level=$logLevel"; fi
    arr_call GET "/log?$logQuery" || exit 1
    if ! jq -e '.records | type == "array"' >/dev/null 2>&1 <<<"$ARR_BODY"; then
      echo "ERROR: respuesta inesperada de /log (¿el servicio no expone el endpoint?)" >&2
      exit 1
    fi
    jq -r --arg g "$logGrep" --argjson n "$logN" '
      [ .records[]
        | select($g == "" or ((.message // "") | ascii_downcase | contains($g | ascii_downcase))
                 or ((.logger // "") | ascii_downcase | contains($g | ascii_downcase)))
      ] | .[:$n] | reverse | .[]
      | "\(.time // "?")  \((.level // "?") | ascii_upcase | .[0:5])  \(.logger // "?")  " +
        (((.message // "") | split("\n")[0] | gsub("(?i)(?<k>api_?key|token|passkey|password|secret)=[^&\\s]+"; "\(.k)=***")) | if length > 200 then .[0:200] + "..." else . end)
    ' <<<"$ARR_BODY"
    ;;

  ""|help|-h|--help)
    echo "Usage: radarr.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  search <query>              Search for movies"
    echo "  search-json <query>         Search (JSON output)"
    echo "  exists <tmdbId>             Check if movie is in library"
    echo "  config                      Show root folders & quality profiles"
    echo "  status                      Show radarr version/status"
    echo "  add <tmdbId> [profileId] [--no-search]  Add a movie (searches by default)"
    echo "  add-collection <tmdbId> [--no-search]  Add full collection"
    echo "  remove <tmdbId>             Remove a movie from library"
    echo "  collection-info <tmdbId>    Get collection details"
    echo "  logs [N] [--level warn|error|info] [--grep texto] [--files]"
    echo "                              Últimas N entradas del log (solo lectura, 50 por defecto)"
    ;;

  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    echo "Usa: radarr.sh help" >&2
    exit 1
    ;;
esac
