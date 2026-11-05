# Skill de Dozzle

Lista los contenedores Docker del stack y lee sus logs a través de Dozzle, con los secretos ocultos. Solo lectura.

## Qué hace

- **Contenedores** — Lista los contenedores con su estado y su salud
- **Logs** — Lee las últimas líneas del log de un contenedor, con filtro por texto, fecha y flujo (`stdout` / `stderr`)

Dozzle no usa clave de API: solo se necesita su URL.

## Configuración

### 1. Averigua la URL de Dozzle

Es la que usas para abrir su interfaz web, con el puerto y sin barra final (`http://host:puerto`).

### 2. Configura la variable de entorno

Añade la URL a `~/.claude/plex-crew/.env`:

```bash
DOZZLE_URL="http://host:8080"
```

**Opciones de configuración:**
- `DOZZLE_URL`: URL de Dozzle (la API se llama en `<DOZZLE_URL>/api/...`)
- `DOZZLE_MAX_TIME`: opcional, segundos máximos por petición de logs (30 por defecto)

### 3. Pruébalo

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/dozzle/scripts/dozzle.sh" status
```

### Cómo invocar el script

En los `SKILL.md` el script se llama con `${CLAUDE_PLUGIN_ROOT}/skills/dozzle/scripts/dozzle.sh`. Fuera de una sesión de Claude Code esa variable no existe: usa la ruta real del plugin, por ejemplo `bash /ruta/al/plugin/skills/dozzle/scripts/dozzle.sh status`.

## Ejemplos de uso

### Listar contenedores

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/dozzle/scripts/dozzle.sh" containers
```

Primera línea con la versión y el recuento; después, nombre, estado, salud e id por contenedor.

### Leer logs

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/dozzle/scripts/dozzle.sh" logs radarr
bash "${CLAUDE_PLUGIN_ROOT}/skills/dozzle/scripts/dozzle.sh" logs radarr --lines 50 --grep error
bash "${CLAUDE_PLUGIN_ROOT}/skills/dozzle/scripts/dozzle.sh" logs sonarr --stderr --since 2026-11-05T08:00:00Z
```

`--lines` (1-5000, 100 por defecto), `--grep` (texto, sin distinguir mayúsculas), `--since` (UTC, `AAAA-MM-DDTHH:MM:SSZ`), `--stderr` y `--stdout`.

## Flujo de trabajo

1. `containers` para ver los nombres exactos y el estado
2. `logs <contenedor> --lines 200 --grep error` para buscar fallos

## Resolución de problemas

**ERROR: faltan variables en el .env**
→ Define `DOZZLE_URL` en `~/.claude/plex-crew/.env`.

**ERROR: no se pudo leer la lista de contenedores de Dozzle**
→ Comprueba la URL, el puerto y que Dozzle esté en marcha; si tiene autenticación activada, la skill no puede leerlo.

**ERROR: contenedor no encontrado**
→ Usa `containers` para ver el nombre exacto.

**AVISO: respuesta truncada**
→ El log es muy largo: acota con `--since`.

## Notas

- Solo lectura; la petición de logs es un `POST` porque así lo expone Dozzle.
- Los secretos que aparezcan en los logs salen como `***` (redacción heurística).
- Requiere `bash`, `curl`, `jq`, `awk` y `sed`.

## Referencia de la API

- [Endpoints de la API](references/api-endpoints.md)
- [Referencia rápida](references/quick-reference.md)
- [Resolución de problemas](references/troubleshooting.md)
- [Dozzle](https://dozzle.dev/)

## Licencia

MIT
