# Hardline — Abort and Rollback Protocol

> When the work can't safely continue, stop. Don't improvise.

---

## What the Hardline is

The Hardline is the abort protocol. It activates when a ticket reaches a state where continuing would be more dangerous than stopping. It is not a failure — it is the correct response to a class of situations.

Named after the hard-wired telephone lines in The Matrix — the only safe way out when things go wrong inside the system.

---

## When to trigger the Hardline

Trigger immediately when any of these occur:

1. **A Tier 1 Sentinel fires on the proposed plan** — a command that would cause irreversible damage was generated
2. **Cypher returns BLOCK** — the plan has a flaw serious enough to stop execution
3. **Seraph returns BLOCK** — the pre-flight check failed
4. **Scope grows beyond the brief** — the fix requires changes the brief did not anticipate
5. **An assumption in the plan turns out to be false** — e.g. a file doesn't exist, a backup failed, a system state is different from expected
6. **The operator is unavailable for a required Gate** — don't proceed without them
7. **A partial change has been made and completing it safely is unclear**

---

## What to do when the Hardline activates

### Step 1 — Stop
Do not make any further changes. Do not attempt to "fix the fix."

### Step 2 — Report current state
Tell the operator exactly what happened:

```
## Hardline Activated

**Reason:** [why the Hardline triggered]
**State:** [what has been changed so far, if anything]
**Risk:** [what could go wrong if left in current state]
```

### Step 3 — Assess reversibility

| State | Action |
|-------|--------|
| No changes made yet | Safe to stop. Recommend approach changes. |
| Changes made, staging only | Changes are safe. Describe what was done. Await operator instructions. |
| Changes made, production | Provide rollback steps immediately. |
| Partial change, system may be broken | Produce emergency rollback and escalate to operator now. |

### Step 4 — Provide rollback (if changes were made)

Provide the exact rollback steps — do not just describe them generally:

```
## Rollback Steps

1. [Exact command or action]
2. [Exact command or action]
**Verify rollback by:** [how to confirm the system is back to pre-change state]
```

### Step 5 — Wait

Do not proceed. Do not guess. Wait for the operator to make a decision.

---

## Where tickets go when blocked

If a ticket is blocked waiting on an external dependency (client action needed, third-party support, manual access required), it moves to `control-room/transit/MOBIL_AVE.md`.

```markdown
## [INC-ID] — [Short title]

**Blocked since:** [date]
**Blocked by:** [what is needed]
**Status:** Waiting — [what needs to happen before work can resume]
**Context:** [brief summary of where work stopped]
```

---

## Rules

- The Hardline is not a place of shame — it is the correct response to ambiguity
- Never attempt a rollback without confirming it with the operator first
- Never leave a partial change in production without an active rollback plan
- A partial fix that makes things worse is worse than no fix at all
