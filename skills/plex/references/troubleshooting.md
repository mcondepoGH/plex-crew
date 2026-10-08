# Resolución de problemas de la API de Plex Media Server

## Problemas de autenticación

### "401 Unauthorized"
**Causa:** token de Plex no válido o ausente

**Solución:**
1. Obtén el token en Plex Web App → Settings → Account → Show Advanced → "Get Token"
2. Verifica el token en la petición: `curl -v "$PLEX_URL/identity" -H "X-Plex-Token: $TOKEN"`
3. Comprueba que el token no tenga espacios ni caracteres de más
4. Asegúrate de que el nombre de la cabecera sea `X-Plex-Token` (distingue mayúsculas y minúsculas)

### No se puede obtener el token de Plex mediante la API
**Causa:** credenciales no válidas o autenticación en dos pasos (2FA) activada

**Solución:**
1. Verifica que el correo y la contraseña son correctos
2. Si la 2FA está activada, obtén el token desde la aplicación web (el inicio de sesión por API no funcionará)
3. Genera una contraseña específica de aplicación si la cuenta tiene 2FA
4. Usa la cabecera `X-Plex-Client-Identifier` (obligatoria para la autenticación)

### El token funciona en el navegador pero no en la API
**Causa:** faltan cabeceras obligatorias

**Solución:**
1. Incluye la cabecera `X-Plex-Token`
2. Añade la cabecera `Accept: application/json` para obtener respuestas JSON
3. Algunos endpoints requieren `X-Plex-Client-Identifier`
4. Verifica que la codificación de la URL sea correcta

## Problemas de conexión

### "Connection refused" o tiempo de espera agotado
**Causa:** Plex no está en ejecución o el puerto es incorrecto

**Solución:**
1. Comprueba el servicio: `curl http://localhost:32400/identity`
2. Verifica el puerto (por defecto: 32400)
3. Revisa los logs de Docker: `docker logs plex`
4. Asegúrate de que Plex Media Server está en ejecución

### "Server not found" al usar https://plex.tv
**Causa:** se intenta acceder al servidor local a través de Plex.tv

**Solución:**
1. Usa la URL directa del servidor: `http://SERVER_IP:32400`
2. O descubre el servidor: `curl "https://plex.tv/pms/resources" -H "X-Plex-Token: $TOKEN"`
3. Extrae `connections.uri` de la respuesta
4. Usa la conexión local para obtener el mejor rendimiento

### No se puede acceder a Plex de forma remota
**Causa:** acceso remoto sin configurar o firewall

**Solución:**
1. Activa el acceso remoto en los ajustes de Plex
2. Configura el reenvío de puertos (por defecto: 32400)
3. Revisa las reglas del firewall
4. Usa Plex Relay como alternativa (más lento)

## Problemas de bibliotecas

### La biblioteca no muestra contenido
**Causa:** biblioteca sin escanear o problemas de permisos

**Solución:**
1. Actualiza la biblioteca: `POST /library/sections/LIBRARY_KEY/refresh`
2. Comprueba los permisos de los archivos (el usuario de Plex debe poder leerlos)
3. Verifica que la ruta de la biblioteca es correcta
4. Revisa los logs del escáner de Plex: Settings → Console → Scanner

### "Library not found" (404)
**Causa:** clave de biblioteca no válida

**Solución:**
1. Obtén las claves de biblioteca válidas: `GET /library/sections`
2. Usa el campo `key` de la respuesta (normalmente 1, 2, 3, etc.)
3. Las claves de biblioteca son numéricas, no nombres

### «Añadido recientemente» no se actualiza
**Causa:** el escáner no se ejecuta o problema de caché

**Solución:**
1. Fuerza la actualización: `POST /library/sections/LIBRARY_KEY/refresh?force=1`
2. Vacía la papelera: `PUT /library/sections/LIBRARY_KEY/emptyTrash`
3. Optimiza la base de datos: `PUT /library/optimize`
4. Comprueba que el servicio del escáner de Plex está en ejecución

### Metadatos incorrectos en un elemento
**Causa:** coincidencia incorrecta o problema con el nombre del archivo

**Solución:**
1. Corrige la coincidencia primero desde la interfaz web (la API no permite hacer coincidencias)
2. Asegúrate de que los archivos siguen las convenciones de nombres de Plex
3. Actualiza los metadatos: `PUT /library/metadata/RATING_KEY/refresh`
4. Revisa los ajustes del agente en la configuración de la biblioteca

## Problemas de búsqueda

### La búsqueda no devuelve resultados
**Causa:** codificación de la consulta o biblioteca sin indexar

**Solución:**
1. Codifica la consulta de búsqueda en la URL: `query=inception` → `query=inception`
2. Usa `%20` para los espacios: `breaking%20bad`
3. Actualiza la biblioteca si se añadió hace poco
4. Prueba a buscar en una biblioteca concreta en lugar de hacer una búsqueda global

### La búsqueda devuelve elementos incorrectos
**Causa:** coincidencia aproximada o problemas de metadatos

**Solución:**
1. Usa títulos exactos
2. Incluye el año en la búsqueda: `?query=inception&year=2010`
3. Filtra por tipo: `?type=1` (película), `?type=2` (serie), `?type=4` (episodio)
4. Busca dentro de una biblioteca concreta para obtener mejores resultados

## Problemas de sesiones

### No se muestran las sesiones activas
**Causa:** no hay reproducción activa o retraso de caché

**Solución:**
1. Verifica que realmente hay una reproducción en curso
2. Espera unos segundos (las sesiones se actualizan cada 5-10 s)
3. Comprueba específicamente el endpoint `/status/sessions`
4. Usa la respuesta XML si el JSON está vacío: quita la cabecera `Accept: application/json`

### No se puede terminar una sesión
**Causa:** ID de sesión no válido o problema de permisos

**Solución:**
1. Obtén primero un ID de sesión válido de las sesiones activas
2. Usa el endpoint correcto: `DELETE /status/sessions/terminate?sessionId=...`
3. Solo el propietario del servidor puede terminar sesiones
4. Es posible que la sesión ya haya terminado por sí sola

## Problemas de transcodificación

### No se ven las sesiones de transcodificación
**Causa:** no hay transcodificación activa o el endpoint cambió

**Solución:**
1. Verifica que realmente se está transcodificando (comprueba la interfaz web)
2. Usa el endpoint `/transcode/sessions`
3. La reproducción directa (direct play/stream) no aparece en las sesiones de transcodificación
4. Comprueba las capacidades del servidor: parte de la reproducción es directa

### Sesión de transcodificación bloqueada
**Causa:** fallo del transcodificador o agotamiento de recursos

**Solución:**
1. Termina la transcodificación: `DELETE /transcode/sessions/SESSION_KEY`
2. Comprueba los recursos del servidor (CPU, RAM)
3. Reinicia Plex Media Server si persiste
4. Revisa los logs del transcodificador: Settings → Console → Transcoder

## Problemas de listas de reproducción

### No se puede crear una lista de reproducción
**Causa:** faltan parámetros obligatorios o URI no válida

**Solución:**
1. Incluye todos los parámetros obligatorios: `type`, `title`, `uri`
2. Formato de la URI: `server://MACHINE_ID/com.plexapp.plugins.library/library/metadata/RATING_KEY`
3. Obtén el ID de la máquina desde `/identity`
4. Créala desde la interfaz web y luego inspecciónala mediante la API

### Los elementos de la lista de reproducción no se muestran
**Causa:** ID de lista incorrecto o lista vacía

**Solución:**
1. Obtén los IDs de lista válidos: `GET /playlists`
2. Usa el `ratingKey` de la lista de listas de reproducción
3. Comprueba `leafCount` (número de elementos) en los metadatos de la lista

## Problemas de gestión de usuarios

### No se ven los usuarios compartidos
**Causa:** no se es el propietario del servidor o Plex Home no está configurado

**Solución:**
1. Solo el propietario del servidor puede gestionar usuarios
2. Usa la API de plex.tv para compartir: `https://plex.tv/api/v2/shared_servers`
3. Los usuarios de Plex Home y los usuarios compartidos son distintos
4. Algunas operaciones requieren autenticación en plex.tv, no local

## Problemas de formato de respuesta

### Se recibe XML en lugar de JSON
**Causa:** falta la cabecera Accept

**Solución:**
1. Añade la cabecera: `-H "Accept: application/json"`
2. Plex devuelve XML por defecto en la mayoría de los endpoints
3. Ambos formatos contienen los mismos datos
4. Usa `jq` para JSON y `xmllint` para XML

### La respuesta está vacía pero el estado es 200
**Causa:** no hay datos disponibles o el filtro es demasiado restrictivo

**Solución:**
1. Comprueba `.MediaContainer.size` en la respuesta
2. Prueba primero sin filtros
3. Verifica que la biblioteca o el elemento existe
4. Algunos endpoints devuelven un array vacío cuando no hay datos

### Respuesta JSON mal formada
**Causa:** versión de Plex o problema del endpoint

**Solución:**
1. Actualiza Plex Media Server
2. Prueba con la respuesta XML
3. Consulta los foros de Plex por si hay problemas conocidos
4. Usa la interfaz web como alternativa

## Problemas de rendimiento

### Respuestas lentas de la API
**Causa:** biblioteca grande o problemas de la base de datos

**Solución:**
1. Optimiza la base de datos: `PUT /library/optimize`
2. Usa paginación y límites: `?limit=100`
3. Filtra las peticiones por bibliotecas concretas
4. Limpia los bundles: `PUT /library/clean/bundles`
5. Compacta la base de datos (requiere reiniciar el servidor)

### Uso alto de CPU durante el escaneo de la biblioteca
**Causa:** es normal en colecciones multimedia grandes

**Solución:**
1. Programa los escaneos fuera de horas punta
2. Desactiva "Scan my library automatically"
3. Usa escaneos manuales por API: `POST /library/sections/LIBRARY_KEY/refresh`
4. Reduce la concurrencia del escáner en los ajustes

## Limitaciones conocidas

- **Sin operaciones masivas:** la mayoría de las operaciones son por elemento
- **API de coincidencias limitada:** no se pueden corregir las coincidencias de metadatos mediante la API (usa la interfaz web)
- **Funciones de Plex Pass:** algunas funciones requieren una suscripción a Plex Pass
- **Seguridad del token:** los tokens son muy potentes; trátalos como contraseñas
- **Límite de peticiones:** la API de Plex.tv tiene límites de peticiones (el servidor local no)
- **XML por defecto:** la mayoría de los endpoints devuelven XML por defecto (usa la cabecera Accept para obtener JSON)

## Problemas específicos de cada versión

### Versiones de Plex Media Server
- **1.25+:** API moderna con mejor compatibilidad con JSON
- **1.30+:** compatibilidad mejorada con webhooks
- **1.32+:** gestión de transcodificación mejorada
- Comprueba la versión: `GET /identity` devuelve el campo `version`

### Cambios en la API
- Los servidores antiguos pueden no admitir todos los endpoints
- Algunas funciones se eliminaron en versiones más recientes
- Consulta los foros oficiales de Plex por si hay avisos de obsolescencia

## Modo de depuración

Activa el registro de depuración:

1. Settings → Server → General → Log Level → "Debug"
2. O mediante la API: actualiza las preferencias
3. Revisa los logs: `~/Library/Application Support/Plex Media Server/Logs/` (Mac/Linux)
4. Docker: `docker logs plex` o `/config/Library/Application Support/Plex Media Server/Logs/`

## Mensajes de error comunes

| Error | Causa | Solución |
|-------|-------|----------|
| "Unauthorized" | Token no válido o ausente | Obtén un token nuevo desde la aplicación web |
| "Not found" | ID o clave no válidos | Verifica que el ID existe mediante un endpoint de listado |
| "Forbidden" | Permiso denegado | Asegúrate de que el token tiene los privilegios adecuados |
| "Bad request" | Petición mal formada | Comprueba el formato de los parámetros |
| "Internal server error" | Problema del servidor Plex | Revisa los logs de Plex y reinicia el servidor |
| "Service unavailable" | Servidor sobrecargado | Reduce las peticiones concurrentes |

## Comandos de depuración útiles

### Comprobar el estado del servidor

```bash
curl -s "$PLEX_URL/identity" -H "X-Plex-Token: $PLEX_TOKEN"
# Debería devolver información del servidor, no un error
```

### Verificar que el token funciona

```bash
curl -s "https://plex.tv/api/v2/user" -H "X-Plex-Token: $PLEX_TOKEN"
# Debería devolver información del usuario
```

### Probar el acceso a las bibliotecas

```bash
curl -s "$PLEX_URL/library/sections" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq
# Debería listar todas las bibliotecas
```

### Comprobar las sesiones activas

```bash
curl -s "$PLEX_URL/status/sessions" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq
# Array vacío si no se está reproduciendo nada
```
