---
name: plex
description: Gestión de Plex Media Server. Úsala cuando el usuario pida "comprobar Plex", "buscar en Plex", "qué hay en Plex", "añadidos recientemente", "quién está viendo", "sesiones de Plex", "biblioteca de Plex", "explorar películas", "explorar series", o mencione Plex Media Server.
---

# Skill de gestión de Plex Media Server

**INVOCACIÓN OBLIGATORIA DE LA SKILL**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "biblioteca de Plex", "buscar en Plex", "qué hay en Plex"
- "sesiones de Plex", "quién está viendo", "streams activos"
- "explorar Plex", "comprobar Plex", "estado de Plex"
- "añadidos recientemente", "continuar viendo"
- Cualquier mención de Plex Media Server o de consultar contenido multimedia

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Explora las bibliotecas de Plex, busca contenido y consulta las reproducciones en curso a través de la API del servidor.

## Propósito

Esta skill da acceso a Plex Media Server, casi todo de solo lectura:
- Listar las secciones de biblioteca y su contenido
- Buscar contenido
- Ver los añadidos recientemente y la lista "continuar viendo"
- Consultar las sesiones en curso y los clientes conectados
- Consultar metadatos, listas de reproducción, cuentas y preferencias

El único comando que modifica estado es `refresh`, que lanza un escaneo de una sección. La skill no controla la reproducción.

## Configuración

Añade las credenciales al `.env` (raíz del repo):

```bash
PLEX_URL="http://localhost:32400"
PLEX_TOKEN="tu-token"
```

- `PLEX_URL`: URL del servidor Plex con puerto (sin barra final)
- `PLEX_TOKEN`: token de autenticación de Plex (plex.tv → cuenta → dispositivos autorizados, o "Ver XML" de cualquier elemento en Plex Web y buscar `X-Plex-Token` en la URL)

## Comandos

Todos los comandos devuelven JSON salvo `refresh`, que imprime texto. Usa `jq` para filtrar. Sin comando muestra la ayuda (código 0); un comando desconocido la muestra por stderr y sale con 1. Si falta un argumento obligatorio, falta el valor de una opción, un valor numérico no es un número o hay una opción desconocida, imprime el uso por stderr y sale con 1. Si Plex responde con un HTTP distinto de 2xx, imprime `ERROR:` por stderr y sale con 1.

### Información del servidor

```bash
bash .claude/skills/plex/scripts/plex-api.sh info
bash .claude/skills/plex/scripts/plex-api.sh identity
```

**Salida:** JSON con la información y las capacidades del servidor (`info`) o su identidad (`identity`).

### Bibliotecas

```bash
bash .claude/skills/plex/scripts/plex-api.sh libraries
```

**Salida:** JSON con las secciones de biblioteca y sus claves. Las claves varían por servidor: lista siempre las secciones antes de explorar una.

### Contenido de una biblioteca

```bash
bash .claude/skills/plex/scripts/plex-api.sh library <section-id>
bash .claude/skills/plex/scripts/plex-api.sh library 1 --limit 50 --offset 100
```

**Salida:** JSON con los elementos de la sección. `--limit` y `--offset` paginan (ambos numéricos).

### Buscar contenido

```bash
bash .claude/skills/plex/scripts/plex-api.sh search "Inception"
bash .claude/skills/plex/scripts/plex-api.sh search "Avengers" --limit 10
```

**Salida:** JSON con los resultados de la búsqueda en todas las bibliotecas.

### Añadidos recientemente y continuar viendo

```bash
bash .claude/skills/plex/scripts/plex-api.sh recent --limit 10
bash .claude/skills/plex/scripts/plex-api.sh ondeck --limit 5
```

**Salida:** JSON. `recent` devuelve los añadidos recientemente (20 por defecto) y `ondeck` la lista "continuar viendo" (10 por defecto).

### Metadatos y elementos hijos

```bash
bash .claude/skills/plex/scripts/plex-api.sh metadata <rating-key>
bash .claude/skills/plex/scripts/plex-api.sh children <rating-key>
```

**Salida:** JSON. `metadata` devuelve los metadatos de un elemento y `children` sus hijos (por ejemplo las temporadas de una serie). El `rating-key` es numérico.

### Sesiones, clientes y otros

```bash
bash .claude/skills/plex/scripts/plex-api.sh sessions
bash .claude/skills/plex/scripts/plex-api.sh clients
bash .claude/skills/plex/scripts/plex-api.sh playlists
bash .claude/skills/plex/scripts/plex-api.sh accounts
bash .claude/skills/plex/scripts/plex-api.sh prefs
```

**Salida:** JSON. `sessions` lista las reproducciones en curso, `clients` los reproductores conectados, `playlists` las listas de reproducción, `accounts` las cuentas de usuario y `prefs` las preferencias del servidor (estos dos últimos requieren ser administrador).

### Lanzar un escaneo de biblioteca

```bash
bash .claude/skills/plex/scripts/plex-api.sh refresh <section-id>
```

**Es una escritura:** confirma con el usuario antes de lanzarla. **No lances ni ofrezcas escaneos tras renombrar ficheros**: un script externo del usuario actualiza Plex (véase `plex-naming-rules`). Úsala solo cuando el usuario la pida de forma explícita.

**Salida:** texto, `Escaneo de la sección N solicitado a Plex (HTTP 2xx)`. El script comprueba el código HTTP: si Plex no responde 2xx, imprime `ERROR:` por stderr y sale con 1. Un 2xx confirma que Plex aceptó la petición, no que el escaneo haya terminado.

## Flujo de trabajo

Cuando el usuario pregunte por Plex:

1. **"¿Qué hay en Plex?"** → ejecuta `libraries` y resume las secciones
2. **"Busca Inception"** → ejecuta `search "Inception"`
3. **"¿Qué se añadió hace poco?"** → ejecuta `recent`
4. **"¿Quién está viendo ahora?"** → ejecuta `sessions`
5. **"¿Qué tengo pendiente de ver?"** → ejecuta `ondeck`
6. **"Lista mis películas"** → ejecuta `libraries` para obtener la clave y luego `library <section-id>`
7. **"Escanea la biblioteca"** → confirma con el usuario y ejecuta `refresh <section-id>`

## Parámetros

### Comando library
- `<section-id>`: clave de la sección (obligatorio, numérico)
- `--limit|-l <n>`: máximo de elementos (numérico)
- `--offset|-o <n>`: posición inicial (numérico)

### Comandos recent y ondeck
- `--limit|-l <n>`: máximo de elementos (numérico; 20 en `recent` y 10 en `ondeck` por defecto)

### Comando search
- `<texto>`: texto a buscar (obligatorio)
- `--limit|-l <n>`: máximo de resultados (numérico)

### Comandos metadata y children
- `<rating-key>`: clave del elemento (obligatorio, numérico)

### Comando refresh
- `<section-id>`: clave de la sección a escanear (obligatorio, numérico)

## Notas

- Requiere acceso de red al servidor de Plex
- Las peticiones envían `Accept: application/json` y el token en la cabecera `X-Plex-Token`
- Las claves de sección (1, 2, 3...) varían por servidor: lista siempre las secciones primero
- Todos los comandos son lecturas GET salvo `refresh`, que también es un GET pero lanza un escaneo
- A diferencia de radarr y sonarr, casi todos los comandos devuelven JSON; solo `refresh` imprime texto
- `refresh` no es destructivo, así que el hook `confirm-destructive` no interviene: la confirmación previa con el usuario es obligatoria igualmente
- El escaneo por zurg tiene sus propias tools (`mcp__zurg__zurg_plex_*`), fuera de esta skill
- Confirma siempre con el usuario antes de cualquier acción sobre reproductores remotos (la skill no las implementa)

## Referencia

- [API de Plex Media Server](https://www.plexopedia.com/plex-media-server/api/)
- [Plex Web](https://app.plex.tv/)
