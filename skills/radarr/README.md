# Skill de Radarr

Busca películas en TMDB, comprueba si están en Radarr, las añade (sueltas o por colección) o las quita desde la API v3, y consulta el log.

## Qué hace

- **Buscar** — Lista las películas con enlace a TMDB y su colección, o devuelve el JSON completo
- **Comprobar** — Indica si una película ya está en la biblioteca
- **Configuración** — Muestra carpetas raíz y perfiles de calidad
- **Estado** — Versión, instancia, sistema operativo y rama
- **Añadir** — Da de alta una película; por defecto la busca y puede iniciar descargas
- **Añadir colección** — Da de alta todas las películas de una colección y monitoriza la colección
- **Quitar** — Da de baja una película, con o sin borrado de ficheros (destructivo)
- **Colección** — Detalles de una colección de Radarr (JSON)
- **Log** — Últimas entradas del log de Radarr (solo lectura)

## Configuración

### 1. Obtén tu clave de API

1. Abre la interfaz web de Radarr
2. Ve a **Settings → General → Security**
3. Copia la **API Key**

### 2. Configura las variables de entorno

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
RADARR_URL="http://localhost:7878"
RADARR_API_KEY="<your_api_key>"
# RADARR_DEFAULT_QUALITY_PROFILE=1
```

**Opciones de configuración:**
- `RADARR_URL`: URL de Radarr con puerto, sin barra final (la API se llama en `<RADARR_URL>/api/v3`)
- `RADARR_API_KEY`: tu clave de API
- `RADARR_DEFAULT_QUALITY_PROFILE`: perfil de calidad por defecto de `add` (opcional; 1 si falta)

### 3. Pruébalo

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" status
```

Fuera de una sesión de Claude Code `${CLAUDE_PLUGIN_ROOT}` no existe: usa la ruta real del plugin.

## Ejemplos de uso

### Buscar

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" search "the matrix"
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" search-json "the matrix" | jq '.[0].overview'
```

### Comprobar y consultar la configuración

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" exists 603
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" config
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" collection-info 2344
```

### **Añadir una película**

Confirma con el usuario antes de añadir: sin `--no-search`, Radarr busca y puede descargar.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" add 603 5 --no-search
```

### **Añadir una colección**

Confirma con el usuario antes de añadir: añade todas las películas de la colección con el primer perfil de calidad de `config`.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" add-collection 2344
```

### **Quitar una película**

Destructivo. El hook `confirm-destructive` bloquea `radarr.sh remove` sin `PLEX_CREW_CONFIRMED=1`, que solo se antepone tras la doble confirmación de la regla global (`plex-crew-rules`). Pregunta siempre si se borran los ficheros.

```bash
PLEX_CREW_CONFIRMED=1 bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" remove 603 --delete-files
```

### Consultar el log

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" logs 20 --level error
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" logs --grep "rootfolder"
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" logs --files
```

## Referencia de la API

- [Endpoints de la API](references/api-endpoints.md)
- [Referencia rápida](references/quick-reference.md)
- [Resolución de problemas](references/troubleshooting.md)
- [Documentación oficial](https://radarr.video/docs/api/)

## Flujo de trabajo

1. `search` para encontrar la película y su `tmdbId` (el número del enlace)
2. `exists` para comprobar que no está ya
3. `config` para elegir el perfil de calidad
4. `add` tras confirmarlo con el usuario (o `add-collection` para una saga)

## Resolución de problemas

**ERROR: GET /system/status respondió HTTP 401**
→ Revisa `RADARR_API_KEY` en `~/.claude/plex-crew/.env`.

**ERROR: no se pudo contactar con Radarr en <URL>**
→ Comprueba la URL, el puerto (7878) y que Radarr esté en marcha.

**ERROR: tmdbId debe ser un número entero: abc**
→ Pasa el id numérico de TMDB (el del enlace de `search`).

**❌ Failed to add movie**
→ Lee el mensaje que sigue: película ya existente, perfil inexistente o carpeta raíz no válida.

## Notas

- Los ids son de TMDB, no de TVDB.
- Limitaciones conocidas: `add`, `add-collection` y `remove` no comprueban el código HTTP; `add` y `add-collection` terminan con código 0 aunque Radarr rechace el alta, y `remove` imprime éxito aunque Radarr lo rechace; usan la primera carpeta raíz; `add-collection` ignora `RADARR_DEFAULT_QUALITY_PROFILE`; `search` imprime todos los resultados. Detalle en `SKILL.md`.
- La clave nunca se imprime.
- Requiere `bash`, `curl` y `jq`.

## Licencia

MIT
