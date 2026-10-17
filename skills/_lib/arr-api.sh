#!/bin/bash
# Helper compartido de curl+auth para skills estilo Arr (Radarr/Sonarr).
# Debe hacerse source, no ejecutarse. El caller debe haber definido ya
# las variables API y AUTH antes de hacer source de esta librería.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: esta librería se carga con source, no se ejecuta" >&2
    exit 1
fi

ARR_MAX_TIME="${ARR_MAX_TIME:-25}"
ARR_CONNECT_TIMEOUT="${ARR_CONNECT_TIMEOUT:-10}"

# Entrecomilla un valor para una línea de configuración de curl.
_arr_quote() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '"%s"' "$s"
}

# Ejecuta curl con URL, cabecera de clave y cuerpo por stdin (--config -): la
# clave no aparece en los argumentos (ps). Uso: _arr_curl <MÉTODO> <ruta> <json|""> [opciones de curl...]
_arr_curl() {
    local method="$1" path="$2" body="$3" conf rc=0 xt=0
    shift 3
    if [[ $- == *x* ]]; then
        xt=1
        set +x
    fi
    conf="url = $(_arr_quote "$API$path")"$'\n'
    conf+="request = $(_arr_quote "$method")"$'\n'
    conf+="header = $(_arr_quote "$AUTH")"$'\n'
    if [[ -n "$body" ]]; then
        conf+='header = "Content-Type: application/json"'$'\n'
        conf+="data-raw = $(_arr_quote "$body")"$'\n'
    fi
    printf '%s' "$conf" | curl --connect-timeout "$ARR_CONNECT_TIMEOUT" --max-time "$ARR_MAX_TIME" "$@" --config - || rc=$?
    if [[ $xt -eq 1 ]]; then
        set -x
    fi
    return "$rc"
}

arr_get() {
    _arr_curl GET "$1" "" -s
}

arr_post() {
    _arr_curl POST "$1" "$2" -s
}

arr_put() {
    _arr_curl PUT "$1" "$2" -s
}

arr_delete() {
    _arr_curl DELETE "$1" "" -s
}

# Petición que comprueba el código HTTP (para escrituras y lecturas críticas).
# Uso: arr_call <MÉTODO> <ruta> [json]
# Deja el cuerpo en ARR_BODY y el código HTTP en ARR_CODE. Devuelve 0 si el
# código es 2xx; si no (o si no hay conexión) imprime "ERROR: ..." por stderr
# y devuelve 1. Llámala sin $(...) para conservar ARR_BODY y ARR_CODE.
arr_call() {
    local method="$1" path="$2" body="${3:-}" out msg
    ARR_BODY=""
    ARR_CODE="000"
    local rc=0
    out=$(_arr_curl "$method" "$path" "$body" -sS -w $'\n%{http_code}') || rc=$?
    if [[ $rc -ne 0 ]]; then
        if [[ $rc -eq 28 ]]; then
            echo "ERROR: timeout tras ${ARR_MAX_TIME}s llamando a $path" >&2
        else
            echo "ERROR: no se pudo conectar con el servicio ($method $path, curl rc $rc)" >&2
        fi
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
