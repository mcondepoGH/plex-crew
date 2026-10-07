# seerr

Gestiona solicitudes en Seerr (compatible con Overseerr y Jellyseerr): buscar títulos, ver el estado, listar solicitudes, pedir películas y series y leer los logs. Envuelve la API `v1`.

## Cuándo se usa

Cuando se pide buscar o solicitar contenido desde Seerr o listar solicitudes pendientes. La carga el agente `arr-acquisition`. Los ids son de **TMDB** (los mismos que usa `radarr`); `sonarr` usa TVDB, así que para series hay que localizar antes el id de TMDB.

## Comandos

Script: `.claude/skills/seerr/scripts/seerr.sh <comando> [args]`. En negrita, los que modifican estado o piden confirmación.

| Comando | Para qué sirve | Argumentos / opciones | Tipo |
|---------|----------------|-----------------------|------|
| `status` | Estado y versión de Seerr. | Ninguno | Lectura (JSON) |
| `search` | Busca títulos: tipo, id TMDB, título, año y estado en Seerr. | `<texto>` | Lectura (texto) |
| `requests` | Lista hasta 50 solicitudes con id, tipo, TMDB, estado y solicitante. | `[pending\|approved\|all]` (`pending` por defecto) | Lectura (texto) |
| `logs` | Últimas entradas del log con formato `fecha [nivel] etiqueta: mensaje`. | `[n]` (50 por defecto), `[nivel]` (`debug`, `info`, `warn`, `error`) | Lectura (texto) |
| **`request-movie`** | Crea una solicitud de película. | `<tmdbId>` | Escritura (texto) |
| **`request-tv`** | Crea una solicitud de serie: todas las temporadas o las indicadas. | `<tmdbId> [temporadas]`, lista separada por comas (`1,2`) | Escritura (texto) |

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

- Una solicitud puede aprobarse sola y pasar a Radarr o Sonarr según la configuración de Seerr; se confirma con el usuario antes de crearla.
- El script no consulta duplicados por adelantado: si Seerr rechaza la solicitud (409 u otro 4xx), muestra el mensaje por stderr y sale con 1.
- Todos los comandos comprueban el código HTTP: una respuesta no 2xx o la falta de conexión imprime `ERROR:` por stderr y sale con 1.
- El filtro de `requests` solo admite los tres valores de la tabla y se limita a 50 resultados; `logs` valida `n` como número y el nivel contra la lista.
- Sin comando muestra la ayuda y sale con 0; un comando desconocido, un argumento que falta o un id no numérico salen con 1.
