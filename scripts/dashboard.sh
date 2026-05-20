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

  stop)
    if [ -f "$PID_FILE" ]; then
      kill "$(cat "$PID_FILE")" 2>/dev/null
      rm -f "$PID_FILE"
      echo "  ◼  Matrix dashboard stopped"
    else
      echo "  Dashboard is not running"
    fi
    ;;

  test)
    # Already running?
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "  Dashboard already running at http://localhost:$PORT"
      open "http://localhost:$PORT/?mode=test"
      exit 0
    fi

    echo ""
    echo "  ▶  Starting Matrix dashboard (TEST MODE) on http://localhost:$PORT"
    echo ""

    python3 "$VAULT/scripts/matrix-dashboard.py" &
    echo $! > "$PID_FILE"

    sleep 0.6
    open "http://localhost:$PORT/?mode=test"
    ;;

  start|*)
    # Already running?
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "  Dashboard already running at http://localhost:$PORT"
      open "http://localhost:$PORT"
      exit 0
    fi

    echo ""
    echo "  ▶  Starting Matrix dashboard on http://localhost:$PORT"
    echo ""

    python3 "$VAULT/scripts/matrix-dashboard.py" &
    echo $! > "$PID_FILE"

    sleep 0.6
    open "http://localhost:$PORT"
    ;;

esac
