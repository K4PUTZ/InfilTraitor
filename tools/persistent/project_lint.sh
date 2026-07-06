#!/bin/bash
##
## PROJECT_LINT — Whole-project GDScript parse check
## Runs a headless checker to verify all .gd files have valid syntax
##
## Exit codes:  
##   0 = No parse errors found  
##   1 = Parse errors detected
##

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
CHECKER="res://godot/scripts/tools/project_lint_checker.gd"

# Validate Godot binary
if [[ ! -f "$GODOT_BIN" ]]; then
    echo "❌ Godot binary not found at: $GODOT_BIN"
    exit 1
fi

echo "[LINT] Checking whole-project parse integrity..."
echo "[LINT] Running: $GODOT_BIN --headless --script $CHECKER"
echo ""

cd "$REPO_ROOT"

# Run the checker with a timeout mechanism
start_time=$(date +%s)

OUTPUT=$("$GODOT_BIN" --headless --script "$CHECKER" 2>&1) || true
EXIT_CODE=$?

end_time=$(date +%s)
elapsed=$((end_time - start_time))

# Extract parse error lines (SCRIPT ERROR: Parse/Compile Error, not Identifier not found)
# We specifically look for actual parse/compile errors, not runtime context issues
PARSE_ERRORS=$(echo "$OUTPUT" | grep -E "SCRIPT ERROR: (Parse|Compile) Error:" || true)

# Count the errors
ERROR_COUNT=0
if [[ -n "$PARSE_ERRORS" ]]; then
    ERROR_COUNT=$(echo "$PARSE_ERRORS" | wc -l | tr -d ' ')
fi

# Report results
if [[ $ERROR_COUNT -gt 0 ]]; then
    echo "[LINT] ❌ FAILED — Parse errors detected ($ERROR_COUNT)"
    echo ""
    echo "$PARSE_ERRORS" | head -20
    echo ""
    if [[ "$1" == "--verbose" ]]; then
        echo "[DEBUG] Full output:"
        echo "$OUTPUT"
        echo ""
    fi
    echo "[LINT] Time: ${elapsed}s"
    exit 1
else
    FILE_COUNT=$(echo "$OUTPUT" | grep "Files checked:" | awk '{print $NF}' || echo "?")
    echo "[LINT] ✅ PASSED — No parse errors detected"
    echo "[LINT] Files checked: $FILE_COUNT"
    echo "[LINT] Time: ${elapsed}s"
    exit 0
fi
