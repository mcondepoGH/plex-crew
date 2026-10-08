---
name: radarr
description: Esta skill debe usarse cuando se gestionan películas en Radarr. Úsala cuando el usuario pida "añadir una película", "buscar en Radarr", "encontrar una película", "añadir a Radarr", "eliminar una película", "añadir una colección de películas", "comprobar si una película existe", "biblioteca de Radarr", o mencione la gestión de películas, la integración con TMDB u operaciones de Radarr.
---

# Skill de gestión de películas en Radarr

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "añadir una película", "buscar en Radarr", "encontrar una película", "añadir a Radarr"
- "eliminar una película", "borrar película", "comprobar si una película existe"
- "añadir una colección de películas", "biblioteca de Radarr", "gestión de películas"
- Cualquier mención de Radarr o de la gestión de películas

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Busca y añade películas a tu biblioteca de Radarr, con soporte de colecciones, perfiles de calidad y búsqueda al añadir.

## Propósito

Esta skill permite gestionar tu biblioteca de películas de Radarr:
- Buscar películas por nombre
- Añadir películas sueltas o colecciones completas
- Comprobar si las películas ya existen
- Eliminar películas (con borrado opcional de archivos)
- Consultar perfiles de calidad y carpetas raíz

Las operaciones incluyen acciones de lectura y de escritura. **Confirma siempre antes de eliminar películas con borrado de archivos.**

## Configuración

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
RADARR_URL="http://localhost:7878"
RADARR_API_KEY="your-api-key"
RADARR_DEFAULT_QUALITY_PROFILE="1"  # Optional (defaults to 1)
```

- `RADARR_URL`: URL de tu servidor Radarr (sin barra final)
- `RADARR_API_KEY`: clave de API de Radarr (Settings → General → API Key)
- `RADARR_DEFAULT_QUALITY_PROFILE`: ID del perfil de calidad (opcional, ejecuta el comando `config` para ver las opciones)

## Ejecución del script

El script está en `${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/`. Los ejemplos siguientes usan rutas relativas a la carpeta de la skill, así que ejecútalos en un subshell que no altere el directorio de trabajo de la sesión:

```bash
(cd "${CLAUDE_PLUGIN_ROOT}/skills/radarr" && bash scripts/radarr.sh search "Inception")
```

## Comandos

Todos los comandos devuelven salida JSON.

### Buscar películas

```bash
bash scripts/radarr.sh search "Inception"
bash scripts/radarr.sh search "The Matrix"
```

**Salida:** lista numerada con IDs de TMDB, títulos, años y sinopsis.

### Comprobar si una película existe

```bash
bash scripts/radarr.sh exists <tmdbId>
```

**Salida:** booleano que indica si la película está en la biblioteca.

### Añadir una película

```bash
bash scripts/radarr.sh add <tmdbId>              # Busca de inmediato (por defecto)
bash scripts/radarr.sh add <tmdbId> --no-search  # Añade sin buscar
```

### Añadir una colección completa

```bash
bash scripts/radarr.sh add-collection <collectionTmdbId>
bash scripts/radarr.sh add-collection <collectionTmdbId> --no-search
```

Añade todas las películas de una colección (p. ej., todas las de El Señor de los Anillos).

### Eliminar una película

```bash
bash scripts/radarr.sh remove <tmdbId>                # Conserva los archivos
bash scripts/radarr.sh remove <tmdbId> --delete-files # Borra también los archivos
```

**Importante:** pregunta siempre al usuario si quiere borrar los archivos al eliminar.

### Obtener la configuración

```bash
bash scripts/radarr.sh config
```

**Salida:** carpetas raíz y perfiles de calidad disponibles con sus IDs.

## Flujo de trabajo

Cuando el usuario pregunte por películas:

1. **"Añade Inception a Radarr"** → Ejecuta `search "Inception"`, presenta los resultados con enlaces de TMDB y después `add <tmdbId>`
2. **"¿Está Dune en mi biblioteca?"** → Ejecuta `exists <tmdbId>`
3. **"Añade todas las películas de Star Wars"** → Busca la colección y después `add-collection <collectionId>`
4. **"Elimina The Matrix"** → Pregunta por el borrado de archivos y ejecuta `remove <tmdbId>` con el flag adecuado
5. **"¿Qué perfiles de calidad tengo?"** → Ejecuta `config`

### Presentar los resultados de búsqueda

Incluye siempre enlaces de TMDB al presentar resultados de búsqueda:
- Formato: `[Title (Year)](https://themoviedb.org/movie/ID)`
- Muestra una lista numerada para que el usuario elija
- Incluye el año y una breve sinopsis

### Añadir películas

1. Busca la película
2. Presenta los resultados con enlaces de TMDB
3. El usuario elige un número
4. **Comprobación de colección:** si la película pertenece a una colección, pregunta si quiere la colección completa
5. Añade la película o la colección (busca de inmediato por defecto)

## Parámetros

### Comando add
- `<tmdbId>`: ID de TMDB de la película (obligatorio)
- `--no-search`: no buscar la película tras añadirla

### Comando add-collection
- `<collectionTmdbId>`: ID de TMDB de la colección (obligatorio)
- `--no-search`: no buscar las películas tras añadirlas

### Comando remove
- `<tmdbId>`: ID de TMDB de la película (obligatorio)
- `--delete-files`: borra también los archivos multimedia (por defecto se conservan)

## Notas

- Requiere acceso de red a tu servidor Radarr
- Usa la API v3 de Radarr
- Todas las operaciones de datos devuelven JSON
- Los IDs de perfil de calidad varían según la instalación: usa `config` para descubrir los tuyos
- Al añadir películas se usa el `defaultQualityProfile` de la configuración
- Las colecciones son propias de TMDB e incluyen películas relacionadas (secuelas, sagas)

## Referencia

- [Documentación de la API de Radarr](https://radarr.video/docs/api/)
- [TMDB](https://themoviedb.org/) — The Movie Database

Para una referencia local detallada, consulta:
- **[Endpoints de la API](./references/api-endpoints.md)** - Referencia completa de endpoints con parámetros
- **[Referencia rápida](./references/quick-reference.md)** - Operaciones habituales con ejemplos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Soluciones para errores de autenticación, conexión y otros

---

## 🔧 Requisitos de uso de herramientas del agente

**CRÍTICO:** al invocar scripts de esta skill mediante la zsh-tool, **USA SIEMPRE `pty: true`**.

Sin el modo PTY, la salida de los comandos no será visible aunque se ejecuten correctamente.

**Patrón de invocación correcto:**
```typescript
<invoke name="mcp__plugin_zsh-tool_zsh-tool__zsh">
<parameter name="command">./skills/SKILL_NAME/scripts/SCRIPT.sh [args]</parameter>
<parameter name="pty">true</parameter>
</invoke>
```
