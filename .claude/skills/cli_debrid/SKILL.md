---
name: cli_debrid
description: Monitor de cli_debrid (godver3/cli_debrid). Úsala cuando el usuario pida "estado de cli_debrid", "estado del programa", "cola de cli_debrid", "descargas activas", "logs de cli_debrid", "tamaño de la biblioteca", "forzar una tarea de cli_debrid", o mencione la monitorización de cli_debrid.
---

# Skill de monitorización de cli_debrid

**INVOCACIÓN OBLIGATORIA DE LA SKILL**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "estado de cli_debrid", "estado del programa", "cola de cli_debrid", "descargas activas"
- "logs de cli_debrid", "tamaño de la biblioteca de cli_debrid", "estadísticas del panel"
- "forzar una tarea", "lanzar Scraping", "por qué no avanza este título en cli_debrid"
- Cualquier mención de cli_debrid o de su monitorización

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Consulta el estado, la cola, las descargas, los logs y las estadísticas de cli_debrid, y fuerza tareas de su planificador.

## Propósito

Esta skill permite supervisar cli_debrid:
- Ver si el programa está en marcha o parado
- Consultar las estadísticas del panel (`dashboard`), la cola y las descargas activas
- Leer el tamaño de la biblioteca y los últimos logs
- Forzar de inmediato una tarea del planificador

Hay operaciones de lectura y de escritura. **Confirma siempre con el usuario antes de forzar una tarea**, salvo que la haya pedido por su nombre.

## Configuración

Añade las credenciales al `.env` (raíz del repo). cli_debrid **no usa API key**: autentica con usuario y contraseña mediante una sesión por cookie, el mismo login que su interfaz web.

```bash
CLI_DEBRID_URL="http://localhost:5000"
CLI_DEBRID_USER="admin"
CLI_DEBRID_PASSWORD="tu-contraseña-del-panel"
```

- `CLI_DEBRID_URL`: URL del panel de cli_debrid (sin barra final)
- `CLI_DEBRID_USER` y `CLI_DEBRID_PASSWORD`: credenciales del panel

## Comandos

Todos imprimen la respuesta de cli_debrid tal cual (JSON); la forma exacta depende de cli_debrid. Sin comando muestra la ayuda (código 0); un comando desconocido la muestra y sale con 1. Si falta un argumento obligatorio o `n` no es numérico, imprime el uso y sale con 1. Un fallo de login, una respuesta HTTP que no sea 2xx o la falta de conexión imprimen `ERROR:` por stderr y salen con 1.

### Consultar el estado

```bash
bash .claude/skills/cli_debrid/scripts/cli_debrid.sh status
bash .claude/skills/cli_debrid/scripts/cli_debrid.sh dashboard
bash .claude/skills/cli_debrid/scripts/cli_debrid.sh library-size
```

**Salida:** `status` indica si el programa está en marcha o parado. `dashboard` devuelve las estadísticas del panel con recuentos por estado. `library-size` devuelve el tamaño de la biblioteca.

### Cola, descargas y logs

```bash
bash .claude/skills/cli_debrid/scripts/cli_debrid.sh queue
bash .claude/skills/cli_debrid/scripts/cli_debrid.sh downloads
bash .claude/skills/cli_debrid/scripts/cli_debrid.sh logs 200
```

**Salida:** `queue` devuelve el contenido de cada cola, `downloads` las descargas activas y `logs [n]` las últimas `n` líneas (100 por defecto).

### Forzar una tarea

```bash
bash .claude/skills/cli_debrid/scripts/cli_debrid.sh trigger-task Scraping
```

**Confirma con el usuario antes de forzar la tarea.** Ejecuta de inmediato una tarea del planificador por su nombre y no pide confirmación por sí misma. **Salida:** la respuesta de cli_debrid.

## Flujo de trabajo

1. **"¿Está en marcha cli_debrid?"** → ejecuta `status`
2. **"¿Qué hay en la cola?"** → ejecuta `queue`; para el detalle por estado, `dashboard`
3. **"¿Por qué no avanza este título?"** → consulta `queue` y `logs`; si el título no aparece, revisa `arr-language-filters` (filtro de idioma)
4. **"Fuerza el Scraping"** → confirma y ejecuta `trigger-task Scraping`

## Parámetros

### Comando logs
- `[n]`: número de líneas (100 por defecto; debe ser numérico)

### Comando trigger-task
- `<nombre>`: nombre de la tarea del planificador, por ejemplo `Scraping` (obligatorio)

## Notas

- La cookie de sesión se guarda en `/tmp` con permisos 600 y se reutiliza mientras sea válida; si caduca, el script vuelve a iniciar sesión solo
- Si el login falla, el script lo dice y sale con 1 en lugar de continuar con una sesión inválida
- Si el panel no responde (curl 7), da la skill por inaccesible e infórmalo

## Referencia

- [cli_debrid en GitHub](https://github.com/godver3/cli_debrid)
