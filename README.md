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

## Manual test commands (verified)

```text
/dispatch dispatch-smoke dispatch-basic 创建文件 DISPATCH_OK.txt 内容为 ok，然后列出目录并结束。不要启动任何服务器，不要等待输入。
```

```text
/dispatchi ralph-smoke dispatchi-basic 测试任务：写10种排序算法，TDD验证排序输出，输出 COMPLETE 然后停止。
```

```text
/cancel <run-id>
```

## Release workflow (adopted)

1. Update skill code in this repo.
2. Run local tests in OpenClaw workspace.
3. Commit to this repo.
4. Publish via GitHub Action to ClawHub.
5. Locally remove skill code (keep `dispatch.env.local`).
6. Re-install from ClawHub and run one more verification.

## GitHub Action publish

Workflow file:

- `.github/workflows/publish-clawhub.yml`

Required secret:

- `CLAWHUB_TOKEN`

Publishing eligibility note:

- ClawHub may require a minimum GitHub account age before publishing (current error observed: 14 days).

Optional repo variables:

- `CLAWHUB_SITE`
- `CLAWHUB_REGISTRY`

Trigger manually with inputs:

- `version` (required)
- `slug_prefix` (default `miniade-`)
- `tags` (default `latest`)
- `changelog`
- `dry_run`

## Notes

- These are **custom skill slash commands**, not OpenClaw built-in system commands.
- `/dispatch` enforces timeout via `DISPATCH_TIMEOUT_SEC` (default 7200s).
- `/dispatch` does **not** force `--teammate-mode auto` by default (can be enabled via env).
- `/dispatchi` defaults to `--max-iterations 20` and `--completion-promise "COMPLETE"`, then auto-exits session on completion.
- `/cancel` accepts `<run-id>` or `<project>/<run-id>` and performs hard-cancel.
