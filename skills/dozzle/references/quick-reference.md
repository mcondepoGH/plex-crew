# Referencia rápida de Dozzle

## Configuración

```bash
# ~/.claude/plex-crew/.env
DOZZLE_URL="http://host:8080"
```

```bash
DZ="${CLAUDE_PLUGIN_ROOT}/skills/dozzle/scripts/dozzle.sh"
```

## Comandos del script

```bash
bash "$DZ" help
bash "$DZ" status
bash "$DZ" containers
bash "$DZ" logs radarr
bash "$DZ" logs radarr --lines 50 --grep error
bash "$DZ" logs sonarr --stderr
bash "$DZ" logs plex --stdout --since 2026-11-05T08:00:00Z
```

## Salidas habituales

| Comando | Salida |
|---------|--------|
| `status`, `containers` | `Dozzle v11.4.0 - 30 contenedores, 30 en ejecución` y, por contenedor, `radarr  running  -  39a3ed741826` |
| `logs` | Las líneas del log tal cual; secretos como `apikey=***` |

Códigos de salida: 0 correcto; 1 error de uso, contenedor no encontrado, HTTP no 2xx o fallo de conexión.

## Ajustes

| Variable | Efecto |
|----------|--------|
| `DOZZLE_MAX_TIME` | Segundos máximos de la petición de logs (30 por defecto) |
| `DOZZLE_EVENTS_TIME` | Segundos máximos de lectura de la lista de contenedores (4 por defecto) |
