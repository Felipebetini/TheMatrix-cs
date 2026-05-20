# Nebuchadnezzar — Active Ticket Dashboard

The Nebuchadnezzar is the hovercraft. This is the active operations view — one row per open ticket, updated in real time as work progresses.

---

## Active tickets

| INC-ID | Project | Summary | Phase | Agent | Risk | Flag |
|--------|---------|---------|-------|-------|------|------|
| — | — | No active tickets | — | — | — | — |

---

## Phase codes

| Code | Meaning |
|------|---------|
| `triage` | Smith reviewing, brief not yet produced |
| `brief` | Brief produced, awaiting operator approval |
| `cypher` | Cypher review in progress |
| `worker` | Worker implementing |
| `tester` | Tester running suites |
| `seraph` | Seraph pre-flight check |
| `gate-a` | Awaiting operator staging test |
| `gate-b` | Awaiting operator approval to deploy |
| `gate-c` | Awaiting operator manual action |
| `gate-d` | Awaiting backup confirmation |
| `deploying` | Commander running deployment sequence |
| `gate-e` | Write-back in progress |
| `closed` | Ticket resolved and closed |
| `blocked` | Hardline triggered — see MOBIL_AVE.md |

---

## Notes

This file is updated by Smith at the start and end of each phase. It is a human-readable view — the live dashboard at `localhost:2025` is the real-time view.

For blocked tickets awaiting external action, see `transit/MOBIL_AVE.md`.
