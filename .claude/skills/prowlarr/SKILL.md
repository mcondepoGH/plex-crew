---
name: prowlarr
description: Search indexers and manage Prowlarr. Use when the user asks to "search for a torrent", "search indexers", "find a release", "check indexer status", "list indexers", "prowlarr search", "sync indexers", or mentions Prowlarr/indexer management.
---

# Prowlarr Skill

**INVOCACIÓN OBLIGATORIA DE LA SKILL**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "buscar un torrent", "buscar en los indexadores", "encontrar un release"
- "buscar en Prowlarr", "indexadores de Prowlarr", "búsqueda en indexadores"
- "estado de los indexadores", "probar indexadores", "estadísticas de Prowlarr"
- "listar indexadores", "sincronizar indexadores", "enviar indexadores a Sonarr"
- Cualquier mención de Prowlarr o de la gestión de indexadores

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Search across all your indexers and manage Prowlarr via API.

## Purpose

This skill provides **read and write** access to your Prowlarr indexer aggregation:
- Search for releases across all configured indexers
- Filter searches by protocol (torrent/usenet) and category
- List and monitor indexer health and statistics
- Enable/disable/delete indexers
- Sync indexer configurations to connected apps (Sonarr, Radarr)
- Test indexer connectivity

Operations include both read and write actions. **Always confirm before deleting or disabling indexers.**

## Setup

Credentials are stored in `.env` (raíz del repo):

```bash
PROWLARR_URL="http://localhost:9696"
PROWLARR_API_KEY="your-api-key"
```

Get your API key from: Prowlarr → Settings → General → Security → API Key

---

## Quick Reference

### Search Releases

```bash
# Basic search across all indexers
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh search "ubuntu 22.04"

# Search torrents only
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh search "ubuntu" --torrents

# Search usenet only
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh search "ubuntu" --usenet

# Search specific categories (2000=Movies, 5000=TV, 3000=Audio, 7000=Books)
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh search "inception" --category 2000

# Limit the number of results (--limit / -l) and choose the search type (--type / -t, default "search")
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh search "inception" --limit 20
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh search "inception" --type moviesearch

# TV search with TVDB ID
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh tv-search --tvdb 71663 --season 1 --episode 1

# Movie search with IMDB ID or TMDB ID (at least one)
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh movie-search --imdb tt0111161
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh movie-search --tmdb 550

# tv-search accepts any of --tvdb, --season, --episode (at least one); the filters are optional individually
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh tv-search --tvdb 71663 --season 1
```

### List Indexers

```bash
# All indexers
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh indexers

# With status details
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh indexers --verbose
```

### Indexer Health & Stats

```bash
# Usage stats per indexer
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh stats

# Test all indexers
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh test-all

# Test specific indexer
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh test <indexer-id>
```

### Indexer Management

```bash
# Enable/disable an indexer
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh enable <indexer-id>
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh disable <indexer-id>

# Delete an indexer
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh delete <indexer-id>
```

### App Sync

```bash
# Sync indexers to Sonarr/Radarr/etc
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh sync

# List connected apps
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh apps
```

### System

```bash
# System status
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh status

# Health check
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh health

# Last n log lines (default 50), optional level filter (info/warn/error)
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh logs 100 error
```

---

## Search Categories

| ID | Category |
|----|----------|
| 2000 | Movies |
| 5000 | TV |
| 3000 | Audio |
| 7000 | Books |
| 1000 | Console |
| 4000 | PC |
| 6000 | XXX |

Sub-categories: 2010 (Movies/Foreign), 2020 (Movies/Other), 2030 (Movies/SD), 2040 (Movies/HD), 2045 (Movies/UHD), 2050 (Movies/BluRay), 2060 (Movies/3D), 5010 (TV/WEB-DL), 5020 (TV/Foreign), 5030 (TV/SD), 5040 (TV/HD), 5045 (TV/UHD), etc.

---

## Common Use Cases

**"Search for the latest Ubuntu ISO"**
```bash
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh search "ubuntu 24.04"
```

**"Find Game of Thrones S01E01"**
```bash
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh tv-search --tvdb 121361 --season 1 --episode 1
```

**"Search for Inception in 4K"**
```bash
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh search "inception 2160p" --category 2045
```

**"Check if my indexers are healthy"**
```bash
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh stats
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh test-all
```

**"Push indexer changes to Sonarr/Radarr"**
```bash
bash .claude/skills/prowlarr/scripts/prowlarr-api.sh sync
```

## Workflow

When the user asks about indexers or searches:

1. **"Search for a torrent"** → Run `search "<query>"` and present results with download links
2. **"Find Breaking Bad S01E01"** → Run `tv-search --tvdb <id> --season 1 --episode 1`
3. **"Which indexers are working?"** → Run `stats` to show indexer health and usage
4. **"Test all my indexers"** → Run `test-all` to verify connectivity
5. **"Sync indexers to Sonarr"** → Run `sync` to push configuration changes
6. **"List available indexers"** → Run `indexers` or `indexers --verbose`

## Notes

- Requires network access to your Prowlarr server
- Uses Prowlarr API v1
- Search, `indexers`, `stats`, `apps`, `health`, `status` return JSON; `logs` prints plain text lines (`time [level] logger: message`)
- `enable`, `disable`, `delete`, `test`, `test-all` and `sync` check the HTTP status of the call: on a non-2xx answer they print an error to stderr and exit 1; on success they print a fixed `{"status": "ok", ...}` JSON (it does not confirm the effect, e.g. that `test` found the indexer healthy beyond HTTP 2xx)
- Commands that take an `<id>` (`test`, `enable`, `disable`, `delete`) print a usage error and exit 1 if it is missing
- **Search operations query external indexers** - respect rate limits
- **Indexer deletion is permanent** - el hook `confirm-destructive` exige la doble confirmación y el marcador `PLEX_CREW_CONFIRMED=1` para `delete`
- Sync operations push indexer configs to all connected apps (Sonarr, Radarr, Lidarr, etc.)
- Category IDs follow Newznab/Torznab standards

---

## 🔧 Agent Tool Usage Requirements

**CRITICAL:** When invoking scripts from this skill via the zsh-tool, **ALWAYS use `pty: true`**.

Without PTY mode, command output will not be visible even though commands execute successfully.

**Correct invocation pattern:**
```typescript
<invoke name="mcp__plugin_zsh-tool_zsh-tool__zsh">
<parameter name="command">.claude/skills/SKILL_NAME/scripts/SCRIPT.sh [args]</parameter>
<parameter name="pty">true</parameter>
</invoke>
```
