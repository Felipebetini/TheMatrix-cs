#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Matrix — PHPCS + WordPress Coding Standards setup           ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Installs PHP_CodeSniffer, WordPress Coding Standards, PHP Mess
# Detector (phpmd), and PHP Copy/Paste Detector (phpcpd).
#
# Usage:
#   ./scripts/setup-phpcs.sh          # interactive — shows output
#   ./scripts/setup-phpcs.sh --auto   # silent — only runs if not installed

set -euo pipefail

AUTO=0
[ "${1:-}" = "--auto" ] && AUTO=1

# ── Detect actual Composer home (varies: ~/.composer vs ~/.config/composer) ──
if command -v composer &>/dev/null; then
    COMPOSER_HOME=$(composer global config home 2>/dev/null || echo "$HOME/.composer")
else
    COMPOSER_HOME="$HOME/.composer"
fi
COMPOSER_BIN="$COMPOSER_HOME/vendor/bin"
PHPCS="$COMPOSER_BIN/phpcs"
PHPMD="$COMPOSER_BIN/phpmd"
PHPCPD="$COMPOSER_BIN/phpcpd"

# ── Already installed? ─────────────────────────────────────────
if command -v phpcs &>/dev/null || [ -x "$PHPCS" ]; then
    if [ $AUTO -eq 1 ]; then
        exit 0  # already installed, nothing to do
    fi
    echo "  PHPCS already installed. Updating..."
fi

quiet() { [ $AUTO -eq 1 ] && "$@" &>/dev/null || "$@"; }
say()   { [ $AUTO -eq 0 ] && echo "  $*" || true; }

[ $AUTO -eq 0 ] && echo "" && echo "  Installing PHP code quality tools..." && echo "  ─────────────────────────────────────"

# ── Check prerequisites ───────────────────────────────────────
if ! command -v php &>/dev/null; then
    say "✗  PHP not found. Install: brew install php"
    exit 1
fi

if ! command -v composer &>/dev/null; then
    say "✗  Composer not found. Install: https://getcomposer.org"
    exit 1
fi

# ── Allow the PHPCS installer plugin (required by Composer ≥2.2) ────────────
composer global config allow-plugins.dealerdirect/phpcodesniffer-composer-installer true \
    --no-interaction 2>/dev/null || true

# ── Install all tools via Composer global ─────────────────────
quiet composer global require --no-interaction \
    squizlabs/php_codesniffer \
    wp-coding-standards/wpcs \
    phpcompatibility/php-compatibility \
    phpcompatibility/phpcompatibility-wp \
    phpmd/phpmd \
    sebastian/phpcpd

# ── Add Composer bin to PATH if needed ────────────────────────
if [[ ":$PATH:" != *":$COMPOSER_BIN:"* ]]; then
    export PATH="$COMPOSER_BIN:$PATH"
    [ $AUTO -eq 0 ] && echo "" && \
        echo "  ⚠  Add to ~/.zshrc: export PATH=\"$COMPOSER_BIN:\$PATH\""
fi

# ── Register WordPress + Compatibility standards ───────────────
WPCS_PATH="$COMPOSER_HOME/vendor/wp-coding-standards/wpcs"
COMPAT_PATH="$COMPOSER_HOME/vendor/phpcompatibility/phpcompatibility-wp/PHPCompatibilityWP"

"${PHPCS}" --config-set installed_paths "$WPCS_PATH,$COMPAT_PATH" 2>/dev/null || true

if [ $AUTO -eq 0 ]; then
    echo ""
    echo "  Installed standards:"
    "${PHPCS}" -i 2>/dev/null | tr ',' '\n' | grep -E "WordPress|PHP" | \
        while IFS= read -r s; do echo "    ✓ $s"; done
    echo ""
    echo "  Tools installed:"
    echo "    ✓ phpcs  (PHP_CodeSniffer + WordPress Coding Standards)"
    echo "    ✓ phpmd  (PHP Mess Detector — complexity, duplication, unused code)"
    echo "    ✓ phpcpd (PHP Copy/Paste Detector)"
    echo ""
    echo "  ✓ Setup complete. pr-check.sh and /wp-lint will now use all tools."
    echo ""
fi
