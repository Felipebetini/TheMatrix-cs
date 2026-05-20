#!/usr/bin/env bash
# Matrix PreToolUse Hook — forwards stdin (tool JSON) to track-tool.py
# Claude Code pipes: {"tool_name": "Read", "tool_input": {...}}
# Must exit 0 — never block the tool.

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$VAULT/scripts/track-tool.py" 2>/dev/null
exit 0
