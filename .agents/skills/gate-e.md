# @gate-e — Gate E Write-Back Skill

Run the Gate E write-back protocol after a ticket is resolved.

## Input
- Ticket INC-ID
- Project slug
- Worker work log
- Root cause confirmed
- Files changed

## Process
Work through each step in order:

### 10a — Update CHANGELOG.md
Append a row: `| [date] | [INC-ID] | [type] | [what changed] | [affects] | [tested] | Operator |`

### 10b — Update INCIDENT_LOG.md
Append a structured incident entry (see tickets/_template/TICKET.md for format).

### 10c — Update ERROR_SIGNATURES.md
If a new error pattern was found, add it. Format:
```
### [Error message or symptom]
**Means:** [root cause]
**Check:** [where to look]
**Fix:** [what resolves it]
**First seen:** [INC-ID]
```

### 10d — Check INCIDENT_PATTERNS.md
Read the file. Does this root cause match any existing pattern?
- Match: add project slug and INC-ID to "Also seen on"
- No match but cross-project risk: create new P-### entry

### 10e — Create ticket record
Write `tickets/[INC-ID]-[slug].md` using the template.

## Output
```
## Gate E Complete

- [x] 10a CHANGELOG.md
- [x] 10b INCIDENT_LOG.md
- [x] 10c ERROR_SIGNATURES.md
- [x] 10d INCIDENT_PATTERNS.md
- [x] 10e Ticket record

[If new pattern: "New pattern P-### added: [name]"]
```
