# Endpoints de la API de Plex usados por el script

## Base y autenticación

- **URL base:** `PLEX_URL` sin barra final (por ejemplo `http://host:32400`)
- **Método:** `GET` en todos los comandos, `refresh` incluido, salvo `setpref`, que usa `PUT`
- **Token:** se envía en la cabecera `X-Plex-Token` y como último parámetro `X-Plex-Token=<token>` de la URL (se une con `?`, o con `&` si la ruta ya contiene `?`)
- **Cabecera de formato:** `Accept: application/json`
- **Timeouts:** conexión 10 s, total 30 s, sin reintentos
- **Respuesta:** el cuerpo tal cual; no se comprueba el código HTTP

El script pasa la URL y las cabeceras a curl por stdin (`--config -`), por lo que el token no aparece en `ps`.

## Comandos y rutas

| Comando | Ruta | Parámetros |
|---------|------|------------|
| `info` | `/` | ninguno |
| `identity` | `/identity` | ninguno |
| `libraries` | `/library/sections` | ninguno |
| `library <id>` | `/library/sections/<id>/all` | `--limit`, `--offset` (ver abajo) |
| `recent` | `/library/recentlyAdded` | `X-Plex-Container-Size` (20 por defecto) |
| `ondeck` | `/library/onDeck` | `X-Plex-Container-Size` (10 por defecto) |
| `search <texto>` | `/search` | `query` (codificado) y, si hay límite, `limit` |
| `metadata <key>` | `/library/metadata/<key>` | ninguno |
| `children <key>` | `/library/metadata/<key>/children` | ninguno |
| `sessions` | `/status/sessions` | ninguno |
| `clients` | `/clients` | ninguno |
| `playlists` | `/playlists` | ninguno |
| `accounts` | `/accounts` | ninguno (token de administrador) |
| `prefs` | `/:/prefs` | ninguno (token de administrador) |
| `refresh <id>` | `/library/sections/<id>/refresh` | ninguno (modifica estado) |
| `setpref <clave> <valor>` | `PUT /:/prefs?<clave>=<valor>` | ninguno (modifica estado; token de administrador) |

## Ruta defectuosa de `library` con opciones

Con `--limit N` y/o `--offset O` el script añade `&X-Plex-Container-Size=<N>` y `&X-Plex-Container-Start=<O>` a la ruta sin `?` intermedio. Como la ruta no contiene `?`, el token se une con `?` al final:

```
/library/sections/<id>/all&X-Plex-Container-Size=<N>?X-Plex-Token=<token>
```

Plex no la interpreta como paginación y puede responder 404. Sin opciones la petición es correcta.

## `refresh`

Dispara un escaneo de la biblioteca; no borra nada. El script imprime el cuerpo de Plex (normalmente vacío) y después, siempre, `{"status": "ok", "message": "Library refresh initiated"}`.

## Forma de la respuesta

```json
{"MediaContainer": {"size": 2, "Metadata": [{"ratingKey": "123", "title": "...", "type": "movie", "year": 2021, "addedAt": 1700000000, "librarySectionID": 1}]}}
```

- Contenido en `MediaContainer.Metadata`; bibliotecas en `MediaContainer.Directory`
- `sessions` añade `User`, `Player`, `Media` y `TranscodeSession` a cada elemento
- `addedAt` y `lastViewedAt` son marcas de tiempo Unix
