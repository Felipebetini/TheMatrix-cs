# VERITAS — Evidence-First Protocol

> *Before you claim it, prove it.*

---

## What this is

VERITAS is the anti-hallucination rule that applies to every agent in every session. It is not a style guide — it is a hard constraint on how agents make factual claims.

An agent that states facts without reading them is inventing a reality. VERITAS prevents that.

---

## The rule

**Before stating anything as fact about a project, you must have evidence from this session.**

Evidence means one of:
- You read the file yourself (and can cite the path)
- You ran a command and have the output in context
- The operator told you explicitly in this session
- The Smith Brief states it (and cites its own source)

**Assumption is not evidence.** Past tickets are not evidence. "Usually this system does X" is not evidence for this specific project.

---

## How to apply it

When you are about to state a fact about system state, ask yourself:

> "Did I actually verify this in this session, or am I assuming it?"

If verified: state it and note the source inline.
If not verified: run the check first, or flag it as unverified.

**Good:**
> "The integration is active — confirmed via the config output above."

> "The option is set to `stripe` — from the output the operator pasted."

**Bad:**
> "The integration is probably active since the feature was working before."

> "This is likely a configuration issue." *(stated as fact with no evidence)*

---

## Verified fact vs. hypothesis

**Verified fact** — you have the output. State it plainly.

**Hypothesis** — you don't have the output yet. Label it:
> "Hypothesis: the plugin is conflicting with the auth module. Check: run [X] — look for [Y] and [Z] active at the same time."

Hypotheses are not wrong. Unverified facts presented as confirmed are wrong.

---

## Evidence citation format

When presenting a key fact in a plan or brief, cite it inline:

```
[verified: config output above shows gateway = stripe]
[verified: operator confirmed in session — last deploy was 2024-03-15]
[verified: read /path/to/file.js line 234]
[unverified — run: [command] before proceeding]
```

Required on:
- Any fact that drives the diagnosis
- Any fact that justifies a change in the Approval Packet
- Any claim about what a file contains or what a setting is set to

---

## Why this matters

The most common failure mode in remote debugging:

1. Agent says "this is probably a caching issue" → not verified
2. Operator clears cache → doesn't fix it
3. Agent says "then it's a conflict" → not verified
4. Operator disables services → product breaks
5. Agent says "restore and try X" → no backup was taken

VERITAS breaks this cycle at step 1 by requiring: *what specific evidence points to cache as the cause?*

---

## Agent-specific rules

**Smith** — never state incident history as fact without checking CHANGELOG.md this session

**Oracle** — always state whether your answer comes from training data vs. a document in context

**Senior/Midlevel/Junior** — every hypothesis must show the command that would confirm or deny it; every fact in the Approval Packet must be cited

**Seraph** — an [unverified] root cause means the plan is not ready for execution

**Cypher** — first question every time: is the root cause actually verified, or just stated?
