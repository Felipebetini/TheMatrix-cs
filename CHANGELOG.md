# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased]

## [0.9.3] - 2026-05-22

### Security
- `scripts/gate-e-verify.sh`: replaced inline Python `-c "...open('$META')..."` with a heredoc passing META as an argument — eliminates shell variable interpolation inside Python string (code injection vector).
- `scripts/commit-guard.sh`: canonicalise WORK_DIR with `cd && pwd` after extraction; reject any path outside `$HOME` — prevents path traversal via crafted `-C` flags. Changed `\s` to `[[:space:]]` for POSIX portability.
- `scripts/matrix-dashboard.py`: restrict `Access-Control-Allow-Origin` from `*` to `http://localhost:2025` — server already binds to localhost only, but wildcard CORS was unnecessarily loose.
- `scripts/track-tool.py`: set mode `0o600` on temp state and events files (`/tmp/matrix-*.json`, `/tmp/matrix-*.jsonl`, lock files) immediately after creation — prevents other local users from reading session telemetry.

## [0.9.2] - 2026-05-22

### Changed
- `README.md`: added a practical GitHub CLI (`gh`) workflow for version bumping, tagging, pushing, creating releases, and verifying release status.

## [0.9.1] - 2026-05-22

### Fixed
- `scripts/setup-phpcs.sh`: detect actual Composer home dynamically via `composer global config home` — macOS Composer ≥2 uses `~/.config/composer`, not `~/.composer`. Allow `dealerdirect/phpcodesniffer-composer-installer` plugin required by Composer ≥2.2. Without this, the already-installed check always missed the binaries and re-ran the full install on every launch.

### Changed
- `scripts/dashboard.sh`: `ensure` now opens `http://localhost:2025` when it has to start the dashboard process, while leaving already-running instances untouched.

## [0.9.0] - 2026-05-22

### Added
- `scripts/commit-guard.sh`: PreToolUse Bash hook — intercepts `git commit`, runs `pr-check.sh` on staged PHP/JS/CSS files. When blocked, writes `/tmp/matrix-pr-issues.md` with structured issues (file + line) for the agent fix loop. Doom loop detection after 3 failed attempts → escalate to Smith.
- `scripts/git-guard.sh`: PreToolUse Bash hook — blocks `git push` to `main`/`master`/`develop` and any `git push --force` at the harness level. Hard enforcement, not prompt-based.
- `scripts/gate-e-verify.sh`: verifies Gate E completion before the ticket flag can be removed — checks ticket file created, project CHANGELOG updated, session saved to DB. Called by `gate-check.sh` on every blocked exit.
- `scripts/setup-phpcs.sh`: installs PHP_CodeSniffer, WordPress Coding Standards, phpmd, and phpcpd via Composer global. `--auto` flag exits silently if already installed. `matrix.sh` calls this on every launch for zero-manual-setup.

### Changed
- `scripts/pr-check.sh`: added PHPCS (WordPress Coding Standards) per-file check, phpmd (cyclomatic complexity + unused code) per-file check, and phpcpd (copy/paste detection) batch run across all staged PHP files.
- `scripts/matrix.sh`: calls `setup-phpcs.sh --auto` on every launch — PHP quality tools auto-install on first run.
- `.github/workflows/quality-gate.yml`: `php-quality` job now installs phpmd + phpcpd and runs them on changed PHP files in CI.
- `agents/SMITH.md`: compressed brief now requires `FIXED_WHEN` and `VERIFY_CMD` fields. Step 3a adds independent FIXED_WHEN verification (agent must run VERIFY_CMD and paste real output). Step 3b documents the commit guard fix loop and doom loop escalation path.
- `AGENTS.md`: commit guard fix loop documented — agents know to read `/tmp/matrix-pr-issues.md`, fix by line number, and respect the 3-attempt doom loop limit.

## [0.6.2] - 2026-05-22

### Added
- `.github/workflows/quality-gate.yml`: phase-1 CI quality gate for PRs/pushes (health quick check, pre-PR quality check, gitleaks secret scan).
- `scripts/install-git-hooks.sh`: installs a local pre-commit hook that runs `pr-check.sh` and `health-check.sh --quick`.

### Changed
- `memory/ZION.md`, `policies/RISK_POLICY.md`, and `agents/SMITH.md`: rollback and backup authority clarified — rollback is operator-only, backups are risk-based and not automatic, and high-load sites require explicit operator decision before backup actions.

## [0.6.1] - 2026-05-21

## [0.6.0] - 2026-05-21

### Added
- `scripts/pr-check.sh`: pre-PR code quality check — PHP/JS/CSS debug code, hardcoded credentials, missing escaping, merge markers. Exit 0 = pass, Exit 1 = block.
- `scripts/health-check.sh`: vault health check — shell/Python syntax, dead wikilinks, orphaned files, agent completeness, skill symlinks, runtime parity.

### Changed
- `README.md`: dashboard section now documents LIVE/HISTORY tabs, SQLite session DB, `matrix_db.py` commands, logo glitch animation. Repository structure updated to reflect current file layout.
- `SETUP.md`: added Step 7b (DB initialisation with `matrix_db.py ingest-rsi`), updated Step 7 to mention auto-start and LIVE/HISTORY tabs.

### Fixed
- `agents/SMITH.md` Gate E: added `matrix_db.py save SESSION_ID` step before clearing the flag (was missing from private repo too — fixed in both).

## [0.5.0] - 2026-05-21

### Added
- Dashboard logo: VT323 font (Google Fonts, monospace fallback) replacing Courier New for the title.
- Logo glitch animation: RGB chromatic-aberration split (red/cyan pseudo-layers with `clip-path` slices), `skewX` body flicker, and JS character corruption.
- Random glitch fires every 5–14s. Intense glitch fires once when Gate E arms or a doom loop is detected.
- `dashboard/components/logo.js`: `initLogo()` and `triggerGlitch(intense)`.

## [0.4.0] - 2026-05-21

### Added
- `projects` table in DB: slug, name, url, language, multisite, critical_flows, risk_zones, primary_playbooks, do_not_touch, special_notes — populated from RSI.yaml.
- `matrix_db.py ingest-rsi [slug]`: reads RSI.yaml, upserts into DB. No-arg form ingests all projects. Auto-runs on every `save`.
- `matrix_db.py report [--project slug]`: AI-readable report — session history, averages vs cross-project benchmarks, RSI context, pending notes, signal frequency bar chart.
- `matrix_db.py insights`: cross-project signal heatmap and hot projects CLI summary.
- Dashboard History tab: **Cross-Project Insights** card — signal heatmap, hot projects, pending recommendations.
- `/api/db/insights` and `/api/db/report` endpoints.
- `agents/SMITH.md` Step B.7: reads DB report at session start.
- `dashboard.sh ensure`: starts server if not running, silent if already up.
- `matrix.sh`: calls `dashboard.sh ensure` on every launch.

### Fixed
- `scripts/version.sh`: no longer inserts empty `### Added\n-` placeholder when `[Unreleased]` already has content — moves existing content to the new version section instead.

## [0.3.0] - 2026-05-21

### Added
- SQLite session storage (`scripts/matrix_db.py`): `sessions`, `bottleneck_snapshots`, `ai_notes` tables. DB stored at `data/matrix.db` (gitignored, created on first save).
- `matrix_db.py save <session_id>`: reads `/tmp` session files, computes all 11 bottleneck signals, writes to DB. CLI also supports `history`, `patterns`, `note`.
- Dashboard **History tab**: full-page view with sessions list (all signals colour-coded), patterns grid per project showing model breakdown, project filter and refresh.
- `agents/SMITH.md` Gate E: close protocol now saves session to DB before clearing the flag.
- `data/` directory added; `data/*.db` gitignored.

### Changed
- Dashboard tab architecture: `LIVE` and `HISTORY` tabs replace the single-view layout.
- `matrix-dashboard.py`: `/api/db/history`, `/api/db/patterns`, `/api/db/notes` endpoints; `allow_reuse_address=True` prevents `[Errno 48]` on restart.
- Dashboard spacing: `#view-live` and `#view-history` are proper flex columns; removed stale `min-height: 100vh`.

### Fixed
- Codex interactive flow now auto-installs live dashboard hooks from `scripts/activate.sh` after AI selection, so `./scripts/matrix.sh` and `./scripts/matrix.sh <project>` work without manual hook setup.
- Burn rate calculation: events sorted chronologically before span computation (was producing inflated values).
- History tab loads correctly in TEST mode.

## [0.2.0] - 2026-05-21

### Added
- Dashboard overhaul: token usage panel with colour-coded event list (green/yellow/red by token count), top-3 bottleneck mini-cards, always-open 280px panel.
- Bottleneck Signals redesigned from card grid to compact key-value list; 11 signals: Stage Time, Wait vs Work, Verify Friction, Tool Hotspot, Queue Pressure, Token Burn Rate, Cache Hit Rate, Rework Index, Doom Loop, Read/Edit Ratio, Context Pressure.
- Graphs drawer: token usage area chart and imported session stats merged into a single collapsible drawer, collapsed by default with summary stats always visible in the header.
- Event log: token count column with colour coding; fixed 180px height with internal scroll.
- Dashboard fully scrollable on desktop and mobile; responsive across three breakpoints (1100 / 768 / 480px); viewport meta tag added.
- `policies/GIT_WORKFLOW.md`: pre-ticket git setup sequence, protected branch rules, branch naming convention.
- `agents/SMITH.md` Step B.5: git repo check and branch creation before the ticket dump.

## [0.1.0] - 2026-05-20

### Added
- First tagged open-source release baseline.
