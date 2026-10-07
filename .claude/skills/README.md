# Cómo crear una skill

Este documento fija el estándar para crear y revisar skills en `.claude/skills/`. Los modelos de referencia son [`radarr`](radarr/) y [`sonarr`](sonarr/): ante cualquier duda, léelas y copia su estructura. Las librerías de shell compartidas están documentadas en [`_lib/README.md`](_lib/README.md) y el hook que protege los comandos destructivos, en [`../../hooks/README.md`](../../hooks/README.md).

## Tipos de skill

| Tipo | Qué es | Contiene | Ejemplos |
|------|--------|----------|----------|
| De servicio | Envuelve un servicio del homelab con un script de shell. | `SKILL.md`, `README.md` y `scripts/<skill>.sh` | `radarr`, `sonarr` (modelo), `prowlarr`, `plex`, `tautulli`, `seerr`, `cli_debrid` |
| De reglas | Documenta reglas curadas que el agente debe aplicar; no ejecuta nada. | `SKILL.md` y `README.md` | `plex-naming-rules`, `zurg-rules`, `arr-language-filters`, `safety-conventions` |

## Estructura de directorios

```
.claude/skills/
├── README.md               este documento
├── _lib/                   librerías compartidas (load-env.sh, arr-api.sh)
└── <skill>/
    ├── SKILL.md            instrucciones para el agente
    ├── README.md           referencia para personas (~55-60 líneas)
    └── scripts/
        └── <skill>.sh      solo en skills de servicio
```

El directorio, el campo `name` del frontmatter y el nombre del script coinciden (`radarr/`, `name: radarr`, `radarr.sh`).

## Plantilla mínima de SKILL.md

El frontmatter lleva solo `name` y `description`. La descripción va en español: "Gestión de X en Y. Úsala cuando el usuario pida ..." con las frases disparadoras entre comillas.

````markdown
---
name: miservicio
description: Gestión de X en MiServicio. Úsala cuando el usuario pida "frase uno", "frase dos", o mencione MiServicio.
---

# Skill de gestión de X en MiServicio

**INVOCACIÓN OBLIGATORIA DE LA SKILL**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "frase uno", "frase dos"
- Cualquier mención de MiServicio

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Frase resumen de lo que hace la skill.

## Propósito
## Configuración
(bloque .env con cada variable y de dónde sale la clave)
## Comandos
(párrafo de comportamiento y un ### por acción: ejemplo + **Salida:**)
## Flujo de trabajo
## Parámetros
## Notas
## Referencia
````

Reglas de contenido:

- Todo en español y en imperativo. Sin bloque pty/zsh-tool, sin "Multiple Servers" ni "Integration".
- El párrafo de `## Comandos` dice qué comandos devuelven JSON y cuáles texto; que sin comando se muestra la ayuda (rc 0); que un comando desconocido da rc 1; y que la falta de un argumento o un id no numérico imprime el uso y da rc 1.
- Cada `###` lleva un ejemplo `bash .claude/skills/<skill>/scripts/<skill>.sh ...` y un párrafo **Salida:**.
- Un comando destructivo dice que el hook `confirm-destructive` exige doble confirmación y `PLEX_CREW_CONFIRMED=1`.
- Los comandos masivos o que escriben sin destruir (`search-all`, `refresh`, `request-*`, `trigger-task`) llevan el aviso "confirma con el usuario antes de ...".

## Plantilla de README.md

````markdown
# <skill>

Frase de una línea con lo que hace.

## Cuándo se usa
Qué agente la carga y qué tipo de ids maneja.

## Comandos
Script: `.claude/skills/<skill>/scripts/<skill>.sh <comando> [args]`.

| Comando | Para qué sirve | Argumentos / opciones | Tipo |
|---------|----------------|-----------------------|------|
| `lectura` | ... | `<arg>` | Lectura (texto) |
| **`escritura`** | ... | `<arg>` | Escritura |

## Variables de entorno

| Variable | Obligatoria | Uso |
|----------|-------------|-----|
| `MISERVICIO_URL` | Sí | ... |
| `HOMELAB_ENV` | No | Ruta alternativa al fichero `.env`. |

## Ejemplos de uso
(bloque con comentarios `# Lectura:` y `# ESCRITURA:`)

## Notas y límites
(rc de ayuda, uso y comando desconocido; flags en cualquier posición; qué imprime cada comando; comprobación HTTP; hook)
````

Los comandos de escritura van en negrita y con Tipo "Escritura"; los de lectura, "Lectura (texto)" o "Lectura (JSON)". Las enumeraciones van en lista o tabla, nunca separadas por comas en línea.

## Plantilla de script

Esqueleto mínimo para un servicio estilo Arr (para otros servicios, sustituye `arr-api.sh` por un helper propio que compruebe el código HTTP):

```bash
#!/bin/bash
set -euo pipefail

# Wrapper de la API de MiServicio: <qué hace>.

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../_lib/load-env.sh" || { echo "ERROR: no se pudo cargar load-env.sh. Copia .env.example a .env" >&2; exit 1; }
load_service_credentials "miservicio" "MISERVICIO_URL" "MISERVICIO_API_KEY"

API="$MISERVICIO_URL/api/v3"
AUTH="X-Api-Key: $MISERVICIO_API_KEY"
source "$SCRIPT_DIR/../../_lib/arr-api.sh" || { echo "ERROR: no se pudo cargar arr-api.sh" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Uso: miservicio.sh <comando> [args]

Comandos (los marcados JSON devuelven JSON; el resto, texto):
  search <texto>        Buscar (texto)
  search-json <texto>   Igual que search, salida JSON
  exists <id>           Comprobar si existe (texto)
  remove <id>           Quitar un elemento
USAGE
}

usage_error() { echo "ERROR: $1" >&2; echo "Uso: miservicio.sh $2" >&2; exit 1; }
require_number() { [[ "$1" =~ ^[0-9]+$ ]] || usage_error "'$1' no es un id numérico" "$2"; }

# Separa flags de posicionales: deja POSITIONAL=() y los flags en variables
parse_args() {
  POSITIONAL=(); FLAG="false"
  local a
  for a in "$@"; do
    case "$a" in
      --flag) FLAG="true" ;;
      *) POSITIONAL+=("$a") ;;
    esac
  done
}

cmd="${1:-}"
shift || true

case "$cmd" in
  ""|-h|--help|help) usage; exit 0 ;;
  exists)
    id="${1:-}"
    [[ -n "$id" ]] || usage_error "falta el id" "exists <id>"
    require_number "$id" "exists <id>"
    arr_get "/item?id=$id" | jq -r '...'
    ;;
  remove)
    parse_args "$@"
    id="${POSITIONAL[0]:-}"
    [[ -n "$id" ]] || usage_error "falta el id" "remove <id>"
    require_number "$id" "remove <id>"
    arr_call DELETE "/item/$id" || exit 1   # escribe ERROR por stderr y rc 1 si no es 2xx
    echo "Quitado: $id"
    ;;
  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
```

Puntos que no se negocian:

- Los argumentos se leen con `"${1:-}"`; nunca con `${1:?}` ni con `$1` a pelo (rompen con `unbound variable`).
- `usage()` usa un heredoc entrecomillado, empieza por `Uso: <script>.sh <comando> [args]`, lista cada comando con su sintaxis e indica cuáles dan JSON.
- Las escrituras usan `arr_call` (véase [`_lib/README.md`](_lib/README.md)): comprueban el código HTTP y no descartan la respuesta con `> /dev/null`.
- Los mensajes de error salen por stderr, en español, sin emojis y con prefijo `ERROR:`.

## Convenciones de nombres de comandos

Los comandos van en kebab-case y se repiten con el mismo significado en todas las skills:

| Comando | Significado |
|---------|-------------|
| `search <texto>` | Búsqueda con salida de texto. |
| `search-json <texto>` | La misma búsqueda con salida JSON. |
| `exists <id>` | Imprime `exists` (más datos) o `not_found`. |
| `config` | Carpetas raíz, perfiles y otros datos de configuración. |
| `add <id> ...` | Alta de un elemento. |
| `remove <id> [--delete-files]` | Baja de un elemento; `--delete-files` borra también los ficheros. |
| `logs [n] [nivel]` | Últimas `n` líneas de log, con filtro opcional de nivel. |
| `search-id <id>` | Lanza la búsqueda de un elemento por su id interno. |
| `search-all` | Lanza la búsqueda de todo lo que falta. |

El JSON solo se devuelve donde lo indican el nombre del comando (`*-json`), la ayuda o la documentación. Los flags (`--no-search`, `--delete-files`) se aceptan en cualquier posición mediante `parse_args`.

## Seguridad y hook

- Todo comando destructivo se registra en la lista `DESTRUCTIVE` de `hooks/confirm-destructive.js`, se documenta en [`hooks/README.md`](../../hooks/README.md) y se cita en el `SKILL.md` y en el `README.md` de la skill.
- El hook bloquea el comando hasta que el usuario ha confirmado dos veces, en dos mensajes distintos; solo entonces se reintenta anteponiendo `PLEX_CREW_CONFIRMED=1`.
- Los comandos masivos o que escriben sin destruir no pasan por el hook, pero su `SKILL.md` exige confirmar con el usuario antes.
- Los secretos viven en `.env` (ignorado por git). Nunca se imprimen ni se escriben en ficheros versionados; los scripts los cargan con `load_service_credentials`.

## Variables de entorno

- Cada servicio usa `<SVC>_URL` y `<SVC>_API_KEY` (o `TOKEN`, `USER` y `PASSWORD` si el servicio lo pide).
- Se declaran vacías en `.env.example` con un comentario `(skill <nombre>)`, por ejemplo `# Radarr: gestión de películas (skill radarr).`
- `HOMELAB_ENV` es opcional y apunta a otro fichero de entorno. Las variables ya exportadas tienen prioridad sobre el fichero.
- Se documentan en la tabla `## Variables de entorno` del README de la skill, incluida `HOMELAB_ENV`.

## Checklist de revisión

SKILL.md

- [ ] 1. El frontmatter tiene solo `name` (igual al directorio) y `description` en español con frases disparadoras entre comillas.
- [ ] 2. El orden es: `# Skill de ...`, bloque de invocación obligatoria, frase resumen, `## Propósito`, `## Configuración`, `## Comandos`, `## Flujo de trabajo`, `## Parámetros`, `## Notas`, `## Referencia`.
- [ ] 3. Todo está en español e imperativo, sin bloque pty/zsh-tool, sin "Multiple Servers" ni "Integration".
- [ ] 4. Los comandos destructivos citan el hook `confirm-destructive` y `PLEX_CREW_CONFIRMED=1`; los masivos o que escriben sin destruir llevan "confirma con el usuario antes de ...".

README.md

- [ ] 5. Tiene unas 55-60 líneas con las secciones `Cuándo se usa`, `Comandos`, `Variables de entorno`, `Ejemplos de uso` y `Notas y límites`.
- [ ] 6. La tabla de comandos marca en negrita los de escritura y usa los Tipos "Lectura (texto/JSON)" y "Escritura".
- [ ] 7. Las enumeraciones están en lista o tabla, nunca separadas por comas en línea.

Script

- [ ] 8. Empieza por `#!/bin/bash`, `set -euo pipefail` y un comentario de una línea.
- [ ] 9. Define `SCRIPT_DIR`, hace `source` de `_lib/load-env.sh` con mensaje de error y llama a `load_service_credentials`.
- [ ] 10. Define `API`/`AUTH` y carga `_lib/arr-api.sh` (servicios estilo Arr), o usa un helper propio con comprobación HTTP.
- [ ] 11. `usage()` usa heredoc entrecomillado, empieza por `Uso: <script>.sh <comando> [args]`, lista cada comando e indica los que dan JSON.
- [ ] 12. Usa `usage_error "<msg>" "<uso>"` (stderr, rc 1), `require_number` (`^[0-9]+$`) para los ids y `parse_args` para flags en cualquier posición.
- [ ] 13. Despacha con `cmd="${1:-}"; shift || true; case`: vacío, `-h`, `--help` y `help` dan la ayuda con rc 0; un comando desconocido da `ERROR: comando desconocido: $cmd` y la ayuda por stderr con rc 1.
- [ ] 14. Los argumentos se leen con `"${1:-}"`, nunca con `${1:?}` ni `$1` a pelo.
- [ ] 15. Los nombres de comando son kebab-case y siguen la tabla de convenciones.
- [ ] 16. El JSON solo se devuelve donde lo indican el nombre, la ayuda o la documentación.
- [ ] 17. Todo comando destructivo está en `DESTRUCTIVE` de `hooks/confirm-destructive.js`, documentado en `hooks/README.md` y citado en SKILL y README.
- [ ] 18. `<SVC>_URL` y `<SVC>_API_KEY` (o TOKEN/USER/PASSWORD) están en `.env.example` con el comentario "(skill X)"; `HOMELAB_ENV` es opcional.
- [ ] 19. Las escrituras comprueban el código HTTP: si no es 2xx, mensaje por stderr y rc 1, sin falso `ok`.
- [ ] 20. Los mensajes de error van por stderr, en español, sin emojis y con prefijo `ERROR:`.

## Verificación manual

Antes de dar una skill por terminada, ejecuta estas pruebas (sustituye `<s>` por el nombre de la skill). Para los caminos de escritura no toques el servicio real: sustituye `curl` por una función que devuelva una respuesta simulada, o las funciones `arr_*` por no-ops.

| Prueba | Comando | Resultado esperado |
|--------|---------|--------------------|
| Sintaxis | `bash -n .claude/skills/<s>/scripts/<s>.sh` | Sin salida, rc 0. |
| Sin argumentos | `bash .claude/skills/<s>/scripts/<s>.sh` | Imprime la ayuda, rc 0. |
| Comando falso | `bash .claude/skills/<s>/scripts/<s>.sh falso` | `ERROR: comando desconocido: falso` y la ayuda por stderr, rc 1. |
| Falta un argumento | `bash .claude/skills/<s>/scripts/<s>.sh exists` | `ERROR:` y `Uso:` por stderr, rc 1. |
| Id no numérico | `bash .claude/skills/<s>/scripts/<s>.sh exists abc` | `ERROR: 'abc' no es un id numérico` y `Uso:` por stderr, rc 1. |
| Lecturas reales | `config`, `exists <id>` y `search "<texto>"` | Salida esperada, rc 0. |
| Escritura con 2xx simulado | `add`, `remove`, `search-all` con `curl` simulado | Mensaje de éxito, rc 0. |
| HTTP 4xx simulado | Las mismas escrituras con respuesta 400 | `ERROR: ... respondió HTTP 400` por stderr, sin mensaje de éxito, rc 1. |

Si la skill añade un comando destructivo, comprueba además que el hook lo bloquea sin `PLEX_CREW_CONFIRMED=1` y lo deja pasar con él.

## Skills de reglas

Una skill de reglas no tiene `scripts/` ni variables de entorno, así que de este estándar aplican solo estas partes:

- `SKILL.md` con el frontmatter (`name` y `description` en español con frases disparadoras), el bloque **INVOCACIÓN OBLIGATORIA DE LA SKILL**, `## Propósito`, las secciones con las reglas y los límites conocidos (qué no cubre la skill).
- `README.md` breve: título con una frase y solo las secciones que aporten (qué reglas contiene, quién la carga y sus límites), sin secciones de relleno como `Comandos` o `Variables de entorno`.
- Las reglas 1 a 3 de la checklist (frontmatter, orden adaptado y español imperativo). Las reglas 4 a 20 no aplican, salvo la 17 si la skill documenta un comando destructivo.
