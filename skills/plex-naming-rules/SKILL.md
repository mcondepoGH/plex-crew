---
name: plex-naming-rules
description: Esta skill debe usarse al nombrar o renombrar contenido de Plex. Úsala cuando el usuario pida "renombrar una serie", "renombrar episodios", "normalizar nombres", "este título está mal emparejado en Plex", "añadir el id de imdb", "añadir {imdb-...}", "corregir el nombre de una temporada", "cap.101" o "especiales S00", o mencione el nombrado de Plex o la identificación de contenido.
---

# Skill de reglas de nombrado Plex

**⚠️ INVOCACIÓN OBLIGATORIA DE LA SKILL ⚠️**

**DEBES invocar esta skill (no es opcional) cuando se dé CUALQUIERA de estas situaciones:**
- "renombrar una serie o película", "renombrar episodios", "normalizar nombres de carpetas o ficheros"
- "este título está mal emparejado en Plex", "Plex lo identifica mal", "corregir un emparejado"
- "añadir el id de imdb, tmdb o tvdb", "añadir {imdb-...}", "falta el año o el id en la carpeta"
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
- Formato `S01E02`: temporada y episodio con dos dígitos y relleno de ceros, sin separadores (`S1E2`, `S01E2`, `1x02` pasan a `S01E02`).
- `SxxExx` va solo. Nunca dentro de sus propios corchetes (`[S01E01]`) ni intercalado entre grupos de corchetes. Colócalo antes de todas las etiquetas de calidad `[...]`.
- Nombres como `cap.NNN` (también `cap 101`, `capitulo 101`): los dos últimos dígitos son el episodio y los anteriores la temporada. `cap.101` es S01E01; `cap.1203` es S12E03.
- Especiales y películas que TVDB lista como Special dentro de la serie: `S00EXX` en `Season 00`, numerados según el orden de TVDB. Solo van a `movies` si TVDB no los coloca en la serie.

### Identificadores
- Sintaxis `{imdb-tt#######}`, `{tmdb-#####}` o `{tvdb-######}`. Siempre llaves; con corchetes Plex los ignora.
- Basta con un id por nombre.
- El id va **al final** del nombre, en la carpeta y en cada fichero (antes de la extensión). Nunca al principio.
- Carpeta de serie limpia: `Serie (Año) {imdb-tt...}`, sin calidad ni texto adicional antes del id.
- La carpeta `Season` va siempre en inglés (`Season 01`).

### Calidad en el nombre
- Añade la calidad al final (`[HDTV 720p][AC3 5.1 Castellano]`) solo si el nombre original ya la define; no se comprueba contra el fichero.
- Si el original no define calidad, no la inventes.
- Idioma: `spa` en los metadatos; "Castellano" procede del nombre del release original.

### Patrón de corrección estándar (temporada o release mal nombrado)
`Título [calidad] SxxExx {imdb-tt...}`

Aplícalo a **todos** los episodios del release en una sola pasada, no solo al roto: los hermanos suelen compartir el mismo tipo de error (corchetes sueltos, espacio antes de la extensión, mayúsculas inconsistentes). Termina con una tabla: episodio, nombre completo, directorio (movies/shows).

## Flujo de trabajo

### Ante un emparejado erróneo en Plex
1. **Detecta**: compara el título y el año esperados (del nombre de la carpeta) con los que muestra Plex, usando la skill `plex` (`search` o `metadata`). Marca solo las identidades distintas, no las diferencias cosméticas ("Big Bang" frente a "The Big Bang Theory" es correcto).
2. **Renombra**: renombra carpeta y fichero con el nombre completo y el id al final. Plex solo vuelve a emparejar con una ruta nueva.
3. **Verifica** con la skill `plex`: título y año correctos.

## Ejemplos

```text
Carpeta:   Mi Serie (2015) {imdb-tt1234567}
Fichero:   Mi Serie [HDTV 720p][AC3 5.1 Castellano] S01E02 {imdb-tt1234567}.mkv
Especial:  Mi Serie (2015) {imdb-tt1234567}/Season 00/... S00E01 ... {imdb-tt1234567}.mkv
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
