#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_VENV="$ROOT_DIR/../../../.venv/bin/python"

if [ -x "$WORKSPACE_VENV" ]; then
	PYTHON_BIN="$WORKSPACE_VENV"
elif command -v python3 >/dev/null 2>&1; then
	PYTHON_BIN="$(command -v python3)"
else
	echo "James operator launcher: python3 not found on PATH."
	exit 1
fi

cd "$ROOT_DIR"
exec "$PYTHON_BIN" launch_james_operator.py "$@"