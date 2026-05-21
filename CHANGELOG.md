# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased]

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
