# Referencia rápida de plex-naming-rules

Reglas y patrones de nombre de un vistazo.

| Regla | Qué exige | Cuándo aplica |
|-------|-----------|---------------|
| Formato `SxxExx` | Temporada y episodio con dos dígitos y ceros (`S1E2`, `S01E2`, `1x02` pasan a `S01E02`), sin separadores | Todo episodio |
| `SxxExx` solo | Nunca en sus propios corchetes (`[S01E01]`) ni entre grupos de corchetes; la calidad `[...]` va después | Todo episodio |
| `cap.NNN` | Los dos últimos dígitos son el episodio, el resto la temporada (`cap.101` es S01E01, `cap.1203` es S12E03); también `cap 101` y `capitulo 101` | Nombres con "cap" |
| Especiales | `S00EXX` en `Season 00`, orden de TVDB; a `movies` solo si TVDB no los coloca en la serie | Especiales y películas "Special" de TVDB |
| Sintaxis del id | solo `{tmdb-#######}` (nunca `{imdb-...}` ni `{tvdb-...}`), siempre llaves; si una película no tiene id de TMDB, consultarlo o preguntar | Series: sin id; películas: en carpeta y fichero |
| Id al final | Solo películas: al final del nombre, en la carpeta y en el fichero (y hermanos como subtítulos). Series: sin id | Carpetas y ficheros |
| Carpeta de serie | `Serie (Año)` (sin id); la carpeta de temporada va en inglés (`Season 01`) | Series |
| Calidad en el nombre | Después de `SxxExx` (`[HDTV 720p][AC3 5.1 Castellano]`) solo si el nombre original la define; nunca inventada | Al renombrar |
| Patrón de corrección | `Serie (Año) - SxxExx [calidad].ext` (sin id) en todos los episodios del release en una sola pasada, tabla final | Temporada o release mal nombrado |
| Documentación oficial | support.plex.tv prevalece sobre cualquier costumbre | Siempre |

## Patrones

```text
Carpeta:   Serie (Año)
Episodio:  Serie (Año) - SxxExx [calidad].ext
Especial:  Serie (Año)/Season 00/Serie (Año) - S00EXX.ext
```

## Formato de episodio de series

Nombres de fichero (decisión del usuario, 2026-10-16). Detalle y conflictos pendientes en `SKILL.md`.

| Tipo | Ejemplo |
|------|---------|
| Episodio individual | `The Series Title's! (2010) - S01E01 - Episode Title 1 [Surround Sound x264][WEBDL-1080p Proper][DTS 5.1][AVC]-RlsGrp` |
| Multi-episodio | `The Series Title's! (2010) - S01E01-E03 - Episode Title [Surround Sound x264][WEBDL-1080p Proper][DTS 5.1][AVC]-RlsGrp` |
| Diario | `The Series Title's! (2010) - 2013-10-30 - Episode Title 1 [Surround Sound x264][WEBDL-1080p Proper][DTS 5.1][AVC]-RlsGrp` |
| Anime individual | `The Series Title's! (2010) - S01E01 - 001 - Episode Title 1 [Surround Sound x264][WEBDL-1080p v2][DTS 5.1][JA][AVC 10bit]-RlsGrp` |
| Anime multi-episodio | `The Series Title's! (2010) - S01E01-E03 - 001-003 - Episode Title [Surround Sound x264][WEBDL-1080p v2][DTS 5.1][JA][AVC 10bit]-RlsGrp` |

Sin id (las series no llevan id). Título del episodio y etiquetas solo si se conocen; `-RlsGrp` es el grupo de release.

## Formato de película

Nombre de fichero (decisión del usuario, 2026-10-16). Detalle y conflictos pendientes en `SKILL.md`.

| Tipo | Ejemplo |
|------|---------|
| Película con edición | `The Movie Title (2010) {tmdb-345691} - {edition-Ultimate Extended Edition} [3D][Surround Sound x264][Bluray-1080p Proper][DTS 5.1][AVC]-EVOLVE` |

El id debe ser siempre el de TMDB. Id en carpeta (`Título (Año) {tmdb-#######}`) y en fichero. Edición `{edition-Nombre}` solo si existe; etiquetas solo con evidencia; `-EVOLVE` es el grupo de release.

## Rutas de contenedor a rutas del host

| Contenedor (lo que muestra Plex) | Host |
|---|---|
| `/movies-local`, `/shows-local` | carpetas locales `movies` y `shows` bajo las raíces de `scope.conf` |

Renombra siempre con la ruta del host; la de contenedor no existe fuera de Docker.

## Comandos de la skill plex utilizados

- `libraries`: localizar las bibliotecas locales de Plex
- `search`: comprobar el título y el año que muestra Plex para un nombre
- `metadata`: comprobar los metadatos completos de un elemento
