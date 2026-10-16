---
name: plex-naming-rules
description: Esta skill debe usarse al nombrar o renombrar contenido de Plex. Úsala cuando el usuario pida "renombrar una serie", "renombrar episodios", "normalizar nombres", "este título está mal emparejado en Plex", "añadir el id de imdb", "añadir {imdb-...}", "corregir el nombre de una temporada", "cap.101" o "especiales S00", o mencione el nombrado de Plex o la identificación de contenido.
---

# Skill de reglas de nombrado Plex

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando se dé CUALQUIERA de estas situaciones:**
- "renombrar una serie o película", "renombrar episodios", "normalizar nombres de carpetas o ficheros"
- "este título está mal emparejado en Plex", "Plex lo identifica mal", "corregir un emparejado"
- "añadir el id de imdb", "añadir {imdb-...}", "falta el año o el id en la carpeta"
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

### Identificadores
- El id del nombre es SIEMPRE el de IMDb, con la sintaxis `{imdb-tt#######}`. Nunca `{tmdb-...}` ni `{tvdb-...}` (decisión del usuario, 2026-10-16). Siempre llaves; con corchetes Plex los ignora.
- Un solo id por nombre.
- Si la obra no tiene id de IMDb conocido, averígualo antes de renombrar (Guid de Plex con `metadata`, lookup de Sonarr/Radarr, `external_ids` de TMDB) o pregunta al usuario. Nunca pongas otro tipo de id en el nombre como alternativa. Los ids de TMDB y TVDB solo sirven para buscar o emparejar, no para escribirlos en el nombre.
- **Regla (2026-10-16, decisión del usuario): el id `{imdb-tt#######}` va SOLO en el nombre de la carpeta padre (carpeta de serie o carpeta de película) y NUNCA en los nombres de los ficheros de dentro (episodios, ficheros de película, subtítulos, etc.).** Vale igual para series y películas.
- El id va al FINAL del nombre de la carpeta, nunca al principio.
- Carpeta de serie: `Serie (Año) {imdb-tt...}`. Puede llevar idioma y calidad en corchetes entre el año y el id: `Serie (Año) [Castellano][1080p] {imdb-tt#######}`. Cada etiqueta solo se añade si TODOS los archivos de la serie comparten ese mismo idioma / esa misma calidad; si difieren, se omite (puede ir una y no la otra, p. ej. calidad sí e idioma no). El id sigue al final, con llaves.
- La carpeta `Season` va siempre en inglés (`Season 01`).

### Calidad en el nombre
- Añade la calidad entre corchetes después de `SxxExx` (`[HDTV 720p][AC3 5.1 Castellano]`) solo si el nombre original ya la define; no se comprueba contra el fichero.
- Si el original no define calidad, no la inventes.
- Idioma: `spa` en los metadatos; "Castellano" procede del nombre del release original.

### Patrón de corrección estándar (temporada o release mal nombrado)
`Serie (Año) - SxxExx [calidad].ext`, con el id solo en la carpeta de la serie

Aplícalo a **todos** los episodios del release en una sola pasada, no solo al roto: los hermanos suelen compartir el mismo tipo de error (corchetes sueltos, espacio antes de la extensión, mayúsculas inconsistentes). Termina con una tabla: episodio, nombre completo, directorio (movies/shows).

## Flujo de trabajo

### Ante un emparejado erróneo en Plex
1. **Detecta**: compara el título y el año esperados (del nombre de la carpeta) con los que muestra Plex, usando la skill `plex` (`search` o `metadata`). Marca solo las identidades distintas, no las diferencias cosméticas ("Big Bang" frente a "The Big Bang Theory" es correcto).
2. **Renombra**: renombra carpeta y fichero con el nombre completo; el id de IMDb va solo al final de la carpeta padre, no en el fichero. Plex solo vuelve a emparejar con una ruta nueva.
3. **Verifica** con la skill `plex`: título y año correctos.

## Ejemplos

```text
Carpeta:   Mi Serie (2015) {imdb-tt1234567}
Fichero:   Mi Serie (2015) - S01E02 [HDTV 720p][AC3 5.1 Castellano].mkv
Película:  Mi Película (2010) {imdb-tt7654321}/Mi Película (2010).mkv
Especial:  Mi Serie (2015) {imdb-tt1234567}/Season 00/Mi Serie (2015) - S00E01.mkv
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
