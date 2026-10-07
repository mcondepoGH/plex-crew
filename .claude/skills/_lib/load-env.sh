#!/bin/bash
# Loader de credenciales compartido por todas las skills. Debe hacerse source, no ejecutarse.
# Fichero de entorno: $HOMELAB_ENV si existe; si no, <raíz-repo>/.env

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: esta librería se carga con source, no se ejecuta" >&2
    exit 1
fi

_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

load_env_file() {
    local env_file="${1:-${HOMELAB_ENV:-$_REPO_ROOT/.env}}"

    if [[ ! -f "$env_file" ]]; then
        echo "ERROR: $env_file no existe" >&2
        echo "Copia .env.example a .env y rellena las credenciales" >&2
        return 1
    fi

    set -a
    # shellcheck source=/dev/null
    source "$env_file"
    set +a
}

validate_env_vars() {
    local missing=()
    for var in "$@"; do
        [[ -z "${!var:-}" ]] && missing+=("$var")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: faltan variables en el .env: ${missing[*]}" >&2
        return 1
    fi
}

load_service_credentials() {
    local url_var="$2"
    local key_var="$3"

    if [[ -z "${!url_var:-}" ]] || [[ -z "${!key_var:-}" ]]; then
        load_env_file || return 1
    fi

    validate_env_vars "$url_var" "$key_var"
}
