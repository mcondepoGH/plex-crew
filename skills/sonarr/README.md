# Skill de Sonarr

Busca y añade series de TV a tu biblioteca de Sonarr.

## Qué hace

- **Búsqueda** — Encuentra series por nombre mediante TVDB
- **Alta** — Añade series a tu biblioteca de Sonarr con búsqueda automática
- **Comprobación** — Verifica si una serie ya existe en tu biblioteca
- **Baja** — Elimina series de tu biblioteca (con borrado opcional de archivos)
- **Configuración** — Consulta carpetas raíz y perfiles de calidad

Todas las operaciones usan la API v3 de Sonarr y admiten opciones de monitorización y búsqueda al añadir.

## Configuración

### 1. Obtén tu clave de API de Sonarr

1. Abre la interfaz web de Sonarr
2. Ve a **Settings → General**
3. Desplázate a la sección **Security**
4. Copia tu **API Key**

### 2. Añade las credenciales al .env

Añade lo siguiente a `~/.claude/plex-crew/.env`:

```bash
SONARR_URL="http://localhost:8989"
SONARR_API_KEY="<your_api_key>"
SONARR_DEFAULT_QUALITY_PROFILE="1"  # Optional: defaults to 1 if not set
```

**Variables de configuración:**
- `SONARR_URL`: URL del servidor Sonarr (sin barra final)
- `SONARR_API_KEY`: tu clave de API de Sonarr
- `SONARR_DEFAULT_QUALITY_PROFILE`: ID del perfil de calidad (opcional, ejecuta el comando `config` para ver los perfiles disponibles)

### 3. Pruébalo

```bash
bash scripts/sonarr.sh search "Breaking Bad"
```

## Ejemplos de uso

### Buscar series

```bash
bash scripts/sonarr.sh search "Breaking Bad"
bash scripts/sonarr.sh search "The Office"
```

Devuelve una lista numerada con IDs de TVDB y enlaces.

### Comprobar si una serie existe

Antes de añadir, comprueba si la serie ya está en tu biblioteca:

```bash
bash scripts/sonarr.sh exists 81189  # TVDB ID de Breaking Bad
```

### Añadir una serie

Añade una serie con búsqueda automática (por defecto):

```bash
bash scripts/sonarr.sh add 81189  # Busca de inmediato
```

Añade sin buscar (búsqueda manual posterior):

```bash
bash scripts/sonarr.sh add 81189 --no-search
```

### Eliminar una serie

Elimina conservando los archivos descargados:

```bash
bash scripts/sonarr.sh remove 81189
```

Elimina y borra todos los archivos:

```bash
bash scripts/sonarr.sh remove 81189 --delete-files
```

**Pregunta siempre al usuario si quiere borrar los archivos al eliminar.**

### Ver la configuración

Obtén las carpetas raíz y los perfiles de calidad disponibles:

```bash
bash scripts/sonarr.sh config
```

Úsalo para determinar el ID de tu `SONARR_DEFAULT_QUALITY_PROFILE`.

## Referencia de la API

La documentación detallada de la API está en el directorio `references/`:

- **[Endpoints de la API](./references/api-endpoints.md)** - Referencia completa de endpoints
- **[Referencia rápida](./references/quick-reference.md)** - Operaciones habituales con ejemplos listos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Soluciones para errores de autenticación, conexión y otros errores comunes

## Flujo de trabajo

Cuando un usuario pida añadir una serie de TV:

1. **Buscar**: `bash scripts/sonarr.sh search "Show Name"`
2. **Presentar resultados**: incluye siempre enlaces de TVDB con el formato `[Title (Year)](https://thetvdb.com/series/SLUG)`
3. **El usuario elige**: el usuario selecciona un número de los resultados
4. **Comprobar**: ejecuta `exists <tvdbId>` para verificar que no esté ya añadida
5. **Añadir**: ejecuta `add <tvdbId>` para añadir la serie e iniciar la búsqueda

## Resolución de problemas

**"Sonarr not configured"**
→ Comprueba que tu fichero `.env` exista en `~/.claude/plex-crew/.env` y contenga SONARR_URL y SONARR_API_KEY

**"Connection refused"**
→ Verifica que la URL de tu servidor Sonarr sea correcta y que Sonarr esté en ejecución

**401 Unauthorized**
→ Tu clave de API no es válida: revisa Settings → General → Security

**"Quality profile not found"**
→ Ejecuta `bash scripts/sonarr.sh config` para ver los IDs de perfil disponibles

## Notas

- Usa la API v3 de Sonarr
- Las credenciales se cargan desde `~/.claude/plex-crew/.env` (SIN ficheros de configuración JSON)
- El perfil de calidad por defecto se puede sustituir en cada alta si hace falta
- Los resultados de búsqueda incluyen IDs de TVDB para una identificación fiable
- Admite todas las opciones de monitorización de Sonarr (future, all, none, etc.)
- Requiere `curl` y `jq` instalados

## Licencia

MIT
