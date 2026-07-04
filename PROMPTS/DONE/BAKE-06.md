# BAKE-06: ThemeApplier & Theme Matrix Debug View

**Prompt for:** K4PUTZ (structured implementation)
**Deliverables:** `theme_applier.gd` module, Theme Matrix debug UI (F-key, joined F2/F3/F4 family), integration into wall layer modulation
**Predecessor:** `BAKE-05` (Drop-in swap complete, baking functional)
**Successor:** `BAKE-07` (BAKE selftest consolidation)
**Status:** Ready for implementation
**PASS criteria:** Theme applied to wall layer via modulate; Theme Matrix renders all materials × all themes in grid; console logs modulate color per material; visual inspection confirms saturation discipline (D9)

---

## Context

Themes (map-specific color tints) are applied **at render time** via `modulate`, not baked into the atlas. This buys flexibility: atlas is reusable across themes, and switching themes is instant (single modulate call). The ThemeApplier is a thin wrapper ensuring one call site for modulation, and the Theme Matrix view is a **visual calibration tool** that exposes saturation discipline (D9) — preventing "mud" from saturated × saturated multiplies.

---

## Part A: ThemeApplier Module

### A.1 Interface

```gdscript
class_name ThemeApplier

# Apply a theme color to all wall-rendering layers
func apply(theme_color: Color) -> void:
    # theme_color is the map's theme tint (e.g., Color(0.95, 0.95, 1.0) for cool white)
    # Set modulate on all wall TileMaps
    
    if WALL_TILEMAPS == null:
        push_error("WALL_TILEMAPS not initialized")
        return
    
    for tilemap in WALL_TILEMAPS:
        tilemap.modulate = theme_color
    
    # Log for evidence
    print("[THEME] Applied: RGB(%.2f, %.2f, %.2f), HSV(%.1f°, %.1%%, %.1%%)" % [
        theme_color.r, theme_color.g, theme_color.b,
        theme_color.get_h() * 360, theme_color.get_s() * 100, theme_color.get_v() * 100
    ])

func clear() -> void:
    # Reset to neutral (white = identity multiply)
    apply(Color.WHITE)

func get_current_theme() -> Color:
    if WALL_TILEMAPS == null or WALL_TILEMAPS.is_empty():
        return Color.WHITE
    return WALL_TILEMAPS[0].modulate
```

### A.2 Integration at Boot

In `room_builder.gd`:

```gdscript
func _ready_themed_walls() -> void:
    # ... geometry built, baking complete ...
    
    # Fetch theme from map spec
    var theme_color = map_spec.theme_color  # Or default to Color.WHITE
    
    # Apply theme
    var theme_applier = ThemeApplier.new()
    theme_applier.apply(theme_color)
    
    # Store globally for debug/theme-switching
    GLOBAL_THEME_APPLIER = theme_applier
```

### A.3 Theme Switching (Runtime, Optional)

For live theme changes (cutscenes, state transitions):

```gdscript
# Elsewhere, when theme changes:
GLOBAL_THEME_APPLIER.apply(new_theme_color)
```

---

## Part B: Theme Matrix Debug View

The Theme Matrix is a **visual grid** showing all materials × all themes, revealing saturation issues before they reach gameplay.

### B.1 UI Layout

```
┌─────────────────────────────────────────────────────┐
│                    THEME MATRIX                      │
├─────────────────────────────────────────────────────┤
│     │ Theme1   │ Theme2   │ Theme3   │ ... (themes) │
├─────┼──────────┼──────────┼──────────┼─────────────┤
│ ST  │ ▦ ▦ ▦   │ ▦ ▦ ▦   │ ▦ ▦ ▦   │             │ (stone)
│ WD  │ ▦ ▦ ▦   │ ▦ ▦ ▦   │ ▦ ▦ ▦   │             │ (wood)
│ ML  │ ▦ ▦ ▦   │ ▦ ▦ ▦   │ ▦ ▦ ▦   │             │ (metal)
│ ... │ ...     │ ...     │ ...     │ ...         │
└─────┴──────────┴──────────┴──────────┴─────────────┘

Each cell (M × T) shows: a rendered voxel tile of material M under theme T
  ▦ ▦ ▦ = sampled voxels to show texture + theme blend
```

### B.2 Implementation

```gdscript
class_name ThemeMatrixDebugView
extends CanvasLayer

var is_active: bool = false
var material_registry: MaterialRegistry
var theme_list: Array[Color]

func _ready() -> void:
    material_registry = GLOBAL_MATERIAL_REGISTRY
    
    # Populate theme list (from map spec or predefined set)
    theme_list = [
        Color(0.95, 0.95, 1.0),   # Cool white (normal)
        Color(1.0, 0.2, 0.2),     # Alarm red
        Color(0.2, 0.8, 0.2),     # Stealth green
        Color(0.5, 0.5, 0.5),     # Darken (night)
    ]

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        # F5 (or next free F-key after F4) toggles Theme Matrix
        if event.keycode == KEY_F5:
            toggle()

func toggle() -> void:
    is_active = !is_active
    visible = is_active
    if is_active:
        render_matrix()

func render_matrix() -> void:
    # Dynamically generate a visual grid
    # Option 1: Use a SubViewport to render each cell
    # Option 2: Use a CanvasItem and draw() calls
    
    var materials = material_registry.list_materials()
    var num_materials = materials.size()
    var num_themes = theme_list.size()
    
    # Grid dimensions
    var cell_width = 64    # pixels per cell
    var cell_height = 64
    var gap = 8
    
    var grid_width = num_themes * (cell_width + gap) + gap
    var grid_height = num_materials * (cell_height + gap) + gap
    
    # Create a drawing surface
    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(grid_width + 200, grid_height + 100)  # Extra for labels
    add_child(panel)
    
    var vbox = VBoxContainer.new()
    panel.add_child(vbox)
    
    # Title
    var title = Label.new()
    title.text = "THEME MATRIX (F5 to hide)"
    title.add_theme_font_size_override("font_size", 16)
    vbox.add_child(title)
    
    # Header row (themes)
    var header_hbox = HBoxContainer.new()
    header_hbox.add_child(Label.new())  # Blank for material names column
    for theme_idx in range(num_themes):
        var theme_label = Label.new()
        var theme_color = theme_list[theme_idx]
        theme_label.text = "T%d (%.2f, %.2f, %.2f)" % [theme_idx, theme_color.r, theme_color.g, theme_color.b]
        theme_label.add_theme_color_override("font_color", theme_color)
        header_hbox.add_child(theme_label)
    vbox.add_child(header_hbox)
    
    # Rows (materials)
    for mat_idx in range(num_materials):
        var material_id = materials[mat_idx]
        var material = material_registry.get_material(material_id)
        
        var row_hbox = HBoxContainer.new()
        
        # Material label
        var mat_label = Label.new()
        mat_label.text = material_id[:3].to_upper()  # Abbreviate
        mat_label.add_theme_color_override("font_color", material.base_color)
        row_hbox.add_child(mat_label)
        
        # Cells (material × theme)
        for theme_idx in range(num_themes):
            var theme_color = theme_list[theme_idx]
            
            # Render a sample voxel under this theme
            var cell_rect = ColorRect.new()
            cell_rect.custom_minimum_size = Vector2(cell_width, cell_height)
            
            # Composite: material base color × theme (multiply)
            var composite_color = material.base_color * theme_color
            cell_rect.color = composite_color
            
            row_hbox.add_child(cell_rect)
        
        vbox.add_child(row_hbox)
    
    # Debug info at bottom
    var debug_label = Label.new()
    debug_label.text = "[D9 Discipline] Themes should have sat < 0.3 (normal) or doc'd as filter. No mud (sat×sat)."
    debug_label.add_theme_font_size_override("font_size", 10)
    debug_label.add_theme_color_override("font_color", Color.GRAY)
    vbox.add_child(debug_label)

func inspect_cell(material_id: String, theme_idx: int) -> void:
    # Drill-down: show detailed breakdown of a cell
    var material = material_registry.get_material(material_id)
    var theme = theme_list[theme_idx]
    
    var composite = material.base_color * theme
    
    print("[THEME MATRIX] %s × theme_%d:" % [material_id, theme_idx])
    print("  Material base: RGB(%.3f, %.3f, %.3f) HSV(%.1f°, %.1%%, %.1%%)" % [
        material.base_color.r, material.base_color.g, material.base_color.b,
        material.base_color.get_h() * 360, material.base_color.get_s() * 100, material.base_color.get_v() * 100
    ])
    print("  Theme:        RGB(%.3f, %.3f, %.3f) HSV(%.1f°, %.1%%, %.1%%)" % [
        theme.r, theme.g, theme.b,
        theme.get_h() * 360, theme.get_s() * 100, theme.get_v() * 100
    ])
    print("  Composite:    RGB(%.3f, %.3f, %.3f) HSV(%.1f°, %.1%%, %.1%%)" % [
        composite.r, composite.g, composite.b,
        composite.get_h() * 360, composite.get_s() * 100, composite.get_v() * 100
    ])
    print("  Verdict: %s" % _verdict(material, theme, composite))

func _verdict(material: Material, theme: Color, composite: Color) -> String:
    var theme_sat = theme.get_s()
    var composite_sat = composite.get_s()
    
    if theme_sat > 0.5 and material.base_color.get_s() > 0.3:
        return "⚠ Potential mud (both saturated); doc as intentional filter?"
    elif composite_sat < 0.05:
        return "✗ Grayscale result; material identity lost"
    else:
        return "✓ Acceptable"
```

### B.3 Selftest (T2, Render)

In `theme_matrix_debug_test.gd`:

```gdscript
func test_matrix_renders() -> void:
    var view = ThemeMatrixDebugView.new()
    view._ready()
    
    # Toggle on
    view.toggle()
    assert(view.is_active, "Matrix not active after toggle")
    
    # Check that children were added
    assert(view.get_child_count() > 0, "No children added to view")
    
    print("PASS: matrix_renders")

func test_inspect_cell_output() -> void:
    var view = ThemeMatrixDebugView.new()
    view._ready()
    
    # Inspect a material × theme combo
    view.inspect_cell("stone", 0)
    
    # Check console output (manual inspection; assert that function completes)
    print("PASS: inspect_cell_output")

func test_saturation_discipline() -> void:
    var registry = GLOBAL_MATERIAL_REGISTRY
    
    for material_id in registry.list_materials():
        var material = registry.get_material(material_id)
        
        # Material base color should be relatively desaturated (or intentional)
        var mat_sat = material.base_color.get_s()
        # No hard rule, but audit: high-sat materials should be noted
        if mat_sat > 0.7:
            print("AUDIT: %s base_color has high saturation (%.1f%%); verify intentional" % 
                  [material_id, mat_sat * 100])
    
    print("PASS: saturation_discipline (audit complete; inspect output)")
```

---

## Part C: Integration with Room Builder

In `room_builder.gd`, after themes are applied:

```gdscript
func _ready_debug_views() -> void:
    if Engine.is_editor_hint():
        return  # Skip in editor; debug views are for runtime only
    
    # Initialize Theme Matrix debug view
    var theme_matrix = ThemeMatrixDebugView.new()
    add_child(theme_matrix)
    theme_matrix._ready()
    
    print("[DEBUG] Theme Matrix available: press F5 to toggle")
```

---

## Part D: Theme Contract (MAP SPEC)

Maps declare their theme:

```gdscript
class MapSpec:
    var theme_color: Color = Color.WHITE  # Default neutral
    var theme_name: String = "default"    # Semantic label (for debug)
    
    # Example themes:
    # "normal": Color(0.95, 0.95, 1.0) - cool white
    # "alarm": Color(1.0, 0.2, 0.2) - red filter
    # "stealth": Color(0.2, 0.8, 0.2) - night vision green
    # "flooded": Color(0.3, 0.5, 1.0) - underwater blue (future)
```

---

## Part E: Rollout Checklist

Before BAKE-07 can start:

- [ ] `theme_applier.gd` written with apply/clear interface, logging.
- [ ] `theme_matrix_debug_view.gd` written with grid rendering (material × theme grid, F5 toggle).
- [ ] Integration: ThemeApplier called at map load; ThemeMatrix added to debug views.
- [ ] Selftest `theme_matrix_debug_test.gd` PASS achieved (renders, inspection, discipline audit).
- [ ] Console logs: theme application (RGB/HSV), saturation audit output.
- [ ] Visual inspection: Theme Matrix grid shows expected colors; no obvious mud (saturated × saturated).
- [ ] Evidence transcript appended to session archive.

---

*End of BAKE-06.*
