#!/bin/bash
set -euo pipefail

# Sonarr API wrapper

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../../_lib/load-env.sh"
# shellcheck source=/dev/null
source "$_LOAD_ENV" || { echo "ERROR: load-env.sh not found. Copia .env.example a .env" >&2; exit 1; }

# Load credentials from .env
load_service_credentials "sonarr" "SONARR_URL" "SONARR_API_KEY"

# Optional quality profile (with default fallback)
DEFAULT_QUALITY_PROFILE="${SONARR_DEFAULT_QUALITY_PROFILE:-1}"

API="$SONARR_URL/api/v3"
AUTH="X-Api-Key: $SONARR_API_KEY"

_ARR_API="$SCRIPT_DIR/../../_lib/arr-api.sh"
# shellcheck source=/dev/null
source "$_ARR_API" || { echo "ERROR: arr-api.sh not found" >&2; exit 1; }

cmd="$1"
shift || true

case "$cmd" in
  search)
    query="$1"
    arr_get "/series/lookup?term=$(echo "$query" | jq -sRr @uri)" | jq -r '
      to_entries | .[:10] | .[] |
      "\(.key + 1). \(.value.title) (\(.value.year)) - https://thetvdb.com/dereferrer/series/\(.value.tvdbId)"
    '
    ;;

  search-json)
    query="$1"
    arr_get "/series/lookup?term=$(echo "$query" | jq -sRr @uri)"
    ;;

  exists)
    tvdbId="$1"
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
    tvdbId="$1"
    qualityProfileId="$2"
    searchFlag="true"
    
    # Check for --no-search flag
    for arg in "$@"; do
      if [ "$arg" = "--no-search" ]; then
        searchFlag="false"
      fi
    done
    
    # Get series details from lookup
    series=$(arr_get "/series/lookup?term=tvdb:$tvdbId" | jq '.[0]')
    
    if [ "$series" = "null" ] || [ -z "$series" ]; then
      echo "❌ Show not found with TVDB ID: $tvdbId"
      exit 1
    fi
    
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
    tvdbId="$1"
    deleteFiles="false"
    if [ "$2" = "--delete-files" ]; then
      deleteFiles="true"
    fi
    
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
    url="/log?pageSize=$n&sortKey=time&sortDirection=descending"
    [[ -n "$level" ]] && url+="&filterKey=level&filterValue=$level"
    arr_get "$url" | jq -r '.records[] | "\(.time) [\(.level)] \(.logger): \(.message // .exception // "")"'
    ;;

  search-all)
    result=$(arr_post "/command" '{"name":"MissingEpisodeSearch"}')
    echo "$result" | jq -r '"🔍 Started: \(.name) (command id \(.id), status \(.status))"'
    ;;

  search-id)
    seriesId="${1:?Usage: sonarr.sh search-id <internal seriesId>}"
    result=$(arr_post "/command" "{\"name\":\"SeriesSearch\",\"seriesId\":$seriesId}")
    echo "$result" | jq -r --arg sid "$seriesId" '"🔍 Started: \(.name) for series \($sid) (command id \(.id), status \(.status))"'
    ;;

  *)
    echo "Usage: sonarr.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  search <query>              Search for TV shows"
    echo "  search-json <query>         Search (JSON output)"
    echo "  exists <tvdbId>             Check if show is in library"
    echo "  config                      Show root folders & quality profiles"
    echo "  add <tvdbId> [profileId] [--no-search]  Add a show (searches by default)"
    echo "  remove <tvdbId> [--delete-files]  Remove a show from library"
    echo "  logs [n] [level]            Last n log lines, optional level filter (info/warn/error)"
    echo "  search-all                  Trigger search for all missing episodes (whole library)"
    ;;
esac
