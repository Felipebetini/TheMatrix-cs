#!/usr/bin/env bash
VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$VAULT/scripts/track-usage-live.py" 2>/dev/null
exit 0
