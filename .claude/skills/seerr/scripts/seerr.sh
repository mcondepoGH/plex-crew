#!/bin/bash
# Seerr (Overseerr-compatible) API helper script
# Usage: seerr.sh <command> [args...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../../_lib/load-env.sh"
# shellcheck source=/dev/null
source "$_LOAD_ENV" || { echo "ERROR: load-env.sh not found" >&2; exit 1; }

load_service_credentials "seerr" "SEERR_URL" "SEERR_API_KEY"

API="${SEERR_URL%/}/api/v1"
AUTH="X-Api-Key: $SEERR_API_KEY"

cmd="${1:-}"
shift || true

case "$cmd" in
  status)
    curl -s -H "$AUTH" "$API/status"
    ;;

  search)
    query="${1:?Usage: seerr.sh search \"Title\"}"
    curl -s -H "$AUTH" "$API/search?query=$(echo "$query" | jq -sRr @uri)" | jq -r '
      .results[] | "\(.mediaType | ascii_upcase) [\(.id)] \(.title // .name) (\(.releaseDate // .firstAirDate // "?" | .[0:4])) - mediaInfo: \(.mediaInfo.status // "none")"
    '
    ;;

  requests)
    filter="${1:-pending}"
    curl -s -H "$AUTH" "$API/request?filter=$filter&take=50" | jq -r '
      .results[] | "[\(.id)] \(.media.mediaType) tmdb:\(.media.tmdbId) status:\(.status) requestedBy:\(.requestedBy.displayName // .requestedBy.email // "?")"
    '
    ;;

  request-movie)
    tmdbId="${1:?Usage: seerr.sh request-movie <tmdbId>}"
    payload=$(jq -n --argjson id "$tmdbId" '{mediaType:"movie", mediaId:$id}')
    curl -s -X POST -H "$AUTH" -H "Content-Type: application/json" -d "$payload" "$API/request"
    ;;

  request-tv)
    tmdbId="${1:?Usage: seerr.sh request-tv <tmdbId> [seasons]}"
    seasons="${2:-}"
    if [[ -n "$seasons" ]]; then
      seasonsJson=$(echo "$seasons" | jq -R 'split(",") | map(tonumber)')
      payload=$(jq -n --argjson id "$tmdbId" --argjson s "$seasonsJson" '{mediaType:"tv", mediaId:$id, seasons:$s}')
    else
      payload=$(jq -n --argjson id "$tmdbId" '{mediaType:"tv", mediaId:$id, seasons:"all"}')
    fi
    curl -s -X POST -H "$AUTH" -H "Content-Type: application/json" -d "$payload" "$API/request"
    ;;

  logs)
    n="${1:-50}"
    level="${2:-}"
    url="$API/settings/logs?take=$n&skip=0"
    [[ -n "$level" ]] && url+="&filter=$level"
    curl -s -H "$AUTH" "$url" | jq -r '.results[] | "\(.timestamp) [\(.level)] \(.label // ""): \(.message)"'
    ;;

  *)
    echo "Usage: seerr.sh {status|search|requests|request-movie|request-tv|logs} [args...]" >&2
    exit 1
    ;;
esac
