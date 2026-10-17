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
  setpref <clave> <valor>             Cambia UNA preferencia del servidor (modifica estado);
                                      clave [A-Za-z0-9]+, valor [A-Za-z0-9._-]+; los bool van como 1/0.
                                      Lee el valor actual, aplica, relee y muestra 'clave: antes -> después';
                                      sale con 1 si el valor final no coincide
  refresh <section-id>                Lanza un escaneo de la biblioteca (modifica estado);
                                      imprime lo que responda Plex y después una línea JSON fija
  emptytrash <section-id>             DESTRUCTIVO e irreversible: vacía la papelera de la biblioteca
                                      (PUT /library/sections/<id>/emptyTrash). Imprime el código HTTP;
                                      sale con 1 si no es 2xx. Exige doble confirmación y PLEX_CREW_CONFIRMED=1

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

# Única función de acceso a la API (GET; PUT si PLEX_METHOD=PUT). Uso: plex_get <ruta[?consulta]>
# Imprime el cuerpo tal cual; no comprueba el código HTTP (salvo PLEX_ONLY_CODE=1: imprime solo el código). Sale con 1 si curl falla.
# URL y cabeceras (con el token) viajan por stdin: no aparecen en ps.
plex_get() {
  command -v curl >/dev/null 2>&1 || { echo "ERROR: se necesita curl" >&2; exit 1; }

  local path="$1" sep="?" conf
  [[ "$path" == *"?"* ]] && sep="&"

  conf="globoff"$'\n'
  [[ "${PLEX_METHOD:-GET}" == "PUT" ]] && conf+='request = "PUT"'$'\n'
  conf+="url = $(curl_quote "${BASE_URL}${path}${sep}X-Plex-Token=${PLEX_TOKEN}")"$'\n'
  conf+='header = "Accept: application/json"'$'\n'
  conf+="header = $(curl_quote "X-Plex-Token: ${PLEX_TOKEN}")"$'\n'
  # Paginación: Plex solo la acepta como cabecera (PAGE_SIZE/PAGE_START los fijan library, recent y ondeck)
  [[ -n "${PAGE_SIZE:-}" ]] && conf+="header = $(curl_quote "X-Plex-Container-Size: ${PAGE_SIZE}")"$'\n'
  # Plex ignora el tamaño si falta el inicio: por defecto 0
  [[ -n "${PAGE_SIZE:-}" || -n "${PAGE_START:-}" ]] && conf+="header = $(curl_quote "X-Plex-Container-Start: ${PAGE_START:-0}")"$'\n'

  # Con PLEX_ONLY_CODE=1 descarta el cuerpo e imprime solo el código HTTP
  local extra=()
  [[ "${PLEX_ONLY_CODE:-0}" == "1" ]] && extra=(-o /dev/null -w '%{http_code}')

  if ! printf '%s' "$conf" | curl -sS --connect-timeout 10 --max-time 30 "${extra[@]}" --config - 2>/dev/null; then
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
    PAGE_SIZE="$LIMIT" PAGE_START="$OFFSET" plex_get "/library/sections/$sid/all"
    ;;

  recent)
    read_opts 0 "recent [--limit N]" "$@"
    PAGE_SIZE="${LIMIT:-20}" plex_get "/library/recentlyAdded"
    ;;

  ondeck)
    read_opts 0 "ondeck [--limit N]" "$@"
    PAGE_SIZE="${LIMIT:-10}" plex_get "/library/onDeck"
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

  setpref)
    U="setpref <clave> <valor>"
    key="${1:-}"
    val="${2:-}"
    [[ -n "$key" ]] || usage_error "falta clave" "$U"
    [[ -n "$val" ]] || usage_error "falta valor" "$U"
    [[ "$key" =~ ^[A-Za-z0-9]+$ ]] || usage_error "clave no válida (solo [A-Za-z0-9]+)" "$U"
    [[ "$val" =~ ^[A-Za-z0-9._-]+$ ]] || usage_error "valor no válido (solo [A-Za-z0-9._-]+)" "$U"
    command -v jq >/dev/null 2>&1 || { echo "ERROR: se necesita jq" >&2; exit 1; }

    # Valor de una preferencia (bool como true/false); vacío si no existe o la respuesta no es JSON
    pref_value() {
      plex_get "/:/prefs" | jq -r --arg k "$key" \
        '[.MediaContainer.Setting[]? | select(.id==$k)][0] | if .==null then "" else (.value | tostring) end' 2>/dev/null || true
    }

    # Estado no JSON de /:/prefs (p. ej. 401) o clave inexistente: no se toca nada
    before="$(plex_get "/:/prefs" | jq -r --arg k "$key" 'if ([.MediaContainer.Setting[]? | select(.id==$k)] | length) > 0 then "ok" else "" end' 2>/dev/null || true)"
    [[ "$before" == "ok" ]] || { echo "ERROR: la preferencia '$key' no existe o no se pudo leer (¿token de administrador?)" >&2; exit 1; }
    before="$(pref_value)"

    PLEX_METHOD=PUT plex_get "/:/prefs?${key}=${val}" >/dev/null

    after="$(pref_value)"
    echo "$key: $before -> $after"
    want="$val"
    [[ "$after" == "true" ]] && after_n="1" || after_n="$after"
    [[ "$after" == "false" ]] && after_n="0"
    [[ "$want" == "true" ]] && want="1"
    [[ "$want" == "false" ]] && want="0"
    [[ "$after_n" == "$want" ]] || { echo "ERROR: el valor final ('$after') no coincide con el pedido ('$val')" >&2; exit 1; }
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

  emptytrash)
    U="emptytrash <section-id>"
    sid="${1:-}"
    [[ -n "$sid" ]] || usage_error "falta section-id" "$U"
    need_int "$sid" "$U"
    code="$(PLEX_METHOD=PUT PLEX_ONLY_CODE=1 plex_get "/library/sections/$sid/emptyTrash")"
    echo "HTTP $code"
    [[ "$code" =~ ^2[0-9][0-9]$ ]] || { echo "ERROR: Plex rechazó el vaciado de la papelera de la sección $sid (HTTP $code)" >&2; exit 1; }
    ;;

  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
