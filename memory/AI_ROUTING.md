# AI Routing — Model Preferences Per Agent

This file documents which AI model each agent should run on and why. The `activate.sh` script uses these preferences automatically.

---

## Routing table

| Agent | Primary | Fallback | Reason |
|-------|---------|----------|--------|
| Smith | Claude | Codex | Needs file write tools for Gate E write-back |
| Senior | Claude | Codex | Complex reasoning + file write |
| Cypher | Claude | Codex | Adversarial reasoning requires full capability |
| Morpheus | Claude | Codex | Code review requires nuanced reading |
| Seraph | Claude | Codex | Pre-flight verification requires file read |
| Trinity | Claude | Codex | Client communication requires tone control |
| Commander | Claude | Codex | Deployment coordination requires reasoning |
| Midlevel | Codex | Claude | Fast execution, pre-loaded context |
| Junior | Codex | Claude | Fast execution, pre-loaded context |
| Tester | Claude | Codex | Test suite execution + reporting |
| Oracle | Gemini | Claude | Large-context research (dump full docs) |

---

## When to override

Use the third argument to `activate.sh` to override the default model:

```bash
./scripts/activate.sh smith my-project codex   # Force Codex (Claude rate-limited)
./scripts/activate.sh oracle my-project claude  # Force Claude (Gemini unavailable)
```

Or check model availability:
```bash
./scripts/activate.sh status
```

---

## Capability notes

### Claude
- Full file read/write tools
- Interactive reasoning and tool use
- Write-back (Gate E) works automatically
- Best for: orchestration, complex decisions, client communication

### Codex
- File read/write + shell execution
- Pre-loaded context via `--system` flag
- Produces clean diffs
- Best for: implementation tasks, workers with well-defined scope

### Gemini
- Very large context window (dump entire project docs)
- No file write tools
- Write-back must be done via labelled output blocks (operator applies manually)
- Best for: Oracle research, reading large codebases or documentation dumps
