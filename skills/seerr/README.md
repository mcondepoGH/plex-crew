# Skill de Seerr

Busca títulos y gestiona solicitudes de contenido en Seerr (compatible con Overseerr y Jellyseerr).

## Qué hace

- **Búsqueda** — Busca títulos y consulta su estado en Seerr
- **Solicitud** — Crea solicitudes de películas y series, completas o por temporada
- **Listado** — Muestra las solicitudes pendientes, aprobadas o todas
- **Estado** — Consulta la versión de Seerr
- **Logs** — Lee las últimas entradas del log, opcionalmente por nivel

Todas las operaciones usan la API v1 de Seerr. Se usan ids de TMDB en todo momento.

## Configuración

### 1. Obtén tu clave de API de Seerr

1. Abre la interfaz web de Seerr
2. Ve a **Settings → General**
3. Copia tu **API Key**

### 2. Configura las variables de entorno

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
SEERR_URL="http://localhost:5055"
SEERR_API_KEY="<your_api_key>"
```

**Opciones de configuración:**
- `SEERR_URL`: URL del servidor Seerr (la API se llama en `<SEERR_URL>/api/v1`)
- `SEERR_API_KEY`: tu clave de API de Seerr (se envía como `X-Api-Key`)
- `HOMELAB_ENV`: ruta opcional a otro fichero de entorno

### 3. Pruébalo

```bash
bash scripts/seerr.sh status
```

## Ejemplos de uso

### Buscar títulos

```bash
bash scripts/seerr.sh search "Dune"
```

Devuelve una línea por resultado con tipo, id de TMDB, título, año y estado en Seerr.

### Listar solicitudes

```bash
bash scripts/seerr.sh requests pending
bash scripts/seerr.sh requests approved
bash scripts/seerr.sh requests all
```

Devuelve hasta 50 solicitudes con id, tipo, id de TMDB, estado y solicitante.

### Solicitar una película

```bash
bash scripts/seerr.sh request-movie 438631
```

**¡Confirma siempre con el usuario antes de solicitar!**

### Solicitar una serie

Todas las temporadas:

```bash
bash scripts/seerr.sh request-tv 1396
```

Solo las temporadas 1 y 2:

```bash
bash scripts/seerr.sh request-tv 1396 1,2
```

### Leer los logs

```bash
bash scripts/seerr.sh logs 20 error
```

## Referencia de la API

La documentación detallada de la API está en el directorio `references/`:

- **[Endpoints de la API](./references/api-endpoints.md)** - Referencia completa de endpoints
- **[Referencia rápida](./references/quick-reference.md)** - Operaciones habituales con ejemplos listos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Soluciones para autenticación, conexión y errores habituales

## Flujo de trabajo

Cuando un usuario pida solicitar un título:

1. **Buscar**: `bash scripts/seerr.sh search "Title"`
2. **Presentar resultados**: incluye el id de TMDB y el estado en Seerr de cada resultado
3. **Comprobar el estado**: si el estado en Seerr no es `none`, el título ya está solicitado o disponible; díselo al usuario
4. **El usuario elige**: el usuario selecciona un resultado
5. **Confirmar**: pide al usuario que confirme la solicitud
6. **Solicitar**: ejecuta `request-movie <tmdbId>` o `request-tv <tmdbId> [seasons]`

## Resolución de problemas

**"faltan variables en el .env"**
→ Comprueba que tus credenciales existen en `~/.claude/plex-crew/.env` con las variables `SEERR_URL` y `SEERR_API_KEY`

**"Connection refused"**
→ Verifica que la URL de tu servidor Seerr es correcta y que Seerr está en ejecución

**401 o 403**
→ Tu clave de API no es válida; revisa Settings → General

**409 Conflict al solicitar**
→ Ya existe una solicitud para ese título; es un duplicado

## Notas

- Una solicitud puede aprobarse automáticamente y enviarse a Radarr o Sonarr según la configuración de Seerr
- El script no comprueba duplicados de antemano: Seerr los rechaza con un 4xx
- Cada comando comprueba el código HTTP: una respuesta no 2xx o un fallo de conexión imprime `ERROR:` en stderr y termina con 1
- Sin comando se muestra la ayuda (código de salida 0); un comando desconocido, un argumento ausente o un id no numérico termina con 1
- Requiere `curl` y `jq` instalados

## Licencia

MIT
