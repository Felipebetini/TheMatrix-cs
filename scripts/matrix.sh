#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  The Matrix — Pipeline Runner                                ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:
#   ./scripts/matrix.sh                    ← Smith asks which project
#   ./scripts/matrix.sh my-project         ← pre-load project context
#   ./scripts/matrix.sh my-project codex   ← force Codex (Claude rate-limited)
#
# Pipeline flow:
#   Smith orchestrates everything internally using sub-agents.
#   Smith → Cypher → Worker → Tester → Seraph → Gate E
#   All chaining happens inside the Smith session — no shell glue needed.

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${1:-}"
FORCE_AI="${2:-}"

export MATRIX_VAULT="$VAULT"

# ─── Pre-flight: detect unconfigured template ──────────────────────────────────

WARN=0

if grep -q "ZION NOT CONFIGURED" "$VAULT/memory/ZION.md" 2>/dev/null; then
    echo ""
    echo "  ⚠️  ZION not configured."
    echo "     Edit memory/ZION.md — replace the 'Who we are' section with your team."
    WARN=1
fi

if [ -n "$PROJECT" ] && grep -q "project-slug\|replace with" "$VAULT/projects/$PROJECT/RSI.yaml" 2>/dev/null; then
    echo ""
    echo "  ⚠️  RSI.yaml for '$PROJECT' has unfilled placeholders."
    echo "     Edit projects/$PROJECT/RSI.yaml before running a real ticket."
    WARN=1
fi

if [ "$WARN" = "1" ]; then
    echo ""
    read -r -p "  Continue anyway? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
fi

echo ""
echo "  ▶  Matrix starting${PROJECT:+ — project: $PROJECT}${FORCE_AI:+ — model: $FORCE_AI}"
echo ""

"$VAULT/scripts/activate.sh" smith "$PROJECT" "$FORCE_AI"

# Post-session Gate E check (safety net — Claude has the Stop hook, this catches Codex)
if [ -f "/tmp/matrix-ticket.flag" ]; then
    echo ""
    echo "  ⚠️  Session ended with an active ticket."
    echo "     Gate E close protocol was not completed."
    echo "     Run matrix.sh again to re-enter Smith and finish, or:"
    echo "     rm /tmp/matrix-ticket.flag  (only if the ticket was dismissed)"
    echo ""
fi
