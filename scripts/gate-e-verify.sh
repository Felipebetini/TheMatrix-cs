#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Matrix Gate E Verifier                                      ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Checks that all Gate E steps were actually completed before
# the ticket flag can be removed.
#
# Usage:
#   bash scripts/gate-e-verify.sh          # check current ticket
#
# Called by gate-check.sh on every Stop attempt when flag is set.
# Exit 0 = all checks pass. Exit 1 = incomplete.

FLAG="/tmp/matrix-ticket.flag"
META="/tmp/matrix-ticket-meta.json"
VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ERRORS=0
WARNINGS=0

pass()  { echo "  ✓  $1"; }
fail()  { echo "  ✗  $1"; ERRORS=$((ERRORS+1)); }
warn()  { echo "  ⚠  $1"; WARNINGS=$((WARNINGS+1)); }

echo ""
echo "  Gate E Verification"
echo "  ══════════════════"

# ── Read metadata (written at brief approval) ──────────────────
PROJECT=""
SESSION_ID=""
if [ -f "$META" ]; then
    PROJECT=$(python3 - "$META" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(d.get('project', ''))
except Exception:
    print('')
PY
    )
    SESSION_ID=$(python3 - "$META" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(d.get('session_id', ''))
except Exception:
    print('')
PY
    )
fi

[ -n "$PROJECT" ]    && echo "  Project:    $PROJECT"
[ -n "$SESSION_ID" ] && echo "  Session ID: $SESSION_ID"
echo ""

# ── Check 1: Ticket file created ──────────────────────────────
TICKET_COUNT=$(find "$VAULT/tickets" -name "*.md" -newer "$FLAG" \
    ! -name "_template*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$TICKET_COUNT" -gt 0 ]; then
    pass "Ticket record created (tickets/)"
else
    fail "No ticket file — create tickets/[INC-ID]-[slug].md"
fi

# ── Check 2: Project CHANGELOG updated ────────────────────────
if [ -n "$PROJECT" ]; then
    CHANGELOG="$VAULT/projects/$PROJECT/CHANGELOG.md"
    if [ -f "$CHANGELOG" ] && [ "$CHANGELOG" -nt "$FLAG" ]; then
        pass "CHANGELOG.md updated (projects/$PROJECT/)"
    else
        fail "projects/$PROJECT/CHANGELOG.md not updated since ticket started"
    fi
else
    warn "Cannot verify CHANGELOG — project not in meta. Write meta at brief approval."
fi

# ── Check 3: Session saved to DB ──────────────────────────────
if [ -n "$PROJECT" ]; then
    DB_CHECK=$(python3 - "$PROJECT" "${SESSION_ID:-}" "$VAULT" <<'PY'
import sqlite3, os, sys

proj = sys.argv[1]
sid  = sys.argv[2] if len(sys.argv) > 2 else ''
vault = sys.argv[3] if len(sys.argv) > 3 else ''
db   = os.path.join(vault, 'data', 'matrix.db') if vault else ''

if not db or not os.path.exists(db):
    print("no_db")
    sys.exit()

try:
    con = sqlite3.connect(db)
    if sid:
        n = con.execute(
            'SELECT COUNT(*) FROM sessions WHERE session_id=?', (sid,)
        ).fetchone()[0]
    else:
        import time
        flag_mtime = int(os.path.getmtime('/tmp/matrix-ticket.flag'))
        n = con.execute(
            'SELECT COUNT(*) FROM sessions WHERE project=? AND closed_at>=?',
            (proj, flag_mtime)
        ).fetchone()[0]
    con.close()
    print(n)
except Exception as e:
    print(f"error: {e}")
PY
    )
    if [ "$DB_CHECK" = "no_db" ]; then
        warn "DB not found — run python3 scripts/matrix_db.py save <session_id>"
    elif [ "$DB_CHECK" = "0" ]; then
        HINT="${SESSION_ID:-<session_id>}"
        fail "Session not saved to DB — run: python3 scripts/matrix_db.py save $HINT"
    elif echo "$DB_CHECK" | grep -q "error"; then
        warn "DB check error: $DB_CHECK"
    else
        pass "Session saved to DB"
    fi
else
    warn "Cannot verify DB — project not in meta"
fi

# ── Check 4: INCIDENT_PATTERNS checked (warning only) ─────────
PATTERNS="$VAULT/memory/INCIDENT_PATTERNS.md"
if [ "$PATTERNS" -nt "$FLAG" ]; then
    pass "INCIDENT_PATTERNS.md reviewed/updated"
else
    warn "INCIDENT_PATTERNS.md not modified — did you check for cross-project match? (10d)"
fi

# ── Summary ───────────────────────────────────────────────────
echo ""
echo "  ══════════════════"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "  ✓ Gate E complete — run: rm -f /tmp/matrix-ticket.flag"
elif [ $ERRORS -eq 0 ]; then
    echo "  ⚠ $WARNINGS warning(s) — core steps done."
    echo "  You may remove the flag, but review warnings first."
else
    echo "  ✗ $ERRORS required step(s) incomplete — do not remove flag yet."
fi
echo ""

exit $ERRORS
