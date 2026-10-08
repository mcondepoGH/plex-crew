# Nombrado de Plex (`plex-naming`)

Especialista en nombres de Plex: renombra series y películas con el formato de Plex y corrige emparejados erróneos.

## Cuándo se usa y qué no hace

Ejemplos:

- "Esta serie sale como otra en Plex."
- "Normaliza los nombres de la carpeta de esta serie a `SxxExx`."
- "Añade el id `{imdb-...}` a esta película."
- "Pon los especiales como `S00Exx`."

Límites:

- No borra nada. Si hace falta borrar, devuelve la propuesta al orquestador.
- No lanza escaneos de Plex tras renombrar.
- No toca duplicados de episodio o temporada.
- Solo escribe bajo las rutas de `scope.conf`; si el hook deniega una ruta, no intenta rodearlo y lo devuelve al orquestador.

## Funciones

- Renombrar carpetas y ficheros de series y películas según `plex-naming-rules`:
  - `SxxExx`
  - ids `{imdb-...}`
  - calidad
  - especiales `S00Exx`
- Detectar y corregir emparejados erróneos renombrando carpeta y fichero con el nombre completo y el id al final, y comprobando el título y el año con la skill `plex` (`search` o `metadata`).
- Localizar las bibliotecas locales con la skill `plex` (comando `libraries`).
- Añadir la calidad al nombre solo si el nombre original ya la define; no se comprueba contra el fichero.
- Probar con un solo elemento y pedir segunda confirmación antes del resto en renombrados masivos.
- Terminar con una tabla: nombre anterior, nombre nuevo y ubicación (movies o shows).

## Tools

- Lectura de ficheros:
  - `Read`: leer ficheros
  - `Glob`: localizar ficheros por patrón
  - `Grep`: buscar contenido
- Escritura y shell:
  - `Bash`: comandos de shell (por ejemplo, renombrados locales); sujeto a ambos hooks
  - `Edit`: editar ficheros; sujeto a `enforce-agent-scope`

## Skills que usa

- [`plex-crew-rules`](../../skills/plex-crew-rules/README.md)
- [`plex-naming-rules`](../../skills/plex-naming-rules/README.md)
- [`plex`](../../skills/plex/README.md)

## Hooks y salvaguardas

| Salvaguarda | Efecto |
|---|---|
| [`confirm-destructive`](../../hooks/README.md#confirm-destructivejs) | Deniega comandos `Bash` destructivos salvo que lleven `PLEX_CREW_CONFIRMED=1`, que solo se pone tras la doble confirmación |
| [`enforce-agent-scope`](../../hooks/README.md#enforce-agent-scopejs) | Registrado en `hooks/hooks.json` (plugin) para las cuatro tools que detalla el README de hooks; solo restringe a este agente, detectado por `agent_type`. Solo deja escribir bajo las rutas de `scope.conf` |
| Doble confirmación | Dos mensajes distintos del usuario antes de cualquier operación destructiva, incluso en modo automático |

`scope.conf` se busca en `$PLEX_CREW_CONFIG` o, si no existe, en `~/.claude/plex-crew/scope.conf` (plantilla: `scope.conf.example`). Admite una ruta absoluta por línea, comentarios con `#` y `~`. Sin rutas, el hook deniega toda escritura. Ante la duda (sustituciones, `eval`, `xargs`, intérpretes...) también deniega. No es un sandbox.

## Colaboración con otros agentes

- Lo invoca el orquestador con `Agent`; no lanza subagentes.
- Si necesita otro dominio (por ejemplo añadir contenido), lo devuelve al orquestador.
- Las operaciones destructivas las propone y el orquestador pide la doble confirmación.
