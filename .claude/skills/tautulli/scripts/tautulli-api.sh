#!/bin/bash
set -euo pipefail

# Wrapper de la API de Tautulli (analíticas de uso de Plex)

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../../_lib/load-env.sh"
# shellcheck source=/dev/null
source "$_LOAD_ENV" || { echo "ERROR: no se encuentra load-env.sh. Copia .env.example a .env" >&2; exit 1; }

# Credenciales desde el .env
load_service_credentials "tautulli" "TAUTULLI_URL" "TAUTULLI_API_KEY"

# Quita la barra final de la URL
TAUTULLI_URL="${TAUTULLI_URL%/}"

usage() {
  cat <<'USAGE'
Uso: tautulli-api.sh <comando> [args]

Todos los comandos son de lectura y devuelven JSON (sobre estándar de Tautulli
con response.result y response.data), salvo logs, que devuelve un array JSON
recortado con las primeras n entradas de response.data.

Comandos:
  server-info                         Versión e información del servidor
  activity                            Streams activos ahora mismo
  history [opciones]                  Historial de reproducción
    --user <usuario>                    Filtrar por usuario
    --section-id <id>                   Filtrar por sección de biblioteca
    --media-type <tipo>                 movie, episode, track...
    --days <n>                          Últimos n días
    --limit <n>                         Máximo de resultados (25 por defecto)
    --search <texto>                    Buscar en los títulos
  user-stats [opciones]               Sin opciones, lista de usuarios; con opciones, tabla de usuarios
    --user <texto>                      Buscar un usuario
    --sort-by <plays|duration|last_seen>  Orden descendente
    --limit <n>                         Máximo de resultados
  libraries                           Secciones de biblioteca
  library-stats --section-id <id>     Datos de una sección
  popular [opciones]                  Contenido más popular
    --media-type <movie|tv|music>       Tipo (movie por defecto; alias: episode y show para tv, track para music)
    --section-id <id>                   Filtrar por sección
    --days <n>                          Periodo (30 por defecto)
    --limit <n>                         Máximo de resultados (10 por defecto)
  recent [opciones]                   Añadidos recientemente
    --section-id <id>                   Filtrar por sección
    --media-type <tipo>                 movie, show, artist...
    --days <n>                          Solo los añadidos en los últimos n días
    --limit <n>                         Máximo de resultados (25 por defecto)
  home-stats [--days <n>]             Estadísticas del panel principal (30 días por defecto)
  plays-by-stream [--days <n>]        Reproducciones por tipo de stream
  plays-by-platform [--days <n>]      Reproducciones por plataforma (top 10)
  plays-by-date [--days <n>]          Reproducciones por fecha
  plays-by-hour [--days <n>]          Reproducciones por hora del día
  plays-by-day [--days <n>]           Reproducciones por día de la semana
  concurrent-streams [--days <n>] [--peak]
                                      Streams simultáneos por tipo; con --peak, solo la serie
                                      "Max. Concurrent Streams"
  metadata --rating-key <n> | --guid <guid>
                                      Metadatos de un elemento
  logs [--limit <n>] [--plex]         Log de Tautulli (25 líneas por defecto); con --plex, el del servidor Plex

Sin comando se muestra esta ayuda.
USAGE
}

# Error de uso: mensaje + línea de uso y salida con código 1
usage_error() {
  echo "ERROR: $1" >&2
  echo "Uso: tautulli-api.sh $2" >&2
  exit 1
}

require_number() {
  [[ "$1" =~ ^[0-9]+$ ]] || usage_error "'$1' no es un número válido ($3)" "$2"
}

# Comprueba que la opción $1 tiene valor; $2 es el número de argumentos restantes
# y $3 el siguiente argumento. Uso: need_value "$1" "$#" "${2:-}" "<uso>"
need_value() {
  if [[ "$2" -lt 2 || "$3" == --* ]]; then
    usage_error "falta el valor de $1" "$4"
  fi
}

# Opción desconocida o argumento sobrante
unknown_option() {
  usage_error "opción desconocida: $1" "$2"
}

# Llamada a la API. Imprime el cuerpo solo si el HTTP es 2xx y Tautulli no
# responde result=error (la API devuelve 200 con ese resultado en los fallos).
# Parámetros: comando seguido de pares clave=valor (se codifican en la URL).
api_call() {
  local cmd="$1"
  shift

  local args=(-sS -G --data-urlencode "apikey=${TAUTULLI_API_KEY}"
              --data-urlencode "cmd=${cmd}" --data-urlencode "out_type=json")
  local p
  for p in "$@"; do
    args+=(--data-urlencode "$p")
  done

  local resp code body
  resp=$(curl "${args[@]}" -w $'\n%{http_code}' "${TAUTULLI_URL}/api/v2") \
    || { echo "ERROR: no se pudo conectar con Tautulli" >&2; exit 1; }
  code="${resp##*$'\n'}"
  body="${resp%$'\n'*}"

  if [[ ! "$code" =~ ^2 ]]; then
    local detail
    detail=$(jq -r '.response.message // empty' 2>/dev/null <<<"$body" || true)
    echo "ERROR: Tautulli respondió HTTP $code en ${cmd}${detail:+: $detail}" >&2
    exit 1
  fi
  if ! jq -e '.response.result' >/dev/null 2>&1 <<<"$body"; then
    echo "ERROR: respuesta no válida de Tautulli (${cmd})" >&2
    exit 1
  fi
  if [[ "$(jq -r '.response.result' <<<"$body")" == "error" ]]; then
    echo "ERROR: Tautulli devolvió un error en ${cmd}: $(jq -r '.response.message // "sin detalle"' <<<"$body")" >&2
    exit 1
  fi
  printf '%s\n' "$body"
}

cmd_server_info() {
  [[ $# -eq 0 ]] || unknown_option "$1" "server-info"
  api_call "get_server_info"
}

cmd_activity() {
  [[ $# -eq 0 ]] || unknown_option "$1" "activity"
  api_call "get_activity"
}

cmd_history() {
  local u="history [--user <usuario>] [--section-id <id>] [--media-type <tipo>] [--days <n>] [--limit <n>] [--search <texto>]"
  local params=()
  local limit="25"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --user) need_value "$1" "$#" "${2:-}" "$u"; params+=("user=$2"); shift 2 ;;
      --section-id)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--section-id"
        params+=("section_id=$2"); shift 2 ;;
      --media-type) need_value "$1" "$#" "${2:-}" "$u"; params+=("media_type=$2"); shift 2 ;;
      --days)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--days"
        # La API espera start_date con formato AAAA-MM-DD
        params+=("start_date=$(date -d "$2 days ago" +%F)")
        shift 2 ;;
      --limit)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--limit"
        limit="$2"; shift 2 ;;
      --search) need_value "$1" "$#" "${2:-}" "$u"; params+=("search=$2"); shift 2 ;;
      *) unknown_option "$1" "$u" ;;
    esac
  done

  params+=("length=$limit")
  api_call "get_history" "${params[@]}"
}

cmd_user_stats() {
  local u="user-stats [--user <texto>] [--sort-by plays|duration|last_seen] [--limit <n>]"
  local params=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --user) need_value "$1" "$#" "${2:-}" "$u"; params+=("search=$2"); shift 2 ;;
      --sort-by)
        need_value "$1" "$#" "${2:-}" "$u"
        case "$2" in
          plays|duration|last_seen) params+=("order_column=$2" "order_dir=desc") ;;
          *) usage_error "valor no válido para --sort-by: '$2' (usa plays, duration o last_seen)" "$u" ;;
        esac
        shift 2 ;;
      --limit)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--limit"
        params+=("length=$2"); shift 2 ;;
      *) unknown_option "$1" "$u" ;;
    esac
  done

  if [[ ${#params[@]} -gt 0 ]]; then
    api_call "get_users_table" "${params[@]}"
  else
    api_call "get_users"
  fi
}

cmd_libraries() {
  [[ $# -eq 0 ]] || unknown_option "$1" "libraries"
  api_call "get_libraries"
}

cmd_library_stats() {
  local u="library-stats --section-id <id>"
  local section_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --section-id)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--section-id"
        section_id="$2"; shift 2 ;;
      *) unknown_option "$1" "$u" ;;
    esac
  done

  [[ -n "$section_id" ]] || usage_error "falta --section-id" "$u"
  api_call "get_library" "section_id=$section_id"
}

cmd_popular() {
  local u="popular [--media-type movie|tv|music] [--section-id <id>] [--days <n>] [--limit <n>]"
  local params=()
  local days="30"
  local limit="10"
  local stat_id="popular_movies"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --section-id)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--section-id"
        params+=("section_id=$2"); shift 2 ;;
      --media-type)
        need_value "$1" "$#" "${2:-}" "$u"
        case "$2" in
          movie) stat_id="popular_movies" ;;
          tv|show|episode) stat_id="popular_tv" ;;
          music|track) stat_id="popular_music" ;;
          *) usage_error "valor no válido para --media-type: '$2' (usa movie, tv o music)" "$u" ;;
        esac
        shift 2 ;;
      --days)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--days"
        days="$2"; shift 2 ;;
      --limit)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--limit"
        limit="$2"; shift 2 ;;
      *) unknown_option "$1" "$u" ;;
    esac
  done

  params+=("time_range=$days" "stats_count=$limit")
  api_call "get_home_stats" "stat_id=$stat_id" "${params[@]}"
}

cmd_recent() {
  local u="recent [--section-id <id>] [--media-type <tipo>] [--days <n>] [--limit <n>]"
  local params=()
  local limit="25"
  local days=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --section-id)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--section-id"
        params+=("section_id=$2"); shift 2 ;;
      --media-type) need_value "$1" "$#" "${2:-}" "$u"; params+=("media_type=$2"); shift 2 ;;
      --days)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--days"
        days="$2"; shift 2 ;;
      --limit)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--limit"
        limit="$2"; shift 2 ;;
      *) unknown_option "$1" "$u" ;;
    esac
  done

  params+=("count=$limit")

  local out
  out=$(api_call "get_recently_added" "${params[@]}")
  if [[ -n "$days" ]]; then
    # La API no filtra por fecha: se descartan aquí los anteriores al corte
    local cutoff
    cutoff=$(date -d "$days days ago" +%s)
    jq --argjson c "$cutoff" '.response.data.recently_added |= map(select((.added_at | tonumber) >= $c))' <<<"$out"
  else
    printf '%s\n' "$out"
  fi
}

# Comandos que solo aceptan --days (parámetros: nombre del comando, comando de la API)
days_only() {
  local name="$1" api_cmd="$2"
  shift 2
  local u="$name [--days <n>]"
  local days="30"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --days)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--days"
        days="$2"; shift 2 ;;
      *) unknown_option "$1" "$u" ;;
    esac
  done

  if [[ "$api_cmd" == "get_home_stats" ]]; then
    api_call "$api_cmd" "time_range=$days"
  else
    api_call "$api_cmd" "time_range=$days" "y_axis=plays"
  fi
}

cmd_concurrent_streams() {
  local u="concurrent-streams [--days <n>] [--peak]"
  local days="30"
  local peak=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --days)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--days"
        days="$2"; shift 2 ;;
      --peak) peak="1"; shift ;;
      *) unknown_option "$1" "$u" ;;
    esac
  done

  local out
  out=$(api_call "get_concurrent_streams_by_stream_type" "time_range=$days")
  if [[ -n "$peak" ]]; then
    jq '.response.data |= (.series |= map(select(.name == "Max. Concurrent Streams")))' <<<"$out"
  else
    printf '%s\n' "$out"
  fi
}

cmd_logs() {
  local u="logs [--limit <n>] [--plex]"
  local n="25"
  local plex=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --limit)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--limit"
        n="$2"; shift 2 ;;
      --plex) plex="1"; shift ;;
      *) unknown_option "$1" "$u" ;;
    esac
  done

  local out
  if [[ -n "$plex" ]]; then
    out=$(api_call "get_plex_log" "log_type=server")
  else
    out=$(api_call "get_logs")
  fi
  jq --argjson n "$n" '.response.data[0:$n]' <<<"$out"
}

cmd_metadata() {
  local u="metadata --rating-key <n> | --guid <guid>"
  local rating_key=""
  local guid=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --rating-key)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--rating-key"
        rating_key="$2"; shift 2 ;;
      --guid) need_value "$1" "$#" "${2:-}" "$u"; guid="$2"; shift 2 ;;
      *) unknown_option "$1" "$u" ;;
    esac
  done

  if [[ -n "$rating_key" ]]; then
    api_call "get_metadata" "rating_key=$rating_key"
  elif [[ -n "$guid" ]]; then
    api_call "get_metadata" "guid=$guid"
  else
    usage_error "falta --rating-key o --guid" "$u"
  fi
}

# Despacho
cmd="${1:-}"
shift || true

case "$cmd" in
  "") usage; exit 0 ;;
  -h|--help|help) usage; exit 0 ;;
  server-info) cmd_server_info "$@" ;;
  activity) cmd_activity "$@" ;;
  history) cmd_history "$@" ;;
  user-stats) cmd_user_stats "$@" ;;
  libraries) cmd_libraries "$@" ;;
  library-stats) cmd_library_stats "$@" ;;
  popular) cmd_popular "$@" ;;
  recent) cmd_recent "$@" ;;
  home-stats) days_only "home-stats" "get_home_stats" "$@" ;;
  plays-by-stream) days_only "plays-by-stream" "get_plays_by_stream_type" "$@" ;;
  plays-by-platform) days_only "plays-by-platform" "get_plays_by_top_10_platforms" "$@" ;;
  plays-by-date) days_only "plays-by-date" "get_plays_by_date" "$@" ;;
  plays-by-hour) days_only "plays-by-hour" "get_plays_by_hourofday" "$@" ;;
  plays-by-day) days_only "plays-by-day" "get_plays_by_dayofweek" "$@" ;;
  concurrent-streams) cmd_concurrent_streams "$@" ;;
  metadata) cmd_metadata "$@" ;;
  logs) cmd_logs "$@" ;;
  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
