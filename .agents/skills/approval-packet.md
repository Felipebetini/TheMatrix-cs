# @approval-packet — Approval Packet Generator Skill

Generate a full Approval Packet for a high-risk operation.

## Input
- Confirmed root cause (with evidence citations)
- Proposed fix (exact commands or changes)
- Rollback plan
- Backup plan

## Process
Assemble the packet, verify every claim has a VERITAS citation.

## Output
```
## Approval Packet

**Ticket:** [INC-ID]
**Risk level:** High

### Root cause
[Evidence-backed paragraph. Every claim cited.]

### Proposed fix
[Exact commands or file changes]

### Why this fixes it
[Technical reasoning]

### What could go wrong
[Honest failure modes]

### Rollback plan
[Exact rollback steps]
**Rollback time:** [minutes]

### Backup
[ ] Command: [exact command]
[ ] Verified: [size/location]

### Test instructions
1. [Step]
2. [Step]
Expected: [outcome]

### Sentinel check
[ ] Tier 1 patterns: none
[ ] Credentials: none visible

---
Reply `approved` to proceed.
```
