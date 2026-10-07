---
name: tautulli
description: Analíticas de uso de Plex a través de Tautulli. Úsala cuando el usuario pida "Tautulli", "analíticas de Plex", "estadísticas de visionado", "streams actuales", "historial de Plex", "lo más visto", "actividad de usuarios", "estadísticas de biblioteca", o mencione la monitorización de Plex con Tautulli.
---

# Skill de analíticas de Plex con Tautulli

**INVOCACIÓN OBLIGATORIA DE LA SKILL**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "Tautulli", "analíticas de Plex", "estadísticas de visionado"
- "streams actuales", "quién está viendo Plex", "sesiones activas"
- "historial de Plex", "historial de visionado", "historial de reproducción"
- "lo más visto", "contenido top", "contenido popular"
- "actividad de usuarios", "estadísticas de usuario", "estadísticas de biblioteca"
- "monitorización de Plex", "analíticas de streams", "tendencias de visionado"
- Cualquier mención de Tautulli o de analíticas de uso de Plex

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Consulta la actividad en curso, el historial de reproducción y las estadísticas de usuarios y bibliotecas a través de la API de Tautulli.

## Propósito

Esta skill da acceso de **solo lectura** a las analíticas de Tautulli:
- Ver la actividad en curso y los streams activos
- Consultar el historial de reproducción con filtros
- Consultar usuarios y su actividad
- Ver bibliotecas, contenido popular y añadidos recientemente
- Analizar el uso por hora, día, plataforma y tipo de stream
- Consultar los streams simultáneos y los metadatos de un elemento

No hay comandos de escritura. Complementa a la skill `plex`: `plex` da el estado en tiempo real y Tautulli el histórico.

## Configuración

Añade las credenciales al `.env` (raíz del repo):

```bash
TAUTULLI_URL="http://localhost:8181"
TAUTULLI_API_KEY="tu-api-key"
```

- `TAUTULLI_URL`: URL de Tautulli con puerto (sin barra final)
- `TAUTULLI_API_KEY`: clave de API de Tautulli (Settings → Web Interface → API; activa "Enable API")

## Comandos

Todos los comandos devuelven JSON con el sobre estándar de Tautulli (`response.result` y `response.data`), salvo `logs`, que devuelve un array JSON recortado. Sin comando muestra la ayuda (código 0); un comando desconocido la muestra por stderr y sale con 1. Si falta un argumento obligatorio, falta el valor de una opción, un valor numérico no es un número o hay una opción desconocida, imprime el uso por stderr y sale con 1. Si Tautulli responde con HTTP distinto de 2xx o con `result` igual a `error` (la API lo devuelve con HTTP 200), imprime `ERROR:` por stderr y sale con 1.

### Información del servidor

```bash
bash .claude/skills/tautulli/scripts/tautulli-api.sh server-info
```

**Salida:** JSON con la versión, el nombre y la dirección del servidor Plex conectado.

### Actividad en curso

```bash
bash .claude/skills/tautulli/scripts/tautulli-api.sh activity
```

**Salida:** JSON con los streams activos: usuario, contenido, reproductor, ancho de banda y transcodificación. No admite opciones.

### Historial de reproducción

```bash
bash .claude/skills/tautulli/scripts/tautulli-api.sh history
bash .claude/skills/tautulli/scripts/tautulli-api.sh history --user "usuario" --limit 50
bash .claude/skills/tautulli/scripts/tautulli-api.sh history --days 7 --media-type movie
bash .claude/skills/tautulli/scripts/tautulli-api.sh history --search "Inception"
```

**Salida:** JSON con `response.data.data`, una entrada por reproducción (25 por defecto). `--days` se traduce a `start_date` con formato `AAAA-MM-DD`.

### Estadísticas de usuarios

```bash
bash .claude/skills/tautulli/scripts/tautulli-api.sh user-stats
bash .claude/skills/tautulli/scripts/tautulli-api.sh user-stats --sort-by plays --limit 10
bash .claude/skills/tautulli/scripts/tautulli-api.sh user-stats --user "usuario"
```

**Salida:** JSON. Sin opciones devuelve la lista de usuarios (`get_users`). Con cualquier opción devuelve la tabla de usuarios (`get_users_table`) con reproducciones, duración y última vez visto. `--sort-by` acepta `plays`, `duration` o `last_seen` y ordena de mayor a menor. `--user` busca por texto. Para la actividad de un usuario en un periodo usa `history --user ... --days N`.

### Bibliotecas

```bash
bash .claude/skills/tautulli/scripts/tautulli-api.sh libraries
bash .claude/skills/tautulli/scripts/tautulli-api.sh library-stats --section-id 1
```

**Salida:** JSON. `libraries` lista las secciones; `library-stats` devuelve los datos de una sección (`--section-id` obligatorio y numérico).

### Contenido popular

```bash
bash .claude/skills/tautulli/scripts/tautulli-api.sh popular
bash .claude/skills/tautulli/scripts/tautulli-api.sh popular --media-type tv --days 30 --limit 10
bash .claude/skills/tautulli/scripts/tautulli-api.sh popular --section-id 1 --limit 10
```

**Salida:** JSON con `response.data.rows` (películas, series o artistas más reproducidos). `--media-type` selecciona la estadística: `movie` (por defecto) usa `popular_movies`, `tv` (o `show`, `episode`) usa `popular_tv` y `music` (o `track`) usa `popular_music`. Por defecto 30 días y 10 resultados.

### Añadidos recientemente

```bash
bash .claude/skills/tautulli/scripts/tautulli-api.sh recent
bash .claude/skills/tautulli/scripts/tautulli-api.sh recent --section-id 1 --limit 50
bash .claude/skills/tautulli/scripts/tautulli-api.sh recent --media-type movie --days 7
```

**Salida:** JSON con `response.data.recently_added` (25 por defecto). La API no filtra por fecha: con `--days` el script descarta localmente los elementos añadidos antes del corte, después de limitar a `--limit`.

### Estadísticas del panel

```bash
bash .claude/skills/tautulli/scripts/tautulli-api.sh home-stats --days 30
```

**Salida:** JSON con las tarjetas del panel principal (más popular, más activo, etc.). 30 días por defecto.

### Analíticas de reproducciones

```bash
bash .claude/skills/tautulli/scripts/tautulli-api.sh plays-by-stream --days 30
bash .claude/skills/tautulli/scripts/tautulli-api.sh plays-by-platform --days 30
bash .claude/skills/tautulli/scripts/tautulli-api.sh plays-by-date --days 30
bash .claude/skills/tautulli/scripts/tautulli-api.sh plays-by-hour --days 7
bash .claude/skills/tautulli/scripts/tautulli-api.sh plays-by-day --days 30
```

**Salida:** JSON con `categories` y `series` (reproducciones por tipo de stream, plataforma, fecha, hora del día o día de la semana). 30 días por defecto.

### Streams simultáneos

```bash
bash .claude/skills/tautulli/scripts/tautulli-api.sh concurrent-streams --days 30
bash .claude/skills/tautulli/scripts/tautulli-api.sh concurrent-streams --days 7 --peak
```

**Salida:** JSON con una serie por tipo de stream (Direct Play, Direct Stream, Transcode) y la serie "Max. Concurrent Streams", por día. Con `--peak` devuelve solo la serie "Max. Concurrent Streams".

### Metadatos

```bash
bash .claude/skills/tautulli/scripts/tautulli-api.sh metadata --rating-key 12345
bash .claude/skills/tautulli/scripts/tautulli-api.sh metadata --guid "plex://movie/5d776..."
```

**Salida:** JSON con los metadatos del elemento. Exige `--rating-key` (numérico) o `--guid`.

### Logs

```bash
bash .claude/skills/tautulli/scripts/tautulli-api.sh logs
bash .claude/skills/tautulli/scripts/tautulli-api.sh logs --plex --limit 100
```

**Salida:** array JSON con las primeras `n` entradas de `response.data` (25 por defecto), sin el sobre `response`. Con `--plex` lee el log del servidor Plex; si Tautulli no tiene configurada la carpeta de logs de Plex, el comando falla con `ERROR:` y código 1.

## Flujo de trabajo

Cuando el usuario pregunte por analíticas de Plex:

1. **"¿Quién está viendo ahora?"** → ejecuta `activity`
2. **"¿Qué es lo más visto?"** → ejecuta `popular --media-type movie --days 30` (y `--media-type tv` para series)
3. **"Historial reciente"** → ejecuta `history --limit 25`
4. **"¿Cuánto ha visto [usuario] esta semana?"** → ejecuta `history --user "usuario" --days 7`
5. **"¿Qué hay nuevo?"** → ejecuta `recent --limit 10`
6. **"¿A qué hora se ve más?"** → ejecuta `plays-by-hour --days 30`
7. **"¿Llegamos al límite de streams?"** → ejecuta `concurrent-streams --days 7 --peak`

Para extraer campos concretos, filtra con `jq`:

```bash
bash .claude/skills/tautulli/scripts/tautulli-api.sh history | jq '.response.data.data[] | {user: .friendly_name, title: .full_title, date: .date}'
```

## Parámetros

### Comando history
- `--user <usuario>`: filtra por usuario
- `--section-id <id>`: filtra por sección (numérico)
- `--media-type <tipo>`: `movie`, `episode`, `track`...
- `--days <n>`: últimos n días (numérico)
- `--limit <n>`: máximo de resultados (numérico; 25 por defecto)
- `--search <texto>`: busca en los títulos

### Comando user-stats
- `--user <texto>`: busca un usuario
- `--sort-by <plays|duration|last_seen>`: criterio de orden (descendente)
- `--limit <n>`: máximo de resultados (numérico)

### Comando popular
- `--media-type <movie|tv|music>`: tipo de estadística (`movie` por defecto)
- `--section-id <id>`: filtra por sección (numérico)
- `--days <n>`: periodo (numérico; 30 por defecto)
- `--limit <n>`: máximo de resultados (numérico; 10 por defecto)

### Comando recent
- `--section-id <id>`: filtra por sección (numérico)
- `--media-type <tipo>`: tipo de contenido
- `--days <n>`: solo los añadidos en los últimos n días (numérico)
- `--limit <n>`: máximo de resultados (numérico; 25 por defecto)

### Comando logs
- `--limit <n>`: máximo de líneas (numérico; 25 por defecto)
- `--plex`: lee el log del servidor Plex en lugar del de Tautulli

## Notas

- Requiere acceso de red al servidor de Tautulli, conectado a su vez a Plex
- Todas las operaciones son peticiones GET de solo lectura a `/api/v2`
- A diferencia de radarr y sonarr, todos los comandos devuelven JSON (y `logs` un array); no hay salida en texto
- Los errores salen por stderr con el prefijo `ERROR:`, también cuando Tautulli responde HTTP 200 con `result` igual a `error`
- Los ids de sección coinciden con las claves de sección de Plex
- Los datos históricos dependen de la retención configurada en Tautulli
- Para otro servidor Tautulli, sobrescribe `TAUTULLI_URL` y `TAUTULLI_API_KEY` en el entorno al llamar al script
- Esta skill no tiene comandos destructivos, así que el hook `confirm-destructive` no interviene

## Referencia

- [Referencia de la API de Tautulli](https://github.com/Tautulli/Tautulli/wiki/Tautulli-API-Reference)
- [Repositorio de Tautulli](https://github.com/Tautulli/Tautulli)
