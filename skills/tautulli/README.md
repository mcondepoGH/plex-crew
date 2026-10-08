# Skill de analítica de Tautulli

Supervisa y analiza el uso de tu Plex Media Server con la completa API de analítica de Tautulli.

## Qué hace

- **Actividad actual** — Supervisa los streams activos y la reproducción en tiempo real
- **Historial de reproducción** — Consulta el historial de visionado detallado con filtros
- **Estadísticas de usuarios** — Sigue los patrones de visionado y la actividad de los usuarios
- **Analítica de bibliotecas** — Analiza el uso de las bibliotecas y el contenido popular
- **Añadido recientemente** — Consulta el contenido nuevo con metadatos detallados
- **Analítica de streams** — Analiza los tipos de stream, las plataformas y el ancho de banda
- **Patrones temporales** — Entiende las tendencias de visionado por hora y fecha
- **Streams simultáneos** — Supervisa los límites de reproducción simultánea

Todas las operaciones son de solo lectura y usan la API de Tautulli para una analítica completa de Plex.

## Qué es Tautulli

Tautulli es una aplicación de monitorización y seguimiento para Plex Media Server. Ofrece:
- Monitorización de la actividad en tiempo real
- Estadísticas históricas de reproducción
- Analítica de usuarios y bibliotecas
- Sistemas de notificaciones
- Metadatos y carátulas detallados
- Gráficos personalizados

Esta skill te da acceso por línea de comandos a la API de analítica de Tautulli.

## Configuración

### 1. Instala Tautulli

Si no tienes Tautulli instalado:

**Docker:**
```bash
docker run -d \
  --name tautulli \
  -p 8181:8181 \
  -v /path/to/config:/config \
  -e TZ=America/New_York \
  ghcr.io/tautulli/tautulli
```

**Instalación manual:**
Sigue las instrucciones de https://github.com/Tautulli/Tautulli#installation

### 2. Configura Tautulli

1. Abre la interfaz web de Tautulli (por defecto: http://localhost:8181)
2. Conéctala a tu Plex Media Server
3. Deja que recopile algunos datos históricos (al menos unas horas)

### 3. Obtén tu clave de API

1. En Tautulli, ve a **Settings → Web Interface**
2. Desplázate hasta la sección **API**
3. Marca la casilla **"API enabled"**
4. Copia tu **API Key**

### 4. Añádela a las variables de entorno

Añade tus credenciales de Tautulli a `~/.claude/plex-crew/.env`:

```bash
# Tautulli Analytics
TAUTULLI_URL="http://192.168.1.100:8181"
TAUTULLI_API_KEY="<your_api_key>"
```

**Opciones de configuración:**
- `TAUTULLI_URL`: URL de tu servidor Tautulli con el puerto (puerto por defecto: 8181)
- `TAUTULLI_API_KEY`: tu clave de API de Tautulli, que se encuentra en Settings

### 5. Pruébalo

```bash
cd skills/tautulli
./scripts/tautulli-api.sh server-info
```

Deberías ver una salida JSON con la versión de tu servidor Tautulli.

## Ejemplos de uso

Todos los ejemplos usan el script auxiliar `tautulli-api.sh`.

### Supervisar la actividad actual

Consulta quién está viendo algo ahora mismo:

```bash
./scripts/tautulli-api.sh activity
```

**La salida incluye:**
- Número de streams activos
- Información del usuario
- Detalles del contenido (título, año, valoración)
- Información del reproductor (dispositivo, ubicación)
- Calidad del stream y ancho de banda
- Estado de transcodificación

### Ver el historial de visionado

Historial de reproducción reciente:

```bash
# Últimas 25 reproducciones (por defecto)
./scripts/tautulli-api.sh history

# Últimas 50 reproducciones
./scripts/tautulli-api.sh history --limit 50

# Historial de la última semana
./scripts/tautulli-api.sh history --days 7

# Historial de un usuario concreto
./scripts/tautulli-api.sh history --user "john"

# Solo películas
./scripts/tautulli-api.sh history --media-type movie

# Buscar un título concreto
./scripts/tautulli-api.sh history --search "Inception"
```

### Estadísticas de usuarios

Sigue los patrones de visionado de los usuarios:

```bash
# Todos los usuarios
./scripts/tautulli-api.sh user-stats

# Un usuario concreto
./scripts/tautulli-api.sh user-stats --user "john"

# Los 10 usuarios más activos
./scripts/tautulli-api.sh user-stats --sort-by plays --limit 10

# Actividad de los últimos 30 días
./scripts/tautulli-api.sh user-stats --days 30
```

### Estadísticas de bibliotecas

Analiza tus bibliotecas:

```bash
# Listar todas las bibliotecas
./scripts/tautulli-api.sh libraries

# Estadísticas de una biblioteca concreta (sustituye 1 por el ID de tu biblioteca)
./scripts/tautulli-api.sh library-stats --section-id 1

# Películas más populares
./scripts/tautulli-api.sh popular --media-type movie --limit 10

# Lo más visto en los últimos 30 días
./scripts/tautulli-api.sh popular --section-id 1 --days 30
```

### Contenido añadido recientemente

Consulta las novedades:

```bash
# Últimas 25 incorporaciones (por defecto)
./scripts/tautulli-api.sh recent

# Últimas 50 incorporaciones
./scripts/tautulli-api.sh recent --limit 50

# Solo películas recientes
./scripts/tautulli-api.sh recent --media-type movie

# Incorporaciones de la última semana
./scripts/tautulli-api.sh recent --days 7
```

### Analítica de streams

Entiende cómo se está transmitiendo el contenido:

```bash
# Tipos de stream (reproducción directa frente a transcodificación)
./scripts/tautulli-api.sh plays-by-stream --days 30

# Distribución por plataforma (Roku, Apple TV, etc.)
./scripts/tautulli-api.sh plays-by-platform --days 30

# Reproducciones por fecha
./scripts/tautulli-api.sh plays-by-date --days 30

# Reproducciones por hora del día
./scripts/tautulli-api.sh plays-by-hour --days 7

# Reproducciones por día de la semana
./scripts/tautulli-api.sh plays-by-day --days 30
```

### Streams simultáneos

Supervisa la reproducción simultánea:

```bash
# Historial de streams simultáneos
./scripts/tautulli-api.sh concurrent-streams --days 30

# Pico de streams simultáneos
./scripts/tautulli-api.sh concurrent-streams --days 7 --peak
```

### Estadísticas del panel

Obtén estadísticas generales como las de la página de inicio de Tautulli:

```bash
# Estadísticas globales
./scripts/tautulli-api.sh home-stats

# Últimos 30 días
./scripts/tautulli-api.sh home-stats --days 30
```

### Metadatos de contenido

Obtén información detallada de un contenido concreto:

```bash
# Por rating key de Plex
./scripts/tautulli-api.sh metadata --rating-key 12345

# Por GUID de Plex
./scripts/tautulli-api.sh metadata --guid "plex://movie/5d776..."
```

## Flujo de trabajo

### Supervisar los streams activos

Cuando alguien pregunte "¿Quién está viendo algo?" o "¿Qué se está reproduciendo?":

1. Ejecuta `activity` para ver las sesiones actuales
2. Comprueba si hay problemas de buffering o transcodificación
3. Si hay problemas, investiga el historial del usuario con `history --user "username"`
4. Consulta las estadísticas de biblioteca para ver si el contenido es popular

### Analizar la popularidad del contenido

Al planificar actualizaciones de la biblioteca o identificar favoritos:

1. Ejecuta `home-stats` para tener una visión general
2. Usa `popular` para encontrar el contenido más visto
3. Filtra por tipo de contenido y periodo
4. Contrasta con `library-stats` para obtener datos por sección

### Entender el comportamiento de los usuarios

Al analizar patrones de uso:

1. Obtén la lista de usuarios con `user-stats`
2. Profundiza en usuarios concretos con `user-stats --user "name"`
3. Consulta las horas de visionado con `plays-by-hour` y `plays-by-day`
4. Revisa el historial de visionado con `history --user "name"`

### Optimizar el rendimiento del servidor

Al investigar el rendimiento:

1. Consulta `plays-by-stream` para ver las proporciones de transcodificación
2. Identifica problemas por plataforma con `plays-by-platform`
3. Supervisa la carga simultánea con `concurrent-streams`
4. Revisa las sesiones activas con `activity`

## Interpretación de los datos

### Tipos de stream

- **Direct Play**: sin transcodificación, rendimiento óptimo
- **Direct Stream**: solo conversión del contenedor
- **Transcode**: conversión completa de vídeo/audio (consume mucha CPU)

### IDs de sección de biblioteca

Los IDs de sección de biblioteca en Tautulli coinciden con las claves de biblioteca de Plex:
- Normalmente 1 = Películas
- Normalmente 2 = Series
- Ejecuta el comando `libraries` para ver tus IDs concretos

### Rangos de tiempo

La mayoría de los comandos admiten el parámetro `--days N`:
- `--days 1`: últimas 24 horas
- `--days 7`: última semana
- `--days 30`: último mes
- `--days 365`: último año

### Identificación de usuarios

- **Friendly Name**: nombre para mostrar (p. ej., "John Smith")
- **Username**: nombre de usuario de Plex (p. ej., "jsmith")
- Usa los nombres amigables para la salida dirigida al usuario
- Usa los nombres de usuario para la automatización y el filtrado

## Referencia de la API

Hay documentación detallada de la API en el directorio `references/`:

- **[Endpoints de la API](./references/api-endpoints.md)** - Referencia completa de la API de Tautulli
- **[Referencia rápida](./references/quick-reference.md)** - Operaciones habituales con ejemplos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Soluciones a problemas de autenticación, conexión y errores

## Integración con la skill de Plex

Esta skill complementa la skill `plex` existente:

| Funcionalidad | Skill de Plex | Skill de Tautulli |
|---------|-----------|----------------|
| **Sesiones actuales** | ✅ Tiempo real | ✅ Tiempo real + ancho de banda |
| **Buscar contenido** | ✅ Todas las bibliotecas | ❌ (usa Plex) |
| **Explorar bibliotecas** | ✅ Exploración completa | ✅ Solo estadísticas |
| **Historial de visionado** | ❌ | ✅ Historial detallado |
| **Estadísticas de usuarios** | ❌ | ✅ Analítica completa |
| **Contenido popular** | ❌ | ✅ Análisis de tendencias |
| **Analítica de streams** | ❌ | ✅ Estadísticas de transcodificación |
| **Tendencias temporales** | ❌ | ✅ Patrones por tiempo |

**Usa ambas juntas:**
1. Encuentra contenido con la skill `plex`
2. Comprueba su popularidad con la skill `tautulli`
3. Supervisa los streams con cualquiera de las dos skills
4. Analiza los patrones con la skill `tautulli`

## Resolución de problemas

### "Connection refused" o timeout

**Causas:**
- Tautulli no está en ejecución
- URL o puerto incorrectos
- Un firewall bloquea la conexión

**Soluciones:**
```bash
# Comprobar si Tautulli está en ejecución
curl -I http://localhost:8181

# Verificar la URL en .env
echo $TAUTULLI_URL

# Probar con la URL completa
curl "http://localhost:8181/api/v2?apikey=<your_api_key>&cmd=get_server_info"
```

### "Invalid API key" o error de autenticación

**Causas:**
- La clave de API es incorrecta
- La API no está activada
- La clave tiene caracteres especiales sin escapar correctamente

**Soluciones:**
1. Verifica que la API está activada en Settings → Web Interface → API
2. Copia la clave de API con cuidado (sin espacios)
3. Regenera la clave de API si es necesario
4. Comprueba que el fichero `~/.claude/plex-crew/.env` no tiene comillas alrededor de la clave

### Datos vacíos o ausentes

**Causas:**
- Historial insuficiente
- La biblioteca aún no se ha escaneado
- No hay actividad de reproducción reciente

**Soluciones:**
1. Espera a que Tautulli recopile datos (se ejecuta cada pocos minutos)
2. Asegúrate de que Plex está conectado en los ajustes de Tautulli
3. Revisa los registros de Tautulli en busca de errores
4. Aumenta el parámetro `--limit` si la paginación oculta datos

### Error "No section_id"

**Causa:** no se especificó el ID de sección de biblioteca cuando era necesario

**Solución:**
```bash
# Lista primero las bibliotecas disponibles
./scripts/tautulli-api.sh libraries

# Después usa el section_id correcto
./scripts/tautulli-api.sh library-stats --section-id 1
```

## Notas

- Tautulli usa el puerto 8181 por defecto
- Los datos históricos dependen de los ajustes de retención (por defecto: ilimitado)
- Las estadísticas son más significativas cuanto más datos se acumulan con el tiempo
- Las consultas grandes pueden tardar según el tamaño de la base de datos
- Los IDs de sección de biblioteca coinciden con las claves de sección de Plex
- Por defecto se muestran los nombres amigables en la mayoría de las salidas
- Los rating keys son los identificadores únicos de contenido de Plex
- Todas las operaciones son de solo lectura y seguras para supervisar

## Consideraciones de rendimiento

- **Bases de datos grandes**: las consultas pueden ser lentas en servidores con años de datos
- **Filtros complejos**: varios filtros aumentan el tiempo de consulta
- **Rangos de tiempo**: los rangos más cortos (--days 7) son más rápidos que los largos
- **Límites**: usa `--limit` para reducir el tamaño del resultado y mejorar la velocidad

**Consejos de optimización:**
- Usa filtros específicos para acotar los resultados
- Consulta datos recientes (--days) en lugar de todo el histórico
- Usa límites razonables (--limit 50 en lugar de 1000)
- Guarda en caché los resultados de las consultas frecuentes

## Seguridad

- No expongas nunca tu clave de API en registros ni commits
- Usa variables de entorno para las credenciales
- Mantén tu clave de API segura: concede acceso de lectura a toda la analítica
- Considera usar la autenticación HTTP Basic de Tautulli para mayor seguridad
- Rota las claves de API con regularidad si se comparten

## Licencia

MIT
