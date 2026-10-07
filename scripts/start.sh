#!/bin/bash
# Arranca Claude Code cargando el .env único del proyecto. Para uso fuera de Docker.
# Fichero de entorno: $HOMELAB_ENV si está definido; si no, <raíz-repo>/.env
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${HOMELAB_ENV:-$REPO_ROOT/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: $ENV_FILE no existe" >&2
    echo "Copia .env.example a .env y rellena los valores" >&2
    exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

if [[ -z "${ZURG_MCP_URL:-}" ]]; then
    echo "ERROR: falta ZURG_MCP_URL en $ENV_FILE" >&2
    exit 1
fi

cd "$REPO_ROOT"
exec claude "$@"
