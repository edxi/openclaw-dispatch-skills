#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_ROOT="$(cd "$SKILL_DIR/.." && pwd)"
ENV_FILE="${OPENCLAW_DISPATCH_ENV:-$SKILLS_ROOT/dispatch.env.local}"
LEGACY_ENV_FILE="$HOME/.config/openclaw/dispatch.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
elif [[ -f "$LEGACY_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$LEGACY_ENV_FILE"
fi

REPOS_ROOT="${REPOS_ROOT:-/home/miniade/repos}"
RESULTS_BASE="${RESULTS_BASE:-/home/miniade/clawd/data/claude-code-results}"
LAUNCH_LOG_DIR="${LAUNCH_LOG_DIR:-/home/miniade/clawd/data/dispatch-launch}"
DISPATCH_REPO="${DISPATCH_REPO:-/home/miniade/repos/claude-code-dispatch}"
DISPATCH_PERMISSION_MODE="${DISPATCH_PERMISSION_MODE:-bypassPermissions}"
DISPATCHI_MAX_ITERATIONS="${DISPATCHI_MAX_ITERATIONS:-20}"
DISPATCHI_COMPLETION_PROMISE="${DISPATCHI_COMPLETION_PROMISE:-COMPLETE}"
AUTO_EXIT_ON_COMPLETE="${AUTO_EXIT_ON_COMPLETE:-1}"
AUTO_EXIT_GRACE_SEC="${AUTO_EXIT_GRACE_SEC:-20}"
AUTO_EXIT_MAX_WAIT_SEC="${AUTO_EXIT_MAX_WAIT_SEC:-21600}"
AUTO_EXIT_POLL_SEC="${AUTO_EXIT_POLL_SEC:-5}"
CODEHOOK_GROUP_DEFAULT="${CODEHOOK_GROUP_DEFAULT:--1002547895616}"
TELEGRAM_GROUP="${TELEGRAM_GROUP:-$CODEHOOK_GROUP_DEFAULT}"

OPENCLAW_BIN="${OPENCLAW_BIN:-$(command -v openclaw 2>/dev/null || echo "$HOME/.npm-global/bin/openclaw")}"
OPENCLAW_CONFIG="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
OPENCLAW_TELEGRAM_ACCOUNT="${OPENCLAW_TELEGRAM_ACCOUNT:-coder}"
CLAUDE_CODE_BIN="${CLAUDE_CODE_BIN:-/home/miniade/.local/bin/claude}"

if [[ $# -lt 3 ]]; then
  echo "Usage: /dispatchi <project> <task-name> <prompt...>" >&2
  exit 2
fi

RUNNER="$DISPATCH_REPO/scripts/claude_code_run.py"
if [[ ! -f "$RUNNER" ]]; then
  echo "Error: runner not found: $RUNNER" >&2
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

RUN_ID="$(date -u +%Y%m%d-%H%M%S)-${PROJECT}-${TASK_NAME}-interactive"
RESULT_DIR="$RESULTS_BASE/$PROJECT/$RUN_ID"
RUN_LOG="$LAUNCH_LOG_DIR/${RUN_ID}.log"
mkdir -p "$RESULT_DIR"

TMUX_SESSION="cc-${PROJECT}-${RUN_ID}"
TMUX_SOCKET_DIR="/tmp/clawdbot-tmux-sockets"
TMUX_SOCKET_NAME="claude-${PROJECT}-${RUN_ID}.sock"
TMUX_SOCKET_PATH="$TMUX_SOCKET_DIR/$TMUX_SOCKET_NAME"
mkdir -p "$TMUX_SOCKET_DIR"

export RESULT_DIR OPENCLAW_BIN OPENCLAW_CONFIG OPENCLAW_TELEGRAM_ACCOUNT CLAUDE_CODE_BIN

jq -n \
  --arg name "$TASK_NAME" \
  --arg group "$TELEGRAM_GROUP" \
  --arg prompt "$PROMPT" \
  --arg workdir "$WORKDIR" \
  --arg ts "$(date -Iseconds)" \
  --argjson agent_teams "$( [[ $NEED_TEAMS -eq 1 ]] && echo true || echo false )" \
  --arg mode "interactive" \
  --arg run_id "$RUN_ID" \
  --arg tmux_session "$TMUX_SESSION" \
  --arg tmux_socket_name "$TMUX_SOCKET_NAME" \
  '{task_name:$name, telegram_group:$group, prompt:$prompt, workdir:$workdir, started_at:$ts, agent_teams:$agent_teams, status:"running", dispatch_mode:$mode, run_id:$run_id, tmux_session:$tmux_session, tmux_socket_name:$tmux_socket_name}' \
  > "$RESULT_DIR/task-meta.json"
: > "$RESULT_DIR/task-output.txt"

RALPH_CMD="/ralph-loop:ralph-loop \"${PROMPT}\" --completion-promise \"${DISPATCHI_COMPLETION_PROMISE}\" --max-iterations ${DISPATCHI_MAX_ITERATIONS}"

CMD=(python3 "$RUNNER"
  --mode interactive
  --cwd "$WORKDIR"
  --permission-mode "$DISPATCH_PERMISSION_MODE"
  --tmux-session "$TMUX_SESSION"
  --tmux-socket-dir "$TMUX_SOCKET_DIR"
  --tmux-socket-name "$TMUX_SOCKET_NAME"
  -p "$RALPH_CMD"
)
if [[ "$NEED_TEAMS" -eq 1 ]]; then
  CMD+=(--agent-teams)
fi

if ! "${CMD[@]}" >>"$RUN_LOG" 2>&1; then
  echo "ERROR: failed to start interactive dispatch" >>"$RUN_LOG"
  exit 1
fi

if ! tmux -S "$TMUX_SOCKET_PATH" has-session -t "$TMUX_SESSION" 2>/dev/null; then
  echo "ERROR: tmux session not found after startup" >>"$RUN_LOG"
  exit 1
fi

tmux -S "$TMUX_SOCKET_PATH" pipe-pane -o -t "${TMUX_SESSION}:0.0" "cat >> '$RESULT_DIR/task-output.txt'" || true

if [[ "$AUTO_EXIT_ON_COMPLETE" = "1" ]]; then
  (
    sleep "$AUTO_EXIT_GRACE_SEC"
    END_TS=$(( $(date +%s) + AUTO_EXIT_MAX_WAIT_SEC ))
    while [ "$(date +%s)" -lt "$END_TS" ]; do
      SNAP=$(tmux -S "$TMUX_SOCKET_PATH" capture-pane -p -J -t "${TMUX_SESSION}:0.0" -S -200 2>/dev/null || true)
      CLEAN=$(printf '%s' "$SNAP" | sed -r 's/\x1B\[[0-9;?]*[ -/]*[@-~]//g')

      # Completion must appear as a standalone line, not only inside command args.
      if printf '%s\n' "$CLEAN" | grep -Eq "^[[:space:]]*${DISPATCHI_COMPLETION_PROMISE}[[:space:]]*$"; then
        tmux -S "$TMUX_SOCKET_PATH" send-keys -t "${TMUX_SESSION}:0.0" -l -- "/exit" || true
        tmux -S "$TMUX_SOCKET_PATH" send-keys -t "${TMUX_SESSION}:0.0" Enter || true
        sleep 2
        tmux -S "$TMUX_SOCKET_PATH" kill-session -t "$TMUX_SESSION" >/dev/null 2>&1 || true
        break
      fi

      sleep "$AUTO_EXIT_POLL_SEC"
    done
  ) >>"$RUN_LOG" 2>&1 &
fi

echo "DISPATCHI_STARTED pid=$$ project=$PROJECT task=$TASK_NAME workdir=$WORKDIR run_id=$RUN_ID result_dir=$RESULT_DIR log=$RUN_LOG max_iter=$DISPATCHI_MAX_ITERATIONS completion=$DISPATCHI_COMPLETION_PROMISE"
