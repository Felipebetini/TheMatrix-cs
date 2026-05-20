#!/usr/bin/env bash
# The Matrix — Agent Activation Script
#
# Usage:
#   ./scripts/activate.sh [agent] [project] [override-ai]
#
# Examples:
#   ./scripts/activate.sh smith                → ask AI, ask project interactively
#   ./scripts/activate.sh smith my-project     → Claude + project context
#   ./scripts/activate.sh smith my-project codex  → Force Codex
#   ./scripts/activate.sh oracle my-project    → Gemini + full project docs
#   ./scripts/activate.sh status               → Check which AIs are available
#
# AI compatibility:
#   Claude  → all agents (full file tools, write-back, interactive)
#   Codex   → Junior, Midlevel (pre-loaded context, produces diffs)
#   Gemini  → Oracle only (large context dumps — no file write)

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAW_AGENT="${1:-smith}"
AGENT="$(printf '%s' "$RAW_AGENT" | tr '[:upper:]' '[:lower:]')"
PROJECT="${2:-}"
OVERRIDE_AI="$(printf '%s' "${3:-}" | tr '[:upper:]' '[:lower:]')"
CONTEXT_FILE="/tmp/matrix-context-$AGENT-$$.md"

normalize_agent() {
    case "$1" in
        mid|mid-level|mid_level) echo "midlevel" ;;
        jr)                       echo "junior" ;;
        sr)                       echo "senior" ;;
        est)                      echo "trinity" ;;
        morph|morpheus)           echo "morpheus" ;;
        cmd|commander)            echo "commander" ;;
        *)                        echo "$1" ;;
    esac
}

AGENT="$(normalize_agent "$AGENT")"

# ─── Status check ──────────────────────────────────────────────────────────────

if [ "$AGENT" = "status" ]; then
    echo ""
    echo "Matrix AI Status"
    echo "────────────────"
    command -v claude  &>/dev/null && echo "  ✓ Claude  (claude)" || echo "  ✗ Claude  — not found"
    command -v gemini  &>/dev/null && echo "  ✓ Gemini  (gemini)" || echo "  ✗ Gemini  — not found"
    command -v codex   &>/dev/null && echo "  ✓ Codex   (codex)"  || echo "  ✗ Codex   — not found"
    echo ""
    echo "Routing (current):"
    echo "  Smith, Senior, Cypher, Seraph, Trinity → Claude (fallback: Codex)"
    echo "  Oracle                                   → Gemini (fallback: Claude)"
    echo "  Junior, Midlevel                         → Codex  (fallback: Claude)"
    echo ""
    echo "Tip: if Claude is rate-limited, pass 'codex' as third arg:"
    echo "  ./scripts/activate.sh smith my-project codex"
    exit 0
fi

# ─── AI Routing ────────────────────────────────────────────────────────────────

primary_ai() {
    case "$1" in
        oracle)                        echo "gemini" ;;
        junior|midlevel)               echo "codex"  ;;
        morpheus|commander|seraph|\
        cypher|senior|smith|trinity|\
        tester)                        echo "claude" ;;
        *)                             echo "claude" ;;
    esac
}

fallback_ai() {
    case "$1" in
        oracle)               echo "claude" ;;
        junior|midlevel)      echo "claude" ;;
        *)                    echo "codex"  ;;
    esac
}

if [ -n "$OVERRIDE_AI" ]; then
    AI="$OVERRIDE_AI"
    echo "  ⚡ Override active: using $AI instead of default"
elif [ -n "$MATRIX_NON_INTERACTIVE" ]; then
    AI=$(primary_ai "$AGENT")
elif [ -t 0 ]; then
    DEFAULT=$(primary_ai "$AGENT")
    echo ""
    echo "  Which AI?"
    echo "  [1] Claude  — full file tools, write-back, interactive  (default)"
    echo "  [2] Codex   — pre-loaded context, produces diffs"
    echo "  [3] Gemini  — large context dumps (Oracle only)"
    echo ""
    read -r -p "  > " ai_choice
    case "$ai_choice" in
        2|codex|x)  AI="codex"  ;;
        3|gemini|g) AI="gemini" ;;
        *)           AI="$DEFAULT" ;;
    esac
    echo ""

    if [ "$AI" = "gemini" ] && [ "$AGENT" != "oracle" ]; then
        echo "  ⚠️  Gemini has no file write tools — Gate E write-back won't run automatically."
        echo "  Smith will output labelled blocks for you to apply manually."
        echo "  For best results with Smith, use Claude."
        echo ""
        read -r -p "  Continue anyway? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
        echo ""
    fi

    if [ "$AI" = "gemini" ] && [ -z "$PROJECT" ] && [ -t 0 ]; then
        echo "  Gemini cannot read files interactively. Which project? (slug)"
        echo "  Available:"
        ls "$VAULT/projects/" | grep -v _template | sed 's/^/    /'
        echo ""
        read -r -p "  Project slug > " PROJECT
        echo ""
    fi
else
    AI=$(primary_ai "$AGENT")
fi

# ─── Context Builder ───────────────────────────────────────────────────────────

build_context() {
    echo "# SYSTEM CONTEXT — THE MATRIX"
    echo ""
    echo "---"
    echo "# RUNTIME"
    echo ""
    echo "Running on: ${AI}"
    echo ""
    if [ "${AI}" = "gemini" ]; then
        echo "Capabilities: large context, research, analysis. No file write tools."
        echo "Write-back (Gate E): output '### WRITE TO: [file path]' labelled blocks — operator applies manually."
        echo "Handoff: print 'MATRIX:NEXT: ./scripts/activate.sh [agent] [slug]' when chaining."
    elif [ "${AI}" = "codex" ]; then
        echo "Capabilities: code execution, file read/write, shell commands."
        echo "Write-back (Gate E): write files directly."
        echo "Handoff: write 'next_agent=[agent]\\nproject=[slug]' to \$MATRIX_HANDOFF_FILE if set."
    else
        echo "Capabilities: file read/write, bash tools, web fetch, interactive reasoning."
        echo "Write-back (Gate E): write files directly."
        echo "Handoff: write 'next_agent=[agent]\\nproject=[slug]' to \$MATRIX_HANDOFF_FILE if set."
    fi
    echo ""

    if [ -n "$MATRIX_BRIEF_FILE" ] && [ -f "$MATRIX_BRIEF_FILE" ]; then
        echo "---"
        echo "# BRIEF FROM PREVIOUS AGENT"
        echo ""
        cat "$MATRIX_BRIEF_FILE"
        echo ""
    fi

    # Always: ZION
    cat "$VAULT/memory/ZION.md"
    echo ""

    # Capabilities for workers
    case "$AGENT" in
        oracle|senior|midlevel|junior)
            if [ -f "$VAULT/memory/CAPABILITIES.md" ]; then
                echo "---"
                cat "$VAULT/memory/CAPABILITIES.md"
                echo ""
            fi
            ;;
    esac

    # Skills for agents that invoke them
    case "$AGENT" in
        senior|morpheus)
            if [ -f "$VAULT/memory/SKILLS.md" ] && [ "${AI:-claude}" = "claude" ]; then
                echo "---"
                cat "$VAULT/memory/SKILLS.md"
                echo ""
            fi
            ;;
    esac

    # No project specified
    if [ -z "$PROJECT" ]; then
        echo "---"
        echo "# AVAILABLE PROJECTS"
        echo ""
        if [ "${AI:-claude}" != "gemini" ]; then
            echo "When the operator tells you which project to work on, read its files yourself."
            echo ""
            echo "Slugs:"
            ls "$VAULT/projects/" | grep -v _template | sed 's/^/  - /'
            echo ""
        fi
    fi

    # Codex runtime rules
    if [ "${AI:-claude}" = "codex" ] && [ -f "$VAULT/memory/CODEX.md" ]; then
        echo "---"
        echo "# CODEX RUNTIME"
        echo ""
        cat "$VAULT/memory/CODEX.md"
        echo ""
    fi

    # Project context
    if [ -n "$PROJECT" ]; then
        local rsi="$VAULT/projects/$PROJECT/RSI.yaml"
        [ -f "$rsi" ] && echo -e "\n---\n# PROJECT: $PROJECT\n" && cat "$rsi" && echo ""

        local changelog="$VAULT/projects/$PROJECT/CHANGELOG.md"
        if [ -f "$changelog" ]; then
            echo "---"
            echo "# SUPPORT CHANGE LOG"
            echo ""
            cat "$changelog"
            echo ""
        fi
    fi

    # Agent prompt
    local agent_file
    agent_file=$(find "$VAULT/agents" -iname "${AGENT}.md" 2>/dev/null | head -1)
    if [ -n "$agent_file" ]; then
        echo "---"
        echo "# YOUR ROLE"
        echo ""
        cat "$agent_file"
    else
        echo "⚠️  No agent file found for '$AGENT'" >&2
        exit 1
    fi
}

# ─── Launch AI ─────────────────────────────────────────────────────────────────

launch() {
    local ai="$1"
    local ctx="$2"

    case "$ai" in
        claude)
            if command -v claude &>/dev/null; then
                cd "$VAULT"
                if [ "$AGENT" = "smith" ] && [ -z "$OVERRIDE_AI" ]; then
                    claude
                elif [ -n "$MATRIX_NON_INTERACTIVE" ]; then
                    claude --system "$(cat "$ctx")" -p "Work through your full task. Use your tools. Write the handoff file when done."
                else
                    claude --system "$(cat "$ctx")"
                fi
                return 0
            fi
            return 1
            ;;
        gemini)
            if command -v gemini &>/dev/null; then
                gemini -p "$(cat "$ctx")"$'\n\n---\nMatrix online. Ready.'
                return 0
            fi
            return 1
            ;;
        codex)
            if command -v codex &>/dev/null; then
                cd "$VAULT"
                codex "$(cat "$ctx")"
                return 0
            fi
            return 1
            ;;
    esac
    return 1
}

# ─── Main ──────────────────────────────────────────────────────────────────────

build_context > "$CONTEXT_FILE"
LINE_COUNT=$(wc -l < "$CONTEXT_FILE")

echo ""
echo "▶  Matrix: $AGENT → $AI  |  project: ${PROJECT:-none}  |  context: ${LINE_COUNT} lines"
echo ""

# Write initial dashboard state
python3 -c "
import json, time, os
state = {
    'status': 'active',
    'agent': '$AGENT',
    'project': '${PROJECT:-unknown}',
    'model': '$AI',
    'started_at': int(time.time()),
    'tool_calls': 0,
    'last_tool': None,
    'gate_e_armed': os.path.exists('/tmp/matrix-ticket.flag'),
}
open('/tmp/matrix-state.json', 'w').write(json.dumps(state))
open('/tmp/matrix-events.jsonl', 'a').write(
    json.dumps({'ts': int(time.time()), 'iso': time.strftime('%Y-%m-%dT%H:%M:%S'), 'tool': 'SYSTEM', 'target': 'Session started — $AGENT on $AI'}) + '\n'
)
" 2>/dev/null

# Try primary (or override) AI
if launch "$AI" "$CONTEXT_FILE"; then
    rm -f "$CONTEXT_FILE"
    python3 -c "
import json
try:
    s = json.load(open('/tmp/matrix-state.json'))
    s['status'] = 'idle'
    open('/tmp/matrix-state.json','w').write(json.dumps(s))
except: pass
" 2>/dev/null
    exit 0
fi

# Primary failed — try fallback
FALLBACK=$(fallback_ai "$AGENT")
if [ "$FALLBACK" != "$AI" ]; then
    echo ""
    echo "⚠️  $AI not available. Falling back to $FALLBACK..."
    echo ""
    if launch "$FALLBACK" "$CONTEXT_FILE"; then
        rm -f "$CONTEXT_FILE"
        exit 0
    fi
fi

# All CLIs failed — clipboard fallback
echo "⚠️  No AI CLI available. Copying context to clipboard..."
if command -v pbcopy &>/dev/null; then
    pbcopy < "$CONTEXT_FILE"
    echo "  → Paste into your AI web UI as the first message."
elif command -v xclip &>/dev/null; then
    xclip -selection clipboard < "$CONTEXT_FILE"
    echo "  → Paste into your AI web UI as the first message."
else
    echo "  → Context saved to: $CONTEXT_FILE"
fi
