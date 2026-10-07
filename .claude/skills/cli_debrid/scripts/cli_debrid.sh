#!/bin/bash
# Envoltorio de la API web de cli_debrid (sesión con cookie, sin API key)
set -euo pipefail

# La cookie de sesión contiene credenciales: que solo la pueda leer el propietario
umask 077

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../../_lib/load-env.sh"
# shellcheck source=/dev/null
source "$_LOAD_ENV" || { echo "ERROR: no se encuentra load-env.sh. Copia .env.example a .env" >&2; exit 1; }

# Solo se exige el .env si alguna variable no está ya exportada
if [[ -z "${CLI_DEBRID_URL:-}" || -z "${CLI_DEBRID_USER:-}" || -z "${CLI_DEBRID_PASSWORD:-}" ]]; then
  load_env_file || exit 1
fi
validate_env_vars "CLI_DEBRID_URL" "CLI_DEBRID_USER" "CLI_DEBRID_PASSWORD" || exit 1

BASE="${CLI_DEBRID_URL%/}"
COOKIE_JAR="/tmp/.cli_debrid_cookie_$(echo -n "$BASE" | cksum | cut -d' ' -f1)"

usage() {
  cat <<'USAGE'
Uso: cli_debrid.sh <comando> [args]

Comandos (todos imprimen la respuesta de cli_debrid tal cual, en JSON):
  status                  Estado del programa: en marcha o parado
  dashboard               Estadísticas del panel con recuentos por estado
  queue                   Contenido de cada cola
  downloads               Descargas activas
  library-size            Tamaño de la biblioteca
  logs [n]                Últimas n líneas de log (100 por defecto)
  trigger-task <nombre>   Forzar de inmediato una tarea del planificador (escritura)
USAGE
}

# Error de uso: mensaje + línea de uso y salida con código 1
usage_error() {
  echo "ERROR: $1" >&2
  echo "Uso: cli_debrid.sh $2" >&2
  exit 1
}

require_number() {
  [[ "$1" =~ ^[0-9]+$ ]] || usage_error "'$1' no es un número válido" "$2"
}

# Código HTTP de una petición autenticada; sale con 1 si no hay conexión
http_code() {
  local code
  code=$(curl -s -b "$COOKIE_JAR" -o /dev/null -w "%{http_code}" "$@") || {
    echo "ERROR: no se pudo conectar con cli_debrid ($BASE)" >&2
    exit 1
  }
  printf '%s' "$code"
}

login() {
  local code
  rm -f "$COOKIE_JAR"
  curl -s -c "$COOKIE_JAR" -o /dev/null \
    --data-urlencode "username=$CLI_DEBRID_USER" \
    --data-urlencode "password=$CLI_DEBRID_PASSWORD" \
    "$BASE/auth/login" || {
    echo "ERROR: no se pudo conectar con cli_debrid ($BASE)" >&2
    exit 1
  }
  chmod 600 "$COOKIE_JAR" 2>/dev/null || true
  # El login no da un código fiable: se comprueba con un endpoint autenticado
  code=$(http_code "$BASE/program_operation/api/program_status")
  if [[ "$code" != "200" ]]; then
    rm -f "$COOKIE_JAR"
    echo "ERROR: el login en cli_debrid ha fallado (HTTP $code); revisa CLI_DEBRID_USER y CLI_DEBRID_PASSWORD" >&2
    exit 1
  fi
}

# Garantiza una sesión válida; reinicia sesión si la cookie falta o ha caducado
ensure_session() {
  local code
  if [[ ! -s "$COOKIE_JAR" ]]; then
    login
    return
  fi
  code=$(http_code "$BASE/program_operation/api/program_status")
  if [[ "$code" != "200" ]]; then
    login
  fi
}

# Imprime el cuerpo de la respuesta si el HTTP es 2xx; si no, ERROR y salida 1
request() {
  local method="$1" path="$2" out code
  shift 2
  out=$(curl -s -b "$COOKIE_JAR" -X "$method" -w $'\n%{http_code}' "$@" "$BASE$path") || {
    echo "ERROR: no se pudo conectar con cli_debrid ($method $path)" >&2
    exit 1
  }
  code="${out##*$'\n'}"
  if [[ ! "$code" =~ ^2[0-9][0-9]$ ]]; then
    echo "ERROR: $method $path respondió HTTP $code" >&2
    exit 1
  fi
  printf '%s\n' "${out%$'\n'*}"
}

api_get() {
  ensure_session
  request GET "$1"
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
    require_number "$n" "logs [n]"
    api_get "/logs/api/logs?lines=$n"
    ;;

  trigger-task)
    task="${1:-}"
    [[ -n "$task" ]] || usage_error "falta el nombre de la tarea" "trigger-task <nombre>"
    ensure_session
    request POST "/program_operation/trigger_task" --data-urlencode "task_name=$task"
    ;;

  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
