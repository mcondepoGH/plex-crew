---
name: arr-language-filters
description: Cómo filtran el idioma cli_debrid, Radarr/Sonarr y Prowlarr/Torrentio en este stack, y límites conocidos. Úsala al diagnosticar por qué un título se descarga, se rechaza o no aparece.
---

# Filtros de idioma del stack de adquisición

Tres sistemas independientes. Objetivo común: **audio en español**. Un subtitulado al español con audio en otro idioma no es lo que se busca.

## cli_debrid
- Binario, sin tolerancia: `filter_in` exige `spa|esp|spanish|castellano` en el nombre. Sin esa palabra no pasa y no hay fallback a inglés.
- `filter_out` rechaza releases etiquetadas subs/VOSE que no sean también español.
- Series y películas: si el nombre lleva "sub", "subs", "subtítulos" o "vose", esa palabra debe ir a la **derecha** de la palabra española. "español...subs" es audio español con subs y se acepta; "subs...español" se rechaza.
- Series añaden `cap[. ]?\d+` en `filter_in` (acepta `Cap.101`). Anime añade `wolfmax` y solo filtra por idioma, sin la regla de posición de subs.
- Scrapers: `Prowlarr_1` (vía Prowlarr, no usa el Torrentio de Prowlarr) y `Torrentio_2` (conexión directa propia).
- Un título que solo llega por las fuentes propias de cli_debrid y no tiene copia en español en ningún indexador se queda sin descargar.

## Radarr y Sonarr
- Perfil de calidad único "Español" (id 7) y un perfil VOSE (id 8).
- Custom Format `Audio-ES` (+100): palabra española en el título, tamaño máximo 25 GB (cifra elegida por el usuario, independiente de los topes de Prowlarr/zurg) y que no sea solo subtitulado. `VOSE` (0) detecta subtítulos en español sin audio español.
- `MinFormatScore: 100` es un **bloqueo duro intencional**: obliga a cumplir `Audio-ES`. Los grabs con score 0 del historial son de una configuración anterior.
- `RD-Bloqueado` (-10000) es un workaround de un bloqueo **real** de Real-Debrid (error API 35, `infringing_file`) sobre nombres que contienen `WEB-DL`, `WEBRip`, `BDRip`, `HDRip`, `DVDRip`, `BluRay.x264`, `HDTV.x264`, `HDTV.XviD`, `WEB.x264`, `WEB.h264`. REMUX y x265 no están en esa lista, así que no es un agujero. cli_debrid no lo necesita porque reintenta solo con otro candidato; Radarr y Sonarr no.
- El cambio de perfil de una serie existente se hace con PUT sobre la serie (`qualityProfileId`), no con `add`.

## Torrentio en Prowlarr
- La definición custom declara `search: [q]` pero Torrentio solo funciona por id IMDb/Kitsu. Una búsqueda de texto libre sin `imdbid` devuelve resultados de un id de validación fijo (Fight Club para películas, Reacher para series).
- **No repetir** el arreglo de quitar `search: [q]` del yml: rompe el indexador entero (la definición deja de existir y la búsqueda con id también falla). Se probó y se revirtió.
- Mitigación que sí funciona: asegurar que toda búsqueda de Torrentio lleve `imdbid` desde el origen.

## Sincronizar carpetas del mount con Radarr
Cuando haya que renombrar carpetas del mount a `Title (Year)` para que Library Import las enlace:
- Lotes de 100 por defecto y fichero de seguimiento para no reprocesar.
- Duplicados: quédate con español confirmado y mayor resolución; las demás copias se dejan intactas.
- Título o año ambiguo sin certeza: ignóralo y repórtalo al final del lote con el motivo; no preguntes uno a uno. Heurística: la biblioteca no suele tener películas anteriores a 1980.
- Año incorrecto en la carpeta: corrige al año real de IMDb/TMDB. Si el destino ya existe, no sobrescribas.
- Packs con varias películas: sepáralos en `Title (Year)/Title (Year).ext` solo si sabes con certeza qué es cada fichero.
- Reporta cada lote con detalle (duplicados resueltos, ignorados, años corregidos).
