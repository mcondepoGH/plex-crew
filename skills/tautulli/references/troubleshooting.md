# Resolución de problemas de Tautulli

Problemas habituales y soluciones al usar la skill de Tautulli.

## Errores de autenticación

### Error: "Invalid API key"

**Síntomas:**
```json
{
  "response": {
    "result": "error",
    "message": "Invalid apikey",
    "data": null
  }
}
```

**Causas:**
- La clave de API es incorrecta
- La clave de API tiene espacios o caracteres especiales
- La API no está activada en Tautulli

**Soluciones:**

1. **Verifica que la API está activada:**
   ```
   - Abre la interfaz web de Tautulli
   - Ve a Settings → Web Interface
   - Desplázate hasta la sección "API"
   - Asegúrate de que "API enabled" está marcado
   - Guarda los ajustes
   ```

2. **Obtén la clave de API correcta:**
   ```
   - En la misma sección API, copia la API Key
   - Debe ser una cadena alfanumérica larga (32 o más caracteres)
   ```

3. **Actualiza el fichero .env:**
   ```bash
   # Editar ~/.claude/plex-crew/.env
   TAUTULLI_API_KEY="correct-key-here"

   # SIN comillas alrededor del valor si contiene caracteres especiales
   # SIN espacios antes ni después del =
   ```

4. **Prueba la clave:**
   ```bash
   # Prueba directa de la API
   curl "${TAUTULLI_URL}/api/v2?apikey=${TAUTULLI_API_KEY}&cmd=get_server_info"

   # Debe devolver un JSON de éxito
   ```

### Error: "ERROR: TAUTULLI_API_KEY must be set in .env"

**Causa:** la variable de entorno no está cargada o falta el fichero .env.

**Soluciones:**

1. **Comprueba que existe el fichero .env:**
   ```bash
   ls -la ~/.claude/plex-crew/.env
   ```

2. **Comprueba que la variable está definida:**
   ```bash
   cat ~/.claude/plex-crew/.env | grep TAUTULLI
   ```

3. **Verifica el formato:**
   ```bash
   # Formato correcto en .env
   TAUTULLI_URL="http://192.168.1.100:8181"
   TAUTULLI_API_KEY="<your_api_key>"

   # SIN espacios alrededor del =
   # Los valores pueden llevar comillas o no
   ```

4. **Carga el fichero manualmente con source:**
   ```bash
   source ~/.claude/plex-crew/.env
   echo $TAUTULLI_API_KEY  # Debe mostrar tu clave
   ```

## Errores de conexión

### Error: "Connection refused" o tiempo de espera agotado

**Síntomas:**
```
curl: (7) Failed to connect to 192.168.1.100 port 8181: Connection refused
```

**Causas:**
- Tautulli no está en ejecución
- URL o puerto incorrectos
- Un firewall bloquea la conexión
- Problemas de red

**Soluciones:**

1. **Comprueba que Tautulli está en ejecución:**
   ```bash
   # Si usas Docker
   docker ps | grep tautulli

   # Comprobar si el puerto está escuchando
   nc -zv 192.168.1.100 8181
   ```

2. **Verifica la URL y el puerto:**
   ```bash
   # Probar el acceso a la interfaz web
   curl -I http://192.168.1.100:8181

   # Debe devolver 200 OK o una redirección 302
   ```

3. **Revisa el firewall:**
   ```bash
   # En el host de Tautulli
   sudo ufw status
   sudo firewall-cmd --list-ports

   # Asegúrate de que 8181/tcp está permitido
   ```

4. **Prueba desde la misma red:**
   ```bash
   # Asegúrate de que puedes acceder a Tautulli desde tu equipo
   ping 192.168.1.100
   curl http://192.168.1.100:8181
   ```

5. **Revisa los logs de Tautulli:**
   ```bash
   # Docker
   docker logs tautulli

   # Instalación manual
   tail -f /path/to/tautulli/logs/tautulli.log
   ```

### Error: "SSL certificate verify failed"

**Causa:** se usa HTTPS con un certificado autofirmado.

**Soluciones:**

1. **Usa HTTP en su lugar:**
   ```bash
   # En ~/.claude/plex-crew/.env
   TAUTULLI_URL="http://192.168.1.100:8181"  # Not https://
   ```

2. **O desactiva la verificación SSL (no recomendado):**
   ```bash
   # Editar tautulli-api.sh
   # Añadir la opción -k al comando curl
   curl -k -sS -X GET "..."
   ```

## Problemas de datos

### Error: datos vacíos o ausentes

**Síntomas:**
```json
{
  "response": {
    "result": "success",
    "data": []
  }
}
```

**Causas:**
- Aún no se han recopilado datos históricos
- Filtros demasiado restrictivos
- Biblioteca sin escanear
- Sin actividad reciente

**Soluciones:**

1. **Espera a que se recopilen datos:**
   ```
   - Tautulli recopila datos cada pocos minutos
   - Revisa Settings → Monitoring → Refresh intervals
   - Espera al menos 10-15 minutos tras la instalación
   ```

2. **Verifica la conexión con Plex:**
   ```bash
   # Comprobar la información del servidor
   ./scripts/tautulli-api.sh server-info

   # Debe mostrar pms_name y pms_version
   ```

3. **Revisa los ajustes de Tautulli:**
   ```
   - Settings → Plex Media Server → Connection
   - Asegúrate de que el servidor Plex está conectado
   - Prueba la conexión
   ```

4. **Quita los filtros y vuelve a intentarlo:**
   ```bash
   # En lugar de:
   ./scripts/tautulli-api.sh history --user "john" --days 1

   # Prueba:
   ./scripts/tautulli-api.sh history --limit 100
   ```

5. **Revisa la retención del historial:**
   ```
   - Settings → General Settings → History Retention
   - Asegúrate de que no elimina datos de forma demasiado agresiva
   ```

### Error: "No section_id provided"

**Causa:** el comando requiere el ID de la sección de biblioteca y no se ha indicado ninguno.

**Soluciones:**

1. **Lista primero las secciones disponibles:**
   ```bash
   ./scripts/tautulli-api.sh libraries
   ```

2. **Usa el section_id correcto:**
   ```bash
   # Obtén los IDs de sección de la salida anterior (normalmente 1, 2, 3...)
   ./scripts/tautulli-api.sh library-stats --section-id 1
   ```

3. **Los IDs de sección coinciden con los de Plex:**
   ```
   - Los IDs de sección son los mismos que las claves de biblioteca de Plex
   - Normalmente: 1=Movies, 2=TV, 3=Music
   - Pero verifícalo con el comando libraries
   ```

## Errores del script

### Error: "command not found: jq"

**Causa:** el procesador JSON jq no está instalado.

**Soluciones:**

```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# Probar
jq --version
```

### Error: "line 2: $'\\r': command not found"

**Causa:** finales de línea de Windows (CRLF) en el script.

**Soluciones:**

```bash
# Convertir los finales de línea
dos2unix skills/tautulli/scripts/tautulli-api.sh

# O usar sed
sed -i 's/\r$//' skills/tautulli/scripts/tautulli-api.sh

# Asegurar que es ejecutable
chmod +x skills/tautulli/scripts/tautulli-api.sh
```

### Error: Permission denied

**Causa:** el script no es ejecutable.

**Soluciones:**

```bash
# Hacer ejecutable
chmod +x skills/tautulli/scripts/tautulli-api.sh

# Verificar
ls -l skills/tautulli/scripts/tautulli-api.sh
# Debe mostrar: -rwxr-xr-x
```

## Problemas de rendimiento

### Consultas lentas o tiempos de espera agotados

**Causas:**
- Base de datos grande con años de datos
- Filtros complejos
- Rangos de tiempo largos
- Sin índices en la base de datos

**Soluciones:**

1. **Usa rangos de tiempo más cortos:**
   ```bash
   # En lugar de todo el histórico:
   ./scripts/tautulli-api.sh history --limit 1000

   # Usa datos recientes:
   ./scripts/tautulli-api.sh history --days 30 --limit 100
   ```

2. **Limita el tamaño del resultado:**
   ```bash
   # Usa límites razonables
   ./scripts/tautulli-api.sh history --limit 50  # No 10000
   ```

3. **Usa filtros específicos:**
   ```bash
   # Acotar la búsqueda
   ./scripts/tautulli-api.sh history --user "john" --section-id 1 --days 7
   ```

4. **Revisa el tamaño de la base de datos:**
   ```bash
   # Si la base de datos es enorme (>1GB), considera:
   # - Reducir la retención del historial
   # - Ejecutar el mantenimiento de la base de datos
   # Settings → Maintenance → Database
   ```

5. **Optimiza la base de datos:**
   ```
   - Settings → Maintenance
   - Ejecuta "Vacuum database"
   - Ejecuta "Check database integrity"
   ```

### Límite de peticiones de la API

**Síntomas:** las peticiones empiezan a fallar tras muchas llamadas rápidas.

**Soluciones:**

1. **Añade pausas entre peticiones:**
   ```bash
   #!/bin/bash
   for user in alice bob charlie; do
       ./scripts/tautulli-api.sh user-stats --user "$user"
       sleep 1  # Esperar 1 segundo entre llamadas
   done
   ```

2. **Agrupa las operaciones:**
   ```bash
   # En lugar de varias llamadas, usa filtros
   ./scripts/tautulli-api.sh history --limit 500
   ```

3. **Almacena los resultados en caché:**
   ```bash
   # Guardar los datos de uso frecuente
   ./scripts/tautulli-api.sh libraries > /tmp/tautulli_libs.json

   # Reutilizar los datos en caché
   cat /tmp/tautulli_libs.json | jq '.response.data'
   ```

## Problemas de integración

### Los datos no coinciden con Plex

**Causas:**
- Tautulli aún no se ha sincronizado
- Se ha perdido la conexión con el servidor Plex
- El historial no se está registrando

**Soluciones:**

1. **Comprueba la conexión con Plex:**
   ```bash
   ./scripts/tautulli-api.sh server-info
   # Verifica que pms_name y pms_version son correctos
   ```

2. **Fuerza la sincronización:**
   ```
   - Settings → Plex Media Server
   - Pulsa "Refresh Libraries"
   ```

3. **Revisa la monitorización:**
   ```
   - Settings → Monitoring
   - Asegúrate de que "Monitor Plex Media Server" está activado
   - Revisa los intervalos de actualización
   ```

4. **Revisa el registro de actividad:**
   ```
   - Tautulli UI → Activity
   - Comprueba si aparecen las sesiones actuales
   ```

### IDs de sección de biblioteca incorrectos

**Síntomas:** los comandos funcionan con section_id 1 pero no con 2 o 3.

**Soluciones:**

1. **Lista todas las secciones:**
   ```bash
   ./scripts/tautulli-api.sh libraries | jq '.response.data[] | {id: .section_id, name: .section_name, type: .section_type}'
   ```

2. **Usa los IDs correctos:**
   ```
   - Los IDs los asigna Plex, no Tautulli
   - Pueden no ser secuenciales (1, 3, 5...)
   - Pueden cambiar si se elimina y se vuelve a crear la biblioteca
   ```

3. **Verifica en Plex:**
   ```
   - Abre la interfaz web de Plex
   - Fíjate en las URL de las bibliotecas
   - Ejemplo: /library/sections/2 → section_id es 2
   ```

## Errores comunes

### 1. Formato de marca de tiempo incorrecto

**Problema:** se usan fechas legibles en lugar de marcas de tiempo Unix.

**Incorrecto:**
```bash
# Esto no funcionará
./scripts/tautulli-api.sh history --start-date "2024-01-01"
```

**Correcto:**
```bash
# Usar el parámetro --days
./scripts/tautulli-api.sh history --days 30

# O convertir a marca de tiempo Unix
START=$(date -d "2024-01-01" +%s)
curl "${TAUTULLI_URL}/api/v2?apikey=${TAUTULLI_API_KEY}&cmd=get_history&start_date=${START}"
```

### 2. No comprobar el campo result

**Problema:** se procesan los datos sin comprobar si la petición ha tenido éxito.

**Incorrecto:**
```bash
# Podría fallar en silencio
./scripts/tautulli-api.sh activity | jq '.response.data.sessions'
```

**Correcto:**
```bash
# Comprobar primero result
RESULT=$(./scripts/tautulli-api.sh activity)
if echo "$RESULT" | jq -e '.response.result == "success"' > /dev/null; then
    echo "$RESULT" | jq '.response.data.sessions'
else
    echo "Error: $(echo "$RESULT" | jq -r '.response.message')"
fi
```

### 3. Malentendidos con la paginación

**Problema:** solo se ven los 25 primeros resultados y se piensa que son todos.

**Solución:**
```bash
# Comprobar el total de registros
TOTAL=$(./scripts/tautulli-api.sh history | jq '.response.data.recordsTotal')
echo "Total records: $TOTAL"

# Usar un límite adecuado
./scripts/tautulli-api.sh history --limit 100

# O paginar
for offset in 0 100 200 300; do
    # Usar una llamada directa a la API con el parámetro start
    curl "${TAUTULLI_URL}/api/v2?apikey=${TAUTULLI_API_KEY}&cmd=get_history&start=${offset}&length=100"
done
```

### 4. Caracteres especiales en las búsquedas

**Problema:** la búsqueda falla con espacios o caracteres especiales.

**Incorrecto:**
```bash
# Los espacios rompen la consulta
./scripts/tautulli-api.sh history --search "Star Wars"
```

**Correcto:**
```bash
# Usar comillas
./scripts/tautulli-api.sh history --search "Star Wars"

# En las llamadas directas a la API, codificar en la URL
QUERY=$(echo "Star Wars" | jq -sRr @uri)
curl "${TAUTULLI_URL}/api/v2?apikey=${TAUTULLI_API_KEY}&cmd=get_history&search=${QUERY}"
```

## Obtener ayuda

### Revisar los logs de Tautulli

```bash
# Docker
docker logs tautulli --tail 100

# Instalación manual
tail -100 /path/to/tautulli/logs/tautulli.log

# Buscar errores o advertencias
grep -i error /path/to/tautulli/logs/tautulli.log
```

### Activar el modo de depuración

```bash
# Añadir el parámetro debug a las llamadas a la API
curl "${TAUTULLI_URL}/api/v2?apikey=${TAUTULLI_API_KEY}&cmd=get_activity&debug=1"

# O en los ajustes de Tautulli
# Settings → Notification Agents → Script → Debug Logging
```

### Probar con curl

```bash
# Saltarse el script auxiliar y probar directamente
curl -v "${TAUTULLI_URL}/api/v2?apikey=${TAUTULLI_API_KEY}&cmd=get_server_info"

# La opción -v muestra la transacción HTTP completa
```

### Verificar el entorno

```bash
# Comprobar todas las variables
env | grep TAUTULLI

# Salida esperada:
TAUTULLI_URL=http://192.168.1.100:8181
TAUTULLI_API_KEY=<your_api_key>
```

## Recursos

- [Incidencias de Tautulli en GitHub](https://github.com/Tautulli/Tautulli/issues)
- [Discord de Tautulli](https://tautulli.com/discord)
- [Reddit de Tautulli](https://www.reddit.com/r/Tautulli/)
- [Documentación de la API](https://github.com/Tautulli/Tautulli/wiki/Tautulli-API-Reference)
- [Foros de Plex](https://forums.plex.tv/)

## ¿Sigues teniendo problemas?

Si ninguna de estas soluciones funciona:

1. **Verifica la versión de Tautulli:**
   ```bash
   ./scripts/tautulli-api.sh server-info | jq '.response.data.tautulli_version'
   ```

2. **Comprueba la conexión con Plex:**
   ```bash
   ./scripts/tautulli-api.sh server-info | jq '.response.data | {pms_name, pms_version, pms_ip}'
   ```

3. **Prueba con un comando mínimo:**
   ```bash
   curl "${TAUTULLI_URL}/api/v2?apikey=${TAUTULLI_API_KEY}&cmd=get_server_info" | jq '.'
   ```

4. **Revisa esta lista de comprobación:**
   - [ ] Tautulli está en ejecución
   - [ ] La API está activada en los ajustes
   - [ ] La clave de API es correcta
   - [ ] La URL y el puerto son correctos
   - [ ] Se puede acceder a la interfaz web de Tautulli
   - [ ] El servidor Plex está conectado
   - [ ] Existen algunos datos históricos
   - [ ] El fichero .env tiene las variables correctas
   - [ ] El script es ejecutable

5. **Recopila información de depuración:**
   ```bash
   echo "Tautulli URL: $TAUTULLI_URL"
   echo "API Key length: ${#TAUTULLI_API_KEY}"
   echo "Server info:"
   ./scripts/tautulli-api.sh server-info
   ```

6. **Consulta los recursos de la comunidad de Tautulli** por si hay problemas similares.
