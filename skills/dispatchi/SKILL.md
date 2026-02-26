---
name: dispatchi
description: Launch non-blocking interactive Claude Code tasks for slash-only plugins like ralph-loop. Use when a task needs interactive slash commands and completion callback routing.
---

Run `{baseDir}/scripts/run_dispatchi.sh` with user args.

## Contract

- Format: `/dispatchi <project> <task-name> <prompt...>`
- Workdir mapping: `${REPOS_ROOT:-$HOME/repos}/<project>`
- Defaults: `max-iterations=20`, `completion-promise=COMPLETE`
- Auto-exit: when completion promise appears, wrapper requests `/exit` and closes tmux session.

## Local config

- optional env file: `${OPENCLAW_DISPATCH_ENV:-~/.config/openclaw/dispatch.env}`
- supports OpenClaw `skills.entries.dispatchi.env` injection
- script is self-contained (does not require local wrapper binaries)

## Behavior

1. Validate args and return usage if incomplete.
2. Start interactive dispatch in background (non-blocking).
3. Return launch summary including run-id/log.
4. Use `/cancel <run-id>` to stop a running loop.
