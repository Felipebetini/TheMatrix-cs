#!/usr/bin/env bash
# The Matrix — Dashboard Launcher
#
# Usage:
#   ./scripts/dashboard.sh          # start server + open browser
#   ./scripts/dashboard.sh test     # start server + open browser in test mode
#   ./scripts/dashboard.sh stop     # kill the server

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT=2025
PID_FILE="/tmp/matrix-dashboard.pid"

case "${1:-start}" in

  ensure)
    # Start silently if not running — used by matrix.sh on every session start
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "  Dashboard already running at http://localhost:$PORT"
    elif lsof -ti ":$PORT" &>/dev/null; then
      echo "  Dashboard already running at http://localhost:$PORT (external process)"
    else
      python3 "$VAULT/scripts/matrix-dashboard.py" &
      echo $! > "$PID_FILE"
      sleep 0.5
      echo "  ▶  Dashboard started at http://localhost:$PORT"
    fi
    ;;

  stop)
    # Kill by PID file
    if [ -f "$PID_FILE" ]; then
      kill "$(cat "$PID_FILE")" 2>/dev/null
      rm -f "$PID_FILE"
    fi
    # Also kill anything else holding the port (handles stale PIDs + manual starts)
    lsof -ti ":$PORT" | xargs kill 2>/dev/null || true
    # Wait for port to actually free
    for i in 1 2 3 4 5; do
      lsof -ti ":$PORT" &>/dev/null || break
      sleep 0.3
    done
    echo "  ◼  Matrix dashboard stopped"
    ;;

  test)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "  Dashboard already running at http://localhost:$PORT"
      open "http://localhost:$PORT/?mode=test"
      exit 0
    fi
    # Clear any stale process on the port
    lsof -ti ":$PORT" | xargs kill 2>/dev/null || true
    sleep 0.3
    echo ""
    echo "  ▶  Starting Matrix dashboard (TEST MODE) on http://localhost:$PORT"
    echo ""
    python3 "$VAULT/scripts/matrix-dashboard.py" &
    echo $! > "$PID_FILE"
    sleep 0.6
    open "http://localhost:$PORT/?mode=test"
    ;;

  start|*)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "  Dashboard already running at http://localhost:$PORT"
      open "http://localhost:$PORT"
      exit 0
    fi
    # Clear any stale process on the port
    lsof -ti ":$PORT" | xargs kill 2>/dev/null || true
    sleep 0.3
    echo ""
    echo "  ▶  Starting Matrix dashboard on http://localhost:$PORT"
    echo ""
    python3 "$VAULT/scripts/matrix-dashboard.py" &
    echo $! > "$PID_FILE"
    sleep 0.6
    open "http://localhost:$PORT"
    ;;

esac
