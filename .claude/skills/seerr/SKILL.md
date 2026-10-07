---
name: seerr
description: Gestión de solicitudes en Overseerr/Seerr. Úsala cuando el usuario pida "busca en seerr", "pide esta película", "pide esta serie", "solicitudes pendientes", "estado de seerr", "logs de seerr", "overseerr", o mencione la gestión de solicitudes.
---

# Skill de gestión de solicitudes en Seerr

**INVOCACIÓN OBLIGATORIA DE LA SKILL**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "busca en seerr", "pide esta película", "pide esta serie", "solicitar una película o serie"
- "solicitudes pendientes", "solicitudes aprobadas", "estado de seerr", "logs de seerr"
- Cualquier mención de Seerr, Overseerr o de la gestión de solicitudes

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Busca títulos, crea solicitudes de películas y series en Seerr, lista las solicitudes y consulta su estado y sus logs.

## Propósito

Esta skill permite operar Seerr (compatible con Overseerr y Jellyseerr):
- Buscar títulos y ver si ya están en Seerr
- Pedir películas y series, completas o por temporadas
- Listar solicitudes pendientes, aprobadas o todas
- Consultar la versión y los logs de Seerr

Hay operaciones de lectura y de escritura. **Confirma siempre con el usuario antes de crear una solicitud.**

## Configuración

Añade las credenciales al `.env` (raíz del repo):

```bash
SEERR_URL="http://localhost:5055"
SEERR_API_KEY="tu-api-key"
```

- `SEERR_URL`: URL de tu servidor Seerr (sin barra final)
- `SEERR_API_KEY`: clave de API de Seerr (Settings → General)

## Comandos

Solo `status` devuelve JSON; el resto imprime texto. Sin comando muestra la ayuda (código 0); un comando desconocido la muestra y sale con 1. Si falta un argumento obligatorio o un id no es numérico, imprime el uso y sale con 1. Una respuesta HTTP que no sea 2xx imprime `ERROR:` por stderr y sale con 1.

### Buscar y consultar

```bash
bash .claude/skills/seerr/scripts/seerr.sh search "Dune"
bash .claude/skills/seerr/scripts/seerr.sh status
bash .claude/skills/seerr/scripts/seerr.sh requests approved
bash .claude/skills/seerr/scripts/seerr.sh logs 20 error
```

**Salida:** `search` imprime una línea por resultado (tipo, id de TMDB, título, año y estado en Seerr). `requests` imprime hasta 50 solicitudes (id, tipo, TMDB, estado y solicitante). `logs` imprime `fecha [nivel] etiqueta: mensaje`. `status` devuelve el JSON con la versión.

### Pedir una película

```bash
bash .claude/skills/seerr/scripts/seerr.sh request-movie <tmdbId>
```

**Confirma con el usuario antes de pedir.** La solicitud es real y, según la configuración de Seerr, puede aprobarse sola y enviarse a Radarr. **Salida:** texto con el id de la solicitud y su estado. Si ya existe una solicitud para ese título, Seerr responde con un 4xx (normalmente 409) y el script imprime el error y sale con 1: avisa al usuario de que es un duplicado.

### Pedir una serie

```bash
bash .claude/skills/seerr/scripts/seerr.sh request-tv <tmdbId>          # Todas las temporadas
bash .claude/skills/seerr/scripts/seerr.sh request-tv <tmdbId> 1,2      # Solo las temporadas 1 y 2
```

**Confirma con el usuario antes de pedir**, con el mismo criterio y la misma gestión de duplicados que en las películas. Las temporadas son una lista de números separados por comas. La solicitud puede enviarse a Sonarr.

## Flujo de trabajo

1. **"Pide Dune"** → ejecuta `search "Dune"`, presenta los resultados con su id de TMDB y el estado en Seerr, confirma cuál quiere y ejecuta `request-movie <tmdbId>`
2. **"Pide Breaking Bad entera"** → busca el id de TMDB y ejecuta `request-tv <tmdbId>` tras confirmar
3. **"¿Qué hay pendiente?"** → ejecuta `requests pending`
4. **"¿Por qué falla Seerr?"** → ejecuta `logs 50 error`

Si el resultado de `search` ya trae un estado de Seerr distinto de `none`, el título ya está solicitado o disponible: dilo antes de pedir.

## Parámetros

### Comando requests
- `[filtro]`: `pending` (por defecto), `approved` o `all`

### Comando logs
- `[n]`: número de entradas (50 por defecto)
- `[nivel]`: `debug`, `info`, `warn` o `error`

### Comando request-tv
- `<tmdbId>`: id de TMDB de la serie (obligatorio)
- `[temporadas]`: lista separada por comas, por ejemplo `1,2` (por defecto, todas)

## Notas

- Los ids son de TMDB, los mismos que usa la skill `radarr`; `sonarr` usa TVDB, así que para una serie localiza antes su id de TMDB
- Usa la API `v1` de Seerr
- Solo `status` devuelve JSON; el resto es texto
- `requests` se limita a 50 resultados

## Referencia

- [Documentación de Overseerr](https://docs.overseerr.dev/)
- [TMDB](https://themoviedb.org/): The Movie Database
