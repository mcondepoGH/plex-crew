---
name: prowlarr
description: Busca en indexadores y gestiona Prowlarr. Úsala cuando el usuario pida "buscar un torrent", "buscar en los indexadores", "encontrar un release", "comprobar el estado de los indexadores", "listar indexadores", "búsqueda en Prowlarr", "sincronizar indexadores", o mencione Prowlarr o la gestión de indexadores.
---

# Skill de Prowlarr

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "buscar un torrent", "buscar en los indexadores", "encontrar un release"
- "buscar en Prowlarr", "indexadores de Prowlarr", "búsqueda en indexadores"
- "comprobar el estado de los indexadores", "probar indexadores", "estadísticas de Prowlarr"
- "listar indexadores", "sincronizar indexadores", "enviar indexadores a Sonarr"
- Cualquier mención de Prowlarr o de la gestión de indexadores

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Busca en todos tus indexadores y gestiona Prowlarr mediante su API.

## Propósito

Esta skill ofrece acceso de **lectura y escritura** a la agregación de indexadores de Prowlarr:
- Buscar releases en todos los indexadores configurados
- Filtrar las búsquedas por protocolo (torrent/usenet) y categoría
- Listar y supervisar el estado y las estadísticas de los indexadores
- Activar, desactivar y eliminar indexadores
- Sincronizar la configuración de los indexadores con las apps conectadas (Sonarr, Radarr)
- Probar la conectividad de los indexadores

Las operaciones incluyen acciones de lectura y de escritura. **Confirma siempre antes de eliminar o desactivar indexadores.**

## Configuración

Las credenciales se guardan en `~/.claude/plex-crew/.env`:

```bash
PROWLARR_URL="http://localhost:9696"
PROWLARR_API_KEY="your-api-key"
```

Obtén tu clave de API en: Prowlarr → Settings → General → Security → API Key

## Ejecución del script

El script está en `${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/`. Los ejemplos siguientes usan rutas relativas a la carpeta de la skill, así que ejecútalos en un subshell que no altere el directorio de trabajo de la sesión:

```bash
(cd "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr" && ./scripts/prowlarr-api.sh search "ubuntu 22.04")
```

---

## Referencia rápida

### Buscar releases

```bash
# Búsqueda básica en todos los indexadores
./scripts/prowlarr-api.sh search "ubuntu 22.04"

# Buscar solo torrents
./scripts/prowlarr-api.sh search "ubuntu" --torrents

# Buscar solo usenet
./scripts/prowlarr-api.sh search "ubuntu" --usenet

# Buscar en categorías concretas (2000=Películas, 5000=TV, 3000=Audio, 7000=Libros)
./scripts/prowlarr-api.sh search "inception" --category 2000

# Búsqueda de series con TVDB ID
./scripts/prowlarr-api.sh tv-search --tvdb 71663 --season 1 --episode 1

# Búsqueda de películas con IMDB ID
./scripts/prowlarr-api.sh movie-search --imdb tt0111161
```

### Listar indexadores

```bash
# Todos los indexadores
./scripts/prowlarr-api.sh indexers

# Con detalles de estado
./scripts/prowlarr-api.sh indexers --verbose
```

### Estado y estadísticas de los indexadores

```bash
# Estadísticas de uso por indexador
./scripts/prowlarr-api.sh stats

# Probar todos los indexadores
./scripts/prowlarr-api.sh test-all

# Probar un indexador concreto
./scripts/prowlarr-api.sh test <indexer-id>
```

### Gestión de indexadores

```bash
# Activar o desactivar un indexador
./scripts/prowlarr-api.sh enable <indexer-id>
./scripts/prowlarr-api.sh disable <indexer-id>

# Eliminar un indexador
./scripts/prowlarr-api.sh delete <indexer-id>
```

### Sincronización con apps

```bash
# Sincronizar indexadores con Sonarr/Radarr/etc
./scripts/prowlarr-api.sh sync

# Listar las apps conectadas
./scripts/prowlarr-api.sh apps
```

### Sistema

```bash
# Estado del sistema
./scripts/prowlarr-api.sh status

# Comprobación de salud
./scripts/prowlarr-api.sh health
```

---

## Categorías de búsqueda

| ID | Categoría |
|----|----------|
| 2000 | Películas |
| 5000 | TV |
| 3000 | Audio |
| 7000 | Libros |
| 1000 | Consolas |
| 4000 | PC |
| 6000 | XXX |

Subcategorías: 2010 (Movies/Foreign), 2020 (Movies/Other), 2030 (Movies/SD), 2040 (Movies/HD), 2045 (Movies/UHD), 2050 (Movies/BluRay), 2060 (Movies/3D), 5010 (TV/WEB-DL), 5020 (TV/Foreign), 5030 (TV/SD), 5040 (TV/HD), 5045 (TV/UHD), etc.

---

## Casos de uso habituales

**"Busca la última ISO de Ubuntu"**
```bash
./scripts/prowlarr-api.sh search "ubuntu 24.04"
```

**"Encuentra Game of Thrones S01E01"**
```bash
./scripts/prowlarr-api.sh tv-search --tvdb 121361 --season 1 --episode 1
```

**"Busca Inception en 4K"**
```bash
./scripts/prowlarr-api.sh search "inception 2160p" --category 2045
```

**"Comprueba si mis indexadores funcionan bien"**
```bash
./scripts/prowlarr-api.sh stats
./scripts/prowlarr-api.sh test-all
```

**"Envía los cambios de indexadores a Sonarr/Radarr"**
```bash
./scripts/prowlarr-api.sh sync
```

## Flujo de trabajo

Cuando el usuario pregunte por indexadores o búsquedas:

1. **"Busca un torrent"** → Ejecuta `search "<query>"` y presenta los resultados con enlaces de descarga
2. **"Encuentra Breaking Bad S01E01"** → Ejecuta `tv-search --tvdb <id> --season 1 --episode 1`
3. **"¿Qué indexadores funcionan?"** → Ejecuta `stats` para mostrar el estado y el uso de los indexadores
4. **"Prueba todos mis indexadores"** → Ejecuta `test-all` para verificar la conectividad
5. **"Sincroniza los indexadores con Sonarr"** → Ejecuta `sync` para enviar los cambios de configuración
6. **"Lista los indexadores disponibles"** → Ejecuta `indexers` o `indexers --verbose`

## Notas

- Requiere acceso de red a tu servidor Prowlarr
- Usa la API v1 de Prowlarr
- Todas las operaciones de datos devuelven JSON
- **Las búsquedas consultan indexadores externos**: respeta los límites de peticiones
- **Eliminar un indexador es permanente**: confirma siempre antes de borrarlo
- Las sincronizaciones envían la configuración de los indexadores a todas las apps conectadas (Sonarr, Radarr, Lidarr, etc.)
- Los IDs de categoría siguen los estándares Newznab/Torznab

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
