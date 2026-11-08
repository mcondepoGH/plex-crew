# Hooks

Cinco hooks en Node: tres `PreToolUse` que actúan como red de seguridad ante errores y dos de registro (`PostToolUse`/`PostToolUseFailure` y `SessionStart`). No son un sandbox: no protegen frente a un adversario.

| Hook | Dónde se registra | Para qué sirve |
|---|---|---|
| `confirm-destructive.js` | `hooks/hooks.json` (plugin), sobre `Bash`, para todos los agentes | Bloquea comandos destructivos sin doble confirmación |
| `enforce-agent-scope.js` | Frontmatter de `agents/plex-naming.md` (solo ese agente) | Limita las rutas donde puede escribir |
| `protected-paths.js` | `hooks/hooks.json` (plugin), `PreToolUse` sobre `Bash\|Read\|Glob\|Grep\|Edit\|Write\|NotebookEdit`, para todos los agentes y la sesión principal | No deja tocar ni leer carpetas de sistema del NAS (`@Recycle`, `@Recently-Snapshot`, `.@*`...); sin override |
| `log-action.js` | `hooks/hooks.json` (plugin), `PostToolUse` y `PostToolUseFailure` sobre `Bash`, `Edit`, `Write`, y `NotebookEdit` | Registra una línea por acción en el log diario |
| `purge-logs.js` | `hooks/hooks.json` (plugin), `SessionStart` (`startup` y `resume`) | Borra los logs de más de 7 días |

## confirm-destructive.js

Se registra en `hooks/hooks.json` (plugin) como `PreToolUse` con `matcher: "Bash"` y un timeout de 10 s. Se aplica a todos los agentes que tengan `Bash` (el orquestador no lo tiene).

Qué vigila: el texto del comando `Bash`. Si casa con algún patrón destructivo y no lleva el marcador, lo deniega con un mensaje que explica la regla. Lo que no casa pasa sin salida.

Alcance (solo el ecosistema del plugin):

- Git: solo si el repo afectado (`cwd` o `git -C`) está dentro de este repositorio.
- Borrado de ficheros (`rm`, `unlink`, `shred`, `truncate`, `mkfs`, `dd of=`, `find -delete`): solo si el comando o el `cwd` tocan rutas de `scope.conf` (carpetas de medios de Plex) o este repositorio.
- `docker`, SQL, `curl -X DELETE` (o `--request DELETE`), `arr_delete` y subcomandos destructivos de las skills: siempre.

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
  - `plex-api.sh emptytrash`
  - los subcomandos de borrado de `rutorrent.sh`
- ruTorrent a mano: `curl` con `mode=remove` o `mode=removewithdata`, `curl` a `/plugins/erasedata`, `curl` a `/RPC2` con `d.erase`, `execute*` o cuerpo desde `@fichero`/`@-`, `rtxmlrpc` con `d.erase`, `execute*`, `--delete` o `--cull`, y `rtcontrol` con `--delete` o `--cull`.

Marcador `PLEX_CREW_CONFIRMED=1`: si el comando lo lleva como asignación de entorno al inicio (por ejemplo `PLEX_CREW_CONFIRMED=1 rm -rf /ruta`, también tras `;`, `&` o `|`), el hook lo deja pasar. Solo se pone tras la doble confirmación del usuario (dos mensajes distintos, incluso en modo automático). Sin marcador, el subagente no ejecuta el comando y devuelve la propuesta al orquestador, que pide las confirmaciones.

Si el JSON de entrada no es válido (vacío o basura), falla cerrado: escribe `plex-crew hook: entrada JSON no válida; bloqueado por seguridad` en stderr y sale con código 2, que Claude Code interpreta como bloqueo. Lo mismo hace `enforce-agent-scope`.

### Rutas con variables de shell

El hook no ejecuta ni expande nada, así que no puede resolver una variable (`$VAR/...`, `${VAR}/...`), `~`, `$(...)` o comillas inversas. Con las operaciones de borrado que vigila (`rm`, `rmdir`, `unlink`, `shred`, `truncate`, `mkfs`, `dd of=`, `rsync --delete`, `find -delete` o `-exec rm`), una ruta de este tipo cuenta siempre como "toca las carpetas de medios", y el comando se deniega sin el marcador `PLEX_CREW_CONFIRMED=1`. Tampoco se resuelve tras un `cd` con variable: el directorio de trabajo pasa a desconocido y las rutas relativas cuentan igual. No hace falta que la variable apunte a un sitio vigilado: el hook no lo sabe. `mv` y `cp` no se vigilan (salvo `mv` hacia `/dev/null`), así que no se rechazan por esto.

Usa rutas literales, absolutas y sin variables: así el hook sí puede decidir si caen fuera de las carpetas de medios (y el comando pasa sin marcador) o dentro (y pide la doble confirmación).

## protected-paths.js

Regla permanente: las carpetas de sistema del NAS (QNAP u otro) no se tocan ni se leen. Se aplica a todos los agentes y a la sesión principal (no mira `agent_type`). Sin override: `PLEX_CREW_CONFIRMED=1` no lo salta. Hace cumplir la regla global de ignorar las carpetas `.@*` (skill `plex-crew-rules`).

Lista por defecto (sin distinguir mayúsculas): `@Recycle`, `@Recently-Snapshot`, `@Transcode`, `@Download`, `@eaDir`, `#recycle`, `#snapshot` y cualquier componente que empiece por `.@` (p. ej. `.@__thumb`).

Ampliar la lista (suma a la de por defecto, no la sustituye):

- `$PLEX_CREW_PROTECTED_NAMES`: nombres separados por `:`.
- `~/.claude/plex-crew/protected-names.conf`: un nombre por línea, `#` comentarios. Un nombre es un componente de ruta, sin `/`.

Criterio de coincidencia: una ruta está protegida si alguno de sus componentes (separados por `/`) es un nombre protegido. Se mira la ruta tal cual y también resuelta (`..` y enlaces simbólicos, usando el ancestro existente más cercano), así que `x/../@Recycle` y un enlace hacia esas carpetas se detectan. Ejemplo de denegación: `ls /ruta/a/medios/@Recycle`.

- `Bash`: cuenta cada palabra del comando (tras quitar comillas, también el valor de `--opcion=ruta` y `of=ruta`, redirecciones `>` y `<`, `$(...)`, `bash -c` y `eval`) que, vista como ruta, tenga un componente protegido, o sea exactamente el nombre (`ls @Recycle`). Se sigue `cd`, y un directorio de trabajo dentro de una carpeta protegida también deniega. Cualquier verbo vale: `ls`, `cat`, `find <ruta>`, `rm`, `mv`/`cp` desde o hacia ellas, `touch`, etc.
- `Read` (`file_path`), `Glob` (`path` y `pattern`), `Grep` (`path` y `glob`), `Edit`/`Write` (`file_path`) y `NotebookEdit` (`notebook_path`): se mira solo la ruta.
- No cuenta: texto suelto con espacios (`echo "ver @Recycle en el README"`), mensajes de `git commit -m`, cuerpos de heredoc, el contenido de `Write`/`Edit` y el `pattern` de `Grep`. Tampoco un fichero llamado `Recycle.txt`.

Límites: un `find /volumen` o un `Glob`/`Grep` recursivo desde una carpeta padre puede recorrer esas carpetas sin nombrarlas y el hook no lo ve; las skills y los agentes deben excluirlas (`-not -path '*/@Recycle/*'`, `--exclude-dir`...). No ve scripts (`bash x.sh`), variables sin resolver ni lo que hagan los programas por dentro. La palabra suelta de una carpeta protegida se deniega aunque solo sea texto a buscar o a imprimir (`grep -r @Recycle fichero`, `echo ver @Recycle`): el hook no distingue ruta de texto; para buscar el texto, ponlo entre comillas junto a otras palabras (`"ver @Recycle"`) o usa `Grep` con `pattern`. Es una red de seguridad contra errores, no un sandbox.

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

### Dónde lee el scope enforce-agent-scope.js

Lee `$PLEX_CREW_CONFIG` o, si no está definida, `~/.claude/plex-crew/scope.conf`. Nunca lee un `scope.conf` del repositorio: en la raíz solo está `scope.conf.example` (plantilla) y `scope.conf` está en `.gitignore` desde la 0.4.10, para no subirlo por error. Si el fichero no existe o no tiene rutas, deniega toda escritura a `plex-naming`.

Formato: una ruta absoluta por línea, `#` para comentarios (y se ignoran las líneas vacías); cada ruta incluye todo lo que cuelga de ella.

Limitación: este hook solo limita las rutas; no impide `mkdir` ni `touch` dentro de las rutas permitidas.

### scope.conf

Las rutas permitidas se leen de:

1. (Lo leen ambos hooks) El fichero indicado en la variable de entorno `PLEX_CREW_CONFIG`, o si no existe, `~/.claude/plex-crew/scope.conf`.
2. Argumentos de línea de comandos opcionales del hook, que se añaden como rutas extra.

Formato: una ruta absoluta por línea; se ignoran las líneas vacías y las que empiezan por `#`; se admite `~` al principio. La plantilla es [`scope.conf.example`](../scope.conf.example):

```
mkdir -p ~/.claude/plex-crew
cp scope.conf.example ~/.claude/plex-crew/scope.conf
```

`PLEX_CREW_CONFIG` se define en el entorno de la shell, no en el `.env`.

La ruta por defecto cuelga de `~/.claude` y no de `~/.config` porque en contenedores `~/.claude` suele ser un volumen persistente, mientras que `~/.config` no.

`scope.conf` lo leen **ambos** hooks y los dos fallan cerrados si falta o no tiene rutas:

- `enforce-agent-scope`: deniega toda escritura a `plex-naming`, con un mensaje que explica cómo crearlo.
- `confirm-destructive`: deniega las operaciones destructivas de fichero, porque sin las raíces de medios no puede decidir qué vigilar.

La plantilla usa rutas ficticias (`/ruta/a/plex/{movies,shows,anime,music}`); sustitúyelas por tus raíces.

Comportamiento a tener presente:

- `mv` dentro de las raíces de medios está permitido a propósito: es la operación de renombrado.
- El marcador `PLEX_CREW_CONFIRMED=1` debe ir al inicio del mismo segmento del comando que la operación destructiva (los segmentos se separan con `;`, `&&`, `||` o `|`). Si va en otro segmento, no cuenta.

## Hooks de log

`log-action.js` se registra como `PostToolUse` y `PostToolUseFailure` (matcher `Bash|Edit|Write|NotebookEdit`, timeout 5 s) y añade una línea por acción, de cualquier agente (hilo principal incluido), a `~/.claude/plex-crew/logs/<AAAA-MM-DD>-auto.log`. La fecha y la hora son las locales de la máquina (zona horaria del sistema), y la zona entre paréntesis es la que resuelve la propia máquina. Formato de línea:

```
HH:MM:SS (<zona de la máquina>) | agente | herramienta | comando | OK
HH:MM:SS (<zona de la máquina>) | agente | herramienta | comando | FALLO
```

- `agente`: el `agent_type` (por ejemplo `plex-crew:arr-acquisition`) o `main` para el hilo principal.
- `comando`: el comando `Bash` o la ruta (`file_path` / `notebook_path`), en una sola línea y recortado a 300 caracteres.
- Último campo: `FALLO` si el evento es `PostToolUseFailure`; en cualquier otro caso, `OK`.
- Los secretos se redactan (`***`) antes de recortar: contraseñas en URLs, cabeceras `Authorization`, pares `token`/`api_key`/`password` y similares, y cadenas hex o base64 largas. Es una red de seguridad: no garantiza detectar todos los secretos.
- La carpeta se crea con permisos 0700 y el fichero con 0600.

`purge-logs.js` se registra como `SessionStart` (`startup` y `resume`, timeout 5 s) y borra los `*.log` de más de 7 días directamente en esa carpeta (sin recursión ni enlaces simbólicos).

Ninguno de los dos bloquea nunca: siempre salen con código 0, y un error al escribir o purgar se ignora. No escriben en stdout.

## Límites

- No es un sandbox: es una red de seguridad contra errores, no contra un adversario. Una orden construida a propósito puede esquivar el análisis.
- Solo ve las cuatro tools de la lista de `enforce-agent-scope` (arriba); no controla ninguna otra.
- `confirm-destructive` trabaja sobre el texto del comando; una operación destructiva que no case con los patrones pasa.
- `enforce-agent-scope` solo cubre a `plex-naming`.

## Límites conocidos

`confirm-destructive` es una red de seguridad contra errores, no un sandbox: analiza el texto del comando y no ejecuta ni resuelve nada. No detecta, entre otros:

- Verbo tomado de una variable: `f=rm; $f -rf ruta`.
- Borrado desde otro lenguaje: `python -c "import shutil; shutil.rmtree('ruta')"`.
- Verbo oculto tras un `alias`.

Para esas vías, el control real son los permisos de Claude Code y el alcance de las rutas montadas.
