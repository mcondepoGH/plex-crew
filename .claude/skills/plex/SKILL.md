---
name: plex
description: Control Plex Media Server - browse libraries, search media, check what's playing, view recently added. Use when the user asks to "check Plex", "search Plex", "what's on Plex", "recently added", "who's watching", "Plex sessions", "Plex library", "browse movies", "browse TV shows", or mentions Plex media server.
---

# Plex Media Server Skill

**INVOCACIÓN OBLIGATORIA DE LA SKILL**

**DEBES invocar esta skill (no es opcional) cuando el usuario mencione CUALQUIERA de estos disparadores:**
- "biblioteca de Plex", "buscar en Plex", "qué hay en Plex"
- "sesiones de Plex", "quién está viendo", "streams activos"
- "explorar Plex", "comprobar Plex", "estado de Plex"
- Cualquier mención de Plex Media Server o de consultar contenido multimedia

**Si no invocas esta skill cuando se dan estos disparadores, incumples tus requisitos operativos.**

Control and query Plex Media Server using the Plex API. Browse libraries, search media, and monitor active sessions.

## Purpose

This skill provides **mostly read-only** access to your Plex Media Server (the only command that changes state is `refresh`, which launches a library scan):
- Browse library sections (Movies, TV, Music, Photos)
- Search for specific media
- View recently added content
- Check what's currently playing (active sessions)
- View "On Deck" (continue watching)
- List available clients/players

All commands are HTTP GET requests, but **`refresh` is NOT read-only**: `GET /library/sections/<id>/refresh` makes Plex scan the library section. Everything else is safe for monitoring/browsing.

## Setup

Add your Plex server credentials to `.env` (raíz del repo):

```bash
# Plex Media Server
PLEX_URL="http://localhost:32400"
PLEX_TOKEN="<your_plex_token>"
```

- `PLEX_URL`: Your Plex server URL with port (default: 32400)
- `PLEX_TOKEN`: Your Plex authentication token

**Getting your Plex token:**
1. Go to plex.tv → Account → Authorized Devices
2. Click on any device, then "View XML"
3. Find `X-Plex-Token` in the URL
4. Or: Open any media in Plex Web, click "Get Info" → "View XML" and find token in URL

## Commands

All commands output JSON. Use `jq` for formatting or filtering.

El script auxiliar `plex-api.sh` simplifica el acceso a la API. Ubicación: `.claude/skills/plex/scripts/plex-api.sh`

### Server Info

```bash
# Using helper script
.claude/skills/plex/scripts/plex-api.sh info

# Or raw curl
curl -s "$PLEX_URL/?X-Plex-Token=$PLEX_TOKEN" -H "Accept: application/json"
```

### Browse Libraries

List all library sections:

```bash
# Using helper script
.claude/skills/plex/scripts/plex-api.sh libraries

# Or raw curl
curl -s "$PLEX_URL/library/sections?X-Plex-Token=$PLEX_TOKEN" -H "Accept: application/json"
```

### List Library Contents

```bash
# Using helper script (replace 1 with your section key)
.claude/skills/plex/scripts/plex-api.sh library 1
.claude/skills/plex/scripts/plex-api.sh library 1 --limit 50 --offset 100

# Or raw curl
curl -s "$PLEX_URL/library/sections/1/all?X-Plex-Token=$PLEX_TOKEN" -H "Accept: application/json"
```

### Search Media

```bash
# Using helper script
.claude/skills/plex/scripts/plex-api.sh search "Inception"
.claude/skills/plex/scripts/plex-api.sh search "Avengers" --limit 10

# Or raw curl
curl -s "$PLEX_URL/search?query=SEARCH_TERM&X-Plex-Token=$PLEX_TOKEN" -H "Accept: application/json"
```

### Recently Added

```bash
# Using helper script (default: 20 items)
.claude/skills/plex/scripts/plex-api.sh recent
.claude/skills/plex/scripts/plex-api.sh recent --limit 10

# Or raw curl
curl -s "$PLEX_URL/library/recentlyAdded?X-Plex-Token=$PLEX_TOKEN" -H "Accept: application/json"
```

### On Deck (Continue Watching)

```bash
# Using helper script (default: 10 items)
.claude/skills/plex/scripts/plex-api.sh ondeck
.claude/skills/plex/scripts/plex-api.sh ondeck --limit 5

# Or raw curl
curl -s "$PLEX_URL/library/onDeck?X-Plex-Token=$PLEX_TOKEN" -H "Accept: application/json"
```

### Active Sessions (What's Playing)

```bash
# Using helper script
.claude/skills/plex/scripts/plex-api.sh sessions

# Or raw curl
curl -s "$PLEX_URL/status/sessions?X-Plex-Token=$PLEX_TOKEN" -H "Accept: application/json"
```

### List Clients/Players

```bash
# Using helper script
.claude/skills/plex/scripts/plex-api.sh clients

# Or raw curl
curl -s "$PLEX_URL/clients?X-Plex-Token=$PLEX_TOKEN" -H "Accept: application/json"
```

### Additional Commands

```bash
# Server identity
.claude/skills/plex/scripts/plex-api.sh identity

# Get metadata for specific item (by rating key)
.claude/skills/plex/scripts/plex-api.sh metadata 12345

# Get children of item (e.g., seasons of a TV show)
.claude/skills/plex/scripts/plex-api.sh children 12345

# List playlists
.claude/skills/plex/scripts/plex-api.sh playlists

# NOT read-only: launches a scan of the library section (see warning below)
.claude/skills/plex/scripts/plex-api.sh refresh 1

# View all commands
.claude/skills/plex/scripts/plex-api.sh --help
```

### Refresh (launches a library scan)

`refresh <section-id>` makes Plex scan that section for new media. It is a write operation in practice, so confirm with the user before using it. The script prints a fixed `{"status": "ok", "message": "Library refresh initiated"}` after the call **without checking Plex's response** (no HTTP status check), so an `ok` does not prove the scan started.

**Do not launch or offer scans after renaming files**: the user has an external script that updates Plex (see `plex-naming-rules`). Only use `refresh` when the user explicitly asks for it.

## Workflow

When the user asks about Plex:

1. **"What's on Plex?"** → Browse libraries and show section overview
2. **"Search for Inception"** → Run search with query
3. **"What was recently added?"** → Run recentlyAdded
4. **"Who's watching right now?"** → Run sessions
5. **"What am I watching?"** → Run onDeck
6. **"List my movies"** → List library sections, then contents of Movies section

### Library Section Types

Common section types (keys vary by server):
- **Movies** — Usually section 1
- **TV Shows** — Usually section 2
- **Music** — Music library
- **Photos** — Photo library

Always list sections first to get the correct section keys for your server.

## Output Format

- Add `-H "Accept: application/json"` for JSON output
- Default output is XML if header not specified
- Media keys look like `/library/metadata/12345`
- Use `jq` to filter and format JSON responses

## Notes

- Requires network access to your Plex server
- All calls are GET requests and read-only, except `refresh` (launches a library scan)
- Library section keys (1, 2, 3...) vary by server setup — list sections first
- Playback control is possible but not implemented (safety)
- Always confirm before triggering playback on remote devices
- Token is scoped to your account — keep it secure

## Multiple Servers

To query multiple Plex servers:

```bash
# Server 1
PLEX_URL="http://server1:32400" PLEX_TOKEN="token1" curl ...

# Server 2
PLEX_URL="http://server2:32400" PLEX_TOKEN="token2" curl ...
```

## Reference

- [Plex Media Server API](https://www.plexopedia.com/plex-media-server/api/)
- [Plex Web App](https://app.plex.tv/)

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
