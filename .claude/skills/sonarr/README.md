# sonarr

Gestiona la biblioteca de series de Sonarr: buscar, comprobar si existe, añadir, quitar, lanzar búsquedas y leer logs. Envuelve la API v3.

## Cuándo se usa

Cuando se pide añadir, buscar, comprobar o quitar una serie. La carga el agente `arr-acquisition`. Antes de añadir se comprueba con `exists`. Los ids son de **TVDB** (no TMDB, a diferencia de Radarr y Seerr).

## Comandos

Script: `.claude/skills/sonarr/scripts/sonarr.sh <comando> [args]`. En negrita, los que modifican estado o piden confirmación.

| Comando | Para qué sirve | Argumentos / opciones | Tipo |
|---------|----------------|-----------------------|------|
| `search` | Busca series (`/series/lookup`). Texto: lista numerada de los 10 primeros con título, año y enlace TVDB; sin sinopsis. | `<consulta>` | Lectura (texto) |
| `search-json` | Lo mismo con el JSON completo del lookup (sin límite de 10). | `<consulta>` | Lectura (JSON) |
| `exists` | Imprime `exists` (con id interno, título y número de temporadas) o `not_found`. | `<tvdbId>` | Lectura (texto) |
| `config` | Carpetas raíz y perfiles de calidad con sus ids. | Ninguno | Lectura (texto) |
| `logs` | Últimas líneas de log, de más reciente a más antigua. | `[n]` (50 por defecto), `[nivel]` (`info`, `warn`, `error`) | Lectura (texto) |
| **`add`** | Añade una serie monitorizada (`monitor: all`, carpetas por temporada) en la primera carpeta raíz. Funciona con solo `<tvdbId>`. Busca episodios que faltan salvo `--no-search`. | `<tvdbId> [profileId] [--no-search]` | Escritura |
| **`remove`** | Quita una serie de la biblioteca. Con `--delete-files` borra también los ficheros. | `<tvdbId> [--delete-files]` | Escritura, destructivo con `--delete-files` |
| **`search-id`** | Lanza `SeriesSearch` sobre una serie. | `<seriesId>` (id interno de Sonarr, no TVDB) | Escritura (dispara descargas) |
| **`search-all`** | Lanza `MissingEpisodeSearch` sobre toda la biblioteca. | Ninguno | Escritura masiva |

## Variables de entorno

| Variable | Obligatoria | Uso |
|----------|-------------|-----|
| `SONARR_URL` | Sí | URL base de Sonarr; la API se llama en `$SONARR_URL/api/v3`. |
| `SONARR_API_KEY` | Sí | Clave de API, cabecera `X-Api-Key`. |
| `HOMELAB_ENV` | No | Ruta alternativa al fichero `.env`. |

## Ejemplos de uso

```bash
# Lectura: buscar la serie y comprobar si ya está (usa el tvdbId del resultado)
bash .claude/skills/sonarr/scripts/sonarr.sh search "Breaking Bad"
bash .claude/skills/sonarr/scripts/sonarr.sh exists 81189

# Lectura: perfiles de calidad disponibles y errores recientes
bash .claude/skills/sonarr/scripts/sonarr.sh config
bash .claude/skills/sonarr/scripts/sonarr.sh logs 30 error

# ESCRITURA: añadir con un perfil concreto y sin lanzar búsqueda
bash .claude/skills/sonarr/scripts/sonarr.sh add 81189 7 --no-search
```

## Notas y límites

- Sin comando muestra la ayuda y sale con 0; un comando desconocido muestra la ayuda y sale con 1. Si falta un argumento obligatorio o un id no es numérico, imprime el uso (`ERROR: ...` y `Uso: sonarr.sh ...`) y sale con 1; nunca falla con `unbound variable`. Los flags `--no-search` y `--delete-files` se aceptan en cualquier posición.
- `add <tvdbId> <profileId> [--no-search]` busca la serie con `term=tvdb:<id>` y aborta si no la encuentra. El perfil es obligatorio y nunca se elige uno por defecto; si falta, imprime el uso, indica ejecutar `config` para ver los ids (p. ej. 7 Español, 8 VOSE) y sale con 1.
- Para cambiar el perfil de una serie existente no sirve `add`; hay que hacer PUT sobre la serie (`qualityProfileId`), lo cual este script no ofrece (véase `arr-language-filters`).
- `remove` llama a `DELETE /series/<id>?deleteFiles=...`; el hook `confirm-destructive` exige la doble confirmación y el marcador `PLEX_CREW_CONFIRMED=1`. Imprime que ha quitado la serie sin verificar la respuesta del `DELETE`.
- `search-id` espera el id interno de Sonarr (el de `exists`); `search-all` afecta a toda la biblioteca.
- Solo `search-json` devuelve JSON; el resto imprime texto. Los mensajes de `add` y `remove` llevan emojis.
- Sonarr no tiene `add-collection`.
