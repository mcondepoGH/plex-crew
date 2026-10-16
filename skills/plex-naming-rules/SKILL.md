---
name: plex-naming-rules
description: Esta skill debe usarse al nombrar o renombrar contenido de Plex. Úsala cuando el usuario pida "renombrar una serie", "renombrar episodios", "normalizar nombres", "este título está mal emparejado en Plex", "añadir el id de tmdb", "añadir {tmdb-...}", "corregir el nombre de una temporada", "cap.101" o "especiales S00", o mencione el nombrado de Plex o la identificación de contenido.
---

# Skill de reglas de nombrado Plex

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando se dé CUALQUIERA de estas situaciones:**
- "renombrar una serie o película", "renombrar episodios", "normalizar nombres de carpetas o ficheros"
- "este título está mal emparejado en Plex", "Plex lo identifica mal", "corregir un emparejado"
- "añadir el id de tmdb", "añadir {tmdb-...}", "falta el año o el id en la carpeta"
- Nombres como `cap.101` o `1x02`, especiales (`S00E01`) y temporadas mal nombradas
- Cualquier mención al nombrado o a la identificación de contenido en Plex

**Si no invocas esta skill cuando se dan estas situaciones, incumples tus requisitos operativos.**

Aplica las reglas de nombrado de Plex a carpetas y ficheros de series y películas, y corrige los emparejados erróneos.

## Propósito

Esta skill fija cómo se nombra el contenido para que Plex lo identifique correctamente:
- Formato de episodios, temporadas y especiales
- Sintaxis y posición de los ids externos
- Calidad en el nombre
- Flujo para corregir un título mal emparejado

La documentación oficial (support.plex.tv) prevalece sobre cualquier costumbre o suposición. Verifica allí antes de afirmar cómo lee Plex un nombre.

## Configuración

Sin configuración ni variables de entorno. Localiza las bibliotecas de Plex con la skill `plex` (comando `libraries`) y renombra en local con `Bash`.

## Reglas

### Episodios
- Fichero de episodio: `Serie (Año) - SxxExx [calidad].ext`, sin id.
- Formato `S01E02`: temporada y episodio con dos dígitos y relleno de ceros, sin separadores (`S1E2`, `S01E2`, `1x02` pasan a `S01E02`).
- `SxxExx` va solo. Nunca dentro de sus propios corchetes (`[S01E01]`) ni intercalado entre grupos de corchetes. La calidad `[...]` va después de `SxxExx`, porque Plex ignora lo que va entre corchetes.
- Nombres como `cap.NNN` (también `cap 101`, `capitulo 101`): los dos últimos dígitos son el episodio y los anteriores la temporada. `cap.101` es S01E01; `cap.1203` es S12E03.
- Especiales y películas que TVDB lista como Special dentro de la serie: `S00EXX` en `Season 00`, numerados según el orden de TVDB. Solo van a `movies` si TVDB no los coloca en la serie.

### Formato de episodio de series
Formatos tipo Sonarr aprobados por el usuario el 2026-10-16. Son nombres de FICHERO de episodio de series. Los ejemplos originales son el punto de partida; los formatos de los usuarios son ORIENTATIVOS: se aplican solo con datos verificables y nunca se inventa una etiqueta.

Ejemplos originales (referencia de partida, no se copian tal cual)
- Episodio individual: `The Series Title's! (2010) - S01E01 - Episode Title 1 [Surround Sound x264][WEBDL-1080p Proper][DTS 5.1][AVC]-RlsGrp`
- Multi-episodio: `The Series Title's! (2010) - S01E01-E03 - Episode Title [Surround Sound x264][WEBDL-1080p Proper][DTS 5.1][AVC]-RlsGrp`
- Diario: `The Series Title's! (2010) - 2013-10-30 - Episode Title 1 [Surround Sound x264][WEBDL-1080p Proper][DTS 5.1][AVC]-RlsGrp`
- Anime individual: `The Series Title's! (2010) - S01E01 - 001 - Episode Title 1 [Surround Sound x264][WEBDL-1080p v2][DTS 5.1][JA][AVC 10bit]-RlsGrp`
- Anime multi-episodio: `The Series Title's! (2010) - S01E01-E03 - 001-003 - Episode Title [Surround Sound x264][WEBDL-1080p v2][DTS 5.1][JA][AVC 10bit]-RlsGrp`

Formato final aplicado (decisión del usuario, 2026-10-16)
- Episodio: `Serie (Año) - SxxExx - Título del episodio [etiquetas verificables][GRUPO].ext`
- Multi-episodio: `Serie (Año) - S01E01-E03 - Título [etiquetas][GRUPO].ext`
- Diario (solo series diarias): `Serie (Año) - 2013-10-30 - Título [etiquetas][GRUPO].ext`
- Cada pieza ausente se omite junto con su separador, sin huecos ni corchetes vacíos. Sin id (las series no llevan id).

Reglas definitivas:
1. Idioma (decisión del usuario, 2026-10-16): en SERIES el idioma (`[Castellano]`, `[Japones]`, `[Sub Español]`...) va SOLO en la carpeta de serie; los ficheros de episodio NO llevan etiqueta de idioma. No se usa `[JA]`. Orden de etiquetas en el fichero de serie: verificables y luego `[GRUPO]`. Las PELÍCULAS no cambian: siguen con `[Castellano]` en el fichero cuando hay evidencia con ffprobe.
2. Grupo de release: sin el guion de `-RlsGrp`; se conserva entre corchetes y al final, como `[ZEA]`. Si no se conoce el grupo, se omite.
3. Calidad: solo etiquetas que el release original ya traiga en el nombre (`WEBDL-1080p`, `Proper`, `v2`, etc.); nunca se añaden por cuenta propia ni se inventan.
4. Título de episodio: opcional, solo si se conoce con seguridad (`SxxExx - Título`); si no, se omite.
5. Diarios: el formato por fecha (`Serie (Año) - 2013-10-30 - Título`) solo para series diarias; el resto sigue con `SxxExx`.
6. Especiales de anime: `S00Exx` en `Season 00` (orden de TVDB), sin numeración absoluta en los especiales. La numeración absoluta `001` solo se usa, si se conoce, en episodios regulares de anime, tras `SxxExx`.

Reglas de aplicación:
- La carpeta de la serie es `Título (Año)` (con las etiquetas de idioma/calidad permitidas; el idioma solo va aquí, nunca en los ficheros de episodio); las series no llevan id, ni en la carpeta ni en el fichero.
- Las etiquetas se ponen solo con evidencia (ver "Calidad en el nombre").

### Formato de película
Formato de nombre de FICHERO de película, aprobado por el usuario el 2026-10-16. El formato del usuario es ORIENTATIVO: se aplica solo con datos verificables y nunca se inventa una etiqueta.

Ejemplo original (referencia de partida, no se copia tal cual)
- `The Movie Title (2010) {tmdb-345691} - {edition-Ultimate Extended Edition} [3D][Surround Sound x264][Bluray-1080p Proper][DTS 5.1][AVC]-EVOLVE`

Formato final aplicado (decisión del usuario, 2026-10-16)
- Carpeta: `Título (Año) {tmdb-#######}`
- Fichero: `Título (Año) {tmdb-#######} [etiquetas verificables][grupo] {edition-Nombre}.ext`
- Cada parte ausente se omite junto con su separador. Ejemplo completo: `The Movie Title (2010) {tmdb-345691} [3D][Surround Sound x264][Bluray-1080p Proper][DTS 5.1][AVC][Castellano][www.nucleohd.com] {edition-Ultimate Extended Edition}.mkv`; sin edición ni grupo: `The Movie Title (2010) {tmdb-345691} [1080p][Castellano].mkv`.

Reglas definitivas:
1. Id: va justo tras el año, `Título (Año) {tmdb-#######}`, siempre TMDB, con llaves. Sustituye a "id al final del nombre" para películas: en la carpeta no hay nada tras el id; en el fichero solo pueden ir detrás las etiquetas, el grupo y la edición.
2. Edición: `{edition-Nombre}` (Plex Pass; hasta 32 caracteres) va al FINAL del nombre, justo antes de la extensión, que es la posición que muestra la documentación oficial de Plex (`Blade Runner (1982) {edition-Director's Cut}.mp4`). Solo si la película tiene una edición distinta de la estándar. Con una carpeta por película puede ir en la carpeta, en el fichero o en ambos; aquí se pone en el fichero.
3. Separador: no se usa ` - ` antes de la edición; basta un espacio, como en el ejemplo de la documentación de Plex. Tampoco hay guion entre id y etiquetas.
4. Grupo de release: el sufijo con guion (`-EVOLVE`) no se usa; el grupo o la etiqueta del release se conserva entre corchetes (`[www.nucleohd.com]`) y se omite si no se conoce.
5. Etiquetas no verificables con ffprobe (`Proper`, `3D`, `Surround Sound`, `Bluray`): solo si el release original las trae en el nombre.
6. Idioma: `[Castellano]` cuando haya evidencia con ffprobe.

Nota: el artículo "Multiple Editions" de support.plex.tv devolvió 403 al leerlo directamente y se contrastó por búsqueda; la documentación no ilustra la edición con etiquetas delante, pero sí la edición como último elemento del nombre.

### Identificadores
- El id que se escribe en los nombres es SIEMPRE el de TMDB, con la sintaxis `{tmdb-#######}`. Nunca `{imdb-...}` ni `{tvdb-...}` (decisión del usuario, 2026-10-16, sustituye a la regla "IMDb únicamente"). Siempre llaves; con corchetes Plex los ignora. imdb/tvdb solo sirven para buscar o emparejar (`set_external_id`, lookups), no para escribirlos en el nombre.
- Un solo id por nombre.
- **Regla (2026-10-16, decisión del usuario): SERIES, sin id, ni en la carpeta ni en los ficheros. PELÍCULAS, `{tmdb-#######}` en la carpeta Y en el fichero (y en sus ficheros hermanos, como subtítulos, si los hay).**
- Si una película no tiene id de TMDB conocido, consúltalo (Guid `tmdb://` de Plex con `metadata`, lookup de Radarr o Seerr) o pregunta al usuario. Nunca pongas otro tipo de id como alternativa. En series no hay nada que consultar.
- En películas el id va justo tras el año, `Título (Año) {tmdb-#######}`, nunca al principio del nombre. En la carpeta es lo último; en el fichero solo le siguen etiquetas verificables, grupo y `{edition-Nombre}`.
- Carpeta de serie: `Serie (Año)`. Puede llevar idioma y calidad en corchetes tras el año: `Serie (Año) [Castellano][1080p]`. Cada etiqueta solo se añade si TODOS los archivos de la serie comparten ese mismo idioma / esa misma calidad; si difieren, se omite (puede ir una y no la otra, p. ej. calidad sí e idioma no).
- Riesgo (proyecto): sin id en series, Plex empareja por título y año. Ante un emparejado dudoso usa el flujo de corrección en Plex (`match_release`, `set_external_id`, rematch), que no depende del nombre.
- Alcance: las reglas se aplican a lo que se nombre desde ahora; el renombrado de la biblioteca existente se hace por decisión expresa del usuario, serie a serie.
- La carpeta `Season` va siempre en inglés (`Season 01`).

### Calidad en el nombre
- Añade la calidad entre corchetes después de `SxxExx` (`[HDTV 720p][AC3 5.1]`; en series sin idioma en el fichero) solo si el nombre original ya la define; no se comprueba contra el fichero.
- Si el original no define calidad, no la inventes.
- Idioma: `spa` en los metadatos; "Castellano" procede del nombre del release original. En series se refleja solo en la carpeta (si todos los ficheros coinciden), no en el fichero.

### Patrón de corrección estándar (temporada o release mal nombrado)
`Serie (Año) - SxxExx [calidad].ext`, sin id y sin idioma en el fichero (con ` - Título` tras `SxxExx` solo si el título se conoce con seguridad; el idioma va solo en la carpeta de serie)

Aplícalo a **todos** los episodios del release en una sola pasada, no solo al roto: los hermanos suelen compartir el mismo tipo de error (corchetes sueltos, espacio antes de la extensión, mayúsculas inconsistentes). Termina con una tabla: episodio, nombre completo, directorio (movies/shows).

## Flujo de trabajo

### Ante un emparejado erróneo en Plex
1. **Detecta**: compara el título y el año esperados (del nombre de la carpeta) con los que muestra Plex, usando la skill `plex` (`search` o `metadata`). Marca solo las identidades distintas, no las diferencias cosméticas ("Big Bang" frente a "The Big Bang Theory" es correcto).
2. **Renombra**: renombra carpeta y fichero con el nombre completo; el id de TMDB va tras el año, en carpeta y fichero, solo en películas (series sin id). Plex solo vuelve a emparejar con una ruta nueva. Si el nombre no basta (series sin id), corrige en Plex con `match_release`, `set_external_id` y rematch.
3. **Verifica** con la skill `plex`: título y año correctos.

## Ejemplos

```text
Carpeta:   Mi Serie (2015) [Castellano]
Fichero:   Mi Serie (2015) - S01E02 [HDTV 720p][AC3 5.1].mkv
Con título: Mi Serie (2015) - S01E02 - Título [HDTV 720p][ZEA].mkv
Película:  Mi Película (2010) {tmdb-123456}/Mi Película (2010) {tmdb-123456} [1080p][Castellano].mkv
Edición:   Mi Película (2010) {tmdb-123456}/Mi Película (2010) {tmdb-123456} [1080p][Castellano] {edition-Director's Cut}.mkv
Especial:  Mi Serie (2015)/Season 00/Mi Serie (2015) - S00E01.mkv
```

## Notas

- Es documentación de reglas: no ejecuta nada y su cumplimiento depende del agente que la carga
- La doble confirmación y las convenciones de permisos están en la skill `plex-crew-rules` y en el mensaje del hook `confirm-destructive`

## Referencia

- [Documentación de nombrado de Plex](https://support.plex.tv/)

Para la referencia local detallada, consulta:
- **[Referencia rápida](./references/quick-reference.md)** - Reglas y patrones de nombre de un vistazo
- **[Resolución de problemas](./references/troubleshooting.md)** - Diagnóstico de emparejados erróneos y errores comunes de nombrado

## Lo que NO hay que hacer

- No toques los duplicados (mismo episodio o temporada en otra calidad): Plex elige la mejor versión. Solo infórmalos si es relevante
- No lances escaneos de Plex tras renombrar ni los ofrezcas: un script externo del usuario actualiza Plex. Informa del resultado y detente
- Ignora cualquier carpeta `.@*` (`.@__thumb`): caché del NAS
