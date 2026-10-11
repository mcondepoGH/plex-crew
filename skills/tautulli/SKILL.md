---
name: tautulli
description: Esta skill debe usarse cuando se necesite supervisar y analizar el uso de Plex Media Server mediante la API de analítica de Tautulli. Úsala cuando el usuario pida "revisar Tautulli", "analítica de Plex", "estadísticas de visionado", "streams actuales", "quién está viendo algo", "historial de Plex", "lo más visto", "actividad de usuarios", "estadísticas de biblioteca", o mencione Tautulli o la monitorización de Plex.
---

# Skill de analítica de Plex con Tautulli

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "revisar Tautulli", "analítica de Plex", "estadísticas de visionado"
- "streams actuales", "quién está viendo algo", "historial de Plex"
- "lo más visto", "actividad de usuarios", "estadísticas de biblioteca"
- Cualquier mención de Tautulli o de la monitorización del uso de Plex

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Consulta en Tautulli qué se está viendo, qué se ha visto y cómo se usa la biblioteca de Plex, siempre en modo lectura.

## Propósito

Esta skill consulta la API de Tautulli para:
- Ver los streams en curso y la información del servidor
- Consultar el historial de reproducción, por usuario, biblioteca, tipo de medio, fecha o texto
- Obtener estadísticas de usuarios y de bibliotecas
- Ver lo más reproducido, lo añadido recientemente y las gráficas de reproducciones
- Leer los metadatos de un elemento

Todos los comandos son de solo lectura. No existe ningún comando destructivo ni de escritura, así que el hook `confirm-destructive` no aplica.

## Configuración

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
TAUTULLI_URL="http://localhost:8181"
TAUTULLI_API_KEY="your-api-key"
```

- `TAUTULLI_URL`: URL de Tautulli, con el puerto (8181 por defecto)
- `TAUTULLI_API_KEY`: clave de API, en Tautulli → Settings → Web Interface → API
- `HOMELAB_ENV`: ruta opcional a otro fichero de entorno; las variables ya exportadas tienen prioridad

## Ejecución del script

El script está en `${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh`. Llámalo siempre con esa ruta y con `bash`, sin cambiar el directorio de trabajo de la sesión. Necesita `curl`, `jq` y `date` (GNU).

## Comandos

Todos los comandos devuelven JSON: el cuerpo completo que responde Tautulli, con el envoltorio `response.result`, `response.message` y `response.data`. Ninguno imprime texto; filtra con `jq '.response.data...'`. Sin comando se muestra la ayuda (código de salida 0); un comando desconocido la muestra por stderr y termina con 1. Una opción desconocida, una opción sin valor, un número no válido (`--days`, `--limit`, `--section-id` y `--rating-key` exigen enteros; `--days` y `--limit`, al menos 1) o un argumento obligatorio ausente imprime el uso y termina con 1. Un fallo de red, una respuesta HTTP no 2xx o un `result` distinto de `success` imprime `ERROR:` en stderr y termina con 1.

Las opciones van en cualquier orden. Con `--days N` en `history`, `user-stats` y `recent` se calcula la marca de tiempo Unix de hace N días; en el resto, N se envía como `time_range` en días. Las fechas se interpretan en la hora del servidor; el usuario trabaja en Europe/Madrid (regla global en `plex-crew-rules`).

### Servidor y actividad

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" server-info
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" activity
```

**Salida:** `server-info` devuelve nombre, versión e IP del servidor. `activity` devuelve los streams en curso (`response.data.sessions`, `stream_count`). `--details` se acepta pero no tiene efecto: la salida es idéntica.

### Historial

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" history --user "ana" --days 7 --limit 10
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" history --media-type movie --search "dune"
```

**Salida:** JSON con las reproducciones (`response.data.data`). Opciones: `--user`, `--section-id`, `--media-type` (`movie`, `episode` o `track`), `--days`, `--limit` (25 por defecto) y `--search`.

### Estadísticas de usuarios

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" user-stats
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" user-stats --sort-by plays --limit 5 --days 30
```

**Salida:** sin opciones lista los usuarios (`get_users`). Con cualquier opción devuelve estadísticas (`get_user_stats`); solo se envían las opciones dadas. `--sort-by` sugiere `plays`, `duration` o `last_seen`. No hay valor por defecto para `--limit`.

### Bibliotecas

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" libraries
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" library-stats --section-id 1
```

**Salida:** `libraries` lista las bibliotecas con su `section_id`. `library-stats` exige `--section-id` y devuelve los datos de esa biblioteca.

### Popular y reciente

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" popular --days 30 --limit 10
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" recent --section-id 2 --days 7 --limit 20
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" home-stats --days 30
```

**Salida:** `popular` devuelve las estadísticas de portada de contenido popular (30 días y 10 resultados por defecto). `recent` devuelve lo añadido recientemente (25 por defecto; sin `--days` no se limita por fecha). `home-stats` devuelve todas las estadísticas de portada del periodo. `--media-type` se pasa tal cual, sin validar.

### Gráficas de reproducciones

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" plays-by-date --days 14
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" plays-by-hour
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" concurrent-streams --days 90 --peak
```

**Salida:** series de datos (`categories` y `series`) para `plays-by-stream`, `plays-by-platform` (top 10), `plays-by-date`, `plays-by-hour` y `plays-by-day`; todas aceptan `--days` (30 por defecto). `concurrent-streams` da los streams simultáneos por tipo de stream; con `--peak` cambia a la serie mensual de simultaneidad.

### Metadatos

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" metadata --rating-key 12345
bash "${CLAUDE_PLUGIN_ROOT}/skills/tautulli/scripts/tautulli-api.sh" metadata --guid "plex://movie/..."
```

**Salida:** metadatos del elemento. Exige `--rating-key` o `--guid`; si se dan ambos, manda `--rating-key`.

## Flujo de trabajo

1. **"¿Quién está viendo algo?"** → `activity` y resume `response.data.sessions`
2. **"¿Qué se ha visto esta semana?"** → `history --days 7`
3. **"¿Qué es lo más visto?"** → `popular --days 30`
4. **"¿Cuánto usa Plex cada usuario?"** → `user-stats --sort-by plays`
5. **"¿A qué hora se ve más?"** → `plays-by-hour`

Para filtrar por biblioteca, ejecuta antes `libraries` y toma el `section_id`.

## Parámetros

| Opción | Comandos | Notas |
|--------|----------|-------|
| `--days N` | history, user-stats, popular, recent, home-stats, plays-by-*, concurrent-streams | Entero >= 1; por defecto 30 donde aplica |
| `--limit N` | history (25), user-stats, popular (10), recent (25) | Entero >= 1 |
| `--section-id N` | history, library-stats, popular, recent | Entero |
| `--media-type T` | history, popular, recent | Sin validar |
| `--user U`, `--search T`, `--sort-by C` | history / user-stats | Texto libre |
| `--rating-key N`, `--guid T` | metadata | Uno de los dos |
| `--details`, `--peak` | activity, concurrent-streams | Flags |

## Notas

- Limitaciones conocidas: `popular` envía siempre `stat_id=popular_movies`, aunque se pase otro `--media-type`; `activity --details` se acepta pero no cambia nada.
- Nunca imprimas `TAUTULLI_API_KEY` ni uses `curl` con la clave en línea: usa siempre el script.
- Timeouts: 10 s de conexión y 30 s en total, sin reintentos.
- Los valores con espacios o caracteres especiales se codifican correctamente.

## Referencia

- [API de Tautulli (wiki Tautulli-API-Reference)](https://github.com/Tautulli/Tautulli/wiki/Tautulli-API-Reference)

Para la referencia local detallada, consulta:
- **[Endpoints de la API](./references/api-endpoints.md)** - Comando del script, `cmd` de la API y parámetros
- **[Referencia rápida](./references/quick-reference.md)** - Configuración y ejemplos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Autenticación, conexión y uso
