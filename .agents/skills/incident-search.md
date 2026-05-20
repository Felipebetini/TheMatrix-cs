# @incident-search — Incident History Search Skill

Search the project's incident history for matches to the current symptom.

## Input
- Project slug
- 2-3 symptom keywords

## Process
1. Search INCIDENT_PATTERNS.md for keyword matches (cross-project patterns)
2. Read projects/[slug]/CHANGELOG.md — recent changes that could be related
3. Search tickets/ directory for matching incident records
4. Check project INCIDENT_LOG if available

## Output
```
## Incident Search

**Query:** [keywords]

**Cross-project patterns:**
- [P-### — name — relevance] or "none"

**Recent project changes (CHANGELOG):**
- [date: what changed — relevant?] or "no recent changes"

**Prior incidents for this project:**
- [INC-ID — title — resolution] or "none found"

**Recommendation:**
[Is this likely a regression? A known pattern? New territory?]
```
