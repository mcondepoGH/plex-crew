# Referencia rápida de cli_debrid

Operaciones habituales para copiar y pegar rápidamente.

## Configuración

```bash
export CLI_DEBRID_URL="http://localhost:5000"
export CLI_DEBRID_USER="admin"
export CLI_DEBRID_PASSWORD="your-password"
```

## Sesión

### Iniciar sesión

```bash
curl -s -c cookies.txt \
  --data-urlencode "username=$CLI_DEBRID_USER" \
  --data-urlencode "password=$CLI_DEBRID_PASSWORD" \
  "$CLI_DEBRID_URL/auth/login"
```

### Comprobar la sesión

```bash
curl -s -b cookies.txt -o /dev/null -w "%{http_code}\n" \
  "$CLI_DEBRID_URL/program_operation/api/program_status"
```

## Monitorización

### Estado del programa

```bash
curl -s -b cookies.txt "$CLI_DEBRID_URL/program_operation/api/program_status"
```

### Estadísticas del dashboard

```bash
curl -s -b cookies.txt "$CLI_DEBRID_URL/statistics/api/index" | jq
```

### Contenido de la cola

```bash
curl -s -b cookies.txt "$CLI_DEBRID_URL/queues/api/queue_contents" | jq
```

### Descargas activas

```bash
curl -s -b cookies.txt "$CLI_DEBRID_URL/statistics/api/active_downloads" | jq
```

### Tamaño de la biblioteca

```bash
curl -s -b cookies.txt "$CLI_DEBRID_URL/statistics/api/library_size" | jq
```

### Últimos logs

```bash
curl -s -b cookies.txt "$CLI_DEBRID_URL/logs/api/logs?lines=200"
```

## Acciones

### Forzar una tarea del planificador

```bash
curl -s -b cookies.txt -X POST \
  --data-urlencode "task_name=Scraping" \
  "$CLI_DEBRID_URL/program_operation/trigger_task"
```

## Script auxiliar

```bash
bash scripts/cli_debrid.sh status
bash scripts/cli_debrid.sh dashboard
bash scripts/cli_debrid.sh queue
bash scripts/cli_debrid.sh downloads
bash scripts/cli_debrid.sh library-size
bash scripts/cli_debrid.sh logs 200
bash scripts/cli_debrid.sh trigger-task Scraping
```
