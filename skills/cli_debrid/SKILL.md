---
name: cli_debrid
description: Esta skill debe usarse cuando se monitorice cli_debrid (godver3/cli_debrid). Úsala cuando el usuario pida "estado de cli_debrid", "estado del programa", "cola de cli_debrid", "descargas activas", "logs de cli_debrid", "tamaño de la biblioteca", "forzar una tarea de cli_debrid", o mencione la monitorización de cli_debrid.
---

# Skill de monitorización de cli_debrid

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "estado de cli_debrid", "estado del programa", "cola de cli_debrid", "descargas activas"
- "logs de cli_debrid", "tamaño de la biblioteca de cli_debrid", "estadísticas del dashboard"
- "forzar una tarea", "lanzar Scraping", "por qué este título no avanza en cli_debrid"
- Cualquier mención de cli_debrid o de su monitorización

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Consulta el estado, la cola, las descargas, los logs y las estadísticas de cli_debrid, y fuerza tareas del planificador.

## Propósito

Esta skill permite monitorizar cli_debrid:
- Ver si el programa está en ejecución o detenido
- Leer las estadísticas del dashboard, la cola y las descargas activas
- Leer el tamaño de la biblioteca y los últimos logs
- Forzar una tarea del planificador de inmediato

Las operaciones incluyen acciones de lectura y de escritura. **Confirma siempre con el usuario antes de forzar una tarea**, salvo que la haya pedido por su nombre.

## Configuración

Añade las credenciales a `~/.claude/plex-crew/.env`. cli_debrid **no usa clave de API**: se autentica con usuario y contraseña mediante una cookie de sesión, el mismo login que su interfaz web.

```bash
CLI_DEBRID_URL="http://localhost:5000"
CLI_DEBRID_USER="admin"
CLI_DEBRID_PASSWORD="your-panel-password"
```

- `CLI_DEBRID_URL`: URL del panel de cli_debrid (sin barra final)
- `CLI_DEBRID_USER` y `CLI_DEBRID_PASSWORD`: credenciales del panel

## Ejecución del script

El script está en `${CLAUDE_PLUGIN_ROOT}/skills/cli_debrid/scripts/cli_debrid.sh`. Llámalo con su ruta absoluta para no alterar el directorio de trabajo de la sesión.

## Comandos

Todos los comandos imprimen la respuesta de cli_debrid tal cual (JSON); su forma exacta depende de cli_debrid. Sin comando muestra la ayuda (código de salida 0); un comando desconocido la muestra y termina con 1. Un argumento obligatorio ausente o un `n` no numérico imprime el uso y termina con 1. Un fallo de login, una respuesta HTTP no 2xx o un fallo de conexión imprime `ERROR:` en stderr y termina con 1.

### Consultar el estado

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/cli_debrid/scripts/cli_debrid.sh" status
bash "${CLAUDE_PLUGIN_ROOT}/skills/cli_debrid/scripts/cli_debrid.sh" dashboard
bash "${CLAUDE_PLUGIN_ROOT}/skills/cli_debrid/scripts/cli_debrid.sh" library-size
```

**Salida:** `status` indica si el programa está en ejecución o detenido. `dashboard` devuelve las estadísticas del panel con los recuentos por estado. `library-size` devuelve el tamaño de la biblioteca.

### Cola, descargas y logs

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/cli_debrid/scripts/cli_debrid.sh" queue
bash "${CLAUDE_PLUGIN_ROOT}/skills/cli_debrid/scripts/cli_debrid.sh" downloads
bash "${CLAUDE_PLUGIN_ROOT}/skills/cli_debrid/scripts/cli_debrid.sh" logs 200
```

**Salida:** `queue` devuelve el contenido de cada cola, `downloads` las descargas activas y `logs [n]` las últimas `n` líneas (por defecto: 100).

### Forzar una tarea

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/cli_debrid/scripts/cli_debrid.sh" trigger-task Scraping
```

**Confirma con el usuario antes de forzar la tarea.** Ejecuta de inmediato una tarea del planificador por su nombre y no pide confirmación por sí mismo. **Salida:** la respuesta de cli_debrid.

## Flujo de trabajo

Cuando el usuario pregunte por cli_debrid:

1. **"¿Está cli_debrid en ejecución?"** → Ejecuta `status`
2. **"¿Qué hay en la cola?"** → Ejecuta `queue`; para el detalle por estado, `dashboard`
3. **"¿Por qué este título no avanza?"** → Revisa `queue` y `logs`; si el título no aparece, revisa `arr-language-filters` (filtro de idioma)
4. **"Fuerza Scraping"** → Confirma y ejecuta `trigger-task Scraping`

## Parámetros

### Comando logs
- `[n]`: número de líneas (por defecto: 100; debe ser numérico)

### Comando trigger-task
- `<name>`: nombre de la tarea del planificador, por ejemplo `Scraping` (obligatorio)

## Notas

- La cookie de sesión se guarda en `/tmp` con permisos 600 y se reutiliza mientras sea válida; si caduca, el script vuelve a iniciar sesión por sí mismo
- Si el login falla, el script lo indica y termina con 1 en lugar de continuar con una sesión no válida
- Si el panel no responde (curl 7), considera la skill inaccesible e infórmalo
- Requiere `curl` instalado

## Referencia

- [cli_debrid en GitHub](https://github.com/godver3/cli_debrid)

Para la referencia local detallada, consulta:
- **[Endpoints de la API](./references/api-endpoints.md)** - Referencia completa de endpoints con parámetros
- **[Referencia rápida](./references/quick-reference.md)** - Operaciones habituales con ejemplos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Soluciones para autenticación, conexión y errores
