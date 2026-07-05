# FIX-BAKE-06: Debug Views & Wiring

**Status:** Ready for implementation
**Predecessor:** FIX-BAKE-05 (The Swap)
**Successor:** FIX-BAKE-07 (Selftest & Invariants)
**Scope:** Wire ThemeMatrixDebugView into room.gd; decide F12 selftest binding; calibration UI
**Effort:** ~2 hours
**Risk:** Low (debug-only, no live impact)

---

## Problem

- **ThemeMatrixDebugView exists** but is never instantiated; F5 is dead in-game
- **F12 selftest binding does not exist** (tests are headless-only)
- **Theme saturation calibration** (D9) has no in-game feedback beyond the grid itself

---

## Solution

### S1: Instantiate ThemeMatrixDebugView in room.gd

**Changes to room.gd (or a new DebugInitializer scene):**

```gdscript
func _ready() -> void:
    # ... existing initialization ...
    
    # Debug views (F keys)
    if OS.is_debug_build() or Engine.is_editor_hint():
        _initialize_debug_views()

func _initialize_debug_views() -> void:
    # Theme Matrix (F5)
    var theme_matrix = preload("res://godot/scripts/debug/theme_matrix_debug_view.gd").new()
    add_child(theme_matrix)
    print("[DEBUG] F5: Theme Matrix viewer initialized")
    
    # Note: F12 selftest is headless-only (see FIX-BAKE-07)
    print("[DEBUG] F12: Run headless selftest via 'godot --headless --script bake_selftest.gd'")

func _input(event: InputEvent) -> void:
    # Optional: add handler for manual test invocation
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_F12:
            # Could invoke headless script or print instructions
            print("[DEBUG] F12: Selftest instructions → check console output")
```

### S2: Theme Matrix UI Polish

The ThemeMatrixDebugView already has `_ready()` and input handling. Ensure it's fully wired:

**Verify in theme_matrix_debug_view.gd:**

```gdscript
func _ready() -> void:
    # Constructor-like setup
    _create_grid_ui()
    
    # Position on screen (top-left or configurable)
    _panel_container.position = Vector2(10, 10)
    _panel_container.size = Vector2(300, 400)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_F5:
            # Toggle visibility
            _panel_container.visible = not _panel_container.visible
            get_tree().root.set_input_as_handled()
            print("[THEME] F5: Grid %s" % ("visible" if _panel_container.visible else "hidden"))
```

### S3: Saturation calibration guidance

Add in-UI documentation for D9 discipline:

```gdscript
# In theme_matrix_debug_view.gd, title section:
func _create_grid_ui() -> void:
    var title = Label.new()
    title.text = "THEME MATRIX (F5) — Material × Theme Grid"
    title.add_theme_font_size_override("font_size", 12)
    
    var instructions = Label.new()
    instructions.text = """
    D9 Saturation Discipline:
    • Facade sources: grayscale (R==G==B)
    • Material base colors: desaturated or intentional tone
    • Themes: soft tints (moderate sat, high val) or dominant filter
    • Result (cell): (base_color × theme × facade_lum)
    • If muddy (low sat, low val): reduce theme saturation
    """
    instructions.add_theme_font_size_override("font_size", 9)
    
    vbox.add_child(title)
    vbox.add_child(instructions)
```

### S4: Headless selftest decision

**Decision point:** Should F12 launch a headless subprocess, or remain CLI-only?

**Recommendation:** Remain CLI-only for v1. The selftest requires deterministic state (no random guards, clean registry) and produces console evidence (literal PASS lines). Launching headless from within a live game is unreliable (background task, output capture, state contamination).

**Documentation:**

```gdscript
# In room.gd _initialize_debug_views():
func _initialize_debug_views() -> void:
    var theme_matrix = preload(...).new()
    add_child(theme_matrix)
    
    print("""
    [DEBUG BINDINGS]
    F5:  Toggle Theme Matrix (calibration grid)
    F12: (Reserved) Selftest — run headless:
         godot --headless --script godot/scripts/tools/bake_selftest.gd
    """)
```

---

## Validation & Evidence (PASS Criteria)

### Test 1: Theme Matrix appears in-game (manual)

**Procedure:**

1. Load a test room with baking enabled
2. Press F5
3. Verify: a 300×400 grid appears in top-left, with:
   - Title: "THEME MATRIX (F5)"
   - Row headers: material names (stone, wood, metal)
   - Column headers: theme names (light, dark, accent)
   - Cells: color swatches showing (base_color × theme)
   - Instructions text visible

**Expected output (console):**
```
[DEBUG] F5: Theme Matrix viewer initialized
[THEME] F5: Grid visible
[THEME] Applied: RGB(0.60, 0.50, 0.80)
```

### Test 2: F5 toggle works

**Procedure:**

1. Press F5 to show
2. Verify grid is visible
3. Press F5 to hide
4. Verify grid is hidden
5. Press F5 to show again

**Expected output:**
```
[THEME] F5: Grid visible
[THEME] F5: Grid hidden
[THEME] F5: Grid visible
```

### Test 3: Selftest CLI instruction is clear

**Procedure:**

1. Load room
2. Verify console shows the F12 instruction with the exact command

**Expected output:**
```
[DEBUG BINDINGS]
F5:  Toggle Theme Matrix (calibration grid)
F12: (Reserved) Selftest — run headless:
     godot --headless --script godot/scripts/tools/bake_selftest.gd
```

---

## Implementation Checklist

- [ ] Verify ThemeMatrixDebugView._ready() creates all UI elements (should already be done)
- [ ] Add `_initialize_debug_views()` to room.gd
- [ ] Call it from room._ready() (after scene is loaded)
- [ ] Add instructions text to theme grid UI
- [ ] Test F5 toggle manually (visual inspection)
- [ ] Verify console output contains "[DEBUG]" messages
- [ ] Add F12 instruction to console (no binding needed; reference only)
- [ ] Test on both debug and release builds (debug_build() may affect visibility)

---

## Notes

- **ThemeMatrixDebugView is intentionally UI-only.** It does not modify the baking or rendering; it is purely for authorial calibration of D9.
- **F12 selftest remains headless** to avoid runtime overhead and state pollution in the live game.
- **Deprecate old F2/F3/F4** (geometry ruler) if they conflict; otherwise leave them available.

---

*End FIX-BAKE-06.*
