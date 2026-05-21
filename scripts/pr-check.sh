#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  The Matrix — Pre-PR Code Quality Check                      ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Run before creating any PR or pushing to production.
# Seraph requires this to PASS before Gate B.
#
# Usage:
#   ./scripts/pr-check.sh                     # git diff HEAD in current dir
#   ./scripts/pr-check.sh --dir /path/to/dir  # all PHP/JS/CSS in directory
#   ./scripts/pr-check.sh file.php file2.js   # specific files
#
# Exit codes:
#   0 = PASS (may have warnings)
#   1 = BLOCK (Tier 1 issues found — do not push)

BLOCKS=0
WARNINGS=0
FILES=()
PHP_FILES=()

# ── Colour helpers ─────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
block() { echo -e "  ${RED}✗ BLOCK${NC}  $1"; BLOCKS=$((BLOCKS+1)); }
warn()  { echo -e "  ${YELLOW}⚠ WARN${NC}   $1"; WARNINGS=$((WARNINGS+1)); }
pass()  { echo -e "  ${GREEN}✓${NC}        $1"; }

echo ""
echo "  PR Quality Check"
echo "  ════════════════"

# ── Collect files ──────────────────────────────────────────────
if [ "$1" = "--dir" ] && [ -n "$2" ]; then
    while IFS= read -r f; do FILES+=("$f"); done < <(
        find "$2" -type f \( -name "*.php" -o -name "*.js" -o -name "*.css" -o -name "*.scss" \) \
        ! -path "*/node_modules/*" ! -path "*/vendor/*" ! -path "*/dist/*" ! -path "*/.git/*"
    )
    echo "  Mode: directory scan ($2)"
elif [ $# -gt 0 ] && [ "$1" != "--dir" ]; then
    FILES=("$@")
    echo "  Mode: specified files"
elif git rev-parse --git-dir &>/dev/null 2>&1; then
    while IFS= read -r f; do
        [ -f "$f" ] && FILES+=("$f")
    done < <(git diff HEAD --name-only --diff-filter=ACM 2>/dev/null)
    [ ${#FILES[@]} -eq 0 ] && while IFS= read -r f; do
        [ -f "$f" ] && FILES+=("$f")
    done < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)
    echo "  Mode: git diff HEAD (${#FILES[@]} changed files)"
else
    echo "  No files specified and not in a git repo. Pass --dir /path or list files."
    exit 0
fi

if [ ${#FILES[@]} -eq 0 ]; then
    echo "  No files to check."
    exit 0
fi

echo ""

# ── Check each file ────────────────────────────────────────────
for FILE in "${FILES[@]}"; do
    EXT="${FILE##*.}"
    NAME=$(basename "$FILE")

    # ── Merge conflict markers (all files) ──────────────────────
    if grep -qn "^<<<<<<< \|^>>>>>>> \|^=======$" "$FILE" 2>/dev/null; then
        block "$NAME — merge conflict markers found"
    fi

    # ── PHP checks ───────────────────────────────────────────────
    if [ "$EXT" = "php" ]; then
        PHP_FILES+=("$FILE")

        # Syntax check
        syntax=$(php -l "$FILE" 2>&1)
        if ! echo "$syntax" | grep -q "No syntax errors"; then
            block "$NAME — PHP syntax error: $(echo "$syntax" | grep -v '^$' | head -2 | tr '\n' ' ')"
        fi

        # Debug code (Tier 1 — should never reach production)
        while IFS= read -r match; do
            [ -n "$match" ] && block "$NAME:$match — debug code (remove before pushing)"
        done < <(grep -n "var_dump\s*(\|print_r\s*(\|var_export\s*(" "$FILE" 2>/dev/null | \
            grep -v "^\s*//" | grep -v "^\s*\*" | \
            sed 's/^\([0-9]*\):.*/\1/')

        # die() / exit() left in — might be intentional but flag it
        while IFS= read -r match; do
            [ -n "$match" ] && block "$NAME:$match — die() or exit() found (review — is this intentional?)"
        done < <(grep -n "^\s*die\s*(\|^\s*exit\s*(" "$FILE" 2>/dev/null | \
            grep -v "^\s*//" | sed 's/^\([0-9]*\):.*/\1/')

        # Hardcoded credentials
        if grep -qiE "(password|passwd|secret|api_key)\s*=\s*['\"][^'\"]{4,}" "$FILE" 2>/dev/null; then
            block "$NAME — possible hardcoded credential (password/secret/api_key with value)"
        fi

        # TODO/FIXME in code (warn — unfinished work)
        todo_count=$(grep -c "TODO\|FIXME\|HACK\|XXX" "$FILE" 2>/dev/null || echo 0)
        [ "$todo_count" -gt 0 ] && warn "$NAME — $todo_count TODO/FIXME marker(s) — review before pushing"

        # WordPress: direct superglobal without sanitization on same line
        while IFS= read -r line; do
            [ -n "$line" ] && warn "$NAME:$(echo "$line" | cut -d: -f1) — \$_GET/\$_POST/\$_REQUEST used — verify sanitization"
        done < <(grep -n '\$_GET\[\|\$_POST\[\|\$_REQUEST\[' "$FILE" 2>/dev/null | \
            grep -v "sanitize_\|intval\|absint\|esc_\|wp_unslash\|isset\|empty\|//\|\*" | head -3)

        # WordPress: echo without escaping
        while IFS= read -r line; do
            [ -n "$line" ] && warn "$NAME:$(echo "$line" | cut -d: -f1) — echo \$variable without esc_ — verify escaping"
        done < <(grep -n "echo\s*\$[a-zA-Z_]" "$FILE" 2>/dev/null | \
            grep -v "esc_\|wp_kses\|absint\|intval\|//\|\*" | head -3)

        # ── PHPCS + WordPress Coding Standards (if installed) ────────
        PHPCS_BIN=""
        for p in phpcs "$HOME/.composer/vendor/bin/phpcs" "$HOME/.config/composer/vendor/bin/phpcs"; do
            command -v "$p" &>/dev/null && { PHPCS_BIN="$p"; break; }
        done

        if [ -n "$PHPCS_BIN" ] && "$PHPCS_BIN" -i 2>/dev/null | grep -q "WordPress"; then
            # Run PHPCS — errors are BLOCK, warnings surface top 3
            phpcs_out=$("$PHPCS_BIN" \
                --standard=WordPress \
                --severity=1 \
                --error-severity=5 \
                --warning-severity=6 \
                --report=json \
                --no-colors \
                "$FILE" 2>/dev/null || true)

            err_count=$(echo "$phpcs_out" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print(sum(f.get('errors',0) for f in d.get('files',{}).values()))
except: print(0)" 2>/dev/null)

            warn_count=$(echo "$phpcs_out" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print(sum(f.get('warnings',0) for f in d.get('files',{}).values()))
except: print(0)" 2>/dev/null)

            if [ "${err_count:-0}" -gt 0 ]; then
                # Surface the first 3 errors
                error_lines=$(echo "$phpcs_out" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    msgs=[]
    for msgs_list in d.get('files',{}).values():
        for m in msgs_list.get('messages',[]):
            if m.get('type')=='ERROR':
                msgs.append(f\"  {m.get('line')}:{m.get('column')} {m.get('message')}\")
    print('\n'.join(msgs[:3]))
except: pass" 2>/dev/null)
                block "$NAME — PHPCS WordPress: $err_count error(s)"
                [ -n "$error_lines" ] && echo "$error_lines"
            fi

            if [ "${warn_count:-0}" -gt 0 ]; then
                warn "$NAME — PHPCS WordPress: $warn_count warning(s) (run phpcs --standard=WordPress $FILE for details)"
            fi

            [ "${err_count:-0}" -eq 0 ] && [ "${warn_count:-0}" -eq 0 ] && \
                pass "$NAME (PHPCS WordPress clean)"
        fi

        # ── phpmd — cyclomatic complexity + unused code ──────────────
        PHPMD_BIN=""
        for p in phpmd "$HOME/.composer/vendor/bin/phpmd" "$HOME/.config/composer/vendor/bin/phpmd"; do
            command -v "$p" &>/dev/null && { PHPMD_BIN="$p"; break; }
        done

        if [ -n "$PHPMD_BIN" ]; then
            phpmd_out=$("$PHPMD_BIN" "$FILE" text \
                codesize,design,unusedcode \
                --minimum-priority 2 2>/dev/null || true)

            if [ -n "$phpmd_out" ]; then
                # Errors containing "complexity" or "coupling" → BLOCK; rest → WARN
                while IFS= read -r line; do
                    [ -z "$line" ] && continue
                    if echo "$line" | grep -qiE "complexity|coupling|too many (methods|fields|parameters)"; then
                        block "$NAME — phpmd: $line"
                    else
                        warn "$NAME — phpmd: $line"
                    fi
                done <<< "$(echo "$phpmd_out" | grep -v "^$FILE" | head -5)"
            fi
        fi

        pass "$NAME (PHP)"
    fi

    # ── JavaScript checks ────────────────────────────────────────
    if [ "$EXT" = "js" ] || [ "$EXT" = "jsx" ] || [ "$EXT" = "ts" ] || [ "$EXT" = "tsx" ]; then

        # Debug code
        while IFS= read -r match; do
            [ -n "$match" ] && block "$NAME:$match — console.log found (remove before pushing)"
        done < <(grep -n "console\.log\s*(" "$FILE" 2>/dev/null | \
            grep -v "^\s*//" | sed 's/^\([0-9]*\):.*/\1/' | head -5)

        if grep -qn "debugger;" "$FILE" 2>/dev/null; then
            block "$NAME — debugger; statement found"
        fi

        # alert() — usually debug
        if grep -qn "^\s*alert\s*(" "$FILE" 2>/dev/null; then
            warn "$NAME — alert() found — is this intentional?"
        fi

        todo_count=$(grep -c "TODO\|FIXME\|HACK" "$FILE" 2>/dev/null || echo 0)
        [ "$todo_count" -gt 0 ] && warn "$NAME — $todo_count TODO/FIXME marker(s)"

        pass "$NAME (JS)"
    fi

    # ── CSS/SCSS checks ──────────────────────────────────────────
    if [ "$EXT" = "css" ] || [ "$EXT" = "scss" ]; then
        # Leftover debug outlines
        if grep -qn "outline:\s*[0-9]\+px.*red\|border:\s*[0-9]\+px.*red" "$FILE" 2>/dev/null; then
            warn "$NAME — red debug border/outline found — intentional?"
        fi
        pass "$NAME (CSS)"
    fi

done

# ── phpcpd — copy/paste detection (batch, all PHP files) ───────
if [ ${#PHP_FILES[@]} -gt 0 ]; then
    PHPCPD_BIN=""
    for p in phpcpd "$HOME/.composer/vendor/bin/phpcpd" "$HOME/.config/composer/vendor/bin/phpcpd"; do
        command -v "$p" &>/dev/null && { PHPCPD_BIN="$p"; break; }
    done

    if [ -n "$PHPCPD_BIN" ]; then
        cpd_out=$("$PHPCPD_BIN" --min-lines 6 --min-tokens 50 "${PHP_FILES[@]}" 2>/dev/null || true)
        if echo "$cpd_out" | grep -q "Found"; then
            dup_count=$(echo "$cpd_out" | grep -c "^  -" || echo 1)
            warn "phpcpd — $dup_count duplicate block(s) found (min 6 lines / 50 tokens)"
            echo "$cpd_out" | grep -E "Found|^\s+-" | head -8 | \
                while IFS= read -r l; do echo "           $l"; done
        fi
    fi
fi

# ── Summary ────────────────────────────────────────────────────
echo ""
echo "  ════════════════════"
if [ $BLOCKS -gt 0 ]; then
    echo -e "  ${RED}✗ BLOCK — $BLOCKS blocking issue(s) found. Fix before pushing.${NC}"
    [ $WARNINGS -gt 0 ] && echo -e "  ${YELLOW}  $WARNINGS warning(s) also present.${NC}"
    echo ""
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "  ${YELLOW}⚠ PASS WITH WARNINGS — $WARNINGS item(s) to review.${NC}"
    echo "  Safe to push, but review warnings first."
else
    echo -e "  ${GREEN}✓ PASS — No issues found.${NC}"
fi
echo ""
exit 0
