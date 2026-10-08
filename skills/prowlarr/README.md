# Skill de Prowlarr

Busca en todos tus indexadores y gestiona Prowlarr.

## Qué hace

- **Búsqueda de releases** en todos los indexadores (torrents + usenet)
- **Filtrado por tipo** (solo torrents, solo usenet) o por categoría (Películas, TV, etc.)
- **Búsqueda de series y películas** por ID de TVDB, IMDB o TMDB
- **Gestión de indexadores** — activar, desactivar, probar y ver estadísticas
- **Sincronización con apps** — envía los cambios de indexadores a Sonarr/Radarr

## Configuración

### 1. Obtén tu clave de API

1. Abre la interfaz web de Prowlarr
2. Ve a **Settings → General → Security**
3. Copia tu **API Key**

### 2. Añade las credenciales al .env

Añade lo siguiente a `~/.claude/plex-crew/.env`:

```bash
PROWLARR_URL="http://localhost:9696"
PROWLARR_API_KEY="<your_api_key>"
```

Sustituye:
- `http://localhost:9696` por la URL de tu Prowlarr
- `<your_api_key>` por tu clave de API real

### 3. Pruébalo

```bash
./skills/prowlarr/scripts/prowlarr-api.sh status
```

## Ejemplos de uso

### Buscar releases

```bash
# Búsqueda básica
prowlarr-api.sh search "ubuntu 24.04"

# Solo torrents
prowlarr-api.sh search "inception" --torrents

# Solo usenet  
prowlarr-api.sh search "inception" --usenet

# Categoría de películas (2000)
prowlarr-api.sh search "inception" --category 2000
```

### Búsqueda de series y películas por ID

```bash
# Buscar por TVDB ID
prowlarr-api.sh tv-search --tvdb 71663 --season 1 --episode 1

# Buscar por IMDB ID
prowlarr-api.sh movie-search --imdb tt0111161
```

### Gestión de indexadores

```bash
# Listar todos los indexadores
prowlarr-api.sh indexers

# Consultar estadísticas de los indexadores
prowlarr-api.sh stats

# Probar todos los indexadores
prowlarr-api.sh test-all

# Sincronizar con Sonarr/Radarr
prowlarr-api.sh sync
```

## Categorías

| ID | Categoría |
|----|----------|
| 2000 | Películas |
| 5000 | TV |
| 3000 | Audio |
| 7000 | Libros |
| 1000 | Consolas |
| 4000 | PC |

## Variables de entorno

La skill carga las credenciales desde `~/.claude/plex-crew/.env`. También puedes sustituirlas temporalmente:

```bash
PROWLARR_URL="https://prowlarr.example.com" \
PROWLARR_API_KEY="your-api-key" \
./skills/prowlarr/scripts/prowlarr-api.sh status
```

## Referencia de la API

La documentación detallada de la API está en el directorio `references/`:

- **[Endpoints de la API](./references/api-endpoints.md)** - Referencia completa de endpoints
- **[Referencia rápida](./references/quick-reference.md)** - Operaciones habituales con ejemplos listos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Soluciones para errores de autenticación, conexión y otros errores comunes

## Resolución de problemas

**"Missing URL or API key"**
→ Comprueba que tu fichero `.env` exista en `~/.claude/plex-crew/.env` y contenga `PROWLARR_URL` y `PROWLARR_API_KEY`

**Connection refused**
→ Verifica que la URL de tu Prowlarr sea correcta y accesible

**401 Unauthorized**
→ Tu clave de API no es válida: regénerala en los ajustes de Prowlarr

## Licencia

MIT
