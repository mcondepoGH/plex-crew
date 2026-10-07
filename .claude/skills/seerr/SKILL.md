---
name: seerr
description: Manage Overseerr/Seerr media requests — search, request movies/TV, list pending requests, check status. Use when the user says "busca en seerr", "pide esta película/serie", "solicitudes pendientes", "overseerr", "seerr", or mentions request management.
---

# Seerr (Overseerr-compatible) Request Manager

Wrapper for the Seerr API (same API shape as Overseerr/Jellyseerr).

## Setup

Requires in `.env` (raíz del repo):
```
SEERR_URL="http://localhost:5055"
SEERR_API_KEY="<api key from Seerr Settings > General>"
```

## Commands

| Action | Command |
|--------|---------|
| Search | `bash .claude/skills/seerr/scripts/seerr.sh search "Title"` |
| Status | `bash .claude/skills/seerr/scripts/seerr.sh status` |
| List pending requests | `bash .claude/skills/seerr/scripts/seerr.sh requests [pending\|approved\|all]` |
| Request movie | `bash .claude/skills/seerr/scripts/seerr.sh request-movie <tmdbId>` |
| Request TV (all seasons) | `bash .claude/skills/seerr/scripts/seerr.sh request-tv <tmdbId>` |
| Request TV (specific seasons) | `bash .claude/skills/seerr/scripts/seerr.sh request-tv <tmdbId> <season1,season2,...>` |

## Notes

- Movie/TV ids are TMDB ids, same ones used by Radarr/Sonarr lookups — chain with the `radarr`/`sonarr` skills' `search` command to find the id first.
- `request-movie`/`request-tv` create a real request that (depending on Seerr config) may auto-approve and send straight to Radarr/Sonarr. Confirm with the user before requesting unless they explicitly named the exact title.
