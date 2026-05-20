# /vault — Obsidian Vault Operations

Use this skill to interact with the Obsidian vault via the Obsidian URI scheme or Obsidian CLI.

> **Obsidian must be running** for URI-based operations (`/vault ticket`, `/vault open`).
> If Obsidian is closed, all operations fall back to direct file writes automatically —
> vault links (`[[filename]]`) won't be maintained, but the files will be created correctly.

## Commands

### /vault ticket [INC-ID] [slug] [title]
Creates a ticket record in the vault's tickets directory.

If Obsidian is running, creates the file via Obsidian URI so vault links are maintained.
If Obsidian is not running, creates the file directly at `tickets/[INC-ID]-[slug].md`.

```bash
# Via Obsidian URI (if running):
open "obsidian://new?vault=The%20Matrix&name=tickets%2F$INC_ID-$SLUG&content=$ENCODED_CONTENT"

# Direct file creation (fallback):
cat > "tickets/${INC_ID}-${SLUG}.md" << 'EOF'
# [INC-ID] — [Project] — [Title]

**Date:** [date]
**Agent:** Smith → [worker tier]
**Status:** Resolved

## Brief
[Smith Brief]

## Resolution
[What was done]

## Deployed
[How and when]
EOF
```

### /vault search [keywords]
Searches across all vault files for the given keywords.

```bash
grep -r "[keywords]" . --include="*.md" -l
```

### /vault open [filename]
Opens a file in Obsidian (if running).

```bash
open "obsidian://open?vault=The%20Matrix&file=[filename]"
```

## Notes

- The vault skill requires Obsidian to be running for URI-based operations
- Direct file creation always works as a fallback
- Vault links (`[[filename]]`) are only created automatically when using the Obsidian URI method
