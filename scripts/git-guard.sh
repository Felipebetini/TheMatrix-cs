#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Matrix Git Guard — PreToolUse hook                          ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Blocks pushes to protected branches and force-pushes.
# Wired as a PreToolUse hook on the Bash tool.
# Exit 1 = block the tool call. Exit 0 = allow.

INPUT=$(cat)
CMD=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

# Only care about git push commands
if ! echo "$CMD" | grep -q "git push\|git merge"; then
    exit 0
fi

PROTECTED="main|master|develop"

# Block: git push [origin] main/master/develop
if echo "$CMD" | grep -qE "git push[^|;]*(origin\s+)?($PROTECTED)(\s|$|\"|\')"; then
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  BLOCKED — protected branch push                    ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    echo "  Branch: $(echo "$CMD" | grep -oE "(main|master|develop)(\s|$)" | tr -d ' ')"
    echo "  Rule:   main, master, develop are never pushed to directly."
    echo ""
    echo "  Push to your feature branch and open a PR instead:"
    echo "    git push origin feature/<ticket>-<title>"
    echo ""
    exit 1
fi

# Block: force push (any branch)
if echo "$CMD" | grep -qE "git push.*(--force|-f)(\s|$)"; then
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  BLOCKED — force push                               ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    echo "  Force-push is never allowed. If you need to fix the"
    echo "  last commit, use a new commit instead."
    echo ""
    exit 1
fi

exit 0
