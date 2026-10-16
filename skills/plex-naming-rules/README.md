# Skill plex-naming-rules

Reglas de nombrado de Plex para series, películas, especiales e identificadores externos, más el flujo para corregir emparejados erróneos. No tiene scripts: es una skill de reglas.

## Qué hace

- **Episodios** — Formato `SxxExx`, conversión de `cap.NNN`
- **Especiales** — `S00EXX` en `Season 00`, en orden de TVDB
- **Identificadores** — solo `{tmdb-#######}` (nunca IMDb ni TVDB), al final del nombre; series: sin id; películas: en la carpeta y en el fichero
- **Calidad** — Se añade al nombre solo si el original la define
- **Emparejados erróneos** — Detectar, corregir el id, dejar que Plex lo resuelva y verificar

## Configuración

No necesita configuración. El agente `plex-naming` la carga con el campo `skills:` de `agents/plex-naming.md`, junto con `plex-crew-rules` y `plex`.

## Ejemplos de uso

```text
Carpeta:   Mi Serie (2015)
Fichero:   Mi Serie (2015) - S01E02 [HDTV 720p][AC3 5.1 Castellano].mkv
Película:  Mi Película (2010) {tmdb-123456}/Mi Película (2010) {tmdb-123456}.mkv
Especial:  Mi Serie (2015)/Season 00/Mi Serie (2015) - S00E01.mkv
```

El renombrado se hace en local con `Bash`; las bibliotecas de Plex se localizan con la skill `plex` (comando `libraries`).

## Rutas de contenedor y rutas del host

Plex (en Docker) ve las carpetas con rutas de contenedor, que no existen en el host donde se renombra. Antes de renombrar, traduce la ruta a la del host bajo las raíces de `scope.conf`:

| Ruta de contenedor (Plex) | Ruta del host (ejemplo) |
|---|---|
| `/movies-local` | `/workspace/mnt/plex-stack/plex/multimedia/movies` |
| `/shows-local` | `/workspace/mnt/plex-stack/plex/multimedia/shows` |

Las rutas del host dependen de la instalación: la correspondencia real es la de tus raíces en `scope.conf`. Si una ruta traducida cae fuera de esas raíces, el hook `enforce-agent-scope` la denegará: no la rodees y devuélvelo al orquestador.

## Referencia de la API

La referencia detallada está en el directorio `references/`:

- **[Referencia rápida](./references/quick-reference.md)** - Reglas y patrones de nombre de un vistazo
- **[Resolución de problemas](./references/troubleshooting.md)** - Diagnóstico de emparejados erróneos y errores comunes de nombrado

## Flujo de trabajo

Ante un emparejado erróneo:

1. **Detecta** comparando el título y el año esperados (del nombre de la carpeta) con los que muestra Plex, usando la skill `plex` (`search` o `metadata`)
2. **Renombra** carpeta y fichero con el nombre completo y el id al final (series: solo en la carpeta; películas: carpeta y fichero); Plex solo vuelve a emparejar con una ruta nueva
3. **Verifica** con la skill `plex`: título y año correctos

## Resolución de problemas

**Plex mantiene el título antiguo**
→ Solo vuelve a emparejar con una ruta nueva: renombra carpeta y fichero con el nombre completo y el id al final (series: solo en la carpeta; películas: carpeta y fichero)

**El id se ignora**
→ Debe usar llaves, no corchetes, y estar al final del nombre; series: solo en la carpeta, nunca en los ficheros; películas: en la carpeta y en el fichero

**`cap.101` se leyó como una película**
→ Conviértelo a `S01E01`: los dos últimos dígitos son el episodio

## Notas

- Es documentación de reglas: no ejecuta nada y su cumplimiento depende del agente que la carga
- La doble confirmación está en la skill `plex-crew-rules` y en el mensaje del hook `confirm-destructive`

## Licencia

MIT
