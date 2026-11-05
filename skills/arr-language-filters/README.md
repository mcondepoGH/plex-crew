# Skill arr-language-filters

Explica cómo diagnosticar el filtrado de idioma de cli_debrid, Radarr/Sonarr y Prowlarr/Torrentio, y sus límites conocidos. Perfiles, formatos personalizados y reglas de filtro son configuración propia de cada usuario; la skill no asume ninguna. No tiene scripts.

## Qué hace

- **cli_debrid** — Reglas binarias `filter_in` y `filter_out`, orden de las palabras de subs, scrapers
- **Radarr y Sonarr** — Perfiles de calidad, formatos personalizados y `minFormatScore` (se consultan con `qualityprofiles` y `customformats`)
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
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" exists 603
bash "${CLAUDE_PLUGIN_ROOT}/skills/radarr/scripts/radarr.sh" config

# Lectura: buscar candidatos por imdbid (evita el fallo de texto libre de Torrentio)
bash "${CLAUDE_PLUGIN_ROOT}/skills/prowlarr/scripts/prowlarr-api.sh" movie-search --imdb tt0133093
```

Ejecuta desde la carpeta de cada skill (`skills/radarr`, `skills/prowlarr`).

## Referencia de la API

La referencia detallada está en el directorio `references/`:

- **[Referencia rápida](./references/quick-reference.md)** - Filtros de cada sistema de un vistazo
- **[Resolución de problemas](./references/troubleshooting.md)** - Por qué un título se rechaza, falta o está en el idioma equivocado

## Flujo de trabajo

Cuando un título se descarga en otro idioma, se rechaza o falta:

1. **cli_debrid**: comprueba el nombre contra tus reglas `filter_in` y `filter_out`, incluido el orden de cualquier palabra de subs
2. **Radarr o Sonarr**: consulta `qualityprofiles` y `customformats`; comprueba el perfil de la serie o película, la puntuación de tu formato de idioma y el `minFormatScore`
3. **Torrentio**: comprueba que la búsqueda llevaba `imdbid`
4. **Bloqueo de un servicio externo** (p. ej. un debrid): comprueba si el nombre coincide con algún formato personalizado de puntuación negativa que tengas para ello
5. Informa de la causa; no cambies la configuración sin la confirmación del usuario

## Resolución de problemas

**Aparece un release con score 0 en el historial**
→ Puede venir de una configuración anterior; compara con el `minFormatScore` actual de tu perfil

**Torrentio devuelve Fight Club o Reacher**
→ Búsqueda de texto libre sin `imdbid`; no quites `search: [q]`, haz que la búsqueda lleve `imdbid`

**Un título nunca llega a cli_debrid**
→ Ningún indexer tiene una copia que cumpla tu `filter_in`; no hay fallback a otro idioma

## Notas

- Perfiles, ids y puntuaciones son configuración de cada usuario; consúltalos con las skills `radarr` y `sonarr`
- Ninguna parte de la skill modifica la configuración por sí misma

## Licencia

MIT
