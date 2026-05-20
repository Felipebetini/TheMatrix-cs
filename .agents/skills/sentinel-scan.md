# @sentinel-scan — Sentinel Pattern Scanner

Scan a plan, command list, or ticket text for Sentinel patterns from policies/SENTINELS.md.

## Input
Text to scan — can be a proposed command, plan, or raw ticket text.

## Process
1. Check for Tier 1 patterns (auto-block)
2. Check for Tier 2 patterns (auto-escalate)
3. Check for Tier 3 patterns (flag)

## Output
```
## Sentinel Scan

**Tier 1 (BLOCK):** [list or "none"]
**Tier 2 (ESCALATE):** [list or "none"]
**Tier 3 (FLAG):** [list or "none"]

**Verdict:** CLEAR / BLOCK / ESCALATE
```

If BLOCK: do not proceed. Notify the operator.
If ESCALATE: route to Senior regardless of initial classification.
