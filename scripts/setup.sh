#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  The Matrix — First-run setup                                ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:
#   ./scripts/setup.sh              ← full setup (ZION + optional project)
#   ./scripts/setup.sh --zion-only  ← only configure ZION
#
# Run automatically by matrix.sh when ZION is unconfigured.
# Safe to re-run — will skip steps already completed.

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZION_FILE="$VAULT/memory/ZION.md"
TEMPLATE_DIR="$VAULT/projects/_template"

# ─── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ─── Helpers ───────────────────────────────────────────────────────────────────

print_header() {
    echo ""
    echo -e "${BOLD}════════════════════════════════════════${RESET}"
    echo -e "${BOLD}  THE MATRIX — First-time setup${RESET}"
    echo -e "${BOLD}════════════════════════════════════════${RESET}"
    echo ""
    echo "  Welcome. Let's configure The Matrix for your team."
    echo "  This takes about 2 minutes."
    echo "  Answers are saved to memory/ZION.md and projects/."
    echo ""
}

print_step() {
    local step="$1" total="$2" title="$3"
    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BOLD}Step $step of $total — $title${RESET}"
    echo ""
}

print_ok()   { echo -e "  ${GREEN}✓${RESET}  $1"; }
print_warn() { echo -e "  ${YELLOW}⚠${RESET}   $1"; }
print_err()  { echo -e "  ${RED}✗${RESET}  $1"; }

# ask QUESTION EXAMPLE MIN_WORDS
# Prompts until the answer meets MIN_WORDS, or gives up after 3 tries.
ask() {
    local question="$1"
    local example="$2"
    local min_words="${3:-5}"
    local attempts=0
    local answer=""

    while true; do
        echo -e "  ${BOLD}${question}${RESET}"
        [ -n "$example" ] && echo -e "  ${CYAN}e.g.${RESET} \"$example\""
        printf "  > "
        read -r answer

        local word_count
        word_count=$(echo "$answer" | wc -w | tr -d '[:space:]')

        if [ "$word_count" -lt "$min_words" ]; then
            attempts=$((attempts + 1))
            echo ""
            if [ "$attempts" -ge 3 ]; then
                print_warn "Short answer accepted. You can edit memory/ZION.md later."
                break
            else
                print_err "Too brief — the agents need enough context to work with."
                echo "  Please write at least $min_words words. (Attempt $attempts/3)"
                echo ""
            fi
        else
            break
        fi
    done

    echo "$answer"
}

# ask_line QUESTION EXAMPLE MIN_CHARS
# Single-line prompt with minimum character validation.
ask_line() {
    local question="$1"
    local example="$2"
    local min_chars="${3:-3}"
    local attempts=0
    local answer=""

    while true; do
        echo -e "  ${BOLD}${question}${RESET}"
        [ -n "$example" ] && echo -e "  ${CYAN}e.g.${RESET} \"$example\""
        printf "  > "
        read -r answer

        local char_count=${#answer}
        if [ "$char_count" -lt "$min_chars" ]; then
            attempts=$((attempts + 1))
            echo ""
            if [ "$attempts" -ge 3 ]; then
                print_warn "Short answer accepted."
                break
            else
                print_err "Too short — minimum $min_chars characters. (Attempt $attempts/3)"
                echo ""
            fi
        else
            break
        fi
    done

    echo "$answer"
}

# ask_slug QUESTION EXAMPLE
# Prompts for a slug: lowercase letters, numbers, hyphens only.
ask_slug() {
    local question="$1"
    local example="$2"
    local answer=""

    while true; do
        echo -e "  ${BOLD}${question}${RESET}"
        [ -n "$example" ] && echo -e "  ${CYAN}e.g.${RESET} \"$example\""
        echo "  (lowercase letters, numbers, hyphens — no spaces)"
        printf "  > "
        read -r answer

        # Normalise: lowercase, replace spaces with hyphens
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

        if [ -z "$answer" ]; then
            print_err "Slug cannot be empty."
            echo ""
        else
            echo "$answer"
            return 0
        fi
    done
}

# ask_choice QUESTION OPTIONS...
# Shows numbered options, returns the chosen value.
ask_choice() {
    local question="$1"
    shift
    local options=("$@")
    local choice answer

    echo -e "  ${BOLD}${question}${RESET}"
    for i in "${!options[@]}"; do
        echo "  [$((i+1))] ${options[$i]}"
    done
    printf "  > "
    read -r choice

    # Validate
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
        echo "${options[$((choice-1))]}"
    else
        echo "${options[0]}"  # default to first
    fi
}

# ─── Writers ───────────────────────────────────────────────────────────────────

write_zion() {
    local team_desc="$1"
    local stakes="$2"

    python3 - "$ZION_FILE" "$team_desc" "$stakes" <<'PYEOF'
import sys, re

zion_file, team_desc, stakes = sys.argv[1], sys.argv[2], sys.argv[3]

with open(zion_file) as f:
    content = f.read()

# Replace the unconfigured block (the warning + two placeholder lines)
old_block = re.compile(
    r'⚠️ ZION NOT CONFIGURED.*?^---',
    re.MULTILINE | re.DOTALL
)

new_block = f"{team_desc}\n\n{stakes}\n\n---"

if old_block.search(content):
    content = old_block.sub(new_block, content, count=1)
else:
    # Fallback: replace the whole "Who we are" section body
    content = re.sub(
        r'(## Who we are\n\n).*?(\n\n---)',
        r'\g<1>' + team_desc + '\n\n' + stakes + r'\2',
        content,
        count=1,
        flags=re.DOTALL
    )

with open(zion_file, 'w') as f:
    f.write(content)

print("ok")
PYEOF
}

create_project() {
    local slug="$1"
    local name="$2"
    local description="$3"
    local operator="$4"
    local language="$5"
    local working_dir="$6"
    local deployment="$7"

    local project_dir="$VAULT/projects/$slug"

    # Copy template
    mkdir -p "$project_dir"
    cp "$TEMPLATE_DIR/RSI.yaml"             "$project_dir/RSI.yaml"
    cp "$TEMPLATE_DIR/CHANGELOG.md"         "$project_dir/CHANGELOG.md"
    cp "$TEMPLATE_DIR/INCIDENT_LOG.md"      "$project_dir/INCIDENT_LOG.md"
    cp "$TEMPLATE_DIR/ERROR_SIGNATURES.md"  "$project_dir/ERROR_SIGNATURES.md"

    # Write RSI.yaml via Python (handles special chars and escaping cleanly)
    python3 - "$project_dir/RSI.yaml" "$slug" "$name" "$description" \
              "$operator" "$language" "$working_dir" "$deployment" <<'PYEOF'
import sys

rsi_file = sys.argv[1]
values = {
    'slug':          sys.argv[2],
    'name':          sys.argv[3],
    'description':   sys.argv[4],
    'operator':      sys.argv[5],
    'language':      sys.argv[6],
    'working_dir':   sys.argv[7],
    'deployment':    sys.argv[8],
}

replacements = {
    'slug: project-slug':              f"slug: {values['slug']}",
    'name: "Project Display Name"':    f"name: \"{values['name']}\"",
    'description: "One sentence about what this project is and who it\'s for."':
        f"description: \"{values['description']}\"",
    'operator: "Your name"':           f"operator: \"{values['operator']}\"",
    'client_language: en':             f"client_language: {values['language']}",
    'working_directory: "/path/to/project/files"':
        f"working_directory: \"{values['working_dir']}\"",
    'deployment: git':                 f"deployment: {values['deployment']}",
}

with open(rsi_file) as f:
    content = f.read()

for old, new in replacements.items():
    content = content.replace(old, new, 1)

with open(rsi_file, 'w') as f:
    f.write(content)

print("ok")
PYEOF

    # Update CHANGELOG.md project name
    sed -i.bak "s/\[Project Name\]/$name/g" "$project_dir/CHANGELOG.md" 2>/dev/null
    rm -f "$project_dir/CHANGELOG.md.bak"
}

# ─── Setup steps ───────────────────────────────────────────────────────────────

setup_zion() {
    local total="${1:-4}"

    print_step 1 "$total" "Team identity"
    echo "  This goes into ZION — the always-loaded core that every agent reads."
    echo "  Be specific. Vague descriptions produce vague agents."
    echo ""

    local team_desc
    team_desc=$(ask \
        "What does your team do?" \
        "Customer success team. We maintain SaaS products for 40+ clients." \
        8)

    echo ""

    local stakes
    stakes=$(ask \
        "What do errors cost your clients?" \
        "Errors cause revenue loss and damage client trust. We move carefully, not fast." \
        7)

    echo ""
    print_step 2 "$total" "Operator name"
    echo "  Your name appears in changelogs and ticket records."
    echo ""

    local operator_name
    operator_name=$(ask_line \
        "Your name:" \
        "Alex Johnson" \
        2)

    echo ""

    # Write to ZION
    local result
    result=$(write_zion "$team_desc" "$stakes")

    if [ "$result" = "ok" ]; then
        print_ok "ZION configured"
    else
        print_warn "ZION write may have had an issue — check memory/ZION.md manually"
    fi

    # Store operator name for project creation
    OPERATOR_NAME="$operator_name"
}

setup_first_project() {
    local step_start="${1:-3}"
    local total="${2:-4}"

    print_step "$step_start" "$total" "First project (optional)"
    echo "  Create a project now, or skip and run ./scripts/new-project.sh later."
    echo ""
    printf "  Create a project now? [y/N] "
    read -r create_now
    echo ""

    if [[ ! "$create_now" =~ ^[Yy]$ ]]; then
        echo "  Skipped — run ./scripts/new-project.sh when you're ready."
        return 0
    fi

    local slug
    slug=$(ask_slug \
        "Project slug:" \
        "my-client")

    echo ""

    # Check if already exists
    if [ -d "$VAULT/projects/$slug" ]; then
        print_warn "Project '$slug' already exists — skipping creation."
        return 0
    fi

    local name
    name=$(ask_line \
        "Project display name:" \
        "My Client" \
        3)
    echo ""

    local description
    description=$(ask \
        "One sentence describing this project:" \
        "E-commerce platform for a mid-size retail brand, running on custom SaaS stack." \
        6)
    echo ""

    local language
    language=$(ask_choice \
        "Client communication language:" \
        "en" "nl" "fr" "de" "es")
    echo ""

    local working_dir
    working_dir=$(ask_line \
        "Where are the project files on this machine?" \
        "/Users/you/projects/my-client" \
        5)
    echo ""

    local deployment
    deployment=$(ask_choice \
        "Deployment method:" \
        "git" "sftp" "ci-cd" "manual")
    echo ""

    create_project "$slug" "$name" "$description" \
                   "${OPERATOR_NAME:-Operator}" "$language" \
                   "$working_dir" "$deployment"

    print_ok "Project '$slug' created at projects/$slug/"
    CREATED_PROJECT="$slug"
}

# ─── Main ──────────────────────────────────────────────────────────────────────

ZION_ONLY=0
[ "${1:-}" = "--zion-only" ] && ZION_ONLY=1

TOTAL_STEPS=4
[ "$ZION_ONLY" = "1" ] && TOTAL_STEPS=2

print_header

OPERATOR_NAME=""
CREATED_PROJECT=""

# Step 1+2: ZION
if grep -q "ZION NOT CONFIGURED" "$ZION_FILE" 2>/dev/null; then
    setup_zion "$TOTAL_STEPS"
else
    print_ok "ZION already configured — skipping"
    # Still need operator name for project creation
    echo ""
    echo -e "  ${BOLD}Your name (for changelogs):${RESET}"
    printf "  > "
    read -r OPERATOR_NAME
fi

# Step 3+4: First project (unless --zion-only)
if [ "$ZION_ONLY" = "0" ]; then
    setup_first_project 3 "$TOTAL_STEPS"
fi

# ─── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  ${GREEN}${BOLD}Setup complete.${RESET}"
echo ""

if [ -n "$CREATED_PROJECT" ]; then
    echo "  Start your first ticket:"
    echo "  ./scripts/matrix.sh $CREATED_PROJECT"
else
    echo "  Next: create a project with ./scripts/new-project.sh"
    echo "  Then: ./scripts/matrix.sh <project-slug>"
fi

echo ""
