---
name: prowlarr
description: Esta skill debe usarse cuando se busca en indexadores o se gestiona Prowlarr. Úsala cuando el usuario pida "buscar un torrent", "buscar en los indexadores", "encontrar un release", "comprobar el estado de los indexadores", "listar indexadores", "búsqueda en Prowlarr", "sincronizar indexadores", "logs de Prowlarr", o mencione Prowlarr o la gestión de indexadores.
---

# Skill de Prowlarr

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "buscar un torrent", "buscar en los indexadores", "encontrar un release"
- "búsqueda en Prowlarr"
- "comprobar el estado de los indexadores", "listar indexadores"
- "sincronizar indexadores"
- Cualquier mención de Prowlarr o de la gestión de indexadores

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Busca releases en los indexadores torrent y usenet de Prowlarr, comprueba su estado, los prueba, activa, desactiva o elimina, los sincroniza con las aplicaciones conectadas (Radarr, Sonarr...) y consulta el log.

## Propósito

Esta skill usa la API v1 de Prowlarr para:
- Buscar releases por texto libre, por episodio (TVDB) o por película (IMDb o TMDB); solo lectura, pero consulta indexadores externos
- Listar los indexadores y sus estadísticas, y revisar el estado y los avisos de salud de Prowlarr
- Probar un indexador o todos (`test`, `test-all`)
- Activar, desactivar o eliminar un indexador (modifica estado)
- Listar las aplicaciones conectadas y lanzar la sincronización de indexadores hacia ellas (modifica estado)
- Consultar las últimas entradas del log (solo lectura)

## Configuración

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
PROWLARR_URL="http://localhost:9696"
PROWLARR_API_KEY="your-api-key"
```

- `PROWLARR_URL`: URL de Prowlarr con el puerto (9696 por defecto); se quita una barra final
- `PROWLARR_API_KEY`: clave de API, en Prowlarr → Settings → General → Security → API Key
- Las variables ya exportadas en el entorno tienen prioridad sobre `~/.claude/plex-crew/.env`
- `PROWLARR_MAX_TIME`: opcional, segundos máximos de cada petición (30 por defecto)
- `PROWLARR_TESTALL_MAX_TIME`: opcional, segundos máximos solo de `test-all` (120 por defecto, o `PROWLARR_MAX_TIME` si está definida)

## Ejecución del script

El script está en `${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh`. Llámalo siempre con esa ruta y con `bash`, sin cambiar el directorio de trabajo de la sesión. Necesita `curl` y `jq`. Hasta `help` exige credenciales cargadas.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" help
```

## Comandos

`logs` y `help` imprimen texto; el resto, JSON. Sin comando, o con `help`, `-h` o `--help`, se muestra la ayuda por stdout (código 0). Un comando desconocido imprime `ERROR: comando desconocido: <x>` y `Usa: prowlarr-api.sh help` por stderr y termina con 1. Cualquier argumento no válido (id ausente o no numérico, opción sin valor, número mal formado, búsqueda sin texto) imprime `ERROR:` y `Uso:` por stderr y termina con 1, sin llamar a Prowlarr. Si no se puede contactar con Prowlarr: `ERROR: no se pudo contactar con Prowlarr en <URL>` (código 1). Si Prowlarr responde con un HTTP que no es 2xx: `ERROR: <MÉTODO> <ruta> respondió HTTP <código>` y, si hay, `: <mensaje>` (código 1).

| Comando | Modifica estado | Confirmación |
|---------|-----------------|--------------|
| `search`, `tv-search`, `movie-search`, `indexers`, `stats`, `apps`, `status`, `health`, `logs` | No | Ninguna |
| `test`, `test-all` | No persistente | Ninguna; avisa de que `test-all` puede tardar hasta 120 s |
| `enable` | Sí | Confirma con el usuario |
| `disable` | Sí | Confirma con el usuario |
| `sync` | Sí | Confirma con el usuario |
| `delete` | Sí, permanente | Doble confirmación y `PLEX_CREW_CONFIRMED=1` |

### Buscar por texto

Solo lectura; consulta indexadores externos, así que respeta sus límites de peticiones.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" search "ubuntu 22.04"
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" search "inception" --category 2000 --torrents --limit 10
```

Opciones: `--torrents` (solo indexadores torrent), `--usenet` (solo usenet; gana la última de las dos), `--category` o `-c <ids>` (categorías Newznab/Torznab, ver la tabla más abajo), `--limit` o `-l <n>` (entero) y `--type` o `-t <tipo>` (no documentada en la ayuda; por defecto `search`).

**Salida:** un array JSON con objetos de claves `title`, `indexer`, `size` (cadena `"1536 MB"`), `seeders`, `leechers`, `age` (días, como lo da Prowlarr), `downloadUrl` e `infoUrl`. Sin texto de búsqueda: `ERROR: falta el texto de búsqueda` y el uso (código 1). La consulta es la primera palabra, salvo que empiece por `--`; entonces es la primera palabra suelta entre las opciones. Entrecomilla el texto.

Para películas y series usa mejor los dos comandos siguientes: con Torrentio, el texto libre devuelve un título fijo (ver la skill `arr-language-filters`).

### Buscar un episodio

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" tv-search --tvdb 71663 --season 1 --episode 1
```

**Salida:** array JSON con `title`, `indexer`, `size`, `seeders`, `age` y `downloadUrl` (sin `leechers` ni `infoUrl`). Sin ninguna de las tres opciones: `ERROR: falta al menos --tvdb` y el uso (código 1). Opciones y palabras desconocidas se ignoran.

### Buscar una película

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" movie-search --imdb tt0111161
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" movie-search --tmdb 278
```

**Salida:** igual que `tv-search`. Sin `--imdb` ni `--tmdb`: `ERROR: falta --imdb o --tmdb` y el uso (código 1).

### Listar indexadores

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" indexers
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" indexers --verbose
```

**Salida:** array JSON `[{id, name, protocol, enabled, priority}]`. Con `--verbose` (o `-v`), el JSON completo de Prowlarr sin transformar; incluye los campos de configuración de cada indexador (pueden contener claves o cookies de trackers: no los pegues en el chat).

### Estadísticas

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" stats
```

**Salida:** array JSON `[{name, queries, grabs, failures, avgResponseTime}]`.

### Probar indexadores

`test` y `test-all` no cambian la configuración, pero lanzan consultas reales a los indexadores. Avisa de que `test-all` puede tardar hasta 120 s.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" test 5
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" test-all
```

**Salida de `test`:** `{"status": "ok", "indexer": "5", "tested": true}` (código 0). Si falla, `ERROR: POST /indexer/test respondió HTTP 400: <mensaje>` y la línea `{"status": "error", "indexer": "5", "tested": false}` por stderr (código 1).

**Salida de `test-all`:** `{"status": "ok", "tested": 3, "failed": 0}` (código 0). Con fallos, por stderr `ERROR: indexers con fallo:` seguido de un array JSON `[{id, name, errors}]`, y por stdout `{"status": "error", "tested": 3, "failed": 1}` (código 1). Si la respuesta no es un array: `ERROR: respuesta inesperada de Prowlarr en testall`.

### Activar o desactivar un indexador

**Modifica estado: confirma con el usuario antes de activar o desactivar.** Al desactivar, el indexador deja de usarse y, tras la siguiente sincronización, desaparece de Radarr y Sonarr.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" disable 5
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" enable 5
```

**Salida:** `{"status": "ok", "indexer": "5", "enabled": false}` (o `true`). Id ausente o no numérico: `ERROR: falta id` o `ERROR: id debe ser un número entero: <valor>` y `Uso: prowlarr-api.sh disable <id>` (código 1). El hook `confirm-destructive` no cubre estos dos comandos: la confirmación es solo responsabilidad tuya.

### Eliminar un indexador

**Destructivo y permanente** (borra el indexador y su configuración). Según la skill `plex-crew-rules`, exige doble confirmación del usuario en dos mensajes distintos y anteponer `PLEX_CREW_CONFIRMED=1` al comando; el hook `confirm-destructive` bloquea cualquier `prowlarr-api.sh delete` sin ese marcador. Si solo hace falta que no se use, propón `disable`.

```bash
PLEX_CREW_CONFIRMED=1 bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" delete 5
```

**Salida:** `{"status": "ok", "indexer": "5", "deleted": true}` (código 0).

### Aplicaciones y sincronización

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" apps
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" sync
```

**Salida de `apps`:** array JSON `[{id, name, syncLevel, implementation}]`.

**`sync` modifica estado: confirma con el usuario antes de sincronizar.** Empuja la configuración de indexadores a todas las aplicaciones conectadas (Sonarr, Radarr...) y puede añadir o quitar indexadores allí. **Salida:** primero el cuerpo de la respuesta de Prowlarr tal cual (el comando en cola) y después la línea `{"status": "ok", "message": "Syncing indexers to applications"}`. No espera a que termine la sincronización.

### Estado y salud

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" status
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" health
```

**Salida de `status`:** el JSON de `/system/status` sin transformar (versión, sistema operativo, rama...). **Salida de `health`:** array JSON `[{source, type, message}]`; `[]` si no hay avisos.

### Consultar el log

Solo lectura.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" logs
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" logs 20 --level warn
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" logs 100 --grep "indexer"
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" logs --files
```

Opciones, en cualquier orden:
- `N`: número de entradas, entero de 1 a 1000 (50 por defecto)
- `--level <nivel>`: `trace`, `debug`, `info`, `warn`, `error` o `fatal` (admite mayúsculas); se envía a Prowlarr, que lo aplica según el nivel
- `--grep <texto>`: solo entradas cuyo mensaje o logger contiene el texto, sin distinguir mayúsculas
- `--files`: lista los ficheros de log; ignora `N`, `--level` y `--grep`

**Salida:** una línea por entrada, la más antigua primero: `<time>  <NIVEL>  <logger>  <mensaje>` (separadores de dos espacios; `?` si falta time o logger; nivel en mayúsculas y de 5 letras como máximo). Del mensaje solo se muestra la primera línea, con los valores de `apikey`, `api_key`, `token`, `passkey`, `password` y `secret` en pares `clave=valor` sustituidos por `***`, truncada a 200 caracteres más `...`. Con `--files`: `<lastWriteTime>  <filename>` por fichero. Argumentos no válidos imprimen `ERROR:` (y el uso, salvo en un nivel no válido) por stderr y terminan con 1 antes de llamar a Prowlarr; si el servicio no expone `/log`: `ERROR: respuesta inesperada de /log (¿el servicio no expone el endpoint?)`.

## Categorías Newznab/Torznab

Para `--category`; admite varias separadas por coma.

| Id | Categoría | Subcategorías habituales |
|----|-----------|--------------------------|
| 1000 | Consolas | |
| 2000 | Películas | 2040 HD, 2045 UHD, 2050 BluRay |
| 3000 | Audio | 3010 MP3, 3040 Lossless |
| 4000 | PC | 4050 Juegos |
| 5000 | TV | 5040 HD, 5045 UHD, 5070 Anime |
| 6000 | XXX | |
| 7000 | Libros | |

## Casos de uso

1. **Buscar una ISO:** `search "ubuntu 22.04" --torrents`
2. **Un episodio concreto:** `tv-search --tvdb 71663 --season 1 --episode 1`
3. **Película en 4K:** `movie-search --imdb tt0111161` y filtra el resultado con `jq` por `2160p` en `title`; o `search "título" --category 2045`
4. **Comprobar los indexadores:** `health`, `stats` (consultas y fallos) y `test-all`; si uno falla, `test <id>`
5. **Quitar un indexador roto de Radarr y Sonarr:** `disable <id>` (tras confirmar) y `sync` (tras confirmar)

## Notas

- Nunca imprimas `PROWLARR_API_KEY` ni uses `curl` con la clave en línea: usa siempre el script, que pasa la clave y los cuerpos de indexador por stdin de curl para que no salgan en `ps`.
- Timeouts: 10 s de conexión y 30 s en total por petición (`PROWLARR_MAX_TIME`); `test-all` 120 s (`PROWLARR_TESTALL_MAX_TIME`). Sin reintentos.
- El usuario trabaja en Europe/Madrid (regla global en `plex-crew-rules`).

### Limitaciones conocidas

- `help` y cualquier comando exigen credenciales cargadas.
- `enable` y `disable` reenvían la definición completa del indexador leída de Prowlarr, cambiando solo `enable`; Prowlarr puede rechazarla (HTTP 400) si el indexador tiene errores de validación.
- `test` solo informa de ok o error; el motivo detallado solo aparece si Prowlarr lo devuelve en el mensaje HTTP.
- `sync` imprime el cuerpo de la respuesta y después el mensaje de éxito; no espera a que acabe la sincronización ni comprueba su resultado.
- `delete` no pide confirmación por sí mismo (solo el hook); `enable`, `disable` y `sync` ni siquiera pasan por el hook.
- No hay comandos para añadir o editar indexadores, aplicaciones, clientes de descarga, etiquetas ni notificaciones, ni para ver el historial.
- `tv-search` acepta cualquier combinación de opciones y solo falla si no se da ninguna: con `--season` o `--episode` sin `--tvdb` hace una consulta sin id.
- `--imdb` y `--category` no se validan; se envían tal cual (`--category` admite lo que acepte Prowlarr, ids numéricos de Newznab/Torznab).
- En las búsquedas, si un resultado tiene `size` nulo, `jq` falla. Los resultados no se ordenan y, sin `--limit`, pueden ser muy largos. `age` va en días.
- `search`: si la primera palabra empieza por `--` no se toma como consulta; las palabras sueltas posteriores a la consulta se ignoran.
- `logs`: el enmascarado solo cubre pares `clave=valor` con las seis claves indicadas (no JSON, cabeceras ni `Bearer`); `--grep` compara con el texto sin enmascarar y solo ve las `min(N*20, 1000)` entradas más recientes; solo se muestra la primera línea de cada mensaje.
- `test-all` puede tardar hasta 120 s; si Prowlarr tarda más, falla con el mensaje de conexión, indistinguible de un servicio caído. Las llamadas no distinguen la causa de un fallo de curl; solo los fallos HTTP informan del código.
- Solo se quita una barra final de `PROWLARR_URL`.

## Referencia

- [Wiki de Prowlarr](https://wiki.servarr.com/prowlarr)
- [API de Prowlarr](https://prowlarr.com/docs/api/)

Para la referencia local detallada, consulta:
- **[Endpoints de la API](./references/api-endpoints.md)** - Comando del script, método, ruta y parámetros
- **[Referencia rápida](./references/quick-reference.md)** - Configuración y ejemplos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Autenticación, conexión y uso
