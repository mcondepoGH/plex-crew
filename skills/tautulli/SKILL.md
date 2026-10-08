---
name: tautulli
description: Esta skill debe usarse cuando se necesite supervisar y analizar el uso de Plex Media Server mediante la API de analítica de Tautulli. Úsala cuando el usuario pida "revisar Tautulli", "analítica de Plex", "estadísticas de visionado", "streams actuales", "quién está viendo algo", "historial de Plex", "lo más visto", "actividad de usuarios", "estadísticas de biblioteca", o mencione Tautulli o la monitorización de Plex.
---

# Skill de analítica de Tautulli

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "Tautulli", "analítica de Plex", "estadísticas de visionado"
- "streams actuales", "quién está viendo Plex", "sesiones activas"
- "historial de Plex", "historial de visionado", "historial de reproducción"
- "lo más visto", "contenido top", "contenido popular"
- "actividad de usuarios", "estadísticas de usuarios", "estadísticas de biblioteca"
- "monitorización de Plex", "analítica de streams", "tendencias de visionado"
- Cualquier mención de Tautulli o de analítica de uso de Plex

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Supervisa y analiza el uso de Plex Media Server mediante la completa API de analítica de Tautulli. Sigue los streams actuales, los datos históricos de reproducción, la actividad de los usuarios y las estadísticas de las bibliotecas.

## Propósito

Esta skill ofrece acceso de **solo lectura** a la analítica de Tautulli:
- Supervisar la actividad actual y los streams activos
- Ver el historial de reproducción con filtros detallados
- Seguir las estadísticas de usuarios y sus patrones de visionado
- Analizar las estadísticas de bibliotecas y el contenido popular
- Ver el contenido añadido recientemente con sus metadatos
- Supervisar los límites de streams simultáneos y el ancho de banda
- Analizar el uso por hora, plataforma y tipo de stream
- Seguir las métricas de rendimiento del servidor y las bibliotecas

Todas las operaciones son **solo GET** y seguras para supervisar y analizar.

**Nota:** esta skill complementa la skill `plex` al añadir analítica y datos históricos que Plex Media Server no expone directamente.

## Configuración

Añade tus credenciales de Tautulli a `~/.claude/plex-crew/.env`:

```bash
# Tautulli Analytics
TAUTULLI_URL="http://192.168.1.100:8181"
TAUTULLI_API_KEY="<your_tautulli_api_key>"
```

- `TAUTULLI_URL`: URL de tu servidor Tautulli con el puerto (por defecto: 8181)
- `TAUTULLI_API_KEY`: tu clave de API de Tautulli

**Cómo obtener tu clave de API:**
1. Abre la interfaz web de Tautulli
2. Ve a Settings → Web Interface → API
3. Activa "API enabled"
4. Copia la clave de API
5. Opcionalmente, configura la autenticación HTTP Basic de la API si lo deseas

## Comandos

Todos los comandos usan el script envoltorio `tautulli-api.sh` y devuelven JSON.

El script auxiliar está en `${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh`. Los ejemplos de abajo usan rutas relativas a la raíz del plugin, así que ejecútalos en un subshell que deje intacto el directorio de trabajo de la sesión:

```bash
(cd "${CLAUDE_PLUGIN_ROOT}" && ./skills/tautulli/scripts/tautulli-api.sh server-info)
```

### Información del servidor

Obtén la identidad y la versión del servidor:

```bash
./skills/tautulli/scripts/tautulli-api.sh server-info
```

### Actividad actual

Supervisa los streams activos y la reproducción actual:

```bash
# Todas las sesiones activas
./skills/tautulli/scripts/tautulli-api.sh activity

# Actividad con detalles de sesión
./skills/tautulli/scripts/tautulli-api.sh activity --details
```

**Devuelve:** streams actuales con usuario, contenido, reproductor, ancho de banda e información de transcodificación

### Historial de reproducción

Consulta los datos históricos de reproducción:

```bash
# Historial reciente (por defecto: 25 elementos)
./skills/tautulli/scripts/tautulli-api.sh history

# Historial con filtros
./skills/tautulli/scripts/tautulli-api.sh history --user "username" --limit 50
./skills/tautulli/scripts/tautulli-api.sh history --days 7 --media-type movie
./skills/tautulli/scripts/tautulli-api.sh history --section-id 1 --limit 100

# Buscar en el historial
./skills/tautulli/scripts/tautulli-api.sh history --search "Inception"
```

**Parámetros:**
- `--user <username>`: filtrar por nombre de usuario
- `--section-id <id>`: filtrar por sección de biblioteca
- `--media-type <type>`: filtrar por movie, episode, track, etc.
- `--days <n>`: historial de los últimos N días
- `--limit <n>`: máximo de resultados (por defecto: 25)
- `--search <query>`: buscar en los títulos

### Estadísticas de usuarios

Sigue la actividad de los usuarios y sus patrones de visionado:

```bash
# Estadísticas de visionado de todos los usuarios
./skills/tautulli/scripts/tautulli-api.sh user-stats

# Detalles de un usuario concreto
./skills/tautulli/scripts/tautulli-api.sh user-stats --user "username"

# Usuarios top por número de reproducciones
./skills/tautulli/scripts/tautulli-api.sh user-stats --sort-by plays --limit 10
```

**Parámetros:**
- `--user <username>`: estadísticas de un usuario concreto
- `--sort-by <metric>`: ordenar por plays, duration, last_seen
- `--limit <n>`: máximo de resultados
- `--days <n>`: estadísticas de los últimos N días

### Estadísticas de bibliotecas

Analiza el uso de las bibliotecas y el contenido popular:

```bash
# Todas las secciones de biblioteca
./skills/tautulli/scripts/tautulli-api.sh libraries

# Estadísticas de una biblioteca concreta
./skills/tautulli/scripts/tautulli-api.sh library-stats --section-id 1

# Contenido popular de una biblioteca
./skills/tautulli/scripts/tautulli-api.sh popular --section-id 1 --limit 10
./skills/tautulli/scripts/tautulli-api.sh popular --media-type movie --days 30
```

**Parámetros:**
- `--section-id <id>`: sección de biblioteca concreta
- `--media-type <type>`: filtrar por tipo (movie, show, artist)
- `--days <n>`: periodo para calcular la popularidad
- `--limit <n>`: máximo de resultados

### Añadido recientemente

Consulta el contenido añadido recientemente con metadatos detallados:

```bash
# Añadido recientemente (por defecto: 25 elementos)
./skills/tautulli/scripts/tautulli-api.sh recent

# Recientes con filtros
./skills/tautulli/scripts/tautulli-api.sh recent --section-id 1 --limit 50
./skills/tautulli/scripts/tautulli-api.sh recent --media-type movie --days 7
```

### Estadísticas de inicio

Obtén las estadísticas del panel de inicio:

```bash
# Estadísticas generales (lo más popular, lo más activo, etc.)
./skills/tautulli/scripts/tautulli-api.sh home-stats

# Estadísticas de un periodo concreto
./skills/tautulli/scripts/tautulli-api.sh home-stats --days 30
```

### Analítica de streams

Analiza los tipos de stream y el uso por plataforma:

```bash
# Reproducciones por tipo de stream (directo/transcodificado)
./skills/tautulli/scripts/tautulli-api.sh plays-by-stream --days 30

# Reproducciones por plataforma
./skills/tautulli/scripts/tautulli-api.sh plays-by-platform --days 30

# Reproducciones por fecha/hora
./skills/tautulli/scripts/tautulli-api.sh plays-by-date --days 30
./skills/tautulli/scripts/tautulli-api.sh plays-by-hour --days 7
./skills/tautulli/scripts/tautulli-api.sh plays-by-day --days 30
```

### Streams simultáneos

Supervisa los patrones de streams simultáneos:

```bash
# Historial de streams simultáneos
./skills/tautulli/scripts/tautulli-api.sh concurrent-streams --days 30

# Pico de streams simultáneos
./skills/tautulli/scripts/tautulli-api.sh concurrent-streams --days 7 --peak
```

### Metadatos de contenido

Obtén los metadatos detallados de un contenido concreto:

```bash
# Por rating key
./skills/tautulli/scripts/tautulli-api.sh metadata --rating-key 12345

# Por GUID
./skills/tautulli/scripts/tautulli-api.sh metadata --guid "plex://movie/5d776..."
```

## Flujo de trabajo

Cuando el usuario pregunte por la analítica de Plex:

1. **"¿Quién está viendo algo ahora mismo?"** → Ejecuta `activity`
2. **"¿Cuáles son las películas más vistas?"** → Ejecuta `popular --media-type movie --days 30`
3. **"Muéstrame el historial de visionado reciente"** → Ejecuta `history --limit 25`
4. **"¿Cuánto ha visto [usuario] esta semana?"** → Ejecuta `user-stats --user "username" --days 7`
5. **"¿Qué hay de nuevo en mi biblioteca?"** → Ejecuta `recent --limit 10`
6. **"¿Cuándo se ve más contenido?"** → Ejecuta `plays-by-hour --days 30`
7. **"¿Estamos alcanzando los límites de streams?"** → Ejecuta `concurrent-streams --days 7 --peak`

### Flujo de monitorización de actividad

1. Comprueba la actividad actual para ver los streams activos
2. Si detectas problemas (buffering, transcodificación), investiga la sesión concreta
3. Revisa el historial de visionado del usuario para entender sus patrones
4. Consulta las estadísticas de biblioteca para identificar el contenido popular
5. Analiza los tipos de stream para optimizar la configuración del servidor

### Flujo de analítica

1. Obtén las estadísticas de inicio para tener una visión general
2. Profundiza en bibliotecas concretas con library-stats
3. Identifica el contenido popular con el comando popular
4. Analiza el comportamiento de los usuarios con user-stats
5. Revisa los patrones temporales con plays-by-hour/date/day
6. Supervisa la distribución por plataforma con plays-by-platform

## Formato de salida

Todos los comandos devuelven JSON con la estructura de respuesta estándar de Tautulli:

```json
{
  "response": {
    "result": "success",
    "message": null,
    "data": { ... }
  }
}
```

Usa `jq` para extraer y dar formato a los datos:

```bash
# Obtener solo los datos
./skills/tautulli/scripts/tautulli-api.sh activity | jq '.response.data'

# Extraer campos concretos
./skills/tautulli/scripts/tautulli-api.sh history | jq '.response.data.data[] | {user: .friendly_name, title: .full_title, date: .date}'
```

## Notas

- Requiere acceso de red a tu servidor Tautulli
- Todas las operaciones son **peticiones GET de solo lectura**
- Tautulli debe estar conectado a tu Plex Media Server
- Los IDs de sección de biblioteca coinciden con las claves de sección de Plex
- Los datos históricos dependen del periodo de retención configurado en Tautulli
- Algunas estadísticas requieren suficiente historial para ser significativas
- Los tiempos de respuesta pueden variar según el tamaño de la base de datos y la complejidad de la consulta
- Los rating keys son los identificadores únicos de Plex para los contenidos
- Por defecto se muestran los nombres amigables (se pueden mostrar los nombres de usuario con flags)

## Integración con la skill de Plex

Esta skill complementa la skill `plex`:

- **Skill de Plex**: estado del servidor en tiempo real (bibliotecas, búsqueda, sesiones)
- **Skill de Tautulli**: analítica histórica (tendencias, estadísticas, historial de visionado)

Usa ambas juntas:
1. Encuentra contenido con la búsqueda de la skill `plex`
2. Comprueba su popularidad con la analítica de la skill `tautulli`
3. Supervisa la reproducción actual con cualquiera de las dos skills
4. Analiza los patrones de visionado con la skill `tautulli`

## Varios servidores

Para usar varias instancias de Tautulli (que supervisan distintos servidores Plex):

```bash
# En ~/.claude/plex-crew/.env
TAUTULLI1_URL="http://server1:8181"
TAUTULLI1_API_KEY="key1"

TAUTULLI2_URL="http://server2:8181"
TAUTULLI2_API_KEY="key2"
```

Después, sobrescribe las variables de entorno:

```bash
# Usar el servidor 1 (por defecto)
./skills/tautulli/scripts/tautulli-api.sh activity

# Usar el servidor 2
TAUTULLI_URL="$TAUTULLI2_URL" TAUTULLI_API_KEY="$TAUTULLI2_API_KEY" \
  ./skills/tautulli/scripts/tautulli-api.sh activity
```

## Referencia

- [Tautulli API Documentation](https://github.com/Tautulli/Tautulli/wiki/Tautulli-API-Reference)
- [Tautulli GitHub](https://github.com/Tautulli/Tautulli)
- [Tautulli Homepage](https://tautulli.com)

Para la referencia detallada de la API, consulta:
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
<parameter name="command">./skills/tautulli/scripts/tautulli-api.sh [command] [args]</parameter>
<parameter name="pty">true</parameter>
</invoke>
```
