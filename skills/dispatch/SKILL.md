---
name: dispatch
description: Launch non-blocking Claude Code headless tasks from slash command dispatch. Use when user requests async coding jobs with completion callback routing and does not require slash-only Claude plugins.
---

Run `{baseDir}/scripts/run_dispatch.sh` with user args.

## Contract

- Format: `/dispatch <project> <task-name> <prompt...>`
- Workdir mapping: `${REPOS_ROOT:-$HOME/repos}/<project>`
- Agent Teams policy: on-demand (enabled only if prompt contains Agent Team signals)
- Safety: headless runs enforce timeout via `DISPATCH_TIMEOUT_SEC` (default 7200s)

## Local config

- optional env file: `${OPENCLAW_DISPATCH_ENV:-<workspace>/skills/dispatch.env.local}` (legacy fallback: `~/.config/openclaw/dispatch.env`)
- supports OpenClaw `skills.entries.dispatch.env` injection
- script is self-contained (does not require local wrapper binaries)

## Behavior

1. Validate args and return usage if incomplete.
2. Start task in background (non-blocking).
3. Return one-line launch summary with run-id and log path.
4. Do not run extra validation unless requested.
