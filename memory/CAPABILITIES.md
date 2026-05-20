# Capabilities — What Each Model Can Do Directly

Use this to decide whether to run a tool yourself or ask the operator to run it.

---

## Claude (via Claude Code CLI)

| Capability | Direct | Notes |
|-----------|--------|-------|
| Read files | ✓ | Use `Read` tool |
| Write files | ✓ | Use `Edit`/`Write` tools |
| Run shell commands | ✓ | Use `Bash` tool |
| Web fetch | ✓ | Use `WebFetch` tool |
| Web search | ✓ | Use `WebSearch` tool |
| Spawn sub-agents | ✓ | Use `Agent` tool |
| Access production systems | Depends | Only if credentials are configured |

## Codex (via Codex CLI)

| Capability | Direct | Notes |
|-----------|--------|-------|
| Read files | ✓ | |
| Write files | ✓ | Produces clean diffs |
| Run shell commands | ✓ | |
| Web access | ✗ | No web tools |
| Interactive input | Limited | Best with pre-loaded context |

## Gemini (via Gemini CLI)

| Capability | Direct | Notes |
|-----------|--------|-------|
| Read files | ✗ | Context must be pre-loaded by `activate.sh` |
| Write files | ✗ | Output labelled blocks instead |
| Run shell commands | ✗ | |
| Large context | ✓ | Best for big doc dumps |
| Web search | ✓ | Built-in grounding |

---

## When to ask the operator instead

Ask the operator to run something directly when:

1. **Credentials are needed** — never handle credentials in agent context
2. **Production access** — always confirm before touching production
3. **Interactive UI actions** — anything that requires a browser click or admin panel navigation
4. **Destructive operations** — always get explicit approval before deletions

For these, produce a **Human Action Card**:

```
## Human Action Card

**Action required:** [what the operator needs to do]
**Location:** [exact path or panel]
**Steps:**
1. [Step]
2. [Step]
**Verify by:** [how to confirm it worked]
**Then:** [what to report back]
```
