---
name: agregarr
description: Esta skill debe usarse cuando se consulte o sincronice Agregarr, el gestor de colecciones de Plex. Úsala cuando el usuario pida "estado de Agregarr", "listar las colecciones de Agregarr", "sincronizar las colecciones", "sincronizar una colección de Agregarr", "estado de la sincronización de colecciones", "tareas programadas de Agregarr", "logs de Agregarr", "por qué no se actualiza una colección de Plex", o mencione Agregarr.
---

# Skill de gestión de colecciones de Agregarr

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "estado de Agregarr", "logs de Agregarr", "tareas programadas de Agregarr"
- "listar las colecciones de Agregarr", "colecciones configuradas"
- "sincronizar las colecciones", "sincronizar una colección de Agregarr"
- "estado de la sincronización de colecciones", "por qué no se actualiza una colección de Plex"
- Cualquier mención de Agregarr

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Consulta las colecciones, la sincronización, las tareas y los logs de Agregarr, y lanza sincronizaciones.

## Propósito

Agregarr gestiona colecciones y listas en Plex (Trakt, IMDb, TMDB, MDBList, Overseerr/Seerr, Radarr/Sonarr...). Esta skill permite:
- Comprobar la versión de Agregarr y que la clave de API es válida
- Listar las colecciones configuradas
- Ver el estado de la sincronización y de las tareas programadas
- Leer los logs
- Lanzar la sincronización de todas las colecciones, de una sola o de una tarea programada

Incluye acciones de lectura y de escritura. **Confirma con el usuario antes de `sync`, `sync-collection` y `run-job`.** No hay comandos para crear, modificar ni borrar colecciones: el borrado (`DELETE /collections/{id}`) existe en la API pero no se ha implementado a propósito, por ser destructivo.

## Configuración

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
AGREGARR_URL="http://localhost:7171"
AGREGARR_API_KEY="your-api-key"
```

- `AGREGARR_URL`: URL del servidor Agregarr (sin barra final)
- `AGREGARR_API_KEY`: clave de API de Agregarr (Settings → General)
- `AGREGARR_MAX_TIME` (opcional): tiempo máximo por petición en segundos (25 por defecto)

## Ejecución del script

El script está en `${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh`. Llámalo con su ruta absoluta para no alterar el directorio de trabajo de la sesión.

## Comandos

`collections --json` es el único modo que devuelve JSON; el resto imprime texto plano. Sin comando muestra la ayuda (código de salida 0); un comando desconocido la muestra y termina con 1. Un argumento obligatorio ausente o un id no válido imprime el uso y termina con 1. Una respuesta HTTP no 2xx, un timeout o la falta de credenciales imprimen `ERROR:` en stderr y terminan con 1.

### Estado

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" status
```

**Salida:** versión, si hay actualización o reinicio pendiente y, tras validar la clave con un endpoint autenticado, el número de colecciones. Si no hay conexión, imprime `Agregarr: DESCONECTADO (<url>)` y termina con 1.

### Colecciones

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" collections
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" collections --json
```

**Salida:** una línea por colección: `[id] nombre - origen:tipo/subtipo medio:... biblioteca:...`.

### Sincronización y tareas

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" sync-status
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" jobs
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" logs 20 error
```

**Salida:** `sync-status` indica si hay una sincronización en curso (etapa y progreso), la última global, el último error y las colecciones pendientes. `jobs` imprime `[id] nombre - próxima ejecución - en ejecución`. `logs` imprime `timestamp [level] label: message`.

### Sincronizar (escritura)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" sync
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" sync-collection 10000
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" run-job <jobId>
```

**Confirma con el usuario antes de ejecutar.** Modifican las colecciones de Plex (y pueden pedir contenido faltante a Seerr, Radarr o Sonarr según la configuración de cada colección). Se ejecutan en segundo plano: consulta `sync-status` después. **Salida:** el mensaje de Agregarr (`success: ...`) o el estado de la tarea.

## Flujo de trabajo

1. **"¿Funciona Agregarr?"** → `status`
2. **"¿Qué colecciones hay?"** → `collections`
3. **"Sincroniza las colecciones"** → confirma, `sync` y luego `sync-status` hasta que `En curso: false`
4. **"No se actualiza la colección X"** → `collections` para el id, `sync-status`, `logs 50 error`; si procede, confirma y `sync-collection <id>`
5. **"¿Cuándo corre la próxima sincronización?"** → `jobs`

## Parámetros

### Comando logs
- `[n]`: número de entradas (por defecto: 50)
- `[nivel]`: `debug`, `info`, `warn` o `error`

### Comando sync-collection
- `<id>`: id numérico de la colección (empiezan en 10000)

### Comando run-job
- `<jobId>`: id de la tarea, tal como lo muestra `jobs`

## Notas

- Usa la API v1 de Agregarr con la cabecera `X-Api-Key`
- `/status` es público: por eso `status` comprueba además `/collections`, que sí exige la clave
- Los endpoints de configuración (`/settings/plex`, `/settings/radarr`...) contienen claves de otros servicios: el script no los usa
- Los endpoints están tomados de `agregarr-api.yml` del repositorio (rama `develop`); en este entorno no hay Agregarr configurado, así que no se han verificado en vivo
- Requiere `curl` y `jq` instalados

## Referencia

- [Agregarr](https://github.com/agregarr/agregarr)
- [Especificación de la API](https://github.com/agregarr/agregarr/blob/develop/agregarr-api.yml)

Para la referencia local detallada, consulta:
- **[Endpoints de la API](./references/api-endpoints.md)** - Referencia de endpoints
- **[Referencia rápida](./references/quick-reference.md)** - Operaciones habituales con ejemplos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Soluciones para autenticación, conexión y pendientes
