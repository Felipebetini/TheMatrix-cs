#!/usr/bin/env bash
# The Matrix — New project creator
#
# Usage:
#   ./scripts/new-project.sh              ← interactive, asks for slug
#   ./scripts/new-project.sh my-project   ← pre-fills the slug

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="$VAULT/projects/_template"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

print_ok()   { echo -e "  ${GREEN}✓${RESET}  $1"; }
print_warn() { echo -e "  ${YELLOW}⚠${RESET}   $1"; }
print_err()  { echo -e "  ${RED}✗${RESET}  $1"; }

# ask QUESTION EXAMPLE MIN_WORDS
ask() {
    local question="$1" example="$2" min_words="${3:-5}"
    local attempts=0 answer=""

    while true; do
        echo -e "  ${BOLD}${question}${RESET}"
        [ -n "$example" ] && echo -e "  ${CYAN}e.g.${RESET} \"$example\""
        printf "  > "
        read -r answer

        local wc
        wc=$(echo "$answer" | wc -w | tr -d '[:space:]')
        if [ "$wc" -lt "$min_words" ]; then
            attempts=$((attempts + 1))
            echo ""
            if [ "$attempts" -ge 3 ]; then
                print_warn "Short answer accepted — edit projects/\$slug/RSI.yaml to improve it."
                break
            else
                print_err "Too brief — at least $min_words words. (Attempt $attempts/3)"
                echo ""
            fi
        else
            break
        fi
    done
    echo "$answer"
}

ask_line() {
    local question="$1" example="$2" min_chars="${3:-3}"
    local attempts=0 answer=""

    while true; do
        echo -e "  ${BOLD}${question}${RESET}"
        [ -n "$example" ] && echo -e "  ${CYAN}e.g.${RESET} \"$example\""
        printf "  > "
        read -r answer

        if [ "${#answer}" -lt "$min_chars" ]; then
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

ask_slug() {
    local question="$1" example="$2" answer=""

    while true; do
        echo -e "  ${BOLD}${question}${RESET}"
        [ -n "$example" ] && echo -e "  ${CYAN}e.g.${RESET} \"$example\""
        echo "  (lowercase, hyphens only — no spaces)"
        printf "  > "
        read -r answer
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
        [ -n "$answer" ] && echo "$answer" && return 0
        print_err "Slug cannot be empty."
        echo ""
    done
}

ask_choice() {
    local question="$1"; shift
    local options=("$@") choice

    echo -e "  ${BOLD}${question}${RESET}"
    for i in "${!options[@]}"; do
        echo "  [$((i+1))] ${options[$i]}"
    done
    printf "  > "
    read -r choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
        echo "${options[$((choice-1))]}"
    else
        echo "${options[0]}"
    fi
}

# ─── Main ──────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}════════════════════════════════════════${RESET}"
echo -e "${BOLD}  THE MATRIX — New project${RESET}"
echo -e "${BOLD}════════════════════════════════════════${RESET}"
echo ""

# Slug — accept from arg or ask
if [ -n "${1:-}" ]; then
    SLUG=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
    echo -e "  Slug: ${CYAN}$SLUG${RESET}"
else
    SLUG=$(ask_slug "Project slug:" "acme-corp")
fi
echo ""

# Check for existing project
if [ -d "$VAULT/projects/$SLUG" ]; then
    print_warn "Project '$SLUG' already exists at projects/$SLUG/"
    printf "  Overwrite? [y/N] "
    read -r overwrite
    [[ "$overwrite" =~ ^[Yy]$ ]] || exit 0
    echo ""
fi

NAME=$(ask_line "Project display name:" "Acme Corp" 3)
echo ""

DESCRIPTION=$(ask \
    "One sentence describing this project:" \
    "B2B SaaS platform for a logistics company with 500+ daily active users." \
    6)
echo ""

OPERATOR=$(ask_line "Your name (for changelogs):" "Alex Johnson" 2)
echo ""

LANGUAGE=$(ask_choice \
    "Client communication language:" \
    "en" "nl" "fr" "de" "es" "pt")
echo ""

WORKING_DIR=$(ask_line \
    "Where are the project files on this machine?" \
    "/Users/you/projects/$SLUG" \
    5)
echo ""

DEPLOYMENT=$(ask_choice \
    "Deployment method:" \
    "git" "sftp" "ci-cd" "manual")
echo ""

# Optional: staging and production URLs
echo -e "  ${BOLD}Staging URL (leave blank to skip):${RESET}"
printf "  > "
read -r STAGING_URL
echo ""

echo -e "  ${BOLD}Production URL (leave blank to skip):${RESET}"
printf "  > "
read -r PROD_URL
echo ""

# ─── Write files ───────────────────────────────────────────────────────────────

mkdir -p "$VAULT/projects/$SLUG"
cp "$TEMPLATE_DIR/RSI.yaml"     "$VAULT/projects/$SLUG/RSI.yaml"
cp "$TEMPLATE_DIR/CHANGELOG.md" "$VAULT/projects/$SLUG/CHANGELOG.md"

python3 - \
    "$VAULT/projects/$SLUG/RSI.yaml" \
    "$SLUG" "$NAME" "$DESCRIPTION" "$OPERATOR" \
    "$LANGUAGE" "$WORKING_DIR" "$DEPLOYMENT" \
    "$STAGING_URL" "$PROD_URL" <<'PYEOF'
import sys

rsi_file = sys.argv[1]
slug, name, desc, operator = sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
lang, wdir, deploy = sys.argv[6], sys.argv[7], sys.argv[8]
staging, production = sys.argv[9], sys.argv[10]

with open(rsi_file) as f:
    content = f.read()

replacements = {
    'slug: project-slug':
        f'slug: {slug}',
    'name: "Project Display Name"':
        f'name: "{name}"',
    'description: "One sentence about what this project is and who it\'s for."':
        f'description: "{desc}"',
    'operator: "Your name"':
        f'operator: "{operator}"',
    'client_language: en':
        f'client_language: {lang}',
    'working_directory: "/path/to/project/files"':
        f'working_directory: "{wdir}"',
    'deployment: git':
        f'deployment: {deploy}',
    'staging_url: ""':
        f'staging_url: "{staging}"',
    'production_url: ""':
        f'production_url: "{production}"',
}

for old, new in replacements.items():
    content = content.replace(old, new, 1)

with open(rsi_file, 'w') as f:
    f.write(content)
PYEOF

# Copy all template files and replace [Project Name] placeholder
for f in CHANGELOG.md INCIDENT_LOG.md ERROR_SIGNATURES.md; do
    cp "$TEMPLATE_DIR/$f" "$VAULT/projects/$SLUG/$f"
    sed -i.bak "s/\[Project Name\]/$NAME/g" "$VAULT/projects/$SLUG/$f" 2>/dev/null
    rm -f "$VAULT/projects/$SLUG/$f.bak"
done

# ─── Summary ───────────────────────────────────────────────────────────────────

echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
print_ok "Project '$SLUG' created"
echo ""
echo "  Files:"
echo "  projects/$SLUG/RSI.yaml           ← identity card (fill in critical_flows)"
echo "  projects/$SLUG/CHANGELOG.md       ← change log (grows with every ticket)"
echo "  projects/$SLUG/INCIDENT_LOG.md    ← incident history (grows with every ticket)"
echo "  projects/$SLUG/ERROR_SIGNATURES.md ← error patterns (grows with every ticket)"
echo ""
echo "  Fill in the critical_flows and do_not_touch sections in RSI.yaml"
echo "  before your first ticket on this project."
echo ""
echo "  Start a ticket:"
echo "  ./scripts/matrix.sh $SLUG"
echo ""
