# Referencia rápida de arr-language-filters

Filtros de cada sistema de un vistazo. Objetivo común: audio en español; los subtítulos en español por sí solos no cuentan.

## cli_debrid

| Regla | Qué exige | Cuándo aplica |
|-------|-----------|---------------|
| `filter_in` binario | El nombre debe contener `spa`, `esp`, `spanish` o `castellano`; si no, no pasa y no hay fallback a inglés | Todo release |
| `filter_out` | Rechaza los releases etiquetados subs/VOSE que no sean también en español | Todo release |
| Posición de los subs | "sub", "subs", "subtítulos" o "vose" deben ir a la derecha de la palabra en español: "español...subs" se acepta, "subs...español" se rechaza | Series y películas |
| Series | Añaden `cap[. ]?\d+` en `filter_in` (acepta `Cap.101`) | Series |
| Anime | Añade `wolfmax`; filtra solo por idioma, sin la regla de posición de los subs | Anime |
| Scrapers | `Prowlarr_1` (a través de Prowlarr) y `Torrentio_2` (conexión directa propia) | Fuentes de candidatos |

## Radarr y Sonarr

| Regla | Qué exige | Cuándo aplica |
|-------|-----------|---------------|
| Perfiles | "Español" (id 7) y VOSE (id 8) | Al añadir o cambiar de perfil |
| `Audio-ES` (+100) | Palabra en español en el título, máximo 25 GB y que no sea solo subtitulado; `VOSE` (0) detecta subtítulos en español sin audio en español | Puntuación del grab |
| `MinFormatScore: 100` | Bloqueo duro intencionado; obliga a `Audio-ES` | Rechazos aparentes |
| `RD-Bloqueado` (-10000) | Apaño para un bloqueo real de Real-Debrid (error de API 35, `infringing_file`); REMUX y x265 no están en la lista | Releases bloqueados por RD |
| Cambio de perfil de una serie existente | PUT sobre la serie (`qualityProfileId`), no `add` | Series existentes |

Patrones de nombre cubiertos por `RD-Bloqueado`: `WEB-DL`, `WEBRip`, `BDRip`, `HDRip`, `DVDRip`, `BluRay.x264`, `HDTV.x264`, `HDTV.XviD`, `WEB.x264`, `WEB.h264`.

## Torrentio en Prowlarr

- Torrentio solo funciona por id de IMDb/Kitsu; una búsqueda de texto libre devuelve un id de validación fijo (Fight Club para películas, Reacher para series)
- No quites `search: [q]` del yml: rompe todo el indexer
- Haz que toda búsqueda en Torrentio lleve `imdbid`

## Sincronización del mount con Radarr

1. Lotes de 100, con un fichero de seguimiento
2. Duplicados: conserva el confirmado en español con la mayor resolución
3. Ambiguos: ignóralos e infórmalos al final del lote (heurística: sin películas anteriores a 1980)
4. Año erróneo: corrígelo; no sobrescribas un destino existente
5. Packs con varias películas: sepáralos solo con certeza
6. Informa de cada lote al detalle
