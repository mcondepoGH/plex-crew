#!/bin/bash
# cli_debrid API helper script (session-auth, no API key)
# Usage: cli_debrid.sh <command> [args...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../../_lib/load-env.sh"
# shellcheck source=/dev/null
source "$_LOAD_ENV" || { echo "ERROR: load-env.sh not found" >&2; exit 1; }

load_env_file || exit 1
validate_env_vars "CLI_DEBRID_URL" "CLI_DEBRID_USER" "CLI_DEBRID_PASSWORD"

BASE="${CLI_DEBRID_URL%/}"
COOKIE_JAR="/tmp/.cli_debrid_cookie_$(echo -n "$BASE" | md5sum | cut -d' ' -f1)"

login() {
  curl -s -c "$COOKIE_JAR" -o /dev/null \
    --data-urlencode "username=$CLI_DEBRID_USER" \
    --data-urlencode "password=$CLI_DEBRID_PASSWORD" \
    "$BASE/auth/login"
}

# Ensure we have a valid session; (re)login if the cookie is missing or stale.
ensure_session() {
  if [[ ! -s "$COOKIE_JAR" ]]; then
    login
    return
  fi
  # Probe a lightweight authenticated endpoint; a redirect to /auth/login means the session is dead.
  code=$(curl -s -b "$COOKIE_JAR" -o /dev/null -w "%{http_code}" "$BASE/program_operation/api/program_status")
  if [[ "$code" != "200" ]]; then
    login
  fi
}

api_get() {
  ensure_session
  curl -s -b "$COOKIE_JAR" "$BASE$1"
}

cmd="${1:-}"
shift || true

case "$cmd" in
  status)
    api_get "/program_operation/api/program_status"
    ;;

  dashboard)
    api_get "/statistics/api/index"
    ;;

  queue)
    api_get "/queues/api/queue_contents"
    ;;

  downloads)
    api_get "/statistics/api/active_downloads"
    ;;

  library-size)
    api_get "/statistics/api/library_size"
    ;;

  logs)
    n="${1:-100}"
    api_get "/logs/api/logs?lines=$n"
    ;;

  trigger-task)
    task="${1:?Usage: cli_debrid.sh trigger-task <task_name>}"
    ensure_session
    curl -s -b "$COOKIE_JAR" -X POST \
      --data-urlencode "task_name=$task" \
      "$BASE/program_operation/trigger_task"
    ;;

  *)
    echo "Usage: cli_debrid.sh {status|dashboard|queue|downloads|library-size|logs [n]|trigger-task <name>}" >&2
    exit 1
    ;;
esac
