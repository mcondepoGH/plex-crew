# Skill de Agregarr

Consulta y sincroniza las colecciones de Plex que gestiona Agregarr.

## Qué hace

- **Estado** — Versión de Agregarr y validación de la clave de API
- **Colecciones** — Lista las colecciones configuradas
- **Sincronización** — Muestra el estado y lanza la sincronización global o de una colección
- **Tareas** — Lista y ejecuta las tareas programadas
- **Logs** — Lee las últimas entradas, opcionalmente por nivel

No crea, modifica ni borra colecciones.

## Configuración

### 1. Obtén tu clave de API de Agregarr

1. Abre la interfaz web de Agregarr
2. Ve a **Settings → General**
3. Copia tu **API Key**

### 2. Configura las variables de entorno

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
AGREGARR_URL="http://localhost:7171"
AGREGARR_API_KEY="<your_api_key>"
```

**Opciones de configuración:**
- `AGREGARR_URL`: URL del servidor (la API se llama en `<AGREGARR_URL>/api/v1`)
- `AGREGARR_API_KEY`: tu clave de API (se envía como `X-Api-Key`)
- `AGREGARR_MAX_TIME`: tiempo máximo por petición en segundos (25 por defecto)

### 3. Pruébalo

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" status
```

### Cómo invocar el script

En los `SKILL.md` el script se llama con `${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh`. Fuera de una sesión de Claude Code esa variable no existe: usa la ruta real del plugin, por ejemplo `bash /workspace/skills/agregarr/scripts/agregarr.sh status`.

## Ejemplos de uso

### Listar colecciones

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" collections
```

### Estado de la sincronización

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" sync-status
```

### Tareas y logs

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" jobs
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" logs 20 error
```

### Sincronizar

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" sync
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" sync-collection 10000
```

**¡Confirma siempre con el usuario antes de sincronizar!**

## Referencia de la API

- **[Endpoints de la API](./references/api-endpoints.md)** - Endpoints que usa el script
- **[Referencia rápida](./references/quick-reference.md)** - Operaciones listas para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Soluciones y funciones pendientes

## Flujo de trabajo

1. `status` para comprobar versión y clave
2. `collections` para localizar ids
3. Confirmar con el usuario y `sync` o `sync-collection <id>`
4. `sync-status` hasta que termine y `logs 50 error` si algo falla

## Resolución de problemas

**"faltan variables en el .env"**
→ Define `AGREGARR_URL` y `AGREGARR_API_KEY` en `~/.claude/plex-crew/.env`

**"Clave de API: NO VÁLIDA"**
→ Regenera o copia de nuevo la clave en Settings → General

**"DESCONECTADO"**
→ Comprueba la URL, el puerto (7171 por defecto) y que el contenedor está en ejecución

## Notas

- `/status` es público; la clave se valida con `/collections`
- Cada comando comprueba el código HTTP; un fallo imprime `ERROR:` en stderr y termina con 1
- Sin comando se muestra la ayuda (código 0); un comando desconocido o un argumento ausente termina con 1
- Requiere `curl` y `jq`

## Licencia

MIT
