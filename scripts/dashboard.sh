#!/usr/bin/env bash
# Matrix Dashboard Launcher
#
# Starts the dashboard server and opens the browser.
# Dashboard polls /tmp/matrix-state.json and /tmp/matrix-events.jsonl.

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT=2025

# Check if already running
if lsof -i :$PORT &>/dev/null 2>&1; then
    echo "  Dashboard already running → http://localhost:$PORT"
    open "http://localhost:$PORT" 2>/dev/null || true
    exit 0
fi

echo ""
echo "  Starting Matrix dashboard → http://localhost:$PORT"
echo ""

# Start server in background
python3 "$VAULT/scripts/matrix-dashboard.py" &
SERVER_PID=$!

# Wait for server to be ready
sleep 0.5

# Open browser
if command -v open &>/dev/null; then
    open "http://localhost:$PORT"
elif command -v xdg-open &>/dev/null; then
    xdg-open "http://localhost:$PORT"
fi

echo "  Dashboard PID: $SERVER_PID"
echo "  Press Ctrl+C to stop"
echo ""

# Keep running until interrupted
wait $SERVER_PID
