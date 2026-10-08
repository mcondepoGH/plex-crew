# Resolución de problemas de arr-language-filters

## Problemas de rechazo

### "¿Por qué se rechazó este release?"
**Causa:** Uno de los tres sistemas lo filtró

**Solución:**
1. cli_debrid: ¿el nombre contiene `spa`, `esp`, `spanish` o `castellano`? ¿Hay una palabra de subs a la izquierda de la palabra en español?
2. Radarr o Sonarr: ¿cumple `Audio-ES` (+100) y `MinFormatScore: 100`?
3. Real-Debrid: ¿el nombre coincide con un patrón de `RD-Bloqueado`?

### Un grab con score 0 en el historial
**Causa:** Viene de una configuración anterior

**Solución:**
1. `MinFormatScore: 100` es un bloqueo duro intencionado y lo rechaza ahora
2. No lo bajes sin confirmarlo con el usuario

### Release con subtítulos en español rechazado
**Causa:** Los subtítulos en español sin audio en español no son lo que se quiere

**Solución:**
1. `VOSE` (0) los detecta en Radarr y Sonarr
2. En cli_debrid, `filter_out` rechaza los releases subs/VOSE que no sean también en español

## Problemas de títulos ausentes

### Un título no aparece en cli_debrid
**Causa:** Solo llega por las fuentes propias de cli_debrid y no tiene copia en español en ningún indexer

**Solución:**
1. Revisa la cola y los logs con la skill `cli_debrid`
2. No hay fallback a inglés: el filtro binario es deliberado

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
1. El Custom Format `RD-Bloqueado` (-10000) evita esos grabs en Radarr y Sonarr
2. cli_debrid reintenta por su cuenta con otro candidato
