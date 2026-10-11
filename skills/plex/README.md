# Skill de Plex

Explora Plex Media Server desde la línea de comandos: bibliotecas, búsquedas, reproducciones en curso y escaneos.

## Qué hace

- **Servidor** — Información e identidad del servidor
- **Bibliotecas** — Lista las bibliotecas y su contenido
- **Reciente** — Lo añadido recientemente y "continuar viendo"
- **Búsqueda** — Búsqueda global y metadatos de un elemento y sus hijos
- **Actividad** — Reproducciones en curso, clientes, listas y cuentas
- **Escaneo** — Lanza el escaneo de una biblioteca (`refresh`, la única escritura)

Todos los comandos devuelven el JSON de Plex sin reformatear, salvo `refresh`, que añade una línea fija.

## Configuración

### 1. Obtén tu token de Plex

1. Abre la web de Plex e inicia sesión
2. Abre cualquier elemento y elige **Ver XML**
3. Copia el valor de `X-Plex-Token` de la URL

### 2. Configura las variables de entorno

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
PLEX_URL="http://localhost:32400"
PLEX_TOKEN="<your_plex_token>"
```

**Opciones de configuración:**
- `PLEX_URL`: URL del servidor con puerto (una barra final se ignora)
- `PLEX_TOKEN`: token de Plex (administrador para `accounts` y `prefs`)

### 3. Pruébalo

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" identity
```

Fuera de una sesión de Claude Code `${CLAUDE_PLUGIN_ROOT}` no existe: usa la ruta real del plugin.

## Ejemplos de uso

### Bibliotecas y contenido

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" libraries | jq '.MediaContainer.Directory[] | {key, title, type}'
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" library 1 | jq '.MediaContainer.Metadata[].title'
```

### Reciente y continuar viendo

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" recent --limit 30
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" ondeck -l 5
```

### Búsqueda y metadatos

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" search "dune" --limit 5
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" metadata 12345
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" children 12345
```

### Actividad

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" sessions
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" clients
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" playlists
```

### Administración

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" accounts
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" prefs
```

### Escaneo de una biblioteca

**Confirma con el usuario antes de lanzarlo.**

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/plex/scripts/plex-api.sh" refresh 1
```

## Referencia de la API

- [Endpoints de la API](references/api-endpoints.md)
- [Referencia rápida](references/quick-reference.md)
- [Resolución de problemas](references/troubleshooting.md)
- [Documentación de Plex](https://developer.plex.tv/pms/)

## Flujo de trabajo

1. Ejecuta `libraries` para conocer los `section-id`
2. Ejecuta `recent`, `search` o `library` para encontrar el `ratingKey`
3. Ejecuta `metadata` o `children` con ese `ratingKey`
4. Filtra el JSON con `jq '.MediaContainer...'`

## Resolución de problemas

**El comando imprime texto o HTML y termina con 0**
→ Plex rechazó la petición (401, 404): el script no comprueba el código HTTP. Revisa `PLEX_TOKEN`.

**ERROR: no se pudo contactar con Plex en <URL>**
→ Comprueba la URL, el puerto (32400) y que Plex esté en marcha.

**ERROR: 'abc' no es un número entero positivo**
→ Pasa un entero como id, `--limit` u `--offset`.

## Notas

- Limitaciones conocidas: no se comprueba el código HTTP; `refresh` imprime siempre la línea de "iniciado"; `library --limit` y `--offset` no paginan (ruta mal formada); `help` exige credenciales; `search` y `library` toman el primer argumento como posicional aunque empiece por `-`; los argumentos sobrantes se ignoran.
- El token nunca se imprime; el script lo pasa a curl por stdin, aunque viaja a Plex en cabecera y en la URL.
- Requiere `bash` y `curl`; `search` requiere además `jq`.

## Licencia

MIT
