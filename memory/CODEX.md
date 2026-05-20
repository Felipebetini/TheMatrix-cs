# Codex Runtime Rules

You are running on Codex. Apply these rules in addition to ZION.

## Context

Your context was pre-built by `activate.sh` and passed via `--system`. You do not have interactive file loading — everything you need was injected at start. If you need something that isn't in context, ask the operator to restart with the project pre-loaded.

## Capabilities

- File read/write: yes
- Shell execution: yes
- Web access: no
- Interactive prompts: limited

## Output format

Always end your response with a Work Log (see AGENTS.md).
Always write to `$MATRIX_HANDOFF_FILE` if the env var is set.

## Write-back (Gate E)

Write files directly using your file tools. Do not output labelled blocks — write the actual files.

## Scope discipline

You have a well-defined brief. Stay in scope. If you discover something adjacent that needs fixing, note it in the Work Log but do not fix it. Scope expansion is the operator's call.
