# Hooks

Siete hooks en Node: cinco `PreToolUse` que actúan como red de seguridad ante errores y dos de registro (`PostToolUse`/`PostToolUseFailure` y `SessionStart`). No son un sandbox: no protegen frente a un adversario.

| Hook | Dónde se registra | Para qué sirve |
|---|---|---|
| `confirm-destructive.js` | `hooks/hooks.json` (plugin), sobre `Bash`, para todos los agentes | Bloquea comandos destructivos sin doble confirmación |
| `enforce-agent-scope.js` | Frontmatter de `agents/plex-naming.md` (solo ese agente) | Limita las rutas donde puede escribir |
| `zurg-mount.js` | `hooks/hooks.json` (plugin), `PreToolUse` sobre `Bash\|Edit\|Write\|NotebookEdit`, para todos los agentes y la sesión principal | En un montaje de zurg no deja crear ni modificar nada (solo renombrar); excepción `__magic__` |
| `protected-paths.js` | `hooks/hooks.json` (plugin), `PreToolUse` sobre `Bash\|Read\|Glob\|Grep\|Edit\|Write\|NotebookEdit`, para todos los agentes y la sesión principal | No deja tocar ni leer carpetas de sistema del NAS (`@Recycle`, `@Recently-Snapshot`, `.@*`...); sin override |
| `log-action.js` | `hooks/hooks.json` (plugin), `PostToolUse` y `PostToolUseFailure` sobre `Bash`, `Edit`, `Write`, `NotebookEdit` y `mcp__zurg__.*` | Registra una línea por acción en el log diario |
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

## zurg-mount.js

Regla permanente: en un montaje de zurg solo se renombra lo que ya existe; nunca se crean carpetas ni ficheros. Se aplica a todos los agentes y a la sesión principal (no mira `agent_type`). No hay override: `PLEX_CREW_CONFIRMED=1` no lo salta.

Qué detecta como montaje de zurg (se suman las dos fuentes). La ruta se resuelve con symlinks y `..`; si no existe, se sube hasta el ancestro existente más cercano.

- Autodetección con `/proc/self/mountinfo` (o el fichero de `$PLEX_CREW_MOUNTINFO`, para pruebas): mount FUSE (`fuse*`) cuya fuente u opciones mencionan `rclone` o `zurg`. Ejemplo: `fuse.rclone zurg:` en `/ruta/a/zurg`. Un directorio padre que sea un bind normal del host (p. ej. ext4) no se ve como FUSE y no se detecta solo.
- Lista configurable de rutas: `$PLEX_CREW_ZURG_MOUNTS` (separadas por `:`) y `~/.claude/plex-crew/zurg-mounts.conf` (una ruta por línea, `#` comentarios). No hay valor por defecto: sin lista configurada, solo cuenta la autodetección FUSE. Ejemplo: `PLEX_CREW_ZURG_MOUNTS=/ruta/a/zurg`. Con la variable definida pero vacía tampoco hay lista.

Qué bloquea cuando el destino está en zurg: `mkdir`, `touch`, `tee`, `truncate`, `cp`, `install`, `ln`, `rsync`, `sed -i`, `dd of=`, `curl`/`wget` con salida a zurg, redirecciones `>` y `>>`, `mv` desde fuera del montaje (o desde otro montaje), y las tools `Write`, `Edit` y `NotebookEdit`. También analiza `bash -c`, `eval` y `$(...)`.

Qué permite: lecturas, `mv`/rename dentro del mismo montaje y cualquier cosa fuera de zurg. Los borrados no los cubre este hook sino `confirm-destructive.js`.

Excepción: rutas bajo la carpeta `__magic__` del montaje (p. ej. `/ruta/a/zurg/__magic__/...`). Con la lista configurable también vale `<ruta>/<carpeta existente>/__magic__`; un `__magic__` más profundo no cuenta.

Límites conocidos:

- Es análisis del texto del comando: no ve scripts (`bash x.sh`), ni lo que hagan programas por dentro, ni `chmod`/`chown` (no crean contenido).
- `python`/`node`/`perl`/`ruby` inline y `xargs`/`find -exec` solo se deniegan si mencionan zurg y un verbo de escritura.
- Rutas con variables sin resolver solo se deniegan si su texto menciona `zurg` o una ruta de la lista.
- Si el directorio de trabajo es desconocido (`cd $X`), las rutas relativas solo se vigilan si el `cd` menciona zurg.
- No cubre las tools `mcp__zurg__*` (las clasifica `confirm-destructive.js`).

## protected-paths.js

Regla permanente: las carpetas de sistema del NAS (QNAP u otro) no se tocan ni se leen. Se aplica a todos los agentes y a la sesión principal (no mira `agent_type`). Sin override: `PLEX_CREW_CONFIRMED=1` no lo salta. Hace cumplir la regla global de ignorar las carpetas `.@*` (skill `plex-crew-rules`).

Lista por defecto (sin distinguir mayúsculas): `@Recycle`, `@Recently-Snapshot`, `@Transcode`, `@Download`, `@eaDir`, `#recycle`, `#snapshot` y cualquier componente que empiece por `.@` (p. ej. `.@__thumb`).

Ampliar la lista (suma a la de por defecto, no la sustituye):

- `$PLEX_CREW_PROTECTED_NAMES`: nombres separados por `:`.
- `~/.claude/plex-crew/protected-names.conf`: un nombre por línea, `#` comentarios. Un nombre es un componente de ruta, sin `/`.

Criterio de coincidencia: una ruta está protegida si alguno de sus componentes (separados por `/`) es un nombre protegido. Se mira la ruta tal cual y también resuelta (`..` y enlaces simbólicos, usando el ancestro existente más cercano), así que `x/../@Recycle` y un enlace hacia esas carpetas se detectan. Ejemplo de denegación: `ls /ruta/a/medios/@Recycle`.

- `Bash`: cuenta cada palabra del comando (tras quitar comillas, también el valor de `--opcion=ruta` y `of=ruta`, redirecciones `>` y `<`, `$(...)`, `bash -c` y `eval`) que, vista como ruta, tenga un componente protegido, o sea exactamente el nombre (`ls @Recycle`). Se sigue `cd`, y un directorio de trabajo dentro de una carpeta protegida también deniega. Cualquier verbo vale: `ls`, `cat`, `find <ruta>`, `rm`, `mv`/`cp` desde o hacia ellas, `touch`, etc.
- `Read` (`file_path`), `Glob` (`path` y `pattern`), `Grep` (`path` y `glob`), `Edit`/`Write` (`file_path`) y `NotebookEdit` (`notebook_path`): se mira solo la ruta.
- No cuenta: texto suelto con espacios (`echo "ver @Recycle en el README"`), mensajes de `git commit -m`, cuerpos de heredoc, el contenido de `Write`/`Edit` y el `pattern` de `Grep`. Tampoco el marcador `@zurg` del scope ni un fichero llamado `Recycle.txt`.

Límites: un `find /volumen` o un `Glob`/`Grep` recursivo desde una carpeta padre puede recorrer esas carpetas sin nombrarlas y el hook no lo ve; las skills y los agentes deben excluirlas (`-not -path '*/@Recycle/*'`, `--exclude-dir`...). No ve scripts (`bash x.sh`), variables sin resolver ni lo que hagan los programas por dentro. Es una red de seguridad contra errores, no un sandbox.

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

Recomendación para zurg: usa el marcador `@zurg/movies` y `@zurg/shows` (ver abajo) o lista `.../zurg/movies` y `.../zurg/shows` a mano; no la raíz de zurg, que abriría `__all__`, `__magic__`, `__realdebrid__` y el resto de carpetas virtuales.

Limitación: este hook solo limita las rutas; no impide `mkdir` ni `touch` dentro de las rutas permitidas. Dentro de un montaje de zurg lo impone `zurg-mount.js` (sección siguiente), para todos los agentes.

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

#### Marcador `@zurg`

Una línea `@zurg/<subruta>` (p. ej. `@zurg/movies`) se sustituye por `<montaje>/<subruta>` para cada montaje de zurg detectado, con la misma detección que `zurg-mount.js` (módulo compartido `hooks/zurg-mounts.js`): mounts FUSE de `/proc/self/mountinfo` cuya fuente u opciones mencionan `rclone` o `zurg`, más la lista `$PLEX_CREW_ZURG_MOUNTS` / `~/.claude/plex-crew/zurg-mounts.conf` (sin valor por defecto: sin lista, solo autodetección). Lo leen `enforce-agent-scope.js` y `confirm-destructive.js`. Reglas:

- `@zurg` solo vale como primer componente: `@zurg` o `@zurg/<subruta>`. La subruta son nombres planos (letras, cifras, `_ . @ + -`); `..`, `~`, variables, comodines u otros caracteres hacen que la línea se ignore (el resto del fichero sigue valiendo). `/abs/@zurg/x` o `@zurgx/y` no son el marcador (se tratan como rutas normales).
- Cada expansión solo cuenta si existe ya como directorio; si no, se descarta. Por eso, si el montaje configurado es un directorio padre donde `movies` no cuelga directamente (p. ej. `/ruta/a`), `@zurg/movies` no abre nada, mientras que con el montaje real (`/ruta/a/zurg`) resuelve a `/ruta/a/zurg/movies`. Con montajes anidados (`.../zurg` y `.../zurg/zurg`) se expande a cada uno si la carpeta existe en él.
- Sin ningún montaje que resuelva, la línea no abre nada (fallo cerrado).
- `movies` y `shows` son los nombres por defecto de zurg para sus carpetas de contenido. Si los cambiaste en la configuración de zurg, escribe tus nombres (`@zurg/<tu-nombre>`) o la ruta absoluta.
- Solo se abre lo que escribes: `@zurg/movies` no da acceso a `__magic__`, `__all__`, `__realdebrid__` ni a `shows`. Evita `@zurg` a secas: abre la raíz entera del montaje.
- Las rutas absolutas siguen funcionando igual y se pueden mezclar con el marcador.

La ruta por defecto cuelga de `~/.claude` y no de `~/.config` porque en contenedores `~/.claude` suele ser un volumen persistente, mientras que `~/.config` no.

`scope.conf` lo leen **ambos** hooks y los dos fallan cerrados si falta o no tiene rutas:

- `enforce-agent-scope`: deniega toda escritura a `plex-naming`, con un mensaje que explica cómo crearlo.
- `confirm-destructive`: deniega las operaciones destructivas de fichero, porque sin las raíces de medios no puede decidir qué vigilar.

La plantilla usa rutas ficticias (`/ruta/a/plex/{movies,shows,anime,music}`); sustitúyelas por tus raíces.

Comportamiento a tener presente:

- `mv` dentro de las raíces de medios está permitido a propósito: es la operación de renombrado.
- El marcador `PLEX_CREW_CONFIRMED=1` debe ir al inicio del mismo segmento del comando que la operación destructiva (los segmentos se separan con `;`, `&&`, `||` o `|`). Si va en otro segmento, no cuenta.

## Cobertura de las tools MCP de zurg

Los tres hooks (`confirm-destructive`, `enforce-agent-scope`, `log-action`) también se registran sobre `mcp__zurg__.*` en `hooks/hooks.json`. Requisito: el MCP de zurg debe estar registrado con el nombre `zurg`; con otro nombre las tools no casan con el matcher y se saltan los hooks. La clasificación vive en `hooks/zurg-tools.js` y es por NOMBRE de tool (sin el prefijo `mcp__zurg__`):

- Solo lectura (pasa): `server_info`, `library_status`, `library_directories`, `provider_health`, `zurg_library_search`, `zurg_plex_match_release`, `zurg_plex_status`, `zurg_repair_status`, `zurg_mount_status`, `zurg_clients_paths`.
- Renombrado (pasa sin marcador y queda en el log): `zurg_release_rename`, `zurg_release_files_rename`. Para `plex-naming`, `enforce-agent-scope` además comprueba contra `scope.conf` las rutas del input (valores con `/` en campos como `path`, `from`, `to`, `new_path`, `old_path`, `src`, `dest`, `target`, `directory`, `file`, anidados incluidos). Si no hay ninguna ruta reconocible, deniega (fallo cerrado): una tool que renombra por hash y nombre, sin ruta, queda bloqueada para `plex-naming` y la ejecuta otro agente.
- Todo lo demás (`zurg_config_set`, `zurg_magic_move`, `zurg_repair_broken`, `zurg_repair_sweep`, `zurg_release_set_external_id`, `zurg_plex_match_all`, `zurg_plex_scan_*`, `zurg_plex_guard`, la tool de Season Fix y cualquier nombre desconocido) se deniega salvo que el texto `PLEX_CREW_CONFIRMED=1` aparezca en algún valor de texto del input (no en las claves), tras la doble confirmación. Hay que ponerlo en un campo de texto libre del esquema (nota, motivo...). Si la tool no tiene ninguno, no se puede confirmar y el orquestador lo gestiona. Las tools que no consten en la lista, incluidas las marcadas "por confirmar" en la skill con otro nombre, fallan cerradas.

No se ha adivinado ningún esquema: los nombres salen de la tabla de `skills/zurg/SKILL.md`. Por verificar con el MCP real: nombres exactos de las tools "por confirmar", si `zurg_plex_match_all`/`scan_*`/`set_external_id` deben pasar sin marcador, qué campos de ruta usan los renombrados, y si hay un campo de texto libre donde poner el marcador.

`log-action` anota el nombre completo de la tool y el input en JSON (máx. 300 caracteres) con la redacción habitual, más la de pares `{"key":"<nombre secreto>","value":...}`.

## Hooks de log

`log-action.js` se registra como `PostToolUse` y `PostToolUseFailure` (matcher `Bash|Edit|Write|NotebookEdit|mcp__zurg__.*`, timeout 5 s) y añade una línea por acción, de cualquier agente (hilo principal incluido), a `~/.claude/plex-crew/logs/<AAAA-MM-DD>-auto.log`. La fecha y la hora son las locales de la máquina (zona horaria del sistema), y la zona entre paréntesis es la que resuelve la propia máquina. Formato de línea:

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
- Solo ve las cuatro tools de la lista de `enforce-agent-scope` (arriba) y las `mcp__zurg__*`; no controla ninguna otra.
- `confirm-destructive` trabaja sobre el texto del comando; una operación destructiva que no case con los patrones pasa.
- `enforce-agent-scope` solo cubre a `plex-naming`.

## Límites conocidos

`confirm-destructive` es una red de seguridad contra errores, no un sandbox: analiza el texto del comando y no ejecuta ni resuelve nada. No detecta, entre otros:

- Verbo tomado de una variable: `f=rm; $f -rf ruta`.
- Borrado desde otro lenguaje: `python -c "import shutil; shutil.rmtree('ruta')"`.
- Verbo oculto tras un `alias`.

Para esas vías, el control real son los permisos de Claude Code y el alcance de las rutas montadas.
