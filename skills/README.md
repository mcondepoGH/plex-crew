# Cómo crear una skill

Este documento fija el estándar para crear y revisar skills en `skills/`. Cada skill sigue la estructura y la forma de definir las cosas de las skills de [claude-homelab](https://github.com/jmagar/claude-homelab). Los modelos de referencia son [`radarr`](radarr/) y [`sonarr`](sonarr/): ante la duda, léelos y copia su estructura. Las librerías de shell compartidas están documentadas en [`_lib/README.md`](_lib/README.md) y el hook que protege los comandos destructivos, en [`../hooks/README.md`](../hooks/README.md).

## Tipos de skill

| Tipo | Qué es | Contiene | Ejemplos |
|------|--------|----------|----------|
| Servicio | Envuelve un servicio del homelab con un script de shell. | `SKILL.md`, `README.md`, `scripts/<skill>.sh` y `references/` | `radarr`, `sonarr` (modelo), `prowlarr`, `plex`, `tautulli` (adaptadas de jmagar), `seerr`, `cli_debrid` |
| Reglas | Documenta reglas curadas que el agente debe aplicar; no ejecuta nada. | `SKILL.md`, `README.md` y `references/` | `plex-crew-rules`, `plex-naming-rules`, `arr-language-filters` |

## Estructura de directorios

```
skills/
├── README.md               este documento
├── _lib/                   librerías compartidas (load-env.sh, arr-api.sh)
└── <skill>/
    ├── SKILL.md            instrucciones para el agente
    ├── README.md           referencia para personas
    ├── scripts/            solo skills de servicio: <skill>.sh
    └── references/
        ├── api-endpoints.md    solo skills de servicio
        ├── quick-reference.md
        └── troubleshooting.md
```

El directorio, el campo `name` del frontmatter y el nombre del script coinciden (`radarr/`, `name: radarr`, `radarr.sh`). Las skills de reglas no tienen `scripts/` ni `api-endpoints.md`.

## Plantilla de SKILL.md

El frontmatter lleva solo `name` y `description`. La description va en español: "Esta skill debe usarse cuando ... Úsala cuando el usuario pida "frase uno", "frase dos", o mencione X." con las frases disparadoras entre comillas. No pongas dos puntos seguidos de un espacio (": ") dentro de la description: rompe el YAML.

````markdown
---
name: miservicio
description: Esta skill debe usarse cuando se gestione X en MiServicio. Úsala cuando el usuario pida "frase uno", "frase dos", o mencione MiServicio.
---

# Skill de gestión de X de MiServicio

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "frase uno", "frase dos"
- Cualquier mención de MiServicio

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Resumen de una frase de lo que hace la skill.

## Propósito
## Configuración
(bloque `.env` con cada variable y de dónde sale la clave)
## Ejecución del script
## Comandos
(párrafo de comportamiento y un ### por acción: ejemplo + **Salida:**)
## Flujo de trabajo
## Parámetros
## Notas
## Referencia
(enlaces externos y después los tres ficheros de `references/`)
````

Reglas de contenido:

- Todo va en español e imperativo. El bloque zsh-tool / pty de las skills de jmagar no se usa aquí. Excepción: los `references/` de las skills copiadas de jmagar (`radarr`, `sonarr`, `prowlarr`, `plex`, `tautulli`) siguen en inglés.
- El párrafo de `## Comandos` indica qué comandos devuelven JSON y cuáles texto; que sin comando se muestra la ayuda (rc 0); que un comando desconocido da rc 1; y que un argumento ausente o un id no numérico imprime el uso y da rc 1.
- Cada `###` lleva un ejemplo `bash "${CLAUDE_PLUGIN_ROOT}/skills/<skill>/scripts/<skill>.sh" ...` y un párrafo **Salida:**.
- Un comando destructivo indica que el hook `confirm-destructive` exige doble confirmación y `PLEX_CREW_CONFIRMED=1`.
- Los comandos masivos o que escriben sin destruir (`search-all`, `refresh`, `request-*`, `trigger-task`) llevan el aviso "confirma con el usuario antes de ...".
- Usa siempre `${CLAUDE_PLUGIN_ROOT}` en las rutas de los scripts: se sustituye en el cuerpo del `SKILL.md` y es la única ruta válida una vez instalado el plugin. No está disponible en el entorno de la herramienta Bash, así que no dependas de ella dentro de los scripts.

## Plantilla de README.md

````markdown
# Skill de MiServicio

Frase de una línea con lo que hace.

## Qué hace
- **Verbo** — descripción

## Configuración
### 1. Obtén tu clave de API
### 2. Configura las variables de entorno
(bloque con las variables de `~/.claude/plex-crew/.env` y una lista "Opciones de configuración", `HOMELAB_ENV` incluida)
### 3. Pruébalo

## Ejemplos de uso
(un ### por acción con un bloque `bash scripts/<skill>.sh ...`)

## Referencia de la API
(enlaces a los tres ficheros de `references/`)

## Flujo de trabajo

## Resolución de problemas
(mensaje en negrita y después "→ solución")

## Notas

## Licencia

MIT
````

Escribe los comandos en negrita en los ejemplos solo cuando modifiquen el estado o requieran confirmación. Las enumeraciones van en una lista o tabla, nunca separadas por comas en línea.

## Ficheros de references/

| Fichero | Contenido |
|---------|-----------|
| `api-endpoints.md` | Solo skills de servicio. Versión, URL base, autenticación, inicio rápido y endpoints por categoría con petición, campos de respuesta y códigos. Documenta solo lo que usa el script, salvo que el conjunto de endpoints sea el oficial. |
| `quick-reference.md` | Operaciones para copiar y pegar: bloque de configuración, después ejemplos de `curl` agrupados por área y los comandos del script auxiliar. Las skills de reglas usan una tabla de reglas en su lugar. |
| `troubleshooting.md` | Problemas agrupados (autenticación, conexión, uso), cada uno con **Causa:** y una **Solución:** numerada. |

## Plantilla de script

Esqueleto mínimo para un servicio estilo Arr (para otros servicios, sustituye `arr-api.sh` por tu propio auxiliar que compruebe el código HTTP):

```bash
#!/bin/bash
set -euo pipefail

# Wrapper de la API de MiServicio: <qué hace>.

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../_lib/load-env.sh" || { echo "ERROR: no se encuentra load-env.sh" >&2; exit 1; }
load_service_credentials "myservice" "MYSERVICE_URL" "MYSERVICE_API_KEY"

API="$MYSERVICE_URL/api/v3"
AUTH="X-Api-Key: $MYSERVICE_API_KEY"
source "$SCRIPT_DIR/../../_lib/arr-api.sh" || { echo "ERROR: no se pudo cargar arr-api.sh" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Uso: myservice.sh <comando> [args]

Comandos (los marcados JSON devuelven JSON; el resto, texto):
  search <texto>        Buscar (texto)
  search-json <texto>   Igual que search, salida JSON
  exists <id>           Comprobar si existe (texto)
  remove <id>           Quitar un elemento
USAGE
}

usage_error() { echo "ERROR: $1" >&2; echo "Uso: myservice.sh $2" >&2; exit 1; }
require_number() { [[ "$1" =~ ^[0-9]+$ ]] || usage_error "'$1' no es un id numérico" "$2"; }

# Separa los flags de los posicionales: deja POSITIONAL=() y los flags en variables
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
    arr_call DELETE "/item/$id" || exit 1   # imprime ERROR en stderr y rc 1 si no es 2xx
    echo "Quitado: $id"
    ;;
  *)
    echo "ERROR: comando desconocido: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
```

Puntos innegociables:

- Los argumentos se leen con `"${1:-}"`; nunca con `${1:?}` ni con un `$1` suelto (fallan con `unbound variable`).
- `usage()` usa un heredoc entrecomillado, empieza con `Uso: <script>.sh <comando> [args]`, lista cada comando con su sintaxis e indica cuáles dan JSON.
- Las escrituras usan `arr_call` (consulta [`_lib/README.md`](_lib/README.md)): comprueban el código HTTP y no descartan la respuesta con `> /dev/null`.
- Los mensajes del script van a stderr, con el prefijo `ERROR:` y sin emojis. Los mensajes de los scripts van en español.

## Convenciones de nombres de comandos

Los comandos van en kebab-case y se repiten con el mismo significado en todas las skills:

| Comando | Significado |
|---------|-------------|
| `search <texto>` | Busca con salida de texto. |
| `search-json <texto>` | La misma búsqueda con salida JSON. |
| `exists <id>` | Imprime `exists` (más datos) o `not_found`. |
| `config` | Carpetas raíz, perfiles y otros datos de configuración. |
| `add <id> ...` | Añade un elemento. |
| `remove <id> [--delete-files]` | Quita un elemento; `--delete-files` borra también los archivos. |
| `logs [n] [level]` | Últimas `n` líneas del log, con un filtro opcional por nivel. |
| `search-id <id>` | Lanza la búsqueda de un elemento por su id interno. |
| `search-all` | Lanza la búsqueda de todo lo que falta. |

Solo se devuelve JSON donde lo indiquen el nombre del comando (`*-json`), la ayuda o la documentación. Los flags (`--no-search`, `--delete-files`) se aceptan en cualquier posición mediante `parse_args`.

## Seguridad y hook

- Todo comando destructivo está registrado en la lista `DESTRUCTIVE` de `hooks/confirm-destructive.js`, documentado en [`hooks/README.md`](../hooks/README.md) y citado en el `SKILL.md` y el `README.md` de la skill.
- El hook bloquea el comando hasta que el usuario haya confirmado dos veces, en dos mensajes distintos; solo entonces se reintenta anteponiendo `PLEX_CREW_CONFIRMED=1`.
- Los comandos masivos o que escriben sin destruir no pasan por el hook, pero su `SKILL.md` exige confirmar antes con el usuario.
- Los secretos viven en `~/.claude/plex-crew/.env` (fuera del repo). Nunca se imprimen ni se escriben en ficheros versionados; los scripts los cargan con `load_service_credentials`.

## Variables de entorno

- Cada servicio usa `<SVC>_URL` y `<SVC>_API_KEY` (o `TOKEN`, `USER` y `PASSWORD` si el servicio lo necesita).
- Se declaran vacías en `.env.example` con un comentario `(skill <name>)`, por ejemplo `# Radarr: gestión de películas (skill radarr).`
- `HOMELAB_ENV` es opcional y apunta a otro fichero de entorno. Las variables ya exportadas tienen prioridad sobre el fichero.
- Se documentan en la sección Configuración del README de la skill, `HOMELAB_ENV` incluida.

## Checklist de revisión

SKILL.md

- [ ] 1. El frontmatter tiene solo `name` (igual al directorio) y `description` en español con las frases disparadoras entre comillas, y se interpreta como YAML.
- [ ] 2. El orden es: `# ... Skill`, bloque de invocación obligatoria, frase de resumen, `## Propósito`, `## Configuración`, `## Ejecución del script` (skills de servicio), `## Comandos` o `## Reglas`, `## Flujo de trabajo`, `## Parámetros`, `## Notas`, `## Referencia`.
- [ ] 3. Todo está en español e imperativo, sin bloque pty/zsh-tool.
- [ ] 4. Los comandos destructivos citan el hook `confirm-destructive` y `PLEX_CREW_CONFIRMED=1`; las escrituras masivas o no destructivas llevan "confirma con el usuario antes de ...".
- [ ] 5. Las rutas de los scripts usan `${CLAUDE_PLUGIN_ROOT}`.

README.md

- [ ] 6. Tiene las secciones `Qué hace`, `Configuración`, `Ejemplos de uso`, `Referencia de la API`, `Flujo de trabajo`, `Resolución de problemas`, `Notas` y `Licencia`.
- [ ] 7. Las enumeraciones van en una lista o tabla, nunca separadas por comas en línea.

references/

- [ ] 8. Tiene `quick-reference.md` y `troubleshooting.md`, más `api-endpoints.md` en las skills de servicio, y el `SKILL.md` los enlaza.

Script (skills de servicio)

- [ ] 9. Empieza con `#!/bin/bash`, `set -euo pipefail` y un comentario de una línea.
- [ ] 10. Define `SCRIPT_DIR`, carga `_lib/load-env.sh` con un mensaje de error y llama a `load_service_credentials`.
- [ ] 11. Define `API`/`AUTH` y carga `_lib/arr-api.sh` (servicios estilo Arr), o usa su propio auxiliar que comprueba el código HTTP.
- [ ] 12. `usage()` usa un heredoc entrecomillado, empieza con `Uso: <script>.sh <comando> [args]`, lista cada comando y marca los que dan JSON.
- [ ] 13. Usa `usage_error "<msg>" "<uso>"` (stderr, rc 1), `require_number` (`^[0-9]+$`) para los ids y `parse_args` para los flags en cualquier posición.
- [ ] 14. Despacha con `cmd="${1:-}"; shift || true; case`: vacío, `-h`, `--help` y `help` dan la ayuda con rc 0; un comando desconocido da `ERROR: comando desconocido: $cmd` y la ayuda a stderr con rc 1.
- [ ] 15. Los argumentos se leen con `"${1:-}"`, nunca con `${1:?}` ni con un `$1` suelto.
- [ ] 16. Los nombres de comando van en kebab-case y siguen la tabla de convenciones.
- [ ] 17. Solo se devuelve JSON donde lo indiquen el nombre, la ayuda o la documentación.
- [ ] 18. Todo comando destructivo está en `DESTRUCTIVE` de `hooks/confirm-destructive.js`, documentado en `hooks/README.md` y citado en SKILL y README.
- [ ] 19. `<SVC>_URL` y `<SVC>_API_KEY` (o TOKEN/USER/PASSWORD) están en `.env.example` con el comentario "(skill X)"; `HOMELAB_ENV` es opcional.
- [ ] 20. Las escrituras comprueban el código HTTP: si no es 2xx, mensaje en stderr y rc 1, sin un `ok` falso.
- [ ] 21. Los mensajes de error van a stderr, sin emojis y con el prefijo `ERROR:`.

## Verificación manual

Antes de dar una skill por terminada, ejecuta estas pruebas (sustituye `<s>` por el nombre de la skill). Para las rutas de escritura no toques el servicio real: sustituye `curl` por una función que devuelva una respuesta simulada, o las funciones `arr_*` por no-ops.

| Prueba | Comando | Resultado esperado |
|--------|---------|--------------------|
| Sintaxis | `bash -n skills/<s>/scripts/<s>.sh` | Sin salida, rc 0. |
| Sin argumentos | `bash skills/<s>/scripts/<s>.sh` | Imprime la ayuda, rc 0. |
| Comando falso | `bash skills/<s>/scripts/<s>.sh fake` | `ERROR: comando desconocido: fake` y la ayuda a stderr, rc 1. |
| Argumento ausente | `bash skills/<s>/scripts/<s>.sh exists` | `ERROR:` y `Uso:` a stderr, rc 1. |
| Id no numérico | `bash skills/<s>/scripts/<s>.sh exists abc` | `ERROR: 'abc' no es un id numérico` y `Uso:` a stderr, rc 1. |
| Lecturas reales | `config`, `exists <id>` y `search "<texto>"` | Salida esperada, rc 0. |
| Escritura con 2xx simulado | `add`, `remove`, `search-all` con `curl` simulado | Mensaje de éxito, rc 0. |
| HTTP 4xx simulado | Las mismas escrituras con una respuesta 400 | `ERROR: ... respondió HTTP 400` a stderr, sin mensaje de éxito, rc 1. |

Si la skill añade un comando destructivo, comprueba también que el hook lo bloquea sin `PLEX_CREW_CONFIRMED=1` y lo deja pasar con él. Por último, ejecuta `claude plugin validate .claude-plugin/plugin.json` para confirmar que todos los frontmatter se interpretan.

## Skills de reglas

Una skill de reglas no tiene `scripts/` ni variables de entorno, así que solo se aplican estas partes del estándar:

- `SKILL.md` con el frontmatter, el bloque de **INVOCACIÓN OBLIGATORIA DE LA SKILL**, `## Propósito`, una `## Configuración` que indique que no hay variables, una sección `## Reglas` (con las subsecciones de cada familia de reglas), `## Flujo de trabajo`, `## Notas`, `## Referencia` y una lista final "Lo que NO hay que hacer".
- `README.md` con las mismas secciones que una skill de servicio; `Configuración` indica que no necesita configuración y quién la carga.
- `references/quick-reference.md` (tabla de reglas) y `references/troubleshooting.md`; sin `api-endpoints.md`.
- Los puntos 1 a 4, 6 a 8 de la checklist y, si la skill documenta un comando destructivo, el 18.
