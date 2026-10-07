# plex-naming-rules

Reglas de nombrado de Plex para series, películas, especiales e identificadores externos, más el flujo para corregir emparejados erróneos. No tiene scripts: es una skill de reglas.

## Cuándo se usa

Siempre que haya que renombrar carpetas o ficheros, arreglar un título mal emparejado en Plex o añadir ids `{imdb-...}`. La carga el agente `plex-naming` (campo `skills:` de `.claude/agents/plex-naming.md`), junto con `zurg-rules` y `plex`.

## Reglas

| Regla | Qué obliga | Cuándo aplica |
|-------|------------|---------------|
| Formato `SxxExx` | Temporada y episodio con dos dígitos y ceros (`S1E2`, `S01E2`, `1x02` pasan a `S01E02`), sin separadores. | Todo episodio. |
| `SxxExx` suelto | Nunca entre corchetes propios (`[S01E01]`) ni intercalado entre grupos de corchetes; va antes de los tags `[...]` de calidad. | Todo episodio. |
| `cap.NNN` | Los dos últimos dígitos son el episodio y los anteriores la temporada (`cap.101` es S01E01, `cap.1203` es S12E03). También `cap 101` y `capitulo 101`. | Nombres con "cap". |
| Especiales | `S00EXX` en `Season 00`, en el orden de TVDB. Solo van a `movies` si TVDB no los ubica dentro de la serie. | Especiales y películas "Special" de TVDB. |
| Sintaxis del id | `{imdb-tt#######}`, `{tmdb-#####}` o `{tvdb-######}`, siempre con llaves (con corchetes Plex los ignora). Basta un id por nombre. | Carpetas y ficheros. |
| Id al final | El id va al final del nombre, en la carpeta y en cada fichero (antes de la extensión), nunca al principio. | Carpetas y ficheros. |
| Carpeta de serie | `Serie (Año) {imdb-tt...}`, sin calidad ni texto extra antes del id. La carpeta de temporada va en inglés (`Season 01`). | Series. |
| Calidad en el nombre | Se añade al final (`[HDTV 720p][AC3 5.1 Castellano]`) solo si el nombre original ya la define; no se comprueba contra el fichero. Si el original no define calidad, no se inventa. "Castellano" viene del nombre de la release original; en metadatos el idioma es `spa`. | Al renombrar. |
| Patrón de arreglo | `Título [calidad] SxxExx {imdb-tt...}`, aplicado a todos los episodios de la release en una pasada, y tabla final con episodio, nombre completo y directorio (movies/shows). | Temporada o release mal nombrada. |
| Documentación oficial | support.plex.tv manda sobre cualquier hábito; se verifica ahí antes de afirmar cómo lee Plex un nombre. | Siempre. |

### Lo que no se hace

- No se tocan duplicados (mismo episodio o temporada en otra calidad): Plex elige la mejor versión; solo se informan si es relevante.
- No se lanzan ni se ofrecen escaneos de Plex tras renombrar: un script externo actualiza Plex.
- Se ignoran las carpetas `.@*`.

## Flujo ante un emparejado erróneo

1. Detectar con `mcp__zurg__zurg_plex_match_release`, comparando el título esperado (de la clave de zurg) con el que resuelve Plex. Solo cuentan identidades distintas, no diferencias cosméticas.
2. Corregir el id con `mcp__zurg__zurg_release_set_external_id` sobre el hash concreto.
3. Dejar que se resuelva con `mcp__zurg__zurg_plex_match_all`, esperar a `match_running: false` en `mcp__zurg__zurg_plex_status` y volver a comprobar. También se puede probar `mcp__zurg__zurg_plex_scan_releases` solo sobre esa ruta.
4. Si Plex mantiene el título viejo, renombrar carpeta y fichero con el nombre completo y el id al final.
5. Verificar con `mcp__zurg__zurg_plex_match_release`: `plex_rating_key_stale` limpio y título y año correctos.

Antes de renombrar episodios a mano se usa **Season Fix** de zurg (plan y luego apply con los `hashes` confirmados), que cubre numeración absoluta tipo fansub (`Show - 37.mkv`). A mano queda lo que no cubre: ya tiene token de temporada, extras NCOP/NCED/OAD, sin número de episodio o match sospechoso.

## Variables de entorno

Ninguna. La skill no ejecuta scripts ni llama a servicios por sí misma.

## Ejemplos de uso

Esta skill no tiene comandos. Un ejemplo de resultado aplicando las reglas:

```text
Carpeta:  Mi Serie (2015) {imdb-tt1234567}
Fichero:  Mi Serie [HDTV 720p][AC3 5.1 Castellano] S01E02 {imdb-tt1234567}.mkv
Especial: Mi Serie (2015) {imdb-tt1234567}/Season 00/... S00E01 ... {imdb-tt1234567}.mkv
```

Las operaciones de renombrado se hacen con las tools `mcp__zurg__zurg_release_rename` y `mcp__zurg__zurg_release_files_rename`, descritas en la skill `zurg-rules`.

## Notas y límites

- Es documentación de reglas: el cumplimiento depende del agente que la carga.
- Para las operaciones sobre el mount de zurg (solo renombrar, nada de crear carpetas) véase `zurg-rules`.
- Las convenciones de permisos y la doble confirmación están en el `CLAUDE.md` raíz y en el mensaje del hook `confirm-destructive`.
