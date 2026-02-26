#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${OPENCLAW_DISPATCH_ENV:-$HOME/.config/openclaw/dispatch.env}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

REPOS_ROOT="${REPOS_ROOT:-/home/miniade/repos}"
RESULTS_BASE="${RESULTS_BASE:-/home/miniade/clawd/data/claude-code-results}"
LAUNCH_LOG_DIR="${LAUNCH_LOG_DIR:-/home/miniade/clawd/data/dispatch-launch}"
DISPATCH_REPO="${DISPATCH_REPO:-/home/miniade/repos/claude-code-dispatch}"
DISPATCH_PERMISSION_MODE="${DISPATCH_PERMISSION_MODE:-bypassPermissions}"
DISPATCH_TEAMMATE_MODE="${DISPATCH_TEAMMATE_MODE:-}"
DISPATCH_TIMEOUT_SEC="${DISPATCH_TIMEOUT_SEC:-7200}"
CODEHOOK_GROUP_DEFAULT="${CODEHOOK_GROUP_DEFAULT:--1002547895616}"
TELEGRAM_GROUP="${TELEGRAM_GROUP:-$CODEHOOK_GROUP_DEFAULT}"

OPENCLAW_BIN="${OPENCLAW_BIN:-$(command -v openclaw 2>/dev/null || echo "$HOME/.npm-global/bin/openclaw")}"
OPENCLAW_CONFIG="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
OPENCLAW_TELEGRAM_ACCOUNT="${OPENCLAW_TELEGRAM_ACCOUNT:-coder}"
CLAUDE_CODE_BIN="${CLAUDE_CODE_BIN:-/home/miniade/.local/bin/claude}"

if [[ $# -lt 3 ]]; then
  echo "Usage: /dispatch <project> <task-name> <prompt...>" >&2
  exit 2
fi

DISPATCH_SH="$DISPATCH_REPO/scripts/dispatch.sh"
if [[ ! -f "$DISPATCH_SH" ]]; then
  echo "Error: dispatch script not found: $DISPATCH_SH" >&2
  exit 2
fi

PROJECT="$1"
TASK_NAME="$2"
shift 2
PROMPT="$*"

WORKDIR="${REPOS_ROOT}/${PROJECT}"
mkdir -p "$WORKDIR" "$LAUNCH_LOG_DIR"

NEED_TEAMS=0
if echo "$PROMPT" | grep -Eiq '(Agent Team|Agent Teams|多智能体|并行|testing agent)'; then
  NEED_TEAMS=1
fi

RUN_ID="$(date -u +%Y%m%d-%H%M%S)-${PROJECT}-${TASK_NAME}"
RESULT_DIR="$RESULTS_BASE/$PROJECT/$RUN_ID"
RUN_LOG="$LAUNCH_LOG_DIR/${RUN_ID}.log"
mkdir -p "$RESULT_DIR"

export RESULT_DIR DISPATCH_TIMEOUT_SEC OPENCLAW_BIN OPENCLAW_CONFIG OPENCLAW_TELEGRAM_ACCOUNT CLAUDE_CODE_BIN

CMD=(bash "$DISPATCH_SH"
  -n "$TASK_NAME"
  -w "$WORKDIR"
  -g "$TELEGRAM_GROUP"
  -p "$PROMPT"
  --permission-mode "$DISPATCH_PERMISSION_MODE"
)

if [[ "$NEED_TEAMS" -eq 1 ]]; then
  CMD+=(--agent-teams)
  if [[ -n "$DISPATCH_TEAMMATE_MODE" ]]; then
    CMD+=(--teammate-mode "$DISPATCH_TEAMMATE_MODE")
  fi
fi

nohup "${CMD[@]}" >"$RUN_LOG" 2>&1 &
PID=$!

echo "DISPATCH_STARTED pid=$PID project=$PROJECT task=$TASK_NAME workdir=$WORKDIR teams=$NEED_TEAMS run_id=$RUN_ID result_dir=$RESULT_DIR log=$RUN_LOG"
