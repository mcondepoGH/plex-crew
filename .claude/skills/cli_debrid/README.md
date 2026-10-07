# cli_debrid

Monitor de cli_debrid: estado del programa, estadísticas del panel, cola, descargas activas, tamaño de la biblioteca y logs, con un comando para forzar tareas del planificador. Envuelve la API web de cli_debrid.

## Cuándo se usa

Para ver qué está haciendo cli_debrid o por qué un título no avanza. La carga el agente `arr-acquisition`; el comportamiento de sus filtros de idioma está en `arr-language-filters`.

## Comandos

Script: `.claude/skills/cli_debrid/scripts/cli_debrid.sh <comando> [args]`. En negrita, los que modifican estado o piden confirmación.

| Comando | Para qué sirve (endpoint) | Argumentos | Tipo |
|---------|---------------------------|------------|------|
| `status` | Estado del programa, en marcha o parado (`/program_operation/api/program_status`). | Ninguno | Lectura |
| `dashboard` | Estadísticas del panel con recuentos por estado (`/statistics/api/index`). | Ninguno | Lectura |
| `queue` | Contenido de cada cola (`/queues/api/queue_contents`). | Ninguno | Lectura |
| `downloads` | Descargas activas (`/statistics/api/active_downloads`). | Ninguno | Lectura |
| `library-size` | Tamaño de la biblioteca (`/statistics/api/library_size`). | Ninguno | Lectura |
| `logs` | Últimas N líneas de log (`/logs/api/logs?lines=N`). | `[n]` (100 por defecto) | Lectura |
| **`trigger-task`** | Fuerza la ejecución inmediata de una tarea del planificador, por ejemplo `Scraping` (POST `/program_operation/trigger_task`). | `<nombre>` (obligatorio) | Escritura |

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

- No usa clave de API: autentica con usuario y contraseña mediante una sesión por cookie (el mismo login que la interfaz web), con POST a `/auth/login`.
- La cookie se guarda en `/tmp/.cli_debrid_cookie_<hash de la URL>` y se reutiliza. Antes de cada petición se sondea `program_status`; si no responde 200, se vuelve a iniciar sesión. El script no comprueba si el login tuvo éxito.
- A diferencia de las demás skills, lee siempre el fichero de entorno (`load_env_file`, y por tanto exige que exista `.env` o `HOMELAB_ENV`) en lugar de aceptar solo variables ya exportadas.
- Las respuestas se imprimen tal cual, sin `jq`; la forma exacta depende de cli_debrid.
- Sin argumentos o con un comando desconocido imprime el uso y sale con código 1; `trigger-task` sin nombre falla con el mensaje de uso.
- `trigger-task` ejecuta la tarea de inmediato y no pide confirmación: debe hacerlo el agente.
