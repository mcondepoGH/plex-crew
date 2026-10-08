# Resolución de problemas de la API de Prowlarr

## Problemas de autenticación

### "401 Unauthorized"
**Causa:** Clave de API no válida o ausente

**Solución:**
1. Obtén la clave de API en Settings → General → Security → API Key
2. Verifica la clave en la petición: `curl -v "$PROWLARR_URL/api/v1/system/status" -H "X-Api-Key: $KEY"`
3. Comprueba que no haya espacios ni caracteres de más en la clave
4. Asegúrate de que el nombre de la cabecera sea `X-Api-Key` (distingue mayúsculas y minúsculas)

### "403 Forbidden"
**Causa:** Endpoint de la API deshabilitado o restringido

**Solución:**
1. Settings → General → Security → Authentication
2. Asegúrate de que "Authentication" no esté configurado como "Disabled"
3. Comprueba si el acceso a la API está restringido por dirección IP

## Problemas de conexión

### "ECONNREFUSED" o tiempo de espera agotado
**Causa:** Prowlarr no está en ejecución o el puerto es incorrecto

**Solución:**
1. Comprueba el servicio: `curl http://localhost:9696/api/v1/system/status`
2. Verifica el puerto en Settings → General → Port (por defecto: 9696)
3. Revisa los registros de Docker: `docker logs prowlarr`
4. Verifica la URL base si está configurada: `/api/v1` pasa a ser `/<urlbase>/api/v1`

### "SSL certificate problem"
**Causa:** Certificado SSL no válido o autofirmado

**Solución:**
1. Usa la opción `-k` para pruebas: `curl -k https://...`
2. Instala un certificado SSL adecuado o usa HTTP para pruebas locales
3. Añade el certificado al almacén de confianza del sistema

## Problemas de indexadores

### "404 Not Found" al añadir un indexador
**Causa:** Nombre de implementación del indexador no válido

**Solución:**
1. Obtén las implementaciones válidas: `GET /api/v1/indexer/schema`
2. Usa exactamente `implementation` e `implementationName` del esquema
3. Revisa la ortografía y las mayúsculas

### "400 Bad Request" al añadir un indexador
**Causa:** Faltan campos obligatorios o la configuración no es válida

**Solución:**
1. Obtén el esquema del indexador: `GET /api/v1/indexer/schema`
2. Revisa los campos obligatorios del esquema
3. Verifica que `configContract` coincida con la implementación
4. Asegúrate de proporcionar todos los ajustes obligatorios

### Indexador añadido pero no funciona
**Causa:** Error de configuración o indexador caído

**Solución:**
1. Prueba el indexador: `POST /api/v1/indexer/test` con `{"id": indexer_id}`
2. Comprueba que la URL del indexador sea accesible
3. Verifica las credenciales si son necesarias (claves de API, usuario/contraseña)
4. Revisa los límites de tasa del indexador
5. Revisa los registros de Prowlarr: Settings → System → Logs

### La prueba del indexador falla
**Causa:** Problemas de conectividad de red o credenciales no válidas

**Solución:**
1. Prueba la URL del indexador manualmente (navegador o curl)
2. Verifica la configuración de VPN/proxy si el indexador la requiere
3. Comprueba la resolución DNS
4. Verifica que las credenciales sean correctas
5. Asegúrate de que el indexador admita las llamadas a la API de Prowlarr

### Los indexadores no se sincronizan con las aplicaciones
**Causa:** Aplicación sin configurar o sincronización deshabilitada

**Solución:**
1. Verifica que las aplicaciones estén configuradas: `GET /api/v1/applications`
2. Comprueba el nivel de sincronización de la aplicación: se requiere `fullSync` para la sincronización automática
3. Lanza la sincronización manualmente: `POST /api/v1/command` con `{"name": "ApplicationSync"}`
4. Prueba la conexión de la aplicación: `POST /api/v1/applications/test`
5. Verifica que las claves de API de las aplicaciones sean correctas

## Problemas de búsqueda

### "No results" en las búsquedas
**Causa:** Indexadores sin configurar o problemas con la consulta

**Solución:**
1. Verifica que los indexadores estén habilitados: `GET /api/v1/indexer`
2. Prueba los indexadores de uno en uno con `?indexerIds=1`
3. Comprueba las estadísticas de los indexadores en busca de fallos: `GET /api/v1/indexerstats`
4. Prueba con términos de búsqueda más amplios
5. Verifica que los indexadores admitan el tipo de búsqueda (película/serie/música)

### Respuestas de búsqueda lentas
**Causa:** Varios indexadores agotan el tiempo de espera

**Solución:**
1. Deshabilita los indexadores lentos o averiados
2. Reduce el número de indexadores consultados
3. Comprueba la conectividad de red
4. Revisa las estadísticas de los indexadores: `GET /api/v1/indexerstats`
5. Aumenta el tiempo de espera en Settings → Indexers → Indexer Timeout

### Los resultados de búsqueda no muestran seeders/peers
**Causa:** El indexador no proporciona datos de seeders

**Solución:**
1. Es normal en algunos indexadores
2. Usa indexadores que proporcionen metadatos completos
3. Ordena por otros campos (tamaño, fecha de publicación)

## Problemas de sincronización de aplicaciones

### Sonarr/Radarr no reciben los indexadores
**Causa:** Sincronización sin configurar o credenciales incorrectas

**Solución:**
1. Verifica que la aplicación esté añadida: `GET /api/v1/applications`
2. Prueba la aplicación: `POST /api/v1/applications/test`
3. Comprueba que las claves de API coincidan entre Prowlarr y la aplicación
4. Asegúrate de usar el nivel de sincronización correcto: `fullSync` o `addOnly`
5. Sincroniza manualmente: `POST /api/v1/command` con `{"name": "ApplicationSync"}`

### Indexadores duplicados en Sonarr/Radarr
**Causa:** Indexadores manuales + sincronización de Prowlarr

**Solución:**
1. Elimina los indexadores manuales de Sonarr/Radarr
2. Deja que Prowlarr gestione todos los indexadores mediante la sincronización
3. O deshabilita la sincronización de Prowlarr y gestiónalos manualmente

### La sincronización con las aplicaciones elimina indexadores
**Causa:** Indexador deshabilitado o eliminado en Prowlarr

**Solución:**
1. La sincronización de Prowlarr elimina de las aplicaciones los indexadores deshabilitados
2. Vuelve a habilitar los indexadores en Prowlarr para restaurarlos en las aplicaciones
3. Usa el nivel de sincronización `addOnly` para evitar eliminaciones

## Problemas de clientes de descarga

### La prueba del cliente de descarga falla
**Causa:** Problemas de conexión o de credenciales

**Solución:**
1. Verifica que el cliente de descarga esté en ejecución
2. Comprueba que el host y el puerto sean correctos
3. Prueba las credenciales manualmente
4. Asegúrate de que la API del cliente de descarga esté habilitada
5. Comprueba la conectividad de red (redes de Docker, etc.)

### Las descargas no se inician desde Prowlarr
**Causa:** Prowlarr es solo de búsqueda, no un gestor de descargas

**Solución:**
1. Prowlarr proporciona resultados de búsqueda a las aplicaciones
2. Sonarr/Radarr gestionan las descargas reales
3. Revisa los clientes de descarga en Sonarr/Radarr, no en Prowlarr
4. Los clientes de descarga de Prowlarr son solo para descargas manuales

## Problemas de categorías

### Se sincronizan categorías incorrectas con las aplicaciones
**Causa:** Mapeo de categorías mal configurado

**Solución:**
1. Revisa los ajustes de la aplicación en Prowlarr
2. Verifica `syncCategories` en la configuración de la aplicación
3. Categorías estándar:
   - Películas: 2000-2999
   - Series: 5000-5999
   - Música: 3000-3999
   - Libros: 7000-7999
4. Actualiza la aplicación: `PUT /api/v1/applications/{id}`

## Problemas de rendimiento

### Uso elevado de CPU
**Causa:** Demasiados indexadores o búsquedas frecuentes

**Solución:**
1. Deshabilita los indexadores que no uses
2. Reduce la frecuencia de sincronización RSS
3. Aumenta la duración de la caché de búsquedas
4. Comprueba si hay fallos de indexadores que provoquen reintentos

### Errores de base de datos bloqueada
**Causa:** Límites de concurrencia de SQLite

**Solución:**
1. Haz primero una copia de seguridad de la base de datos
2. Reinicia Prowlarr
3. Reduce las operaciones concurrentes
4. Comprueba el rendimiento de E/S del disco

## Problemas del historial

### Faltan entradas del historial
**Causa:** Limpieza del historial o problema de base de datos

**Solución:**
1. Revisa los ajustes de retención del historial
2. El historial solo conserva las entradas recientes
3. Revisa los registros de la base de datos en busca de errores
4. Aumenta la retención del historial si es necesario

## Problemas de notificaciones

### Las notificaciones no funcionan
**Causa:** Servicio de notificaciones mal configurado

**Solución:**
1. Prueba la notificación: `POST /api/v1/notification/test`
2. Verifica las credenciales del servicio de notificaciones
3. Comprueba que los disparadores de notificación estén habilitados
4. Revisa los registros del servicio de notificaciones

## Limitaciones conocidas

- **Solo búsqueda:** Prowlarr no descarga contenido, solo proporciona resultados de búsqueda
- **Específico de cada indexador:** Algunos indexadores tienen requisitos propios (VPN, credenciales)
- **Límites de tasa:** Muchos indexadores tienen límites de tasa (respétalos)
- **Sin búsqueda masiva:** Busca una consulta cada vez mediante la API
- **Límites de categorías:** No todos los indexadores admiten todas las categorías

## Problemas específicos de versión

### API v1 (actual)
- API estable desde la v1.0
- Los cambios incompatibles se anuncian en las notas de la versión
- Comprueba la versión: `GET /api/v1/system/status` devuelve el campo `version`

### Actualizaciones de definiciones de indexadores
- Los indexadores se actualizan regularmente mediante definiciones
- Settings → System → Updates → Update Definitions
- Puede ser necesario reiniciar tras actualizar las definiciones

## Modo de depuración

Habilita el registro de depuración para obtener información detallada de los errores:

1. Settings → General → Log Level → Debug (o Trace para máxima verbosidad)
2. Reinicia Prowlarr
3. Revisa los registros: `/config/logs/prowlarr.txt` (Docker) o UI → System → Logs
4. Filtra por componente: `API` para los registros específicos de la API

## Mensajes de error comunes

| Error | Causa | Solución |
|-------|-------|----------|
| "Indexer already exists" | Indexador duplicado | Revisa primero los indexadores existentes |
| "Unable to connect to indexer" | Problema de red/cortafuegos | Verifica la conectividad y las credenciales |
| "Invalid API key for application" | Clave de API de la aplicación incorrecta | Actualiza la clave de API en la configuración de la aplicación en Prowlarr |
| "Application sync failed" | Aplicación inaccesible | Prueba la conexión y la red de la aplicación |
| "Indexer returned no results" | Problema con la consulta de búsqueda | Prueba otros términos o revisa el indexador |
| "Rate limit exceeded" | Demasiadas peticiones | Espera y reintenta, reduce la frecuencia |
| "Indexer is unavailable" | Indexador caído | Deshabilita el indexador temporalmente |
| "Invalid search type" | El indexador no admite el tipo | Usa solo indexadores compatibles |
