---
name: plex
description: Esta skill debe usarse cuando se necesite controlar Plex Media Server para explorar bibliotecas, buscar contenido, ver qué se está reproduciendo o consultar lo añadido recientemente. Úsala cuando el usuario pida "revisar Plex", "buscar en Plex", "qué hay en Plex", "añadido recientemente", "quién está viendo algo", "sesiones de Plex", "biblioteca de Plex", "explorar películas", "explorar series", o mencione Plex Media Server.
---

# Skill de Plex Media Server

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "biblioteca de Plex", "buscar en Plex", "qué hay en Plex"
- "sesiones de Plex", "quién está viendo algo", "streams activos"
- "explorar Plex", "revisar Plex", "estado de Plex"
- Cualquier mención de Plex Media Server o de consultar contenido multimedia

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Controla y consulta Plex Media Server mediante la API de Plex. Explora bibliotecas, busca contenido y supervisa las sesiones activas.

## Propósito

Esta skill ofrece acceso de **solo lectura** a tu Plex Media Server:
- Explorar las secciones de biblioteca (Películas, Series, Música, Fotos)
- Buscar contenido concreto
- Ver el contenido añadido recientemente
- Comprobar qué se está reproduciendo (sesiones activas)
- Ver "On Deck" (continuar viendo)
- Listar los clientes/reproductores disponibles

Todas las operaciones son **solo GET** y seguras para supervisar y explorar.

## Configuración

Añade las credenciales de tu servidor Plex a `~/.claude/plex-crew/.env`:

```bash
# Plex Media Server
PLEX_URL="http://192.168.1.100:32400"
PLEX_TOKEN="<your_plex_token>"
```

- `PLEX_URL`: URL de tu servidor Plex con el puerto (por defecto 32400)
- `PLEX_TOKEN`: tu token de autenticación de Plex

**Cómo obtener tu token de Plex:**
1. Ve a plex.tv → Account → Authorized Devices
2. Haz clic en cualquier dispositivo y luego en "View XML"
3. Busca `X-Plex-Token` en la URL
4. O bien: abre cualquier contenido en Plex Web, haz clic en "Get Info" → "View XML" y busca el token en la URL

## Comandos

Todos los comandos devuelven JSON. Usa `jq` para dar formato o filtrar.

El script auxiliar `plex-api.sh` simplifica el acceso a la API. Está en `${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh`. Los ejemplos de abajo usan rutas relativas a la raíz del plugin, así que ejecútalos en un subshell que deje intacto el directorio de trabajo de la sesión:

```bash
(cd "${CLAUDE_PLUGIN_ROOT}" && ./skills/plex/scripts/plex-api.sh info)
```

### Información del servidor

```bash
# Con el script auxiliar
./skills/plex/scripts/plex-api.sh info

# O con curl directo
curl -s "$PLEX_URL/?X-Plex-Token=$PLEX_TOKEN" -H "Accept: application/json"
```

### Explorar bibliotecas

Lista todas las secciones de biblioteca:

```bash
# Con el script auxiliar
./skills/plex/scripts/plex-api.sh libraries

# O con curl directo
curl -s "$PLEX_URL/library/sections?X-Plex-Token=$PLEX_TOKEN" -H "Accept: application/json"
```

### Listar el contenido de una biblioteca

```bash
# Con el script auxiliar (sustituye 1 por la clave de tu sección)
./skills/plex/scripts/plex-api.sh library 1
./skills/plex/scripts/plex-api.sh library 1 --limit 50 --offset 100

# O con curl directo
curl -s "$PLEX_URL/library/sections/1/all?X-Plex-Token=$PLEX_TOKEN" -H "Accept: application/json"
```

### Buscar contenido

```bash
# Con el script auxiliar
./skills/plex/scripts/plex-api.sh search "Inception"
./skills/plex/scripts/plex-api.sh search "Avengers" --limit 10

# O con curl directo
curl -s "$PLEX_URL/search?query=SEARCH_TERM&X-Plex-Token=$PLEX_TOKEN" -H "Accept: application/json"
```

### Añadido recientemente

```bash
# Con el script auxiliar (por defecto: 20 elementos)
./skills/plex/scripts/plex-api.sh recent
./skills/plex/scripts/plex-api.sh recent --limit 10

# O con curl directo
curl -s "$PLEX_URL/library/recentlyAdded?X-Plex-Token=$PLEX_TOKEN" -H "Accept: application/json"
```

### On Deck (continuar viendo)

```bash
# Con el script auxiliar (por defecto: 10 elementos)
./skills/plex/scripts/plex-api.sh ondeck
./skills/plex/scripts/plex-api.sh ondeck --limit 5

# O con curl directo
curl -s "$PLEX_URL/library/onDeck?X-Plex-Token=$PLEX_TOKEN" -H "Accept: application/json"
```

### Sesiones activas (qué se está reproduciendo)

```bash
# Con el script auxiliar
./skills/plex/scripts/plex-api.sh sessions

# O con curl directo
curl -s "$PLEX_URL/status/sessions?X-Plex-Token=$PLEX_TOKEN" -H "Accept: application/json"
```

### Listar clientes/reproductores

```bash
# Con el script auxiliar
./skills/plex/scripts/plex-api.sh clients

# O con curl directo
curl -s "$PLEX_URL/clients?X-Plex-Token=$PLEX_TOKEN" -H "Accept: application/json"
```

### Comandos adicionales

```bash
# Identidad del servidor
./skills/plex/scripts/plex-api.sh identity

# Obtener los metadatos de un elemento concreto (por rating key)
./skills/plex/scripts/plex-api.sh metadata 12345

# Obtener los hijos de un elemento (p. ej., las temporadas de una serie)
./skills/plex/scripts/plex-api.sh children 12345

# Listar listas de reproducción
./skills/plex/scripts/plex-api.sh playlists

# Refrescar una sección de biblioteca (buscar contenido nuevo)
./skills/plex/scripts/plex-api.sh refresh 1

# Ver todos los comandos
./skills/plex/scripts/plex-api.sh --help
```

## Flujo de trabajo

Cuando el usuario pregunte por Plex:

1. **"¿Qué hay en Plex?"** → Explora las bibliotecas y muestra un resumen de las secciones
2. **"Busca Inception"** → Ejecuta la búsqueda con la consulta
3. **"¿Qué se añadió recientemente?"** → Ejecuta recentlyAdded
4. **"¿Quién está viendo algo ahora mismo?"** → Ejecuta sessions
5. **"¿Qué estoy viendo?"** → Ejecuta onDeck
6. **"Lista mis películas"** → Lista las secciones de biblioteca y luego el contenido de la sección de Películas

### Tipos de sección de biblioteca

Tipos de sección habituales (las claves varían según el servidor):
- **Películas** — Normalmente la sección 1
- **Series** — Normalmente la sección 2
- **Música** — Biblioteca de música
- **Fotos** — Biblioteca de fotos

Lista siempre primero las secciones para obtener las claves correctas de tu servidor.

## Formato de salida

- Añade `-H "Accept: application/json"` para obtener la salida en JSON
- La salida por defecto es XML si no se indica la cabecera
- Las claves de contenido tienen el aspecto `/library/metadata/12345`
- Usa `jq` para filtrar y dar formato a las respuestas JSON

## Notas

- Requiere acceso de red a tu servidor Plex
- Todas las llamadas son **peticiones GET de solo lectura**
- Las claves de sección de biblioteca (1, 2, 3...) varían según la configuración del servidor: lista primero las secciones
- El control de reproducción es posible pero no está implementado (por seguridad)
- Confirma siempre antes de iniciar la reproducción en dispositivos remotos
- El token está asociado a tu cuenta: mantenlo seguro

## Varios servidores

Para consultar varios servidores Plex:

```bash
# Servidor 1
PLEX_URL="http://server1:32400" PLEX_TOKEN="token1" curl ...

# Servidor 2
PLEX_URL="http://server2:32400" PLEX_TOKEN="token2" curl ...
```

## Referencia

- [Plex Media Server API](https://www.plexopedia.com/plex-media-server/api/)
- [Plex Web App](https://app.plex.tv/)

Para la referencia local detallada, consulta:
- **[Endpoints de la API](./references/api-endpoints.md)** - Referencia completa de endpoints con parámetros
- **[Referencia rápida](./references/quick-reference.md)** - Operaciones habituales con ejemplos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Soluciones a problemas de autenticación, conexión y errores

---

## 🔧 Requisitos de uso de herramientas del agente

**CRÍTICO:** Al invocar scripts de esta skill mediante la zsh-tool, **USA SIEMPRE `pty: true`**.

Sin el modo PTY, la salida de los comandos no será visible aunque se ejecuten correctamente.

**Patrón de invocación correcto:**
```typescript
<invoke name="mcp__plugin_zsh-tool_zsh-tool__zsh">
<parameter name="command">./skills/SKILL_NAME/scripts/SCRIPT.sh [args]</parameter>
<parameter name="pty">true</parameter>
</invoke>
```
