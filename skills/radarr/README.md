# Skill de Radarr

Busca y añade películas a tu biblioteca de Radarr.

## Qué hace

- **Búsqueda** — Encuentra películas por nombre mediante TMDB
- **Alta** — Añade películas a tu biblioteca de Radarr con búsqueda automática
- **Colecciones** — Añade colecciones de películas completas de una vez
- **Comprobación** — Verifica si una película ya existe en tu biblioteca
- **Baja** — Elimina películas de tu biblioteca (con borrado opcional de archivos)
- **Configuración** — Consulta carpetas raíz y perfiles de calidad

Todas las operaciones usan la API v3 de Radarr y admiten detección de colecciones y búsqueda al añadir.

## Configuración

### 1. Obtén tu clave de API de Radarr

1. Abre la interfaz web de Radarr
2. Ve a **Settings → General**
3. Desplázate a la sección **Security**
4. Copia tu **API Key**

### 2. Configura las variables de entorno

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
RADARR_URL="http://localhost:7878"
RADARR_API_KEY="<your_api_key>"
RADARR_DEFAULT_QUALITY_PROFILE="1"  # Optional (defaults to 1)
```

**Opciones de configuración:**
- `RADARR_URL`: URL del servidor Radarr (por defecto http://localhost:7878)
- `RADARR_API_KEY`: tu clave de API de Radarr
- `RADARR_DEFAULT_QUALITY_PROFILE`: ID del perfil de calidad para las películas nuevas (opcional, ejecuta el comando `config` para ver los perfiles disponibles)

### 3. Pruébalo

```bash
bash scripts/radarr.sh search "Inception"
```

## Ejemplos de uso

### Buscar películas

```bash
bash scripts/radarr.sh search "Inception"
bash scripts/radarr.sh search "The Matrix"
```

Devuelve una lista numerada con IDs de TMDB, información de la colección y enlaces.

### Comprobar si una película existe

Antes de añadir, comprueba si la película ya está en tu biblioteca:

```bash
bash scripts/radarr.sh exists 27205  # TMDB ID de Inception
```

### Añadir una película

Añade una película con búsqueda automática (por defecto):

```bash
bash scripts/radarr.sh add 27205  # Busca de inmediato
```

Añade sin buscar (búsqueda manual posterior):

```bash
bash scripts/radarr.sh add 27205 --no-search
```

### Añadir una colección completa

Si una película pertenece a una colección (p. ej., Marvel Cinematic Universe, Star Wars), puedes añadir la colección entera:

```bash
bash scripts/radarr.sh add-collection 86311  # Marvel Cinematic Universe
```

Sin buscar:

```bash
bash scripts/radarr.sh add-collection 86311 --no-search
```

### Eliminar una película

Elimina conservando los archivos descargados:

```bash
bash scripts/radarr.sh remove 27205
```

Elimina y borra todos los archivos:

```bash
bash scripts/radarr.sh remove 27205 --delete-files
```

**Pregunta siempre al usuario si quiere borrar los archivos al eliminar.**

### Ver la configuración

Obtén las carpetas raíz y los perfiles de calidad disponibles:

```bash
bash scripts/radarr.sh config
```

Úsalo para determinar el ID de tu `defaultQualityProfile`.

## Referencia de la API

La documentación detallada de la API está en el directorio `references/`:

- **[Endpoints de la API](./references/api-endpoints.md)** - Referencia completa de endpoints
- **[Referencia rápida](./references/quick-reference.md)** - Operaciones habituales con ejemplos listos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Soluciones para errores de autenticación, conexión y otros errores comunes

## Flujo de trabajo

Cuando un usuario pida añadir una película:

1. **Buscar**: `bash scripts/radarr.sh search "Movie Name"`
2. **Presentar resultados**: incluye siempre enlaces de TMDB con el formato `[Title (Year)](https://themoviedb.org/movie/ID)`
3. **El usuario elige**: el usuario selecciona un número de los resultados
4. **Comprobar colección**: si la película pertenece a una colección, pregunta al usuario si quiere añadir la colección completa
5. **Comprobar existencia**: ejecuta `exists <tmdbId>` para verificar que no esté ya añadida
6. **Añadir**: ejecuta `add <tmdbId>` o `add-collection <collectionId>` para añadir e iniciar la búsqueda


## Resolución de problemas

**"Radarr not configured"**
→ Comprueba que tus credenciales existan en `~/.claude/plex-crew/.env` con las variables `RADARR_URL` y `RADARR_API_KEY`

**"Connection refused"**
→ Verifica que la URL de tu servidor Radarr sea correcta y que Radarr esté en ejecución

**401 Unauthorized**
→ Tu clave de API no es válida: revisa Settings → General → Security

**"Quality profile not found"**
→ Ejecuta `bash scripts/radarr.sh config` para ver los IDs de perfil disponibles

**Colección no encontrada**
→ No todas las películas pertenecen a una colección: revisa la información de colección en los resultados de búsqueda

## Notas

- Usa la API v3 de Radarr
- El perfil de calidad por defecto se puede sustituir en cada alta si hace falta
- Los resultados de búsqueda incluyen IDs de TMDB para una identificación fiable
- La detección de colecciones ayuda a organizar sagas y franquicias
- Admite ajustes de disponibilidad mínima (announced, in cinemas, released)
- Requiere `curl` y `jq` instalados

## Licencia

MIT
