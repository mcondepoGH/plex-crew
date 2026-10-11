# Referencia rápida de Agregarr

Operaciones habituales para copiar y pegar rápidamente.

## Configuración

```bash
export AGREGARR_URL="http://localhost:7171"
export AGREGARR_API_KEY="your-api-key"
```

## Sistema

### Estado (público)

```bash
curl -s "$AGREGARR_URL/api/v1/status" | jq
```

### Últimos logs de error

```bash
curl -s "$AGREGARR_URL/api/v1/settings/logs?take=20&skip=0&filter=error" \
  -H "X-Api-Key: $AGREGARR_API_KEY" | jq -r '.[] | "\(.timestamp) [\(.level)] \(.label): \(.message)"'
```

### Tareas programadas

```bash
curl -s "$AGREGARR_URL/api/v1/settings/jobs" -H "X-Api-Key: $AGREGARR_API_KEY" | jq
```

## Colecciones

### Listar

```bash
curl -s "$AGREGARR_URL/api/v1/collections" -H "X-Api-Key: $AGREGARR_API_KEY" \
  | jq -r '.collectionConfigs[] | "\(.id) \(.name) \(.type)"'
```

### Estado de la sincronización

```bash
curl -s "$AGREGARR_URL/api/v1/collections/sync/status" -H "X-Api-Key: $AGREGARR_API_KEY" | jq
```

### Sincronizar (escritura)

```bash
curl -s -X POST "$AGREGARR_URL/api/v1/collections/sync" -H "X-Api-Key: $AGREGARR_API_KEY"
curl -s -X POST "$AGREGARR_URL/api/v1/collections/10000/sync" -H "X-Api-Key: $AGREGARR_API_KEY"
```

## Script auxiliar

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" status
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" collections
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" sync-status
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" jobs
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" logs 20 error
bash "${CLAUDE_PLUGIN_ROOT}/skills/agregarr/scripts/agregarr.sh" sync-collection 10000
```
