# Referencia rápida de Plex Media Server

Operaciones comunes para copiar y pegar rápidamente.

## Configuración

### Variables de entorno (para curl directo)

```bash
export PLEX_URL="http://localhost:32400"
export PLEX_TOKEN="your-plex-token"
```

### Uso del script auxiliar (recomendado)

Añade a `~/.claude/plex-crew/.env`:
```bash
PLEX_URL="http://192.168.1.100:32400"
PLEX_TOKEN="your-plex-token"
```

El script auxiliar `skills/plex/scripts/plex-api.sh` simplifica el acceso a la API y gestiona la autenticación automáticamente.

## Cómo obtener tu token de Plex

### Desde Plex Web App

1. Abre Plex Web App
2. Settings → Account → desplázate hasta el final
3. Show Advanced → "Get Token"

### Mediante la API (si tienes las credenciales)

```bash
curl -X POST "https://plex.tv/users/sign_in.json" \
  -H "X-Plex-Client-Identifier: unique-client-id" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "user[login]=your-email@example.com&user[password]=yourpassword" | \
  jq -r '.user.authToken'
```

## Información del servidor

### Obtener la identidad del servidor

```bash
# Con el script auxiliar
./skills/plex/scripts/plex-api.sh identity | jq

# O con curl directo
curl -s "$PLEX_URL/identity" \
  -H "X-Plex-Token: $PLEX_TOKEN" | jq
```

### Obtener la información del servidor

```bash
# Con el script auxiliar
./skills/plex/scripts/plex-api.sh info | jq

# O con curl directo
curl -s "$PLEX_URL/" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

### Obtener las preferencias del servidor

```bash
# Con el script auxiliar
./skills/plex/scripts/plex-api.sh prefs | jq

# O con curl directo
curl -s "$PLEX_URL/:/prefs" \
  -H "X-Plex-Token: $PLEX_TOKEN" | jq
```

### Obtener el estado del servidor

```bash
# Con el script auxiliar
./skills/plex/scripts/plex-api.sh sessions | jq

# O con curl directo
curl -s "$PLEX_URL/status/sessions" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

## Gestión de bibliotecas

### Obtener todas las bibliotecas

```bash
# Con el script auxiliar
./skills/plex/scripts/plex-api.sh libraries | jq '.MediaContainer.Directory[] | {key, title, type}'

# O con curl directo
curl -s "$PLEX_URL/library/sections" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq '.MediaContainer.Directory[] | {key, title, type}'
```

### Obtener el contenido de una biblioteca

```bash
# Con el script auxiliar (sustituye 1 por la clave de tu biblioteca)
./skills/plex/scripts/plex-api.sh library 1 | jq '.MediaContainer.Metadata[] | {title, year, type}'
./skills/plex/scripts/plex-api.sh library 1 --limit 50 --offset 100

# O con curl directo
curl -s "$PLEX_URL/library/sections/LIBRARY_KEY/all" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq '.MediaContainer.Metadata[] | {title, year, type}'
```

### Obtener lo añadido recientemente

```bash
# Con el script auxiliar (por defecto: 20 elementos)
./skills/plex/scripts/plex-api.sh recent | jq
./skills/plex/scripts/plex-api.sh recent --limit 10

# O con curl directo
curl -s "$PLEX_URL/library/recentlyAdded" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

### Actualizar una biblioteca

```bash
# Con el script auxiliar
./skills/plex/scripts/plex-api.sh refresh 1

# O con curl directo
curl -s "$PLEX_URL/library/sections/LIBRARY_KEY/refresh" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

### Buscar archivos nuevos (forzado)

```bash
# Usa curl directo (la actualización forzada no está en el script auxiliar)
curl -s "$PLEX_URL/library/sections/LIBRARY_KEY/refresh?force=1" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

## Metadatos del contenido

### Obtener los detalles de una película o serie

```bash
# Con el script auxiliar (sustituye 12345 por la rating key)
./skills/plex/scripts/plex-api.sh metadata 12345 | jq

# O con curl directo
curl -s "$PLEX_URL/library/metadata/RATING_KEY" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

### Obtener los detalles de temporadas y episodios (hijos)

```bash
# Con el script auxiliar (obtiene las temporadas de una serie)
./skills/plex/scripts/plex-api.sh children 12345 | jq

# O con curl directo
curl -s "$PLEX_URL/library/metadata/RATING_KEY/children" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

### Buscar en todas las bibliotecas

```bash
# Con el script auxiliar
./skills/plex/scripts/plex-api.sh search "Inception" | jq
./skills/plex/scripts/plex-api.sh search "Marvel" --limit 5

# O con curl directo
curl -s "$PLEX_URL/search?query=inception" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

## Reproducción y sesiones

### Obtener las sesiones activas (reproduciendo ahora)

```bash
# Con el script auxiliar
./skills/plex/scripts/plex-api.sh sessions | jq '.MediaContainer.Metadata[] | {title, user: .User.title, player: .Player.title}'

# O con curl directo
curl -s "$PLEX_URL/status/sessions" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq '.MediaContainer.Metadata[] | {title, user: .User.title, player: .Player.title}'
```

### Obtener «Continuar viendo» (On Deck)

```bash
# Con el script auxiliar (por defecto: 10 elementos)
./skills/plex/scripts/plex-api.sh ondeck | jq
./skills/plex/scripts/plex-api.sh ondeck --limit 5

# O con curl directo
curl -s "$PLEX_URL/library/onDeck" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

### Listar los clientes conectados

```bash
# Con el script auxiliar
./skills/plex/scripts/plex-api.sh clients | jq

# O con curl directo
curl -s "$PLEX_URL/clients" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

### Obtener el historial de sesiones

```bash
curl -s "$PLEX_URL/status/sessions/history/all" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

### Detener una sesión de reproducción

```bash
# Obtén primero el ID de sesión de las sesiones activas
curl -X DELETE "$PLEX_URL/status/sessions/terminate?sessionId=SESSION_ID&reason=message" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

## Listas de reproducción

### Obtener todas las listas de reproducción

```bash
# Con el script auxiliar
./skills/plex/scripts/plex-api.sh playlists | jq '.MediaContainer.Metadata[] | {title, playlistType, leafCount}'

# O con curl directo
curl -s "$PLEX_URL/playlists" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq '.MediaContainer.Metadata[] | {title, playlistType, leafCount}'
```

### Obtener el contenido de una lista de reproducción

```bash
curl -s "$PLEX_URL/playlists/PLAYLIST_ID/items" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

### Crear una lista de reproducción

```bash
curl -X POST "$PLEX_URL/playlists?type=video&title=My%20Playlist&smart=0&uri=server://MACHINE_ID/com.plexapp.plugins.library/library/metadata/RATING_KEY" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

## Usuarios y uso compartido

### Obtener los usuarios (Plex Home)

```bash
# Con el script auxiliar (solo administrador)
./skills/plex/scripts/plex-api.sh accounts | jq

# O con curl directo
curl -s "$PLEX_URL/accounts" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

### Obtener los servidores compartidos

```bash
curl -s "https://plex.tv/api/v2/shared_servers" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

## Webhooks

### Obtener la configuración de webhooks

```bash
curl -s "$PLEX_URL/:/prefs" \
  -H "X-Plex-Token: $PLEX_TOKEN" | grep webhook
```

## Mantenimiento

### Vaciar la papelera de una biblioteca

```bash
curl -X PUT "$PLEX_URL/library/sections/LIBRARY_KEY/emptyTrash" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

### Limpiar los bundles

```bash
curl -X PUT "$PLEX_URL/library/clean/bundles" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

### Optimizar la base de datos

```bash
curl -X PUT "$PLEX_URL/library/optimize" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

## Transcodificación

### Obtener las sesiones de transcodificación

```bash
curl -s "$PLEX_URL/transcode/sessions" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq
```

### Terminar una sesión de transcodificación

```bash
curl -X DELETE "$PLEX_URL/transcode/sessions/TRANSCODE_SESSION_KEY" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

## Flujos de trabajo

### Flujo de trabajo: obtener estadísticas de las bibliotecas

```bash
# Obtiene todas las bibliotecas
libraries=$(curl -s "$PLEX_URL/library/sections" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq -r '.MediaContainer.Directory[] | "\(.key)|\(.title)|\(.type)"')

# Cuenta los elementos de cada biblioteca
echo "$libraries" | while IFS='|' read key title type; do
  count=$(curl -s "$PLEX_URL/library/sections/$key/all" \
    -H "X-Plex-Token: $PLEX_TOKEN" \
    -H "Accept: application/json" | jq '.MediaContainer.size')

  echo "$title ($type): $count items"
done
```

### Flujo de trabajo: encontrar películas sin ver

```bash
curl -s "$PLEX_URL/library/sections/LIBRARY_KEY/unwatched" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq '.MediaContainer.Metadata[] | {title, year, addedAt}'
```

### Flujo de trabajo: obtener el contenido más reproducido

```bash
curl -s "$PLEX_URL/library/sections/LIBRARY_KEY/all?sort=viewCount:desc&limit=10" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq '.MediaContainer.Metadata[] | {title, viewCount}'
```

### Flujo de trabajo: actualizar todas las bibliotecas

```bash
curl -s "$PLEX_URL/library/sections" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq -r '.MediaContainer.Directory[].key' | \
  while read library_key; do
    echo "Refreshing library $library_key"
    curl -s "$PLEX_URL/library/sections/$library_key/refresh" \
      -H "X-Plex-Token: $PLEX_TOKEN"
    sleep 2
  done
```

### Flujo de trabajo: monitorizar las reproducciones activas

```bash
while true; do
  clear
  echo "Active Plex Streams ($(date))"
  echo "================================"

  curl -s "$PLEX_URL/status/sessions" \
    -H "X-Plex-Token: $PLEX_TOKEN" \
    -H "Accept: application/json" | \
    jq -r '.MediaContainer.Metadata[]? | "User: \(.User.title)\nTitle: \(.title)\nPlayer: \(.Player.title)\nState: \(.Player.state)\n"'

  sleep 10
done
```

### Flujo de trabajo: obtener lo añadido recientemente en todas las bibliotecas

```bash
curl -s "$PLEX_URL/library/recentlyAdded" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq '.MediaContainer.Metadata[] | {title, type, addedAt}'
```

### Flujo de trabajo: marcar un elemento como visto

```bash
curl -X POST "$PLEX_URL/:/scrobble?identifier=com.plexapp.plugins.library&key=RATING_KEY" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

### Flujo de trabajo: marcar un elemento como no visto

```bash
curl -X POST "$PLEX_URL/:/unscrobble?identifier=com.plexapp.plugins.library&key=RATING_KEY" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

### Flujo de trabajo: obtener On Deck (Continuar viendo)

```bash
curl -s "$PLEX_URL/library/onDeck" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | jq '.MediaContainer.Metadata[] | {title, viewOffset}'
```

### Flujo de trabajo: copia de seguridad de la base de datos

```bash
# Detén Plex primero (si es posible)
# Después copia la base de datos
cp "$PLEX_DATA_DIR/Plug-in Support/Databases/com.plexapp.plugins.library.db" \
   "$PLEX_DATA_DIR/Plug-in Support/Databases/com.plexapp.plugins.library.db.backup-$(date +%Y%m%d)"

# O usa la copia de seguridad integrada de Plex
curl -X POST "$PLEX_URL/butler/StartBackup" \
  -H "X-Plex-Token: $PLEX_TOKEN"
```

### Flujo de trabajo: limpiar contenido antiguo

```bash
# Busca elementos no vistos desde hace más de 1 año
cutoff_date=$(date -d '1 year ago' +%s)

curl -s "$PLEX_URL/library/sections/LIBRARY_KEY/all" \
  -H "X-Plex-Token: $PLEX_TOKEN" \
  -H "Accept: application/json" | \
  jq --arg cutoff "$cutoff_date" -r '.MediaContainer.Metadata[] | select(.lastViewedAt != null and (.lastViewedAt | tonumber) < ($cutoff | tonumber)) | {title, lastViewedAt, ratingKey}'
```

## Filtros y ordenación comunes

### Filtrar por no visto

```
?unwatched=1
```

### Filtrar por género

```
?genre=1234  # Obtén primero los ID de género de la biblioteca
```

### Ordenar por fecha de adición (más recientes primero)

```
?sort=addedAt:desc
```

### Ordenar por valoración

```
?sort=rating:desc
```

### Limitar los resultados

```
?limit=10
```
