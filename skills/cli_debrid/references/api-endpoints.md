# Referencia de la API de cli_debrid

**URL base:** `http://localhost:5000`
**Autenticación:** cookie de sesión obtenida con un login de usuario y contraseña (sin clave de API)

Aquí solo se documentan los endpoints que usa `scripts/cli_debrid.sh`. La forma exacta de las respuestas depende de la versión de cli_debrid.

## Autenticación

#### POST /auth/login

Inicia sesión y guarda la cookie de sesión. El código de estado de esta llamada no es fiable: el script verifica la sesión llamando después a `program_status`.

**Campos del formulario:** `username`, `password`

**Ejemplo de petición:**
```bash
curl -s -c cookies.txt \
  --data-urlencode "username=$CLI_DEBRID_USER" \
  --data-urlencode "password=$CLI_DEBRID_PASSWORD" \
  "$CLI_DEBRID_URL/auth/login"
```

## Inicio rápido

```bash
# Define las variables de entorno
export CLI_DEBRID_URL="http://localhost:5000"
export CLI_DEBRID_USER="admin"
export CLI_DEBRID_PASSWORD="your-password"

# Inicia sesión y prueba la conexión
curl -s -c cookies.txt --data-urlencode "username=$CLI_DEBRID_USER" --data-urlencode "password=$CLI_DEBRID_PASSWORD" "$CLI_DEBRID_URL/auth/login"
curl -s -b cookies.txt "$CLI_DEBRID_URL/program_operation/api/program_status"
```

## Endpoints por categoría

### Programa

#### GET /program_operation/api/program_status

Estado del programa, en ejecución o detenido. Lo usa el comando `status` y sirve como sondeo de la sesión.

**Códigos de respuesta:**
- `200`: Sesión autenticada
- Cualquier otro código: la sesión no existe o ha caducado

---

#### POST /program_operation/trigger_task

Fuerza una tarea del planificador de inmediato. Lo usa `trigger-task`.

**Campos del formulario:** `task_name` (por ejemplo `Scraping`)

**Ejemplo de petición:**
```bash
curl -s -b cookies.txt -X POST \
  --data-urlencode "task_name=Scraping" \
  "$CLI_DEBRID_URL/program_operation/trigger_task"
```

---

### Estadísticas

#### GET /statistics/api/index

Estadísticas del dashboard con los recuentos por estado. Lo usa `dashboard`.

#### GET /statistics/api/active_downloads

Descargas activas. Lo usa `downloads`.

#### GET /statistics/api/library_size

Tamaño de la biblioteca. Lo usa `library-size`.

---

### Colas

#### GET /queues/api/queue_contents

Contenido de cada cola. Lo usa `queue`.

---

### Logs

#### GET /logs/api/logs

Últimas líneas del log. Lo usa `logs`.

**Parámetros de consulta:**
- `lines`: número de líneas (el script usa `100` por defecto)

**Ejemplo de petición:**
```bash
curl -s -b cookies.txt "$CLI_DEBRID_URL/logs/api/logs?lines=200"
```
