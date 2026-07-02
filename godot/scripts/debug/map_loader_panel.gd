extends CanvasLayer
## DEBUG-01: Map loader panel — F2 toggle to reload the map with different settings.
## Displays registered map IDs from MapCatalog.list_map_ids(), allows selecting height
## and seed override, then calls room.load_map() to reload.

const MapCatalogClass = preload("res://godot/scripts/world/maps/map_catalog.gd")

var _room: Node2D = null
var _map_list: ItemList = null
var _height_spinbox: SpinBox = null
var _seed_spinbox: SpinBox = null
var _btn_load: Button = null
var _btn_cancel: Button = null


func setup(room: Node2D) -> void:
	_room = room
	_build_ui()
	visible = false
	layer = 1000


func _build_ui() -> void:
	## Main background panel
	var panel := Control.new()
	add_child(panel)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -200.0
	panel.offset_top = -200.0
	panel.custom_minimum_size = Vector2(400.0, 400.0)

	var bg := ColorRect.new()
	panel.add_child(bg)
	bg.color = Color(0.0, 0.0, 0.0, 0.85)
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0

	## Container
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 8)
	var margin = vbox.add_theme_constant_override("margin_left", 12)
	vbox.add_theme_constant_override("margin_right", 12)
	vbox.add_theme_constant_override("margin_top", 12)
	vbox.add_theme_constant_override("margin_bottom", 12)

	## Title
	var title := Label.new()
	title.text = "Map Loader"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	vbox.add_child(title)

	## Map ID list
	var map_label := Label.new()
	map_label.text = "Map ID:"
	map_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(map_label)

	_map_list = ItemList.new()
	_map_list.custom_minimum_size = Vector2(350.0, 80.0)
	vbox.add_child(_map_list)
	var map_ids := MapCatalogClass.list_map_ids()
	for map_id in map_ids:
		_map_list.add_item(map_id)
	if _map_list.item_count > 0:
		_map_list.select(0)
	_map_list.item_selected.connect(_on_map_selected)

	## Wall height
	var height_label := Label.new()
	height_label.text = "Wall Height:"
	height_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(height_label)

	_height_spinbox = SpinBox.new()
	_height_spinbox.min_value = 0
	_height_spinbox.max_value = 8
	_height_spinbox.value = 0
	_height_spinbox.custom_minimum_size = Vector2(350.0, 0.0)
	vbox.add_child(_height_spinbox)

	## Seed
	var seed_label := Label.new()
	seed_label.text = "Seed:"
	seed_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(seed_label)

	_seed_spinbox = SpinBox.new()
	_seed_spinbox.min_value = 0
	_seed_spinbox.max_value = 999999
	_seed_spinbox.value = 0
	_seed_spinbox.custom_minimum_size = Vector2(350.0, 0.0)
	vbox.add_child(_seed_spinbox)

	## Buttons
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(hbox)

	_btn_load = Button.new()
	_btn_load.text = "Load"
	_btn_load.custom_minimum_size = Vector2(150.0, 30.0)
	_btn_load.pressed.connect(_on_load_pressed)
	hbox.add_child(_btn_load)

	_btn_cancel = Button.new()
	_btn_cancel.text = "Cancel"
	_btn_cancel.custom_minimum_size = Vector2(150.0, 30.0)
	_btn_cancel.pressed.connect(_on_cancel_pressed)
	hbox.add_child(_btn_cancel)


func _on_map_selected(_index: int) -> void:
	pass


func _on_load_pressed() -> void:
	var selected_items := _map_list.get_selected_items()
	if selected_items.size() > 0:
		var selected_index := selected_items[0]
		var map_ids := MapCatalogClass.list_map_ids()
		if selected_index >= 0 and selected_index < map_ids.size():
			var selected_map_id := map_ids[selected_index]
			var height := int(_height_spinbox.value)
			var seed := int(_seed_spinbox.value)
			_room.load_map(selected_map_id, height, seed)
			visible = false


func _on_cancel_pressed() -> void:
	visible = false


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
