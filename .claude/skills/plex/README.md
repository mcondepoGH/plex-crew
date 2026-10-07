# plex

Consulta Plex Media Server: bibliotecas, búsqueda, añadidos recientes, "continuar viendo", sesiones activas, clientes y metadatos. Envuelve la API HTTP de Plex y devuelve JSON. Casi todo es de solo lectura; la excepción es `refresh`, que lanza un escaneo de biblioteca.

## Cuándo se usa

Cuando se pregunta qué hay en Plex, quién está viendo algo o qué se añadió hace poco. La usan los agentes `plex-naming` (para comprobar cómo ve Plex un título) y `arr-acquisition`. Complementa a `tautulli` (estado en tiempo real frente a histórico).

## Comandos

Script: `.claude/skills/plex/scripts/plex-api.sh <comando> [args]`. En negrita, los que modifican estado o piden confirmación.

| Comando | Para qué sirve | Argumentos / opciones | Tipo |
|---------|----------------|-----------------------|------|
| `info` | Información y capacidades del servidor (`/`). | Ninguno | Lectura (JSON) |
| `identity` | Identidad del servidor (`/identity`). | Ninguno | Lectura (JSON) |
| `libraries` | Lista las secciones de biblioteca (para conocer sus claves). | Ninguno | Lectura (JSON) |
| `library` | Contenido de una sección. | `<section-id> [--limit\|-l N] [--offset\|-o O]` | Lectura (JSON) |
| `recent` | Añadidos recientemente (20 por defecto). | `[--limit\|-l N]` | Lectura (JSON) |
| `ondeck` | Lista "continuar viendo" (10 por defecto). | `[--limit\|-l N]` | Lectura (JSON) |
| `search` | Búsqueda en todas las bibliotecas. | `<texto> [--limit\|-l N]` | Lectura (JSON) |
| `metadata` | Metadatos de un elemento. | `<rating-key>` | Lectura (JSON) |
| `children` | Hijos de un elemento (p. ej. temporadas de una serie). | `<rating-key>` | Lectura (JSON) |
| `sessions` | Reproducciones en curso. | Ninguno | Lectura (JSON) |
| `clients` | Clientes y reproductores conectados. | Ninguno | Lectura (JSON) |
| `playlists` | Listas de reproducción. | Ninguno | Lectura (JSON) |
| `accounts` | Cuentas de usuario (requiere ser administrador). | Ninguno | Lectura (JSON) |
| `prefs` | Preferencias del servidor (requiere ser administrador). | Ninguno | Lectura (JSON) |
| **`refresh`** | Lanza un escaneo de la sección (`/library/sections/<id>/refresh`). Confirmar antes con el usuario. | `<section-id>` | Escritura (dispara un escaneo; texto) |

## Variables de entorno

| Variable | Obligatoria | Uso |
|----------|-------------|-----|
| `PLEX_URL` | Sí | URL base de Plex, con puerto (se quita la barra final). |
| `PLEX_TOKEN` | Sí | Token de autenticación, enviado en la cabecera `X-Plex-Token`. |
| `HOMELAB_ENV` | No | Ruta alternativa al fichero `.env`. |

## Ejemplos de uso

```bash
# Lectura: claves de las secciones y primeros 50 elementos de una
bash .claude/skills/plex/scripts/plex-api.sh libraries
bash .claude/skills/plex/scripts/plex-api.sh library 1 --limit 50

# Lectura: buscar un título y contar las reproducciones en curso
bash .claude/skills/plex/scripts/plex-api.sh search "Inception" --limit 10
bash .claude/skills/plex/scripts/plex-api.sh sessions | jq '.MediaContainer.size'

# ESCRITURA: escanear una sección (confirmar antes; no hacerlo tras renombrar)
bash .claude/skills/plex/scripts/plex-api.sh refresh 1
```

## Notas y límites

- Sin comando muestra la ayuda y sale con 0; un comando desconocido muestra la ayuda por stderr y sale con 1. Un argumento obligatorio que falta, una opción sin valor, un valor no numérico (`section-id`, `rating-key`, `--limit`, `--offset`) o una opción desconocida imprimen el uso por stderr y salen con 1; nunca fallan con `unbound variable`.
- Todas las llamadas comprueban el código HTTP: si no es 2xx imprimen `ERROR:` por stderr y salen con 1.
- `refresh` imprime una línea de texto solo si Plex responde 2xx. Eso confirma que Plex aceptó la petición, no que el escaneo haya terminado.
- Tras renombrar archivos no se lanzan ni se ofrecen escaneos (`refresh`): un script externo actualiza Plex, según `plex-naming-rules`.
- El token viaja solo en la cabecera `X-Plex-Token`, no en la URL.
- `recent` pasa `X-Plex-Container-Size`, pero el servidor puede devolver más elementos de los pedidos.
- La skill no controla la reproducción.
- El escaneo por zurg tiene sus propias tools (`mcp__zurg__zurg_plex_*`), fuera de esta skill.
