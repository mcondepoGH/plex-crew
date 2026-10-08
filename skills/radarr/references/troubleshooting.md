# Resolución de problemas de la API de Radarr

## Problemas de autenticación

### "401 Unauthorized"
**Causa:** clave de API no válida o ausente

**Solución:**
1. Obtén la clave de API en Settings → General → Security → API Key
2. Añádela a `~/.claude/plex-crew/.env`: `RADARR_API_KEY="<your_api_key>"`
3. Verifica la clave en la petición: `curl -v "$RADARR_URL/api/v3/system/status" -H "X-Api-Key: $KEY"`
4. Comprueba que la clave no tenga espacios ni caracteres de más
5. Asegúrate de que el nombre de la cabecera sea `X-Api-Key` (distingue mayúsculas y minúsculas)

### "403 Forbidden"
**Causa:** endpoint de la API deshabilitado o restringido

**Solución:**
1. Settings → General → Security → Authentication
2. Asegúrate de que "Authentication" no esté en "Disabled"
3. Comprueba si el acceso a la API está restringido por dirección IP
4. Verifica que Radarr no esté en modo de solo lectura

## Problemas de conexión

### "ECONNREFUSED" o tiempo de espera agotado
**Causa:** Radarr no está en ejecución o el puerto es incorrecto

**Solución:**
1. Comprueba el servicio: `curl http://localhost:7878/api/v3/system/status`
2. Verifica el puerto en Settings → General → Port (por defecto: 7878)
3. Revisa los logs de Docker: `docker logs radarr`
4. Verifica la URL base si está configurada: `/api/v3` pasa a ser `/<urlbase>/api/v3`

### "SSL certificate problem"
**Causa:** certificado SSL no válido o autofirmado

**Solución:**
1. Usa la opción `-k` para pruebas: `curl -k https://...`
2. Instala un certificado SSL adecuado o usa HTTP para pruebas locales
3. Añade el certificado al almacén de confianza del sistema

## Problemas de gestión de películas

### "404 Not Found" al añadir una película
**Causa:** ID de TMDB o slug de la película no válidos

**Solución:**
1. Busca primero: `GET /api/v3/movie/lookup?term=...`
2. Usa el `tmdbId` y el `titleSlug` exactos de los resultados de la búsqueda
3. Verifica que la película existe en TMDB

### "400 Bad Request" al añadir una película
**Causa:** faltan campos obligatorios o la ruta no es válida

**Solución:**
1. Campos obligatorios: `title`, `qualityProfileId`, `titleSlug`, `tmdbId`, `path`, `monitored`
2. Asegúrate de que la ruta no exista ya
3. Verifica que el ID del perfil de calidad existe: `GET /api/v3/qualityprofile`
4. Comprueba que la carpeta raíz está configurada: `GET /api/v3/rootfolder`

### Película añadida pero sin búsqueda
**Causa:** búsqueda desactivada en las opciones de alta

**Solución:**
1. Incluye en la petición de alta:
   ```json
   "addOptions": {
     "searchForMovie": true
   }
   ```
2. O lanza la búsqueda manualmente: `POST /api/v3/command` con `{"name": "MoviesSearch", "movieIds": [1]}`

### No se puede eliminar la película
**Causa:** problemas de permisos o archivos bloqueados

**Solución:**
1. Comprueba los permisos del sistema de archivos
2. Usa el parámetro `deleteFiles=true` si es necesario
3. Detén antes las descargas activas
4. Revisa los volúmenes montados de Docker si usas contenedores

## Problemas de descarga

### Las descargas no se inician
**Causa:** no hay indexadores configurados o hay problemas de conexión

**Solución:**
1. Verifica los indexadores: Settings → Indexers (o `GET /api/v3/indexer`)
2. Prueba las conexiones de los indexadores
3. Comprueba la sincronización con Prowlarr si lo usas
4. Verifica que el cliente de descargas está configurado: `GET /api/v3/downloadclient`

### "No results found" al buscar
**Causa:** los indexadores no devuelven resultados o los requisitos de calidad son demasiado estrictos

**Solución:**
1. Prueba la búsqueda manual: `GET /api/v3/release?movieId=...`
2. Revisa la configuración del corte (cutoff) del perfil de calidad
3. Verifica que los indexadores admiten películas (algunos son solo de series)
4. Revisa los límites de peticiones del indexador
5. Espera a que el release esté disponible (comprueba la fecha de estreno)

### Elementos de la cola atascados en "Downloading"
**Causa:** problema de comunicación con el cliente de descargas

**Solución:**
1. Comprueba el estado del cliente de descargas: `GET /api/v3/downloadclient`
2. Prueba manualmente la conexión con el cliente de descargas
3. Verifica las credenciales y las claves de API
4. Revisa los logs del cliente de descargas
5. Elimina el elemento atascado: `DELETE /api/v3/queue/{id}?removeFromClient=true`

## Problemas de importación

### Las películas no se importan
**Causa:** problemas de nomenclatura de archivos o de permisos

**Solución:**
1. Revisa en el historial los fallos de importación: `GET /api/v3/history?eventType=downloadFailed`
2. Verifica que el nombre del archivo coincide con el patrón esperado: Settings → Media Management → Movie Naming
3. Comprueba los permisos de archivos (Docker: asegúrate de que PUID/PGID coinciden)
4. Revisa las importaciones fallidas: `GET /api/v3/queue?includeUnknownMovieItems=true`

### Se importó una película incorrecta
**Causa:** error al interpretar el nombre de archivo o discrepancia con TMDB

**Solución:**
1. Usa una nomenclatura adecuada: `Movie Title (Year).ext`
2. Incluye el año en el nombre de archivo para evitar ambigüedades
3. Asócialo manualmente desde la interfaz si la búsqueda por API falla
4. Revisa en TMDB si hay títulos alternativos

## Problemas del calendario

### El calendario muestra fechas de estreno incorrectas
**Causa:** diferencias de fechas de estreno por región

**Solución:**
1. Settings → UI → First Day of Week (para la visualización del calendario)
2. Usa los campos `physicalRelease` o `digitalRelease` en lugar de `inCinemas`
3. Los datos de TMDB pueden variar según la región

### Faltan películas en el calendario
**Causa:** las películas no están monitorizadas o no tienen fecha de estreno

**Solución:**
1. Verifica que la película está monitorizada: `GET /api/v3/movie/{id}` y comprueba `monitored: true`
2. Comprueba si existe fecha de estreno en TMDB
3. Actualiza los metadatos de la película: `POST /api/v3/command` con `{"name": "RefreshMovie", "movieId": 1}`

## Problemas de colecciones

### Las colecciones no se sincronizan
**Causa:** límites de peticiones de la API de TMDB o problemas de red

**Solución:**
1. Actualiza las colecciones: `POST /api/v3/command` con `{"name": "RefreshCollections"}`
2. Comprueba el estado de la API de TMDB
3. Espera y reintenta (las colecciones se sincronizan periódicamente)

### Las películas no se añaden automáticamente a la colección
**Causa:** monitorización de colecciones desactivada

**Solución:**
1. Activa la monitorización de colecciones: `PUT /api/v3/collection/{id}` con `{"monitored": true, "searchOnAdd": true}`
2. Añade manualmente las películas que faltan desde los detalles de la colección

## Problemas de listas de importación

### Las listas de importación no se sincronizan
**Causa:** URL de la lista inaccesible o credenciales de la API no válidas

**Solución:**
1. Prueba la URL de la lista manualmente
2. Verifica las credenciales si son necesarias
3. Comprueba que el formato de la lista coincide con lo que espera Radarr
4. Activa la lista de importación: `GET /api/v3/importlist` y comprueba `enabled: true`
5. Lanza una sincronización manual: `POST /api/v3/command` con `{"name": "ImportListSync"}`

### Películas duplicadas desde listas de importación
**Causa:** la película ya existe en la biblioteca

**Solución:**
1. Es el comportamiento esperado (Radarr no añade duplicados)
2. Busca títulos alternativos o IDs de TMDB distintos
3. Usa exclusiones si es necesario: Settings → Import Lists → Exclusions

## Problemas de rendimiento

### Respuestas lentas de la API
**Causa:** biblioteca grande o recursos limitados

**Solución:**
1. Usa paginación: `?page=1&pageSize=50`
2. Filtra las peticiones por ID
3. Aumenta la memoria asignada (Docker: `--memory 1g`)
4. Desactiva los indexadores que no uses
5. Reduce el intervalo de sincronización RSS

### Errores de base de datos bloqueada
**Causa:** límites de concurrencia de SQLite

**Solución:**
1. Haz primero una copia de seguridad de la base de datos
2. Reinicia Radarr
3. Revisa la E/S de disco (los discos lentos provocan bloqueos)
4. Reduce las operaciones concurrentes
5. Considera migrar la base de datos a PostgreSQL (v5+)

## Problemas de metadatos

### Faltan pósteres o ilustraciones
**Causa:** problemas con TMDB o con el proveedor de metadatos

**Solución:**
1. Actualiza los metadatos: `POST /api/v3/command` con `{"name": "RefreshMovie"}`
2. Borra la caché de metadatos: Settings → General → Clear Metadata Cache
3. Comprueba en TMDB si hay imágenes disponibles
4. Espera 24 horas a que se sincronicen los metadatos

### Información de película incorrecta
**Causa:** datos de TMDB incorrectos u obsoletos

**Solución:**
1. Informa a TMDB si los datos son erróneos
2. Actualiza la película: `POST /api/v3/command` con `{"name": "RefreshMovie", "movieId": 1}`
3. Vuelve a añadir la película si persiste
4. Busca entradas alternativas en TMDB

## Limitaciones conocidas

- **TMDB obligatorio:** no se pueden añadir películas sin un ID de TMDB válido
- **Sin API de alta masiva:** hay que añadir las películas de una en una (usa bucles)
- **Corte de calidad:** una vez alcanzado, no se mejora salvo que se fuerce
- **Películas eliminadas:** el historial se conserva incluso tras eliminar la película
- **4K/HDR:** requiere perfiles de calidad e instancias separados para cada versión

## Problemas específicos de versión

### Diferencias de API entre v3 y v5
- v5 usa el mismo endpoint `/api/v3` (confuso pero cierto)
- v5 añade mejor soporte de colecciones
- v5 incluye puntuación de formatos personalizados
- Comprueba la versión: `GET /api/v3/system/status` devuelve el campo `version`

### Migración desde la API v2
- La API v2 está obsoleta, usa v3
- Actualiza todos los scripts a endpoints `/api/v3`
- Los formatos de respuesta son mayormente compatibles, pero valídalos

## Modo de depuración

Activa el registro de depuración para obtener información detallada de los errores:

1. Settings → General → Log Level → Debug (o Trace para más detalle)
2. Reinicia Radarr
3. Revisa los logs: `/config/logs/radarr.txt` (Docker) o UI → System → Logs
4. Filtra por componente: `API` para logs específicos de la API

## Mensajes de error comunes

| Error | Causa | Solución |
|-------|-------|----------|
| "Movie already exists" | Película duplicada | Comprueba primero las películas existentes |
| "Quality profile does not exist" | ID de perfil no válido | Obtén IDs válidos en `/api/v3/qualityprofile` |
| "Root folder does not exist" | Ruta no válida | Configura las carpetas raíz en Settings |
| "Unable to add, path already configured" | Ruta duplicada | Usa otra ruta o elimina la existente |
| "Indexer not available" | Indexador caído/deshabilitado | Comprueba el estado y la conexión del indexador |
| "Download client not available" | Cliente caído/mal configurado | Verifica la configuración del cliente de descargas |
| "Movie not found" | ID de película no válido | Obtén el ID de la película en `/api/v3/movie` |
| "Movie has not been released yet" | Fecha de estreno futura | Espera al estreno o comprueba la fecha |
