# Alfred Protocol: GUI Control Mission

## Goal
Enable Alfred to "see" (Screen Capture + OCR), "read" (Document Conversion), and "act" (Simulated Clicks/Keystrokes/AppleScript) on macOS to automate complex GUI-based workflows and data entry with human-like reliability and state-awareness.

## System Architecture: Hybrid Interaction
This agent uses four primary methods for interaction and control:
1.  **Structured Control (AppleScript):** 
    - **Usage:** Preferred for native macOS apps (Chrome, Finder, Terminal).
    - **Tool:** `/usr/bin/osascript`.
    - **Capability:** Direct URL navigation, window activation, and system-level keystrokes.
2.  **Visual Interaction (Python + Native Vision):**
    - **Usage:** Used when structured control is unavailable.
    - **Tool:** `Agent_Operator/apple_vision.py` (uses macOS Vision Framework) and `Agent_Operator/vision_hands.py`.
3.  **Document Processing:**
    - **Usage:** Extracting data from binary documents (Word, PDF) to inform automation.
    - **Tool:** `textutil` (native macOS) for `.docx` to `.txt` conversion.
4.  **Voice Interaction (Brain Protocol):**
    - **Usage:** Hands-free command entry and intelligent processing.
    - **Tools:** `get_command.py`, `brain_loop.py`, `speak.py`.

## Environment & Tools
- **Hands:** `cliclick` (/usr/local/bin/cliclick) - Mouse/Keyboard simulation.
- **Eyes:** `apple_vision.py` - Native macOS Vision OCR.
- **Brain:** Gemini CLI - Advanced reasoning and tool execution.
- **Voice:** `Daniel` (macOS System Voice) - Butler-like persona.
- **System:** `osascript` (/usr/bin/osascript) - AppleScript for native app control.
- **Processing:** `textutil`, `python3`.

## Operational Routines & Best Practices
- **UI State Assessment (Critical):** Before acting, Alfred must capture a full-screen screenshot to verify:
    - Focus: Is the correct application/window in the foreground?
    - Context: Is the app in the correct mode (e.g., "Design" vs "Preview")?
    - Readiness: Is the cursor active or the field editable?
- **Navigation Reliability:** Do not rely on browser "back" buttons or generic shortcuts if specific UI buttons (like "Voltar") are available. Use page refreshes if the UI state becomes stale or ambiguous.
- **The "Clear & Type" Edit Routine:** To prevent text artifacts (like unintended keystroke names), use: **Click Field -> Cmd+A -> Backspace -> Type New Text**.
- **The Verification Loop:** Every action sequence must conclude with a verification screenshot. Never assume an action was successful without "seeing" the result.
- **Focus Alternation:** Alfred must alternate focus between the target application and the Terminal after every action or screenshot to maintain user visibility.

## Current Status (2026-03-01)
- **Voice Protocol**: Refined with silent error handling and automated quit triggers.
- **Vision Protocol**: Native macOS Vision fully integrated as the primary OCR engine.
- **Automation**: Unified quitting routine now handles memory updates and documentation synchronization.
