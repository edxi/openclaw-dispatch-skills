# openclaw-dispatch-skills

Portable OpenClaw slash skills for Claude Code dispatch workflows (self-contained, no dependency on local wrapper scripts):

- `/dispatch <project> <task-name> <prompt...>` (headless async)
- `/dispatchi <project> <task-name> <prompt...>` (interactive, for slash-only plugins like ralph-loop)
- `/cancel <run-id>` (cancel a running interactive loop)

## Why this repo

These skills are designed for ClawHub publishing and cross-machine use.
They avoid hardcoding a single local path and support local overrides via:

1. environment variables
2. optional env file (`<workspace>/skills/dispatch.env.local`)  
   (legacy fallback: `~/.config/openclaw/dispatch.env`)
3. OpenClaw `skills.entries.<skill>.env` injection

## Skill layout

- `skills/dispatch`
- `skills/dispatchi`
- `skills/cancel`
- `skills/dispatch.env.example`

## Local override file

Copy example and edit (recommended in skills root):

```bash
cp skills/dispatch.env.example /home/miniade/.openclaw/workspace-coder/skills/dispatch.env.local
```

(or use your own workspace path)

## OpenClaw config-based env injection (recommended)

In `~/.openclaw/openclaw.json`:

```json5
{
  skills: {
    entries: {
      dispatch: {
        env: {
          REPOS_ROOT: "/home/miniade/repos",
          LAUNCH_LOG_DIR: "/home/miniade/clawd/data/dispatch-launch"
        }
      },
      dispatchi: {
        env: {
          REPOS_ROOT: "/home/miniade/repos",
          DISPATCHI_MAX_ITERATIONS: "20",
          DISPATCHI_COMPLETION_PROMISE: "COMPLETE"
        }
      },
      cancel: {
        env: {
          RESULTS_BASE: "/home/miniade/clawd/data/claude-code-results"
        }
      }
    }
  }
}
```

## Install into workspace skills

OpenClaw loads workspace skills from `<workspace>/skills` and picks up changes on the next session.

For this coder agent workspace:

```bash
./scripts/sync-to-workspace.sh /home/miniade/.openclaw/workspace-coder/skills
```

## Package `.skill` files

```bash
./scripts/package-all.sh
```

Output to `./dist`.

## Notes

- These are **custom skill slash commands**, not OpenClaw built-in system commands.
- `/dispatch` enforces timeout via `DISPATCH_TIMEOUT_SEC` (default 7200s).
- `/dispatch` does **not** force `--teammate-mode auto` by default (can be enabled via env).
- `/dispatchi` defaults to `--max-iterations 20` and `--completion-promise "COMPLETE"`, then auto-exits session on completion.
- `/cancel` accepts `<run-id>` or `<project>/<run-id>` and performs hard-cancel.
