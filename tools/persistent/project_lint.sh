#!/bin/bash
##
## PROJECT_LINT — Whole-project GDScript compile check
## Thin wrapper: delegates to project_lint.py, the single source of truth
## (autoload false-positive suppression, error classification, exit codes).
##
## Exit codes:
##   0 = No real compile errors found
##   1 = Real compile errors detected
##

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/project_lint.py" "$@"
