# Referencia rápida de plex-naming-rules

Reglas y patrones de nombre de un vistazo.

| Regla | Qué exige | Cuándo aplica |
|-------|-----------|---------------|
| Formato `SxxExx` | Temporada y episodio con dos dígitos y ceros (`S1E2`, `S01E2`, `1x02` pasan a `S01E02`), sin separadores | Todo episodio |
| `SxxExx` solo | Nunca en sus propios corchetes (`[S01E01]`) ni entre grupos de corchetes; la calidad `[...]` va después | Todo episodio |
| `cap.NNN` | Los dos últimos dígitos son el episodio, el resto la temporada (`cap.101` es S01E01, `cap.1203` es S12E03); también `cap 101` y `capitulo 101` | Nombres con "cap" |
| Especiales | `S00EXX` en `Season 00`, orden de TVDB; a `movies` solo si TVDB no los coloca en la serie | Especiales y películas "Special" de TVDB |
| Sintaxis del id | `{imdb-tt#######}`, `{tmdb-#####}` o `{tvdb-######}`, siempre llaves; basta con un id | Series: id solo en la carpeta; películas: en carpeta y fichero |
| Id al final | Series: solo en la carpeta de la serie, al final; no en los episodios. Películas: al final de carpeta y fichero (antes de la extensión) | Carpetas y ficheros |
| Carpeta de serie | `Serie (Año) {imdb-tt...}`; la carpeta de temporada va en inglés (`Season 01`) | Series |
| Calidad en el nombre | Después de `SxxExx` (`[HDTV 720p][AC3 5.1 Castellano]`) solo si el nombre original la define; nunca inventada | Al renombrar |
| Patrón de corrección | `Serie (Año) - SxxExx [calidad].ext` (id solo en la carpeta) en todos los episodios del release en una sola pasada, tabla final | Temporada o release mal nombrado |
| Documentación oficial | support.plex.tv prevalece sobre cualquier costumbre | Siempre |

## Patrones

```text
Carpeta:   Serie (Año) {imdb-tt...}
Episodio:  Serie (Año) - SxxExx [calidad].ext
Especial:  Serie (Año) {imdb-tt...}/Season 00/Serie (Año) - S00EXX.ext
```

## Rutas de contenedor a rutas del host

| Contenedor (lo que muestra Plex) | Host |
|---|---|
| `/movies-local`, `/shows-local` | carpetas locales `movies` y `shows` bajo las raíces de `scope.conf` |

Renombra siempre con la ruta del host; la de contenedor no existe fuera de Docker.

## Comandos de la skill plex utilizados

- `libraries`: localizar las bibliotecas locales de Plex
- `search`: comprobar el título y el año que muestra Plex para un nombre
- `metadata`: comprobar los metadatos completos de un elemento
