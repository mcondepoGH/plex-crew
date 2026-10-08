---
name: seerr
description: Esta skill debe usarse cuando se gestionen solicitudes de contenido en Overseerr/Seerr. Úsala cuando el usuario pida "buscar en Seerr", "solicitar una película", "solicitar una serie", "solicitudes pendientes", "estado de Seerr", "logs de Seerr", "Overseerr", o mencione la gestión de solicitudes.
---

# Skill de gestión de solicitudes de Seerr

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "buscar en Seerr", "solicitar una película", "solicitar una serie", "pedir esta serie"
- "solicitudes pendientes", "solicitudes aprobadas", "estado de Seerr", "logs de Seerr"
- Cualquier mención de Seerr, Overseerr o la gestión de solicitudes

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Busca títulos, crea solicitudes de películas y series en Seerr, lista las solicitudes y consulta su estado y los logs.

## Propósito

Esta skill permite operar Seerr (compatible con Overseerr y Jellyseerr):
- Buscar títulos y ver si ya están en Seerr
- Solicitar películas y series, completas o por temporada
- Listar las solicitudes pendientes, aprobadas o todas
- Consultar la versión de Seerr y sus logs

Las operaciones incluyen acciones de lectura y de escritura. **Confirma siempre con el usuario antes de crear una solicitud.**

## Configuración

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
SEERR_URL="http://localhost:5055"
SEERR_API_KEY="your-api-key"
```

- `SEERR_URL`: URL de tu servidor Seerr (sin barra final)
- `SEERR_API_KEY`: clave de API de Seerr (Settings → General)

## Ejecución del script

El script está en `${CLAUDE_PLUGIN_ROOT}/skills/seerr/scripts/seerr.sh`. Llámalo con su ruta absoluta para no alterar el directorio de trabajo de la sesión.

## Comandos

Solo `status` devuelve JSON; el resto imprime texto plano. Sin comando muestra la ayuda (código de salida 0); un comando desconocido la muestra y termina con 1. Un argumento obligatorio ausente o un id no numérico imprime el uso y termina con 1. Una respuesta HTTP no 2xx imprime `ERROR:` en stderr y termina con 1.

### Búsqueda y consulta

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/seerr/scripts/seerr.sh" search "Dune"
bash "${CLAUDE_PLUGIN_ROOT}/skills/seerr/scripts/seerr.sh" status
bash "${CLAUDE_PLUGIN_ROOT}/skills/seerr/scripts/seerr.sh" requests approved
bash "${CLAUDE_PLUGIN_ROOT}/skills/seerr/scripts/seerr.sh" logs 20 error
```

**Salida:** `search` imprime una línea por resultado (tipo, id de TMDB, título, año y estado en Seerr). `requests` imprime hasta 50 solicitudes (id, tipo, TMDB, estado y solicitante). `logs` imprime `timestamp [level] label: message`. `status` devuelve el JSON con la versión.

### Solicitar una película

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/seerr/scripts/seerr.sh" request-movie <tmdbId>
```

**Confirma con el usuario antes de solicitar.** La solicitud es real y, según la configuración de Seerr, puede aprobarse automáticamente y enviarse a Radarr. **Salida:** texto con el id de la solicitud y su estado. Si ya existe una solicitud para ese título, Seerr responde con un 4xx (normalmente 409) y el script imprime el error y termina con 1: indica al usuario que es un duplicado.

### Solicitar una serie

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/seerr/scripts/seerr.sh" request-tv <tmdbId>          # Todas las temporadas
bash "${CLAUDE_PLUGIN_ROOT}/skills/seerr/scripts/seerr.sh" request-tv <tmdbId> 1,2      # Solo las temporadas 1 y 2
```

**Confirma con el usuario antes de solicitar**, con los mismos criterios y el mismo tratamiento de duplicados que para las películas. Las temporadas son una lista de números separados por comas. La solicitud puede enviarse a Sonarr.

## Flujo de trabajo

Cuando el usuario pregunte por solicitudes:

1. **"Solicita Dune"** → Ejecuta `search "Dune"`, presenta los resultados con su id de TMDB y su estado en Seerr, confirma cuál quiere y ejecuta `request-movie <tmdbId>`
2. **"Solicita todo Breaking Bad"** → Busca el id de TMDB, confirma y ejecuta `request-tv <tmdbId>`
3. **"¿Qué hay pendiente?"** → Ejecuta `requests pending`
4. **"¿Por qué falla Seerr?"** → Ejecuta `logs 50 error`

Si el resultado de `search` ya muestra un estado en Seerr distinto de `none`, el título ya está solicitado o disponible: dilo antes de solicitar.

## Parámetros

### Comando requests
- `[filter]`: `pending` (por defecto), `approved` o `all`

### Comando logs
- `[n]`: número de entradas (por defecto: 50)
- `[level]`: `debug`, `info`, `warn` o `error`

### Comando request-tv
- `<tmdbId>`: id de TMDB de la serie (obligatorio)
- `[seasons]`: lista separada por comas, por ejemplo `1,2` (por defecto: todas)

## Notas

- Los ids son ids de TMDB, los mismos que usa la skill `radarr`; `sonarr` usa TVDB, así que para una serie busca primero su id de TMDB
- Usa la API v1 de Seerr
- Solo `status` devuelve JSON; todo lo demás es texto
- `requests` está limitado a 50 resultados
- Requiere `curl` y `jq` instalados

## Referencia

- [Documentación de Overseerr](https://docs.overseerr.dev/)
- [TMDB](https://themoviedb.org/) — The Movie Database

Para la referencia local detallada, consulta:
- **[Endpoints de la API](./references/api-endpoints.md)** - Referencia completa de endpoints con parámetros
- **[Referencia rápida](./references/quick-reference.md)** - Operaciones habituales con ejemplos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Soluciones para autenticación, conexión y errores
