---
name: arr-language-filters
description: Esta skill debe usarse al diagnosticar el filtrado de idioma en el stack de adquisición. Úsala cuando el usuario pregunte "por qué se descargó en otro idioma", "por qué se rechaza este release", "por qué no aparece este título", "falso positivo o negativo del filtro de idioma", "MinFormatScore", "perfil Español o VOSE", "Audio-ES", "RD-Bloqueado", "Torrentio devuelve Fight Club", o pida sincronizar las carpetas del mount con Radarr.
---

# Skill de filtros de idioma de adquisición

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando se dé CUALQUIERA de estas situaciones:**
- "por qué se descargó en otro idioma", "por qué se rechaza este release", "por qué no aparece este título"
- "el filtro deja pasar algo que no debería" o "bloquea algo que está en español" (falsos positivos y negativos)
- "idioma", "filtros", "perfil Español o VOSE", "MinFormatScore", "Audio-ES", "RD-Bloqueado"
- "Torrentio devuelve resultados que no son" (Fight Club, Reacher) o búsquedas sin `imdbid`
- "sincronizar las carpetas del mount con Radarr"

**Si no invocas esta skill cuando se dan estas situaciones, incumples tus requisitos operativos.**

Explica cómo filtran el idioma los tres sistemas de adquisición del stack y qué límites conocidos tienen.

## Propósito

Esta skill permite diagnosticar por qué un título se descarga, se rechaza o no aparece:
- Reglas de idioma de cli_debrid
- Perfiles y Custom Formats de Radarr y Sonarr
- Fallo de la búsqueda por texto en Torrentio
- Flujo para sincronizar las carpetas del mount con Radarr

Tres sistemas independientes. Objetivo común: **audio en español**. Un release con subtítulos en español pero audio en otro idioma no es lo que se quiere.

## Configuración

Sin variables de entorno. Se combina con las skills de servicio (`radarr`, `prowlarr`, `cli_debrid`), cada una de las cuales documenta sus propias variables.

## Reglas

### cli_debrid
- Binario, sin tolerancia: `filter_in` exige `spa|esp|spanish|castellano` en el nombre. Sin esa palabra no pasa y no hay fallback a inglés.
- `filter_out` rechaza los releases etiquetados subs/VOSE que no sean también en español.
- Series y películas: si el nombre tiene "sub", "subs", "subtítulos" o "vose", esa palabra debe ir a la **derecha** de la palabra en español. "español...subs" es audio en español con subs y se acepta; "subs...español" se rechaza.
- Las series añaden `cap[. ]?\d+` en `filter_in` (acepta `Cap.101`). El anime añade `wolfmax` y solo filtra por idioma, sin la regla de posición de los subs.
- Scrapers: `Prowlarr_1` (a través de Prowlarr, no usa el Torrentio de Prowlarr) y `Torrentio_2` (conexión directa propia).
- Un título que solo llega por las fuentes propias de cli_debrid y no tiene copia en español en ningún indexer se queda sin descargar.

### Radarr y Sonarr
- Un único perfil de calidad "Español" (id 7) y un perfil VOSE (id 8).
- Custom Format `Audio-ES` (+100): palabra en español en el título, tamaño máximo 25 GB (una cifra elegida por el usuario, independiente de los límites de Prowlarr/zurg) y que no sea solo subtitulado. `VOSE` (0) detecta subtítulos en español sin audio en español.
- `MinFormatScore: 100` es un **bloqueo duro intencionado**: obliga a que se cumpla `Audio-ES`. Los grabs con score 0 en el historial vienen de una configuración anterior.
- `RD-Bloqueado` (-10000) es un apaño para un bloqueo **real** de Real-Debrid (error de API 35, `infringing_file`) en nombres que contienen `WEB-DL`, `WEBRip`, `BDRip`, `HDRip`, `DVDRip`, `BluRay.x264`, `HDTV.x264`, `HDTV.XviD`, `WEB.x264`, `WEB.h264`. REMUX y x265 no están en esa lista, así que no es un agujero. cli_debrid no lo necesita porque reintenta por su cuenta con otro candidato; Radarr y Sonarr no.
- Cambiar el perfil de una serie existente se hace con un PUT sobre la serie (`qualityProfileId`), no con `add`.

### Torrentio en Prowlarr
- La definición personalizada declara `search: [q]`, pero Torrentio solo funciona por id de IMDb/Kitsu. Una búsqueda de texto libre sin `imdbid` devuelve resultados de un id de validación fijo (Fight Club para películas, Reacher para series).
- **No repitas** el arreglo de quitar `search: [q]` del yml: rompe todo el indexer (la definición deja de existir y la búsqueda por id también falla). Se probó y se revirtió.
- Mitigación que funciona: asegúrate de que toda búsqueda en Torrentio lleve `imdbid` desde el origen.

## Flujo de trabajo

### Sincronizar las carpetas del mount con Radarr
Cuando hay que renombrar las carpetas del mount a `Title (Year)` para que Library Import las enlace:
1. Lotes de 100 por defecto, con un fichero de seguimiento para no reprocesar.
2. Duplicados: conserva el confirmado en español con la mayor resolución; deja intactas las demás copias.
3. Título o año ambiguo sin certeza: ignóralo e infórmalo al final del lote con el motivo; no preguntes uno a uno. Heurística: la biblioteca no suele tener películas anteriores a 1980.
4. Año erróneo en la carpeta: corrígelo al año real de IMDb/TMDB. Si el destino ya existe, no sobrescribas.
5. Packs con varias películas: sepáralos en `Title (Year)/Title (Year).ext` solo si tienes certeza de qué es cada fichero.
6. Informa de cada lote al detalle (duplicados resueltos, ignorados, años corregidos).

### Ejemplos de diagnóstico
```bash
# Lectura: ver si Radarr ya conoce la película y su configuración (perfiles, carpetas raíz)
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" exists 603
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" config

# Lectura: buscar candidatos por imdbid (evita el fallo de texto libre de Torrentio)
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" movie-search --imdb tt0133093
```

## Notas

- Es documentación de comportamiento y decisiones: los ids de perfil (7, 8) y los scores son los de este stack y pueden cambiar si se reconfigura Radarr/Sonarr
- Ninguna parte de la skill modifica la configuración por sí misma

## Referencia

Para la referencia local detallada, consulta:
- **[Referencia rápida](./references/quick-reference.md)** - Filtros de cada sistema de un vistazo
- **[Resolución de problemas](./references/troubleshooting.md)** - Por qué un título se rechaza, falta o está en el idioma equivocado

## Lo que NO hay que hacer

- No repitas el arreglo de quitar `search: [q]` de la definición de Torrentio: rompe todo el indexer
- No bajes `MinFormatScore` ni cambies los perfiles (ids 7 y 8) para "arreglar" un rechazo sin confirmarlo con el usuario: el bloqueo es intencionado
- No propongas un fallback a inglés en cli_debrid: el filtro binario es deliberado
- Esta skill solo documenta: no modifica la configuración por sí misma
