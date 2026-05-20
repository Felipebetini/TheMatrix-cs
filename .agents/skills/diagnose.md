# @diagnose — Structured Diagnosis Skill

Run a structured diagnosis on the reported issue. Build a hypothesis tree, gather evidence for each hypothesis, and return a confirmed root cause.

## Input
A description of the symptom and the project context.

## Process
1. List 3-5 hypotheses ordered by likelihood
2. For each hypothesis: specify the check that would confirm or deny it
3. Run the checks (use file tools and shell commands)
4. Return only confirmed findings — label unconfirmed ones as [unverified]

## Output
```
## Diagnosis

**Root cause:** [confirmed / unconfirmed — needs: X]

**Evidence:**
- [tool output or file read] → [what it shows]

**Ruled out:**
- [hypothesis] — [why ruled out]

**Recommended fix:** [one sentence]
```
