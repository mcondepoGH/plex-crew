#!/bin/bash
# Envoltorio de la API de Agregarr (gestor de colecciones de Plex)
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOAD_ENV="$SCRIPT_DIR/../../_lib/load-env.sh"
# shellcheck source=/dev/null
source "$_LOAD_ENV" || { echo "ERROR: no se encuentra load-env.sh" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Uso: agregarr.sh <comando> [args]

Comandos (los marcados JSON devuelven JSON; el resto, texto):
  status                       Versión de Agregarr y comprobación de la clave de API (texto)
  collections [--json]         Colecciones configuradas: id, nombre, origen, tipo de medio (texto; JSON con --json)
  sync-status                  Estado de la sincronización de colecciones en curso o la última (texto)
  jobs                         Tareas programadas y su próxima ejecución (texto)
  logs [n] [nivel]             Últimas n entradas del log (50 por defecto);
                               nivel: debug/info/warn/error (texto)
  sync                         Lanzar la sincronización de todas las colecciones (escritura, texto)
  sync-collection <id>         Sincronizar una sola colección (escritura, texto)
  run-job <jobId>              Ejecutar una tarea programada (escritura, texto)
USAGE
}

# Error de uso: mensaje + línea de uso y salida con código 1
usage_error() {
  echo "ERROR: $1" >&2
  echo "Uso: agregarr.sh $2" >&2
  exit 1
}

require_number() {
  [[ "$1" =~ ^[0-9]+$ ]] || usage_error "'$1' no es un número válido" "$2"
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
  status|collections|sync-status|jobs|logs|sync|sync-collection|run-job) ;;
  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac

load_service_credentials "agregarr" "AGREGARR_URL" "AGREGARR_API_KEY"

API="${AGREGARR_URL%/}/api/v1"
AUTH="X-Api-Key: $AGREGARR_API_KEY"
ARR_MAX_TIME="${AGREGARR_MAX_TIME:-25}"

_ARR_API="$SCRIPT_DIR/../../_lib/arr-api.sh"
# shellcheck source=/dev/null
source "$_ARR_API" || { echo "ERROR: no se encuentra arr-api.sh" >&2; exit 1; }

case "$cmd" in
  status)
    arr_call GET "/status" || { echo "Agregarr: DESCONECTADO ($AGREGARR_URL)"; exit 1; }
    jq -r '"Agregarr \(.version // "?") - actualización disponible: \(.updateAvailable // false), reinicio requerido: \(.restartRequired // false)"' <<<"$ARR_BODY"
    # /status es público: se valida la clave con un endpoint autenticado
    arr_call GET "/collections" || { echo "Clave de API: NO VÁLIDA o sin permisos" >&2; exit 1; }
    jq -r '"Clave de API: OK - \((.collectionConfigs // []) | length) colecciones configuradas"' <<<"$ARR_BODY"
    ;;

  collections)
    arr_call GET "/collections" || exit 1
    if [[ "${1:-}" == "--json" ]]; then
      printf '%s\n' "$ARR_BODY"
    elif [[ "$(jq '(.collectionConfigs // []) | length' <<<"$ARR_BODY")" == "0" ]]; then
      echo "No hay colecciones configuradas"
    else
      jq -r '.collectionConfigs[] | "[\(.id)] \(.name // "?") - origen:\(.type // "?")\(if .subtype then "/" + .subtype else "" end) medio:\(.mediaType // "?") biblioteca:\(.libraryName // "?")"' <<<"$ARR_BODY"
    fi
    ;;

  sync-status)
    arr_call GET "/collections/sync/status" || exit 1
    jq -r '"En curso: \(.running)" +
      (if .running then " - \(.currentStage // "?") (\(.processedCollections // 0)/\(.totalCollections // 0), \(.progress // 0)%)" else "" end) +
      "\nÚltima sincronización global: \(.lastGlobalSyncAt // "nunca")" +
      "\nError global: \(.globalSyncError // "ninguno")" +
      "\nColecciones pendientes de sincronizar: \(.collectionsNeedingSync // "?")"' <<<"$ARR_BODY"
    ;;

  jobs)
    arr_call GET "/settings/jobs" || exit 1
    if [[ "$(jq 'length' <<<"$ARR_BODY")" == "0" ]]; then
      echo "No hay tareas programadas"
    else
      jq -r '.[] | "[\(.id)] \(.name) - próxima: \(.nextExecutionTime // "?") - en ejecución: \(.running // false)"' <<<"$ARR_BODY"
    fi
    ;;

  logs)
    n="${1:-50}"
    level="${2:-}"
    require_number "$n" "logs [n] [nivel]"
    if [[ -n "$level" ]]; then
      case "$level" in
        debug|info|warn|error) ;;
        *) usage_error "nivel no válido: $level (usa debug, info, warn o error)" "logs [n] [nivel]" ;;
      esac
    fi
    path="/settings/logs?take=$n&skip=0"
    [[ -n "$level" ]] && path+="&filter=$level"
    arr_call GET "$path" || exit 1
    jq -r '.[]? | "\(.timestamp) [\(.level)] \(.label // ""): \(.message)"' <<<"$ARR_BODY"
    ;;

  sync)
    arr_call POST "/collections/sync" || exit 1
    jq -r '"\(.status // "ok"): \(.message // "sincronización iniciada")"' <<<"$ARR_BODY"
    ;;

  sync-collection)
    id="${1:-}"
    [[ -n "$id" ]] || usage_error "falta el id de la colección" "sync-collection <id>"
    require_number "$id" "sync-collection <id>"
    arr_call POST "/collections/$id/sync" || exit 1
    jq -r '"\(.status // "ok"): \(.message // "sincronización iniciada")"' <<<"$ARR_BODY"
    ;;

  run-job)
    jobId="${1:-}"
    [[ -n "$jobId" ]] || usage_error "falta el id de la tarea" "run-job <jobId>"
    [[ "$jobId" =~ ^[A-Za-z0-9._-]+$ ]] || usage_error "'$jobId' no es un id de tarea válido" "run-job <jobId>"
    arr_call POST "/settings/jobs/$jobId/run" || exit 1
    jq -r '"Tarea \(.id // "?") (\(.name // "?")) - en ejecución: \(.running // false)"' <<<"$ARR_BODY"
    ;;
esac
