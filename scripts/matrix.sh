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

set -euo pipefail

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${1:-}"
FORCE_AI="${2:-}"
SELECTED_AI_FILE="/tmp/matrix-selected-ai-$$.txt"

export MATRIX_VAULT="$VAULT"
export MATRIX_SELECTED_AI_FILE="$SELECTED_AI_FILE"

echo ""
echo "  ▶  Matrix starting${PROJECT:+ — project: $PROJECT}${FORCE_AI:+ — model: $FORCE_AI}"
echo ""

# Ensure dashboard is running before the session starts
"$VAULT/scripts/dashboard.sh" ensure

"$VAULT/scripts/activate.sh" smith "$PROJECT" "$FORCE_AI"

SELECTED_AI=""
if [ -f "$SELECTED_AI_FILE" ]; then
    SELECTED_AI="$(tr -d '[:space:]' < "$SELECTED_AI_FILE" 2>/dev/null || true)"
fi
rm -f "$SELECTED_AI_FILE"

# Post-session Gate E check (safety net for Codex — Claude has the Stop hook)
if [ -f "/tmp/matrix-ticket.flag" ]; then
    echo ""
    echo "  ⚠️  Session ended with an active ticket."
    echo "     Gate E close protocol was not completed."
    echo "     Run matrix.sh again to re-enter Smith and finish, or:"
    echo "     rm /tmp/matrix-ticket.flag  (only if Felipe dismissed the ticket)"
    echo ""
    if [ "$SELECTED_AI" = "codex" ] || [ "$FORCE_AI" = "codex" ]; then
        echo "  ❌ Codex session blocked from clean exit while Gate E is still pending."
        exit 1
    fi
fi
