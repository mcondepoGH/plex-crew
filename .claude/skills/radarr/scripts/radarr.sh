#!/bin/bash
set -euo pipefail

# Radarr API wrapper

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../../../../scripts/load-env.sh"
# shellcheck source=/dev/null
source "$_LOAD_ENV" || { echo "ERROR: load-env.sh not found. Copia .env.example a .env" >&2; exit 1; }

# Load credentials from .env
load_service_credentials "radarr" "RADARR_URL" "RADARR_API_KEY"

# Optional quality profile (with default fallback)
DEFAULT_QUALITY_PROFILE="${RADARR_DEFAULT_QUALITY_PROFILE:-1}"

API="$RADARR_URL/api/v3"
AUTH="X-Api-Key: $RADARR_API_KEY"

_ARR_API="$SCRIPT_DIR/../../../../scripts/arr-api.sh"
# shellcheck source=/dev/null
source "$_ARR_API" || { echo "ERROR: arr-api.sh not found" >&2; exit 1; }

cmd="$1"
shift || true

case "$cmd" in
  search)
    query="$1"
    arr_get "/movie/lookup?term=$(echo "$query" | jq -sRr @uri)" | jq -r '
      to_entries | .[] |
      "\(.key + 1). \(.value.title) (\(.value.year)) - https://themoviedb.org/movie/\(.value.tmdbId)" +
      (if .value.collection.tmdbId then " [Collection: \(.value.collection.title)]" else "" end)
    '
    ;;

  search-json)
    query="$1"
    arr_get "/movie/lookup?term=$(echo "$query" | jq -sRr @uri)"
    ;;

  exists)
    tmdbId="$1"
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
    tmdbId="$1"
    qualityProfileId="$2"
    searchFlag="true"
    
    # Check for --no-search flag
    for arg in "$@"; do
      if [ "$arg" = "--no-search" ]; then
        searchFlag="false"
      fi
    done
    
    # Get movie details from lookup
    movie=$(arr_get "/movie/lookup/tmdb?tmdbId=$tmdbId")

    # Get default root folder
    rootFolder=$(arr_get "/rootfolder" | jq -r '.[0].path')

    # Use provided quality profile ID, config default, or first available
    if [ -z "$qualityProfileId" ] || [ "$qualityProfileId" = "--no-search" ]; then
      if [ -n "$DEFAULT_QUALITY_PROFILE" ]; then
        qualityProfile="$DEFAULT_QUALITY_PROFILE"
      else
        qualityProfile=$(arr_get "/qualityprofile" | jq -r '.[0].id')
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
    collectionTmdbId="$1"
    searchTerm="$2"
    searchFlag="true"
    
    # Check for --no-search flag
    for arg in "$@"; do
      if [ "$arg" = "--no-search" ]; then
        searchFlag="false"
      fi
    done
    
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
      echo "Usage: add-collection <collectionTmdbId> <searchTerm> [--no-search]"
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
    
    # Get default root folder and quality profile
    rootFolder=$(arr_get "/rootfolder" | jq -r '.[0].path')
    qualityProfile=$(arr_get "/qualityprofile" | jq -r '.[0].id')
    
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
    tmdbId="$1"
    deleteFiles="false"
    if [ "$2" = "--delete-files" ]; then
      deleteFiles="true"
    fi
    
    # Get movie ID from library
    movie=$(arr_get "/movie?tmdbId=$tmdbId")

    if [ "$movie" = "[]" ]; then
      echo "❌ Movie not found in library"
      exit 1
    fi

    movieId=$(echo "$movie" | jq -r '.[0].id')
    title=$(echo "$movie" | jq -r '.[0].title')
    year=$(echo "$movie" | jq -r '.[0].year')
    hasFile=$(echo "$movie" | jq -r '.[0].hasFile')

    arr_delete "/movie/$movieId?deleteFiles=$deleteFiles" > /dev/null
    
    if [ "$deleteFiles" = "true" ]; then
      echo "🗑️ Removed: $title ($year) + deleted files"
    else
      echo "🗑️ Removed: $title ($year) (files kept)"
    fi
    ;;
    
  collection-info)
    tmdbId="$1"
    arr_get "/collection" | jq --argjson tid "$tmdbId" '.[] | select(.tmdbId == $tid)'
    ;;

  logs)
    n="${1:-50}"
    level="${2:-}"
    url="/log?pageSize=$n&sortKey=time&sortDirection=descending"
    [[ -n "$level" ]] && url+="&filterKey=level&filterValue=$level"
    arr_get "$url" | jq -r '.records[] | "\(.time) [\(.level)] \(.logger): \(.message // .exception // "")"'
    ;;

  search-all)
    result=$(arr_post "/command" '{"name":"MissingMoviesSearch"}')
    echo "$result" | jq -r '"🔍 Started: \(.name) (command id \(.id), status \(.status))"'
    ;;

  search-id)
    movieId="${1:?Usage: radarr.sh search-id <internal movieId>}"
    result=$(arr_post "/command" "{\"name\":\"MoviesSearch\",\"movieIds\":[$movieId]}")
    echo "$result" | jq -r --arg mid "$movieId" '"🔍 Started: \(.name) for movie \($mid) (command id \(.id), status \(.status))"'
    ;;

  *)
    echo "Usage: radarr.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  search <query>              Search for movies"
    echo "  search-json <query>         Search (JSON output)"
    echo "  exists <tmdbId>             Check if movie is in library"
    echo "  config                      Show root folders & quality profiles"
    echo "  add <tmdbId> [profileId] [--no-search]  Add a movie (searches by default)"
    echo "  add-collection <tmdbId> [--no-search]  Add full collection"
    echo "  remove <tmdbId>             Remove a movie from library"
    echo "  collection-info <tmdbId>    Get collection details"
    echo "  logs [n] [level]            Last n log lines, optional level filter (info/warn/error)"
    echo "  search-all                  Trigger search for all missing movies (whole library)"
    ;;
esac
