# Skills — Which Claude Code Skills to Invoke When

This file documents the Claude Code slash commands (skills) available in this system and when to use them.

---

## Built-in Matrix skills

### `/vault` — Obsidian vault operations
**Invoke when:** Creating ticket records, searching across all project files, writing to vault via Obsidian CLI
**Available operations:**
- `/vault ticket [INC-ID] [slug] [title]` — create a ticket record
- `/vault search [keywords]` — search the vault
- `/vault open [file]` — open a file in Obsidian

### `/compact` — Compress context
**Invoke when:** Before spawning Seraph after a heavy investigation or Morpheus review phase
**Effect:** Summarizes the conversation without losing key facts. Seraph needs a clean, focused context.

---

## When to invoke skills vs. tools

| Task | Use |
|------|-----|
| Create a ticket record | `/vault ticket` |
| Search across all project docs | `/vault search` |
| Context is heavy before Seraph | `/compact` |
| Read a specific known file | `Read` tool directly |
| Run a shell command | `Bash` tool directly |

---

## Adding skills

Skills live in `.claude/commands/`. Each skill is a markdown file with instructions.

To add a skill:
1. Create `.claude/commands/skill-name.md`
2. Document when to invoke it in this file
3. Test by typing `/skill-name` in a Claude Code session
