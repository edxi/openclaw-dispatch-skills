#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${OPENCLAW_DISPATCH_ENV:-$HOME/.config/openclaw/dispatch.env}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

REPOS_ROOT="${REPOS_ROOT:-$HOME/repos}"
LAUNCH_LOG_DIR="${LAUNCH_LOG_DIR:-$HOME/.openclaw/data/dispatch-launch}"
DISPATCH_REPO="${DISPATCH_REPO:-$HOME/repos/claude-code-dispatch}"
CC_DISPATCH_BIN="${CC_DISPATCH_BIN:-$(command -v cc-dispatch 2>/dev/null || echo "$HOME/.local/bin/cc-dispatch")}"
DISPATCH_PERMISSION_MODE="${DISPATCH_PERMISSION_MODE:-bypassPermissions}"
DISPATCH_TEAMMATE_MODE="${DISPATCH_TEAMMATE_MODE:-}"
DISPATCH_TIMEOUT_SEC="${DISPATCH_TIMEOUT_SEC:-7200}"

if [[ $# -lt 3 ]]; then
  echo "Usage: /dispatch <project> <task-name> <prompt...>" >&2
  exit 2
fi

PROJECT="$1"
TASK_NAME="$2"
shift 2
PROMPT="$*"

WORKDIR="${REPOS_ROOT}/${PROJECT}"
mkdir -p "$WORKDIR"
mkdir -p "$LAUNCH_LOG_DIR"

NEED_TEAMS=0
if echo "$PROMPT" | grep -Eiq '(Agent Team|Agent Teams|多智能体|并行|testing agent)'; then
  NEED_TEAMS=1
fi

RUN_ID="$(date -u +%Y%m%d-%H%M%S)-${PROJECT}-${TASK_NAME}"
RUN_LOG="$LAUNCH_LOG_DIR/${RUN_ID}.log"

if [[ -x "$CC_DISPATCH_BIN" ]]; then
  CMD=("$CC_DISPATCH_BIN" -n "$TASK_NAME" -w "$WORKDIR" -p "$PROMPT" --permission-mode "$DISPATCH_PERMISSION_MODE")
  if [[ "$NEED_TEAMS" -eq 1 ]]; then
    CMD+=(--agent-teams)
    if [[ -n "$DISPATCH_TEAMMATE_MODE" ]]; then
      CMD+=(--teammate-mode "$DISPATCH_TEAMMATE_MODE")
    fi
  fi
else
  DISPATCH_SH="$DISPATCH_REPO/scripts/dispatch.sh"
  if [[ ! -f "$DISPATCH_SH" ]]; then
    echo "Error: neither cc-dispatch nor $DISPATCH_SH found" >&2
    exit 2
  fi
  RESULTS_BASE="${RESULTS_BASE:-$HOME/.openclaw/data/claude-code-results}"
  RESULT_DIR="$RESULTS_BASE/$PROJECT/$RUN_ID"
  mkdir -p "$RESULT_DIR"
  export RESULT_DIR
  export DISPATCH_TIMEOUT_SEC
  CMD=(bash "$DISPATCH_SH" -n "$TASK_NAME" -w "$WORKDIR" -p "$PROMPT" --permission-mode "$DISPATCH_PERMISSION_MODE")
  if [[ "$NEED_TEAMS" -eq 1 ]]; then
    CMD+=(--agent-teams)
    if [[ -n "$DISPATCH_TEAMMATE_MODE" ]]; then
      CMD+=(--teammate-mode "$DISPATCH_TEAMMATE_MODE")
    fi
  fi
fi

export DISPATCH_TIMEOUT_SEC
nohup "${CMD[@]}" >"$RUN_LOG" 2>&1 &
PID=$!

echo "DISPATCH_STARTED pid=$PID project=$PROJECT task=$TASK_NAME workdir=$WORKDIR teams=$NEED_TEAMS run_id=$RUN_ID log=$RUN_LOG"
