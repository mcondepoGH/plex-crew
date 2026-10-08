# Referencia de endpoints de la API de Tautulli

Referencia completa de todos los endpoints de la API v2 de Tautulli usados en esta skill.

## URL base de la API

```
http://<your_tautulli_url>/api/v2?apikey=<your_api_key>&cmd=COMMAND&param=value
```

Todas las peticiones son GET, con los parámetros en la cadena de consulta.

## Autenticación

Añade `apikey=<your_api_key>` a todas las peticiones. La clave de API se encuentra en:
- Settings → Web Interface → API → API Key

## Formato de respuesta

El formato por defecto es JSON. Todas las respuestas siguen esta estructura:

```json
{
  "response": {
    "result": "success",
    "message": null,
    "data": { ... }
  }
}
```

**Respuesta correcta:**
- `result`: "success"
- `data`: datos de la respuesta (varían según el endpoint)
- `message`: null o mensaje informativo

**Respuesta de error:**
- `result`: "error"
- `message`: descripción del error
- `data`: null o detalles del error

## Información del servidor

### get_server_info

Obtiene la información y la versión del servidor Tautulli.

**Endpoint:** `cmd=get_server_info`

**Parámetros:** ninguno

**Respuesta:**
```json
{
  "response": {
    "result": "success",
    "data": {
      "tautulli_version": "2.13.4",
      "pms_identifier": "abc123...",
      "pms_name": "MyPlexServer",
      "pms_version": "1.32.5.7349",
      "pms_platform": "Linux",
      "pms_ip": "192.168.1.100",
      "pms_port": "32400",
      "pms_is_remote": 0,
      "pms_ssl": 0
    }
  }
}
```

## Actividad y sesiones

### get_activity

Obtiene la actividad actual de Plex Media Server con el detalle de las sesiones.

**Endpoint:** `cmd=get_activity`

**Parámetros:** ninguno

**Respuesta:**
```json
{
  "response": {
    "result": "success",
    "data": {
      "stream_count": "2",
      "stream_count_direct_play": 1,
      "stream_count_direct_stream": 0,
      "stream_count_transcode": 1,
      "total_bandwidth": 12500,
      "lan_bandwidth": 8000,
      "wan_bandwidth": 4500,
      "sessions": [
        {
          "session_key": "123",
          "session_id": "abc123",
          "media_type": "movie",
          "user": "john",
          "friendly_name": "John Smith",
          "full_title": "Inception (2010)",
          "title": "Inception",
          "year": "2010",
          "rating_key": "12345",
          "parent_rating_key": "",
          "grandparent_rating_key": "",
          "player": "Plex Web",
          "product": "Plex Web",
          "platform": "Chrome",
          "device": "PC",
          "location": "lan",
          "quality_profile": "Original",
          "stream_container": "mkv",
          "stream_video_codec": "h264",
          "stream_audio_codec": "aac",
          "transcode_decision": "direct play",
          "video_decision": "direct play",
          "audio_decision": "direct play",
          "bandwidth": 8000,
          "progress_percent": 45,
          "view_offset": 2700000,
          "duration": 6000000
        }
      ]
    }
  }
}
```

## Historial

### get_history

Obtiene el historial de reproducción con filtrado detallado.

**Endpoint:** `cmd=get_history`

**Parámetros:**
- `user` (string): filtra por nombre de usuario
- `user_id` (int): filtra por ID de usuario
- `section_id` (int): filtra por sección de biblioteca
- `media_type` (string): movie, episode, track, photo
- `rating_key` (int): filtra por un elemento multimedia concreto
- `start_date` (timestamp): historial posterior a esta fecha (marca de tiempo Unix)
- `before` (timestamp): historial anterior a esta fecha (marca de tiempo Unix)
- `search` (string): búsqueda en los títulos
- `order_column` (string): columna de ordenación (date, friendly_name, full_title, etc.)
- `order_dir` (string): desc o asc
- `start` (int): desplazamiento de paginación (por defecto: 0)
- `length` (int): número de resultados (por defecto: 25)

**Respuesta:**
```json
{
  "response": {
    "result": "success",
    "data": {
      "recordsFiltered": 1234,
      "recordsTotal": 1234,
      "draw": 1,
      "data": [
        {
          "date": 1704156789,
          "friendly_name": "John Smith",
          "user": "john",
          "user_id": 123456,
          "media_type": "movie",
          "rating_key": "12345",
          "parent_rating_key": "",
          "grandparent_rating_key": "",
          "full_title": "Inception (2010)",
          "title": "Inception",
          "year": "2010",
          "section_id": 1,
          "library_name": "Movies",
          "player": "Plex Web",
          "platform": "Chrome",
          "product": "Plex Web",
          "quality_profile": "Original",
          "stream_video_codec": "h264",
          "stream_audio_codec": "aac",
          "transcode_decision": "direct play",
          "percent_complete": 98,
          "watched_status": 1,
          "started": 1704150000,
          "stopped": 1704156789,
          "duration": 6789,
          "paused_counter": 2,
          "ip_address": "192.168.1.50"
        }
      ]
    }
  }
}
```

## Estadísticas de usuarios

### get_users

Obtiene la lista de todos los usuarios con estadísticas básicas.

**Endpoint:** `cmd=get_users`

**Parámetros:** ninguno

**Respuesta:**
```json
{
  "response": {
    "result": "success",
    "data": [
      {
        "user_id": 123456,
        "username": "john",
        "friendly_name": "John Smith",
        "email": "john@example.com",
        "thumb": "/path/to/avatar.jpg",
        "is_home_user": 1,
        "is_allow_sync": 1,
        "is_restricted": 0,
        "do_notify": 1,
        "keep_history": 1,
        "deleted_user": 0,
        "allow_guest": 0,
        "user_thumb": "/path/to/thumb.jpg",
        "last_seen": 1704156789,
        "ip_address": "192.168.1.50",
        "plays": 1234,
        "duration": 456789
      }
    ]
  }
}
```

### get_user_stats

Obtiene estadísticas detalladas de un usuario concreto.

**Endpoint:** `cmd=get_user_stats`

**Parámetros:**
- `user` (string): nombre de usuario (opcional; si se omite, todos los usuarios)
- `user_id` (int): ID de usuario (alternativa a user)
- `start_date` (timestamp): estadísticas posteriores a esta fecha
- `order_column` (string): columna de ordenación (plays, duration, last_seen)
- `order_dir` (string): desc o asc
- `length` (int): número de resultados

**Respuesta:** similar a get_users, pero con desgloses más detallados por tipo de contenido.

## Información de bibliotecas

### get_libraries

Obtiene todas las secciones de biblioteca.

**Endpoint:** `cmd=get_libraries`

**Parámetros:** ninguno

**Respuesta:**
```json
{
  "response": {
    "result": "success",
    "data": [
      {
        "section_id": "1",
        "section_name": "Movies",
        "section_type": "movie",
        "thumb": "/path/to/thumb.jpg",
        "art": "/path/to/art.jpg",
        "count": 1234,
        "parent_count": 0,
        "child_count": 0,
        "is_active": 1,
        "do_notify": 1,
        "do_notify_created": 1,
        "keep_history": 1
      }
    ]
  }
}
```

### get_library

Obtiene estadísticas detalladas de una sección de biblioteca concreta.

**Endpoint:** `cmd=get_library`

**Parámetros:**
- `section_id` (int, obligatorio): ID de la sección de biblioteca

**Respuesta:**
```json
{
  "response": {
    "result": "success",
    "data": {
      "section_id": "1",
      "section_name": "Movies",
      "section_type": "movie",
      "count": 1234,
      "child_count": 0,
      "parent_count": 0,
      "plays": 5678,
      "duration": 1234567,
      "last_accessed": 1704156789,
      "last_played": "Inception (2010)",
      "library_art": "/path/to/art.jpg",
      "library_thumb": "/path/to/thumb.jpg"
    }
  }
}
```

## Información multimedia

### get_recently_added

Obtiene los elementos multimedia añadidos recientemente.

**Endpoint:** `cmd=get_recently_added`

**Parámetros:**
- `count` (int): número de resultados (por defecto: 25)
- `start` (int): desplazamiento de paginación
- `section_id` (int): filtra por sección de biblioteca
- `media_type` (string): movie, show, artist

**Respuesta:**
```json
{
  "response": {
    "result": "success",
    "data": {
      "recently_added": [
        {
          "added_at": "1704156789",
          "media_type": "movie",
          "section_id": "1",
          "library_name": "Movies",
          "rating_key": "12345",
          "parent_rating_key": "",
          "grandparent_rating_key": "",
          "title": "Dune",
          "year": "2021",
          "thumb": "/library/metadata/12345/thumb/...",
          "parent_thumb": "",
          "grandparent_thumb": "",
          "art": "/library/metadata/12345/art/...",
          "originally_available_at": "2021-10-22",
          "guid": "plex://movie/5d77...",
          "content_rating": "PG-13",
          "summary": "Feature adaptation of Frank Herbert's science fiction novel...",
          "tagline": "",
          "rating": "8.0",
          "duration": 9360000,
          "file": "/path/to/movie.mkv",
          "container": "mkv",
          "bitrate": 15000,
          "video_codec": "hevc",
          "video_resolution": "1080",
          "video_framerate": "24p",
          "audio_codec": "aac",
          "audio_channels": "5.1"
        }
      ]
    }
  }
}
```

### get_metadata

Obtiene los metadatos detallados de un elemento multimedia concreto.

**Endpoint:** `cmd=get_metadata`

**Parámetros:**
- `rating_key` (int): rating key de Plex (obligatorio si no se indica guid)
- `guid` (string): GUID de Plex (obligatorio si no se indica rating_key)

**Respuesta:** metadatos extensos que incluyen reparto, géneros, detalles técnicos, etc.

## Estadísticas y analítica

### get_home_stats

Obtiene las estadísticas de la página de inicio (datos del panel de resumen).

**Endpoint:** `cmd=get_home_stats`

**Parámetros:**
- `time_range` (int): días a incluir (por defecto: 30)
- `stats_type` (string): plays o duration
- `stat_id` (string): estadística concreta (popular_movies, popular_tv, popular_music)

**Respuesta:**
```json
{
  "response": {
    "result": "success",
    "data": [
      {
        "stat_id": "popular_movies",
        "stat_type": "popular",
        "stat_title": "Most Popular Movies",
        "rows": [
          {
            "title": "Inception",
            "total_plays": 45,
            "total_duration": 123456,
            "users_watched": "John, Jane, Bob",
            "rating_key": "12345",
            "grandparent_thumb": "",
            "thumb": "/library/metadata/12345/thumb/...",
            "art": "/library/metadata/12345/art/...",
            "section_id": 1,
            "media_type": "movie",
            "content_rating": "PG-13",
            "labels": [],
            "user": "",
            "friendly_name": "",
            "platform": "",
            "row_id": 12345,
            "year": "2010"
          }
        ]
      }
    ]
  }
}
```

### get_plays_by_date

Obtiene las reproducciones agrupadas por fecha.

**Endpoint:** `cmd=get_plays_by_date`

**Parámetros:**
- `time_range` (int): días a incluir (por defecto: 30)
- `y_axis` (string): plays o duration
- `user_id` (int): filtra por usuario
- `grouping` (int): nivel de agrupación (0=día, 1=semana, 2=mes)

**Respuesta:**
```json
{
  "response": {
    "result": "success",
    "data": {
      "categories": ["2024-01-01", "2024-01-02", "2024-01-03"],
      "series": [
        {
          "name": "TV",
          "data": [12, 15, 18]
        },
        {
          "name": "Movies",
          "data": [8, 10, 7]
        },
        {
          "name": "Music",
          "data": [45, 50, 42]
        }
      ]
    }
  }
}
```

### get_plays_by_hourofday

Obtiene las reproducciones agrupadas por hora del día.

**Endpoint:** `cmd=get_plays_by_hourofday`

**Parámetros:**
- `time_range` (int): días a incluir (por defecto: 30)
- `y_axis` (string): plays o duration
- `user_id` (int): filtra por usuario

**Respuesta:** similar a get_plays_by_date, con las horas 0-23 como categorías.

### get_plays_by_dayofweek

Obtiene las reproducciones agrupadas por día de la semana.

**Endpoint:** `cmd=get_plays_by_dayofweek`

**Parámetros:**
- `time_range` (int): días a incluir (por defecto: 30)
- `y_axis` (string): plays o duration
- `user_id` (int): filtra por usuario

**Respuesta:** similar a get_plays_by_date, con los días (Mon-Sun) como categorías.

### get_plays_by_stream_type

Obtiene las reproducciones agrupadas por tipo de stream (direct play, direct stream, transcode).

**Endpoint:** `cmd=get_plays_by_stream_type`

**Parámetros:**
- `time_range` (int): días a incluir (por defecto: 30)
- `y_axis` (string): plays o duration
- `user_id` (int): filtra por usuario

**Respuesta:**
```json
{
  "response": {
    "result": "success",
    "data": {
      "categories": ["Direct Play", "Direct Stream", "Transcode"],
      "series": [
        {
          "name": "TV",
          "data": [120, 30, 15]
        },
        {
          "name": "Movies",
          "data": [80, 10, 5]
        }
      ]
    }
  }
}
```

### get_plays_by_top_10_platforms

Obtiene las reproducciones por las principales plataformas/dispositivos.

**Endpoint:** `cmd=get_plays_by_top_10_platforms`

**Parámetros:**
- `time_range` (int): días a incluir (por defecto: 30)
- `y_axis` (string): plays o duration
- `user_id` (int): filtra por usuario

**Respuesta:**
```json
{
  "response": {
    "result": "success",
    "data": {
      "categories": ["Plex Web", "Roku", "Apple TV", "iOS", "Android"],
      "series": [
        {
          "name": "Plays",
          "data": [120, 89, 67, 45, 23]
        }
      ]
    }
  }
}
```

### get_concurrent_streams_by_stream_type

Obtiene el número de streams simultáneos a lo largo del tiempo por tipo de stream.

**Endpoint:** `cmd=get_concurrent_streams_by_stream_type`

**Parámetros:**
- `time_range` (int): días a incluir (por defecto: 30)
- `y_axis` (string): concurrent
- `user_id` (int): filtra por usuario

**Respuesta:** datos de series temporales con el número de streams simultáneos.

## Parámetros comunes

La mayoría de los endpoints admiten estos parámetros estándar:

- `out_type` (string): json o xml (por defecto: json)
- `order_column` (string): columna por la que ordenar
- `order_dir` (string): desc o asc (por defecto: desc)
- `start` (int): desplazamiento de paginación (por defecto: 0)
- `length` (int): número de resultados (por defecto: 25)
- `user_id` (int): filtra por ID de usuario
- `section_id` (int): filtra por ID de sección de biblioteca
- `time_range` (int): días a incluir en las estadísticas
- `callback` (string): función de callback JSONP
- `debug` (bool): incluye información de depuración

## Respuestas de error

Cuando se produce un error, la respuesta tiene `result: "error"`:

```json
{
  "response": {
    "result": "error",
    "message": "Invalid apikey",
    "data": null
  }
}
```

Errores habituales:
- `Invalid apikey`: la clave de API es incorrecta o falta
- `Invalid parameter`: falta un parámetro obligatorio o no es válido
- `No section_id provided`: se requiere el ID de la sección de biblioteca pero no se ha indicado
- `Failed to retrieve data`: error de la base de datos o del servidor Plex

## Límite de peticiones

Tautulli no aplica límites de peticiones por defecto, pero:
- Evita el sondeo excesivo (recomendado: máximo 1 petición/segundo)
- Usa rangos de tiempo razonables para las estadísticas
- Almacena en caché los resultados cuando proceda
- Usa paginación en los conjuntos de resultados grandes

## Buenas prácticas

1. **Comprueba siempre el campo `result`** antes de procesar los datos
2. **Gestiona con elegancia los datos ausentes** (valores null, arrays vacíos)
3. **Usa filtros específicos** para reducir el tamaño de la respuesta
4. **Almacena en caché los datos de acceso frecuente** (lista de bibliotecas, lista de usuarios)
5. **Usa paginación** en las consultas de historial
6. **Rangos de tiempo razonables** para las estadísticas (normalmente 7-30 días)
7. **Codifica los parámetros en la URL**, especialmente las consultas de búsqueda
8. **Comprueba la versión de Tautulli** para saber qué funciones están disponibles

## Referencia

- [Documentación oficial de la API de Tautulli](https://github.com/Tautulli/Tautulli/wiki/Tautulli-API-Reference)
- [Tautulli en GitHub](https://github.com/Tautulli/Tautulli)
