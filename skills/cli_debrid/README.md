# Skill de cli_debrid

Monitoriza cli_debrid: estado del programa, estadísticas del dashboard, cola, descargas activas, tamaño de la biblioteca y logs, con un comando para forzar tareas del planificador.

## Qué hace

- **Estado** — Ve si el programa está en ejecución o detenido
- **Panel** — Lee las estadísticas del panel con los recuentos por estado
- **Cola** — Lee el contenido de cada cola
- **Descargas** — Lista las descargas activas
- **Tamaño de la biblioteca** — Lee el tamaño de la biblioteca
- **Logs** — Lee las últimas líneas del log
- **Forzar tarea** — Fuerza una tarea del planificador de inmediato

Todas las operaciones usan la API web de cli_debrid con una cookie de sesión (sin clave de API).

## Configuración

### 1. Obtén las credenciales del panel

Usa el mismo usuario y contraseña con los que inicias sesión en la interfaz web de cli_debrid.

### 2. Configura las variables de entorno

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
CLI_DEBRID_URL="http://localhost:5000"
CLI_DEBRID_USER="admin"
CLI_DEBRID_PASSWORD="<your_panel_password>"
```

**Opciones de configuración:**
- `CLI_DEBRID_URL`: URL del panel de cli_debrid (se elimina la barra final)
- `CLI_DEBRID_USER`: usuario del panel
- `CLI_DEBRID_PASSWORD`: contraseña del panel
- `HOMELAB_ENV`: ruta opcional a otro fichero de entorno

### 3. Pruébalo

```bash
bash scripts/cli_debrid.sh status
```

## Ejemplos de uso

### Consultar el estado

```bash
bash scripts/cli_debrid.sh status
bash scripts/cli_debrid.sh dashboard
bash scripts/cli_debrid.sh library-size
```

### Cola y descargas

```bash
bash scripts/cli_debrid.sh queue | jq .
bash scripts/cli_debrid.sh downloads
```

### Leer los logs

```bash
bash scripts/cli_debrid.sh logs 200
```

### Forzar una tarea

```bash
bash scripts/cli_debrid.sh trigger-task Scraping
```

**¡Confirma siempre con el usuario antes de forzar una tarea, salvo que la haya pedido por su nombre!**

## Referencia de la API

La documentación detallada de la API está en el directorio `references/`:

- **[Endpoints de la API](./references/api-endpoints.md)** - Referencia completa de endpoints
- **[Referencia rápida](./references/quick-reference.md)** - Operaciones habituales con ejemplos listos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Soluciones para autenticación, conexión y errores habituales

## Flujo de trabajo

Cuando un usuario pregunte por qué un título no avanza:

1. **Estado**: `bash scripts/cli_debrid.sh status` para confirmar que el programa está en ejecución
2. **Cola**: `bash scripts/cli_debrid.sh queue` para localizar el título
3. **Logs**: `bash scripts/cli_debrid.sh logs 200` para buscar errores
4. **Filtro de idioma**: si el título nunca aparece, revisa `arr-language-filters`
5. **Forzar**: con la confirmación del usuario, `trigger-task <name>`

## Resolución de problemas

**"faltan variables en el .env"**
→ Comprueba que tus credenciales existen en `~/.claude/plex-crew/.env` con las variables `CLI_DEBRID_URL`, `CLI_DEBRID_USER` y `CLI_DEBRID_PASSWORD`

**"el login en cli_debrid ha fallado"**
→ El usuario o la contraseña son incorrectos; compruébalos en la interfaz web

**"no se pudo conectar con cli_debrid"**
→ Verifica que la URL del panel es correcta y que cli_debrid está en ejecución

**Respuesta no 2xx**
→ El script imprime `ERROR: <METHOD> <path> respondió HTTP <code>` y termina con 1

## Notas

- Se autentica con POST a `/auth/login`; la cookie vive en `/tmp/.cli_debrid_cookie_<hash of the URL>`, creada con `umask 077` y permisos 600
- Antes de cada petición se sondea `program_status`; si no responde 200, el script vuelve a iniciar sesión
- El fichero de entorno solo es necesario cuando alguna de las tres variables no está ya exportada
- Las respuestas se imprimen sin transformar; su forma exacta depende de cli_debrid
- `trigger-task` no pide confirmación por sí mismo: debe pedirla el agente
- Requiere `curl` instalado

## Licencia

MIT
