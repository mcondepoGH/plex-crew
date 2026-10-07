# seerr

Gestiona solicitudes en Seerr (compatible con Overseerr/Jellyseerr): buscar títulos, ver el estado, listar solicitudes, pedir películas y series y leer los logs. Envuelve la API `v1`.

## Cuándo se usa

Cuando se pide buscar o solicitar contenido desde Seerr o listar solicitudes pendientes. La carga el agente `arr-acquisition`. Los ids son de **TMDB** (los mismos que usa `radarr`); `sonarr` usa TVDB, así que para series hay que localizar antes el id de TMDB.

## Comandos

Script: `.claude/skills/seerr/scripts/seerr.sh <comando> [args]`. En negrita, los que modifican estado o piden confirmación.

| Comando | Para qué sirve | Argumentos / opciones | Tipo |
|---------|----------------|-----------------------|------|
| `status` | Estado y versión de Seerr (JSON crudo). | Ninguno | Lectura |
| `search` | Busca títulos: tipo, id TMDB, título, año y estado en Seerr. | `"Título"` (obligatorio) | Lectura |
| `requests` | Lista hasta 50 solicitudes con id, tipo, TMDB, estado y solicitante. | `[filtro]` (`pending` por defecto; por ejemplo `approved`, `all`) | Lectura |
| `logs` | Últimas entradas del log con formato `fecha [nivel] etiqueta: mensaje`. | `[n]` (50 por defecto), `[nivel]` (`error`, `warn`, `info`, `debug`) | Lectura |
| **`request-movie`** | Crea una solicitud de película. | `<tmdbId>` | Escritura |
| **`request-tv`** | Crea una solicitud de serie: todas las temporadas, o las indicadas. | `<tmdbId> [temporadas]`, lista separada por comas (`1,2`) | Escritura |

## Variables de entorno

| Variable | Obligatoria | Uso |
|----------|-------------|-----|
| `SEERR_URL` | Sí | URL base de Seerr; la API se llama en `<SEERR_URL>/api/v1`. |
| `SEERR_API_KEY` | Sí | Clave de API, cabecera `X-Api-Key` (Settings > General). |
| `HOMELAB_ENV` | No | Ruta alternativa al fichero `.env`. |

## Ejemplos de uso

```bash
# Lectura: buscar un título y ver su id de TMDB
bash .claude/skills/seerr/scripts/seerr.sh search "Dune"

# Lectura: solicitudes pendientes y errores recientes
bash .claude/skills/seerr/scripts/seerr.sh requests pending
bash .claude/skills/seerr/scripts/seerr.sh logs 20 error

# ESCRITURA: pedir las temporadas 1 y 2 de una serie
bash .claude/skills/seerr/scripts/seerr.sh request-tv 1396 1,2
```

## Notas y límites

- `request-movie` y `request-tv` crean una solicitud real: según la configuración de Seerr puede aprobarse sola y pasar a Radarr o Sonarr. Se confirma con el usuario antes, salvo que haya nombrado el título exacto. El script no comprueba duplicados ni confirma nada.
- `request-movie` y `request-tv` pasan el id por `jq --argjson`, así que debe ser numérico; las temporadas se convierten con `tonumber`.
- `search` formatea `.results[]`; `status`, `request-movie` y `request-tv` devuelven el JSON crudo.
- El filtro de `requests` se envía tal cual a la API y se limita a 50 resultados (`take=50`); `logs` pagina con `take=<n>&skip=0`.
- Sin argumentos o con un comando desconocido, el script imprime el uso y sale con código 1.
