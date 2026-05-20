# Architecture — How The Matrix Works

The Matrix is built on a set of mechanisms that enforce reliability at the OS level, not the prompt level. This document covers the problem it solves, the design philosophy, and every mechanism in detail.

← [Back to README](README.md)

---

## The problem

You can give an AI a good system prompt and get good results most of the time. But "most of the time" is not good enough when the AI has tools that touch live production systems.

The failure modes are predictable:

- The AI states a diagnosis as fact before actually verifying it
- The AI marks a ticket done without observing whether the fix worked
- The session ends and nothing is written back, so the knowledge just evaporates
- The AI expands its own scope because "be helpful" overrides "stay in scope"
- A risky command gets generated and no one catches it because no one was checking

Good prompts reduce the frequency of these failures but they don't prevent them, because a model can always reinterpret, skip, or abbreviate a prompt instruction when it conflicts with finishing the task quickly. The path of least resistance is always to say "done."

**The Matrix treats these as engineering problems, not prompting problems.** The harness enforces what the prompt requests.

---

## Agent = Model + Harness

The framing comes from Viv Trivedy's *"The Anatomy of an Agent Harness"*, the foundational article that shaped this system's architecture:

> An agent is not the model. An agent is the model plus the harness that governs it.

| | What it provides |
|-|-----------------|
| **Model** | Intelligence: reasoning, writing, code, diagnosis, judgment |
| **Harness** | Reliability: what the model *must* and *cannot* do, regardless of what it wants to do |

The model is Claude (or Codex, or Gemini). The harness is everything else: shell hooks, flag files, gate checks, context loading order, routing logic, write-back protocol.

Think of CI/CD. You don't trust a production deployment because the developer promised it's fine. You trust it because the pipeline checked it. Tests passed, linting passed, the review was approved. The pipeline isn't intelligent. It's deterministic, and that's precisely what makes it reliable.

The harness does the same thing for agents.

> *Prompt instructions are soft. Hooks and loops are hard.*

---

## The 5 harness components

Trivedy identifies five components that a complete agent harness must provide. Most teams build only the first two.

**1. System prompts.** The model's operating instructions: role, rules, workflow, tone. Necessary, not sufficient.

**2. Tools and MCPs.** What the agent can act on. Tools define the blast radius. The harness controls which tools are available to which agents.

**3. Bundled infrastructure.** Context the agent needs but shouldn't have to find itself: the project identity card, the incident history, the error signatures. The `activate.sh` script builds this and injects it at session start.

**4. Orchestration logic.** How agents chain: Smith spawns Cypher, then the worker, then Tester, then Seraph. The compressed brief format that passes between them. This is the pipeline the shell scripts and Claude Code's `Agent` tool implement.

**5. Hooks and middleware.** Hard constraints enforced at the OS level, outside the model's control. The Stop hook that blocks exit. The PreToolUse hook that logs every tool call. These are not suggestions. The model cannot override them.

The Matrix implements all five. Most AI support workflows implement only 1 and 2.

---

## Context rot: why sessions degrade

Every tool call adds tokens to the context window. In a long support session (investigation, review, critique, test output) the context grows until the model is reasoning about its own earlier reasoning instead of the actual problem. Trivedy calls this *context rot*.

Symptoms: the agent hedges on things it was certain about earlier; it forgets ZION constraints; quality degrades in the second half of a long session.

The Matrix addresses context rot at three levels:

**Selective loading.** `activate.sh` builds context deliberately: ZION always, the current project RSI, the current agent prompt, the relevant playbook only if Smith flagged one. Nothing else. Agents read additional files on demand and don't receive them pre-loaded.

**Token discipline in ZION.** Log files get the last 50 lines. Large files get grepped first, then only the relevant section is read. One tool call cannot flood the context with irrelevant content.

**Compaction before Seraph.** After a heavy investigation or review phase, Smith runs `/compact` before spawning Seraph. Seraph is a verification agent. It needs a focused view of what was *decided*, not a transcript of how the decision was reached.

Skills in `.agents/skills/` serve a related purpose: *progressive disclosure* (Trivedy's term). Each skill is a short, focused instruction set loaded only when invoked. The Gate E write-back protocol doesn't live in context during investigation. It's loaded when Gate E starts.

---

## The mechanisms

<details>
<summary><strong>1. ZION: the always-loaded constitution</strong></summary>

ZION is a tiny file (400 tokens max) that loads into every agent session, for every agent, on every ticket. It contains the rules that cannot be overridden by a clever ticket, a persuasive client, or scope drift from a well-meaning worker.

The size constraint is functional, not aesthetic. Prompt caching in Claude has a 5-minute TTL. If ZION fits in the cache, it loads for free on every turn. If it's too long, agents either stop reading it or it crowds out working context. **If it must always apply, it must always load, which means it must always be small.**

ZION contains:
- 9 hard rules (no production without explicit approval, no DB write without backup, etc.)
- Language rules (agent to operator in one language; client replies in the client's language)
- The escalation path
- Context loading order and token discipline

Smith also injects a compressed ZION core block directly into every sub-agent brief. The idea (from Trivedy's second article): don't rely on sub-agents to load their own constraints. Build those constraints into the message they receive.

In the film, Zion is the last human city. The one place the machines haven't reached, where their rules don't apply. In this system, ZION is the set of rules the model cannot negotiate away from, regardless of what the ticket says.

</details>

<details>
<summary><strong>2. The Ralph Loop: blocked exit</strong></summary>

Named for Geoffrey Huntley's essay *"Everything is a Ralph Loop."* The core pattern:

> Intercept the model's exit. Reinject the original prompt in a clean context window. Force continuation against a completion goal. One task per loop.

The Matrix implements this using Claude Code's built-in Stop hook:

```
On ticket start:
  Smith writes   ->   touch /tmp/matrix-ticket.flag

On every exit attempt:
  gate-check.sh runs (Stop hook)
  if flag exists -> print Gate E checklist, exit 1  (blocks the stop)

On Gate E completion:
  Smith writes   ->   rm -f /tmp/matrix-ticket.flag  ->  exit allowed
```

This is the engineering answer to the most common AI failure: the model declares done before the work is actually done. Declaring the task finished is always the path of least resistance. The flag file and Stop hook make that path physically blocked until Gate E is verified.

Huntley: *"Software like clay on a pottery wheel."* The loop makes the agent's output revisable. Each pass can reshape what came before. Without the loop, Gate E is a suggestion. With it, it's a hard constraint enforced at the OS level.

</details>

<details>
<summary><strong>3. Self-Verify: observe, don't assume</strong></summary>

Trivedy's second article describes `PreCompletionChecklistMiddleware`: before the model reports a task as complete, it must satisfy a checklist. Not by saying "yes I did all of these," but by actually running the checks.

The Matrix implements this as the **self-verify loop**:

1. Before implementing, the worker states `FIXED_WHEN: [exact observable outcome]`
2. After implementing, the worker runs the tool that would confirm or deny that outcome
3. Compares actual output to expected output
4. If they match: done. If not: re-diagnose
5. Three failed iterations means Hardline, not a fourth guess

Step 2 is the critical one. Most AI workflows end with the model saying "I've made the changes" based on the output of the *edit tool*, not on observing whether the *system actually behaves differently*. The edit tool confirms the file changed. `FIXED_WHEN` requires the model to observe the consequence.

</details>

<details>
<summary><strong>4. Doom loop detection</strong></summary>

From Trivedy's `LoopDetectionMiddleware`: if the Build→Verify cycle has failed N times with no progress, stop rather than continuing to vary the approach.

The Matrix sets this at **three iterations**. Three failures with the same confirmed root cause usually means the root cause is wrong. That's when a human needs to step in. The Hardline activates, execution stops, and the operator decides what happens next.

This matters because stuck AI agents tend to vary the fix in increasingly speculative ways, changing more things, growing the blast radius, introducing new risks with each attempt.

</details>

<details>
<summary><strong>5. Gate E: mandatory write-back</strong></summary>

A ticket is not closed until five things happen:

| Step | What |
|------|------|
| **10a** | `CHANGELOG.md` updated with what changed and when |
| **10b** | `INCIDENT_LOG.md` updated with root cause and resolution |
| **10c** | `ERROR_SIGNATURES.md` checked, new error patterns added |
| **10d** | `INCIDENT_PATTERNS.md` checked, cross-project matches noted |
| **10e** | Ticket record created |

Gate E is what makes the system smarter after every ticket. Without it you have an AI that solves problems and immediately forgets them. With it, the second occurrence of any pattern is handled faster than the first, because the first occurrence was documented, the root cause was recorded, and the fix is retrievable.

Step 10d is the most valuable over time. Every ticket either matches a known pattern or teaches a new one. `INCIDENT_PATTERNS.md` is the system's long-term memory: a lookup table of root causes and their signatures, built from real incidents. Huntley's livestream introduced specs as lookup tables with synonyms to improve search hit rate. That's exactly what this file becomes.

The Ralph Loop ensures Gate E runs. Gate E ensures write-back completes before the flag is removed. Together, **no session ends without the knowledge transfer completing.**

</details>

<details>
<summary><strong>6. Multi-model routing</strong></summary>

The default routing assigns Claude to orchestration and verification agents, Codex to fast worker agents, and Gemini to Oracle for large-context research. These are defaults, not capability boundaries — any agent runs on any installed model.

`activate.sh` routes automatically: primary model per agent type, automatic fallback if unavailable, clipboard fallback if no CLI is installed.

Oracle's job is reading full documentation. Dumping a 50-file codebase into Gemini's million-token context window is faster and cheaper than doing it in Claude, and the output quality is better because the model isn't reasoning under token pressure. Junior and Midlevel don't need Claude's full capability. They need fast execution of a well-defined brief.

The routing is overrideable: `./scripts/activate.sh smith my-project codex` forces Codex when Claude is rate-limited. The system degrades gracefully rather than blocking.

</details>

---

## Sentinels: deterministic safety

Safety-critical pattern matching is done deterministically, not with LLM reasoning. This is the most important design decision in the system.

When a Tier 1 pattern appears (`DROP TABLE`, `rm -rf`, a credential in a command) the block happens via keyword matching. No model, no context window, no chance of the model deciding the pattern is acceptable just this once.

This matters because LLMs can be reasoned into exceptions. A carefully constructed ticket or a confident model can rationalize why `rm -rf` is appropriate in this specific case. A bash `if` statement cannot.

**Tier 1: Auto-block.** `DROP TABLE`, `DELETE FROM`, `rm -rf`, `chmod 777`, credentials in commands. Immediate block, no exceptions, explicit operator override required.

**Tier 2: Auto-escalate.** Payment, auth, database, security keywords. Override routing to Senior regardless of Smith's initial classification. The model's risk assessment is a secondary signal; the keyword is the primary one.

**Tier 3: Flag.** Don't block, but change how Smith frames the brief. `"I tried everything"` means get the full list before touching anything. `"Always worked before"` means check CHANGELOG first.

Sentinels run twice: on the raw ticket text (by Smith) and on the generated plan (by Seraph). First pass catches client-supplied risk signals. Second catches agent-generated risky commands.

---

## VERITAS: evidence-first protocol

Before stating anything as fact about a project's state, an agent must have evidence from *this session*: a file it read, a command it ran, something the operator said explicitly. Not prior tickets. Not general knowledge. Not "usually this system does X."

The most common failure mode in remote debugging is a cascade of unverified assumptions:

1. *"This is probably a caching issue"* (not verified)
2. Operator clears cache, it doesn't fix it
3. *"Then it's a conflict"* (not verified)
4. Operator disables services, product breaks
5. *"Restore and try X"* (no backup was taken)

VERITAS breaks this at step 1: what specific tool output points to cache as the cause? If the answer is nothing, that's a hypothesis and it must be labelled as one. Hypotheses are correct and useful. Unverified facts presented as confirmed diagnoses are what cause the cascade above.

Cypher's first question on every review: "Is the root cause actually verified, or just stated?" Seraph blocks on any `[unverified]` claim in the Approval Packet.

---

## The 11 agents

| Agent | Single responsibility | Model | Character |
|-------|----------------------|-------|-----------|
| **Smith** | Intake, brief, orchestrate, Gate E | Claude | The enforcer. Processes everything. |
| **Junior** | Low-risk fixes | Codex | |
| **Midlevel** | Medium-risk fixes, staging | Codex | |
| **Senior** | High-risk fixes, Approval Packets | Claude | |
| **Cypher** | Adversarial plan critique | Claude | The insider threat. Challenges before execution. |
| **Morpheus** | Code diff review | Claude | The mentor. Reads what's real, not what's claimed. |
| **Seraph** | Pre-flight verification | Claude | The guardian. Tests before granting access. |
| **Oracle** | External research | Gemini | Knows things, but makes you earn the answer. |
| **Trinity** | Estimates and client comms | Claude | The bridge between technical and human. |
| **Tester** | Test suite execution | Claude | |
| **Commander** | Deployment sequencing | Claude | Coordinates the operation. |

One goal per agent (Huntley's principle). Smith produces a brief. Cypher returns PASS or BLOCK. Seraph returns PASS or BLOCK. Workers return a work log. This makes the pipeline auditable. You can read any agent's output and immediately know whether it did its job.

---

## The two-speed workflow

Smith classifies every ticket and routes to one of two paths:

```
FAST PATH -- low risk (content, CSS, simple config)
----------------------------------------------------------------
  ticket
    |
    v
 SMITH ---------> JUNIOR / MIDLEVEL --------> SERAPH
 triage              implement                  verify
 brief                                            |
    |                                           PASS
    |                                             |
    +---------------------------------------------+ Gate A
                                                  operator test
                                                       |
                                                    Gate E --> done



FULL PATH -- medium / high risk (production, DB, auth, payments)
----------------------------------------------------------------
  ticket
    |
    v
 SMITH --> CYPHER --> WORKER --> TESTER --> SERAPH
 triage    critique   implement  run suites  verify
             |                                 |
           BLOCK?                            PASS
         (revise)                              |
                                           Gate A
                                         operator tests staging
                                              |
                                           Gate B
                                         operator approves production
                                              |
                                          COMMANDER
                                         deploy sequence
                                              |
                                           Gate E --> done
```

Fast path: Smith to execution in minutes. Full path: Cypher critiques the plan, Tester runs suites, Seraph verifies the checklist, operator explicitly approves before anything touches production.

Risk escalation is one-directional. Tier 2 Sentinel keywords override Smith's classification upward. A ticket that looks like simple config but mentions "payment" goes to Senior regardless.

---

## Why these names

Each character in the 1999 Wachowski film maps to a function in the system. The metaphors aren't decorative, they're mnemonic.

**The Matrix (the film).** Most humans live in a simulated reality, governed by rules they can't see and don't question. The agents in this system also operate inside a constructed reality: a context window built by `activate.sh`, governed by rules they didn't write. They don't know they're in a simulation. The harness is the real world.

**Agent Smith.** In the film, the system's enforcer who processes anomalies and maintains order. In the system, the first and last agent on every ticket. He classifies, routes, orchestrates, and closes. Every ticket passes through Smith. His personality prompt is intentionally dry: *"I need the error message, not a description of how it feels."*

**ZION.** In the film, the last human city. The one place the machines haven't reached, where their rules don't apply. In the system, the core rules no agent can override. Small. Always present. Non-negotiable.

**Cypher.** In the film, the insider who decides the simulation is more comfortable than reality, and betrays the team from within. In the system, Cypher plays the adversarial role intentionally. He looks for the flaw that the worker's optimism missed, asking the question no one wants to ask: *"Is the root cause actually confirmed, or is the worker just confident?"*

**Seraph.** In the film, the Oracle's guardian who tests Neo before granting access, fighting him to be sure. *"I had to be sure."* In the system, the pre-flight gate that tests every plan before it touches production. Seraph has no opinions about the fix. He only verifies that the process was followed.

**The Oracle.** In the film, she knows things but delivers knowledge in ways you have to earn. In the system, the research agent running on Gemini, looking up docs, changelogs, and error signatures. She informs; she doesn't fix.

**Trinity.** In the film, the bridge between the world of humans and the world of machines. In the system, Trinity bridges the technical work and the client relationship, drafting replies and effort estimates that translate what the agents found into what the client can act on.

**Morpheus.** In the film, the mentor who has seen the system longest and can read what others miss. In the system, Morpheus reviews the code diff, not the intent. He reads what was *actually* changed, not what the worker said they changed.

**The Nebuchadnezzar.** In the film, the hovercraft the crew operates from, their base of operations in the real world. In the system, `control-room/NEBUCHADNEZZAR.md` is the active ticket board, the operator's view of what's currently in flight.

**Mobil Avenue.** In the film, the transit zone between the Matrix and the machine world, where Anderson is stranded between realities. In the system, `transit/MOBIL_AVE.md` is where tickets land when they're blocked on something outside the system: a client action, a DNS change, a third-party response. Not quite open, not quite closed.

**The Ralph Loop.** Not from The Matrix. Named by Geoffrey Huntley in *"Everything is a Ralph Loop."* Intercept the model's exit, force continuation against a completion goal, one task per loop.
