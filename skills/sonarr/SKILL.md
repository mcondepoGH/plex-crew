---
name: sonarr
description: Esta skill debe usarse cuando se gestionan series de TV en Sonarr. Úsala cuando el usuario pida "añadir una serie", "buscar en Sonarr", "encontrar una serie", "añadir a Sonarr", "eliminar una serie", "comprobar si una serie existe", "biblioteca de Sonarr", "buscar en TVDB", o mencione la gestión de series de TV u operaciones de Sonarr.
---

# Skill de gestión de series de TV en Sonarr

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "añadir una serie", "buscar en Sonarr", "encontrar una serie", "añadir a Sonarr"
- "eliminar una serie", "borrar serie", "comprobar si una serie existe"
- "biblioteca de Sonarr", "gestión de series de TV", "añadir serie"
- Cualquier mención de Sonarr o de la gestión de series de TV

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Busca y añade series de TV a tu biblioteca de Sonarr, con soporte de opciones de monitorización, perfiles de calidad y búsqueda al añadir.

## Propósito

Esta skill permite gestionar tu biblioteca de series de TV de Sonarr:
- Buscar series por nombre
- Añadir series a tu biblioteca con opciones configurables
- Comprobar si las series ya existen
- Eliminar series (con borrado opcional de archivos)
- Consultar perfiles de calidad y carpetas raíz

Las operaciones incluyen acciones de lectura y de escritura. **Confirma siempre antes de eliminar series con borrado de archivos.**

## Configuración

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
SONARR_URL="http://localhost:8989"
SONARR_API_KEY="<your_api_key>"
SONARR_DEFAULT_QUALITY_PROFILE="1"  # Optional: defaults to 1 if not set
```

**Variables de configuración:**
- `SONARR_URL`: URL de tu servidor Sonarr (sin barra final)
- `SONARR_API_KEY`: clave de API de Sonarr (Settings → General → API Key)
- `SONARR_DEFAULT_QUALITY_PROFILE`: ID del perfil de calidad (opcional, por defecto 1)

## Ejecución del script

El script está en `${CLAUDE_PLUGIN_ROOT}/skills/sonarr/scripts/`. Los ejemplos siguientes usan rutas relativas a la carpeta de la skill, así que ejecútalos en un subshell que no altere el directorio de trabajo de la sesión:

```bash
(cd "${CLAUDE_PLUGIN_ROOT}/skills/sonarr" && bash scripts/sonarr.sh search "Breaking Bad")
```

## Comandos

Todos los comandos devuelven salida JSON.

### Buscar series

```bash
bash scripts/sonarr.sh search "Breaking Bad"
bash scripts/sonarr.sh search "The Office"
```

**Salida:** lista numerada con IDs de TVDB, títulos, años y sinopsis.

### Comprobar si una serie existe

```bash
bash scripts/sonarr.sh exists <tvdbId>
```

**Salida:** booleano que indica si la serie está en la biblioteca.

### Añadir una serie

```bash
bash scripts/sonarr.sh add <tvdbId>              # Busca de inmediato (por defecto)
bash scripts/sonarr.sh add <tvdbId> --no-search  # Añade sin buscar
```

### Eliminar una serie

```bash
bash scripts/sonarr.sh remove <tvdbId>                # Conserva los archivos
bash scripts/sonarr.sh remove <tvdbId> --delete-files # Borra también los archivos
```

**Importante:** pregunta siempre al usuario si quiere borrar los archivos al eliminar.

### Obtener la configuración

```bash
bash scripts/sonarr.sh config
```

**Salida:** carpetas raíz y perfiles de calidad disponibles con sus IDs.

## Flujo de trabajo

Cuando el usuario pregunte por series de TV:

1. **"Añade Breaking Bad a Sonarr"** → Ejecuta `search "Breaking Bad"`, presenta los resultados con enlaces de TVDB y después `add <tvdbId>`
2. **"¿Está The Office en mi biblioteca?"** → Ejecuta `exists <tvdbId>`
3. **"Elimina Game of Thrones"** → Pregunta por el borrado de archivos y ejecuta `remove <tvdbId>` con el flag adecuado
4. **"¿Qué perfiles de calidad tengo?"** → Ejecuta `config`

### Presentar los resultados de búsqueda

Incluye siempre enlaces de TVDB al presentar resultados de búsqueda:
- Formato: `[Title (Year)](https://thetvdb.com/series/SLUG)`
- Muestra una lista numerada para que el usuario elija
- Incluye el año y una breve sinopsis

### Añadir series

1. Busca la serie
2. Presenta los resultados con enlaces de TVDB
3. El usuario elige un número
4. Añade la serie (busca episodios por defecto)

## Parámetros

### Comando add
- `<tvdbId>`: ID de TVDB de la serie (obligatorio)
- `--no-search`: no buscar episodios tras añadirla

### Comando remove
- `<tvdbId>`: ID de TVDB de la serie (obligatorio)
- `--delete-files`: borra también los archivos multimedia (por defecto se conservan)

## Notas

- Requiere acceso de red a tu servidor Sonarr
- Usa la API v3 de Sonarr
- Todas las operaciones de datos devuelven JSON
- Los IDs de perfil de calidad varían según la instalación: usa `config` para descubrir los tuyos
- Al añadir series se usa el `SONARR_DEFAULT_QUALITY_PROFILE` de `~/.claude/plex-crew/.env` (por defecto 1)

## Referencia

- [Documentación de la API de Sonarr](https://sonarr.tv/docs/api/)
- [TVDB](https://thetvdb.com/) — base de datos de series de TV

Para una referencia local detallada, consulta:
- **[Endpoints de la API](./references/api-endpoints.md)** - Referencia completa de endpoints con parámetros
- **[Referencia rápida](./references/quick-reference.md)** - Operaciones habituales con ejemplos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Soluciones para errores de autenticación, conexión y otros

---

## 🔧 Requisitos de uso de herramientas del agente

**CRÍTICO:** al invocar scripts de esta skill mediante la zsh-tool, **USA SIEMPRE `pty: true`**.

Sin el modo PTY, la salida de los comandos no será visible aunque se ejecuten correctamente.

**Patrón de invocación correcto:**
```typescript
<invoke name="mcp__plugin_zsh-tool_zsh-tool__zsh">
<parameter name="command">./skills/SKILL_NAME/scripts/SCRIPT.sh [args]</parameter>
<parameter name="pty">true</parameter>
</invoke>
```
