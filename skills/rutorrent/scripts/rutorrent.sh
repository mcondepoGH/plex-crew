#!/bin/bash
# Envoltorio de la API web de ruTorrent (plugin httprpc, addtorrent, create, _task).
# Autenticación opcional: basic auth de nginx solo si hay RUTORRENT_USER. Las credenciales se
# pasan a curl por stdin (-K -), nunca en argv ni en la salida. Sin usuario no se envía auth.
# No usa `set -e`: cada error se comprueba y se trata de forma explícita.
set -uo pipefail
umask 077

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../../_lib/load-env.sh"

# Binario de curl; RUTORRENT_CURL_BIN permite sustituirlo en las pruebas (sin red).
CURL="${RUTORRENT_CURL_BIN:-curl}"
MAX_TIME="${RUTORRENT_MAX_TIME:-30}"
BASE=""

usage() {
  cat <<'USAGE'
Uso: rutorrent.sh <comando> [args]

Lectura:
  list [--raw]                 Torrents: hash, nombre, tamaño, hecho, etiqueta (--raw = JSON de ruTorrent)
  info <HASH>                  Datos de un torrent (JSON)
  files <HASH>                 Ficheros de un torrent (JSON)
  diskspace                    Espacio en disco (plugin diskspace)
  tasks                        Tareas del plugin _task (creación de torrents)

Escritura segura:
  add <URL|FICHERO.torrent> [--label X] [--stopped]
  start <HASH>
  stop <HASH>
  recheck <HASH>
  label <HASH> <ETIQUETA>
  create <RUTA> [--tracker URL] [--private] [--comment TEXTO] [--allow-library]
                               Crea un .torrent (no empieza a sembrar: start_seeding=0)

Destructivos (el hook confirm-destructive exige doble confirmación y PLEX_CREW_CONFIRMED=1):
  remove <HASH>                Quita el torrent y conserva los datos
  remove-with-data <HASH> [--allow-library]
                               Quita el torrent Y BORRA sus datos (muestra antes info, files y ruta)

Siempre se opera por HASH (40 hex). Las rutas son las que ve el contenedor de ruTorrent.
Variables: RUTORRENT_URL (obligatoria); RUTORRENT_USER y RUTORRENT_PASSWORD (opcionales:
solo si ruTorrent tiene autenticación básica); RUTORRENT_ALLOWED_DIR (opcional: prefijo permitido para crear y borrar datos).
USAGE
}

die() { echo "ERROR: $1" >&2; exit 1; }

usage_error() {
  echo "ERROR: $1" >&2
  echo "Uso: rutorrent.sh $2" >&2
  exit 1
}

need_env() {
  [[ -n "$BASE" ]] && return 0
  # shellcheck source=/dev/null
  source "$_LOAD_ENV" || die "no se encuentra load-env.sh"
  if [[ -z "${RUTORRENT_URL:-}" ]]; then
    load_env_file || exit 1
  fi
  validate_env_vars "RUTORRENT_URL" || exit 1
  BASE="${RUTORRENT_URL%/}"
}

need_jq() { command -v jq >/dev/null 2>&1 || die "se necesita jq"; }

# Configuración de curl con la autenticación, por stdin. Escapa \ y " del formato de -K.
auth_config() {
  local u="${RUTORRENT_USER:-}" p="${RUTORRENT_PASSWORD:-}"
  u="${u//\\/\\\\}"; u="${u//\"/\\\"}"
  p="${p//\\/\\\\}"; p="${p//\"/\\\"}"
  printf 'user = "%s:%s"\n' "$u" "$p"
}

# rt_call RUTA [args de curl...]: imprime el cuerpo si HTTP 2xx; si no, ERROR y salida 1.
# Con --data-urlencode o -F curl hace POST; sin ellos, GET.
rt_call() {
  local path="$1" out code rc
  shift
  need_env
  if [[ -n "${RUTORRENT_USER:-}" ]]; then
    out=$(auth_config | "$CURL" -sS --max-time "$MAX_TIME" -K - -w $'\n%{http_code}' "$@" "$BASE$path" 2>/dev/null)
  else
    out=$("$CURL" -sS --max-time "$MAX_TIME" -w $'\n%{http_code}' "$@" "$BASE$path" 2>/dev/null </dev/null)
  fi
  rc=$?
  if [[ $rc -ne 0 ]]; then
    if [[ $rc -eq 28 ]]; then
      die "tiempo de espera agotado con ruTorrent ($path)"
    fi
    die "no se pudo conectar con ruTorrent ($path)"
  fi
  code="${out##*$'\n'}"
  if [[ "$code" == "401" ]]; then
    die "ruTorrent respondió HTTP 401 en $path; ruTorrent exige autenticación: define RUTORRENT_USER y RUTORRENT_PASSWORD"
  fi
  if [[ ! "$code" =~ ^2[0-9][0-9]$ ]]; then
    die "$path respondió HTTP $code"
  fi
  out="${out%$'\n'*}"
  # Por si el servidor reflejara la contraseña, nunca se imprime tal cual.
  if [[ -n "${RUTORRENT_PASSWORD:-}" ]]; then
    out="${out//"$RUTORRENT_PASSWORD"/***}"
  fi
  printf '%s\n' "$out"
}

# rt_post RUTA campo=valor...: POST urlencoded
rt_post() {
  local path="$1" f args=()
  shift
  for f in "$@"; do args+=(--data-urlencode "$f"); done
  rt_call "$path" "${args[@]}"
}

# httprpc MODO [campo=valor...]
httprpc() {
  local mode="$1"
  shift
  rt_post /plugins/httprpc/action.php "mode=$mode" "$@"
}

# ---------- validaciones ----------

norm_hash() {
  local h="$1" usage="$2"
  [[ "$h" =~ ^[0-9A-Fa-f]{40}$ ]] || usage_error "'$h' no es un hash válido (40 caracteres hexadecimales)" "$usage"
  printf '%s' "${h^^}"
}

# Valida una ruta del contenedor. $1 ruta, $2 "1" si se permite la biblioteca.
# Imprime el motivo y devuelve 1 si no es válida.
check_path() {
  local p="$1" allow_lib="$2" low dir
  if [[ -z "$p" || "$p" != /* ]]; then
    echo "la ruta debe ser absoluta" >&2; return 1
  fi
  if [[ "$p" == *$'\n'* || "$p" == *$'\r'* ]]; then
    echo "la ruta contiene saltos de línea" >&2; return 1
  fi
  if [[ "/$p/" == *"/../"* || "/$p/" == *"/./"* ]]; then
    echo "la ruta no puede contener '.' ni '..'" >&2; return 1
  fi
  if [[ "/$p" == *"/.@"* ]]; then
    echo "la ruta toca una carpeta .@* (se ignoran)" >&2; return 1
  fi
  p="${p%/}"
  low="${p,,}"
  if [[ "$allow_lib" != "1" && ( "$low" == */movies* || "$low" == */shows* ) ]]; then
    echo "la ruta está en la biblioteca (movies/shows); usa --allow-library solo si el usuario lo ha pedido expresamente" >&2
    return 1
  fi
  if [[ -n "${RUTORRENT_ALLOWED_DIR:-}" ]]; then
    dir="${RUTORRENT_ALLOWED_DIR%/}"
    if [[ "$p" != "$dir" && "$p" != "$dir"/* ]]; then
      echo "la ruta queda fuera de RUTORRENT_ALLOWED_DIR ($dir)" >&2
      return 1
    fi
  fi
  return 0
}

# Ruta de guardado de un torrent (getsavepath). Defensivo: acepta cadena JSON, array,
# objeto con path/savepath o texto plano. Formato no verificado en vivo.
get_savepath() {
  local h="$1" body p
  body=$(httprpc getsavepath "hash=$h") || exit 1
  p=""
  if command -v jq >/dev/null 2>&1 && printf '%s' "$body" | jq -e . >/dev/null 2>&1; then
    p=$(printf '%s' "$body" | jq -r '
      if type=="string" then .
      elif type=="array" then (.[0] // "" | tostring)
      elif type=="object" then (.path // .savepath // .dir // "" | tostring)
      else "" end' 2>/dev/null)
  else
    p="$(printf '%s' "$body" | tr -d '\r\n')"
  fi
  printf '%s' "$p"
}

# Entrada de un torrent en mode=list (JSON). Defensivo: devuelve {} si no existe.
torrent_entry() {
  local h="$1" body
  need_jq
  body=$(httprpc list) || exit 1
  printf '%s' "$body" | jq -c --arg h "$h" '(.t // {})[$h] // {}' 2>/dev/null || echo '{}'
}

# ---------- comandos ----------

cmd_list() {
  local raw=0 body
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --raw) raw=1 ;;
      *) usage_error "opción desconocida: $1" "list [--raw]" ;;
    esac
    shift
  done
  body=$(httprpc list) || exit 1
  if [[ $raw -eq 1 ]]; then
    printf '%s\n' "$body"
    return 0
  fi
  need_jq
  # Índices de mode=list (confirmados en vivo): 4 nombre, 5 tamaño, 8 bytes hechos, 14 etiqueta (d.custom1), 25 ruta de guardado.
  printf '%s' "$body" | jq -r '
    (.t // {}) | to_entries[]
    | [.key, (.value[4] // ""), (.value[5] // 0), (.value[8] // 0), ((.value[14] // "") | tostring | @uri)]
    | @tsv' 2>/dev/null || die "no se pudo interpretar la respuesta de list (usa --raw)"
}

cmd_info() {
  local h
  [[ $# -ge 1 ]] || usage_error "falta el hash" "info <HASH>"
  h=$(norm_hash "$1" "info <HASH>") || exit 1
  torrent_entry "$h"
}

cmd_files() {
  local h
  [[ $# -ge 1 ]] || usage_error "falta el hash" "files <HASH>"
  h=$(norm_hash "$1" "files <HASH>") || exit 1
  httprpc fls "hash=$h"
}

cmd_add() {
  local src="" label="" stopped=0 args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --label)
        [[ $# -ge 2 ]] || usage_error "falta el valor de --label" "add <URL|FICHERO> [--label X] [--stopped]"
        label="$2"; shift ;;
      --stopped) stopped=1 ;;
      -*) usage_error "opción desconocida: $1" "add <URL|FICHERO> [--label X] [--stopped]" ;;
      *)
        [[ -z "$src" ]] || usage_error "solo se admite una URL o un fichero" "add <URL|FICHERO> [--label X] [--stopped]"
        src="$1" ;;
    esac
    shift
  done
  [[ -n "$src" ]] || usage_error "falta la URL o el fichero" "add <URL|FICHERO> [--label X] [--stopped]"
  if [[ "$src" =~ ^(https?|magnet): ]]; then
    args+=(--form-string "url=$src")
  else
    [[ -f "$src" ]] || die "no existe el fichero: $src"
    [[ "${src,,}" == *.torrent ]] || die "el fichero debe ser un .torrent: $src"
    args+=(-F "torrent_file[]=@$src")
  fi
  [[ -z "$label" ]] || args+=(--form-string "label=$label")
  [[ $stopped -eq 0 ]] || args+=(--form-string "torrents_start_stopped=1")
  args+=(--form-string "json=1")
  rt_call /php/addtorrent.php "${args[@]}"
}

cmd_simple_hash() { # cmd_simple_hash MODO NOMBRE
  local mode="$1" name="$2" h
  shift 2
  [[ $# -ge 1 ]] || usage_error "falta el hash" "$name <HASH>"
  h=$(norm_hash "$1" "$name <HASH>") || exit 1
  httprpc "$mode" "hash=$h"
}

cmd_label() {
  local h
  [[ $# -ge 2 ]] || usage_error "faltan argumentos" "label <HASH> <ETIQUETA>"
  h=$(norm_hash "$1" "label <HASH> <ETIQUETA>") || exit 1
  [[ "$2" != *$'\n'* && "$2" != *$'\r'* ]] || die "la etiqueta no puede tener saltos de línea"
  httprpc setlabel "hash=$h" "s=label" "v=$2"
}

cmd_create() {
  local path="" tracker="" private=0 comment="" allow_lib=0 reason
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tracker)
        [[ $# -ge 2 ]] || usage_error "falta el valor de --tracker" "create <RUTA> [--tracker URL] [--private] [--comment C]"
        tracker="$2"; shift ;;
      --comment)
        [[ $# -ge 2 ]] || usage_error "falta el valor de --comment" "create <RUTA> [--tracker URL] [--private] [--comment C]"
        comment="$2"; shift ;;
      --private) private=1 ;;
      --allow-library) allow_lib=1 ;;
      -*) usage_error "opción desconocida: $1" "create <RUTA> [--tracker URL] [--private] [--comment C]" ;;
      *)
        [[ -z "$path" ]] || usage_error "solo se admite una ruta" "create <RUTA> ..."
        path="$1" ;;
    esac
    shift
  done
  [[ -n "$path" ]] || usage_error "falta la ruta" "create <RUTA> [--tracker URL] [--private] [--comment C]"
  reason=$(check_path "$path" "$allow_lib" 2>&1) || die "ruta rechazada: $reason"
  rt_post /plugins/create/action.php \
    "cmd=create" "path_edit=${path%/}" "trackers=$tracker" "comment=$comment" \
    "start_seeding=0" "private=$private"
}

cmd_remove() {
  local h
  [[ $# -ge 1 ]] || usage_error "falta el hash" "remove <HASH>"
  h=$(norm_hash "$1" "remove <HASH>") || exit 1
  httprpc remove "hash=$h"
}

cmd_remove_with_data() {
  local h="" allow_lib=0 sp reason
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --allow-library) allow_lib=1 ;;
      -*) usage_error "opción desconocida: $1" "remove-with-data <HASH> [--allow-library]" ;;
      *)
        [[ -z "$h" ]] || usage_error "solo se admite un hash" "remove-with-data <HASH> [--allow-library]"
        h="$1" ;;
    esac
    shift
  done
  [[ -n "$h" ]] || usage_error "falta el hash" "remove-with-data <HASH> [--allow-library]"
  h=$(norm_hash "$h" "remove-with-data <HASH> [--allow-library]") || exit 1
  echo "== info ==" >&2
  torrent_entry "$h" >&2
  echo "== files ==" >&2
  httprpc fls "hash=$h" >&2 || exit 1
  sp=$(get_savepath "$h") || exit 1
  echo "== ruta de guardado ==" >&2
  echo "$sp" >&2
  [[ -n "$sp" ]] || die "no se pudo determinar la ruta de guardado; no se borra nada"
  reason=$(check_path "$sp" "$allow_lib" 2>&1) || die "borrado rechazado: $reason"
  httprpc removewithdata "hash=$h"
}

cmd="${1:-}"
shift || true

case "$cmd" in
  "" | -h | --help | help) usage; exit 0 ;;
  list) cmd_list "$@" ;;
  info) cmd_info "$@" ;;
  files) cmd_files "$@" ;;
  diskspace) rt_call /plugins/diskspace/action.php ;;
  tasks) rt_post /plugins/_task/action.php "cmd=list" ;;
  add) cmd_add "$@" ;;
  start) cmd_simple_hash start start "$@" ;;
  stop) cmd_simple_hash stop stop "$@" ;;
  recheck) cmd_simple_hash recheck recheck "$@" ;;
  label) cmd_label "$@" ;;
  create) cmd_create "$@" ;;
  remove) cmd_remove "$@" ;;
  remove-with-data) cmd_remove_with_data "$@" ;;
  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
