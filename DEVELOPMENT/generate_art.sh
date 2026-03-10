#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# generate_art.sh — Wrapper to run generate_concept.py safely detached
# ═══════════════════════════════════════════════════════════════════════════
#
# WHY THIS EXISTS:
#   The VS Code integrated terminal kills background processes when a new
#   command is run in the same terminal tab.  This wrapper launches the
#   Python generator via `nohup` in a subshell so it survives, and writes
#   progress to a status file you can poll with --status.
#
# USAGE:
#   bash generate_art.sh                        # generate with default prompt
#   bash generate_art.sh --status               # check progress of running job
#   bash generate_art.sh --prompt "my prompt"   # custom prompt
#   bash generate_art.sh --stop                 # cancel running generation
#   bash generate_art.sh --start-sd             # only start the SD WebUI server
#
# All other flags are forwarded to generate_concept.py (--width, --steps, etc.)
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARENT_ROOT="$(cd "$REPO_ROOT/.." && pwd)"

# Prefer a sibling checkout next to the repo, but also support an in-repo checkout.
if [ -d "$PARENT_ROOT/stable-diffusion-webui" ]; then
    SD_DIR="$PARENT_ROOT/stable-diffusion-webui"
else
    SD_DIR="$REPO_ROOT/stable-diffusion-webui"
fi
PYTHON="$SD_DIR/venv/bin/python"
GENERATOR="$SCRIPT_DIR/generate_concept.py"
LOG="/tmp/sd_gen.log"
PID_FILE="/tmp/sd_gen.pid"
STATUS_FILE="/tmp/sd_gen_status.txt"
API="http://127.0.0.1:7860"

# ── Helpers ────────────────────────────────────────────────────────────────
is_running() {
    [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

api_progress() {
    curl -s "$API/sdapi/v1/progress" 2>/dev/null | \
        python3 -c "
import sys, json
d = json.load(sys.stdin)
p = d['progress']
s = d['state']
job = s.get('job', '')
if job:
    print(f\"Progress: {p*100:.0f}% | Step {s['sampling_step']}/{s['sampling_steps']} | Job: {job}\")
else:
    print('Idle — no active generation job.')
" 2>/dev/null || echo "SD WebUI not reachable."
}

# ── Commands ───────────────────────────────────────────────────────────────
case "${1:-}" in
    --status)
        echo "=== SD WebUI API ==="
        api_progress
        echo ""
        echo "=== Generator process ==="
        if is_running; then
            echo "Running (PID $(cat "$PID_FILE"))"
            [ -f "$LOG" ] && echo "Last log lines:" && tail -3 "$LOG"
        else
            echo "Not running."
            [ -f "$STATUS_FILE" ] && echo "Last result: $(cat "$STATUS_FILE")"
        fi
        exit 0
        ;;

    --stop)
        if is_running; then
            kill "$(cat "$PID_FILE")" 2>/dev/null && echo "Generator stopped."
            rm -f "$PID_FILE"
        else
            echo "No generator running."
        fi
        # Also interrupt any active SD job
        curl -s -X POST "$API/sdapi/v1/interrupt" > /dev/null 2>&1 && echo "SD job interrupted."
        exit 0
        ;;

    --start-sd)
        echo "Starting SD WebUI server only…"
        # If the API is already reachable, exit without triggering generation.
        if curl -sf "$API/sdapi/v1/sd-models" >/dev/null 2>&1; then
            echo "Already running."
            exit 0
        fi
        # If not running, launch it via the generator's launch_sd()
        "$PYTHON" -c "
import sys; sys.path.insert(0, '$SCRIPT_DIR')
from generate_concept import launch_sd
launch_sd('$API')
"
        exit 0
        ;;
esac

# ── Main: launch generation detached ──────────────────────────────────────
if is_running; then
    echo "⚠️  A generation is already running (PID $(cat "$PID_FILE"))."
    echo "   Use: bash generate_art.sh --status"
    echo "   Or:  bash generate_art.sh --stop"
    exit 1
fi

echo "GENERATING" > "$STATUS_FILE"

# Forward all args to the Python script
(
    trap '' INT HUP TERM
    "$PYTHON" "$GENERATOR" "$@" >> "$LOG" 2>&1
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        echo "DONE ($(date))" > "$STATUS_FILE"
    else
        echo "FAILED exit=$EXIT_CODE ($(date))" > "$STATUS_FILE"
    fi
    rm -f "$PID_FILE"
) &

CHILD=$!
echo "$CHILD" > "$PID_FILE"

echo "🚀  Generation launched (PID $CHILD)"
echo "    Log:    tail -f $LOG"
echo "    Status: bash generate_art.sh --status"
echo ""
echo "The process runs in the background — you can close this terminal safely."
