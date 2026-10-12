---
name: plex
description: Esta skill debe usarse cuando se necesite controlar Plex Media Server para explorar bibliotecas, buscar contenido, ver qué se está reproduciendo o consultar lo añadido recientemente. Úsala cuando el usuario pida "revisar Plex", "buscar en Plex", "qué hay en Plex", "añadido recientemente", "quién está viendo algo", "sesiones de Plex", "biblioteca de Plex", "explorar películas", "explorar series", "forzar el escaneo de una biblioteca", o mencione Plex Media Server.
---

# Skill de control de Plex Media Server

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "revisar Plex", "buscar en Plex", "qué hay en Plex"
- "añadido recientemente", "quién está viendo algo", "sesiones de Plex"
- "biblioteca de Plex", "explorar películas", "explorar series"
- "forzar el escaneo de una biblioteca"
- Cualquier mención de Plex Media Server

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Consulta en Plex sus bibliotecas, su contenido y sus reproducciones en curso con la API del servidor.

## Propósito

Esta skill consulta la API de Plex Media Server para:
- Ver la información del servidor y listar las bibliotecas
- Explorar una biblioteca, lo añadido recientemente y "continuar viendo"
- Buscar contenido y leer los metadatos de un elemento y sus hijos
- Ver las reproducciones en curso, los clientes, las listas y las cuentas
- Lanzar el escaneo de una biblioteca (`refresh`)
- Cambiar una preferencia del servidor (`setpref`)

`refresh` y `setpref` son las únicas escrituras; `refresh` dispara un escaneo y `setpref` cambia un ajuste. Ninguna borra nada. Ningún comando es destructivo, así que el hook `confirm-destructive` no aplica. Para ids, rematches y nombres de Plex usa las skills y agentes de nombrado, no esta skill. Ignora las carpetas `.@*` (regla global en `plex-crew-rules`).

## Configuración

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
PLEX_URL="http://localhost:32400"
PLEX_TOKEN="your-plex-token"
```

- `PLEX_URL`: URL del servidor con el puerto (32400 por defecto); una barra final se ignora
- `PLEX_TOKEN`: token de Plex. En la web de Plex abre cualquier elemento, elige Ver XML y copia `X-Plex-Token` de la URL
- Las variables ya exportadas en el entorno tienen prioridad sobre `~/.claude/plex-crew/.env`

## Ejecución del script

El script está en `${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh`. Llámalo siempre con esa ruta y con `bash`, sin cambiar el directorio de trabajo de la sesión. Necesita `curl`; `search` necesita además `jq`.

## Comandos

Todos los comandos devuelven JSON: el cuerpo que responde Plex, sin reformatear (la excepción es `refresh`). Filtra con `jq`. Sin comando se muestra la ayuda (código de salida 0); un comando desconocido la muestra por stderr y termina con 1. Un argumento obligatorio ausente, una opción desconocida, una opción sin valor o un id, `--limit` u `--offset` no numérico imprime el uso y termina con 1. Si curl no consigue contactar con Plex, imprime `ERROR:` en stderr y termina con 1.

Las opciones tienen alias cortos: `-l` para `--limit` y `-o` para `--offset`. En `library` y `search` el primer argumento es siempre el posicional (id o texto) y las opciones van después. Las fechas de Plex (`addedAt`, `lastViewedAt`) son marcas de tiempo Unix; el usuario trabaja en Europe/Madrid (regla global en `plex-crew-rules`).

### Servidor

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" info
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" identity
```

**Salida:** `info` devuelve el `MediaContainer` del servidor (versión, plataforma, capacidades). `identity` devuelve versión, `machineIdentifier` y si está reclamado.

### Bibliotecas

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" libraries
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" library 1
```

**Salida:** `libraries` devuelve las bibliotecas en `Directory` (`key`, `title`, `type`, ubicaciones); `key` es el `section-id`. `library` devuelve el contenido de esa biblioteca en `Metadata`, sin límite por defecto (puede ser enorme). `--limit` y `--offset` están rotos, ver Limitaciones conocidas.

### Reciente y continuar viendo

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" recent --limit 30
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" ondeck
```

**Salida:** `recent` devuelve lo añadido recientemente (20 por defecto). `ondeck` devuelve "continuar viendo" (10 por defecto). Ambos aceptan `--limit N`.

### Búsqueda

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" search "la casa de papel" --limit 5
```

**Salida:** resultado de la búsqueda global de Plex. El texto se codifica (espacios, tildes y caracteres especiales). Un texto vacío se envía como consulta vacía. Plex puede ignorar `--limit` según la versión.

### Metadatos

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" metadata 12345
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" children 12345
```

**Salida:** `metadata` devuelve los metadatos del elemento con ese `ratingKey`. `children` devuelve sus hijos: temporadas de una serie, episodios de una temporada o pistas de un álbum.

### Actividad y listas

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" sessions
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" clients
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" playlists
```

**Salida:** `sessions` devuelve las reproducciones en curso (`User`, `Player`, `Media`, `TranscodeSession`); sin ninguna, un `MediaContainer` con `size` 0. No hay historial: eso es de la skill `tautulli`. `clients` devuelve los reproductores conectados (puede venir vacío). `playlists` devuelve las listas de reproducción.

### Administración

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" accounts
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" prefs | jq '.MediaContainer.Setting[] | select(.id=="FriendlyName")'
```

**Salida:** `accounts` devuelve las cuentas de usuario y `prefs` las preferencias del servidor; ambos exigen un token de administrador. `prefs` puede contener datos sensibles: filtra y no pegues la salida entera en el chat.

### Cambiar una preferencia

**Confirma con el usuario antes de ejecutar `setpref`** y cambia un solo ajuste por llamada.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" setpref autoEmptyTrash 1
```

**Salida:** una línea `clave: antes -> después`, p. ej. `autoEmptyTrash: false -> true` (los bool se muestran como `true`/`false`). Hace `PUT /:/prefs?<clave>=<valor>`: lee el valor actual, aplica, relee y sale con 1 si el valor final no coincide o si la clave no existe. La clave solo admite `[A-Za-z0-9]+` y el valor `[A-Za-z0-9._-]+`. En Plex un bool `true` se guarda como `1` y `false` como `0`. Requiere `jq` y token de administrador.

### Escaneo de una biblioteca

**Confirma con el usuario antes de ejecutar `refresh`.** El usuario tiene un script externo que ya actualiza Plex tras renombrar: no ofrezcas escaneos por iniciativa propia, ni siquiera tras un renombrado.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" refresh 1
```

**Salida:** lo que devuelva Plex (normalmente nada) y, siempre, la línea `{"status": "ok", "message": "Library refresh initiated"}`. Esa línea sale aunque Plex haya rechazado la petición; no la tomes como prueba de que el escaneo empezó.

## Flujo de trabajo

1. **"¿Qué hay en Plex?"** → `libraries` y elige el `key` de la biblioteca
2. **"¿Qué se añadió hace poco?"** → `recent --limit 30`
3. **"¿Está X en Plex?"** → `search "X"` y toma el `ratingKey`
4. **"¿Qué temporadas o episodios tiene?"** → `children <ratingKey>` y repite con la temporada
5. **"¿Quién está viendo algo?"** → `sessions`

Cadena de ids: `libraries` da el `section-id`; `search` y `library` dan el `ratingKey` para `metadata` y `children`.

## Lectura de la salida

La respuesta va dentro de `MediaContainer`. Los elementos están en `Metadata` (contenido) o en `Directory` (bibliotecas). Campos frecuentes: `ratingKey`, `title`, `type`, `year`, `addedAt`, `librarySectionID`. Ejemplo: `... recent | jq '.MediaContainer.Metadata[] | {ratingKey, title, type, year}'`.

## Parámetros

| Opción | Comandos | Notas |
|--------|----------|-------|
| `<section-id>` | library, refresh | Entero; primer argumento |
| `<clave> <valor>` | setpref | clave `[A-Za-z0-9]+`, valor `[A-Za-z0-9._-]+` |
| `<rating-key>` | metadata, children | Entero |
| `<texto>` | search | Primer argumento; entrecomíllalo |
| `--limit N`, `-l N` | library, recent (20), ondeck (10), search | Entero >= 0 |
| `--offset N`, `-o N` | library | Entero >= 0; roto |

## Notas

- Nunca imprimas `PLEX_TOKEN` ni uses `curl` con el token en línea: usa siempre el script.
- Timeouts: 10 s de conexión y 30 s en total, sin reintentos.
- El token viaja a Plex en cabecera y en la URL, pero el script lo pasa a curl por stdin y no sale en `ps`.

### Limitaciones conocidas

- No se comprueba el código HTTP: un 401 o un 404 imprime el cuerpo de Plex (texto o HTML, no JSON) y termina con 0. Si la salida no es JSON, sospecha del token o de la ruta.
- `refresh` imprime siempre la línea de "iniciado".
- `library --limit` y `--offset` generan una ruta mal formada (`/library/sections/<id>/all&X-Plex-Container-Size=<N>?X-Plex-Token=...`): la paginación no se aplica y Plex puede responder 404. Filtra con `jq` o usa `recent`.
- `help` también exige credenciales cargadas.
- `search` y `library` toman el primer argumento como posicional aunque empiece por `-`: `search --limit 5` busca el texto `--limit` y falla por la opción `5`.
- Los argumentos sobrantes se ignoran en silencio en los comandos sin opciones y en `metadata`, `children` y `refresh`.
- No hay filtros, formato de texto, marcado de visto, edición de metadatos ni borrado.

## Referencia

- [API de Plex Media Server (developer.plex.tv)](https://developer.plex.tv/pms/)
- [Soporte de Plex](https://support.plex.tv)

Para la referencia local detallada, consulta:
- **[Endpoints de la API](./references/api-endpoints.md)** - Comando del script, ruta de Plex y parámetros
- **[Referencia rápida](./references/quick-reference.md)** - Configuración y ejemplos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Autenticación, conexión y uso
