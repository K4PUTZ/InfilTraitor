#!/usr/bin/env python3
##
## project_lint.py — Whole-project GDScript compile check (Godot 4.6.1)
## Runs the validator script and reports compile/parse errors.
##
## Known headless limitation (handled here): Godot in `--script` mode does not
## register autoload singletons as compile-time globals, so any script that
## references an autoload by bare identifier (e.g. `Registries.foo()`) fails
## with "Identifier not found: <AutoloadName>". Those specific errors — and the
## "Failed to compile depended scripts." cascades they cause — are FALSE
## POSITIVES and are suppressed, using the authoritative autoload list parsed
## from project.godot. Every other Parse/Compile error is real and fails the
## check. Caveat: a file whose first reported error is a suppressed autoload
## reference is only partially validated (the compiler stops early); the
## editor/PROBLEMS view still covers those, and any error the compiler does
## report past suppression fails the gate as usual.
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

def parse_autoload_names(repo_root):
    """Parse the [autoload] section of project.godot → set of singleton names."""
    project_file = os.path.join(repo_root, "project.godot")
    names = set()
    if not os.path.isfile(project_file):
        return names
    in_section = False
    with open(project_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("["):
                in_section = (line == "[autoload]")
                continue
            if in_section and "=" in line:
                names.add(line.split("=", 1)[0].strip())
    return names

def collect_error_records(output):
    """Pair each 'SCRIPT ERROR: Parse/Compile Error: <msg>' line with the
    'at: GDScript::reload (res://path:line)' location that follows it.
    Returns a list of (message, location) tuples."""
    records = []
    lines = output.split("\n")
    for i, line in enumerate(lines):
        match = re.search(r"SCRIPT ERROR: ((?:Parse|Compile) Error: .*)", line)
        if not match:
            continue
        message = match.group(1).strip()
        location = "?"
        # Location is printed on one of the immediately following lines
        for j in range(i + 1, min(i + 4, len(lines))):
            loc_match = re.search(r"at: GDScript::reload \((res://[^)]+)\)", lines[j])
            if loc_match:
                location = loc_match.group(1)
                break
        records.append((message, location))
    return records

def classify_records(records, autoload_names):
    """Split error records into (real, suppressed).

    Suppressed (headless false positives only):
      - "Identifier not found: <name>" where <name> is a declared autoload
      - "Failed to compile depended scripts." — a cascade whose root cause is
        always reported as its own record (real root causes still fail)
    """
    real = []
    suppressed = []
    for message, location in records:
        ident = re.search(r"Identifier not found: (\w+)", message)
        if ident and ident.group(1) in autoload_names:
            suppressed.append((message, location))
        elif "Failed to compile depended scripts" in message:
            suppressed.append((message, location))
        else:
            real.append((message, location))
    return real, suppressed

def run_lint_check(repo_root, verbose=False):
    """Run the full-project compile check"""
    godot_bin = find_godot_binary()
    if not godot_bin:
        print("❌ Godot binary not found")
        return False

    autoload_names = parse_autoload_names(repo_root)

    print("[LINT] Checking whole-project compile integrity...")
    print(f"[LINT] Using: {godot_bin}")
    print(f"[LINT] Autoloads (headless false-positive whitelist): "
          f"{', '.join(sorted(autoload_names)) or '(none)'}")
    print()

    os.chdir(repo_root)

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
            timeout=30,
        )
        output = result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        print("[LINT] ❌ FAILED — Validator timeout (took >30s)")
        print("[LINT] This likely indicates compilation issues preventing script execution")
        return False
    except Exception as e:
        print(f"[LINT] ❌ FAILED — {e}")
        return False

    elapsed = time.time() - start_time

    records = collect_error_records(output)
    real, suppressed = classify_records(records, autoload_names)

    file_count_match = re.search(r"Files checked: (\d+)", output)
    file_count = file_count_match.group(1) if file_count_match else "?"

    if real:
        print(f"[LINT] ❌ FAILED — {len(real)} real compile error(s) detected")
        print()
        for message, location in real[:20]:
            print(f"  {location}")
            print(f"    {message}")
        if len(real) > 20:
            print(f"  ... and {len(real) - 20} more")
        print()
        if suppressed:
            print(f"[LINT] ({len(suppressed)} autoload-context false positive(s) "
                  f"also suppressed — not counted above)")
        if verbose:
            print("[DEBUG] Full output:")
            print(output)
        print(f"[LINT] Time: {elapsed:.1f}s")
        return False

    print("[LINT] ✅ PASSED — No real compile errors detected")
    print(f"[LINT] Files checked: {file_count}")
    if suppressed:
        affected = sorted({loc for _, loc in suppressed if loc != "?"})
        print(f"[LINT] Suppressed {len(suppressed)} headless autoload false "
              f"positive(s) in {len(affected)} file(s):")
        for loc in affected:
            print(f"  - {loc} (partially validated — autoload refs unresolvable headless)")
    print(f"[LINT] Time: {elapsed:.1f}s")
    return True

def main():
    verbose = "--verbose" in sys.argv or "-v" in sys.argv
    repo_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

    success = run_lint_check(repo_root, verbose)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
