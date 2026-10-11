# Skill de Prowlarr

Busca releases en los indexadores torrent y usenet de Prowlarr, comprueba su estado, los prueba, activa, desactiva o elimina, los sincroniza con Radarr y Sonarr, y consulta el log, desde la API v1.

## Qué hace

- **Buscar** — Por texto libre (`search`), por episodio con id de TVDB (`tv-search`) o por película con id de IMDb o TMDB (`movie-search`)
- **Indexadores** — Lista, estadísticas, prueba de uno o de todos
- **Gestionar** — Activar, desactivar o eliminar un indexador
- **Sincronizar** — Lista las aplicaciones conectadas y lanza la sincronización de indexadores hacia ellas
- **Sistema** — Estado, avisos de salud y últimas entradas del log (`logs`, solo lectura)

## Configuración

### 1. Obtén tu clave de API

1. Abre la interfaz web de Prowlarr
2. Ve a **Settings → General → Security**
3. Copia la **API Key**

### 2. Configura las variables de entorno

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
PROWLARR_URL="http://localhost:9696"
PROWLARR_API_KEY="<your_api_key>"
```

**Opciones de configuración:**
- `PROWLARR_URL`: URL de Prowlarr con puerto (la API se llama en `<PROWLARR_URL>/api/v1`); se quita una barra final
- `PROWLARR_API_KEY`: tu clave de API
- `PROWLARR_MAX_TIME`: opcional, segundos máximos por petición (30 por defecto)
- `PROWLARR_TESTALL_MAX_TIME`: opcional, segundos máximos de `test-all` (120 por defecto)

### 3. Pruébalo

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" status
```

Fuera de una sesión de Claude Code `${CLAUDE_PLUGIN_ROOT}` no existe: usa la ruta real del plugin.

## Ejemplos de uso

### Buscar

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" search "ubuntu 22.04"
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" search "inception" --category 2000 --torrents
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" tv-search --tvdb 71663 --season 1 --episode 1
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" movie-search --imdb tt0111161
```

Para Torrentio, el texto libre devuelve un título fijo: usa `movie-search` o `tv-search` con ids (ver la skill `arr-language-filters`).

### Revisar indexadores

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" indexers
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" stats
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" health
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" test 5
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" test-all
```

`test-all` puede tardar hasta 120 s.

### **Activar, desactivar y sincronizar**

Confirma con el usuario antes de activar, desactivar o sincronizar: `sync` empuja la configuración a Sonarr, Radarr y demás aplicaciones, y puede añadir o quitar indexadores allí.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" disable 5
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" enable 5
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" apps
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" sync
```

### **Eliminar un indexador**

Destructivo y permanente. El hook `confirm-destructive` bloquea `prowlarr-api.sh delete` sin `PLEX_CREW_CONFIRMED=1`, que solo se antepone tras la doble confirmación de la regla global (`plex-crew-rules`). Si solo hay que dejar de usarlo, prefiere `disable`.

```bash
PLEX_CREW_CONFIRMED=1 bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" delete 5
```

### Consultar el log

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" logs 20 --level warn
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" logs --grep "indexer"
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" logs --files
```

## Referencia de la API

- [Endpoints de la API](references/api-endpoints.md)
- [Referencia rápida](references/quick-reference.md)
- [Resolución de problemas](references/troubleshooting.md)
- [Wiki de Prowlarr](https://wiki.servarr.com/prowlarr)
- [Documentación de la API](https://prowlarr.com/docs/api/)

## Flujo de trabajo

1. `health` y `stats` para ver qué indexadores dan problemas
2. `test <id>` o `test-all` para confirmarlo
3. `disable <id>` tras confirmarlo con el usuario, y `sync` para que Radarr y Sonarr se enteren
4. `search`, `tv-search` o `movie-search` para localizar un release concreto

## Resolución de problemas

**ERROR: GET /system/status respondió HTTP 401**
→ Revisa `PROWLARR_API_KEY` en `~/.claude/plex-crew/.env`.

**ERROR: no se pudo contactar con Prowlarr en <URL>**
→ Comprueba la URL, el puerto (9696) y que Prowlarr esté en marcha. Con `test-all`, también puede ser que superara los 120 s.

**ERROR: id debe ser un número entero: abc**
→ Pasa el id numérico del indexador (el `id` de `indexers`).

## Notas

- Limitaciones conocidas: no hay comandos para añadir o editar indexadores, aplicaciones ni ver el historial; `enable` y `disable` reenvían la definición completa del indexador y Prowlarr puede rechazarla (HTTP 400); `sync` no espera a que termine; `delete` solo lo protege el hook. Detalle en `SKILL.md`.
- La clave de API y los cuerpos de indexador no salen en `ps` ni en ninguna salida.
- Requiere `bash`, `curl` y `jq`.

## Licencia

MIT
