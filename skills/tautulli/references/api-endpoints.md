# Endpoints de la API de Tautulli usados por el script

## Base

- URL: `<TAUTULLI_URL>/api/v2`, método GET
- Parámetros fijos: `apikey` (clave), `cmd` (comando de la API) y `out_type=json`
- Los valores se codifican en la URL; la clave nunca se imprime
- Timeouts: 10 s de conexión, 30 s en total

## Envoltorio de respuesta

```json
{
  "response": {
    "result": "success",
    "message": null,
    "data": {}
  }
}
```

- `result`: `success` o `error`; el script falla con rc 1 si no es `success`
- `message`: texto del error (por ejemplo, clave inválida)
- `data`: contenido propio de cada comando

El script imprime este JSON completo, sin transformar.

## Comandos del script

`N` es un entero positivo. `ts(N)` es la marca de tiempo Unix en segundos de hace N días.

| Comando del script | `cmd` de la API | Parámetros |
|--------------------|-----------------|------------|
| `server-info` | `get_server_info` | ninguno |
| `activity` | `get_activity` | ninguno (`--details` no tiene efecto) |
| `history` | `get_history` | `length` (25), `user`, `section_id`, `media_type`, `start_date=ts(N)`, `search` |
| `user-stats` sin opciones | `get_users` | ninguno |
| `user-stats` con opciones | `get_user_stats` | `user`, `order_column` (de `--sort-by`), `length`, `start_date=ts(N)`; solo los dados |
| `libraries` | `get_libraries` | ninguno |
| `library-stats` | `get_library` | `section_id` |
| `popular` | `get_home_stats` | `stat_id=popular_movies` (fijo), `time_range` (30), `length` (10), `section_id`, `media_type` |
| `recent` | `get_recently_added` | `count` (25), `section_id`, `media_type`, `start=ts(N)` |
| `home-stats` | `get_home_stats` | `time_range` (30) |
| `plays-by-stream` | `get_plays_by_stream_type` | `time_range` (30), `y_axis=plays` |
| `plays-by-platform` | `get_plays_by_top_10_platforms` | `time_range` (30), `y_axis=plays` |
| `plays-by-date` | `get_plays_by_date` | `time_range` (30), `y_axis=plays` |
| `plays-by-hour` | `get_plays_by_hourofday` | `time_range` (30), `y_axis=plays` |
| `plays-by-day` | `get_plays_by_dayofweek` | `time_range` (30), `y_axis=plays` |
| `concurrent-streams` | `get_concurrent_streams_by_stream_type` | `time_range` (30) |
| `concurrent-streams --peak` | `get_plays_per_month` | `time_range` (30), `y_axis=concurrent` |
| `metadata` | `get_metadata` | `rating_key` o `guid` (manda `rating_key`) |

## Códigos y errores

| Situación | Resultado del script |
|-----------|----------------------|
| Fallo de red o timeout | `ERROR: no se pudo contactar con Tautulli en <URL>`, rc 1 |
| HTTP no 2xx | `ERROR: Tautulli respondió HTTP <código>`, rc 1 |
| `result` distinto de `success` | `ERROR: Tautulli devolvió error: <message>`, rc 1 |

Referencia oficial: https://github.com/Tautulli/Tautulli/wiki/Tautulli-API-Reference
