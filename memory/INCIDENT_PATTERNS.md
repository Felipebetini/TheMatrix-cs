# Incident Patterns — Cross-Project Pattern Library

Patterns are root causes that have appeared on more than one project. Smith checks this file at the start of every ticket. When a new pattern is confirmed, it gets added here.

The value: the second occurrence of a pattern is handled faster than the first.

---

## How to read this file

Each pattern has:
- **Root cause** — the technical reason (not the symptom)
- **Symptom** — what the client reported
- **First seen** — incident ID and project slug
- **Also seen on** — grows with each recurrence
- **Check** — fastest way to confirm this pattern on a new project
- **Fix** — what resolves it

---

## How to add a pattern

At Gate E (Step 10d), Smith checks whether the closed ticket's root cause matches an existing pattern. If not, and the root cause could affect other projects, Smith adds a new entry:

```markdown
## P-[next number] — [Short pattern name]

**Root cause:** [one sentence — the technical reason, not the symptom]
**Symptom:** [what the client reported]
**First seen:** [INC-ID] / [slug]
**Also seen on:** (none yet)
**Check:** [the fastest way to confirm this pattern on a new project]
**Fix:** [what resolves it]
```

---

## Patterns

*(No patterns yet — this file grows as tickets are resolved.)*

---

*Last updated: —*
