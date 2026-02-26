# openclaw-dispatch-skills

Portable OpenClaw slash skills for Claude Code dispatch workflows:

- `/dispatch <project> <task-name> <prompt...>` (headless async)
- `/dispatchi <project> <task-name> <prompt...>` (interactive, for slash-only plugins like ralph-loop)
- `/cancel <run-id>` (cancel a running interactive loop)

## Security posture (low-VT profile)

This repo ships self-contained skill scripts and avoids runtime execution of external repo scripts.

- No runtime remote downloads.
- No `source` of env files; only allowlisted `KEY=VALUE` parsing.
- Callback/network routing is **off by default** (`ENABLE_CALLBACK=0`).
- Headless runs use timeout guard (`DISPATCH_TIMEOUT_SEC`, default 7200s).
- `dispatchi` validates tmux session startup and auto-exits on completion.

## Skill layout

- `skills/dispatch`
- `skills/dispatchi`
- `skills/cancel`
- `skills/dispatch.env.example`

## Local config

Default config path used by scripts:

- `<workspace>/skills/dispatch.env.local`

Create from template:

```bash
cp skills/dispatch.env.example /home/miniade/.openclaw/workspace-coder/skills/dispatch.env.local
```

## Install into workspace skills

```bash
./scripts/sync-to-workspace.sh /home/miniade/.openclaw/workspace-coder/skills
```

OpenClaw loads workspace skills from `<workspace>/skills` on next session.

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

- ClawHub may require a minimum GitHub account age before publishing (observed: 14 days).

Trigger manually with inputs:

- `version` (required)
- `slug_prefix` (default `miniade-`)
- `tags` (default `latest`)
- `changelog`
- `dry_run`
