# Resolución de problemas de plex-naming-rules

## Problemas de emparejado

### Plex resuelve un título distinto
**Causa:** Id externo erróneo o ausente en el nombre, o un emparejado obsoleto

**Solución:**
1. Compara el título y el año esperados (del nombre de la carpeta) con los que muestra Plex, usando la skill `plex` (`search` o `metadata`); marca solo las identidades distintas, no las cosméticas
2. Renombra carpeta y fichero con el nombre completo; el id de TMDB va al final de carpeta y fichero solo en películas (series sin id)
3. Verifica de nuevo con la skill `plex`: título y año correctos

### Plex mantiene el título antiguo tras renombrar
**Causa:** Plex solo vuelve a emparejar con una ruta nueva

**Solución:**
1. Asegúrate de que han cambiado tanto la carpeta como el fichero, no solo uno de ellos
2. Usa el nombre completo; el id de TMDB va al final de carpeta y fichero solo en películas (series sin id)
3. Verifica con la skill `plex`: título y año correctos

### El id se ignora
**Causa:** Corchetes en lugar de llaves, o, en películas, el id no está al final del nombre

**Solución:**
1. Usa solo `{tmdb-#######}` y solo en películas; si la película no tiene id de TMDB conocido, consúltalo (Guid `tmdb://` de Plex, lookup de Radarr/Seerr) o pregunta, y no pongas otro tipo de id
2. Colócalo al final del nombre, en la carpeta y en el fichero de la película. Las series no llevan id: ante un emparejado dudoso usa `match_release`, `set_external_id` y rematch

## Problemas de nombrado

### Episodio leído como otra cosa
**Causa:** `SxxExx` en sus propios corchetes o intercalado entre grupos de corchetes

**Solución:**
1. Escribe `SxxExx` solo, con las etiquetas de calidad después
2. Aplica el patrón de corrección `Serie (Año) - SxxExx [calidad].ext` (sin id) a todos los episodios del release

### Nombres al estilo `cap.101`
**Causa:** Numeración de episodios no estándar

**Solución:**
1. Los dos últimos dígitos son el episodio, los anteriores la temporada (`cap.1203` es S12E03)

### Numeración absoluta de episodios (`Show - 37.mkv`)
**Causa:** No hay token de temporada

**Solución:**
1. Calcula la temporada y el episodio de cada fichero y renombra a `SxxExx`
2. Deja sin cambios los ficheros que ya tienen token de temporada, los extras NCOP/NCED/OAD, los ficheros sin número de episodio y los emparejados dudosos; infórmalos

### Especial listado como película
**Causa:** TVDB no lo coloca dentro de la serie

**Solución:**
1. Si TVDB lo lista como Special dentro de la serie, usa `S00EXX` en `Season 00`
2. En caso contrario, va a `movies`
