---
name: dozzle
description: Esta skill debe usarse cuando se consulten los logs o el estado de los contenedores Docker del stack a través de Dozzle. Úsala cuando el usuario pida "logs de un contenedor", "logs de Dozzle", "ver los logs de radarr", "qué contenedores hay", "estado de los contenedores", "por qué falla un contenedor", "buscar un error en los logs", o mencione Dozzle.
---

# Skill de logs de contenedores de Dozzle

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "logs de un contenedor", "logs de Dozzle", "ver los logs de <servicio>"
- "qué contenedores hay", "estado de los contenedores"
- "por qué falla un contenedor", "buscar un error en los logs"
- Cualquier mención de Dozzle

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Lista los contenedores Docker que ve Dozzle y lee sus logs, con los secretos ocultos. Es de solo lectura: no reinicia, para ni modifica contenedores.

## Propósito

Esta skill usa la API HTTP de Dozzle para:
- Listar los contenedores con su estado (`running`, `exited`...) y su salud
- Leer las últimas líneas del log de un contenedor, filtrando por texto, por fecha o por flujo (`stdout` / `stderr`)

Dozzle no usa clave de API: solo hace falta su URL. **Para ver logs de contenedores usa siempre esta skill** (no `docker logs`).

## Configuración

Añade la URL a `~/.claude/plex-crew/.env`:

```bash
DOZZLE_URL="http://host:8080"
```

- `DOZZLE_URL`: URL de Dozzle con el puerto, sin barra final. No hay variable de clave.
- Las variables ya exportadas en el entorno tienen prioridad sobre `~/.claude/plex-crew/.env`.
- Opcional: `DOZZLE_MAX_TIME` (segundos máximos por petición de logs, 30 por defecto).

Si Dozzle tiene la autenticación activada, la skill no puede leerlo (ver `references/troubleshooting.md`).

## Ejecución del script

El script está en `${CLAUDE_PLUGIN_ROOT}/skills/dozzle/scripts/dozzle.sh`. Llámalo siempre con esa ruta y con `bash`, sin cambiar el directorio de trabajo de la sesión. Necesita `curl`, `jq`, `awk` y `sed`.

## Comandos

Todo imprime texto. Sin comando, o con `help`, `-h` o `--help`, muestra la ayuda por stdout (código 0). Un comando desconocido imprime `ERROR: comando desconocido: <x>` y la ayuda por stderr y termina con 1. Un argumento ausente o no válido imprime `ERROR:` y `Uso:` por stderr y termina con 1, sin llamar a Dozzle. Si Dozzle no responde, `ERROR: no se pudo leer la lista de contenedores de Dozzle en <URL>` y código 1.

### Listar contenedores

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/dozzle/scripts/dozzle.sh" status
bash "${CLAUDE_PLUGIN_ROOT}/skills/dozzle/scripts/dozzle.sh" containers
```

**Salida:** `status` y `containers` hacen lo mismo. Primera línea: `Dozzle v11.4.0 - 30 contenedores, 30 en ejecución`. Después, una línea por contenedor ordenada por nombre: nombre, estado, salud (`-` si no tiene healthcheck) e id corto. No admiten argumentos.

### Leer logs de un contenedor

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/dozzle/scripts/dozzle.sh" logs radarr
bash "${CLAUDE_PLUGIN_ROOT}/skills/dozzle/scripts/dozzle.sh" logs radarr --lines 50 --grep error
bash "${CLAUDE_PLUGIN_ROOT}/skills/dozzle/scripts/dozzle.sh" logs sonarr --stderr --since 2026-11-05T08:00:00Z
```

Opciones, en cualquier orden:
- `<contenedor>`: nombre (sin distinguir mayúsculas), id o prefijo del id, o un trozo único del nombre. Obligatorio.
- `--lines N`: últimas N líneas, entero de 1 a 5000 (100 por defecto)
- `--grep <texto>`: solo las líneas que contienen el texto, sin distinguir mayúsculas; se aplica antes de recortar a N
- `--since <fecha>`: solo desde esa fecha UTC, formato `AAAA-MM-DDTHH:MM:SSZ`; úsalo para acotar logs muy largos
- `--stderr` / `--stdout`: solo ese flujo (ambos por defecto)

**Salida:** las líneas del log tal como las escribe la aplicación, la más antigua primero (Dozzle no añade marca de hora: la hora es la que ponga la aplicación). Los secretos (`token=`, `apikey=`, `password=`, `secret=`, cabeceras `Authorization`, `X-Api-Key`, `Bearer ...`) salen como `***`. Sin coincidencias no imprime nada (código 0). Si no se encuentra el contenedor: `ERROR: contenedor no encontrado: <x>` y código 1.

## Flujo de trabajo

1. **"Logs de radarr"** → `logs radarr --lines 100`
2. **"Por qué falla X"** → `logs X --lines 200 --grep error`; si no hay nada, `--stderr` o más líneas
3. **"Qué contenedores hay / están caídos"** → `containers` y revisa los que no estén en `running` o en `healthy`
4. Contenedor desconocido → `containers` para ver los nombres exactos

## Parámetros

| Argumento | Comandos | Notas |
|-----------|----------|-------|
| `<contenedor>` | logs | Nombre, id o prefijo; un solo contenedor |
| `--lines N` | logs | Entero 1-5000; 100 por defecto |
| `--grep texto` | logs | Sin distinguir mayúsculas, texto literal |
| `--since fecha` | logs | UTC, `AAAA-MM-DDTHH:MM:SSZ` |
| `--stderr`, `--stdout` | logs | Limitan el flujo; ambos si no se indica |
| (ninguno) | status, containers | No admiten argumentos |

## Notas

- Solo lectura. La petición de logs es un `POST` porque así lo expone Dozzle, pero no modifica nada.
- Nunca imprimas secretos que aparezcan en un log aunque la redacción haya fallado; avisa al usuario.
- Las horas del usuario son las de la máquina donde corre el plugin (regla global en `plex-crew-rules`).

### Limitaciones conocidas

- Dozzle devuelve el log completo del contenedor (o desde `--since`); el recorte a N líneas y `--grep` se hacen en el cliente. Con logs enormes la respuesta se corta a los `DOZZLE_MAX_TIME` segundos con un `AVISO` por stderr: usa `--since`.
- La lista de contenedores se lee del stream de eventos de Dozzle (4 s como máximo); con varios hosts conectados solo se garantiza el contenido del primer evento.
- La redacción de secretos es heurística (pares `clave=valor`, `clave: valor`, JSON `"clave":"valor"`, cabeceras y `Bearer`): no cubre secretos sin nombre de clave.
- No hay seguimiento en vivo (`follow`), niveles ni filtro por regex.

## Referencia

- [Dozzle](https://dozzle.dev/)

Para la referencia local detallada, consulta:
- **[Endpoints de la API](./references/api-endpoints.md)** - Endpoints de Dozzle que usa el script
- **[Referencia rápida](./references/quick-reference.md)** - Configuración y ejemplos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Conexión, autenticación y uso
