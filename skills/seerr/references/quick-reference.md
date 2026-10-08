# Referencia rápida de Seerr

Operaciones habituales para copiar y pegar rápidamente.

## Configuración

```bash
export SEERR_URL="http://localhost:5055"
export SEERR_API_KEY="your-api-key"
```

## Información del sistema

### Obtener el estado

```bash
curl -s "$SEERR_URL/api/v1/status" \
  -H "X-Api-Key: $SEERR_API_KEY" | jq
```

### Obtener los últimos logs de error

```bash
curl -s "$SEERR_URL/api/v1/settings/logs?take=20&skip=0&filter=error" \
  -H "X-Api-Key: $SEERR_API_KEY" | jq -r '.results[] | "\(.timestamp) [\(.level)] \(.label // ""): \(.message)"'
```

## Búsqueda

### Buscar un título

```bash
curl -s "$SEERR_URL/api/v1/search?query=Dune" \
  -H "X-Api-Key: $SEERR_API_KEY" | jq '.results[] | {mediaType, id, title, name}'
```

## Solicitudes

### Listar las solicitudes pendientes

```bash
curl -s "$SEERR_URL/api/v1/request?filter=pending&take=50" \
  -H "X-Api-Key: $SEERR_API_KEY" | jq '.results[] | {id, status, media: .media.tmdbId}'
```

### Solicitar una película

```bash
curl -s -X POST "$SEERR_URL/api/v1/request" \
  -H "X-Api-Key: $SEERR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"mediaType":"movie","mediaId":438631}' | jq
```

### Solicitar una serie

```bash
curl -s -X POST "$SEERR_URL/api/v1/request" \
  -H "X-Api-Key: $SEERR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"mediaType":"tv","mediaId":1396,"seasons":[1,2]}' | jq
```

## Script auxiliar

```bash
bash scripts/seerr.sh status
bash scripts/seerr.sh search "Dune"
bash scripts/seerr.sh requests pending
bash scripts/seerr.sh logs 20 error
bash scripts/seerr.sh request-movie 438631
bash scripts/seerr.sh request-tv 1396 1,2
```
