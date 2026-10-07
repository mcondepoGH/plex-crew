# cli_debrid

Monitor de cli_debrid: estado del programa, estadísticas del panel, cola, descargas activas, tamaño de la biblioteca y logs, con un comando para forzar tareas del planificador. Envuelve la API web de cli_debrid.

## Cuándo se usa

Para ver qué está haciendo cli_debrid o por qué un título no avanza. La carga el agente `arr-acquisition`; el comportamiento de sus filtros de idioma está en `arr-language-filters`.

## Comandos

Script: `.claude/skills/cli_debrid/scripts/cli_debrid.sh <comando> [args]`. En negrita, los que modifican estado o piden confirmación.

| Comando | Para qué sirve (endpoint) | Argumentos / opciones | Tipo |
|---------|---------------------------|-----------------------|------|
| `status` | Estado del programa, en marcha o parado (`/program_operation/api/program_status`). | Ninguno | Lectura (JSON) |
| `dashboard` | Estadísticas del panel con recuentos por estado (`/statistics/api/index`). | Ninguno | Lectura (JSON) |
| `queue` | Contenido de cada cola (`/queues/api/queue_contents`). | Ninguno | Lectura (JSON) |
| `downloads` | Descargas activas (`/statistics/api/active_downloads`). | Ninguno | Lectura (JSON) |
| `library-size` | Tamaño de la biblioteca (`/statistics/api/library_size`). | Ninguno | Lectura (JSON) |
| `logs` | Últimas líneas de log (`/logs/api/logs?lines=N`). | `[n]` (100 por defecto, numérico) | Lectura (JSON) |
| **`trigger-task`** | Fuerza la ejecución inmediata de una tarea del planificador (POST `/program_operation/trigger_task`). | `<nombre>`, por ejemplo `Scraping` | Escritura |

## Variables de entorno

| Variable | Obligatoria | Uso |
|----------|-------------|-----|
| `CLI_DEBRID_URL` | Sí | URL base del panel (se quita la barra final). |
| `CLI_DEBRID_USER` | Sí | Usuario del panel. |
| `CLI_DEBRID_PASSWORD` | Sí | Contraseña del panel. |
| `HOMELAB_ENV` | No | Ruta alternativa al fichero `.env`. |

## Ejemplos de uso

```bash
# Lectura: estado y cola
bash .claude/skills/cli_debrid/scripts/cli_debrid.sh status
bash .claude/skills/cli_debrid/scripts/cli_debrid.sh queue | jq .

# Lectura: últimas 200 líneas de log
bash .claude/skills/cli_debrid/scripts/cli_debrid.sh logs 200

# ESCRITURA: forzar la tarea Scraping (confirmar antes si no la pidió por nombre)
bash .claude/skills/cli_debrid/scripts/cli_debrid.sh trigger-task Scraping
```

## Notas y límites

- Autentica con POST a `/auth/login`. La cookie vive en `/tmp/.cli_debrid_cookie_<hash de la URL>` (el hash sale de `cksum`), se crea con `umask 077` y permisos 600, y se reutiliza.
- Antes de cada petición se sondea `program_status`; si no responde 200 se vuelve a iniciar sesión. Tras el login se vuelve a sondear: si sigue sin ser 200, el script sale con 1 y borra la cookie.
- Solo exige el fichero `.env` (o `HOMELAB_ENV`) cuando alguna de las tres variables no está ya exportada.
- Las respuestas se imprimen sin transformar; la forma exacta depende de cli_debrid. Una respuesta no 2xx o la falta de conexión salen con 1 y `ERROR:` por stderr.
- Sin comando muestra la ayuda y sale con 0; un comando desconocido, `trigger-task` sin nombre o un `n` no numérico salen con 1.
- `trigger-task` no pide confirmación por sí mismo: debe hacerlo el agente.
