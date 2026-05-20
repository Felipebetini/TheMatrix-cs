# Setup Guide — Adapting The Matrix to Your Team

This guide covers everything you need to change to make The Matrix work for your team and domain. The harness (hooks, gates, scripts) works out of the box. The content (rules, risk policy, agent prompts) needs to match your context.

> **Before your first ticket:** complete Steps 1–4 below. The repo ships with placeholder text in `memory/ZION.md` and `projects/_template/RSI.yaml`. If you run `./scripts/matrix.sh` without configuring them, Smith will load template instructions into every agent session. The pre-flight check in `matrix.sh` will warn you — but it's better to configure first.

---

## Prerequisites

| Tool | Required for | Install |
|------|-------------|---------|
| Claude Code CLI | Smith, Senior, Seraph, all orchestration | `npm install -g @anthropic-ai/claude-code` |
| Codex CLI | Junior, Midlevel workers | `npm install -g @openai/codex` |
| Gemini CLI | Oracle (large-context research) | `npm install -g @google/gemini-cli` |
| Python 3 | Dashboard, track-tool hook | standard on macOS/Linux |
| Bash | All scripts | standard |

All three AI CLIs are optional — the system falls back gracefully. Claude alone is sufficient to get started.

---

## Step 1 — Clone and make scripts executable

```bash
git clone https://github.com/your-org/the-matrix.git
cd the-matrix
chmod +x scripts/*.sh
```

---

## Step 2 — Configure ZION

`memory/ZION.md` is the always-loaded constitution. Edit the **"Who we are"** section to describe your team:

```yaml
# Change this section:
## Who we are
[Your team type]. [What you maintain]. [What errors cost your clients].
[Operator name] is the Architect. They are the final decision-maker.
```

Keep ZION under 400 tokens. It must fit in the prompt cache and load on every session.

---

## Step 3 — Configure the risk policy

`policies/RISK_POLICY.md` defines low/medium/high risk. The structure works for any support team, but the examples are generic. Replace the examples with your platform's specifics:

- What does a "low risk" change look like in your system? (e.g., CSS change, copy edit, config toggle)
- What makes something automatically high risk? (e.g., payment flow, auth, production database)
- What are your Tier 1 Sentinel patterns? (operations that should always be blocked)

---

## Step 4 — Create your first project

Copy the template:
```bash
cp -r projects/_template projects/your-project-slug
```

Edit `projects/your-project-slug/RSI.yaml`:

```yaml
slug: your-project-slug
name: "Your Project Name"
description: "One sentence about what this project is"
operator: "Your name"

# Critical flows — things that earn money or define the product
critical_flows:
  - "[Flow 1]"
  - "[Flow 2]"

# Do not touch without explicit approval
do_not_touch:
  - "[Something dangerous]"

# Where the working files live
working_directory: "/path/to/your/project/files"

# Deployment method
deployment: git  # or: sftp, ci-cd, manual
```

---

## Step 5 — Wire up the Claude Code hooks

`.claude/settings.json` contains two hooks:
1. **Stop hook** (`gate-check.sh`) — blocks exit if a ticket flag is active (the Ralph Loop)
2. **PreToolUse hook** (`track-tool.py`) — writes every tool call to the dashboard state

These are already configured. Make sure Claude Code reads them by running `claude` from the project root (where `.claude/settings.json` lives).

---

## Step 6 — Test the Ralph Loop

```bash
# Create a test flag
touch /tmp/matrix-ticket.flag

# Try to exit a Claude session — it should be blocked
claude
# Type: /exit or Ctrl+D — Claude should show a Gate E warning

# Clean up
rm /tmp/matrix-ticket.flag
```

---

## Step 7 — Run the dashboard (optional)

```bash
./scripts/dashboard.sh
# → http://localhost:2025
```

The dashboard shows active agent, current tool, Gate E status, and a live event log. It reads `/tmp/matrix-state.json` and `/tmp/matrix-events.jsonl` written by the PreToolUse hook.

---

## Step 8 — Launch

```bash
./scripts/matrix.sh
# → or: ./scripts/matrix.sh your-project-slug
```

Smith will greet you and ask for the ticket.

---

## Adapting the agent prompts

Each agent in `agents/` is a complete system prompt. They're written generically but reference a few structural conventions you should keep:

- The **compressed brief format** (Smith → worker header block) — all agents expect this format
- The **FIXED_WHEN field** — workers must state this and verify it before declaring done
- The **Gate E checklist** — Smith runs this at close; don't remove any steps
- The **ZION_CORE block** — Smith injects this into every sub-agent brief; keep it

You can extend any agent's capabilities, but avoid shortening the gate and verify logic — that's where the reliability comes from.

---

## Adapting the playbooks

`playbooks/` contains generic runbooks for common ticket types. Each playbook follows the same structure:

```markdown
# [Ticket Type] — Playbook

## When to use this
## Diagnosis steps
## Common root causes
## Fix approach
## Test instructions template
## Escalation triggers
```

Add playbooks for ticket types that recur in your team. Smith references playbooks in the brief, and workers load the relevant one at the start of their session.

---

## Multi-model routing

`scripts/activate.sh` routes each agent to the right AI. Edit the `primary_ai()` function to match your preferences:

```bash
primary_ai() {
    case "$1" in
        oracle)                        echo "gemini" ;;
        junior|midlevel)               echo "codex"  ;;
        smith|senior|seraph|cypher|\
        trinity|morpheus|commander)    echo "claude" ;;
        *)                             echo "claude" ;;
    esac
}
```

If you only have Claude, all agents will use Claude — the fallback logic handles this automatically.

---

## Language rules

If your team handles tickets in multiple languages, edit the language rules in `memory/ZION.md`:

```markdown
## Language rules
- All operator ↔ agent communication = [your internal language]
- All client-facing text = match the client's language
```

If you're monolingual, remove the language rules section. Smith will still produce reply drafts in the same language.

---

## What to keep, what to change

| Component | Keep as-is | Adapt |
|-----------|-----------|-------|
| `scripts/gate-check.sh` | ✓ | — |
| `scripts/track-tool.py` | ✓ | — |
| `scripts/matrix-dashboard.py` | ✓ | — |
| `dashboard/index.html` | ✓ | — |
| `.claude/settings.json` | ✓ | — |
| `policies/HUMAN_GATES.md` | Gate structure | Human-only action table |
| `policies/SENTINELS.md` | Tier structure | Patterns for your platform |
| `policies/RISK_POLICY.md` | Level structure | Examples and auto-flags |
| `memory/ZION.md` | Non-negotiables | "Who we are" section |
| `agents/SMITH.md` | Full flow | Working directory paths |
| Worker agents | Gate logic, VERITAS, self-verify | Platform-specific commands |
