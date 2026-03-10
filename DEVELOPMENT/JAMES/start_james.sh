#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_BIN="/usr/local/bin/python3.13"

cd "$ROOT_DIR"

echo "James: Running preflight..."
"$PYTHON_BIN" james.py preflight

echo ""
echo "James: Ready. Example next commands:"
echo "  $PYTHON_BIN james.py capture-prompt \"Open Godot and inspect the project\""
echo "  $PYTHON_BIN james.py start-task \"Manual Godot workflow\""
echo "  $PYTHON_BIN james.py launch-godot --push-current"
