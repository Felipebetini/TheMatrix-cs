#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$ROOT/.git/hooks"
HOOK="$HOOKS_DIR/pre-commit"

if [ ! -d "$HOOKS_DIR" ]; then
  echo "Not a git repository: $ROOT"
  exit 1
fi

cat > "$HOOK" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo ""
echo "Running Matrix pre-commit quality gates..."

"$ROOT/scripts/pr-check.sh"
"$ROOT/scripts/health-check.sh" --quick

echo "Pre-commit gates passed."
EOF

chmod +x "$HOOK"

echo "Installed pre-commit hook at $HOOK"
echo "Hook runs: scripts/pr-check.sh + scripts/health-check.sh --quick"
