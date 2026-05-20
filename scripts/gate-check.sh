#!/usr/bin/env bash
# Matrix Gate E — Stop Hook (Ralph Loop)
#
# Claude Code calls this script when the model tries to stop.
# If /tmp/matrix-ticket.flag exists, an active ticket requires Gate E.
# Exit non-zero to block the stop and force Gate E completion.
#
# Smith writes the flag after brief approval:    touch /tmp/matrix-ticket.flag
# Smith removes it after Gate E completes:       rm -f /tmp/matrix-ticket.flag

FLAG="/tmp/matrix-ticket.flag"

if [ -f "$FLAG" ]; then
    echo "STOP BLOCKED — Active Matrix ticket requires Gate E."
    echo ""
    echo "Complete the close protocol before this session ends:"
    echo "  10a — CHANGELOG.md updated"
    echo "  10b — INCIDENT_LOG.md updated"
    echo "  10c — ERROR_SIGNATURES.md checked for new patterns"
    echo "  10d — INCIDENT_PATTERNS.md checked for cross-project match"
    echo "  10e — Ticket record created"
    echo "  10f — Unknown fields written back"
    echo ""
    echo "Smith removes the flag after Gate E: rm /tmp/matrix-ticket.flag"
    echo ""
    echo "If the operator dismissed the ticket without a fix:"
    echo "  rm /tmp/matrix-ticket.flag"
    exit 1
fi

exit 0
