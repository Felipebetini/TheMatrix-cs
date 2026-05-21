#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  The Matrix — Pipeline Runner                                ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:
#   ./scripts/matrix.sh                        ← Smith asks which project + select AI
#   ./scripts/matrix.sh testa-omega3           ← pre-loads project, select AI
#   ./scripts/matrix.sh testa-omega3 claude    ← Claude
#   ./scripts/matrix.sh testa-omega3 codex     ← Codex
#   ./scripts/matrix.sh testa-omega3 gemini    ← Gemini (Oracle only)
#
# Pipeline flow:
#   Smith orchestrates everything internally using sub-agents.
#   Smith → Commander → Worker → Morpheus → [Seraph gate] → Gate E
#   All chaining happens inside the Smith session — no shell glue needed.

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${1:-}"
FORCE_AI="${2:-}"

export MATRIX_VAULT="$VAULT"

echo ""
echo "  ▶  Matrix starting${PROJECT:+ — project: $PROJECT}${FORCE_AI:+ — model: $FORCE_AI}"
echo ""

# Ensure dashboard is running before the session starts
"$VAULT/scripts/dashboard.sh" ensure

"$VAULT/scripts/activate.sh" smith "$PROJECT" "$FORCE_AI"

# Post-session Gate E check (safety net for Codex — Claude has the Stop hook)
if [ -f "/tmp/matrix-ticket.flag" ]; then
    echo ""
    echo "  ⚠️  Session ended with an active ticket."
    echo "     Gate E close protocol was not completed."
    echo "     Run matrix.sh again to re-enter Smith and finish, or:"
    echo "     rm /tmp/matrix-ticket.flag  (only if Felipe dismissed the ticket)"
    echo ""
fi
