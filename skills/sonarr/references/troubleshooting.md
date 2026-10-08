# Resolución de problemas de la API de Sonarr

## Problemas de autenticación

### "401 Unauthorized"
**Causa:** clave de API no válida o ausente

**Solución:**
1. Obtén la clave de API en Settings → General → Security → API Key
2. Añádela a `~/.claude/plex-crew/.env`: `SONARR_API_KEY="<your_api_key>"`
3. Verifica la clave en la petición: `curl -v "$SONARR_URL/api/v3/system/status" -H "X-Api-Key: $KEY"`
4. Comprueba que la clave no tenga espacios ni caracteres de más
5. Asegúrate de que el nombre de la cabecera sea `X-Api-Key` (distingue mayúsculas y minúsculas)

### "403 Forbidden"
**Causa:** endpoint de la API deshabilitado o restringido

**Solución:**
1. Settings → General → Security → Authentication
2. Asegúrate de que "Authentication" no esté en "Disabled"
3. Comprueba si el acceso a la API está restringido por dirección IP
4. Verifica que Sonarr no esté en modo de solo lectura

## Problemas de conexión

### "ECONNREFUSED" o tiempo de espera agotado
**Causa:** Sonarr no está en ejecución o el puerto es incorrecto

**Solución:**
1. Comprueba el servicio: `curl http://localhost:8989/api/v3/system/status`
2. Verifica el puerto en Settings → General → Port (por defecto: 8989)
3. Revisa los logs de Docker: `docker logs sonarr`
4. Verifica la URL base si está configurada: `/api/v3` pasa a ser `/<urlbase>/api/v3`

### "SSL certificate problem"
**Causa:** certificado SSL no válido o autofirmado

**Solución:**
1. Usa la opción `-k` para pruebas: `curl -k https://...`
2. Instala un certificado SSL adecuado o usa HTTP para pruebas locales
3. Añade el certificado al almacén de confianza del sistema

## Problemas de gestión de series

### "404 Not Found" al añadir una serie
**Causa:** ID de TVDB o slug de la serie no válidos

**Solución:**
1. Busca primero: `GET /api/v3/series/lookup?term=...`
2. Usa el `tvdbId` y el `titleSlug` exactos de los resultados de la búsqueda
3. Verifica que la serie existe en TheTVDB

### "400 Bad Request" al añadir una serie
**Causa:** faltan campos obligatorios o la ruta no es válida

**Solución:**
1. Campos obligatorios: `title`, `qualityProfileId`, `titleSlug`, `tvdbId`, `path`, `monitored`, `seasonFolder`
2. Asegúrate de que la ruta no exista ya
3. Verifica que el ID del perfil de calidad existe: `GET /api/v3/qualityprofile`
4. Comprueba que la carpeta raíz está configurada: `GET /api/v3/rootfolder`

### Serie añadida pero sin búsqueda
**Causa:** búsqueda desactivada en las opciones de alta

**Solución:**
1. Incluye en la petición de alta:
   ```json
   "addOptions": {
     "searchForMissingEpisodes": true
   }
   ```
2. O lanza la búsqueda manualmente: `POST /api/v3/command` con `{"name": "SeriesSearch", "seriesId": 1}`

### No se puede eliminar la serie
**Causa:** problemas de permisos o archivos bloqueados

**Solución:**
1. Comprueba los permisos del sistema de archivos
2. Usa el parámetro `deleteFiles=true` si es necesario
3. Detén antes las descargas activas
4. Comprueba los montajes de volúmenes de Docker si usas contenedores

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
1. Prueba la búsqueda manual: `GET /api/v3/release?episodeId=...`
2. Revisa la configuración del corte de calidad del perfil
3. Verifica que los indexadores admiten la serie (algunos se especializan)
4. Comprueba los límites de peticiones de los indexadores
5. Usa la sincronización RSS para los releases populares

### Elementos de la cola atascados en "Downloading"
**Causa:** problema de comunicación con el cliente de descargas

**Solución:**
1. Comprueba el estado del cliente de descargas: `GET /api/v3/downloadclient`
2. Prueba manualmente la conexión con el cliente de descargas
3. Verifica las credenciales y las claves de API
4. Revisa los logs del cliente de descargas
5. Elimina el elemento atascado: `DELETE /api/v3/queue/{id}?removeFromClient=true`

## Problemas de episodios

### Los episodios no se importan
**Causa:** problemas de nombres de archivo o de permisos

**Solución:**
1. Comprueba en el historial los fallos de importación: `GET /api/v3/history?eventType=downloadFailed`
2. Verifica que el nombre del archivo coincide con el patrón esperado: Settings → Media Management → Episode Naming
3. Comprueba los permisos de los archivos (Docker: asegúrate de que PUID/PGID coinciden)
4. Revisa las importaciones fallidas: `GET /api/v3/queue?includeUnknownSeriesItems=true`

### Se importó un episodio incorrecto
**Causa:** la numeración de scene no coincide

**Solución:**
1. Activa la numeración de scene si es necesario: Series → Edit → Use Scene Numbering
2. Consulta TheTVDB para ver el orden correcto de los episodios
3. Haz la correspondencia manualmente desde la interfaz si falla la búsqueda por API
4. Renombra el archivo para que coincida con el patrón esperado

## Problemas del calendario

### El calendario muestra episodios duplicados
**Causa:** varios releases del mismo episodio

**Solución:**
1. Es un comportamiento normal: el calendario muestra fechas de emisión, no descargas
2. Filtra por estado de monitorización
3. Comprueba el estado del archivo del episodio: campo `hasFile`

### Faltan episodios en el calendario
**Causa:** la serie o los episodios no están monitorizados

**Solución:**
1. Verifica que la serie está monitorizada: `GET /api/v3/series/{id}` y comprueba `monitored: true`
2. Comprueba la monitorización de los episodios: `GET /api/v3/episode?seriesId={id}`
3. Actualiza los metadatos de la serie: `POST /api/v3/command` con `{"name": "RefreshSeries", "seriesId": 1}`

## Problemas de rendimiento

### Respuestas lentas de la API
**Causa:** biblioteca grande o limitaciones de recursos

**Solución:**
1. Usa paginación: `?page=1&pageSize=50`
2. Filtra las peticiones por serie: `?seriesId=1`
3. Aumenta la memoria asignada (Docker: `--memory 1g`)
4. Desactiva los indexadores que no uses
5. Reduce el intervalo de sincronización RSS

### Errores de base de datos bloqueada
**Causa:** límites de concurrencia de SQLite

**Solución:**
1. Haz primero una copia de seguridad de la base de datos
2. Reinicia Sonarr
3. Comprueba la E/S del disco (los discos lentos provocan bloqueos)
4. Reduce las operaciones concurrentes
5. Valora migrar la base de datos a PostgreSQL (v4+)

## Problemas de metadatos

### Faltan pósteres o ilustraciones
**Causa:** problemas con TheTVDB o con el proveedor de metadatos

**Solución:**
1. Actualiza los metadatos: `POST /api/v3/command` con `{"name": "RefreshSeries"}`
2. Limpia la caché de metadatos: Settings → General → Clear Metadata Cache
3. Comprueba en TheTVDB si hay imágenes disponibles
4. Espera 24 horas a que se sincronicen los metadatos

### Información de serie incorrecta
**Causa:** datos de TheTVDB incorrectos o desactualizados

**Solución:**
1. Informa a TheTVDB si los datos son erróneos
2. Actualiza la serie: `POST /api/v3/command` con `{"name": "RefreshSeries", "seriesId": 1}`
3. Vuelve a añadir la serie si el problema persiste
4. Revisa si hay alias o nombres alternativos

## Limitaciones conocidas

- **TheTVDB obligatorio:** no se pueden añadir series sin un ID de TVDB válido
- **Sin API de alta masiva:** hay que añadir las series de una en una (usa bucles)
- **Numeración de scene:** puede diferir de la numeración de TVDB (usa el interruptor de numeración de scene)
- **Corte de calidad:** una vez alcanzado, no se mejora salvo que se fuerce
- **Episodios eliminados:** el historial se conserva incluso tras eliminar el episodio

## Problemas específicos de versión

### Diferencias de API entre v3 y v4
- v4 usa el mismo endpoint `/api/v3` (confuso, pero cierto)
- v4 añade compatibilidad con PostgreSQL (recomendado para bibliotecas grandes)
- v4 incluye un algoritmo de búsqueda mejorado
- Comprueba la versión: `GET /api/v3/system/status` devuelve el campo `version`

### Migración desde la API v2
- La API v2 está obsoleta; usa la v3
- Actualiza todos los scripts a los endpoints `/api/v3`
- Los formatos de respuesta son en su mayoría compatibles, pero conviene validarlos

## Modo de depuración

Activa el registro de depuración para obtener información detallada de los errores:

1. Settings → General → Log Level → Debug (o Trace para más detalle)
2. Reinicia Sonarr
3. Revisa los logs: `/config/logs/sonarr.txt` (Docker) o UI → System → Logs
4. Filtra por componente: `API` para los logs específicos de la API

## Mensajes de error comunes

| Error | Causa | Solución |
|-------|-------|----------|
| "Series already exists" | Serie duplicada | Comprueba primero las series existentes |
| "Quality profile does not exist" | ID de perfil no válido | Obtén IDs válidos en `/api/v3/qualityprofile` |
| "Root folder does not exist" | Ruta no válida | Configura las carpetas raíz en Settings |
| "Unable to add, path already configured" | Ruta duplicada | Usa otra ruta o elimina la existente |
| "Indexer not available" | Indexador caído/deshabilitado | Comprueba el estado y la conexión del indexador |
| "Download client not available" | Cliente caído/mal configurado | Verifica la configuración del cliente de descargas |
| "Episode not found" | ID de episodio no válido | Obtén el ID del episodio en `/api/v3/episode` |
