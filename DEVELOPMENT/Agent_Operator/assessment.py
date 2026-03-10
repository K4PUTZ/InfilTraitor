import os
import json
import subprocess

# Define the script directory to use absolute paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def get_status(command):
    try:
        subprocess.run(command, check=True, capture_output=True)
        return "✅ OK"
    except:
        return "❌ ERROR"

def print_status_car():
    # Define cache dir path
    cache_dir = os.path.join(SCRIPT_DIR, "cache")
    if not os.path.exists(cache_dir):
        os.makedirs(cache_dir)
        
    status = {
        "EYES (Native)": get_status(["python3", "-c", "import Vision"]),
        "EYES (Legacy)": get_status(["/opt/homebrew/bin/tesseract", "--version"]),
        "HANDS (Click)": get_status(["/usr/local/bin/cliclick", "-h"]),
        "SYSTEM (OS)": get_status(["osascript", "-e", 'return "ok"']),
        "CACHE": "✅ CLEAN" if not os.listdir(cache_dir) else "⚠️ FULL"
    }
    
    memory_path = os.path.join(SCRIPT_DIR, "memory.json")
    if os.path.exists(memory_path):
        with open(memory_path, "r") as f:
            mem = json.load(f)
    else:
        mem = {}

    car = f"""
    Agent Operator Mission Status
    -----------------------------------
       ______
      /|_||_`.__
     (   _    _ _\      EYES:   {status["EYES (Native)"]} (Native Vision)
     =`-(_)--(_)-'      HANDS:  {status["HANDS (Click)"]} (Cliclick)
    ------------------  LOGIC:  {status["SYSTEM (OS)"]} (AppleScript)
    
    SYSTEM ASSESMENT:
    - Native OCR: {status["EYES (Native)"]}
    - Legacy OCR: {status["EYES (Legacy)"]}
    - Cache: {status["CACHE"]}
    - Successes: {mem.get("success_count", 0)}
    - Learned Skills: {len(mem.get("learned_patterns", []))}
    
    READY FOR MISSION
    """
    print(car)

if __name__ == "__main__":
    print_status_car()
