#!/bin/bash
# Helper compartido de curl+auth para skills estilo Arr (Radarr/Sonarr).
# Debe hacerse source, no ejecutarse. El caller debe haber definido ya
# las variables API y AUTH antes de hacer source de esta librería.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: esta librería se carga con source, no se ejecuta" >&2
    exit 1
fi

arr_get() {
    curl -s -H "$AUTH" "$API$1"
}

arr_post() {
    curl -s -X POST -H "$AUTH" -H "Content-Type: application/json" -d "$2" "$API$1"
}

arr_put() {
    curl -s -X PUT -H "$AUTH" -H "Content-Type: application/json" -d "$2" "$API$1"
}

arr_delete() {
    curl -s -X DELETE -H "$AUTH" "$API$1"
}

# Petición que comprueba el código HTTP (para escrituras y lecturas críticas).
# Uso: arr_call <MÉTODO> <ruta> [json]
# Deja el cuerpo en ARR_BODY y el código HTTP en ARR_CODE. Devuelve 0 si el
# código es 2xx; si no (o si no hay conexión) imprime "ERROR: ..." por stderr
# y devuelve 1. Llámala sin $(...) para conservar ARR_BODY y ARR_CODE.
arr_call() {
    local method="$1" path="$2" body="${3:-}" out msg
    local args=(-s -w $'\n%{http_code}' -X "$method" -H "$AUTH")
    if [[ -n "$body" ]]; then
        args+=(-H "Content-Type: application/json" -d "$body")
    fi
    ARR_BODY=""
    ARR_CODE="000"
    if ! out=$(curl "${args[@]}" "$API$path"); then
        echo "ERROR: no se pudo conectar con el servicio ($method $path)" >&2
        return 1
    fi
    ARR_CODE="${out##*$'\n'}"
    ARR_BODY="${out%$'\n'*}"
    if [[ ! "$ARR_CODE" =~ ^2[0-9][0-9]$ ]]; then
        msg=$(jq -r 'if type == "array" then (.[0].errorMessage // .[0].message // empty)
                     else (.message // .errorMessage // empty) end' <<<"$ARR_BODY" 2>/dev/null || true)
        echo "ERROR: $method $path respondió HTTP $ARR_CODE${msg:+: $msg}" >&2
        return 1
    fi
}
