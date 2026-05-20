# @risk-classify — Risk Classification Skill

Classify the risk level of a ticket based on policies/RISK_POLICY.md.

## Input
Ticket summary and any known facts about what it involves.

## Process
1. Check for automatic high-risk flags (keywords)
2. Apply the three-tier classification criteria
3. Note any Sentinel flags for the brief

## Output
```
## Risk Classification

**Level:** low / medium / high
**Reason:** [one sentence]

**Automatic flags triggered:**
- [list or "none"]

**Sentinel flags:**
- Tier 1: [list or "none"]
- Tier 2: [list or "none"]
- Tier 3: [list or "none"]

**Recommended worker:** junior / midlevel / senior
**Cypher required:** yes / no
```
