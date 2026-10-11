#!/bin/bash
# Envoltorio de solo lectura de la API de Tautulli: analítica de uso de Plex.
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../../_lib/load-env.sh" || { echo "ERROR: no se encuentra load-env.sh" >&2; exit 1; }
load_service_credentials "tautulli" "TAUTULLI_URL" "TAUTULLI_API_KEY"

BASE_URL="${TAUTULLI_URL%/}"

usage() {
  cat <<'USAGE'
Uso: tautulli-api.sh <comando> [opciones]

Todos los comandos son de solo lectura y devuelven JSON (el cuerpo completo de Tautulli).

Comandos:
  server-info                         Información del servidor
  activity [--details]                Streams en curso (--details se acepta sin efecto)
  history [--user U] [--section-id N] [--media-type T] [--days N] [--limit N] [--search TEXTO]
                                      Historial de reproducción (límite 25 por defecto)
  user-stats [--user U] [--sort-by COL] [--limit N] [--days N]
                                      Sin opciones lista los usuarios; con opciones, sus estadísticas
                                      (COL sugerida: plays, duration, last_seen)
  libraries                           Bibliotecas de Plex
  library-stats --section-id N        Estadísticas de una biblioteca
  popular [--section-id N] [--media-type T] [--days N] [--limit N]
                                      Contenido popular (30 días y 10 resultados por defecto)
  recent [--section-id N] [--media-type T] [--days N] [--limit N]
                                      Añadido recientemente (límite 25 por defecto)
  home-stats [--days N]               Estadísticas de portada (30 días por defecto)
  plays-by-stream [--days N]          Reproducciones por tipo de stream
  plays-by-platform [--days N]        Reproducciones por plataforma (top 10)
  plays-by-date [--days N]            Reproducciones por fecha
  plays-by-hour [--days N]            Reproducciones por hora del día
  plays-by-day [--days N]             Reproducciones por día de la semana
  concurrent-streams [--days N] [--peak]
                                      Streams simultáneos; --peak da el máximo mensual
  metadata (--rating-key N | --guid TEXTO)
                                      Metadatos de un elemento

Tipos de medio habituales: movie, episode, track.
USAGE
}

# Error de uso: mensaje + línea de uso, salida con código 1
usage_error() {
  echo "ERROR: $1" >&2
  echo "Uso: tautulli-api.sh $2" >&2
  exit 1
}

# Marca de tiempo Unix (segundos) de hace $1 días
days_ago() {
  date -d "$1 days ago" +%s
}

# Lee las opciones de un comando y las deja en el array asociativo OPT
# (clave = nombre sin guiones iniciales y con _ en lugar de -).
# Uso: parse_opts <uso> <opciones con valor> <flags> <numéricas> <numéricas >= 1> <args...>
# Las listas van separadas por comas.
declare -A OPT=()
OPT_COUNT=0
parse_opts() {
  local use="$1" with_value="$2" flags="$3" numeric="$4" positive="$5"
  shift 5
  local arg key
  while [[ $# -gt 0 ]]; do
    arg="$1"
    key="${arg#--}"
    key="${key//-/_}"
    if [[ ",$with_value," == *",$arg,"* ]]; then
      [[ -n "${2:-}" ]] || usage_error "falta el valor de $arg" "$use"
      if [[ ",$numeric," == *",$arg,"* ]]; then
        [[ "$2" =~ ^[0-9]+$ ]] || usage_error "'$2' no es un número entero positivo" "$use"
        if [[ ",$positive," == *",$arg,"* && "$2" -lt 1 ]]; then
          usage_error "'$2' no es un número entero positivo" "$use"
        fi
      fi
      OPT[$key]="$2"
      OPT_COUNT=$((OPT_COUNT + 1))
      shift 2
    elif [[ ",$flags," == *",$arg,"* ]]; then
      OPT[$key]="1"
      OPT_COUNT=$((OPT_COUNT + 1))
      shift
    else
      usage_error "opción desconocida: $arg" "$use"
    fi
  done
}

# Entrecomilla un valor para una línea de configuración de curl
curl_quote() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}

WORK_DIR=""
cleanup() {
  [[ -n "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
  return 0
}
trap cleanup EXIT

# Única función de acceso a la API. Uso: api_get <cmd> [clave=valor ...]
# Imprime el JSON devuelto; sale con 1 ante cualquier fallo.
# La configuración de curl (con la clave) viaja por stdin: no aparece en ps.
api_get() {
  command -v curl >/dev/null 2>&1 || { echo "ERROR: se necesita curl" >&2; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "ERROR: se necesita jq" >&2; exit 1; }

  local api_cmd="$1"
  shift
  local conf code pair result msg body

  conf="get"$'\n'
  conf+="url = $(curl_quote "$BASE_URL/api/v2")"$'\n'
  conf+="data-urlencode = $(curl_quote "apikey=$TAUTULLI_API_KEY")"$'\n'
  conf+="data-urlencode = $(curl_quote "cmd=$api_cmd")"$'\n'
  conf+='data-urlencode = "out_type=json"'$'\n'
  for pair in "$@"; do
    conf+="data-urlencode = $(curl_quote "$pair")"$'\n'
  done

  WORK_DIR="$(mktemp -d)"
  body="$WORK_DIR/body"

  if ! code="$(printf '%s' "$conf" | curl -s --connect-timeout 10 --max-time 30 \
      --config - -o "$body" -w '%{http_code}' 2>/dev/null)"; then
    echo "ERROR: no se pudo contactar con Tautulli en $BASE_URL" >&2
    exit 1
  fi

  if [[ ! "$code" =~ ^2[0-9][0-9]$ ]]; then
    echo "ERROR: Tautulli respondió HTTP $code: $(head -c 200 "$body" 2>/dev/null | tr '\n' ' ')" >&2
    exit 1
  fi

  if ! result="$(jq -r '.response.result // empty' "$body" 2>/dev/null)"; then
    echo "ERROR: Tautulli devolvió una respuesta que no es JSON" >&2
    exit 1
  fi
  if [[ "$result" != "success" ]]; then
    msg="$(jq -r '.response.message // "sin mensaje"' "$body" 2>/dev/null)" || msg="sin mensaje"
    echo "ERROR: Tautulli devolvió error: $msg" >&2
    exit 1
  fi
  jq . "$body"
}

cmd="${1:-}"
shift || true

case "$cmd" in
  ""|-h|--help|help)
    usage
    exit 0
    ;;

  server-info)
    parse_opts "server-info" "" "" "" "" "$@"
    api_get get_server_info
    ;;

  activity)
    parse_opts "activity [--details]" "" "--details" "" "" "$@"
    api_get get_activity
    ;;

  history)
    U="history [--user U] [--section-id N] [--media-type T] [--days N] [--limit N] [--search TEXTO]"
    parse_opts "$U" "--user,--section-id,--media-type,--days,--limit,--search" "" \
      "--section-id,--days,--limit" "--days,--limit" "$@"
    args=("length=${OPT[limit]:-25}")
    [[ -n "${OPT[user]:-}" ]] && args+=("user=${OPT[user]}")
    [[ -n "${OPT[section_id]:-}" ]] && args+=("section_id=${OPT[section_id]}")
    [[ -n "${OPT[media_type]:-}" ]] && args+=("media_type=${OPT[media_type]}")
    [[ -n "${OPT[days]:-}" ]] && args+=("start_date=$(days_ago "${OPT[days]}")")
    [[ -n "${OPT[search]:-}" ]] && args+=("search=${OPT[search]}")
    api_get get_history "${args[@]}"
    ;;

  user-stats)
    U="user-stats [--user U] [--sort-by COL] [--limit N] [--days N]"
    parse_opts "$U" "--user,--sort-by,--limit,--days" "" "--limit,--days" "--limit,--days" "$@"
    if [[ $OPT_COUNT -eq 0 ]]; then
      api_get get_users
    else
      args=()
      [[ -n "${OPT[user]:-}" ]] && args+=("user=${OPT[user]}")
      [[ -n "${OPT[sort_by]:-}" ]] && args+=("order_column=${OPT[sort_by]}")
      [[ -n "${OPT[limit]:-}" ]] && args+=("length=${OPT[limit]}")
      [[ -n "${OPT[days]:-}" ]] && args+=("start_date=$(days_ago "${OPT[days]}")")
      api_get get_user_stats "${args[@]}"
    fi
    ;;

  libraries)
    parse_opts "libraries" "" "" "" "" "$@"
    api_get get_libraries
    ;;

  library-stats)
    U="library-stats --section-id N"
    parse_opts "$U" "--section-id" "" "--section-id" "" "$@"
    [[ -n "${OPT[section_id]:-}" ]] || usage_error "falta --section-id" "$U"
    api_get get_library "section_id=${OPT[section_id]}"
    ;;

  popular)
    U="popular [--section-id N] [--media-type T] [--days N] [--limit N]"
    parse_opts "$U" "--section-id,--media-type,--days,--limit" "" \
      "--section-id,--days,--limit" "--days,--limit" "$@"
    # Limitación conocida: stat_id es siempre popular_movies, sea cual sea --media-type
    args=("stat_id=popular_movies" "time_range=${OPT[days]:-30}" "length=${OPT[limit]:-10}")
    [[ -n "${OPT[section_id]:-}" ]] && args+=("section_id=${OPT[section_id]}")
    [[ -n "${OPT[media_type]:-}" ]] && args+=("media_type=${OPT[media_type]}")
    api_get get_home_stats "${args[@]}"
    ;;

  recent)
    U="recent [--section-id N] [--media-type T] [--days N] [--limit N]"
    parse_opts "$U" "--section-id,--media-type,--days,--limit" "" \
      "--section-id,--days,--limit" "--days,--limit" "$@"
    args=("count=${OPT[limit]:-25}")
    [[ -n "${OPT[section_id]:-}" ]] && args+=("section_id=${OPT[section_id]}")
    [[ -n "${OPT[media_type]:-}" ]] && args+=("media_type=${OPT[media_type]}")
    [[ -n "${OPT[days]:-}" ]] && args+=("start=$(days_ago "${OPT[days]}")")
    api_get get_recently_added "${args[@]}"
    ;;

  home-stats)
    parse_opts "home-stats [--days N]" "--days" "" "--days" "--days" "$@"
    api_get get_home_stats "time_range=${OPT[days]:-30}"
    ;;

  plays-by-stream|plays-by-platform|plays-by-date|plays-by-hour|plays-by-day)
    parse_opts "$cmd [--days N]" "--days" "" "--days" "--days" "$@"
    case "$cmd" in
      plays-by-stream)   target="get_plays_by_stream_type" ;;
      plays-by-platform) target="get_plays_by_top_10_platforms" ;;
      plays-by-date)     target="get_plays_by_date" ;;
      plays-by-hour)     target="get_plays_by_hourofday" ;;
      *)                 target="get_plays_by_dayofweek" ;;
    esac
    api_get "$target" "time_range=${OPT[days]:-30}" "y_axis=plays"
    ;;

  concurrent-streams)
    parse_opts "concurrent-streams [--days N] [--peak]" "--days" "--peak" "--days" "--days" "$@"
    if [[ -n "${OPT[peak]:-}" ]]; then
      api_get get_plays_per_month "time_range=${OPT[days]:-30}" "y_axis=concurrent"
    else
      api_get get_concurrent_streams_by_stream_type "time_range=${OPT[days]:-30}"
    fi
    ;;

  metadata)
    U="metadata (--rating-key N | --guid TEXTO)"
    parse_opts "$U" "--rating-key,--guid" "" "--rating-key" "" "$@"
    if [[ -n "${OPT[rating_key]:-}" ]]; then
      api_get get_metadata "rating_key=${OPT[rating_key]}"
    elif [[ -n "${OPT[guid]:-}" ]]; then
      api_get get_metadata "guid=${OPT[guid]}"
    else
      usage_error "falta --rating-key o --guid" "$U"
    fi
    ;;

  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
