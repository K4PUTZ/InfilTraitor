#!/bin/bash
PROJECT_DIR="/Users/mateus/Agent_Operator"
cd "$PROJECT_DIR" || exit

CACHE_DIR="cache"
SKILLS_DIR="skills"

# 1. Clean Cache
rm -rf "$CACHE_DIR"/*

# 2. Assessment
echo "Alfred: Performing System Assessment..."
python3 assessment.py

# 3. Load Skills
echo "Alfred: Loading Learned Skills..."
for skill in "$SKILLS_DIR"/*.sh; do
    [ -e "$skill" ] || continue
    echo "  - Enabling: $(basename "$skill")"
done

# 4. Voice Protocol Launch (Alfred Brain Loop)
echo "Alfred: Enabling Brain Protocol..."
python3 brain_loop.py &

# 5. Mission Launch
/opt/homebrew/bin/gemini
