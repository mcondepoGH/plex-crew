# Hooks

Dos hooks `PreToolUse` en Node que actúan como red de seguridad ante errores. No son un sandbox: no protegen frente a un adversario.

| Hook | Dónde se registra | Para qué sirve |
|---|---|---|
| `confirm-destructive.js` | `hooks/hooks.json` (plugin), sobre `Bash`, para todos los agentes | Bloquea comandos destructivos sin doble confirmación |
| `enforce-agent-scope.js` | Frontmatter de `agents/plex-naming.md` (solo ese agente) | Limita las rutas donde puede escribir |

## confirm-destructive.js

Se registra en `hooks/hooks.json` (plugin) como `PreToolUse` con `matcher: "Bash"` y un timeout de 10 s. Se aplica a todos los agentes que tengan `Bash` (el orquestador no lo tiene).

Qué vigila: el texto del comando `Bash`. Si casa con algún patrón destructivo y no lleva el marcador, lo deniega con un mensaje que explica la regla. Lo que no casa pasa sin salida.

Patrones principales:

- Borrado de ficheros:
  - `rm`
  - `unlink`
  - `shred`
  - `truncate`
  - `mkfs`
- `dd` con `of=`.
- Git:
  - `git reset --hard`
  - `git clean -f`
  - `git push --force` o `-f`
  - `git checkout --`
  - `git restore`
- `docker` / `docker compose` con:
  - `rm`
  - `rmi`
  - `down`
  - `kill`
  - `system prune`
  - `volume rm`
- `find` con `-delete` o `-exec rm`.
- SQL:
  - `DELETE FROM`
  - `DROP TABLE`
  - `DROP DATABASE`
- `curl -X DELETE`.
- Skills de servicios (con `bash`, ruta relativa o absoluta):
  - `radarr.sh remove` (con o sin `--delete-files`)
  - `sonarr.sh remove` (con o sin `--delete-files`)
  - `prowlarr-api.sh delete`

Marcador `PLEX_CREW_CONFIRMED=1`: si el comando lo lleva como asignación de entorno al inicio (por ejemplo `PLEX_CREW_CONFIRMED=1 rm -rf /ruta`, también tras `;`, `&` o `|`), el hook lo deja pasar. Solo se pone tras la doble confirmación del usuario (dos mensajes distintos, incluso en modo automático). Sin marcador, el subagente no ejecuta el comando y devuelve la propuesta al orquestador, que pide las confirmaciones.

Si el JSON de entrada no se puede leer, no bloquea.

## enforce-agent-scope.js

Está registrado en `hooks/hooks.json` (plugin) para todas las llamadas, pero solo restringe cuando el `agent_type` del input es `plex-naming` o `<plugin>:plex-naming`; en cualquier otro caso sale sin decidir (con `PLEX_CREW_ENFORCE_ALL=1` restringe también sin `agent_type`, para pruebas). Actúa sobre estas tools:

- `Edit`
- `Write`
- `NotebookEdit`
- `Bash`

Qué vigila: que toda escritura quede dentro de las rutas permitidas (incluye todo lo que cuelga de ellas; se resuelven los enlaces simbólicos).

- `Edit` y `Write`: comprueban `file_path`.
- `NotebookEdit`: comprueba `notebook_path`.
- `Bash`: analiza el comando de forma conservadora.
  - Lo trocea por estos separadores:
    - `;`
    - `&&`
    - `||`
    - `|`
    - `&`
    - saltos de línea
  - Comprueba las rutas afectadas por estos comandos:
    - `mv`
    - `cp`
    - `rm`
    - `rmdir`
    - `mkdir`
    - `touch`
    - `ln`
    - `tee`
    - `truncate`
    - `install`
    - `sed -i`
    - redirecciones `>` / `>>`
  - También revisa las sustituciones `$(...)` y las rutas que aparecen en código inline de `python`, `perl`, `node` y `ruby`.
- Ante la duda deniega, y el mensaje pide simplificar el comando. Casos:
  - `eval`
  - `xargs`
  - `bash -c` (y shells similares)
  - `find` con `-exec` o `-delete`
  - rutas con expansiones sin resolver
  - directorio de trabajo desconocido

### scope.conf

Las rutas permitidas se leen de:

1. El fichero indicado en la variable de entorno `PLEX_CREW_CONFIG`, o si no existe, `~/.claude/plex-crew/scope.conf`.
2. Argumentos de línea de comandos opcionales del hook, que se añaden como rutas extra.

Formato: una ruta absoluta por línea; se ignoran las líneas vacías y las que empiezan por `#`; se admite `~` al principio. La plantilla es [`scope.conf.example`](../scope.conf.example):

```
mkdir -p ~/.claude/plex-crew
cp scope.conf.example ~/.claude/plex-crew/scope.conf
```

`PLEX_CREW_CONFIG` se define en el entorno de la shell, no en el `.env`.

La ruta por defecto cuelga de `~/.claude` y no de `~/.config` porque en el contenedor del stack `~/.claude` está montado desde un volumen (`./claude-code/config`) y persiste entre reinicios, mientras que `~/.config` no.

Si el fichero falta o no tiene rutas, el hook deniega toda escritura con un mensaje que explica cómo crearlo.

## Límites

- No es un sandbox: es una red de seguridad contra errores, no contra un adversario. Una orden construida a propósito puede esquivar el análisis.
- Solo ve las cuatro tools de la lista de `enforce-agent-scope` (arriba); no controla ninguna otra.
- `confirm-destructive` trabaja sobre el texto del comando; una operación destructiva que no case con los patrones pasa.
- `enforce-agent-scope` solo cubre a `plex-naming`.
