#!/bin/bash
# Helper compartido de curl+auth para skills estilo Arr (Radarr/Sonarr).
# Debe hacerse source, no ejecutarse. El caller debe haber definido ya
# las variables API y AUTH antes de hacer source de esta librería.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: esta librería se carga con source, no se ejecuta" >&2
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
