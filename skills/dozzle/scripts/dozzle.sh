#!/bin/bash
# Envoltorio de solo lectura de Dozzle (visor de logs de contenedores Docker). Sin clave de API.
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../../_lib/load-env.sh"
# shellcheck source=/dev/null
source "$_LOAD_ENV" || { echo "ERROR: no se encuentra load-env.sh" >&2; exit 1; }

LOGS_USE="logs <contenedor> [--lines N] [--grep texto] [--since AAAA-MM-DDTHH:MM:SSZ] [--stderr|--stdout]"

usage() {
  cat <<'USAGE'
Uso: dozzle.sh <comando> [args]

Comandos (solo lectura, texto):
  status                    Versión de Dozzle y lista de contenedores con su estado
  containers                Igual que status
  logs <contenedor> [--lines N] [--grep texto] [--since FECHA] [--stderr|--stdout]
                            Últimas N líneas (100 por defecto, máximo 5000) del log del contenedor
                            (nombre o id); --grep filtra por texto sin distinguir mayúsculas;
                            --since solo trae desde esa fecha UTC (AAAA-MM-DDTHH:MM:SSZ);
                            --stderr / --stdout limitan el flujo (ambos por defecto).
                            Los secretos (tokens, apikey=, passwords) salen como ***
USAGE
}

# Error de uso: mensaje + línea de uso y salida con código 1
usage_error() {
  echo "ERROR: $1" >&2
  echo "Uso: dozzle.sh $2" >&2
  exit 1
}

require_number() {
  [[ "$1" =~ ^[0-9]+$ ]] || usage_error "'$1' no es un número válido" "$2"
}

cmd="${1:-}"
shift || true

case "$cmd" in
  ""|-h|--help|help)
    usage
    exit 0
    ;;
  status|containers|logs) ;;
  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac

# Validar argumentos antes de tocar la red o las credenciales
case "$cmd" in
  status|containers)
    [[ $# -eq 0 ]] || usage_error "$cmd no admite argumentos: $1" "$cmd"
    ;;
  logs)
    container=""
    n=100
    grep_text=""
    since=""
    want_out=false
    want_err=false
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --lines)
          [[ -n "${2:-}" ]] || usage_error "--lines requiere un valor" "$LOGS_USE"
          if [[ "$2" =~ ^[0-9]{1,4}$ ]] && (( 10#$2 >= 1 && 10#$2 <= 5000 )); then
            n=$((10#$2))
          else
            usage_error "--lines debe ser un entero entre 1 y 5000: $2" "$LOGS_USE"
          fi
          shift 2
          ;;
        --grep)
          [[ -n "${2:-}" ]] || usage_error "--grep requiere un texto" "$LOGS_USE"
          grep_text="$2"
          shift 2
          ;;
        --since)
          [[ -n "${2:-}" ]] || usage_error "--since requiere una fecha" "$LOGS_USE"
          [[ "$2" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] \
            || usage_error "--since no válido: $2 (usa AAAA-MM-DDTHH:MM:SSZ en UTC)" "$LOGS_USE"
          since="$2"
          shift 2
          ;;
        --stderr) want_err=true; shift ;;
        --stdout) want_out=true; shift ;;
        -*) usage_error "opción desconocida para logs: $1" "$LOGS_USE" ;;
        *)
          [[ -z "$container" ]] || usage_error "solo se admite un contenedor (sobra: $1)" "$LOGS_USE"
          [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] || usage_error "nombre o id de contenedor no válido: $1" "$LOGS_USE"
          container="$1"
          shift
          ;;
      esac
    done
    [[ -n "$container" ]] || usage_error "falta el contenedor" "$LOGS_USE"
    if [[ "$want_out" == false && "$want_err" == false ]]; then
      want_out=true
      want_err=true
    fi
    ;;
esac

load_service_credentials "dozzle" "DOZZLE_URL"

BASE="${DOZZLE_URL%/}"
MAX_TIME="${DOZZLE_MAX_TIME:-30}"

# Oculta secretos en texto de log (stdin -> stdout)
redact() {
  sed -E \
    -e 's/(Bearer|Basic)[[:space:]]+[A-Za-z0-9._~+\/=-]+/\1 ***/Ig' \
    -e 's/(Authorization|Cookie|Set-Cookie)([[:space:]]*:[[:space:]]*).*/\1\2***/I' \
    -e 's/(X-Api-Key|X-Plex-Token)([[:space:]]*:[[:space:]]*)[^[:space:]]+/\1\2***/Ig' \
    -e "s/((api[_-]?key|access[_-]?token|token|passkey|password|passwd|secret)[\"']?[[:space:]]*[=:][[:space:]]*[\"']?)[^&[:space:]\"',;]+/\1***/Ig"
}

# Lista de contenedores: lee el stream de eventos (SSE) hasta el primer containers-changed.
# Deja la versión en DZ_VERSION y un contenedor por línea (JSON) en DZ_CONTAINERS.
dz_containers() {
  local raw
  DZ_VERSION=""
  DZ_CONTAINERS=""
  set +o pipefail
  raw="$(curl -sS --connect-timeout 10 --max-time "${DOZZLE_EVENTS_TIME:-4}" -N "$BASE/api/events/stream" 2>/dev/null \
    | awk '/^event: /{ev=$2} /^data: /{ if (ev=="server-version") print "V" substr($0,7); else if (ev=="containers-changed") { print "C" substr($0,7); exit } }')"
  set -o pipefail
  if [[ -z "$raw" ]]; then
    echo "ERROR: no se pudo leer la lista de contenedores de Dozzle en $BASE (¿URL incorrecta, caído o con autenticación?)" >&2
    exit 1
  fi
  DZ_VERSION="$(sed -n 's/^V//p' <<<"$raw" | head -1 | jq -r '.version // "?"' 2>/dev/null || echo "?")"
  DZ_CONTAINERS="$(sed -n 's/^C//p' <<<"$raw" | head -1 | jq -c '.[]' 2>/dev/null || true)"
  if [[ -z "$DZ_CONTAINERS" ]]; then
    echo "ERROR: Dozzle no devolvió contenedores (respuesta inesperada)" >&2
    exit 1
  fi
}

cmd_status() {
  dz_containers
  jq -rs --arg v "$DZ_VERSION" '
    "Dozzle \($v) - \(length) contenedores, \(map(select(.state == "running")) | length) en ejecución",
    (sort_by(.name)[] | [.name, (.state // "?"), (.health // "-"), .id] | @tsv)
  ' <<<"$DZ_CONTAINERS" | awk -F'\t' 'NR == 1 { print; next } { printf "%-24s %-10s %-10s %s\n", $1, $2, $3, $4 }'
}

cmd_logs() {
  local match host id name body code out rc=0 q
  dz_containers
  match="$(jq -rs --arg c "$container" '
    ($c | ascii_downcase) as $q
    | ( [.[] | select((.name | ascii_downcase) == $q)]
        + [.[] | select(.id | startswith($c))]
        + [.[] | select((.name | ascii_downcase) | contains($q))] )
    | reduce .[] as $x ([]; if any(.[]; .id == $x.id) then . else . + [$x] end)
    | if length == 0 then empty else (.[0] | "\(.host)\t\(.id)\t\(.name)") end
  ' <<<"$DZ_CONTAINERS")"
  if [[ -z "$match" ]]; then
    echo "ERROR: contenedor no encontrado: $container (usa 'dozzle.sh containers')" >&2
    exit 1
  fi
  IFS=$'\t' read -r host id name <<<"$match"

  q="container=$host/$id"
  [[ "$want_out" == true ]] && q+="&stdout=1"
  [[ "$want_err" == true ]] && q+="&stderr=1"
  [[ -n "$since" ]] && q+="&from=$since"

  # POST de solo lectura: Dozzle expone así la descarga de logs (texto plano, un evento por línea)
  out="$(curl -sS --connect-timeout 10 --max-time "$MAX_TIME" -N -X POST -w $'\n%{http_code}' "$BASE/api/containers/logs?$q" 2>/dev/null)" || rc=$?
  if [[ $rc -ne 0 && $rc -ne 28 ]]; then
    echo "ERROR: no se pudo contactar con Dozzle en $BASE (curl rc $rc)" >&2
    exit 1
  fi
  if [[ $rc -eq 28 ]]; then
    echo "AVISO: respuesta truncada tras ${MAX_TIME}s (DOZZLE_MAX_TIME); usa --since para acotar" >&2
    code=200
    body="$out"
  else
    code="${out##*$'\n'}"
    body="${out%$'\n'*}"
  fi
  if [[ ! "$code" =~ ^2[0-9][0-9]$ ]]; then
    echo "ERROR: logs de $name respondió HTTP $code${body:+: $(head -c 200 <<<"$body" | head -1)}" >&2
    exit 1
  fi

  [[ -n "$body" ]] || return 0
  if [[ -n "$grep_text" ]]; then
    printf '%s\n' "${body%$'\n'}" | redact | { grep -iF -- "$grep_text" || true; } | tail -n "$n"
  else
    printf '%s\n' "${body%$'\n'}" | redact | tail -n "$n"
  fi
}

case "$cmd" in
  status|containers) cmd_status ;;
  logs) cmd_logs ;;
esac
