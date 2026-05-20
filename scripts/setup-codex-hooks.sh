#!/usr/bin/env bash
# Configure Codex CLI hooks for Matrix dashboard tracking.
# Writes/merges ~/.codex/hooks.json

set -euo pipefail

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_FILE="$HOME/.codex/hooks.json"

mkdir -p "$(dirname "$HOOKS_FILE")"

python3 - "$HOOKS_FILE" "$VAULT" <<'PY'
import json
import os
import sys

hooks_file = sys.argv[1]
vault = sys.argv[2]

pre_cmd = f"bash '{vault}/scripts/track-tool.sh'"
post_cmd = f"bash '{vault}/scripts/track-usage-live.sh'"

def load(path):
    try:
        with open(path) as f:
            data = json.load(f)
            if isinstance(data, dict):
                return data
    except Exception:
        pass
    return {"hooks": {}}

def ensure_handler(root, event_name, command):
    hooks = root.setdefault("hooks", {})
    event_list = hooks.setdefault(event_name, [])
    entry = {
        "matcher": "",
        "hooks": [{"type": "command", "command": command}],
    }
    if entry not in event_list:
        event_list.append(entry)

data = load(hooks_file)
ensure_handler(data, "PreToolUse", pre_cmd)
ensure_handler(data, "PostToolUse", post_cmd)

with open(hooks_file, "w") as f:
    json.dump(data, f, indent=2)

print(f"Updated {hooks_file}")
print("Enabled:")
print(f"  PreToolUse  -> {pre_cmd}")
print(f"  PostToolUse -> {post_cmd}")
PY

echo ""
echo "Restart Codex sessions so new hooks take effect."
