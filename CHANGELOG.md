# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased]

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

