# Skill de Tautulli

Consulta en modo lectura la analítica de uso de Plex a través de la API de Tautulli.

## Qué hace

- **Actividad** — Muestra los streams en curso y la información del servidor
- **Historial** — Lista reproducciones filtradas por usuario, biblioteca, tipo, fecha o texto
- **Usuarios** — Lista usuarios y calcula sus estadísticas
- **Bibliotecas** — Lista bibliotecas y sus estadísticas
- **Popular y reciente** — Lo más reproducido y lo añadido recientemente
- **Gráficas** — Reproducciones por tipo de stream, plataforma, fecha, hora y día, y streams simultáneos
- **Metadatos** — Datos de un elemento por `rating_key` o `guid`

Todos los comandos devuelven el JSON completo de Tautulli y ninguno escribe nada.

## Configuración

### 1. Obtén tu clave de API

1. Abre la interfaz web de Tautulli
2. Ve a **Settings → Web Interface → API**
3. Copia la **API Key**

### 2. Configura las variables de entorno

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
TAUTULLI_URL="http://localhost:8181"
TAUTULLI_API_KEY="<your_api_key>"
```

**Opciones de configuración:**
- `TAUTULLI_URL`: URL de Tautulli con puerto (la API se llama en `<TAUTULLI_URL>/api/v2`)
- `TAUTULLI_API_KEY`: tu clave de API
- `HOMELAB_ENV`: ruta opcional a otro fichero de entorno

### 3. Pruébalo

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" server-info
```

Fuera de una sesión de Claude Code `${CLAUDE_PLUGIN_ROOT}` no existe: usa la ruta real del plugin.

## Ejemplos de uso

### Actividad actual

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" activity | jq '.response.data.stream_count'
```

### Historial

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" history --user ana --days 7 --limit 10
```

### Estadísticas de usuarios y bibliotecas

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" user-stats --sort-by plays --limit 5
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" libraries
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" library-stats --section-id 1
```

### Popular, reciente y gráficas

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" popular --days 30
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" recent --days 7
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" plays-by-hour --days 30
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" concurrent-streams --peak
```

### Metadatos

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" metadata --rating-key 12345
```

## Referencia de la API

- [Endpoints de la API](references/api-endpoints.md)
- [Referencia rápida](references/quick-reference.md)
- [Resolución de problemas](references/troubleshooting.md)
- [Documentación oficial](https://github.com/Tautulli/Tautulli/wiki/Tautulli-API-Reference)

## Flujo de trabajo

1. Ejecuta `activity` para ver qué se reproduce ahora
2. Ejecuta `libraries` para conocer los `section_id`
3. Ejecuta `history`, `popular` o `plays-by-*` con `--days` para analizar un periodo
4. Filtra el JSON con `jq '.response.data...'`

## Resolución de problemas

**ERROR: Tautulli devolvió error: Invalid apikey**
→ Revisa `TAUTULLI_API_KEY` en `~/.claude/plex-crew/.env`.

**ERROR: no se pudo contactar con Tautulli en <URL>**
→ Comprueba la URL, el puerto (8181) y que Tautulli esté en marcha.

**ERROR: 'abc' no es un número entero positivo**
→ Pasa un entero a `--days`, `--limit`, `--section-id` o `--rating-key`.

## Notas

- Limitaciones conocidas: `popular` envía siempre `stat_id=popular_movies` aunque se pase otro `--media-type`, y `activity --details` se acepta sin efecto.
- Las fechas se interpretan en la hora del servidor.
- La clave nunca se imprime; el script la pasa a curl por stdin.
- Requiere `bash`, `curl`, `jq` y `date` (GNU).

## Licencia

MIT
