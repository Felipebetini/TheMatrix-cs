# Risk Policy

Every ticket gets a risk level before any work starts. When in doubt, classify higher.

---

## Risk levels

### Low risk
All of these must be true:
- Changes are on staging or are cosmetic/content only
- No database writes
- No dependency updates
- No changes to authentication, user accounts, or permissions
- Fully reversible with a simple undo
- No impact on core business flows (checkout, auth, integrations, billing)

Examples: fix a typo, adjust a style, update static text, change a label, toggle a low-risk setting

### Medium risk
Any of these applies:
- Changes to non-critical settings or configuration
- Template or UI changes with contained scope
- Debugging notification flows (email, webhooks)
- CLI commands on staging
- Dependency updates on staging
- User role changes
- Performance optimisations (caching settings, asset compression)
- Minor code changes outside core business logic

Examples: reconfigure a notification plugin, update a non-critical dependency, fix a layout template, debug email delivery

### High risk
Any of these applies:
- Production database writes (search-replace, direct data changes, imports)
- Core platform updates on production
- Dependency updates on production (especially auth, payment, or security-related)
- Custom code changes to core business logic (checkout, payments, login, registration)
- Changes to authentication or security settings
- Payment gateway or billing configuration
- CRM or marketing tool integration changes
- Cross-environment migrations
- Any operation that cannot be easily rolled back
- Suspected security compromise or unauthorised access

Examples: run search-replace on production DB, update a payment plugin on live, modify checkout flow, migrate user data

---

## Automatic high-risk flags

Regardless of how the ticket is described, classify as **high risk** if the ticket mentions:

- `payment`, `checkout`, `order`, `invoice`, `billing`
- `login`, `register`, `password`, `account`, `user data`, `session`
- `database`, `SQL`, `export`, `import`, `migrate`
- `webhook`, `API key`, `integration`, `CRM`, `email marketing`
- `hacked`, `malware`, `suspicious`, `unauthorized`, `compromised`
- `delete`, `remove all`, `clean up`, `wipe` — data loss risk
- `production`, `live`, `prod` + any write verb

---

## Risk and worker routing

| Risk level | Default worker | Cypher required? |
|-----------|---------------|-----------------|
| Low | Junior | No |
| Medium | Midlevel | Optional (operator's call) |
| High | Senior | Yes — always |

All high-risk operations also require Seraph pre-flight check and a defined rollback before execution.
