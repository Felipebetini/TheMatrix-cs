# Integration Broken — Playbook

## When to use this

A third-party integration has stopped working: webhook not firing, API not responding, data not syncing, notifications not sending.

## Risk classification

- Read-only integration issue (data not displaying): **medium**
- Write integration issue (data not being sent): **medium-high**
- Payment or billing integration: **high** (Tier 2 Sentinel — Senior required)
- CRM or customer data sync: **high** (Tier 2 Sentinel)

## Diagnosis steps

### 1. Determine direction of failure

Integrations fail in two directions:
- **Outbound** — our system not sending data to the third party
- **Inbound** — third-party not sending data to us (webhooks)

Ask: which direction is the problem?

### 2. Check the obvious first

- Is the third-party service up? Check their status page.
- Have API keys expired or been rotated? (Never read keys — ask the operator to verify in the admin panel)
- Has anything changed recently? (Check CHANGELOG)
- Is the integration enabled in the current environment? (Some are staging-only or production-only)

### 3. Find the error

Integrations usually fail silently or log to non-obvious locations. Ask:
- Are there error logs in the admin panel for this integration?
- Are there webhook delivery logs in the third-party dashboard?
- Is there a test mode or test endpoint that can be triggered?

### 4. Reproduce with a minimal test

Can the failure be triggered on demand? (e.g., submit a test form, trigger a test webhook, run a test transaction in sandbox mode)

If yes: reproduce and capture the exact error.
If no: work from existing logs.

## Common root causes

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| No data arriving | Webhook URL changed or misconfigured | Verify webhook URL in third-party dashboard |
| "Unauthorized" error | API key expired or wrong environment key | Operator rotates/verifies key in admin panel |
| Partial data syncing | Schema mismatch — field names changed | Map fields, update integration config |
| Works in staging, not production | Environment-specific API key or endpoint | Check production config separately |
| Was working, suddenly stopped | Third-party API change or deprecation | Check third-party changelog |

## Fix approach

**API key issue (Gate C — Human Action Card):**
```
## Human Action Card
Action: Verify/update API key for [integration name]
Location: Admin Settings → Integrations → [integration name]
Steps:
1. Check current key status (does it show as active?)
2. If expired: generate a new key in [third-party service dashboard]
3. Paste new key into the integration settings
4. Save
Verify by: trigger a test event and check for success in the logs
```

**Webhook URL issue:**
- Confirm the correct webhook endpoint URL
- Update in the third-party dashboard (Gate C if requires UI action)
- Trigger a test webhook delivery and verify receipt

**Config/mapping issue:**
- Document the current config before changing
- Test the change on staging if available
- Gate A before production

## Test instructions template

```
1. [Trigger the integration: submit a form / place a test order / trigger a test event]
2. Wait [X seconds] for the event to process
3. Check [destination system] for the new record
4. Expected: [specific data fields] appear in [location]
5. Check integration logs for "success" status
```

## Escalation triggers

- Integration involves payment data: Tier 2 Sentinel, Senior required immediately
- Integration involves customer PII: Senior required
- API key needs to be shared with agents: never — Gate C, operator handles keys
- Third-party reports a security issue with the integration: security incident protocol

## Oracle research triggers

Activate Oracle if:
- The third-party service has recently published a changelog or deprecation notice
- The error message is unfamiliar and not in ERROR_SIGNATURES.md
- The integration uses an undocumented or unusual API
