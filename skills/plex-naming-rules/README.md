# Skill plex-naming-rules

Reglas de nombrado de Plex para series, películas, especiales e identificadores externos, más el flujo para corregir emparejados erróneos. No tiene scripts: es una skill de reglas.

## Qué hace

- **Episodios** — Formato `SxxExx`, conversión de `cap.NNN`
- **Especiales** — `S00EXX` en `Season 00`, en orden de TVDB
- **Identificadores** — `{imdb-...}`, `{tmdb-...}` o `{tvdb-...}` al final del nombre
- **Calidad** — Se añade al nombre solo si el original la define
- **Emparejados erróneos** — Detectar, corregir el id, dejar que Plex lo resuelva y verificar

## Configuración

No necesita configuración. El agente `plex-naming` la carga con el campo `skills:` de `agents/plex-naming.md`, junto con `plex-crew-rules` y `plex`.

## Ejemplos de uso

```text
Carpeta:   Mi Serie (2015) {imdb-tt1234567}
Fichero:   Mi Serie [HDTV 720p][AC3 5.1 Castellano] S01E02 {imdb-tt1234567}.mkv
Especial:  Mi Serie (2015) {imdb-tt1234567}/Season 00/... S00E01 ... {imdb-tt1234567}.mkv
```

El renombrado se hace en local con `Bash`; las bibliotecas de Plex se localizan con la skill `plex` (comando `libraries`).

## Referencia de la API

La referencia detallada está en el directorio `references/`:

- **[Referencia rápida](./references/quick-reference.md)** - Reglas y patrones de nombre de un vistazo
- **[Resolución de problemas](./references/troubleshooting.md)** - Diagnóstico de emparejados erróneos y errores comunes de nombrado

## Flujo de trabajo

Ante un emparejado erróneo:

1. **Detecta** comparando el título y el año esperados (del nombre de la carpeta) con los que muestra Plex, usando la skill `plex` (`search` o `metadata`)
2. **Renombra** carpeta y fichero con el nombre completo y el id al final; Plex solo vuelve a emparejar con una ruta nueva
3. **Verifica** con la skill `plex`: título y año correctos

## Resolución de problemas

**Plex mantiene el título antiguo**
→ Solo vuelve a emparejar con una ruta nueva: renombra carpeta y fichero con el nombre completo y el id al final

**El id se ignora**
→ Debe usar llaves, no corchetes, y estar al final del nombre

**`cap.101` se leyó como una película**
→ Conviértelo a `S01E01`: los dos últimos dígitos son el episodio

## Notas

- Es documentación de reglas: no ejecuta nada y su cumplimiento depende del agente que la carga
- La doble confirmación está en la skill `plex-crew-rules` y en el mensaje del hook `confirm-destructive`

## Licencia

MIT
