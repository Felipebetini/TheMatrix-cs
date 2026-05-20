# The Matrix

# This is still a work in progress; use it at your own risk!

> **An AI harness for support teams. Not just prompts — a system with teeth.**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Runs on Claude Code](https://img.shields.io/badge/runs%20on-Claude%20Code-blueviolet)](https://claude.ai/code)
[![Setup](https://img.shields.io/badge/Setup-guide-brightgreen.svg)](https://github.com/Felipebetini/TheMatrix-cs/blob/main/SETUP.md)

The Matrix is an open-source template for running a team of AI agents that handle support tickets — with human approval at every risky step and mandatory knowledge write-back after every resolved ticket. It works for any support team: SaaS, e-commerce, CMS, internal tooling.

---

<!-- DEMO VIDEO -->
<!-- Record and drop your video here. Suggested scenes:
     1. dashboard.sh — Matrix rain, live tool log
     2. ./scripts/matrix.sh — Smith greeting, ticket intake
     3. The pipeline running — agent names flipping on the dashboard
     4. The Ralph Loop blocking exit — the money shot
     See README for the full recording script. -->

---

## Table of contents

- [Quick start](#quick-start)
- [Adapting it to your team](#adapting-it-to-your-team)
- [The live dashboard](#the-live-dashboard)
- [Repository structure](#repository-structure)
- [How it works](#the-problem)
  - [The problem](#the-problem)
  - [Agent = Model + Harness](#agent--model--harness)
  - [The 5 harness components](#the-5-harness-components)
  - [Context rot: why sessions degrade](#context-rot-why-sessions-degrade)
  - [The mechanisms](#the-mechanisms)
  - [Sentinels — deterministic safety](#sentinels--deterministic-safety)
  - [VERITAS — evidence-first protocol](#veritas--evidence-first-protocol)
  - [The 11 agents](#the-11-agents)
  - [The two-speed workflow](#the-two-speed-workflow)
  - [Why these names](#why-these-names)
- [Design principles](#design-principles)
- [References](#references)

---

## Quick start

**Minimum requirement:** Claude Code CLI

```bash
npm install -g @anthropic-ai/claude-code
```

Optional (for multi-model routing):
```bash
npm install -g @openai/codex          # Junior, Midlevel workers
npm install -g @google/gemini-cli     # Oracle research agent
```

**Install and run:**

```bash
git clone https://github.com/Felipebetini/TheMatrix-cs.git
cd TheMatrix-cs
chmod +x scripts/*.sh
./scripts/matrix.sh
```

**What you'll see:**

```
  ▶  Matrix starting

  Which AI?
  [1] Claude  — full file tools, write-back, interactive  (default)
  [2] Codex   — pre-loaded context, produces diffs
  [3] Gemini  — large context dumps (Oracle only)

  >

▶  Matrix: smith → claude  |  project: none  |  context: 142 lines

Matrix online. Which project are we working on today?
```

**Verify the Ralph Loop is wired:**

```bash
touch /tmp/matrix-ticket.flag
# open a Claude Code session and try to exit → should be blocked
rm /tmp/matrix-ticket.flag
```

**Check which AI CLIs are available:**

```bash
./scripts/activate.sh status
```

> **Before your first real ticket:** the launcher will detect unconfigured state and walk you through setup automatically. Or run `./scripts/setup.sh` directly. See `SETUP.md` for the full guide.

---

## Adapting it to your team

The harness — hooks, gates, scripts, dashboard — works out of the box. Three files need your context before you start:

**1. `memory/ZION.md`** — Replace the "Who we are" section with your team and domain. Keep the non-negotiables, or rewrite them for your context. Keep the file under 400 tokens.

**2. `policies/RISK_POLICY.md`** — Replace the examples and automatic high-risk flags with the operations that are genuinely dangerous in your system. The three-tier structure is reusable as-is.

**3. `projects/_template/RSI.yaml`** — Create one directory per client or product. The RSI (Relationship and System Identity) card is what Smith loads to understand the project before reading any ticket. Fill in the critical flows and do-not-touch zones.

See [`SETUP.md`](https://github.com/Felipebetini/TheMatrix-cs/blob/main/SETUP.md) for the full adaptation guide, including multi-language teams, Codex-only setups, and how to write playbooks for your ticket types.

---

## The problem

You can give an AI a good system prompt and get good results *most of the time*. But "most of the time" is not good enough when the AI has tools that touch live production systems.

The failure modes are predictable:

- The AI states a diagnosis as fact before actually verifying it
- The AI marks a ticket done without observing whether the fix worked
- The session ends and nothing is written back — the knowledge evaporates
- The AI expands its own scope because "be helpful" overrides "stay in scope"
- A risky command is generated and no one catches it because no one was checking

Good prompts *reduce* the frequency of these failures. They don't *prevent* them — because a model can always reinterpret, skip, or abbreviate a prompt instruction when it conflicts with completing the task quickly. The path of least resistance is always to say "done."

**The Matrix treats these as engineering problems, not prompting problems.** The harness enforces what the prompt requests.

---

## Agent = Model + Harness

This framing comes from Viv Trivedy's *"The Anatomy of an Agent Harness"* — the foundational article that shaped this system's architecture. The core claim:

> An agent is not the model. An agent is the model plus the harness that governs it.

| | What it provides |
|-|-----------------|
| **Model** | Intelligence — reasoning, writing, code, diagnosis, judgment |
| **Harness** | Reliability — what the model *must* and *cannot* do, regardless of what it wants to do |

The model is Claude (or Codex, or Gemini). The harness is everything else: the shell hooks, the flag files, the gate checks, the context loading order, the routing logic, the write-back protocol.

The CI/CD analogy is exact. You don't trust a production deployment because the developer promised it's fine. You trust it because the pipeline checked it: tests passed, linting passed, the review was approved. The pipeline isn't intelligent — it's deterministic — and that's precisely what makes it reliable. The developer's judgment is valuable; the pipeline's constraints are what make that judgment trustworthy.

The harness does the same thing for agents.

> *Prompt instructions are soft. Hooks and loops are hard.*

---

## The 5 harness components

Trivedy identifies five components that a complete agent harness must provide. Most teams build only the first two.

**1. System prompts** — The model's operating instructions: role, rules, workflow, tone. Necessary, not sufficient.

**2. Tools and MCPs** — What the agent can act on. Tools define the blast radius. The harness controls which tools are available to which agents.

**3. Bundled infrastructure** — Context the agent needs but shouldn't have to find: the project identity card, the incident history, the error signatures. The `activate.sh` script builds this and injects it at session start.

**4. Orchestration logic** — How agents chain: Smith spawns Cypher, then the worker, then Tester, then Seraph. The compressed brief format that passes between them. This is the pipeline the shell scripts and Claude Code's `Agent` tool implement.

**5. Hooks and middleware** — Hard constraints enforced at the OS level, outside the model's control. The Stop hook that blocks exit. The PreToolUse hook that logs every tool call. These are not suggestions. The model cannot override them.

The Matrix implements all five. Most AI support workflows implement only 1 and 2.

---

## Context rot: why sessions degrade

Every tool call adds tokens to the context window. In a long support session — investigation, review, critique, test output — the context grows until the model is reasoning about its own earlier reasoning instead of the actual problem. Trivedy calls this *context rot*.

Symptoms: the agent hedges on things it was certain about earlier; it "forgets" ZION constraints; quality degrades in the second half of a long session.

The Matrix addresses context rot at three levels:

**Selective loading.** `activate.sh` builds context deliberately: ZION always, the current project RSI, the current agent prompt, the relevant playbook only if Smith flagged one. Nothing else. Agents read additional files on demand — they don't receive them pre-loaded.

**Token discipline in ZION.** Log files → last 50 lines. Large files → `grep` first, read only the relevant section. One tool call cannot flood the context with irrelevant content.

**Compaction before Seraph.** After a heavy investigation or review phase, Smith runs `/compact` before spawning Seraph. Seraph is a verification agent — it needs a focused view of what was *decided*, not a transcript of how the decision was reached.

Skills in `.agents/skills/` serve a related purpose: *progressive disclosure* (Trivedy's term). Each skill is a short, focused instruction set loaded only when invoked. The Gate E write-back protocol doesn't live in context during investigation — it's loaded when Gate E starts.

---

## The mechanisms

### 1. ZION — The always-loaded constitution

ZION is a tiny file (≤400 tokens) that loads into every agent session, for every agent, on every ticket. It contains the rules that cannot be overridden by a clever ticket, a persuasive client, or scope drift from a well-meaning worker.

The size constraint is functional, not aesthetic. Prompt caching in Claude has a 5-minute TTL. If ZION fits in the cache, it loads for free on every turn. If it's too long, agents either stop reading it or it crowds out working context. **If it must always apply, it must always load, which means it must always be small.**

ZION contains:
- 9 hard rules (no production without explicit approval, no DB write without backup, etc.)
- Language rules (agent↔operator in one language; client replies in the client's language)
- The escalation path
- Context loading order and token discipline

Smith also injects a compressed ZION core block directly into every sub-agent brief it passes — the "context engineering on behalf of agents" pattern from Trivedy's second article. Don't rely on sub-agents to load their own constraints. Build those constraints into the message they receive.

In the film: Zion is the last human city — the one place the machines haven't reached, where their rules don't apply. In the system: ZION is the set of rules the model cannot negotiate away from, regardless of what the ticket says.

### 2. The Ralph Loop — Blocked exit

Named for Geoffrey Huntley's essay *"Everything is a Ralph Loop."* The core pattern:

> Intercept the model's exit. Reinject the original prompt in a clean context window. Force continuation against a completion goal. One task per loop.

The Matrix implements this using Claude Code's built-in Stop hook:

```
On ticket start:
  Smith writes  →  touch /tmp/matrix-ticket.flag

On every exit attempt:
  gate-check.sh runs (Stop hook)
  if flag exists → print Gate E checklist, exit 1  ← blocks the stop

On Gate E completion:
  Smith writes  →  rm -f /tmp/matrix-ticket.flag  →  exit allowed
```

This is the engineering answer to the most common AI failure: the model declares done before the work is actually done. Declaring the task finished is always the path of least resistance. The flag file and Stop hook make that path physically blocked until Gate E is verified.

Huntley: *"Software like clay on a pottery wheel."* The loop makes the agent's output revisable — each pass can reshape what came before. Without the loop, Gate E is a suggestion. With it, it's a hard constraint enforced at the OS level.

### 3. Self-Verify — Observe, don't assume

Trivedy's second article describes `PreCompletionChecklistMiddleware`: before the model reports a task as complete, it must satisfy a checklist — not by saying "yes I did all of these," but by actually running the checks.

The Matrix implements this as the **self-verify loop**:

1. Before implementing, the worker states `FIXED_WHEN: [exact observable outcome]`
2. After implementing, the worker runs the tool that would confirm or deny that outcome
3. Compares actual output to expected output
4. If they match: done. If not: re-diagnose
5. Three failed iterations → Hardline, not a fourth guess

Step 2 is the critical one. Most AI workflows end with the model saying "I've made the changes" based on the output of the *edit tool* — not based on observing that the *system actually behaves differently*. The edit tool confirms the file changed. `FIXED_WHEN` requires the model to observe the consequence.

### 4. Doom loop detection

From Trivedy's `LoopDetectionMiddleware`: if the Build→Verify cycle has failed N times with no progress, stop rather than continuing to vary the approach.

The Matrix sets this at **three iterations**. Three failures with the same confirmed root cause means the root cause is probably wrong — a human needs to make that call. The Hardline activates, execution stops, and the operator decides what happens next.

This matters because stuck AI agents tend to vary the fix in increasingly speculative ways — changing more things, growing the blast radius, introducing new risks with each attempt.

### 5. Gate E — Mandatory write-back

A ticket is not closed until five things happen:

| Step | What |
|------|------|
| **10a** | `CHANGELOG.md` updated — what changed and when |
| **10b** | `INCIDENT_LOG.md` updated — root cause and resolution |
| **10c** | `ERROR_SIGNATURES.md` checked — new error patterns added |
| **10d** | `INCIDENT_PATTERNS.md` checked — cross-project matches noted |
| **10e** | Ticket record created |

Gate E is what makes the system smarter after every ticket. Without it: an AI that solves problems and forgets them. With it: the second occurrence of any pattern is handled faster than the first, because the first occurrence was documented, the root cause was recorded, and the fix is retrievable.

Step 10d is the most valuable over time. Every ticket either matches a known pattern or teaches a new one. `INCIDENT_PATTERNS.md` is the system's long-term memory — a lookup table of root causes and their signatures, built from real incidents. Huntley's livestream: specs as lookup tables with synonyms to improve search hit rate. That's exactly what this file becomes.

The Ralph Loop ensures Gate E runs. Gate E ensures write-back completes before the flag is removed. Together: **no session ends without the knowledge transfer completing.**

### 6. Multi-model routing

Different agents run on different models because different tasks have fundamentally different requirements:

| Model | Strength | Agents |
|-------|---------|--------|
| **Claude** | Long-horizon reasoning, file write-back, interactive judgment | Smith, Senior, Cypher, Seraph, Trinity, Commander |
| **Codex** | Fast execution, clean diffs, pre-loaded context | Junior, Midlevel |
| **Gemini** | Very large context — 50+ files without degrading | Oracle |

`activate.sh` routes automatically: primary model per agent type, automatic fallback if unavailable, clipboard fallback if no CLI is installed.

Oracle's job is reading full documentation. Dumping a 50-file codebase into Gemini's million-token context window is faster and cheaper than doing it in Claude, and better quality because the model isn't reasoning under pressure. Junior and Midlevel don't need Claude's full capability — they need fast execution of a well-defined brief.

The routing is overrideable: `./scripts/activate.sh smith my-project codex` forces Codex when Claude is rate-limited. The system degrades gracefully rather than blocking.

---

## Sentinels — Deterministic safety

The most philosophically important design choice in the system: **safety-critical pattern matching is done deterministically, not with LLM reasoning.**

When a Tier 1 pattern appears — `DROP TABLE`, `rm -rf`, any credential in a command — the block happens via keyword matching. No model, no context window, no chance of the model deciding the pattern is acceptable just this once.

This matters because LLMs can be reasoned into exceptions. A carefully constructed ticket or a confident model can rationalize why `rm -rf` is appropriate in this specific case. A bash `if` statement cannot.

**Tier 1 — Auto-block.** `DROP TABLE`, `DELETE FROM`, `rm -rf`, `chmod 777`, credentials in commands. Immediate block, no exceptions, explicit operator override required.

**Tier 2 — Auto-escalate.** Payment, auth, database, security keywords. Override routing to Senior regardless of Smith's initial classification. The model's risk assessment is a secondary signal; the keyword is the primary one.

**Tier 3 — Flag.** Don't block, but change how Smith frames the brief. `"I tried everything"` → get the full list before touching anything. `"Always worked before"` → check CHANGELOG first.

Sentinels run twice: on the raw ticket text (by Smith) and on the generated plan (by Seraph). First pass catches client-supplied risk signals. Second catches agent-generated risky commands — the fix that's correct for the diagnosis but contains a command that should never appear.

---

## VERITAS — Evidence-first protocol

Before stating anything as fact about a project's state, an agent must have evidence from *this session*: a file it read, a command it ran, something the operator said explicitly. Not prior tickets. Not general knowledge. Not "usually this system does X."

The most common failure mode in remote debugging is a cascade of unverified assumptions:

1. *"This is probably a caching issue"* — not verified
2. Operator clears cache → doesn't fix it
3. *"Then it's a conflict"* — not verified
4. Operator disables services → product breaks
5. *"Restore and try X"* — no backup was taken

VERITAS breaks this at step 1: *what specific tool output points to cache as the cause?* If the answer is nothing, that's a hypothesis — and it must be labelled as one. Hypotheses are correct and useful. Unverified facts presented as confirmed diagnoses are what cause the cascade above.

Cypher's first question on every review: "Is the root cause actually verified, or just stated?" Seraph blocks on any `[unverified]` claim in the Approval Packet.

---

## The 11 agents

| Agent | Single responsibility | Model | Character |
|-------|----------------------|-------|-----------|
| **Smith** | Intake → brief → orchestrate → Gate E | Claude | The enforcer. Processes everything. |
| **Junior** | Low-risk fixes | Codex | — |
| **Midlevel** | Medium-risk fixes, staging | Codex | — |
| **Senior** | High-risk fixes, Approval Packets | Claude | — |
| **Cypher** | Adversarial plan critique | Claude | The insider threat — challenges before execution |
| **Morpheus** | Code diff review | Claude | The mentor — reads what's real, not what's claimed |
| **Seraph** | Pre-flight verification | Claude | The guardian — tests before granting access |
| **Oracle** | External research | Gemini | Knows, but makes you earn the answer |
| **Trinity** | Estimates + client comms | Claude | The bridge between technical and human |
| **Tester** | Test suite execution | Claude | — |
| **Commander** | Deployment sequencing | Claude | Coordinates the operation |

One goal per agent (Huntley's principle). Smith produces a brief. Cypher returns PASS or BLOCK. Seraph returns PASS or BLOCK. Workers return a work log. This makes the pipeline auditable — you can read any agent's output and immediately know whether it did its job.

---

## The two-speed workflow

Smith classifies every ticket and routes to one of two paths:

```
FAST PATH — low risk (content, CSS, simple config)
──────────────────────────────────────────────────────────────────
  ticket
    │
    ▼
 SMITH ──────────► JUNIOR / MIDLEVEL ────────► SERAPH
 triage              implement                  verify
 brief                                            │
    │                                           PASS
    │                                             │
    └─────────────────────────────────────────────► Gate A
                                                  operator test
                                                       │
                                                    Gate E ──► done



FULL PATH — medium / high risk (production, DB, auth, payments)
──────────────────────────────────────────────────────────────────
  ticket
    │
    ▼
 SMITH ──► CYPHER ──► WORKER ──► TESTER ──► SERAPH
 triage    critique   implement  run suites  verify
             │                                 │
           BLOCK?                            PASS
         (revise)                              │
                                           Gate A
                                         operator tests staging
                                              │
                                           Gate B
                                         operator approves production
                                              │
                                          COMMANDER
                                         deploy sequence
                                              │
                                           Gate E ──► done
```

Fast path: Smith to execution in minutes. Full path: Cypher critiques the plan, Tester runs suites, Seraph verifies the checklist, operator explicitly approves before anything touches production.

Risk escalation is one-directional. Tier 2 Sentinel keywords override Smith's classification upward. A ticket that looks like simple config but mentions "payment" goes to Senior regardless.

---

## Why these names

The naming is deliberate. Each character in the 1999 Wachowski film maps to a function in the system. The metaphors aren't decorative — they're mnemonic.

**The Matrix (the film).** Most humans live in a simulated reality, governed by rules they can't see and don't question. The agents in this system also operate inside a constructed reality: a context window built by `activate.sh`, governed by rules they didn't write. They don't know they're in a simulation. The harness is the real world.

**Agent Smith.** In the film: the system's enforcer, who processes anomalies and maintains order. In the system: the first and last agent on every ticket. He classifies, routes, orchestrates, and closes. Every ticket passes through Smith. His personality prompt is intentionally dry: *"I need the error message, not a description of how it feels."*

**ZION.** In the film: the last human city — the one place the machines haven't reached, where the Matrix's rules don't apply. In the system: the core rules no agent can override. ZION is what makes the simulation safe to operate in. Small. Always present. Non-negotiable.

**Cypher.** In the film: the insider who decides the simulation is more comfortable than reality, and betrays the team from within. In the system: Cypher plays the adversarial role intentionally. He looks for the flaw that the worker's optimism missed, asking the question no one wants to ask: *"Is the root cause actually confirmed, or is the worker just confident?"*

**Seraph.** In the film: the Oracle's guardian, who tests Neo before granting access — fighting him to be sure. *"I had to be sure."* In the system: the pre-flight gate that tests every plan before it touches production. Seraph has no opinions about the fix. He only verifies that the process was followed. *"I had to be sure."*

**The Oracle.** In the film: she knows things but delivers knowledge in ways you have to earn — giving you what you're ready to receive. In the system: the research agent, running on Gemini with large-context capabilities, looking up docs, changelogs, and error signatures. She informs; she doesn't fix.

**Trinity.** In the film: the bridge between the world of humans and the world of machines. In the system: Trinity bridges the technical work and the client relationship — drafting replies and effort estimates that translate what the agents found into what the client can act on.

**Morpheus.** In the film: the mentor who has seen the system longest and can read what others miss. In the system: Morpheus reviews the code diff, not the intent. He reads what was *actually* changed, not what the worker said they changed.

**The Nebuchadnezzar.** In the film: the hovercraft the crew operates from — their base of operations in the real world. In the system: `control-room/NEBUCHADNEZZAR.md` is the active ticket board — the operator's view of what's currently in flight.

**Mobil Avenue.** In the film: the transit zone between the Matrix and the machine world, where Anderson is stranded between realities. In the system: `transit/MOBIL_AVE.md` is where tickets go when they're blocked waiting on something outside the system — a client action, a DNS change, a third-party response. Not quite open, not quite closed.

**The Ralph Loop.** Not from The Matrix. Named by Geoffrey Huntley in *"Everything is a Ralph Loop."* Intercept the model's exit, force continuation against a completion goal, one task per loop.

---

## The live dashboard

A terminal-style dashboard served locally on `localhost:2025`.

```bash
./scripts/dashboard.sh
# → opens http://localhost:2025
```

Shows in real time:
- Active agent and project
- Current model
- Current tool being called (updated on every PreToolUse event)
- Gate E armed / clear
- Live event log with timestamps

The PreToolUse hook (`scripts/track-tool.py`) writes every tool call to `/tmp/matrix-state.json` and `/tmp/matrix-events.jsonl`. The dashboard polls those files every second. Python stdlib only — no pip installs. The Matrix rain animation is canvas-based with no libraries.

---

## Repository structure

```
the-matrix/
├── README.md                    ← you are here
├── SETUP.md                     ← full adaptation guide
├── CLAUDE.md                    ← auto-loaded by Claude Code on launch
├── AGENTS.md                    ← auto-loaded by Codex on launch
│
├── agents/                      ← 11 agent system prompts
│   ├── SMITH.md
│   ├── JUNIOR.md  MIDLEVEL.md  SENIOR.md
│   ├── CYPHER.md  MORPHEUS.md  SERAPH.md
│   ├── ORACLE.md  TRINITY.md   TESTER.md  COMMANDER.md
│
├── memory/
│   ├── ZION.md                  ← always-loaded constitution (≤400 tokens)
│   ├── INCIDENT_PATTERNS.md     ← cross-project pattern library
│   ├── AI_ROUTING.md            ← model preferences per agent
│   ├── CAPABILITIES.md          ← what each model can do directly
│   ├── SKILLS.md                ← which skills to invoke when
│   └── CODEX.md                 ← Codex-specific runtime rules
│
├── policies/
│   ├── RISK_POLICY.md           ← low / medium / high classification
│   ├── HUMAN_GATES.md           ← Gates A–E definitions
│   ├── SENTINELS.md             ← deterministic block + escalate patterns
│   ├── VERITAS.md               ← evidence-first protocol
│   ├── HANDOFF.md               ← compressed brief format + chain protocol
│   └── HARDLINE.md              ← abort and rollback protocol
│
├── playbooks/                   ← runbooks for known ticket types
│   ├── account-access-issue.md
│   ├── integration-broken.md
│   └── performance-issue.md
│
├── projects/
│   └── _template/
│       ├── RSI.yaml             ← project identity card (copy per client)
│       └── CHANGELOG.md         ← support change log
│
├── tickets/
│   └── _template/TICKET.md      ← ticket record (created at Gate E)
│
├── scripts/
│   ├── matrix.sh                ← launcher (start here)
│   ├── activate.sh              ← AI routing + context builder
│   ├── gate-check.sh            ← Stop hook — the Ralph Loop enforcer
│   ├── track-tool.py            ← PreToolUse hook — writes dashboard state
│   ├── matrix-dashboard.py      ← web server (Python stdlib, no pip)
│   └── dashboard.sh             ← dashboard launcher
│
├── dashboard/
│   └── index.html               ← Matrix rain + live event log
│
├── .claude/
│   ├── settings.json            ← Stop hook + PreToolUse hook wiring
│   └── commands/vault.md        ← /vault skill (Obsidian integration)
│
├── .codex/
│   ├── agents/                  ← Codex agent definitions (4 roles)
│   └── config.toml
│
├── .agents/
│   └── skills/                  ← 8 lazily-loaded Codex skills
│       ├── diagnose.md          ← structured hypothesis tree
│       ├── verify.md            ← self-verify loop
│       ├── sentinel-scan.md     ← deterministic pattern check
│       ├── gate-e.md            ← write-back protocol
│       ├── risk-classify.md     ← risk tier + sentinel flags
│       ├── incident-search.md   ← history lookup
│       ├── reply-draft.md       ← client communication
│       └── approval-packet.md   ← high-risk approval format
│
├── control-room/
│   └── NEBUCHADNEZZAR.md        ← active ticket board
│
└── transit/
    └── MOBIL_AVE.md             ← blocked tickets queue
```

---

## Design principles

**The harness makes it reliable, not the model.** Every hard constraint is enforced by something outside the model's control: a Stop hook, a flag file, a keyword scan. Prompts guide; the harness enforces. The model's judgment is valuable; the harness's constraints are what make that judgment trustworthy in production.

**Deterministic over probabilistic for safety.** Tier 1 Sentinels are blocked by keyword matching, not LLM reasoning. LLMs can be convinced; a bash conditional cannot. Safety-critical checks must be deterministic.

**Token discipline is an engineering problem.** ZION is ≤400 tokens so it fits the prompt cache. Agents load context on demand because pre-loading everything causes context rot. Skills are lazy-loaded because most capabilities aren't needed on most tickets. These aren't style choices — they're the difference between a session that works on turn 20 and one that has degraded by turn 10.

**One goal per agent.** Each agent has a single, auditable output. This makes the pipeline inspectable and failure-locatable. When something goes wrong you can read the output of each agent in sequence and find exactly where it broke.

**The system must get smarter after every ticket.** Gate E is not optional administration — it converts resolved tickets into permanent institutional knowledge. The second occurrence of any problem is handled faster than the first. This is the compounding return on the system.

**The operator is the last gate.** "Approved" must appear explicitly. Not assumed, not implied, not inferred. The word must appear, in this session, from the operator.

---

## References

The Matrix builds directly on ideas from the following sources. Read them to understand the *why* behind every design decision.

---

### [1] "The Anatomy of an Agent Harness" — Viv Trivedy
**[x.com/Vtrivedy10/status/2031408954517971368](https://x.com/Vtrivedy10/status/2031408954517971368)**

The foundational article. Defines Agent = Model + Harness and identifies the five harness components. Also covers context rot, compaction strategy, skills as progressive disclosure, and Ralph Loops for long-horizon execution. Every architectural decision in The Matrix traces back to a concept in this article.

---

### [2] "Improving Deep Agents with Harness Engineering" — Viv Trivedy
**[x.com/Vtrivedy10/status/2023805578561060992](https://x.com/Vtrivedy10/status/2023805578561060992)**

How LangChain went from Top 30 to Top 5 on Terminal Bench 2.0 by *only* changing the harness, not the model. Introduces `PreCompletionChecklistMiddleware` → self-verify loop and `FIXED_WHEN`; `LoopDetectionMiddleware` → doom loop detection; context engineering on behalf of agents → ZION injection into sub-agent briefs; SSH-first batching → evidence-first principle.

---

### [3] "Everything is a Ralph Loop" — Geoffrey Huntley
**[ghuntley.com/loop/](https://ghuntley.com/loop/)**

The Ralph Loop pattern: intercept the model's exit via hook, reinject the original prompt in a clean context window, force continuation against a completion goal. *"Performs one task per loop. Software like clay on a pottery wheel."* The `gate-check.sh` Stop hook is a direct implementation. Huntley's livestream also introduced specs-as-lookup-tables with synonyms — the philosophy behind `INCIDENT_PATTERNS.md`.

---

### [4] LangChain Deep Agents — Architecture Overview
**[docs.langchain.com/oss/python/deepagents/overview](https://docs.langchain.com/oss/python/deepagents/overview)**

Agent harness architecture reference: task decomposition, virtual filesystem for context offloading, auto-summarization, sandbox execution, subagent spawning, long-term memory, declarative permission rules, provider-agnostic model routing. The multi-model routing in `activate.sh` reflects these patterns.

---

### [5] OpenAI Codex Skills Documentation
**[developers.openai.com/codex/skills](https://developers.openai.com/codex/skills)**

Skill directory structure, SKILL.md frontmatter, lazy loading model (only name + description initially, full instructions on invocation), implicit vs. explicit invocation, discovery priority order. The `.agents/skills/` directory implements this spec.

---

### [6] Obsidian CLI Documentation
**[obsidian.md/help/cli](https://obsidian.md/help/cli)**

CLI commands used for vault integration: `search:context`, `append`, `create`, `backlinks`, `tasks`. The `/vault` Claude Code skill is built on these commands.

---

### Feature attribution

| Feature | Source |
|---------|--------|
| Ralph Loop — Stop hook | Huntley + Trivedy [1] |
| Self-verify loop — `FIXED_WHEN` | Trivedy [2] — `PreCompletionChecklistMiddleware` |
| Doom loop — 3-iteration limit | Trivedy [2] — `LoopDetectionMiddleware` |
| ZION injection into sub-agent briefs | Trivedy [2] — context engineering on behalf of agents |
| Context compaction before Seraph | Trivedy [1] — compaction strategy |
| Token discipline rules | Trivedy [1] — tool call offloading |
| Skills as progressive disclosure | Trivedy [1] + Codex skills docs [5] |
| `INCIDENT_PATTERNS` as lookup tables | Huntley [3] — specs with synonyms |
| One goal per agent | Huntley [3] — one task per loop |
| Multi-model routing | LangChain [4] + Trivedy routing model |
| Codex skills system | OpenAI Codex docs [5] |
| Obsidian vault integration | Obsidian CLI [6] |

---

## License

MIT — use it, adapt it, ship it. Attribution appreciated but not required.

---

*Named after the films. Built for support teams. The agents don't know they're in a simulation — that's the point.*
