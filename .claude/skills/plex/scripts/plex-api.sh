#!/bin/bash
set -euo pipefail

# Wrapper de la API de Plex Media Server

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../../_lib/load-env.sh"
# shellcheck source=/dev/null
source "$_LOAD_ENV" || { echo "ERROR: no se encuentra load-env.sh. Copia .env.example a .env" >&2; exit 1; }

# Credenciales desde el .env
load_service_credentials "plex" "PLEX_URL" "PLEX_TOKEN"

# Quita la barra final de la URL
PLEX_URL="${PLEX_URL%/}"

usage() {
  cat <<'USAGE'
Uso: plex-api.sh <comando> [args]

Todos los comandos devuelven JSON, salvo refresh (texto).

Comandos:
  info                                  Información y capacidades del servidor
  identity                              Identidad del servidor
  libraries                             Secciones de biblioteca (para conocer sus claves)
  library <section-id> [--limit N] [--offset O]
                                        Contenido de una sección
  recent [--limit N]                    Añadidos recientemente (20 por defecto)
  ondeck [--limit N]                    Lista "continuar viendo" (10 por defecto)
  search <texto> [--limit N]            Búsqueda en todas las bibliotecas
  metadata <rating-key>                 Metadatos de un elemento
  children <rating-key>                 Hijos de un elemento (p. ej. temporadas de una serie)
  sessions                              Reproducciones en curso
  clients                               Clientes conectados
  playlists                             Listas de reproducción
  accounts                              Cuentas de usuario (requiere ser administrador)
  prefs                                 Preferencias del servidor (requiere ser administrador)
  refresh <section-id>                  ESCRITURA: lanza un escaneo de la sección (texto)

Opciones cortas: -l equivale a --limit y -o a --offset.
Sin comando se muestra esta ayuda.
USAGE
}

# Error de uso: mensaje + línea de uso y salida con código 1
usage_error() {
  echo "ERROR: $1" >&2
  echo "Uso: plex-api.sh $2" >&2
  exit 1
}

require_number() {
  [[ "$1" =~ ^[0-9]+$ ]] || usage_error "'$1' no es un número válido ($3)" "$2"
}

# Comprueba que la opción $1 tiene valor; $2 es el número de argumentos restantes
# y $3 el siguiente argumento. Uso: need_value "$1" "$#" "${2:-}" "<uso>"
need_value() {
  if [[ "$2" -lt 2 || "$3" == -* ]]; then
    usage_error "falta el valor de $1" "$4"
  fi
}

unknown_option() {
  usage_error "opción desconocida: $1" "$2"
}

# Llamada autenticada a Plex. Imprime el cuerpo solo si el HTTP es 2xx;
# si no, avisa por stderr y sale con 1.
api_call() {
  local method="$1"
  local endpoint="$2"

  local resp code body
  resp=$(curl -sS -X "$method" \
      -H "Accept: application/json" \
      -H "X-Plex-Token: $PLEX_TOKEN" \
      -w $'\n%{http_code}' \
      "${PLEX_URL}${endpoint}") \
    || { echo "ERROR: no se pudo conectar con Plex" >&2; exit 1; }
  code="${resp##*$'\n'}"
  body="${resp%$'\n'*}"

  if [[ ! "$code" =~ ^2 ]]; then
    echo "ERROR: Plex respondió HTTP $code en $method $endpoint" >&2
    exit 1
  fi
  [[ -z "$body" ]] || printf '%s\n' "$body"
}

# Comando sin argumentos: $1 es el nombre, el resto lo recibido
no_args() {
  local name="$1"
  shift
  [[ $# -eq 0 ]] || unknown_option "$1" "$name"
}

cmd_library() {
  local u="library <section-id> [--limit N] [--offset O]"
  local section_id="${1:-}"
  [[ -n "$section_id" ]] || usage_error "falta el section-id" "$u"
  require_number "$section_id" "$u" "section-id"
  shift
  local limit="" offset=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --limit|-l)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--limit"
        limit="$2"; shift 2 ;;
      --offset|-o)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--offset"
        offset="$2"; shift 2 ;;
      *) unknown_option "$1" "$u" ;;
    esac
  done

  local query=""
  [[ -n "$limit" ]] && query+="&X-Plex-Container-Size=$limit"
  [[ -n "$offset" ]] && query+="&X-Plex-Container-Start=$offset"

  api_call GET "/library/sections/${section_id}/all${query:+?${query#&}}"
}

# recent y ondeck: $1 endpoint, $2 nombre, $3 límite por defecto, resto: opciones
cmd_listing() {
  local endpoint="$1" name="$2" limit="$3"
  shift 3
  local u="$name [--limit N]"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --limit|-l)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--limit"
        limit="$2"; shift 2 ;;
      *) unknown_option "$1" "$u" ;;
    esac
  done

  api_call GET "${endpoint}?X-Plex-Container-Size=$limit"
}

cmd_search() {
  local u="search <texto> [--limit N]"
  local query="${1:-}"
  [[ -n "$query" ]] || usage_error "falta el texto de búsqueda" "$u"
  shift
  local limit=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --limit|-l)
        need_value "$1" "$#" "${2:-}" "$u"; require_number "$2" "$u" "--limit"
        limit="$2"; shift 2 ;;
      *) unknown_option "$1" "$u" ;;
    esac
  done

  # Codifica el texto para la URL
  local encoded
  encoded=$(printf '%s' "$query" | jq -sRr @uri)

  local params="query=$encoded"
  [[ -n "$limit" ]] && params+="&limit=$limit"

  api_call GET "/search?$params"
}

# metadata y children: $1 nombre, $2 sufijo del endpoint, resto: argumentos
cmd_item() {
  local name="$1" suffix="$2"
  shift 2
  local u="$name <rating-key>"
  local rating_key="${1:-}"
  [[ -n "$rating_key" ]] || usage_error "falta el rating-key" "$u"
  require_number "$rating_key" "$u" "rating-key"
  [[ $# -le 1 ]] || unknown_option "$2" "$u"
  api_call GET "/library/metadata/${rating_key}${suffix}"
}

cmd_refresh() {
  local u="refresh <section-id>"
  local section_id="${1:-}"
  [[ -n "$section_id" ]] || usage_error "falta el section-id" "$u"
  require_number "$section_id" "$u" "section-id"
  [[ $# -le 1 ]] || unknown_option "$2" "$u"

  # api_call sale con 1 si Plex no responde 2xx
  api_call GET "/library/sections/${section_id}/refresh" > /dev/null
  echo "Escaneo de la sección $section_id solicitado a Plex (HTTP 2xx)"
}

# Despacho
cmd="${1:-}"
shift || true

case "$cmd" in
  "") usage; exit 0 ;;
  -h|--help|help) usage; exit 0 ;;
  info) no_args info "$@"; api_call GET "/" ;;
  identity) no_args identity "$@"; api_call GET "/identity" ;;
  libraries) no_args libraries "$@"; api_call GET "/library/sections" ;;
  library) cmd_library "$@" ;;
  recent) cmd_listing "/library/recentlyAdded" recent 20 "$@" ;;
  ondeck) cmd_listing "/library/onDeck" ondeck 10 "$@" ;;
  search) cmd_search "$@" ;;
  metadata) cmd_item metadata "" "$@" ;;
  children) cmd_item children "/children" "$@" ;;
  sessions) no_args sessions "$@"; api_call GET "/status/sessions" ;;
  clients) no_args clients "$@"; api_call GET "/clients" ;;
  playlists) no_args playlists "$@"; api_call GET "/playlists" ;;
  accounts) no_args accounts "$@"; api_call GET "/accounts" ;;
  prefs) no_args prefs "$@"; api_call GET "/:/prefs" ;;
  refresh) cmd_refresh "$@" ;;
  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
