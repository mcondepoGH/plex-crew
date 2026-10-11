---
name: radarr
description: Esta skill debe usarse cuando se gestionan películas en Radarr. Úsala cuando el usuario pida "añadir una película", "buscar en Radarr", "encontrar una película", "añadir a Radarr", "eliminar una película", "añadir una colección de películas", "comprobar si una película existe", "biblioteca de Radarr", "logs de Radarr", o mencione la gestión de películas, la integración con TMDB u operaciones de Radarr.
---

# Skill de gestión de películas de Radarr

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "añadir una película", "añadir a Radarr", "eliminar una película"
- "añadir una colección de películas"
- "buscar en Radarr", "encontrar una película"
- "comprobar si una película existe", "biblioteca de Radarr"
- Cualquier mención de la gestión de películas, de la integración con TMDB o de operaciones de Radarr

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Busca películas en TMDB, comprueba si están en la biblioteca de Radarr, las añade (sueltas o por colección) o las quita, y consulta el log de Radarr.

## Propósito

Esta skill usa la API v3 de Radarr para:
- Buscar películas por texto (resultados con enlace a TMDB y, si la hay, su colección)
- Comprobar si una película ya está en la biblioteca
- Mostrar las carpetas raíz, los perfiles de calidad y el estado de Radarr
- Añadir una película o una colección completa (modifica estado; por defecto lanza la búsqueda y puede iniciar descargas)
- Quitar una película, con o sin borrado de ficheros (destructivo)
- Consultar los detalles de una colección y las últimas entradas del log (solo lectura)

Los identificadores son de TMDB (`tmdbId`), no de TVDB: `seerr` también usa TMDB; `sonarr` usa TVDB.

## Configuración

Añade las credenciales a `~/.claude/plex-crew/.env`:

```bash
RADARR_URL="http://localhost:7878"
RADARR_API_KEY="your-api-key"
# Opcional: perfil de calidad por defecto de `add` (1 si falta o está vacía)
# RADARR_DEFAULT_QUALITY_PROFILE=1
```

- `RADARR_URL`: URL de Radarr con el puerto (7878 por defecto), sin barra final
- `RADARR_API_KEY`: clave de API, en Radarr → Settings → General → Security → API Key
- `RADARR_DEFAULT_QUALITY_PROFILE`: id del perfil que usa `add` si no se indica otro
- Las variables ya exportadas en el entorno tienen prioridad sobre `~/.claude/plex-crew/.env` (si `RADARR_URL` y `RADARR_API_KEY` ya están exportadas, el fichero no se lee y `RADARR_DEFAULT_QUALITY_PROFILE` solo se toma del entorno)

## Ejecución del script

El script está en `${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh`. Llámalo siempre con esa ruta y con `bash`, sin cambiar el directorio de trabajo de la sesión. Necesita `curl` y `jq`. Hasta `help` exige credenciales cargadas.

## Comandos

`search-json` y `collection-info` devuelven JSON; el resto de comandos imprime texto. Sin comando, o con `help`, `-h` o `--help`, se muestra la ayuda por stdout (código de salida 0). Un comando desconocido imprime `ERROR: comando desconocido: <x>` y `Usa: radarr.sh help` por stderr y termina con 1. `search` sin texto, y los comandos con id (`exists`, `add`, `add-collection`, `remove`, `collection-info`) con un id ausente o no numérico (o `add` con un perfil no numérico) imprimen `ERROR:` y `Uso:` por stderr y terminan con 1, sin llamar a Radarr. Si no se puede contactar con Radarr, los comandos de llamada directa imprimen `ERROR: no se pudo contactar con Radarr en <URL>` y terminan con 1; `search`, `status` y `logs` muestran los mensajes de la librería compartida.

### Buscar películas

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" search "the matrix"
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" search-json "the matrix"
```

**Salida:** `search` imprime una línea por resultado, todos los que devuelve Radarr: `1. The Matrix (1999) - https://themoviedb.org/movie/603 [Collection: The Matrix Collection]`. El sufijo ` [Collection: ...]` solo aparece si la película pertenece a una colección. Sin resultados no imprime nada. Si falta el año o el id, aparece `null`. Solo se usa el primer argumento: entrecomilla el texto. `search-json` devuelve el JSON crudo (con sinopsis, `titleSlug` y demás campos); úsalo cuando necesites más datos.

Presenta los resultados al usuario en una lista numerada con el enlace a TMDB y la colección, si la hay.

### Comprobar si una película existe

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" exists 603
```

**Salida:** `not_found` si no está en la biblioteca. Si está, dos líneas: `exists` y `ID: 12, Title: The Matrix, Has File: true`.

Ejecútalo siempre antes de `add`.

### Carpetas raíz y perfiles de calidad

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" config
```

**Salida:** `=== Root Folders ===`, una línea `<id>: <ruta>` por carpeta, una línea en blanco, `=== Quality Profiles ===` y una línea `<id>: <nombre>` por perfil.

Úsalo para elegir el `profileId` de `add`.

### Estado de Radarr

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" status
```

**Salida:** una línea: `Radarr 5.14.0.9383 - Radarr (debian, branch master)`. Sin nombre de instancia sale `Radarr`; sin sistema operativo o rama, `?`.

### Añadir una película

**Modifica estado: confirma con el usuario antes de añadir** (la película elegida y el perfil de calidad). Avisa de que, salvo con `--no-search`, Radarr busca la película y puede iniciar descargas. Comprueba antes con `exists`.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" add 603
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" add 603 5
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" add 603 5 --no-search
```

**Salida:** en éxito, `✅ Added: The Matrix (1999)` y, si la búsqueda estaba activa, `🔍 Search started` (código 0). Si Radarr no devuelve `id`: `❌ Failed to add movie` y, en otra línea, su mensaje o la respuesta completa (código 0, ver limitaciones).

`add` toma la primera carpeta raíz y deja la película monitorizada. `--no-search` desactiva la búsqueda y se reconoce en cualquier posición, pero el id va siempre primero y el perfil, de haberlo, segundo: en `add 603 --no-search 5` el `5` se ignora y se usa el perfil por defecto.

### Añadir una colección

**Modifica estado de forma masiva: confirma con el usuario antes de añadir.** Indica cuántas películas tiene la colección (sale en `search` y en `collection-info`), que el perfil será el primero de `config` (ignora `RADARR_DEFAULT_QUALITY_PROFILE`) y que, salvo con `--no-search`, Radarr busca cada película y puede iniciar descargas. Comprueba antes con `exists` las películas que te importen.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" add-collection 2344
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" add-collection 2344 "The Matrix" --no-search
```

**Salida**, en este orden: `🔍 Finding movies in collection...`; `📦 Found 3 movies in collection`; una línea por película (`✅ The Matrix (1999)`, `⏭️  The Matrix Reloaded (2003) - already in library` con dos espacios tras el emoji, o `❌ <título> (<año>) - <mensaje>` si Radarr la rechaza); una línea en blanco; `📊 Added: 2 | Skipped: 1`; `🔍 Search started for new movies` (solo con búsqueda activa y alguna añadida); y `👁️ Collection monitored (new releases auto-added)` si la colección queda monitorizada. Termina con código 0 aunque fallen películas sueltas.

El `idColeccionTmdb` es el de `collection.tmdbId` (no el de la película); `collection-info` lo muestra. El término de búsqueda solo se usa si la colección no figura aún en Radarr: si figura, se usa su título sin el sufijo ` Collection`. Sin colección conocida ni término, imprime `❌ Could not determine collection name. Please provide search term.` y el uso (código 1). Si no encuentra películas de esa colección: `❌ No movies found for collection <id>` (código 1).

### Quitar una película

**Destructivo.** Según la skill `plex-crew-rules`, exige doble confirmación del usuario en dos mensajes distintos y anteponer `PLEX_CREW_CONFIRMED=1` al comando; el hook `confirm-destructive` bloquea cualquier `radarr.sh remove` sin ese marcador, con o sin `--delete-files`. Pregunta siempre si se borran también los ficheros (el borrado es irreversible). Esta skill nunca borra carpetas ni ficheros del mount de zurg: las operaciones de zurg van solo con las tools `zurg_*`.

```bash
PLEX_CREW_CONFIRMED=1 bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" remove 603
PLEX_CREW_CONFIRMED=1 bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" remove 603 --delete-files
```

**Salida:** `🗑️ Removed: The Matrix (1999) (files kept)` o, con la opción, `🗑️ Removed: The Matrix (1999) + deleted files` (código 0). Si la película no está en la biblioteca: `❌ Movie not found in library` (código 1). La opción solo se reconoce como segundo argumento.

### Detalles de una colección

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" collection-info 2344
```

**Salida:** el JSON indentado (`jq`) de la colección de `/collection` cuyo `tmdbId` coincide. Si Radarr no la conoce, no imprime nada (código 0).

### Consultar el log

Solo lectura.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" logs
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" logs 20 --level error
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" logs 100 --grep "rootfolder"
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" logs --files
```

Opciones, en cualquier orden:
- `N`: número de entradas, entero de 1 a 1000 (50 por defecto)
- `--level <nivel>`: `trace`, `debug`, `info`, `warn`, `error` o `fatal` (admite mayúsculas)
- `--grep <texto>`: solo entradas cuyo mensaje o logger contiene el texto, sin distinguir mayúsculas
- `--files`: lista los ficheros de log; ignora `--level` y `--grep`

**Salida:** una línea por entrada, la más antigua primero: `<time>  <LEVEL>  <logger>  <mensaje>` (separadores de dos espacios; `?` si falta time, level o logger; nivel en mayúsculas y de 5 letras como máximo). Del mensaje solo se muestra la primera línea, con los valores de `api_key`, `apikey`, `token`, `passkey`, `password` y `secret` en pares `clave=valor` sustituidos por `***`, y se trunca a 200 caracteres más `...`. Con `--files`: `<lastWriteTime>  <filename>` por fichero. Argumentos no válidos imprimen `ERROR:` (y el uso, salvo en un nivel no válido) por stderr y terminan con 1 antes de llamar a Radarr; si el servicio no expone `/log`, `ERROR: respuesta inesperada de /log (¿el servicio no expone el endpoint?)`.

## Flujo de trabajo

1. **"Añade X a Radarr"** → `search "X"`, muestra la lista numerada y deja elegir
2. Toma el `tmdbId` del enlace elegido y ejecuta `exists <tmdbId>`; si ya existe, avisa y no añadas
3. Ejecuta `config` para ver los perfiles y confirma con el usuario perfil y búsqueda
4. Tras la confirmación, ejecuta `add <tmdbId> [profileId] [--no-search]`
5. **"Añade la saga X"** → `search`, toma el id de la colección, confirma cuántas películas se añaden y ejecuta `add-collection`
6. **"Quita X"** → `exists`, doble confirmación, pregunta por los ficheros y `PLEX_CREW_CONFIRMED=1 ... remove`

## Parámetros

| Argumento | Comandos | Notas |
|-----------|----------|-------|
| `<texto>` | search, search-json | Solo el primer argumento; entrecomíllalo |
| `<tmdbId>` | exists, add, remove | Entero de TMDB |
| `<idColeccionTmdb>` | add-collection, collection-info | Entero de TMDB de la colección |
| `[perfilId]` | add | Entero; segundo argumento; por defecto `RADARR_DEFAULT_QUALITY_PROFILE` o 1 |
| `[término]` | add-collection | Segundo argumento; solo si la colección no está en Radarr |
| `--no-search` | add, add-collection | En cualquier posición; no lanza la búsqueda |
| `--delete-files` | remove | Solo como segundo argumento; borra los ficheros del disco |
| `[N]`, `--level`, `--grep`, `--files` | logs | Ver el apartado del log |

## Notas

- Nunca imprimas `RADARR_API_KEY` ni uses `curl` con la clave en línea: usa siempre el script.
- Timeouts: `search`, `status` y `logs` 25 s (librería compartida); el resto, 10 s de conexión y 30 s en total, sin reintentos.
- El usuario trabaja en Europe/Madrid (regla global en `plex-crew-rules`).

### Limitaciones conocidas

- `add` y `add-collection` no comprueban el código HTTP de la alta: si Radarr la rechaza (película ya existente, perfil inexistente), imprimen `❌ ...` pero terminan con código 0. `add` no avisa de que la película ya existía; comprueba antes con `exists`.
- `add` no comprueba que el lookup devolvió una película válida: con un `tmdbId` inexistente envía igualmente el alta y sale `❌ Failed to add movie`.
- `add` y `add-collection` usan siempre la primera carpeta raíz de `/rootfolder` y `monitored: true`; no se pueden elegir carpeta, disponibilidad mínima ni etiquetas. `add` no valida el perfil contra `/qualityprofile`; `add-collection` ignora `RADARR_DEFAULT_QUALITY_PROFILE` y usa el primer perfil de la lista.
- `add-collection`: si la colección ya figura en Radarr, se ignora el término dado. En `add-collection 2344 --no-search` el `--no-search` se toma también como término (solo importa si la colección no figura en Radarr: la búsqueda fallará con `❌ No movies found ...`). Las películas salen del lookup de Radarr con ese término, así que una colección grande se limita a lo que devuelva. Siempre activa `searchOnAdd` al monitorizar la colección, aun con `--no-search`, y si ese paso falla no hay mensaje.
- `remove` no comprueba el código HTTP del borrado: imprime `🗑️ Removed` aunque Radarr lo rechace. Verifica con `exists`. No marca la exclusión de importación.
- `exists` compara el cuerpo con `[]` exacto, de modo que una respuesta de error (por ejemplo HTTP 401) cuenta como `exists` y la línea de datos falla o sale vacía; `config` con una respuesta de error falla con un error de jq.
- `search` imprime todos los resultados del lookup, sin sinopsis; `search-json` devuelve el JSON completo.
- `logs`: el enmascarado solo cubre pares `clave=valor` con las seis claves indicadas (no JSON, cabeceras ni `Bearer`); `--grep` compara con el texto sin enmascarar, solo ve las `min(N*20, 1000)` entradas más recientes y la comparación sin mayúsculas es solo ASCII; solo se muestra la primera línea de cada mensaje.
- Las llamadas directas no distinguen la causa del fallo de curl (el mensaje es único); solo `search`, `status` y `logs` informan del código HTTP.
- `search`, `status` y `logs` usan la librería compartida: la clave queda en la línea de comandos de curl (visible en `ps`). El resto la pasa por stdin.
- La barra final de `RADARR_URL` no se quita y da `//api/v3`.
- No hay comandos de calendario, cola, historial, importación, refresh ni búsqueda de releases.

## Referencia

- [API de Radarr](https://radarr.video/docs/api/)
- [TMDB](https://www.themoviedb.org/)

Para la referencia local detallada, consulta:
- **[Endpoints de la API](./references/api-endpoints.md)** - Comando del script, método, ruta y cuerpos de las altas
- **[Referencia rápida](./references/quick-reference.md)** - Configuración y ejemplos para copiar y pegar
- **[Resolución de problemas](./references/troubleshooting.md)** - Autenticación, conexión y uso
