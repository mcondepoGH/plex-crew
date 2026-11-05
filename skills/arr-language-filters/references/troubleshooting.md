# Resolución de problemas de arr-language-filters

## Problemas de rechazo

### "¿Por qué se rechazó este release?"
**Causa:** Uno de los tres sistemas lo filtró

**Solución:**
1. cli_debrid: ¿el nombre cumple tus `filter_in` y no tus `filter_out`? ¿Importa el orden de las palabras de subs en tus reglas?
2. Radarr o Sonarr: con `qualityprofiles` y `customformats`, ¿la suma de puntuaciones del release alcanza el `minFormatScore` del perfil?
3. Servicio externo (p. ej. un debrid): ¿el nombre coincide con algún formato personalizado de puntuación negativa tuyo?

### Un grab con puntuación inferior al mínimo en el historial
**Causa:** Viene de una configuración anterior

**Solución:**
1. Compara con el `minFormatScore` actual del perfil (`qualityprofiles`): si es mayor que 0 lo rechazaría ahora
2. No lo bajes sin confirmarlo con el usuario

### Release con subtítulos en español rechazado
**Causa:** Tu configuración puede no considerar válidos los subtítulos sin audio en el idioma deseado

**Solución:**
1. En Radarr y Sonarr, revisa con `customformats` si tienes un formato que detecte subtítulos y qué puntuación aporta
2. En cli_debrid, revisa tus `filter_out`

## Problemas de títulos ausentes

### Un título no aparece en cli_debrid
**Causa:** Solo llega por las fuentes propias de cli_debrid y ningún indexer tiene una copia que cumpla tu `filter_in`

**Solución:**
1. Revisa la cola y los logs con la skill `cli_debrid`
2. No hay fallback a otro idioma: el filtro es binario

### Torrentio devuelve Fight Club o Reacher
**Causa:** Búsqueda de texto libre sin `imdbid`; Torrentio solo funciona por id de IMDb/Kitsu

**Solución:**
1. Haz que toda búsqueda en Torrentio lleve `imdbid`
2. No quites `search: [q]` del yml: rompe todo el indexer

## Problemas de perfiles

### Cambiar el perfil de una serie existente no hace nada
**Causa:** `add` no cambia una serie existente

**Solución:**
1. Usa un PUT sobre la serie (`qualityProfileId`)

### Descargas bloqueadas por Real-Debrid (error de API 35)
**Causa:** Real-Debrid bloquea nombres con ciertos patrones (`infringing_file`)

**Solución:**
1. Un formato personalizado de puntuación muy negativa que cubra esos nombres evita esos grabs en Radarr y Sonarr (se configura a mano; consulta `customformats`)
2. cli_debrid reintenta por su cuenta con otro candidato
