#!/bin/bash
# Prowlarr API helper script
# Usage: prowlarr-api.sh <command> [args...]

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../../_lib/load-env.sh"
# shellcheck source=/dev/null
source "$_LOAD_ENV" || { echo "ERROR: no se encuentra load-env.sh" >&2; exit 1; }

# Load credentials from .env
load_service_credentials "prowlarr" "PROWLARR_URL" "PROWLARR_API_KEY"

# Remove trailing slash
PROWLARR_URL="${PROWLARR_URL%/}"

# API call helper: imprime el cuerpo por stdout; si el HTTP no es 2xx o hay
# timeout, imprime "ERROR: ..." por stderr y devuelve 1.
# Timeout: PROWLARR_MAX_TIME (30 s por defecto; usa API_MAX_TIME_OVERRIDE interno)
api() {
    local method="$1"
    local endpoint="$2"
    shift 2

    local max_time="${API_MAX_TIME_OVERRIDE:-${PROWLARR_MAX_TIME:-30}}"
    local out rc=0 code body
    out=$(curl -sS --max-time "$max_time" -w $'\n%{http_code}' -X "$method" \
        -H "X-Api-Key: ${PROWLARR_API_KEY}" \
        -H "Content-Type: application/json" \
        "$@" \
        "${PROWLARR_URL}/api/v1${endpoint}") || rc=$?
    if [[ $rc -ne 0 ]]; then
        if [[ $rc -eq 28 ]]; then
            echo "ERROR: timeout tras ${max_time}s llamando a $endpoint" >&2
        else
            echo "ERROR: no se pudo conectar con Prowlarr ($method $endpoint, curl rc $rc)" >&2
        fi
        return 1
    fi
    code="${out##*$'\n'}"
    body="${out%$'\n'*}"
    API_CODE="$code"
    if [[ ! "$code" =~ ^2[0-9][0-9]$ ]]; then
        local msg
        msg=$(jq -r 'if type == "array" then (map(.errorMessage // .message // empty) | join("; "))
                     else (.message // .errorMessage // empty) end' <<<"$body" 2>/dev/null || true)
        echo "ERROR: $method $endpoint respondió HTTP $code${msg:+: $msg}" >&2
        return 1
    fi
    printf '%s\n' "$body"
}

usage() {
    cat <<EOF
Prowlarr API CLI

Usage: $(basename "$0") <command> [options]

Search Commands:
  search <query> [options]      Search across indexers
    --torrents                  Torrents only (indexerIds=-2)
    --usenet                    Usenet only (indexerIds=-1)
    --category <id>             Filter by category (2000=Movies, 5000=TV)
    --limit <n>                 Max results
  
  tv-search [options]           Search TV releases
    --tvdb <id>                 TVDB ID
    --season <n>                Season number
    --episode <n>               Episode number
  
  movie-search [options]        Search movie releases
    --imdb <id>                 IMDB ID (e.g., tt0111161)
    --tmdb <id>                 TMDB ID

Indexer Commands:
  indexers [--verbose]          List all indexers
  stats                         Indexer usage statistics
  test <id>                     Test specific indexer
  test-all                      Test all indexers
  enable <id>                   Enable an indexer
  disable <id>                  Disable an indexer
  delete <id>                   Delete an indexer

App Sync:
  apps                          List connected applications
  sync                          Sync indexers to apps (Sonarr/Radarr)

System:
  status                        System status
  health                        Health check

Examples:
  $(basename "$0") search "ubuntu 22.04"
  $(basename "$0") search "inception" --category 2000 --torrents
  $(basename "$0") tv-search --tvdb 71663 --season 1 --episode 1
  $(basename "$0") movie-search --imdb tt0111161
  $(basename "$0") stats
EOF
}

cmd_search() {
    local query=""
    local type="search"
    local indexer_ids=""
    local categories=""
    local limit=""
    
    # First positional arg is the query
    if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
        query="$1"
        shift
    fi
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --torrents) indexer_ids="-2"; shift ;;
            --usenet) indexer_ids="-1"; shift ;;
            --category|-c) categories="$2"; shift 2 ;;
            --limit|-l) limit="$2"; shift 2 ;;
            --type|-t) type="$2"; shift 2 ;;
            *) 
                if [[ -z "$query" ]]; then
                    query="$1"
                fi
                shift 
                ;;
        esac
    done
    
    if [[ -z "$query" ]]; then
        echo '{"error": "Query required"}' >&2
        exit 1
    fi
    
    local params="query=$(jq -rn --arg q "$query" '$q | @uri')"
    params+="&type=$type"
    [[ -n "$indexer_ids" ]] && params+="&indexerIds=$indexer_ids"
    [[ -n "$categories" ]] && params+="&categories=$categories"
    [[ -n "$limit" ]] && params+="&limit=$limit"
    
    api GET "/search?$params" | jq '[.[] | {
        title: .title,
        indexer: .indexer,
        size: (.size | . / 1048576 | floor | tostring + " MB"),
        seeders: .seeders,
        leechers: .leechers,
        age: .age,
        downloadUrl: .downloadUrl,
        infoUrl: .infoUrl
    }]'
}

cmd_tv_search() {
    local tvdb="" season="" episode=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tvdb) tvdb="$2"; shift 2 ;;
            --season|-s) season="$2"; shift 2 ;;
            --episode|-e) episode="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    local query=""
    [[ -n "$tvdb" ]] && query+="{TvdbId:$tvdb} "
    [[ -n "$season" ]] && query+="{Season:$season} "
    [[ -n "$episode" ]] && query+="{Episode:$episode}"
    
    if [[ -z "$query" ]]; then
        echo '{"error": "At least --tvdb required"}' >&2
        exit 1
    fi
    
    local encoded_query
    encoded_query=$(jq -rn --arg q "$query" '$q | @uri')
    
    api GET "/search?query=$encoded_query&type=tvsearch" | jq '[.[] | {
        title: .title,
        indexer: .indexer,
        size: (.size | . / 1048576 | floor | tostring + " MB"),
        seeders: .seeders,
        age: .age,
        downloadUrl: .downloadUrl
    }]'
}

cmd_movie_search() {
    local imdb="" tmdb=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --imdb) imdb="$2"; shift 2 ;;
            --tmdb) tmdb="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    local query=""
    [[ -n "$imdb" ]] && query+="{ImdbId:$imdb}"
    [[ -n "$tmdb" ]] && query+="{TmdbId:$tmdb}"
    
    if [[ -z "$query" ]]; then
        echo '{"error": "At least --imdb or --tmdb required"}' >&2
        exit 1
    fi
    
    local encoded_query
    encoded_query=$(jq -rn --arg q "$query" '$q | @uri')
    
    api GET "/search?query=$encoded_query&type=moviesearch" | jq '[.[] | {
        title: .title,
        indexer: .indexer,
        size: (.size | . / 1048576 | floor | tostring + " MB"),
        seeders: .seeders,
        age: .age,
        downloadUrl: .downloadUrl
    }]'
}

cmd_indexers() {
    local verbose=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose|-v) verbose=true; shift ;;
            *) shift ;;
        esac
    done
    
    if [[ "$verbose" == "true" ]]; then
        api GET "/indexer"
    else
        api GET "/indexer" | jq '[.[] | {
            id: .id,
            name: .name,
            protocol: .protocol,
            enabled: .enable,
            priority: .priority
        }]'
    fi
}

cmd_stats() {
    api GET "/indexerstats" | jq '.indexers | [.[] | {
        name: .indexerName,
        queries: .numberOfQueries,
        grabs: .numberOfGrabs,
        failures: .numberOfFailedQueries,
        avgResponseTime: .averageResponseTime
    }]'
}

cmd_test() {
    local id="${1:-}"
    [ -n "$id" ] || { echo "ERROR: falta id" >&2; exit 1; }
    local indexer
    indexer=$(api GET "/indexer/$id") || exit 1
    api POST "/indexer/test" -d "$indexer" > /dev/null || {
        echo "{\"status\": \"error\", \"indexer\": \"$id\", \"tested\": false}" >&2
        exit 1
    }
    echo '{"status": "ok", "indexer": "'"$id"'", "tested": true}'
}

cmd_test_all() {
    local result names failed
    # El test de todos los indexers es lento: timeout de 120 s por defecto
    result=$(API_MAX_TIME_OVERRIDE="${PROWLARR_TESTALL_MAX_TIME:-${PROWLARR_MAX_TIME:-120}}" api POST "/indexer/testall") || exit 1
    if ! jq -e 'type == "array"' >/dev/null 2>&1 <<<"$result"; then
        echo "ERROR: respuesta inesperada de Prowlarr en testall" >&2
        exit 1
    fi
    names=$(api GET "/indexer" | jq 'map({key: (.id|tostring), value: .name}) | from_entries') || names='{}'
    failed=$(jq --argjson names "$names" '[.[] | select(.isValid | not) | {id, name: ($names[(.id|tostring)] // "?"), errors: [.validationFailures[]?.errorMessage]}]' <<<"$result")
    if jq -e 'all(.[]; .isValid)' >/dev/null <<<"$result"; then
        echo "{\"status\": \"ok\", \"tested\": $(jq length <<<"$result"), \"failed\": 0}"
    else
        echo "ERROR: indexers con fallo:" >&2
        jq . <<<"$failed" >&2
        echo "{\"status\": \"error\", \"tested\": $(jq length <<<"$result"), \"failed\": $(jq length <<<"$failed")}"
        exit 1
    fi
}

cmd_enable() {
    local id="${1:-}"
    [ -n "$id" ] || { echo "ERROR: falta id" >&2; exit 1; }
    local indexer
    indexer=$(api GET "/indexer/$id" | jq '.enable = true') || exit 1
    api PUT "/indexer/$id" -d "$indexer" > /dev/null || exit 1
    echo '{"status": "ok", "indexer": "'"$id"'", "enabled": true}'
}

cmd_disable() {
    local id="${1:-}"
    [ -n "$id" ] || { echo "ERROR: falta id" >&2; exit 1; }
    local indexer
    indexer=$(api GET "/indexer/$id" | jq '.enable = false') || exit 1
    api PUT "/indexer/$id" -d "$indexer" > /dev/null || exit 1
    echo '{"status": "ok", "indexer": "'"$id"'", "enabled": false}'
}

cmd_delete() {
    local id="${1:-}"
    [ -n "$id" ] || { echo "ERROR: falta id" >&2; exit 1; }
    api DELETE "/indexer/$id" > /dev/null || exit 1
    echo '{"status": "ok", "indexer": "'"$id"'", "deleted": true}'
}

cmd_apps() {
    api GET "/applications" | jq '[.[] | {
        id: .id,
        name: .name,
        syncLevel: .syncLevel,
        implementation: .implementation
    }]'
}

cmd_sync() {
    api POST "/command" -d '{"name": "ApplicationIndexerSync"}'
    echo '{"status": "ok", "message": "Syncing indexers to applications"}'
}

cmd_status() {
    api GET "/system/status"
}

cmd_health() {
    api GET "/health" | jq '[.[] | {
        source: .source,
        type: .type,
        message: .message
    }]'
}

# Main dispatch
case "${1:-}" in
    search) shift; cmd_search "$@" ;;
    tv-search) shift; cmd_tv_search "$@" ;;
    movie-search) shift; cmd_movie_search "$@" ;;
    indexers) shift; cmd_indexers "$@" ;;
    stats) shift; cmd_stats "$@" ;;
    test) shift; cmd_test "$@" ;;
    test-all) shift; cmd_test_all "$@" ;;
    enable) shift; cmd_enable "$@" ;;
    disable) shift; cmd_disable "$@" ;;
    delete) shift; cmd_delete "$@" ;;
    apps) shift; cmd_apps "$@" ;;
    sync) shift; cmd_sync "$@" ;;
    status) shift; cmd_status "$@" ;;
    health) shift; cmd_health "$@" ;;
    -h|--help|help|"") usage ;;
    *) echo "Unknown command: $1" >&2; usage; exit 1 ;;
esac
