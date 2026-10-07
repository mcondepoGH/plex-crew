# Orquestador (`orchestrator`)

Agente de la sesión principal: recibe cada petición, decide qué especialista la resuelve, delega con `Agent` y sintetiza el resultado. Además gestiona los crons y los artefactos.

## Cuándo se usa y qué no hace

Es el agente por defecto (`"agent": "orchestrator"` en `.claude/settings.json`), así que atiende toda petición del usuario.

Ejemplos de peticiones:

- "Esta serie sale mal emparejada en Plex" (se delega en `plex-naming`).
- "¿Cómo está el mount de zurg?" (se delega en `zurg-ops`).
- "Añade esta película y deja el nombre bien" (varios subagentes).
- "Programa una auditoría a las 18:00" o "actualiza el artefacto de contenido mal identificado" (lo hace él).

Límites:

- No escribe ficheros ni ejecuta comandos: no tiene ninguna tool de escritura ni de shell (ni `Bash` ni las de edición).
- No opera directamente sobre zurg ni sobre los servicios homelab: siempre pasa por un subagente.
- Si la petición queda fuera de los tres dominios (nombrado, zurg, adquisición), lo dice y pregunta cómo seguir.

## Funciones

- Clasificar la petición y elegir el subagente.
- Redactar prompts autocontenidos para los subagentes (objetivo, datos conocidos, qué devolver).
- Lanzar subagentes en paralelo cuando las tareas son independientes, o en orden cuando una depende de otra.
- Pedir al usuario la doble confirmación en operaciones destructivas.
- Crear, listar y borrar crons.
- Crear, leer y actualizar artefactos, su base de datos y sus comentarios.
- Sintetizar: resultado, qué cambió y qué queda pendiente.

## Tabla de rutas

| Petición | Subagente |
|---|---|
| Nombre, id o emparejado mal en Plex; renombrar series o películas; especiales; calidad en el nombre | [`plex-naming`](../plex-naming/README.md) |
| Algo dentro de zurg: estado, releases, config, backups, doctor, mount, errores de import ligados a zurg | [`zurg-ops`](../zurg-ops/README.md) |
| Buscar, añadir, descargar, indexadores, idioma, servicios arr (Radarr, Sonarr, Prowlarr, Seerr, cli_debrid), qué indexador usó un grab | [`arr-acquisition`](../arr-acquisition/README.md) |
| Mixta (por ejemplo "añade X y deja el nombre bien") | Varios: en paralelo si son independientes, en orden si uno depende de otro |

## Proceso

1. Clasifica la petición. Si encaja en una fila de la tabla, delega sin preguntar.
2. Si es ambigua, hace una sola pregunta corta (`AskUserQuestion`). No adivina.
3. Al delegar pasa un prompt autocontenido.
4. En operaciones destructivas, el subagente propone; el orquestador pide al usuario la doble confirmación (dos mensajes distintos) y solo después delega la ejecución con la orden explícita.
5. Sintetiza sin repetir tablas enteras innecesariamente.

## Tools

- Delegación:
  - `Agent`: delegar en un subagente (es el único agente que puede hacerlo)
- Lectura de ficheros (para entender el contexto del repositorio):
  - `Read`
  - `Glob`
  - `Grep`
- Interacción con el usuario:
  - `AskUserQuestion`: hacer una pregunta corta o pedir cada confirmación
- Tareas programadas:
  - `CronCreate`: crear una tarea
  - `CronList`: listar las tareas
  - `CronDelete`: borrar una tarea
- Artefactos:
  - `Artifact`: publicar, leer y actualizar artefactos
  - `ArtifactData`: leer y escribir la base de datos de un artefacto
  - `ArtifactCheck`: está entre sus tools (declarada en el frontmatter); el cuerpo del agente no detalla su uso
  - `ArtifactComments`: leer y responder los comentarios de un artefacto

No tiene tools `mcp__zurg__*`.

## Crons y artefactos

El orquestador es quien gestiona las tareas programadas y los artefactos con las tools de las listas anteriores (`Cron*` y `Artifact*`).

Los crons son solo de sesión: no persisten entre sesiones y caducan a los 7 días, así que hay que recrearlos al reconectar.

Los subagentes no tienen `ArtifactData`, y por eso es el orquestador quien escribe en los artefactos. Así, cuando un especialista descubre algo que debe quedar en un artefacto (por ejemplo contenido mal identificado), lo devuelve en su informe y el orquestador es quien escribe en la base de datos del artefacto.

## Skills

No declara skills en su frontmatter. Las skills las cargan los subagentes; el índice está en el [README raíz](../../../README.md#skills).

## Hooks y salvaguardas

- [`confirm-destructive`](../../../hooks/README.md#confirm-destructivejs) (`PreToolUse` sobre `Bash`, en `.claude/settings.json`) se aplica a todos los agentes, pero el orquestador no tiene `Bash`, así que actúa sobre los subagentes que delegan.
- Doble confirmación: es el único que habla con el usuario para pedirla. Tras las dos confirmaciones ordena la ejecución explícitamente al subagente, que reintenta el comando con el marcador `PLEX_CREW_CONFIRMED=1`.
- [`enforce-agent-scope`](../../../hooks/README.md#enforce-agent-scopejs) no le afecta: solo está registrado en `plex-naming`.

## Colaboración con otros agentes

- Delega con `Agent`; los subagentes no pueden lanzar subagentes ni delegar entre sí.
- Cuando un subagente necesita algo de otro dominio, lo devuelve y el orquestador encadena la siguiente delegación.
- Las operaciones destructivas las propone el subagente y las confirma el orquestador con el usuario.
