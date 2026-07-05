## ThemeMatrixDebugView — Visual grid showing all materials × all themes
##
## Reveals saturation issues before they reach gameplay.
## Press F5 to toggle visibility.

class_name ThemeMatrixDebugView
extends CanvasLayer

var is_active: bool = false
var material_registry
var theme_list: Array[Color] = []
var _panel_container: PanelContainer = null


func _ready() -> void:
	# Fetch material registry (global or mock)
	if Engine.has_meta("GLOBAL_MATERIAL_REGISTRY"):
		material_registry = Engine.get_meta("GLOBAL_MATERIAL_REGISTRY")
	else:
		push_warning("[THEME MATRIX] No GLOBAL_MATERIAL_REGISTRY found; using fallback")
		material_registry = null

	# Populate theme list (from map spec or predefined set)
	theme_list = [
		Color(0.95, 0.95, 1.0),   # Cool white (normal)
		Color(1.0, 0.2, 0.2),     # Alarm red
		Color(0.2, 0.8, 0.2),     # Stealth green
		Color(0.5, 0.5, 0.5),     # Darken (night)
	]

	# Start invisible
	visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# F5 toggles Theme Matrix
		if event.keycode == KEY_F5:
			toggle()
			get_tree().root.set_input_as_handled()


func toggle() -> void:
	is_active = !is_active
	visible = is_active
	if is_active:
		render_matrix()
		print("[THEME] F5: Grid visible")
	else:
		# Clean up old panel
		if _panel_container and is_instance_valid(_panel_container):
			_panel_container.queue_free()
			_panel_container = null
		print("[THEME] F5: Grid hidden")


func render_matrix() -> void:
	# Clean up old panel if exists
	if _panel_container and is_instance_valid(_panel_container):
		_panel_container.queue_free()

	if not material_registry:
		push_error("[THEME MATRIX] No material registry; cannot render")
		return

	var materials = material_registry.list_materials()
	if materials.is_empty():
		push_error("[THEME MATRIX] No materials in registry")
		return

	var num_materials = materials.size()
	var num_themes = theme_list.size()

	# Grid dimensions
	var cell_width = 64
	var cell_height = 64
	var gap = 8
	var label_width = 60
	var label_height = 20

	var grid_width = label_width + num_themes * (cell_width + gap) + gap
	var grid_height = label_height + num_materials * (cell_height + gap) + gap

	# Create panel
	_panel_container = PanelContainer.new()
	_panel_container.custom_minimum_size = Vector2(grid_width + 20, grid_height + 100)
	add_child(_panel_container)

	# Main VBox
	var vbox = VBoxContainer.new()
	_panel_container.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "THEME MATRIX (F5 to hide)"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	# Instructions text (S3: FIX-BAKE-06)
	var instructions = Label.new()
	instructions.text = """D9 Saturation Discipline:
• Facade: grayscale (R=G=B)
• Material base color: desaturated or intentional tone
• Themes: soft tints (moderate sat, high val) or dominant filter
• Result (cell): (base_color × theme × facade_lum)
• If muddy (low sat, low val): reduce theme saturation"""
	instructions.add_theme_font_size_override("font_size", 8)
	instructions.add_theme_color_override("font_color", Color.GRAY)
	instructions.custom_minimum_size = Vector2(0, 80)
	instructions.clip_text = true
	vbox.add_child(instructions)

	# Header row (themes)
	var header_hbox = HBoxContainer.new()
	var blank_label = Label.new()
	blank_label.custom_minimum_size = Vector2(label_width, 0)
	blank_label.text = ""
	header_hbox.add_child(blank_label)

	for theme_idx in range(num_themes):
		var theme_label = Label.new()
		var theme_color = theme_list[theme_idx]
		theme_label.text = "T%d" % theme_idx
		theme_label.custom_minimum_size = Vector2(cell_width, 0)
		theme_label.add_theme_color_override("font_color", theme_color)
		theme_label.add_theme_font_size_override("font_size", 10)
		header_hbox.add_child(theme_label)

	vbox.add_child(header_hbox)

	# Rows (materials)
	for mat_idx in range(num_materials):
		var material_id = materials[mat_idx]
		var material = material_registry.get_material(material_id)

		var row_hbox = HBoxContainer.new()

		# Material label
		var mat_label = Label.new()
		mat_label.text = material_id.substr(0, 3).to_upper()
		mat_label.custom_minimum_size = Vector2(label_width, 0)
		mat_label.add_theme_font_size_override("font_size", 10)
		if material and material.has_method("get") and "base_color" in material:
			mat_label.add_theme_color_override("font_color", material.base_color)
		row_hbox.add_child(mat_label)

		# Cells (material × theme)
		for theme_idx in range(num_themes):
			var theme_color = theme_list[theme_idx]

			# Composite: material base color × theme (multiply)
			var composite_color = Color.WHITE
			if material and material.has_method("get") and "base_color" in material:
				composite_color = material.base_color * theme_color
			else:
				composite_color = theme_color

			var cell_rect = ColorRect.new()
			cell_rect.color = composite_color
			cell_rect.custom_minimum_size = Vector2(cell_width, cell_height)
			row_hbox.add_child(cell_rect)

		vbox.add_child(row_hbox)

	# Debug info at bottom
	var debug_label = Label.new()
	debug_label.text = "[D9] Themes should be desaturated (normal) or documented as filter. Avoid mud (sat×sat)."
	debug_label.add_theme_font_size_override("font_size", 9)
	debug_label.add_theme_color_override("font_color", Color.GRAY)
	vbox.add_child(debug_label)


func inspect_cell(material_id: String, theme_idx: int) -> void:
	if not material_registry:
		push_error("[THEME MATRIX] No material registry")
		return

	var material = material_registry.get_material(material_id)
	if not material:
		push_error("[THEME MATRIX] Material '%s' not found" % material_id)
		return

	if theme_idx < 0 or theme_idx >= theme_list.size():
		push_error("[THEME MATRIX] Theme index %d out of range" % theme_idx)
		return

	var mat_color = Color.WHITE
	if material.has_method("get") and "base_color" in material:
		mat_color = material.base_color

	var theme = theme_list[theme_idx]
	var composite = mat_color * theme

	print("[THEME MATRIX] %s × theme_%d:" % [material_id, theme_idx])
	print("  Material:  RGB(%.3f, %.3f, %.3f)" % [mat_color.r, mat_color.g, mat_color.b])
	print("  Theme:     RGB(%.3f, %.3f, %.3f)" % [theme.r, theme.g, theme.b])
	print("  Composite: RGB(%.3f, %.3f, %.3f)" % [composite.r, composite.g, composite.b])
	print("  Verdict: %s" % _verdict(mat_color, theme, composite))


func _verdict(_material_color: Color, _theme: Color, composite: Color) -> String:
	# Simple saturation check: if composite is near-gray (all channels similar), identity lost
	var r = composite.r
	var g = composite.g
	var b = composite.b
	var max_ch = maxf(r, maxf(g, b))
	var min_ch = minf(r, minf(g, b))
	var range_ch = max_ch - min_ch

	if range_ch < 0.05:
		return "✗ Grayscale result; material identity lost"
	else:
		return "✓ Acceptable"
