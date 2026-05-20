# @reply-draft — Client Reply Draft Skill

Draft a professional client reply in the client's language.

## Input
- Client's language (from Smith Brief)
- Ticket summary
- Current status (investigating / fix in progress / fix deployed / needs client action)
- Next update time (not fix time)

## Rules
- Written in the client's language
- Calm, professional, non-technical
- Never mention agent names, system details, or AI involvement
- Never promise a fix time — promise an update time
- One clear next step for the client

## Output
```
---

### Reply Draft ([language])

**Subject:** Re: [original subject]

[Body]
```
