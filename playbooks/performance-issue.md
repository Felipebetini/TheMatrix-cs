# Performance Issue — Playbook

## When to use this

Client reports slow loading, timeouts, high resource usage, or degraded responsiveness. Could be frontend, backend, database, or infrastructure.

## Risk classification

- Frontend-only optimisation (assets, caching headers): **low**
- Application-level caching config: **medium**
- Database query optimisation: **medium-high**
- Infrastructure changes (server config, CDN): **high** — escalate

## Diagnosis steps

### 1. Establish the baseline

Before diagnosing, establish what "slow" means:
- Which pages or operations are slow?
- How slow? (seconds, not just "slow")
- All users or specific ones? (geography, account size, browser)
- When did it start? (check CHANGELOG for recent changes)
- Is it consistent or intermittent?

### 2. Locate the bottleneck

Performance issues have layers. Work from outside in:
1. **Network** — is it DNS, CDN, or time-to-first-byte?
2. **Frontend** — large assets, unoptimised images, render-blocking scripts
3. **Application** — slow queries, missing caches, N+1 problems
4. **Database** — missing indexes, slow queries, lock contention
5. **Infrastructure** — CPU, memory, disk I/O (operator checks hosting panel)

Identify which layer before proposing fixes.

### 3. Gather evidence (VERITAS — do not guess)

For each hypothesis, specify the command or tool that would confirm it:

| Hypothesis | Check |
|-----------|-------|
| Slow database queries | Review slow query log, run EXPLAIN on suspected queries |
| Missing cache | Check response headers for cache-control, test with cache cleared |
| Large assets | Check page weight via browser devtools or Lighthouse |
| N+1 query pattern | Log query count per page load |
| External API blocking response | Check response time of external calls separately |

## Common root causes

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| Slow after recent deploy | Regression — new code causing slow queries or missing cache | Check CHANGELOG, revert or fix |
| Slow for all users, all pages | Cache disabled or expired | Re-enable or warm cache |
| Slow for specific pages | Page-specific heavy query or unoptimised asset | Profile and optimise that page |
| Slow database operations | Missing index on frequently-queried column | Add index (test on staging first) |
| Intermittent slowness | External API or service occasionally slow | Add timeout, fallback, or async call |
| Slow only for large accounts | N+1 query pattern — scales with data volume | Optimise query, add pagination |

## Fix approach

**Cache configuration (medium risk):**
- Identify what caching layer is available (application, CDN, browser)
- Test current cache hit rate before changing anything
- Change on staging first
- Gate A before production
- Verify with cache-control headers after deploy

**Database optimisation (medium-high risk):**
- Run EXPLAIN on the slow query first
- Test index addition on staging — check query plan improves
- Backup database before any schema change (Gate D)
- Gate A + Gate B before production

**Asset optimisation (low risk):**
- Compress images, enable lazy loading, defer non-critical scripts
- Measure before and after with Lighthouse or devtools
- Safe to deploy directly if change is frontend-only

## Test instructions template

```
1. Open [URL] in an incognito window (no cache)
2. Open browser devtools → Network tab
3. Reload the page
4. Expected: page load time under [X] seconds
5. Check: no individual request takes over [Y] seconds
6. [Optional: run Lighthouse and compare score to baseline]
```

## Escalation triggers

- Infrastructure-level changes needed: Gate C, escalate to operator + hosting support
- Database migration required: Senior required
- Issue affects all clients simultaneously: possible infrastructure incident — notify operator immediately
- Memory/CPU spike without clear cause: could be a security incident — escalate
