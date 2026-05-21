#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT/VERSION"
CHANGELOG_FILE="$ROOT/CHANGELOG.md"

usage() {
  cat <<USAGE
Usage:
  ./scripts/version.sh [major|minor|patch] [--tag]

Examples:
  ./scripts/version.sh patch
  ./scripts/version.sh minor --tag
USAGE
}

[ $# -ge 1 ] || { usage; exit 1; }
BUMP="$1"
TAG_AFTER=0
if [ "${2:-}" = "--tag" ]; then
  TAG_AFTER=1
fi

CURR="$(tr -d '[:space:]' < "$VERSION_FILE")"
IFS='.' read -r MA MI PA <<< "$CURR"

case "$BUMP" in
  major) MA=$((MA+1)); MI=0; PA=0 ;;
  minor) MI=$((MI+1)); PA=0 ;;
  patch) PA=$((PA+1)) ;;
  *) usage; exit 1 ;;
esac

NEXT="$MA.$MI.$PA"
DATE="$(date +%Y-%m-%d)"

echo "$NEXT" > "$VERSION_FILE"

python3 - "$CHANGELOG_FILE" "$NEXT" "$DATE" <<'PY'
import sys, re
from pathlib import Path

path = Path(sys.argv[1])
ver  = sys.argv[2]
date = sys.argv[3]
text = path.read_text()

parts = text.split("## [Unreleased]\n", 1)
if len(parts) != 2:
    raise SystemExit("CHANGELOG missing '## [Unreleased]' section")

before, after = parts

# Find where the next version section starts
next_ver = re.search(r'^## \[', after, re.MULTILINE)
if next_ver:
    unreleased_body = after[:next_ver.start()]
    rest            = after[next_ver.start():]
else:
    unreleased_body = after
    rest            = ''

unreleased_body = unreleased_body.strip()

if unreleased_body:
    # [Unreleased] has content — move it to the new version section
    new_text = (
        before +
        "## [Unreleased]\n\n" +
        f"## [{ver}] - {date}\n\n" +
        unreleased_body + "\n\n" +
        rest
    )
else:
    # [Unreleased] is empty — add an empty version header, no placeholder
    new_text = (
        before +
        "## [Unreleased]\n\n" +
        f"## [{ver}] - {date}\n\n" +
        rest
    )

path.write_text(new_text)
PY

echo "Version bumped: $CURR -> $NEXT"

echo "Updated: VERSION, CHANGELOG.md"

if [ "$TAG_AFTER" -eq 1 ]; then
  git -C "$ROOT" add VERSION CHANGELOG.md
  git -C "$ROOT" commit -m "chore(release): v$NEXT"
  git -C "$ROOT" tag "v$NEXT"
  echo "Created commit + tag: v$NEXT"
fi
