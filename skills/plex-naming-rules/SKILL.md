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
Formatos estándar tipo Sonarr, aprobados por el usuario el 2026-10-16. Son nombres de FICHERO de episodio de series; sirven como ejemplos de referencia.

Formato de episodio estándar
- Episodio individual: `The Series Title's! (2010) - S01E01 - Episode Title 1 [Surround Sound x264][WEBDL-1080p Proper][DTS 5.1][AVC]-RlsGrp`
- Multi-episodio: `The Series Title's! (2010) - S01E01-E03 - Episode Title [Surround Sound x264][WEBDL-1080p Proper][DTS 5.1][AVC]-RlsGrp`

Formato de episodio diario
- Ejemplo: `The Series Title's! (2010) - 2013-10-30 - Episode Title 1 [Surround Sound x264][WEBDL-1080p Proper][DTS 5.1][AVC]-RlsGrp`

Formato de episodio de Anime
- Episodio individual: `The Series Title's! (2010) - S01E01 - 001 - Episode Title 1 [Surround Sound x264][WEBDL-1080p v2][DTS 5.1][JA][AVC 10bit]-RlsGrp`
- Multi-episodio: `The Series Title's! (2010) - S01E01-E03 - 001-003 - Episode Title [Surround Sound x264][WEBDL-1080p v2][DTS 5.1][JA][AVC 10bit]-RlsGrp`

Partes del nombre:
- `The Series Title's! (2010)`: título de la serie y año, igual que en la carpeta (sin id; las series no llevan id).
- `S01E01`: temporada y episodio, dos dígitos como mínimo (`E100` o más con tres). Suelto, sin corchetes propios.
- `S01E01-E03`: multi-episodio, del primero al último episodio del fichero.
- `2013-10-30`: fecha de emisión (`AAAA-MM-DD`), para series diarias en lugar de `SxxExx`.
- `001` / `001-003`: numeración absoluta del episodio (o rango), solo en anime, tras `SxxExx`.
- `Episode Title`: título del episodio.
- `[Surround Sound x264]`, `[WEBDL-1080p Proper]`, `[DTS 5.1]`, `[AVC]`: etiquetas de calidad, origen, versión (`Proper`, `v2`), audio y códec de vídeo (`AVC 10bit` en anime).
- `[JA]`: idioma del audio, solo en el ejemplo de anime.
- `-RlsGrp`: grupo de release, pegado al final con guion, sin corchetes.

Reglas de aplicación:
- La carpeta de la serie es `Título (Año)` (con las etiquetas de idioma/calidad permitidas); las series no llevan id, ni en la carpeta ni en el fichero.
- El título del episodio y cada etiqueta se ponen solo si se conocen. No inventes nada (ver "Calidad en el nombre").
- Si falta una pieza, se omite entera junto con su separador, sin dejar huecos ni corchetes vacíos.

### Conflictos con convenciones previas
Pendientes de decisión del usuario. Hasta que los resuelva, no apliques estos formatos de forma masiva ni cambies nombres ya existentes por esta causa.
1. Idioma: el ejemplo de anime usa `[JA]` (código corto); hasta ahora se usan etiquetas en español como `[Castellano]` o `[Japones]`. Falta decidir qué convención rige para el idioma en el fichero.
2. Grupo de release: `-RlsGrp` al final frente a etiquetas de release entre corchetes como `[ZEA]` usadas hasta ahora. Falta decidir si el grupo va como sufijo con guion o entre corchetes.
3. Etiquetas de calidad: `[WEBDL-1080p Proper]`, `[Surround Sound x264]`, `[AVC]` frente a las vigentes (`[HDTV 720p][AC3 5.1 Castellano]`, validadas con ffprobe). `Proper`, `v2`, `Surround Sound` y el origen (WEBDL) no se pueden validar con ffprobe; falta decidir si se admiten solo cuando el release original las define.
4. Orden y separadores: el patrón vigente es `Serie (Año) - SxxExx [calidad].ext` (sin título de episodio); los nuevos añaden ` - Título` entre `SxxExx` y las etiquetas. Falta confirmar que el título de episodio pasa a ser parte del patrón vigente y del patrón de corrección.
5. Episodios diarios: el formato por fecha no lleva `SxxExx`, lo que choca con la regla de "todo episodio como SxxExx" (y con la conversión de `cap.NNN`). Falta decidir cuándo una serie se trata como diaria.
6. Anime y especiales: la numeración absoluta `001` convive con `SxxExx`, pero no está definido cómo se numera un especial de anime (`S00Exx` en `Season 00` según TVDB frente a numeración absoluta). Falta decidirlo.

### Formato de película
Formato estándar de nombre de FICHERO de película, aprobado por el usuario el 2026-10-16. Sirve como ejemplo de referencia.

Formato de película estándar
- Ejemplo: `The Movie Title (2010) {tmdb-345691} - {edition-Ultimate Extended Edition} [3D][Surround Sound x264][Bluray-1080p Proper][DTS 5.1][AVC]-EVOLVE`
- Nota: el id debe ser siempre el de TMDB (`{tmdb-#######}`), nunca IMDb ni TVDB (decisión del usuario, 2026-10-16).

Partes del nombre:
- `The Movie Title`: título de la película.
- `(2010)`: año de estreno entre paréntesis.
- `{tmdb-345691}`: id de TMDB entre llaves (nunca corchetes), como en la carpeta.
- `- {edition-Ultimate Extended Edition}`: edición con la sintaxis de Plex `{edition-Nombre}` (Plex Pass; nombre de hasta 32 caracteres). Solo si la película tiene una edición distinta de la estándar.
- `[3D]`: etiqueta de formato de vídeo.
- `[Surround Sound x264]`, `[Bluray-1080p Proper]`, `[DTS 5.1]`, `[AVC]`: etiquetas de códec, origen y calidad (con versión `Proper`), audio y vídeo.
- `-EVOLVE`: grupo de release, pegado al final con guion, sin corchetes.

Verificado en support.plex.tv (artículo "Multiple Editions"): la edición es `{edition-Nombre}` y la documentación la ilustra justo antes de la extensión: `Blade Runner (1982) {edition-Director's Cut}.mp4`. Con una carpeta por película, la edición puede ir en la carpeta, en el fichero o en ambos (Plex recomienda ambos). La documentación no muestra la edición seguida de más etiquetas ni su posición respecto al id (no verificado; el artículo devolvió 403 al leerlo directamente y se contrastó por búsqueda).

Reglas de aplicación:
- La carpeta de la película es `Título (Año) {tmdb-#######}`; el id va en la carpeta Y en el fichero (y en hermanos como subtítulos).
- Edición, título y cada etiqueta se ponen solo si hay evidencia (nombre original o ffprobe). No inventes nada (ver "Calidad en el nombre").
- Si falta una pieza, se omite entera junto con su separador, sin huecos ni corchetes vacíos.

### Conflictos del formato de película
Pendientes de decisión del usuario. Hasta que los resuelva, no apliques este formato de forma masiva ni cambies nombres ya existentes por esta causa.
1. Posición de la edición: el ejemplo pone `{tmdb-...} - {edition-...} [etiquetas]-GRUPO`, pero la documentación de Plex solo ilustra la edición inmediatamente antes de la extensión. Falta confirmar que Plex la lee con etiquetas y grupo detrás, y la posición del id respecto a `{edition-...}` (la regla vigente pide el id al final del nombre).
2. Id al final: la regla vigente dice que el id va al FINAL del nombre; en el ejemplo el id queda antes de la edición, las etiquetas y el grupo. Falta decidir si esta regla se relaja para ficheros de película.
3. Grupo de release: `-EVOLVE` con guion frente a etiquetas conservadas hasta ahora como `MUSAKOLA` o `[www.nucleohd.com]`. Falta decidir si se unifica como sufijo con guion.
4. Etiquetas no verificables: `Proper`, `3D`, `Surround Sound` y el origen (`Bluray`) no se pueden validar con ffprobe; falta decidir si se admiten solo cuando el release original las define (regla vigente de calidad con evidencia).
5. Idioma: el ejemplo no lleva etiqueta de idioma; las convenciones previas usan `[Castellano]`. Falta decidir si el idioma va en el fichero de película y cómo.
6. Separador: ` - ` entre id y edición frente al patrón vigente de película `Título (Año) {tmdb-#######}.ext`. Falta decidir si el guion es parte del patrón.

### Identificadores
- El id que se escribe en los nombres es SIEMPRE el de TMDB, con la sintaxis `{tmdb-#######}`. Nunca `{imdb-...}` ni `{tvdb-...}` (decisión del usuario, 2026-10-16, sustituye a la regla "IMDb únicamente"). Siempre llaves; con corchetes Plex los ignora. imdb/tvdb solo sirven para buscar o emparejar (`set_external_id`, lookups), no para escribirlos en el nombre.
- Un solo id por nombre.
- **Regla (2026-10-16, decisión del usuario): SERIES, sin id, ni en la carpeta ni en los ficheros. PELÍCULAS, `{tmdb-#######}` en la carpeta Y en el fichero (y en sus ficheros hermanos, como subtítulos, si los hay).**
- Si una película no tiene id de TMDB conocido, consúltalo (Guid `tmdb://` de Plex con `metadata`, lookup de Radarr o Seerr) o pregunta al usuario. Nunca pongas otro tipo de id como alternativa. En series no hay nada que consultar.
- En películas el id va al FINAL del nombre de la carpeta, nunca al principio.
- Carpeta de serie: `Serie (Año)`. Puede llevar idioma y calidad en corchetes tras el año: `Serie (Año) [Castellano][1080p]`. Cada etiqueta solo se añade si TODOS los archivos de la serie comparten ese mismo idioma / esa misma calidad; si difieren, se omite (puede ir una y no la otra, p. ej. calidad sí e idioma no).
- Riesgo (proyecto): sin id en series, Plex empareja por título y año. Ante un emparejado dudoso usa el flujo de corrección en Plex (`match_release`, `set_external_id`, rematch), que no depende del nombre.
- Alcance: la regla se aplica solo a lo que se nombre desde ahora; no se renombra la biblioteca local existente, que conserva los ids ya puestos.
- La carpeta `Season` va siempre en inglés (`Season 01`).

### Calidad en el nombre
- Añade la calidad entre corchetes después de `SxxExx` (`[HDTV 720p][AC3 5.1 Castellano]`) solo si el nombre original ya la define; no se comprueba contra el fichero.
- Si el original no define calidad, no la inventes.
- Idioma: `spa` en los metadatos; "Castellano" procede del nombre del release original.

### Patrón de corrección estándar (temporada o release mal nombrado)
`Serie (Año) - SxxExx [calidad].ext`, sin id

Aplícalo a **todos** los episodios del release en una sola pasada, no solo al roto: los hermanos suelen compartir el mismo tipo de error (corchetes sueltos, espacio antes de la extensión, mayúsculas inconsistentes). Termina con una tabla: episodio, nombre completo, directorio (movies/shows).

## Flujo de trabajo

### Ante un emparejado erróneo en Plex
1. **Detecta**: compara el título y el año esperados (del nombre de la carpeta) con los que muestra Plex, usando la skill `plex` (`search` o `metadata`). Marca solo las identidades distintas, no las diferencias cosméticas ("Big Bang" frente a "The Big Bang Theory" es correcto).
2. **Renombra**: renombra carpeta y fichero con el nombre completo; el id de TMDB va al final de carpeta y fichero solo en películas (series sin id). Plex solo vuelve a emparejar con una ruta nueva. Si el nombre no basta (series sin id), corrige en Plex con `match_release`, `set_external_id` y rematch.
3. **Verifica** con la skill `plex`: título y año correctos.

## Ejemplos

```text
Carpeta:   Mi Serie (2015)
Fichero:   Mi Serie (2015) - S01E02 [HDTV 720p][AC3 5.1 Castellano].mkv
Película:  Mi Película (2010) {tmdb-123456}/Mi Película (2010) {tmdb-123456}.mkv
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
