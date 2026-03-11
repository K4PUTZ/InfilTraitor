#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_VENV="$ROOT_DIR/../../../.venv/bin/python"

if [ -x "$WORKSPACE_VENV" ]; then
	PYTHON_BIN="$WORKSPACE_VENV"
elif command -v python3 >/dev/null 2>&1; then
	PYTHON_BIN="$(command -v python3)"
else
	echo "James: python3 not found on PATH."
	exit 1
fi

cd "$ROOT_DIR"

echo "James: Running preflight..."
"$PYTHON_BIN" james.py preflight

echo ""
echo "James: Audio input selection:"
"$PYTHON_BIN" james.py audio-device --selected-only

echo ""
echo "James: Ready. Example next commands:"
echo "  $PYTHON_BIN james.py listen --goal \"Voice operator request\""
echo "  $PYTHON_BIN james.py monitor"
echo "  $PYTHON_BIN james.py capture-prompt \"Open Godot and inspect the project\""
echo "  $PYTHON_BIN james.py audio-device"
echo "  $PYTHON_BIN james.py start-task \"Manual Godot workflow\""
echo "  $PYTHON_BIN james.py launch-godot --push-current"
