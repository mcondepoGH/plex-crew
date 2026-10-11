# Skill de Sonarr

Busca series en TVDB, comprueba si están en Sonarr y las añade o las quita desde la API v3.

## Qué hace

- **Buscar** — Lista hasta 10 series con enlace a TVDB, o devuelve el JSON completo
- **Comprobar** — Indica si una serie ya está en la biblioteca
- **Configuración** — Muestra carpetas raíz y perfiles de calidad
- **Estado** — Versión, instancia, sistema operativo y rama
- **Añadir** — Da de alta una serie; por defecto busca los episodios que faltan
- **Quitar** — Da de baja una serie, con o sin borrado de ficheros (destructivo)

## Configuración

### 1. Obtén tu clave de API

1. Abre la interfaz web de Sonarr
2. Ve a **Settings → General → Security**
3. Copia la **API Key**

### 2. Configura las variables de entorno

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
SONARR_URL="http://localhost:8989"
SONARR_API_KEY="<your_api_key>"
# SONARR_DEFAULT_QUALITY_PROFILE=1
```

**Opciones de configuración:**
- `SONARR_URL`: URL de Sonarr con puerto, sin barra final (la API se llama en `<SONARR_URL>/api/v3`)
- `SONARR_API_KEY`: tu clave de API
- `SONARR_DEFAULT_QUALITY_PROFILE`: perfil de calidad por defecto de `add` (opcional; 1 si falta)
- `HOMELAB_ENV`: ruta opcional a otro fichero de entorno

### 3. Pruébalo

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh" status
```

Fuera de una sesión de Claude Code `${CLAUDE_PLUGIN_ROOT}` no existe: usa la ruta real del plugin.

## Ejemplos de uso

### Buscar

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh" search "breaking bad"
bash "${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh" search-json "breaking bad" | jq '.[0].overview'
```

### Comprobar y consultar la configuración

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh" exists 81189
bash "${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh" config
```

### **Añadir una serie**

Confirma con el usuario antes de añadir: sin `--no-search`, Sonarr busca y puede descargar.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh" add 81189 5 --no-search
```

### **Quitar una serie**

Destructivo. El hook `confirm-destructive` bloquea `sonarr.sh remove` sin `PLEX_CREW_CONFIRMED=1`, que solo se antepone tras la doble confirmación de la regla global (`plex-crew-rules`).

```bash
PLEX_CREW_CONFIRMED=1 bash "${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/sonarr.sh" remove 81189 --delete-files
```

## Referencia de la API

- [Endpoints de la API](references/api-endpoints.md)
- [Referencia rápida](references/quick-reference.md)
- [Resolución de problemas](references/troubleshooting.md)
- [Documentación oficial](https://sonarr.tv/docs/api/)

## Flujo de trabajo

1. `search` para encontrar la serie y su `tvdbId` (el número del enlace)
2. `exists` para comprobar que no está ya
3. `config` para elegir el perfil de calidad
4. `add` tras confirmarlo con el usuario

## Resolución de problemas

**ERROR: GET /system/status respondió HTTP 401**
→ Revisa `SONARR_API_KEY` en `~/.claude/plex-crew/.env`.

**ERROR: no se pudo contactar con Sonarr en <URL>**
→ Comprueba la URL, el puerto (8989) y que Sonarr esté en marcha.

**ERROR: tvdbId no válido: 'abc'**
→ Pasa el id numérico de TVDB.

**❌ Failed to add show**
→ Lee el mensaje que sigue: serie ya existente, perfil inexistente o carpeta raíz no válida.

## Notas

- Los ids son de TVDB, no de TMDB.
- Limitaciones conocidas: `add` y `remove` no comprueban el código HTTP y `remove` imprime éxito aunque Sonarr lo rechace; `add` usa la primera carpeta raíz y `monitor: all`; `search` muestra solo 10 resultados. Detalle en `SKILL.md`.
- La clave nunca se imprime.
- Requiere `bash`, `curl` y `jq`.

## Licencia

MIT
