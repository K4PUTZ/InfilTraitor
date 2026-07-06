#!/usr/bin/env python3
##
## project_lint.py — Whole-project GDScript parse check (Godot 4.6.1)
## Runs the validator script and reports parse errors
##

import subprocess
import sys
import os
import re
import time

def find_godot_binary():
    """Locate the Godot 4.6.1 binary"""
    candidates = [
        "/Applications/Godot.app/Contents/MacOS/Godot",
        "/usr/bin/godot",
        "/usr/local/bin/godot",
    ]
    for candidate in candidates:
        if os.path.isfile(candidate):
            return candidate
    return None

def run_lint_check(repo_root, verbose=False):
    """Run the full-project parse check"""
    godot_bin = find_godot_binary()
    if not godot_bin:
        print("❌ Godot binary not found")
        return False
    
    print("[LINT] Checking whole-project parse integrity...")
    print(f"[LINT] Using: {godot_bin}")
    print()
    
    os.chdir(repo_root)
    
    # Run the validator script (proven fast: 0.7s)
    cmd = [
        godot_bin,
        "--headless",
        "--script", "res://godot/scripts/tools/project_lint_validator.gd",
    ]
    
    start_time = time.time()
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=10,  # Validator should complete in <1s on clean code
        )
        output = result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        print("[LINT] ❌ FAILED — Validator timeout (took >10s)")
        print("[LINT] This likely indicates compilation issues preventing script execution")
        return False
    except Exception as e:
        print(f"[LINT] ❌ FAILED — {e}")
        return False
    
    elapsed = time.time() - start_time
    
    # Extract parse error lines
    # Format: "SCRIPT ERROR: Parse Error: <message>" or "SCRIPT ERROR: Compile Error: <message>"
    parse_error_lines = []
    for line in output.split('\n'):
        if 'SCRIPT ERROR:' in line and ('Parse Error' in line or 'Compile Error' in line):
            parse_error_lines.append(line)
    
    if parse_error_lines:
        print("[LINT] ❌ FAILED — Parse errors detected")
        print()
        for line in parse_error_lines[:20]:  # Show first 20
            print(f"  {line}")
        if len(parse_error_lines) > 20:
            print(f"  ... and {len(parse_error_lines) - 20} more")
        print()
        if verbose:
            print("[DEBUG] Full output:")
            print(output)
        print(f"[LINT] Time: {elapsed:.1f}s")
        return False
    else:
        # Extract file count from summary
        file_count_match = re.search(r"Files checked: (\d+)", output)
        file_count = file_count_match.group(1) if file_count_match else "?"
        
        print("[LINT] ✅ PASSED — No parse errors detected")
        print(f"[LINT] Files checked: {file_count}")
        print(f"[LINT] Time: {elapsed:.1f}s")
        return True

def main():
    verbose = "--verbose" in sys.argv or "-v" in sys.argv
    repo_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    
    success = run_lint_check(repo_root, verbose)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()

