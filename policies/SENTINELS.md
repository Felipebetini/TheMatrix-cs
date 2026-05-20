# Sentinels — Automatic Safety Triggers

> Sentinels don't negotiate. They detect and respond. Fast, cheap, deterministic.

---

## What Sentinels are

Sentinels are keyword and pattern rules that trigger automatically — no LLM reasoning needed. Smith scans the raw ticket and the proposed plan against these rules before routing. Seraph runs them again before execution.

If a Sentinel fires, it's a flag — not necessarily a block. The tier determines the response.

---

## Tier 1 — Auto-block (stop everything, require operator to explicitly override)

Any of these in a proposed command or plan: **BLOCK immediately.**

| Pattern | Reason |
|---------|--------|
| `DROP TABLE`, `DELETE FROM`, `TRUNCATE` | Irreversible data destruction |
| `rm -rf` | File system destruction |
| `chmod 777` | Security misconfiguration |
| Any credential value in a command | Secrets must never appear in plans |
| Commands that create admin-level users | Privilege escalation |
| Database reset commands | Destroys entire dataset |
| `--force` on irreversible operations | Bypasses safety prompts |

---

## Tier 2 — Auto-escalate to Senior + require Seraph check

Any of these topics in the ticket or plan: escalate regardless of Smith's initial routing.

| Trigger | Why |
|---------|-----|
| `payment`, `checkout`, `order`, `invoice`, `billing` | Revenue-critical flow |
| `login`, `register`, `password`, `session`, `auth` | Authentication — security-sensitive |
| `database`, `SQL`, `search-replace`, `import`, `migrate` | Data integrity risk |
| `webhook`, `API key`, `integration`, `CRM` | External system coupling |
| `hacked`, `malware`, `suspicious`, `unauthorized`, `compromised` | Security incident |
| `delete all`, `remove all`, `clean up`, `wipe` | Data loss risk |
| `production`, `live`, `prod` + any write verb | Production write |
| Any multi-tenant or cross-account operation | Blast radius risk |

---

## Tier 3 — Flag to operator (add to Smith brief, don't block)

Informational flags — worth noting, not stopping.

| Pattern | Flag message |
|---------|-------------|
| `urgent`, `ASAP`, `emergency` | Client is stressed — manage expectations in reply draft |
| `always worked before` | Likely a regression — check CHANGELOG |
| `I tried everything` | Client has already made changes — get the full list before any action |
| Unknown dependency or plugin name | Oracle lookup required before touching |
| `the developer said…` | Third-party involvement — clarify scope before starting |
| `client needs this today` | Deadline pressure — Trinity required before committing |
| Multiple unrelated issues in one ticket | Scope creep risk — ask operator to split or prioritise |

---

## How Sentinels fit in the workflow

```
Ticket arrives → Smith reads it → Sentinel scan (Tier 3 flags noted in brief)
                                → Tier 2 triggers → override routing to Senior
                                → Tier 1 triggers → BLOCK, notify operator

Plan produced → Seraph runs Sentinel scan on commands → Tier 1 = BLOCK
```

Sentinels run twice: on the ticket (by Smith) and on the plan (by Seraph). This catches both client-supplied risk signals and agent-generated risky commands.

---

## Updating Sentinels

When a new risky pattern is discovered from an incident, add it here. See the playbooks for platform-specific patterns.
