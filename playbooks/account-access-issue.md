# Account Access Issue — Playbook

## When to use this

Client cannot log in, has lost access, reports "wrong password" or "account locked" or "invitation not received".

## Risk classification

- Password reset for a single user: **low**
- Role change or permission change: **medium**
- Account deletion or data removal: **high**
- Suspected unauthorised access: **high** (Tier 2 Sentinel)

## Diagnosis steps

### 1. Establish the scope
- Is it one user or multiple?
- When did it last work? (check CHANGELOG for recent auth-related changes)
- What error message does the user see exactly? (ask for a screenshot if possible)

### 2. Check for system-level causes first
Before touching any account:
- Check if the auth service/provider is functioning
- Check for recent config changes that could affect auth (check CHANGELOG)
- Check for rate limiting or IP blocks if multiple failed attempts

### 3. Confirm account status
- Does the account exist?
- Is it active?
- What role/permissions does it have?
- Was it created via invitation? Did the invitation expire?

### 4. Check for known patterns
- Search INCIDENT_PATTERNS.md for auth-related patterns
- Check ERROR_SIGNATURES.md for the specific error message

## Common root causes

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| "Invalid credentials" | Expired password or account locked after failed attempts | Reset password, check lockout policy |
| Invitation not received | Email delivery issue or invitation expired | Resend invitation, check email logs |
| "Account not found" | User registered with different email | Look up by name, confirm correct email |
| Login works, but access denied | Incorrect role or permissions | Review and correct role assignment |
| Recent auth change broke it | Config change affected existing sessions | Revert or fix the config, session invalidation |

## Fix approach

**Password reset (low risk):**
- Produce a Human Action Card for the operator to reset via admin UI
- Test instructions: confirm user can log in and access expected features

**Role/permission change (medium risk):**
- Document current role before changing
- Change on staging first if available
- Gate A required before production

**Suspected unauthorised access (high risk):**
- Escalate to Senior immediately
- Do not change anything until root cause is confirmed
- Audit access logs for the period in question

## Test instructions template

```
1. Navigate to [login URL]
2. Enter [user@email.com] and the new password
3. Expected: successful login, redirect to [dashboard/home]
4. Verify: user can access [expected feature or section]
5. Verify: user cannot access [sections outside their role]
```

## Escalation triggers

- Any sign of unauthorised access: stop, escalate to Senior, do not change passwords yet (preserve evidence)
- Multiple users affected simultaneously: likely a system issue, not an account issue — escalate
- Access issue involves billing or payment account: Tier 2 Sentinel, Senior required
