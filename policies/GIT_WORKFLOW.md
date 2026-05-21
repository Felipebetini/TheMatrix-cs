# Git Workflow Policy

Non-negotiable git rules for all agents on all projects.

---

## Pre-ticket git setup (run before every ticket)

Before loading project context or asking for the ticket, Smith checks the project repo state. Steps in order:

### 1. Check for a git repo

```bash
git -C [project-path] rev-parse --git-dir 2>/dev/null
```

- **Repo exists** → continue to step 2.
- **No repo** → ask the operator:
  > "No git repo found for `<slug>`. Give me the clone URL and I'll set it up."
  Then: `git clone <url> [project-path]` and continue.

### 2. Check for uncommitted changes

```bash
git -C [project-path] status --short
```

- **Clean** → continue to step 3.
- **Dirty** → stop and resolve first. Show the diff, ask the operator what to do (commit, stash, or discard). Do not proceed to the ticket until the working tree is clean.

### 3. Pull from master and create the ticket branch

```bash
git -C [project-path] checkout master   # or main
git -C [project-path] pull origin master
```

Then ask for the ticket title:
> "What's the ticket title? (e.g. `7880 Client Name | Feature`)"

Build the branch name:
- Take the ticket number and title given.
- Strip special characters (`|`, `.`, `/`, etc.) and replace spaces with `-`.
- Format: `<type>/cs-<ticket-number>-<title-slug>`
- Example input: `"7880 Client Name | RSS"` → branch: `bug/cs-7880-Client-Name-RSS`

```bash
git -C [project-path] checkout -b <branch>
```

Confirm to the operator:
> "Branch `<branch>` created from master. Ready for the ticket."

---

## Protected branches

**`main`, `master`, and `develop` are never pushed to directly.**

Agents may not run any of these:
- `git push origin main`
- `git push origin master`
- `git push origin develop`
- `git push --force` on any branch
- `git merge` into a protected branch

The operator is the merge gate. All code reaches main/master through a PR/MR that the operator approves.

---

## Branch naming

**Never commit directly to `main`, `master`, or `develop`.** Always create a branch first.

### Format

```
<type>/cs-<ticket-number>-<title-with-hyphens>
```

| Part | Description |
|---|---|
| `<type>` | `bug`, `feature`, `hotfix`, `chore` |
| `cs-` | Fixed prefix — marks this as a CS team branch |
| `<ticket-number>` | The ticket ID from the support system |
| `<title-with-hyphens>` | Short description, spaces replaced with hyphens |

### Examples

```
bug/cs-7519-Client-checkout-broken
feature/cs-7612-Add-referral-discount-code
hotfix/cs-7634-Payment-webhook-empty-credentials
```

### Rules

- Spaces → hyphens
- Keep title short but recognisable — enough to identify the ticket at a glance
- Never use slashes, dots, or special characters inside the title part

---

## Commit

- Commit message: imperative, present tense, English
- Stage specific files — never `git add -A` or `git add .` on a production repo

## Push

- Push the branch to `origin/<branch-name>` — never `origin/main` or `origin/develop`
- Open a PR / merge request if the project uses one
- The operator is the merge gate — agents do not merge

---

## Related policies

- `policies/HUMAN_GATES.md` — push to production is always a human gate
- `memory/ZION.md` — non-negotiables that apply everywhere
