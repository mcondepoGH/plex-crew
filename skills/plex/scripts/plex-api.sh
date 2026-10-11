#!/bin/bash
# Envoltorio de la API de Plex Media Server: explorar bibliotecas, buscar y ver reproducciones.
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../../_lib/load-env.sh" || { echo "ERROR: no se encuentra load-env.sh" >&2; exit 1; }
load_service_credentials "plex" "PLEX_URL" "PLEX_TOKEN"

BASE_URL="${PLEX_URL%/}"

usage() {
  cat <<'USAGE'
Uso: plex-api.sh <comando> [opciones]

Todos los comandos devuelven JSON (el cuerpo que responde Plex), salvo la nota de refresh.
Los id (section-id, rating-key) son números enteros.

Comandos:
  info                                Información del servidor
  identity                            Identidad del servidor (versión, machineIdentifier)
  libraries                           Bibliotecas (secciones)
  library <section-id> [--limit N] [--offset N]
                                      Contenido de una biblioteca (sin límite por defecto)
  recent [--limit N]                  Añadido recientemente (20 por defecto)
  ondeck [--limit N]                  Continuar viendo (10 por defecto)
  search <texto> [--limit N]          Búsqueda global
  metadata <rating-key>               Metadatos de un elemento
  children <rating-key>               Hijos de un elemento (temporadas, episodios, pistas)
  sessions                            Reproducciones en curso
  clients                             Clientes conectados
  playlists                           Listas de reproducción
  accounts                            Cuentas de usuario (token de administrador)
  prefs                               Preferencias del servidor (token de administrador)
  refresh <section-id>                Lanza un escaneo de la biblioteca (modifica estado);
                                      imprime lo que responda Plex y después una línea JSON fija

Alias cortos: -l para --limit y -o para --offset.
USAGE
}

# Error de uso: mensaje + línea de uso, salida con código 1
usage_error() {
  echo "ERROR: $1" >&2
  echo "Uso: plex-api.sh $2" >&2
  exit 1
}

# Valida que $1 sea un entero no negativo; $2 es la sintaxis del comando
need_int() {
  [[ "$1" =~ ^[0-9]+$ ]] || usage_error "'$1' no es un número entero positivo" "$2"
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

# Única función de acceso a la API (siempre GET). Uso: plex_get <ruta[?consulta]>
# Imprime el cuerpo tal cual; no comprueba el código HTTP. Sale con 1 si curl falla.
# URL y cabeceras (con el token) viajan por stdin: no aparecen en ps.
plex_get() {
  command -v curl >/dev/null 2>&1 || { echo "ERROR: se necesita curl" >&2; exit 1; }

  local path="$1" sep="?" conf
  [[ "$path" == *"?"* ]] && sep="&"

  conf="globoff"$'\n'
  conf+="url = $(curl_quote "${BASE_URL}${path}${sep}X-Plex-Token=${PLEX_TOKEN}")"$'\n'
  conf+='header = "Accept: application/json"'$'\n'
  conf+="header = $(curl_quote "X-Plex-Token: ${PLEX_TOKEN}")"$'\n'

  if ! printf '%s' "$conf" | curl -sS --connect-timeout 10 --max-time 30 --config - 2>/dev/null; then
    echo "ERROR: no se pudo contactar con Plex en $BASE_URL" >&2
    exit 1
  fi
}

# Lee --limit/-l (y --offset/-o si $1 = 1) del resto de argumentos.
# Deja LIMIT y OFFSET (vacíos si no se dieron). Uso: read_opts <con_offset> <uso> <args...>
LIMIT=""
OFFSET=""
read_opts() {
  local with_offset="$1" use="$2"
  shift 2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --limit|-l)
        [[ -n "${2:-}" ]] || usage_error "falta el valor de $1" "$use"
        need_int "$2" "$use"
        LIMIT="$2"
        shift 2
        ;;
      --offset|-o)
        [[ "$with_offset" == "1" ]] || usage_error "opción desconocida: $1" "$use"
        [[ -n "${2:-}" ]] || usage_error "falta el valor de $1" "$use"
        need_int "$2" "$use"
        OFFSET="$2"
        shift 2
        ;;
      *)
        usage_error "opción desconocida: $1" "$use"
        ;;
    esac
  done
}

cmd="${1:-}"
shift || true

case "$cmd" in
  ""|-h|--help|help)
    usage
    exit 0
    ;;

  info)      plex_get "/" ;;
  identity)  plex_get "/identity" ;;
  libraries) plex_get "/library/sections" ;;
  sessions)  plex_get "/status/sessions" ;;
  clients)   plex_get "/clients" ;;
  playlists) plex_get "/playlists" ;;
  accounts)  plex_get "/accounts" ;;
  prefs)     plex_get "/:/prefs" ;;

  library)
    U="library <section-id> [--limit N] [--offset N]"
    sid="${1:-}"
    [[ -n "$sid" ]] || usage_error "falta section-id" "$U"
    shift
    need_int "$sid" "$U"
    read_opts 1 "$U" "$@"
    extra=""
    [[ -n "$LIMIT" ]] && extra+="&X-Plex-Container-Size=$LIMIT"
    [[ -n "$OFFSET" ]] && extra+="&X-Plex-Container-Start=$OFFSET"
    # Limitación conocida: el trozo va sin "?" y la paginación no funciona
    plex_get "/library/sections/$sid/all$extra"
    ;;

  recent)
    read_opts 0 "recent [--limit N]" "$@"
    plex_get "/library/recentlyAdded?X-Plex-Container-Size=${LIMIT:-20}"
    ;;

  ondeck)
    read_opts 0 "ondeck [--limit N]" "$@"
    plex_get "/library/onDeck?X-Plex-Container-Size=${LIMIT:-10}"
    ;;

  search)
    U="search <texto> [--limit N]"
    [[ $# -gt 0 ]] || usage_error "falta texto" "$U"
    text="$1"
    shift
    read_opts 0 "$U" "$@"
    command -v jq >/dev/null 2>&1 || { echo "ERROR: se necesita jq" >&2; exit 1; }
    query="$(printf '%s' "$text" | jq -sRr @uri)"
    path="/search?query=$query"
    [[ -n "$LIMIT" ]] && path+="&limit=$LIMIT"
    plex_get "$path"
    ;;

  metadata)
    U="metadata <rating-key>"
    key="${1:-}"
    [[ -n "$key" ]] || usage_error "falta rating-key" "$U"
    need_int "$key" "$U"
    plex_get "/library/metadata/$key"
    ;;

  children)
    U="children <rating-key>"
    key="${1:-}"
    [[ -n "$key" ]] || usage_error "falta rating-key" "$U"
    need_int "$key" "$U"
    plex_get "/library/metadata/$key/children"
    ;;

  refresh)
    U="refresh <section-id>"
    sid="${1:-}"
    [[ -n "$sid" ]] || usage_error "falta section-id" "$U"
    need_int "$sid" "$U"
    plex_get "/library/sections/$sid/refresh"
    # Limitación conocida: esta línea sale siempre, sin comprobar la respuesta de Plex
    echo '{"status": "ok", "message": "Library refresh initiated"}'
    ;;

  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
