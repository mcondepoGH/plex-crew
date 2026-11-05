---
name: arr-language-filters
description: Esta skill debe usarse al diagnosticar el filtrado de idioma en el stack de adquisición. Úsala cuando el usuario pregunte "por qué se descargó en otro idioma", "por qué se rechaza este release", "por qué no aparece este título", "falso positivo o negativo del filtro de idioma", "minFormatScore", "perfil de calidad", "formato personalizado de idioma", "Torrentio devuelve Fight Club", o pida sincronizar las carpetas del mount con Radarr.
---

# Skill de filtros de idioma de adquisición

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando se dé CUALQUIERA de estas situaciones:**
- "por qué se descargó en otro idioma", "por qué se rechaza este release", "por qué no aparece este título"
- "el filtro deja pasar algo que no debería" o "bloquea algo que está en español" (falsos positivos y negativos)
- "idioma", "filtros", "perfil de calidad", "minFormatScore", "formato personalizado de idioma"
- "Torrentio devuelve resultados que no son" (Fight Club, Reacher) o búsquedas sin `imdbid`
- "sincronizar las carpetas del mount con Radarr"

**Si no invocas esta skill cuando se dan estas situaciones, incumples tus requisitos operativos.**

Explica cómo diagnosticar el filtrado de idioma en los tres sistemas de adquisición del stack y qué límites conocidos tienen. Los perfiles, formatos personalizados y reglas de filtro son configuración propia de cada usuario: la skill describe el método, no asume ninguna configuración concreta.

## Propósito

Esta skill permite diagnosticar por qué un título se descarga, se rechaza o no aparece:
- Reglas de idioma de cli_debrid
- Perfiles y Custom Formats de Radarr y Sonarr
- Fallo de la búsqueda por texto en Torrentio
- Flujo para sincronizar las carpetas del mount con Radarr

Tres sistemas independientes. Pregunta común: ¿qué idioma de audio exige TU configuración? Un release con subtítulos pero sin audio en el idioma deseado puede colarse o rechazarse según cómo lo hayas configurado.

## Configuración

Sin variables de entorno. Se combina con las skills de servicio (`radarr`, `prowlarr`, `cli_debrid`), cada una de las cuales documenta sus propias variables.

## Reglas

### cli_debrid
- El filtrado es binario: un release pasa o no pasa las reglas `filter_in` (patrones que el nombre debe contener) y `filter_out` (patrones que lo rechazan). Consulta las que tengas configuradas por tipo de contenido (series, películas, anime): pueden diferir.
- Si tus reglas tratan palabras de subtítulos ("sub", "subs", "vose"...) según su posición respecto a la palabra de idioma, comprueba ese orden en el nombre del release.
- No hay fallback a otro idioma: un título que solo llega por las fuentes propias de cli_debrid y no tiene copia que cumpla `filter_in` en ningún indexer se queda sin descargar.
- Revisa qué scrapers tienes activos y de dónde sale cada candidato.

### Radarr y Sonarr
- Lista tus perfiles con `qualityprofiles` y tus formatos personalizados con `customformats` (skills `radarr` y `sonarr`): `qualityprofiles` muestra por perfil el `minFormatScore` y la puntuación de cada formato.
- Un release solo se acepta si la suma de puntuaciones de sus formatos alcanza el `minFormatScore` de tu perfil. Si ese mínimo es mayor que 0, funciona como bloqueo duro: un release que no cumpla el formato de idioma que lo aporta se rechaza.
- Los grabs con puntuación inferior al mínimo actual en el historial pueden venir de una configuración anterior del perfil.
- Si un servicio externo (p. ej. un debrid) bloquea ciertos nombres, un formato personalizado con puntuación muy negativa es una forma de evitar esos grabs; compruébalo en tus formatos, no se asume.
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

- Es documentación del método de diagnóstico: perfiles, formatos, ids y puntuaciones son configuración de cada usuario; consúltalos siempre con las skills de servicio
- Ninguna parte de la skill modifica la configuración por sí misma

## Referencia

Para la referencia local detallada, consulta:
- **[Referencia rápida](./references/quick-reference.md)** - Filtros de cada sistema de un vistazo
- **[Resolución de problemas](./references/troubleshooting.md)** - Por qué un título se rechaza, falta o está en el idioma equivocado

## Lo que NO hay que hacer

- No repitas el arreglo de quitar `search: [q]` de la definición de Torrentio: rompe todo el indexer
- No bajes el `minFormatScore` ni cambies perfiles o formatos para "arreglar" un rechazo sin confirmarlo con el usuario: puede ser un bloqueo intencionado
- No propongas un fallback a otro idioma en cli_debrid sin confirmarlo con el usuario: el filtro binario puede ser deliberado
- Esta skill solo documenta: no modifica la configuración por sí misma
