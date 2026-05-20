# Handoff — How Agents Chain

This document defines how agents pass work to each other. Smith orchestrates all handoffs — agents do not call each other directly.

---

## The compressed brief format

Every handoff from Smith to a worker includes a compressed brief in this format:

```
FROM: smith
TO: [agent]
PROJECT: [slug]
CLIENT: [name]
CLIENT_LANGUAGE: [detected language code]
RISK: [low|medium|high]
MODE: [fix|investigation|estimate|mixed|communication]
SUMMARY: [1-2 sentences]
FIXED_WHEN: [concrete, observable outcome]
TICKET_TYPE: [bug|regression|config|content|update|performance|security|question]
PLAYBOOK: [filename or none]
INCIDENT_MATCH: [pattern ID or none]
SENTINEL_FLAGS: [list or none]
DEPLOYMENT: [git|sftp|ci-cd|manual|unknown]
BACKUP_REQUIRED: [yes|no]
INVOLVES_PRODUCTION: [yes|no]
QUESTIONS_ANSWERED: [clarifications from this session, or none]

ZION_CORE:
- Nothing to production without the operator's explicit "approved"
- No database write without a confirmed backup immediately before
- No fix delivered without numbered test instructions + expected outcomes
- Never guess credentials, API keys, or configs — ask the operator
- VERITAS: no claim about system state without evidence from this session
- Ask one question at a time — wait for the answer before asking the next
- If scope grows beyond the brief — stop and report, don't expand silently
```

---

## Handoff sequence (full path)

```
Smith → (brief approved by operator)
     → Cypher: "Critique this plan. Return PASS or BLOCK."
     ↓ (if PASS)
     → Worker (Junior/Midlevel/Senior): "Implement the fix."
     ↓ (on completion)
     → Tester: "Run all available test suites. Return PASS/FAIL."
     ↓ (if PASS)
     [/compact on Claude]
     → Seraph: "Run pre-flight check. Return PASS or BLOCK."
     ↓ (if PASS)
     → Smith presents final packet to operator
     ↓ (operator approves)
     → Gate E: write-back protocol
```

---

## What each handoff contains

### Smith → Cypher
- Compressed brief
- Proposed approach (from initial triage)
- Any Sentinel flags

### Smith → Worker
- Compressed brief
- Project slug (worker loads its own context)
- Cypher PASS confirmation (full path) or "fast path, no Cypher"

### Worker → Smith (work log)
- Files changed
- Change summary
- Test instructions
- FIXED_WHEN verification result

### Smith → Tester
- Compressed brief
- Worker output (especially changed files)

### Smith → Seraph
- Compressed brief
- Worker summary
- Tester results

### Smith → Operator (final packet)
- Worker summary
- Files changed
- Tester results
- Seraph result
- Client reply draft (if requested)

---

## Handoff file protocol (Codex/Gemini)

When Smith chains to a non-Claude agent (Codex pipeline), it writes a handoff file:

```bash
# Smith writes:
echo "next_agent=midlevel
project=my-project
status=ready" > "$MATRIX_HANDOFF_FILE"

# Next agent reads $MATRIX_HANDOFF_FILE on start
```

For Claude sub-agents, handoffs happen in-session via the `Agent` tool — no files needed.

---

## Rules

- Workers never call each other directly — all routing goes through Smith
- Cypher only receives the brief and proposed approach — not the full conversation
- Seraph receives a summary, not raw tool outputs — compact context first
- Gate E runs in Smith's session — not delegated to a sub-agent
