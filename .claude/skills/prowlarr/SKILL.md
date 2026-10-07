---
name: prowlarr
description: Gestión de indexadores en Prowlarr. Úsala cuando el usuario pida "buscar un torrent", "buscar en los indexadores", "encontrar un release", "estado de los indexadores", "listar indexadores", "buscar en Prowlarr", "sincronizar indexadores", o mencione Prowlarr o la gestión de indexadores.
---

# Skill de gestión de indexadores en Prowlarr

**INVOCACIÓN OBLIGATORIA DE LA SKILL**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "buscar un torrent", "buscar en los indexadores", "encontrar un release"
- "buscar en Prowlarr", "indexadores de Prowlarr", "búsqueda en indexadores"
- "estado de los indexadores", "probar indexadores", "estadísticas de Prowlarr"
- "listar indexadores", "sincronizar indexadores", "enviar indexadores a Sonarr"
- Cualquier mención de Prowlarr o de la gestión de indexadores

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Busca releases en todos los indexadores de Prowlarr y gestiona los indexadores y su sincronización con Sonarr y Radarr.

## Propósito

Esta skill permite operar Prowlarr:
- Buscar releases en todos los indexadores, por texto o por id (TVDB, IMDB, TMDB)
- Filtrar las búsquedas por protocolo (torrent o usenet) y por categoría
- Listar los indexadores, ver sus estadísticas y probar su conectividad
- Activar, desactivar o borrar indexadores
- Sincronizar los indexadores con las aplicaciones conectadas (Sonarr, Radarr)
- Consultar el estado del sistema, la salud y los logs

Hay operaciones de lectura y de escritura. **Confirma siempre con el usuario antes de desactivar o borrar indexadores y antes de sincronizar.**

## Configuración

Añade las credenciales al `.env` (raíz del repo):

```bash
PROWLARR_URL="http://localhost:9696"
PROWLARR_API_KEY="tu-api-key"
```

- `PROWLARR_URL`: URL de tu servidor Prowlarr (sin barra final)
- `PROWLARR_API_KEY`: clave de API de Prowlarr (Settings → General → Security → API Key)

## Comandos

Devuelven JSON `search`, `tv-search`, `movie-search`, `indexers`, `stats`, `apps`, `status` y `health`. El resto (`logs`, `test`, `test-all`, `enable`, `disable`, `delete` y `sync`) imprime texto. Sin comando muestra la ayuda (código 0); un comando desconocido la muestra por stderr y sale con 1. Si falta un argumento obligatorio, falta el valor de una opción, un id o un valor numérico no es un número o hay una opción desconocida, imprime el uso por stderr y sale con 1. Si Prowlarr responde con un HTTP distinto de 2xx, imprime `ERROR:` por stderr y sale con 1 (también en las lecturas).

### Buscar releases

```bash
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh search "ubuntu 22.04"
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh search "ubuntu" --torrents
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh search "inception" --category 2000 --limit 20
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh search "inception" --type moviesearch
```

**Salida:** JSON, un array con título, indexador, tamaño en MB, seeders, leechers, edad y URLs de descarga e información. Cada búsqueda consulta indexadores externos: no encadenes muchas seguidas.

### Buscar series por id

```bash
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh tv-search --tvdb 71663 --season 1 --episode 1
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh tv-search --tvdb 71663 --season 1
```

**Salida:** JSON, un array con título, indexador, tamaño, seeders, edad y URL de descarga. Exige al menos una de `--tvdb`, `--season` o `--episode`.

### Buscar películas por id

```bash
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh movie-search --imdb tt0111161
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh movie-search --tmdb 550
```

**Salida:** JSON con el mismo formato que `tv-search`. Exige al menos `--imdb` o `--tmdb`. Es la forma preferida de buscar una película concreta (véase Notas sobre Torrentio).

### Listar indexadores

```bash
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh indexers
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh indexers --verbose
```

**Salida:** JSON, un array con id, nombre, protocolo, si está activo y prioridad. Con `--verbose` devuelve el JSON completo de cada indexador.

### Estadísticas y pruebas

```bash
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh stats
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh test <id>
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh test-all
```

**Salida:** `stats` devuelve JSON con consultas, grabs, fallos y tiempo medio de respuesta por indexador. `test` imprime texto si el indexador supera la prueba; si falla, imprime `ERROR:` con el motivo por stderr y sale con 1. `test-all` imprime una línea por indexador (`correcto` o `FALLA`); un indexador que falla no cambia el código de salida.

### Activar o desactivar un indexador

```bash
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh enable <id>
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh disable <id>
```

**Es una escritura:** confirma con el usuario antes de desactivar un indexador. **Salida:** texto con el resultado, solo si Prowlarr responde 2xx.

### Borrar un indexador

```bash
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh delete <id>
```

**Importante:** el borrado es permanente. El hook `confirm-destructive` exige la doble confirmación y el marcador `PLEX_CREW_CONFIRMED=1` para `delete`. **Salida:** texto con el resultado, solo si Prowlarr responde 2xx.

### Aplicaciones y sincronización

```bash
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh apps
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh sync
```

**Salida:** `apps` devuelve JSON con id, nombre, nivel de sync e implementación de cada aplicación conectada. `sync` es una escritura: empuja los indexadores a todas las aplicaciones conectadas, así que confirma con el usuario antes de lanzarlo. Imprime texto solo si Prowlarr responde 2xx.

### Sistema

```bash
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh status
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh health
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh logs 100 error
```

**Salida:** `status` y `health` devuelven JSON (`health` con origen, tipo y mensaje de cada aviso). `logs` imprime texto, una línea por registro (`hora [nivel] origen: mensaje`), de más reciente a más antiguo; `n` es numérico y vale 50 por defecto.

## Flujo de trabajo

Cuando el usuario pregunte por indexadores o búsquedas:

1. **"Busca un torrent"** → ejecuta `search "<texto>"` y presenta los resultados con sus enlaces
2. **"Busca Breaking Bad S01E01"** → ejecuta `tv-search --tvdb <id> --season 1 --episode 1`
3. **"¿Qué indexadores funcionan?"** → ejecuta `stats` y `health`
4. **"Prueba mis indexadores"** → ejecuta `test-all`
5. **"Sincroniza con Sonarr"** → confirma con el usuario y ejecuta `sync`
6. **"Lista los indexadores"** → ejecuta `indexers` (o `indexers --verbose`)

## Parámetros

### Comando search
- `<texto>`: texto a buscar (obligatorio; entre comillas si tiene espacios)
- `--torrents`: solo torrents (`indexerIds=-2`)
- `--usenet`: solo usenet (`indexerIds=-1`)
- `--category|-c <id>`: categoría Newznab (numérico)
- `--limit|-l <n>`: número máximo de resultados (numérico)
- `--type|-t <tipo>`: tipo de búsqueda (`search` por defecto; también `tvsearch`, `moviesearch`...)

### Comando tv-search
- `--tvdb <id>`: id de TVDB (numérico)
- `--season|-s <n>`: temporada (numérico)
- `--episode|-e <n>`: episodio (numérico)

### Comando movie-search
- `--imdb <id>`: id de IMDB con formato `tt0111161`
- `--tmdb <id>`: id de TMDB (numérico)

### Comando indexers
- `--verbose|-v`: devuelve el JSON completo

### Comandos test, enable, disable y delete
- `<id>`: id del indexador (obligatorio, numérico; se ve con `indexers`)

### Comando logs
- `[n]`: número de líneas (numérico; 50 por defecto)
- `[nivel]`: nivel de log (`info`, `warn`, `error`...)

## Notas

- Requiere acceso de red al servidor de Prowlarr
- Usa la API v1 de Prowlarr
- A diferencia de radarr y sonarr, `search` ya devuelve JSON (no hay `search-json`) y los errores van por stderr como texto `ERROR:`, no como JSON
- Las escrituras (`enable`, `disable`, `delete`, `test`, `test-all`, `sync`) comprueban el código HTTP y nunca imprimen un éxito fijo si Prowlarr no responde 2xx; un 2xx confirma que Prowlarr aceptó la llamada
- Las opciones desconocidas son un error con código 1 en todos los comandos
- La búsqueda de texto de Torrentio sin `imdbid` devuelve resultados de un título de validación fijo: usa `movie-search --imdb` o `tv-search --tvdb` cuando puedas (véase `arr-language-filters`)
- Categorías Newznab habituales: 2000 Movies, 5000 TV, 3000 Audio, 7000 Books, 1000 Console, 4000 PC, 6000 XXX
- Subcategorías habituales: 2040 Movies/HD, 2045 Movies/UHD, 5030 TV/SD, 5040 TV/HD, 5045 TV/UHD
- `logs` pasa el nivel como filtro a Prowlarr, que puede devolver registros de otros niveles
- `disable` y `sync` no pasan por el hook `confirm-destructive` (solo `delete`): la confirmación previa con el usuario depende de ti

## Referencia

- [Documentación de la API de Prowlarr](https://prowlarr.com/docs/api/)
- [Wiki de Prowlarr](https://wiki.servarr.com/prowlarr)
