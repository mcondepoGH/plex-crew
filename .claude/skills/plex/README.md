# plex

Consulta Plex Media Server: bibliotecas, búsqueda, añadidos recientes, "On Deck", sesiones activas, clientes y metadatos. Envuelve la API HTTP de Plex y devuelve JSON. Casi todo es de solo lectura; la excepción es `refresh`, que lanza un escaneo de biblioteca.

## Cuándo se usa

Cuando se pregunta qué hay en Plex, quién está viendo algo o qué se añadió hace poco. La usan los agentes `plex-naming` (para comprobar cómo ve Plex un título) y `arr-acquisition`. Complementa a `tautulli` (estado en tiempo real frente a histórico).

## Comandos

Script: `.claude/skills/plex/scripts/plex-api.sh <comando> [opciones]`. En negrita, los que modifican estado o piden confirmación.

| Comando | Para qué sirve | Argumentos / opciones | Tipo |
|---------|----------------|-----------------------|------|
| `info` | Información y capacidades del servidor (`/`). | Ninguno | Lectura |
| `identity` | Identidad del servidor (`/identity`). | Ninguno | Lectura |
| `libraries` | Lista las secciones de biblioteca (para conocer sus claves). | Ninguno | Lectura |
| `library` | Contenido de una sección. | `<section-id> [--limit\|-l N] [--offset\|-o O]` | Lectura |
| `recent` | Añadidos recientemente (20 por defecto). | `[--limit\|-l N]` | Lectura |
| `ondeck` | Lista "continuar viendo" (10 por defecto). | `[--limit\|-l N]` | Lectura |
| `search` | Búsqueda en todas las bibliotecas. | `<consulta> [--limit\|-l N]` | Lectura |
| `metadata` | Metadatos de un elemento. | `<rating-key>` | Lectura |
| `children` | Hijos de un elemento (p. ej. temporadas de una serie). | `<rating-key>` | Lectura |
| `sessions` | Reproducciones en curso. | Ninguno | Lectura |
| `clients` | Clientes/reproductores conectados. | Ninguno | Lectura |
| `playlists` | Listas de reproducción. | Ninguno | Lectura |
| `accounts` | Cuentas de usuario (requiere ser administrador). | Ninguno | Lectura |
| `prefs` | Preferencias del servidor (requiere ser administrador). | Ninguno | Lectura |
| **`refresh`** | Lanza un escaneo de la sección (`/library/sections/<id>/refresh`). | `<section-id>` | Escritura (dispara un escaneo) |

Sin argumentos, `-h`, `--help` o `help` muestran la ayuda.

## Variables de entorno

| Variable | Obligatoria | Uso |
|----------|-------------|-----|
| `PLEX_URL` | Sí | URL base de Plex, con puerto (se quita la barra final). |
| `PLEX_TOKEN` | Sí | Token de autenticación. |
| `HOMELAB_ENV` | No | Ruta alternativa al fichero `.env`. |

## Ejemplos de uso

```bash
# Lectura: claves de las secciones y primeros 50 elementos de una
bash .claude/skills/plex/scripts/plex-api.sh libraries
bash .claude/skills/plex/scripts/plex-api.sh library 1 --limit 50

# Lectura: buscar un título y quién está viendo algo ahora
bash .claude/skills/plex/scripts/plex-api.sh search "Inception" --limit 10
bash .claude/skills/plex/scripts/plex-api.sh sessions | jq '.MediaContainer.size'

# ESCRITURA: escanear una sección (no hacerlo tras renombrar: véase notas)
bash .claude/skills/plex/scripts/plex-api.sh refresh 1
```

## Notas y límites

- Las claves de sección (1, 2, 3...) varían por servidor: se listan primero con `libraries`.
- Las peticiones envían `Accept: application/json` y el token tanto en la cabecera `X-Plex-Token` como en la URL (`?X-Plex-Token=...`), por lo que puede quedar en logs del servidor.
- `set -u` hace que `library`, `search`, `metadata`, `children` y `refresh` sin argumento fallen con "unbound variable". Una opción desconocida en `library`, `recent`, `ondeck` o `search` aborta con "Unknown option".
- `refresh` imprime siempre `{"status": "ok", ...}` sin comprobar la respuesta de Plex.
- La skill no controla la reproducción.
- Tras renombrar archivos no se lanzan ni se ofrecen escaneos (`refresh`): un script externo actualiza Plex, según `plex-naming-rules`.
- El escaneo por zurg tiene sus propias tools (`mcp__zurg__zurg_plex_*`), fuera de esta skill.
