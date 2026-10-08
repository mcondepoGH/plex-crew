# Skill arr-language-filters

Explica cómo filtran el idioma cli_debrid, Radarr/Sonarr y Prowlarr/Torrentio en este stack, y sus límites conocidos. Objetivo común: audio en español (un release con subtítulos en español pero audio en otro idioma no cuenta). No tiene scripts.

## Qué hace

- **cli_debrid** — Reglas binarias `filter_in` y `filter_out`, posición de los subs, scrapers
- **Radarr y Sonarr** — Perfiles, Custom Format `Audio-ES`, `MinFormatScore`, `RD-Bloqueado`
- **Torrentio en Prowlarr** — Por qué las búsquedas de texto libre devuelven un título fijo y la mitigación válida
- **Sincronización del mount** — Flujo para renombrar las carpetas del mount a `Title (Year)` para Library Import

## Configuración

Sin variables de entorno. El agente `arr-acquisition` la carga, junto con estas skills declaradas en su frontmatter (`skills:`):

- `plex-crew-rules`
- `arr-language-filters`
- `radarr`
- `sonarr`
- `prowlarr`
- `seerr`
- `cli_debrid`
- `plex`
- `tautulli`

## Ejemplos de uso

Combinada con las skills de servicio (cada una documenta sus propias variables de entorno):

```bash
# Lectura: ver si Radarr ya conoce la película y su configuración (perfiles, carpetas raíz)
bash scripts/radarr.sh exists 603
bash scripts/radarr.sh config

# Lectura: buscar candidatos por imdbid (evita el fallo de texto libre de Torrentio)
bash scripts/prowlarr-api.sh movie-search --imdb tt0133093
```

Ejecuta desde la carpeta de cada skill (`skills/radarr`, `skills/prowlarr`).

## Referencia de la API

La referencia detallada está en el directorio `references/`:

- **[Referencia rápida](./references/quick-reference.md)** - Filtros de cada sistema de un vistazo
- **[Resolución de problemas](./references/troubleshooting.md)** - Por qué un título se rechaza, falta o está en el idioma equivocado

## Flujo de trabajo

Cuando un título se descarga en otro idioma, se rechaza o falta:

1. **cli_debrid**: comprueba que el nombre contiene `spa`, `esp`, `spanish` o `castellano`, y la posición de cualquier palabra de subs
2. **Radarr o Sonarr**: comprueba el perfil (id 7 u 8), el score de `Audio-ES` y `MinFormatScore: 100`
3. **Torrentio**: comprueba que la búsqueda llevaba `imdbid`
4. **Bloqueo de Real-Debrid**: comprueba si el nombre coincide con un patrón de `RD-Bloqueado`
5. Informa de la causa; no cambies la configuración sin la confirmación del usuario

## Resolución de problemas

**Aparece un release con score 0 en el historial**
→ Viene de una configuración anterior; `MinFormatScore: 100` lo bloquea ahora

**Torrentio devuelve Fight Club o Reacher**
→ Búsqueda de texto libre sin `imdbid`; no quites `search: [q]`, haz que la búsqueda lleve `imdbid`

**Un título nunca llega a cli_debrid**
→ No tiene copia en español en ningún indexer; no hay fallback a inglés

## Notas

- Los ids de perfil (7, 8) y los scores son los de este stack y pueden cambiar si se reconfigura Radarr/Sonarr
- Ninguna parte de la skill modifica la configuración por sí misma

## Licencia

MIT
