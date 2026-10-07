# arr-language-filters

Explica cómo filtran el idioma cli_debrid, Radarr/Sonarr y Prowlarr/Torrentio en este stack, y sus límites conocidos. Objetivo común: audio en español (un subtitulado al español con audio en otro idioma no cuenta). No tiene scripts.

## Cuándo se usa

Al diagnosticar por qué un título se descarga, se rechaza o no aparece. La carga el agente `arr-acquisition`, que declara estas skills en su frontmatter (`skills:`):

- `arr-language-filters`
- `radarr`
- `sonarr`
- `prowlarr`
- `seerr`
- `cli_debrid`
- `plex`
- `tautulli`

## Reglas

Son tres sistemas independientes.

### cli_debrid

| Regla | Qué obliga | Cuándo aplica |
|-------|------------|---------------|
| `filter_in` binario | Exige en el nombre una de las palabras listadas bajo la tabla (`spa`, `esp`, `spanish`, `castellano`). Sin esa palabra no pasa y no hay fallback a inglés. | Toda release. |
| `filter_out` | Rechaza releases etiquetadas subs/VOSE que no sean también español. | Toda release. |
| Posición de subs | Si el nombre lleva "sub", "subs", "subtítulos" o "vose", esa palabra debe ir a la derecha de la palabra española: "español...subs" se acepta, "subs...español" se rechaza. | Series y películas. |
| Series | Añaden `cap[. ]?\d+` en `filter_in` (acepta `Cap.101`). | Series. |
| Anime | Añade `wolfmax` y solo filtra por idioma, sin la regla de posición de subs. | Anime. |
| Scrapers | `Prowlarr_1` (vía Prowlarr, no usa el Torrentio de Prowlarr) y `Torrentio_2` (conexión directa propia). | Origen de candidatos. |
| Sin copia en español | Un título que solo llega por las fuentes propias y no tiene copia en español en ningún indexador se queda sin descargar. | Casos "no aparece". |

Palabras que exige `filter_in`:

- `spa`
- `esp`
- `spanish`
- `castellano`

### Radarr y Sonarr

| Regla | Qué obliga | Cuándo aplica |
|-------|------------|---------------|
| Perfiles | Perfil de calidad único "Español" (id 7) y un perfil VOSE (id 8). | Al añadir o cambiar perfil. |
| Custom Format `Audio-ES` (+100) | Palabra española en el título, tamaño máximo 25 GB (cifra elegida por el usuario, independiente de los topes de Prowlarr/zurg) y que no sea solo subtitulado. `VOSE` (0) detecta subtítulos en español sin audio español. | Puntuación de grabs. |
| `MinFormatScore: 100` | Bloqueo duro intencional: obliga a cumplir `Audio-ES`. Los grabs con score 0 del historial son de una configuración anterior. | Rechazos aparentes. |
| `RD-Bloqueado` (-10000) | Workaround de un bloqueo real de Real-Debrid (error API 35, `infringing_file`) sobre nombres que contengan alguno de los patrones listados justo debajo de la tabla. REMUX y x265 no están en la lista. cli_debrid no lo necesita porque reintenta con otro candidato; Radarr y Sonarr no. | Releases bloqueadas por RD. |
| Cambio de perfil de una serie | Se hace con PUT sobre la serie (`qualityProfileId`), no con `add`. | Series existentes. |

Patrones de nombre que cubre `RD-Bloqueado`:

- `WEB-DL`
- `WEBRip`
- `BDRip`
- `HDRip`
- `DVDRip`
- `BluRay.x264`
- `HDTV.x264`
- `HDTV.XviD`
- `WEB.x264`
- `WEB.h264`

### Torrentio en Prowlarr

- La definición custom declara `search: [q]`, pero Torrentio solo funciona por id IMDb/Kitsu. Una búsqueda de texto libre sin `imdbid` devuelve resultados de un id de validación fijo (Fight Club en películas, Reacher en series).
- No repetir el arreglo de quitar `search: [q]` del yml: rompe el indexador entero. Se probó y se revirtió.
- Mitigación válida: asegurar que toda búsqueda de Torrentio lleve `imdbid` desde el origen.

## Flujo: sincronizar carpetas del mount con Radarr

Para renombrar carpetas del mount a `Title (Year)` y que Library Import las enlace:

1. Lotes de 100 por defecto, con fichero de seguimiento para no reprocesar.
2. Duplicados: se queda el español confirmado de mayor resolución; las demás copias se dejan intactas.
3. Título o año ambiguo sin certeza: se ignora y se reporta al final del lote con el motivo, sin preguntar uno a uno. Heurística: la biblioteca no suele tener películas anteriores a 1980.
4. Año incorrecto: se corrige al año real de IMDb/TMDB. Si el destino ya existe, no se sobrescribe.
5. Packs con varias películas: se separan en `Title (Year)/Title (Year).ext` solo con certeza de qué es cada fichero.
6. Cada lote se reporta con detalle (duplicados resueltos, ignorados, años corregidos).

## Ejemplos de diagnóstico

Se combina con las skills de servicios (cada una documenta sus variables de entorno):

```bash
# Lectura: ver si Radarr ya conoce la película y qué ids de perfil existen
bash .claude/skills/radarr/scripts/radarr.sh exists 603
bash .claude/skills/radarr/scripts/radarr.sh config

# Lectura: buscar candidatos por imdbid (evita el bug de texto libre de Torrentio)
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh movie-search --imdb tt0133093

# Lectura: errores recientes de Radarr
bash .claude/skills/radarr/scripts/radarr.sh logs 50 error
```

## Notas y límites

- Es documentación de comportamiento y decisiones: los ids de perfil (7, 8) y las puntuaciones son los de este stack y pueden cambiar si se reconfigura Radarr/Sonarr.
- Ninguna parte de la skill modifica configuración por sí sola.
