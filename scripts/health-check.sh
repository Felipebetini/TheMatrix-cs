#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  The Matrix — Vault Health Check                             ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:
#   ./scripts/health-check.sh          # full check
#   ./scripts/health-check.sh --quick  # scripts only (fast)
#
# Checks:
#   1. Shell script syntax (bash -n)
#   2. Python script syntax (py_compile)
#   3. Dead wikilinks (obsidian unresolved)
#   4. Stale agent name references (renamed agents)
#   5. SKILLS.md entries vs actual skill files
#   6. Orphaned vault files (meaningful .md files not linked)
#   7. Codex skill symlinks (vault → global)
#   8. Runtime parity (CLAUDE.md / AGENTS.md / GEMINI.md vs RUNTIME_CONTRACT.md)

VAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0
WARNINGS=0

pass()    { echo "  ✓  $1"; }
warn()    { echo "  ⚠️  $1"; WARNINGS=$((WARNINGS+1)); }
fail()    { echo "  ✗  $1"; ERRORS=$((ERRORS+1)); }
section() { echo ""; echo "── $1 ──────────────────────────────────"; }

echo ""
echo "  Matrix Health Check"
echo "  ════════════════════"

# ── 1. Shell script syntax ─────────────────────────────────────
section "Shell scripts"
for f in "$VAULT"/scripts/*.sh; do
    name=$(basename "$f")
    if bash -n "$f" 2>/dev/null; then
        pass "$name"
    else
        fail "$name — syntax error: $(bash -n "$f" 2>&1)"
    fi
done

# ── 2. Python script syntax ────────────────────────────────────
section "Python scripts"
for f in "$VAULT"/scripts/*.py; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    if python3 -m py_compile "$f" 2>/dev/null; then
        pass "$name"
    else
        fail "$name — $(python3 -m py_compile "$f" 2>&1)"
    fi
done

if [ "${1:-}" = "--quick" ]; then
    echo ""
    echo "  Quick check complete — $ERRORS error(s), $WARNINGS warning(s)"
    exit $ERRORS
fi

# ── 3. Stale agent name references ────────────────────────────
section "Stale agent names (renamed agents)"
STALE_NAMES=("REBEL" "ESTIMATOR" "agents/REBEL.md" "agents/ESTIMATOR.md")
STALE_FOUND=0
for name in "${STALE_NAMES[@]}"; do
    matches=$(grep -rl "$name" "$VAULT" \
        --include="*.md" --include="*.yaml" --include="*.sh" --include="*.py" --include="*.json" \
        2>/dev/null | grep -v ".git" | grep -v "health-check.sh")
    if [ -n "$matches" ]; then
        fail "Found '$name' in: $(echo "$matches" | tr '\n' ' ')"
        STALE_FOUND=1
    fi
done
[ $STALE_FOUND -eq 0 ] && pass "No stale agent name references"

# ── 4. SKILLS.md vs actual skill files ────────────────────────
section "Skill registry (SKILLS.md vs .agents/skills/)"
# Check that every skill folder has a SKILL.md
for skill_dir in "$VAULT"/.agents/skills/*/; do
    skill_name=$(basename "$skill_dir")
    if [ ! -f "$skill_dir/SKILL.md" ]; then
        fail "Skill '$skill_name' has no SKILL.md"
    else
        pass "Skill: $skill_name"
    fi
done

# Check that every custom Matrix skill in SKILLS.md has a corresponding folder
# Skip Claude Code built-in skills (they live in Claude Code, not .agents/skills/)
CLAUDE_BUILTIN="security-review simplify review init fewer-permission-prompts update-config keybindings-help loop schedule claude-api ultrareview"
while IFS= read -r line; do
    skill=$(echo "$line" | grep -o '`/[a-z][a-z0-9-]*`' | head -1 | tr -d '`/')
    [ -z "$skill" ] && continue
    # Skip if it's a Claude Code built-in
    is_builtin=0
    for builtin in $CLAUDE_BUILTIN; do
        [ "$skill" = "$builtin" ] && is_builtin=1 && break
    done
    [ $is_builtin -eq 1 ] && continue
    # Skip template placeholders (literal example text in SKILLS.md)
    [ "$skill" = "skill-name" ] && continue
    if [ ! -d "$VAULT/.agents/skills/$skill" ]; then
        warn "SKILLS.md references '/$skill' but .agents/skills/$skill/ not found"
    fi
done < "$VAULT/memory/SKILLS.md"

# ── 5. Codex skill symlinks (global) ──────────────────────────
section "Codex skill symlinks (~/.agents/skills/)"
for skill_dir in "$VAULT"/.agents/skills/*/; do
    skill_name=$(basename "$skill_dir")
    global="$HOME/.agents/skills/$skill_name"
    if [ -L "$global" ] && [ -d "$global" ]; then
        pass "Symlink: $skill_name"
    elif [ -d "$global" ] && [ ! -L "$global" ]; then
        warn "$skill_name exists globally but is a copy, not a symlink — may diverge"
    else
        fail "Missing global symlink for '$skill_name' — run: ln -sf '$skill_dir' '$global'"
    fi
done

# ── 6. Dead wikilinks ─────────────────────────────────────────
section "Dead wikilinks (obsidian unresolved)"
# Known acceptable dead links — per-project template references or .yaml files
KNOWN_DEAD="ENVIRONMENTS HOTSPOTS PROJECT STACK RSI INCIDENT_LOG INC-20260508-001 INC-2026 doc/ logo.jpg src/Monolog CODE_OF_CONDUCT .github/"
if command -v obsidian &>/dev/null; then
    unresolved=$(obsidian unresolved vault="$(basename "$VAULT")" 2>/dev/null)
    real_dead=""
    while IFS= read -r link; do
        [ -z "$link" ] && continue
        skip=0
        for known in $KNOWN_DEAD; do
            [[ "$link" == *"$known"* ]] && skip=1 && break
        done
        [ $skip -eq 0 ] && real_dead="$real_dead\n$link"
    done <<< "$unresolved"
    if [ -z "$(echo -e "$real_dead" | tr -d '\n')" ]; then
        pass "No unexpected dead wikilinks"
        pass "Known template/per-project links: $KNOWN_DEAD (expected)"
    else
        echo -e "$real_dead" | while IFS= read -r line; do
            [ -n "$line" ] && warn "Dead link: $line"
        done
    fi
else
    warn "Obsidian CLI not available — skipping wikilink check (open Obsidian first)"
fi

# ── 7. Orphaned meaningful .md files ──────────────────────────
section "Orphaned vault files"
if command -v obsidian &>/dev/null; then
    orphans=$(obsidian orphans vault="$(basename "$VAULT")" 2>/dev/null | \
        grep "\.md$" | \
        grep -v "^projects/" | \
        grep -v "_template" | \
        grep -v "^tickets/INC" | \
        grep -v "^scripts/" | \
        grep -v "^worktrees/" | \
        grep -v "Welcome\|RSI\.md")
    if [ -z "$orphans" ]; then
        pass "No meaningful orphans"
    else
        echo "$orphans" | while IFS= read -r line; do
            warn "Orphan: $line"
        done
    fi
else
    warn "Obsidian CLI not available — skipping orphan check"
fi

# ── 8. Agent files have required sections ─────────────────────
section "Agent file completeness"
REQUIRED=("## Role" "## Personality" "## Rules")
for agent_file in "$VAULT"/agents/*.md; do
    agent=$(basename "$agent_file" .md)
    missing=()
    for section_name in "${REQUIRED[@]}"; do
        if ! grep -q "$section_name" "$agent_file" 2>/dev/null; then
            missing+=("$section_name")
        fi
    done
    if [ ${#missing[@]} -eq 0 ]; then
        pass "Agent: $agent"
    else
        warn "Agent $agent missing: ${missing[*]}"
    fi
done

# ── 8. Runtime parity ─────────────────────────────────────────
section "Runtime parity (CLAUDE / AGENTS / GEMINI vs CONTRACT)"
parity_output=$("$VAULT/scripts/runtime-parity-check.sh" 2>/dev/null)
parity_exit=$?
if [ $parity_exit -eq 0 ]; then
    pass "All runtime adapters match RUNTIME_CONTRACT.md"
else
    # Extract failing lines from parity output and surface them
    echo "$parity_output" | grep "^  ✗" | while IFS= read -r line; do
        fail "${line#*✗  }"
    done
    ERRORS=$((ERRORS+1))
fi

# ── Summary ────────────────────────────────────────────────────
echo ""
echo "  ════════════════════"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "  ✓ All checks passed"
elif [ $ERRORS -eq 0 ]; then
    echo "  ⚠️  $WARNINGS warning(s) — no blocking errors"
else
    echo "  ✗ $ERRORS error(s), $WARNINGS warning(s)"
fi
echo ""

exit $ERRORS
