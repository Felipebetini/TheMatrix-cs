# Mobil Avenue — Blocked Tickets Queue

Tickets land here when they are blocked waiting on something outside the system's control: a client action, a third-party response, a manual approval that hasn't arrived.

Named after the transit zone between worlds — not quite here, not quite there.

---

## Blocked tickets

| INC-ID | Project | Blocked since | Blocked by | Owner |
|--------|---------|--------------|------------|-------|
| — | — | — | — | — |

---

## Blocked ticket detail template

```markdown
## [INC-ID] — [Project] — [Short title]

**Blocked since:** YYYY-MM-DD
**Blocked by:** [What is needed — e.g. "Client needs to provide API key"]
**Next action:** [Who does what — e.g. "Operator follows up with client by YYYY-MM-DD"]
**Status:** Waiting

### Context
[Brief summary of where work stopped and what has been done so far]

### When unblocked
[What to do when the blocker is resolved — e.g. "Resume at Gate C — key is ready to configure"]
```

---

## How a ticket lands here

Smith moves a ticket to Mobil Avenue when:
- A Gate C action requires client involvement (e.g. client must configure something)
- A third-party support ticket is open and blocking the fix
- Waiting on information only the client can provide
- Waiting on an external access grant (hosting, DNS, domain registrar)

## How a ticket leaves here

When the blocker is resolved:
1. Operator confirms in the Matrix session
2. Smith removes the entry from this file
3. Ticket resumes from where it stopped (the context section says where)
