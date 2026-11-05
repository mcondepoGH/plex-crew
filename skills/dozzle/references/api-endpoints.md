# Endpoints de la API de Dozzle

Solo se documenta lo que usa el script. Comprobado en vivo contra Dozzle v11.4.0; otras versiones pueden cambiar las rutas (ver `troubleshooting.md`). Documentación oficial: https://dozzle.dev/

## Base y autenticación

- URL base: `${DOZZLE_URL}` (sin barra final)
- Sin clave de API ni cabeceras de autenticación
- Todas las llamadas llevan `--connect-timeout 10` y `--max-time` (4 s para la lista de contenedores; `DOZZLE_MAX_TIME`, 30 s, para los logs)

## Comandos y peticiones

| Comando | Método y ruta | Notas |
|---------|---------------|-------|
| `status`, `containers` | `GET /api/events/stream` | Stream SSE; se lee hasta el primer evento `containers-changed` y se corta |
| `logs <contenedor> [opciones]` | `POST /api/containers/logs?container=<host>/<id>[&stdout=1][&stderr=1][&from=<fecha UTC>]` | Solo lectura; respuesta `text/plain`, una línea de log por línea |

## Stream de eventos

`GET /api/events/stream` emite eventos SSE (`event: <nombre>` y `data: <json>`):

| Evento | Contenido |
|--------|-----------|
| `server-version` | `{"version":"v11.4.0"}` |
| `containers-changed` | Array con todos los contenedores; la primera aparición es la lista completa |

Campos de cada contenedor usados: `id` (corto), `name`, `state`, `health` (puede faltar), `host` (id del host Docker). El objeto trae más campos (`image`, `labels`, `stats`...) que el script ignora.

## Logs

`POST /api/containers/logs` (sin cuerpo; todo va en la consulta):

| Parámetro | Valor |
|-----------|-------|
| `container` | `<host>/<id>`, obligatorio (se obtiene de la lista de contenedores) |
| `stdout`, `stderr` | `1` para incluir el flujo; hace falta al menos uno |
| `from` | Opcional, fecha UTC `AAAA-MM-DDTHH:MM:SSZ`: solo desde ese momento (el script lo expone como `--since`) |

La respuesta es el log completo (o desde `from`) en texto plano, sin marca de hora añadida por Dozzle. El script recorta a las últimas N líneas, filtra con `--grep` y oculta secretos en el cliente.

## Errores

| HTTP | Texto | Causa |
|------|-------|-------|
| 400 | `stdout or stderr is required` | Falta `stdout=1` y `stderr=1` |
| 400 | `at least one container is required` / `container must be <host>/<id>` | Parámetro `container` ausente o mal formado |
| 404 | `host <x> not found`, `rpc error: code = NotFound desc = container not found` | Host o contenedor inexistente |
| 405 | (vacío) | Se usó `GET` en lugar de `POST` en `/api/containers/logs` |
