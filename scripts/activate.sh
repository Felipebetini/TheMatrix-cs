#!/usr/bin/env bash
# The Matrix — Agent Activation Script
#
# Usage:
#   ./scripts/activate.sh [agent] [project] [override-ai]
#
# Examples:
#   ./scripts/activate.sh smith               → ask AI, ask project interactively
#   ./scripts/activate.sh smith imlab         → Claude + imlab context
#   ./scripts/activate.sh smith imlab codex   → Force Codex (Claude rate-limited)
#   ./scripts/activate.sh oracle imlab        → Gemini + full .ai-docs
#   ./scripts/activate.sh status              → Check which AIs are available
#
# AI compatibility:
#   Claude  → all agents (full file tools, write-back, interactive loading)
#   Codex   → Junior, Midlevel, Senior (pre-loaded context, produces diffs)
#   Gemini  → Oracle only (large context dumps — no file write support)

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAW_AGENT="${1:-smith}"
AGENT="$(printf '%s' "$RAW_AGENT" | tr '[:upper:]' '[:lower:]')"
PROJECT="${2:-}"
OVERRIDE_AI="$(printf '%s' "${3:-}" | tr '[:upper:]' '[:lower:]')"
CONTEXT_FILE="/tmp/matrix-context-$AGENT-$$.md"
SESSION_ID="${MATRIX_SESSION_ID:-$(date +%s)-$AGENT-${PROJECT:-none}-$RANDOM}"
SESSION_SAFE="$(printf '%s' "$SESSION_ID" | tr -cs '[:alnum:]_.-' '-')"
SESSION_SUFFIX="-$SESSION_SAFE"
STATE_FILE="/tmp/matrix-state${SESSION_SUFFIX}.json"
EVENTS_FILE="/tmp/matrix-events${SESSION_SUFFIX}.jsonl"
USAGE_LIVE_FILE="/tmp/matrix-usage-live${SESSION_SUFFIX}.json"

export MATRIX_SESSION_ID="$SESSION_SAFE"
export MATRIX_STATE_FILE="$STATE_FILE"
export MATRIX_EVENTS_FILE="$EVENTS_FILE"
export MATRIX_USAGE_LIVE_FILE="$USAGE_LIVE_FILE"

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
    echo "Tip: if Claude is rate-limited, add 'codex' as third arg:"
    echo "  ./scripts/activate.sh smith imlab codex"
    exit 0
fi

# ─── AI Routing ────────────────────────────────────────────────────────────────

primary_ai() {
    case "$1" in
        oracle)                        echo "gemini" ;;
        junior|midlevel)               echo "codex"  ;;
        morpheus|commander|seraph|\
        cypher|senior|smith|trinity)  echo "claude" ;;
        *)                             echo "claude" ;;
    esac
}

fallback_ai() {
    case "$1" in
        oracle)               echo "claude" ;;  # Gemini down → Claude
        junior|midlevel)      echo "claude" ;;  # Codex down → Claude
        *)                    echo "codex"  ;;  # Claude down → Codex
    esac
}

# Override AI if third arg provided (e.g. "codex" when Claude is rate-limited)
if [ -n "$OVERRIDE_AI" ]; then
    AI="$OVERRIDE_AI"
    echo "  ⚡ Override active: using $AI instead of default"
elif [ -n "$MATRIX_NON_INTERACTIVE" ]; then
    # Called from matrix.sh pipeline — use default AI, no prompts
    AI=$(primary_ai "$AGENT")
elif [ -t 0 ]; then
    # Interactive session — must select explicitly, no default
    while true; do
        echo ""
        echo "  Select AI:"
        echo "  [1] claude  — full harness, Stop hook, write-back"
        echo "  [2] codex   — skills system, fast execution"
        echo "  [3] gemini  — Oracle only, large context, read-only"
        echo ""
        read -r -p "  > " ai_choice
        case "$ai_choice" in
            1|claude|c) AI="claude";  break ;;
            2|codex|x)  AI="codex";   break ;;
            3|gemini|g) AI="gemini";  break ;;
            *) echo "  Please enter 1, 2, or 3" ;;
        esac
    done
    echo ""

    # Gemini warning for non-Oracle agents
    if [ "$AI" = "gemini" ] && [ "$AGENT" != "oracle" ]; then
        echo "  ⚠️  Gemini has no file write tools — write-back (Step 10) won't run automatically."
        echo "  Smith will output formatted blocks for you to apply manually instead."
        echo "  For best results with Smith, use Claude."
        echo ""
        read -r -p "  Continue anyway? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
        echo ""
    fi

    # Gemini has no file tools, so project must be pre-loaded.
    if [ "$AI" = "gemini" ] && [ -z "$PROJECT" ] && [ -t 0 ]; then
        echo "  $AI cannot read files interactively. Which project? (slug)"
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

    # ── Runtime capabilities note ──────────────────────────────────────────────
    echo "---"
    echo "# RUNTIME"
    echo ""
    echo "Running on: ${AI}"
    echo ""
    if [ "${AI}" = "gemini" ]; then
        echo "Capabilities: large context, research, analysis. No file write tools."
        echo "Write-back (Step 10): output labelled blocks → '### WRITE TO: [file path]' — Felipe applies manually."
        echo "Handoff: print 'MATRIX:NEXT: ./scripts/activate.sh [agent] [slug]' when chaining to next agent."
    elif [ "${AI}" = "codex" ]; then
        echo "Capabilities: code execution, file read/write, shell commands."
        echo "Write-back (Step 10): write files directly using your file tools."
        echo "Handoff: check \$MATRIX_HANDOFF_FILE — if set, write 'next_agent=[agent]\\nproject=[slug]' to it."
    else
        echo "Capabilities: file read/write, bash tools, web fetch, interactive reasoning."
        echo "Write-back (Step 10): write files directly using your file/edit tools."
        echo "Handoff: check \$MATRIX_HANDOFF_FILE — if set, write 'next_agent=[agent]\\nproject=[slug]' to it."
    fi
    echo ""

    # ── Pipeline context (if launched via matrix.sh) ───────────────────────────
    if [ -n "$MATRIX_BRIEF_FILE" ] && [ -f "$MATRIX_BRIEF_FILE" ]; then
        echo "---"
        echo "# BRIEF FROM PREVIOUS AGENT"
        echo ""
        cat "$MATRIX_BRIEF_FILE"
        echo ""
    fi

    # 1. Zion — always
    cat "$VAULT/memory/ZION.md"
    echo ""

    # 1b. Capabilities — for agents that do active checking
    case "$AGENT" in
        oracle|senior|midlevel|junior)
            if [ -f "$VAULT/memory/CAPABILITIES.md" ]; then
                echo "---"
                cat "$VAULT/memory/CAPABILITIES.md"
                echo ""
            fi
            ;;
    esac

    # 1c. Skills — for agents that can invoke Claude Code skills
    case "$AGENT" in
        senior|morpheus)
            if [ -f "$VAULT/memory/SKILLS.md" ] && [ "${AI:-claude}" = "claude" ]; then
                echo "---"
                cat "$VAULT/memory/SKILLS.md"
                echo ""
            fi
            ;;
    esac

    # 2a. No project specified
    if [ -z "$PROJECT" ]; then
        echo "---"
        echo "# AVAILABLE PROJECTS"
        echo ""
        if [ "${AI:-claude}" != "gemini" ]; then
            echo "When the user tells you which project they want to work on, read its files yourself."
            echo "Projects live at:"
            echo "  - Context/docs:  ~/Documents/The Matrix/projects/[slug]/"
            echo "  - Working files: ~/Local Sites/[slug]/app/public/  (LocalWP — this is where fixes are made)"
            echo ""
            echo "Slugs:"
            ls "$VAULT/projects/" | grep -v _template | sed 's/^/  - /'
            echo ""
            echo "After user confirms project, read these files (use your file tools):"
            echo "  ~/Local Sites/[slug]/app/public/.ai-docs/AI_CONTEXT.md"
            echo "  ~/Local Sites/[slug]/app/public/.ai-docs/ARCHITECTURE.md"
            echo "  ~/Local Sites/[slug]/app/public/.ai-docs/ERROR_SIGNATURES.md"
            echo "  ~/Documents/The Matrix/projects/[slug]/RSI.yaml"
            echo "  ~/Documents/The Matrix/projects/[slug]/CHANGELOG.md"
            echo ""
        else
            echo "NOTE: Running on Gemini. No interactive file tools available."
            echo "Ask Felipe which project and he will restart with the slug pre-loaded."
            echo ""
            echo "Slugs:"
            ls "$VAULT/projects/" | grep -v _template | sed 's/^/  - /'
            echo ""
        fi
    fi

    # 2c. Codex runtime rules (codex-only layer)
    if [ "${AI:-claude}" = "codex" ] && [ -f "$VAULT/memory/CODEX.md" ]; then
        echo "---"
        echo "# CODEX RUNTIME"
        echo ""
        cat "$VAULT/memory/CODEX.md"
        echo ""
    fi

    # 2b. Project RSI if specified (pre-loaded shortcut)
    if [ -n "$PROJECT" ]; then
        local rsi="$VAULT/projects/$PROJECT/RSI.yaml"
        [ -f "$rsi" ] && echo -e "\n---\n# PROJECT: $PROJECT\n" && cat "$rsi" && echo ""

        # 3. Find .ai-docs in Local Sites (primary source of project knowledge)
        local aidocs=""
        for candidate in \
            "$HOME/Local Sites/$PROJECT/app/public/.ai-docs" \
            "$HOME/Local Sites/${PROJECT}/app/public/.ai-docs"; do
            if [ -d "$candidate" ]; then
                aidocs="$candidate"
                break
            fi
        done

        if [ -n "$aidocs" ]; then
            echo "---"
            if [ "$AGENT" = "oracle" ]; then
                # Oracle gets everything — Gemini handles the full size
                echo "# PROJECT DOCUMENTATION (.ai-docs — full)"
                echo ""
                for f in "$aidocs"/*.md "$aidocs"/*.txt; do
                    [ -f "$f" ] || continue
                    echo "## $(basename "$f")"
                    echo ""
                    cat "$f"
                    echo ""
                    echo "---"
                done
            else
                # Other agents: key files only (token discipline)
                echo "# PROJECT KNOWLEDGE (.ai-docs)"
                echo ""
                for key in "AI_CONTEXT.md" "ARCHITECTURE.md" "ERROR_SIGNATURES.md" "ENVIRONMENT.md"; do
                    [ -f "$aidocs/$key" ] || continue
                    echo "## $key"
                    echo ""
                    cat "$aidocs/$key"
                    echo ""
                    echo "---"
                done
            fi
        else
            echo "# NOTE: No .ai-docs found for '$PROJECT' in ~/Local Sites/ — load manually if available"
        fi

        # 4. Project hub + support change log (Matrix-only — not in .ai-docs)
        # Hub file is named "[Display Name].md" (not CHANGELOG.md)
        local hub
        hub=$(find "$VAULT/projects/$PROJECT" -maxdepth 1 -name "*.md" ! -name "CHANGELOG.md" 2>/dev/null | head -1)
        if [ -n "$hub" ]; then
            echo "---"
            echo "# PROJECT HUB"
            echo ""
            cat "$hub"
            echo ""
        fi
        local changelog="$VAULT/projects/$PROJECT/CHANGELOG.md"
        if [ -f "$changelog" ]; then
            echo "---"
            echo "# SUPPORT CHANGE LOG (our changes to this site)"
            echo ""
            cat "$changelog"
            echo ""
        fi
    fi

    # 5. Agent prompt
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
                    # Smith: interactive, CLAUDE.md handles context
                    echo ""
                    echo "  ┌─────────────────────────────────────────────┐"
                    echo "  │  Smith is ready. Type your project name or  │"
                    echo "  │  paste the ticket to begin.                 │"
                    echo "  └─────────────────────────────────────────────┘"
                    echo ""
                    claude
                elif [ -n "$MATRIX_NON_INTERACTIVE" ]; then
                    # Pipeline agent: run to completion and exit automatically
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
    'session_id': '$SESSION_SAFE',
}
open('$STATE_FILE', 'w').write(json.dumps(state))
open('$EVENTS_FILE', 'a').write(
    json.dumps({'ts': int(time.time()), 'iso': time.strftime('%Y-%m-%dT%H:%M:%S'), 'tool': 'SYSTEM', 'target': 'Session started — $AGENT on $AI'}) + '\n'
)
" 2>/dev/null

# Try primary (or override) AI
if launch "$AI" "$CONTEXT_FILE"; then
    rm -f "$CONTEXT_FILE"
    # Mark session idle in dashboard
    python3 -c "
import json
try:
    s = json.load(open('$STATE_FILE'))
    s['status'] = 'idle'
    open('$STATE_FILE','w').write(json.dumps(s))
except: pass
" 2>/dev/null
    exit 0
fi

# Primary failed — try fallback automatically
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

# All CLIs failed — clipboard
echo "⚠️  No CLI available. Copying context to clipboard..."
if command -v pbcopy &>/dev/null; then
    pbcopy < "$CONTEXT_FILE"
    echo "  → Pasted into the web UI as your first message."
elif command -v xclip &>/dev/null; then
    xclip -selection clipboard < "$CONTEXT_FILE"
    echo "  → Pasted into the web UI as your first message."
else
    echo "  → Context saved to: $CONTEXT_FILE"
fi
