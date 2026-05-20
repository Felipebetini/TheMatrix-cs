# Human Gates

These are the hard stops in every workflow. Agents cannot proceed past a gate without the operator's explicit action or approval. No exceptions.

---

## Gate types

### Gate A — Testing gate
**What it is:** The operator must test the fix on staging before it can go to production.
**When it triggers:** Every ticket where a change was made, no matter how small.
**What agents produce:** Numbered test instructions with expected outcomes.
**What the operator does:** Runs the tests, reports pass/fail.
**What happens next:** Only after "all steps pass" does the worker produce a production-ready plan.

### Gate B — Approval gate
**What it is:** The operator must explicitly approve the Approval Packet before a high-risk operation runs.
**When it triggers:** Any production write, database operation, or security remediation.
**What agents produce:** Full Approval Packet (see `agents/SENIOR.md`).
**What the operator does:** Reads the packet, confirms "approved" or requests changes.
**What happens next:** Only after explicit approval does the worker provide final execution steps.

### Gate C — Human-only action gate
**What it is:** Some things require the operator to do them manually — agents cannot do them via CLI or code.
**When it triggers:** See table below.
**What agents produce:** A "Human Action Card" — exactly what to do, where to click, what to verify.
**What the operator does:** Executes the manual steps, confirms completion.

### Gate D — Backup gate
**What it is:** A backup must be confirmed before any destructive operation.
**When it triggers:** Any database write or production deployment of code changes.
**What agents produce:** The exact backup command, pre-written and ready to run.
**What the operator does:** Runs the backup, confirms it completed successfully.
**What happens next:** Only after backup confirmed does the operation proceed.

### Gate E — Close gate
**What it is:** The write-back protocol must complete before a ticket can be marked resolved.
**When it triggers:** After the operator confirms the fix is working in production.
**What agents produce:** Updated CHANGELOG.md, INCIDENT_LOG.md, ERROR_SIGNATURES.md (if new pattern), INCIDENT_PATTERNS.md check, and ticket record.
**What the operator does:** Confirms "all done" after Smith reports Gate E clear.
**What happens next:** Ticket is closed. System is smarter than before this ticket started.

---

## Human-only actions (Gate C triggers)

These require manual action — agents cannot do them via CLI:

| Action | Category |
|--------|----------|
| UI-based feature activation/deactivation | Platform admin |
| Entering license keys or secrets | Credentials |
| Configuring payment provider credentials | Payments |
| Email provider authentication | Integrations |
| SSL certificate verification | Infrastructure |
| DNS changes | Infrastructure |
| CDN or proxy configuration | Infrastructure |
| Hosting-level runtime version changes | Infrastructure |
| Restoring from a backup | Disaster recovery |
| Two-factor authentication setup | Security |
| API key generation or rotation | Security |
| Test payment execution | QA |

For each of these, agents produce a Human Action Card:

```
## Human Action Card

**Action required:** [what the operator needs to do]
**Location:** [exact path in admin panel or external service]
**Steps:**
1. [Step]
2. [Step]
**Verify by:** [how to confirm it worked]
**Then:** [what to do next / report back]
```

---

## What agents must never do autonomously

- Push changes to production
- Delete files or database records
- Expose or rotate credentials
- Disable security features
- Send messages to clients (drafts only — operator sends)
- Mark a ticket as resolved — that is the operator's call
