import json
import datetime
import os
import re

# Define the script directory to use absolute paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

MEMORY_FILE = os.path.join(SCRIPT_DIR, "memory.json")
HANDOVER_FILE = os.path.join(SCRIPT_DIR, "LAST_SESSION.md")
MISSION_FILE = os.path.join(SCRIPT_DIR, "MISSION.md")

def update_mission_md(summary):
    if not os.path.exists(MISSION_FILE):
        return
    
    with open(MISSION_FILE, "r") as f:
        content = f.read()

    today = datetime.date.today().strftime("%Y-%m-%d")
    status_header = f"## Current Status ({today})"
    
    # Simple regex to replace the status section or append it
    if "## Current Status" in content:
        # Replace existing status section
        new_content = re.sub(r"## Current Status \(.*?\)\n(.*\n?)*", f"{status_header}\n{summary}\n", content)
    else:
        new_content = content + f"\n{status_header}\n{summary}\n"
        
    with open(MISSION_FILE, "w") as f:
        f.write(new_content)

def run_quit_routine():
    print("Alfred: Commencing Automated Quitting Routine...")
    
    # 1. Update Memory
    try:
        if os.path.exists(MEMORY_FILE):
            with open(MEMORY_FILE, "r") as f:
                memory = json.load(f)
        else:
            memory = {"success_count": 0, "failure_log": [], "learned_patterns": []}
    except:
        memory = {"success_count": 0, "failure_log": [], "learned_patterns": []}

    memory["success_count"] += 1
    
    # 2. Prepare Summary
    summary = """- **Voice Protocol**: Refined with silent error handling and automated quit triggers.
- **Vision Protocol**: Native macOS Vision fully integrated as the primary OCR engine.
- **Automation**: Unified quitting routine now handles memory updates and documentation synchronization."""

    # 3. Update Documentation
    update_mission_md(summary)

    handover_content = f"""# Alfred Handover Note - {datetime.datetime.now().strftime("%Y-%m-%d %H:%M")}

## Summary of Last Session
{summary}

## Priority for Next Session
1. Expand the `skills/` library with more GUI automation patterns.
2. Optimize the "Wait-for-UI" loop for web-based workflows.

## Status: READY
"""
    with open(HANDOVER_FILE, "w") as f:
        f.write(handover_content)

    # 4. Save Memory
    with open(MEMORY_FILE, "w") as f:
        json.dump(memory, f, indent=4)

    print("Alfred: Memory updated. Documentation synchronized.")
    print("Alfred: At your service, Master Mateus. See you in the next session.")

if __name__ == "__main__":
    run_quit_routine()
