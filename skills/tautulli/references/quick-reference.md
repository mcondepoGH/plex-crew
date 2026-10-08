# Referencia rápida de Tautulli

Comandos listos para copiar y pegar para las operaciones habituales de Tautulli.

## Configuración

```bash
# Añadir a ~/.claude/plex-crew/.env
TAUTULLI_URL="http://192.168.1.100:8181"
TAUTULLI_API_KEY="<your_api_key>"

# Ir al directorio de la skill
cd skills/tautulli
```

## Comandos rápidos

### Comprobar el estado del servidor

```bash
# Información y versión del servidor
./scripts/tautulli-api.sh server-info
```

### Actividad actual

```bash
# Quién está viendo algo ahora mismo
./scripts/tautulli-api.sh activity

# Actividad con información detallada de las sesiones
./scripts/tautulli-api.sh activity --details
```

### Historial de reproducción

```bash
# Últimas 25 reproducciones
./scripts/tautulli-api.sh history

# Últimas 50 reproducciones
./scripts/tautulli-api.sh history --limit 50

# Historial de un usuario concreto
./scripts/tautulli-api.sh history --user "john"

# Historial de la última semana
./scripts/tautulli-api.sh history --days 7

# Solo películas
./scripts/tautulli-api.sh history --media-type movie

# Buscar un título concreto
./scripts/tautulli-api.sh history --search "Inception"

# Combinar filtros
./scripts/tautulli-api.sh history --user "john" --media-type episode --days 30 --limit 100
```

### Estadísticas de usuarios

```bash
# Todos los usuarios con sus estadísticas
./scripts/tautulli-api.sh user-stats

# Usuario concreto
./scripts/tautulli-api.sh user-stats --user "john"

# Los 10 usuarios más activos
./scripts/tautulli-api.sh user-stats --sort-by plays --limit 10

# Actividad de los últimos 30 días
./scripts/tautulli-api.sh user-stats --days 30
```

### Bibliotecas

```bash
# Listar todas las secciones de biblioteca
./scripts/tautulli-api.sh libraries

# Estadísticas de una biblioteca concreta (sustituye 1 por el ID de tu sección)
./scripts/tautulli-api.sh library-stats --section-id 1
```

### Contenido popular

```bash
# Películas más populares
./scripts/tautulli-api.sh popular --media-type movie --limit 10

# Lo más visto en los últimos 30 días
./scripts/tautulli-api.sh popular --days 30 --limit 20

# Popular en una biblioteca concreta
./scripts/tautulli-api.sh popular --section-id 1 --days 7
```

### Añadido recientemente

```bash
# Últimas 25 incorporaciones
./scripts/tautulli-api.sh recent

# Últimas 50 incorporaciones
./scripts/tautulli-api.sh recent --limit 50

# Solo películas recientes
./scripts/tautulli-api.sh recent --media-type movie

# Incorporaciones de la última semana de una biblioteca concreta
./scripts/tautulli-api.sh recent --section-id 1 --days 7
```

### Estadísticas de inicio

```bash
# Estadísticas del panel de resumen
./scripts/tautulli-api.sh home-stats

# Resumen de los últimos 30 días
./scripts/tautulli-api.sh home-stats --days 30

# Resumen de los últimos 7 días
./scripts/tautulli-api.sh home-stats --days 7
```

### Analítica de streams

```bash
# Tipos de stream (direct play frente a transcode)
./scripts/tautulli-api.sh plays-by-stream --days 30

# Distribución por plataforma
./scripts/tautulli-api.sh plays-by-platform --days 30

# Reproducciones por fecha
./scripts/tautulli-api.sh plays-by-date --days 30

# Reproducciones por hora del día
./scripts/tautulli-api.sh plays-by-hour --days 7

# Reproducciones por día de la semana
./scripts/tautulli-api.sh plays-by-day --days 30
```

### Streams simultáneos

```bash
# Historial de streams simultáneos
./scripts/tautulli-api.sh concurrent-streams --days 30

# Pico de streams simultáneos
./scripts/tautulli-api.sh concurrent-streams --days 7 --peak
```

### Metadatos multimedia

```bash
# Por rating key de Plex
./scripts/tautulli-api.sh metadata --rating-key 12345

# Por GUID de Plex
./scripts/tautulli-api.sh metadata --guid "plex://movie/5d776..."
```

## Procesar la salida con jq

### Extraer campos concretos

```bash
# Obtener solo la sección data
./scripts/tautulli-api.sh activity | jq '.response.data'

# Obtener el número de sesiones
./scripts/tautulli-api.sh activity | jq '.response.data.stream_count'

# Listar los usuarios activos
./scripts/tautulli-api.sh activity | jq '.response.data.sessions[].friendly_name'

# Obtener los títulos y fechas del historial
./scripts/tautulli-api.sh history | jq '.response.data.data[] | {title: .full_title, date: .date, user: .friendly_name}'
```

### Filtrar resultados

```bash
# Solo sesiones con transcodificación
./scripts/tautulli-api.sh activity | jq '.response.data.sessions[] | select(.transcode_decision == "transcode")'

# Películas vistas por el usuario
./scripts/tautulli-api.sh history --user "john" | jq '.response.data.data[] | select(.media_type == "movie") | .full_title'

# Incorporaciones recientes de las últimas 24 horas
./scripts/tautulli-api.sh recent | jq --arg cutoff "$(date -d '1 day ago' +%s)" '.response.data.recently_added[] | select(.added_at > ($cutoff | tonumber))'
```

### Dar formato a la salida

```bash
# Mostrar la respuesta completa con formato legible
./scripts/tautulli-api.sh activity | jq '.'

# Salida compacta (una línea)
./scripts/tautulli-api.sh activity | jq -c '.'

# Formato CSV para el historial
./scripts/tautulli-api.sh history | jq -r '.response.data.data[] | [.date, .friendly_name, .full_title, .percent_complete] | @csv'

# Formato de tabla
./scripts/tautulli-api.sh user-stats | jq -r '.response.data[] | "\(.friendly_name)\t\(.plays)\t\(.duration)"'
```

### Estadísticas y agregación

```bash
# Total de reproducciones del historial
./scripts/tautulli-api.sh history --limit 1000 | jq '.response.data.recordsTotal'

# Recuento por tipo de contenido
./scripts/tautulli-api.sh history --limit 100 | jq '.response.data.data | group_by(.media_type) | map({type: .[0].media_type, count: length})'

# Porcentaje medio de visionado
./scripts/tautulli-api.sh history --limit 100 | jq '[.response.data.data[].percent_complete] | add / length'

# Suma de todo el tiempo de visionado (segundos)
./scripts/tautulli-api.sh user-stats | jq '[.response.data[].duration] | add'
```

## Flujos de trabajo habituales

### Comprobar quién está viendo algo

```bash
# Lista simple de los usuarios actuales
./scripts/tautulli-api.sh activity | jq -r '.response.data.sessions[] | "\(.friendly_name) - \(.full_title)"'

# Información detallada de las sesiones
./scripts/tautulli-api.sh activity | jq '.response.data.sessions[] | {user: .friendly_name, title: .full_title, player: .player, progress: .progress_percent}'
```

### Encontrar los usuarios más activos de esta semana

```bash
./scripts/tautulli-api.sh user-stats --days 7 --sort-by plays --limit 10 | jq '.response.data[] | {name: .friendly_name, plays: .plays, hours: (.duration / 3600 | floor)}'
```

### Listar las incorporaciones recientes sin ver

```bash
# Obtener las incorporaciones recientes
./scripts/tautulli-api.sh recent --limit 50 | jq -r '.response.data.recently_added[] | .rating_key' > recent_keys.txt

# Para cada una, comprobar si tiene historial de reproducción
while read key; do
    plays=$(./scripts/tautulli-api.sh history --limit 1000 | jq ".response.data.data[] | select(.rating_key == \"$key\") | .rating_key" | wc -l)
    if [ "$plays" -eq 0 ]; then
        title=$(./scripts/tautulli-api.sh metadata --rating-key "$key" | jq -r '.response.data.full_title')
        echo "Unwatched: $title"
    fi
done < recent_keys.txt
```

### Generar un informe semanal

```bash
#!/bin/bash
# Informe semanal de actividad

echo "=== Tautulli Weekly Report ==="
echo

echo "Top 5 Users:"
./scripts/tautulli-api.sh user-stats --days 7 --sort-by plays --limit 5 | \
    jq -r '.response.data[] | "\(.friendly_name): \(.plays) plays, \((.duration / 3600) | floor) hours"'

echo
echo "Most Popular Movies:"
./scripts/tautulli-api.sh popular --media-type movie --days 7 --limit 5 | \
    jq -r '.response.data[0].rows[] | "\(.title) (\(.year)): \(.total_plays) plays"'

echo
echo "Peak Viewing Times:"
./scripts/tautulli-api.sh plays-by-hour --days 7 | \
    jq -r '.response.data.series[0] | .data | to_entries | sort_by(.value) | reverse | .[0:3][] | "Hour \(.key): \(.value) plays"'
```

### Monitorizar la carga de transcodificación

```bash
#!/bin/bash
# Comprobar si hay transcodificación y de quién

transcodes=$(./scripts/tautulli-api.sh activity | \
    jq '.response.data.sessions[] | select(.transcode_decision == "transcode")')

count=$(echo "$transcodes" | jq -s 'length')

if [ "$count" -gt 0 ]; then
    echo "⚠️  $count active transcodes:"
    echo "$transcodes" | jq -r '"\(.friendly_name) - \(.full_title) (\(.video_decision))"'
else
    echo "✅ No active transcodes"
fi
```

### Encontrar el contenido favorito de un usuario

```bash
#!/bin/bash
# Encontrar lo que más ve un usuario

USER="john"

echo "Top movies watched by $USER:"
./scripts/tautulli-api.sh history --user "$USER" --media-type movie --limit 500 | \
    jq -r '.response.data.data[] | .full_title' | sort | uniq -c | sort -rn | head -10

echo
echo "Top shows watched by $USER:"
./scripts/tautulli-api.sh history --user "$USER" --media-type episode --limit 500 | \
    jq -r '.response.data.data[] | .grandparent_title' | sort | uniq -c | sort -rn | head -10
```

## Llamadas directas a la API (avanzado)

Si necesitas llamar a la API directamente, sin el script auxiliar:

```bash
# Estructura básica
curl -s "${TAUTULLI_URL}/api/v2?apikey=${TAUTULLI_API_KEY}&cmd=COMMAND&param=value"

# Obtener la actividad
curl -s "${TAUTULLI_URL}/api/v2?apikey=${TAUTULLI_API_KEY}&cmd=get_activity" | jq '.'

# Obtener el historial con parámetros
curl -s "${TAUTULLI_URL}/api/v2?apikey=${TAUTULLI_API_KEY}&cmd=get_history&user=john&length=50" | jq '.'

# Codificar en la URL los espacios y los caracteres especiales
QUERY=$(echo "Star Wars" | jq -sRr @uri)
curl -s "${TAUTULLI_URL}/api/v2?apikey=${TAUTULLI_API_KEY}&cmd=get_history&search=${QUERY}" | jq '.'
```

## Alias útiles

Añade a tu `~/.bashrc` o `~/.zshrc`:

```bash
# Atajos de Tautulli
alias tautulli='cd skills/tautulli && ./scripts/tautulli-api.sh'
alias tautulli-activity='tautulli activity | jq ".response.data.sessions[] | {user: .friendly_name, title: .full_title, progress: .progress_percent}"'
alias tautulli-history='tautulli history | jq -r ".response.data.data[] | \"\(.date | strftime(\"%Y-%m-%d %H:%M\")) - \(.friendly_name) - \(.full_title)\""'
alias tautulli-users='tautulli user-stats | jq -r ".response.data[] | \"\(.friendly_name): \(.plays) plays\""'
```

Después, úsalos:
```bash
tautulli-activity
tautulli-history
tautulli-users
```

## Consejos

1. **Combina filtros** para obtener resultados precisos: `--user "name" --media-type movie --days 7`
2. **Usa jq para mayor claridad**: es más fácil de leer que el JSON sin procesar
3. **Guarda las consultas frecuentes** como funciones de shell o scripts
4. **Comprueba recordsTotal** en el historial para saber si necesitas paginación
5. **Usa --limit con criterio**: los límites grandes ralentizan las consultas
6. **Guarda en caché los IDs de biblioteca**: rara vez cambian
7. **Los rangos de tiempo más cortos** (--days) son más rápidos
8. **Prueba con límites pequeños** antes de ejecutar consultas grandes
