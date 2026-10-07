---
name: plex-naming-rules
description: Reglas de nombrado de Plex para series, películas, especiales e identificadores. Úsala siempre que haya que renombrar carpetas o ficheros, arreglar un emparejado erróneo o añadir ids {imdb-...}.
---

# Reglas de nombrado Plex

La documentación oficial (support.plex.tv) manda sobre cualquier hábito o suposición. Verifica ahí antes de afirmar cómo Plex lee un nombre.

## Episodios
- Formato `S01E02`: temporada y episodio con dos dígitos y relleno de ceros, sin separadores (`S1E2`, `S01E2`, `1x02` pasan a `S01E02`).
- `SxxExx` va suelto. Nunca entre corchetes propios (`[S01E01]`) ni intercalado entre grupos de corchetes. Colócalo antes de todos los tags `[...]` de calidad.
- Nombres tipo `cap.NNN` (también `cap 101`, `capitulo 101`): los dos últimos dígitos son el episodio y los anteriores la temporada. `cap.101` es S01E01; `cap.1203` es S12E03.
- Especiales y películas que TVDB lista como Special dentro de la serie: `S00EXX` en `Season 00`, numerados en el orden de TVDB. Solo van a `movies` si TVDB no los ubica en la serie.

## Identificadores
- Sintaxis `{imdb-tt#######}`, `{tmdb-#####}` o `{tvdb-######}`. Llaves siempre; con corchetes Plex los ignora.
- Basta un id por nombre.
- El id va **al final** del nombre, en la carpeta y en cada fichero (antes de la extensión). Nunca al principio.
- Carpeta de serie limpia: `Serie (Año) {imdb-tt...}`, sin calidad ni texto extra antes del id.
- La carpeta `Season` va siempre en inglés (`Season 01`).

## Calidad en el nombre
- Añade la calidad al final (`[HDTV 720p][AC3 5.1 Castellano]`) solo si el nombre original ya la define; no se comprueba contra el fichero.
- Si el original no define calidad, no la inventes.
- Idioma: `spa` en metadatos; "Castellano" viene del nombre de la release original.

## Patrón estándar de arreglo (temporada o release mal nombrada)
`Título [calidad] SxxExx {imdb-tt...}`
Aplícalo a **todos** los episodios de la release en una pasada, no solo al roto: los hermanos suelen tener el mismo tipo de error (corchetes sueltos, espacio antes de la extensión, mayúsculas inconsistentes). Termina con una tabla: episodio, nombre completo, directorio (movies/shows).

## Flujo ante un emparejado erróneo en Plex
1. Detectar: compara el título esperado (de la clave de zurg) con el que resuelve Plex con `mcp__zurg__zurg_plex_match_release`. Marca solo identidades distintas, no diferencias cosméticas ("Big Bang" frente a "The Big Bang Theory" vale).
2. Corregir el id con `mcp__zurg__zurg_release_set_external_id` sobre el hash concreto.
3. Dejar que se resuelva: `zurg_plex_match_all`, esperar a `match_running: false` en `zurg_plex_status`, volver a comprobar. Prueba también `zurg_plex_scan_releases` solo sobre esa ruta.
4. Si Plex mantiene el título viejo (solo re-empareja con una ruta nueva): renombrar carpeta y fichero con el nombre completo y el id al final.
5. Verificar con `zurg_plex_match_release`: `plex_rating_key_stale` limpio y título y año correctos.

Antes de renombrar episodios a mano, usa **Season Fix** de zurg (plan y luego apply con los `hashes` confirmados). Cubre numeración absoluta tipo fansub (`Show - 37.mkv`). Deja a mano solo lo que Season Fix no cubre: ya tiene token de temporada, extras NCOP/NCED/OAD, sin número de episodio o match sospechoso.

## Lo que NO hay que hacer
- No toques duplicados (mismo episodio o temporada en otra calidad): Plex elige la mejor versión. Solo infórmalos si es relevante.
- No lances escaneos de Plex tras renombrar ni los ofrezcas: un script externo del usuario actualiza Plex. Informa del resultado y para.
- Ignora cualquier carpeta `.@*` (`.@__thumb`): caché del NAS.
