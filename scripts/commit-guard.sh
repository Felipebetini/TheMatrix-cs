#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Matrix Commit Guard — PreToolUse hook                       ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Intercepts git commit calls, runs pr-check.sh on staged files.
# When blocked, writes structured issues to /tmp/matrix-pr-issues.md
# so the agent can read, fix, and retry — creating a fix loop.
# Doom loop detection: same file failing 3+ times → escalate.
# Exit 1 = block. Exit 0 = allow.

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISSUES_FILE="/tmp/matrix-pr-issues.md"
FAIL_COUNT_FILE="/tmp/matrix-pr-fail-count"

INPUT=$(cat)
CMD=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

# Only intercept git commit commands
if ! echo "$CMD" | grep -qE "git\s+(commit|-C\s+\S+\s+commit)"; then
    exit 0
fi

# Extract working directory from -C flag if present
WORK_DIR=""
if echo "$CMD" | grep -qE "git[[:space:]]+-C[[:space:]]+"; then
    WORK_DIR=$(echo "$CMD" | grep -oE "\-C[[:space:]]+[^[:space:]]+" | head -1 | awk '{print $2}' | sed "s|~|$HOME|g")
    # Canonicalise and validate — reject traversal outside home
    if [ -n "$WORK_DIR" ]; then
        WORK_DIR="$(cd "$WORK_DIR" 2>/dev/null && pwd || echo '')"
        [[ "$WORK_DIR" != "$HOME"* ]] && WORK_DIR=""
    fi
fi

# Get staged files
if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
    STAGED=$(git -C "$WORK_DIR" diff --cached --name-only --diff-filter=ACM 2>/dev/null | \
        while IFS= read -r f; do echo "$WORK_DIR/$f"; done)
else
    STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)
fi

[ -z "$STAGED" ] && exit 0

# Only check code files
FILES_TO_CHECK=""
while IFS= read -r f; do
    case "$f" in
        *.php|*.js|*.jsx|*.ts|*.tsx|*.css|*.scss)
            [ -f "$f" ] && FILES_TO_CHECK="$FILES_TO_CHECK $f"
            ;;
    esac
done <<< "$STAGED"

[ -z "$FILES_TO_CHECK" ] && exit 0

echo "  Running pr-check on staged files..."
# shellcheck disable=SC2086
RESULT=$(bash "$VAULT/scripts/pr-check.sh" $FILES_TO_CHECK 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    # Clean pass — reset fail counter and clear issues file
    rm -f "$ISSUES_FILE" "$FAIL_COUNT_FILE"
    if echo "$RESULT" | grep -q "WARN"; then
        echo "  pr-check PASS (with warnings):"
        echo "$RESULT" | grep "WARN" | head -5
    fi
    exit 0
fi

# ── BLOCKED — write structured issues file for the fix loop ───
FAIL_COUNT=0
if [ -f "$FAIL_COUNT_FILE" ]; then
    FAIL_COUNT=$(cat "$FAIL_COUNT_FILE" 2>/dev/null || echo 0)
fi
FAIL_COUNT=$((FAIL_COUNT + 1))
echo "$FAIL_COUNT" > "$FAIL_COUNT_FILE"

# Extract blocking issues
BLOCKING=$(echo "$RESULT" | grep "BLOCK" | sed 's/.*BLOCK[[:space:]]*//' | head -10)

# Write structured issues file agents will read
cat > "$ISSUES_FILE" <<ISSUES
# Commit blocked — pr-check issues to fix

**Attempt:** $FAIL_COUNT of 3 before doom loop escalation
**Files checked:** $(echo "$FILES_TO_CHECK" | tr ' ' '\n' | xargs -I{} basename {} | tr '\n' ', ')

## Blocking issues (must fix before commit)

$(echo "$BLOCKING")

## Full pr-check output

\`\`\`
$(echo "$RESULT" | grep -E "BLOCK|WARN|✗|⚠" | head -20)
\`\`\`

## How to fix and retry

1. Fix each blocking issue listed above
2. Stage the fixed files: \`git add <files>\`
3. Retry the commit — this guard will re-run automatically

**Do NOT use --no-verify to bypass this check.**
ISSUES

# ── Output to agent ────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  BLOCKED — pr-check found issues (attempt $FAIL_COUNT/3)      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "$BLOCKING"
echo ""

if [ "$FAIL_COUNT" -ge 3 ]; then
    echo "  ⚠  DOOM LOOP — same commit blocked 3 times."
    echo "     Escalate to Smith: the fix approach may be wrong."
    echo "     Issues saved to: $ISSUES_FILE"
    echo ""
    exit 1
fi

echo "  Issues written to: $ISSUES_FILE"
echo "  Fix the issues above, stage the files, and retry the commit."
echo "  The guard will re-run automatically."
echo ""
exit 1
