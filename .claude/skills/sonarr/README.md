# sonarr

Gestiona la biblioteca de series de Sonarr: buscar, comprobar si existe, añadir, quitar, lanzar búsquedas y leer logs. Envuelve la API v3.

## Cuándo se usa

Cuando se pide añadir, buscar, comprobar o quitar una serie. La carga el agente `arr-acquisition`. Antes de añadir se comprueba con `exists`. Los ids son de **TVDB** (no TMDB, a diferencia de Radarr y Seerr).

## Comandos

Script: `.claude/skills/sonarr/scripts/sonarr.sh <comando> [args]`. En negrita, los que modifican estado o piden confirmación.

| Comando | Para qué sirve | Argumentos / opciones | Tipo |
|---------|----------------|-----------------------|------|
| `search` | Busca series (`/series/lookup`). Lista numerada de los 10 primeros con título, año y enlace TVDB. | `<consulta>` | Lectura |
| `search-json` | Lo mismo con el JSON completo del lookup. | `<consulta>` | Lectura |
| `exists` | Imprime `exists` (con id interno, título y número de temporadas) o `not_found`. | `<tvdbId>` | Lectura |
| `config` | Carpetas raíz y perfiles de calidad con sus ids. | Ninguno | Lectura |
| `logs` | Últimas líneas de log, de más reciente a más antigua. | `[n]` (50 por defecto), `[nivel]` (`info`, `warn`, `error`) | Lectura |
| **`add`** | Añade una serie monitorizada (`monitor: all`, carpetas por temporada) en la primera carpeta raíz. Busca episodios que faltan salvo `--no-search`. | `<tvdbId> [profileId] [--no-search]` | Escritura |
| **`remove`** | Quita una serie de la biblioteca. Con `--delete-files` borra también los ficheros. | `<tvdbId> [--delete-files]` | Escritura, destructivo con `--delete-files` |
| **`search-id`** | Lanza `SeriesSearch` sobre una serie. | `<seriesId>` (id interno de Sonarr, no TVDB) | Escritura (dispara descargas) |
| **`search-all`** | Lanza `MissingEpisodeSearch` sobre toda la biblioteca. | Ninguno | Escritura masiva |

## Variables de entorno

| Variable | Obligatoria | Uso |
|----------|-------------|-----|
| `SONARR_URL` | Sí | URL base de Sonarr; la API se llama en `$SONARR_URL/api/v3`. |
| `SONARR_API_KEY` | Sí | Clave de API, cabecera `X-Api-Key`. |
| `SONARR_DEFAULT_QUALITY_PROFILE` | No | Id del perfil usado en `add`; si no se define, se usa `1`. |
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

- Igual que en Radarr, el script usa `set -euo pipefail` y lee `$1`, `$2` directamente: sin comando falla con "unbound variable", y `add <tvdbId>` o `remove <tvdbId>` con un solo argumento fallan por `$2` sin definir. Pasar `profileId` o `--no-search` en `add`, y un segundo argumento en `remove`.
- `add` busca la serie con `term=tvdb:<id>` y aborta si no la encuentra. Perfil: `profileId`, si no `SONARR_DEFAULT_QUALITY_PROFILE`, si no `1`.
- Para cambiar el perfil de una serie existente no sirve `add`; hay que hacer PUT sobre la serie (`qualityProfileId`), lo cual este script no ofrece (véase `arr-language-filters`).
- `remove` llama a `DELETE /series/<id>?deleteFiles=...` y no pide confirmación: la doble confirmación con `--delete-files` es responsabilidad del agente.
- `search-id` espera el id interno de Sonarr (el de `exists`); `search-all` afecta a toda la biblioteca.
- `search`, `exists` y `config` imprimen texto, no JSON; solo `search-json` devuelve JSON. Los mensajes de `add` y `remove` llevan emojis.
- Un comando desconocido imprime la ayuda con código de salida 0.
