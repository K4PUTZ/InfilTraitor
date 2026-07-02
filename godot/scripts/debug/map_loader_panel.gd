extends ConfirmationDialog
## DEBUG-01: Map loader panel — toggles to reload the map with different settings.

const MapCatalogClass = preload("res://godot/scripts/world/maps/map_catalog.gd")

var _room: Node2D = null
var _map_list: OptionButton = null
var _height_spinbox: SpinBox = null
var _seed_spinbox: SpinBox = null


func setup(room: Node2D) -> void:
	_room = room
	title = "Map Loader"
	confirmed.connect(_on_load_pressed)
	canceled.connect(_on_cancel_pressed)
	_build_ui()
	print("DEBUG: Map loader panel initialized")


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)

	## Map ID dropdown
	var map_label := Label.new()
	map_label.text = "Map ID:"
	vbox.add_child(map_label)

	_map_list = OptionButton.new()
	vbox.add_child(_map_list)
	var map_ids := MapCatalogClass.list_map_ids()
	for i in range(map_ids.size()):
		_map_list.add_item(map_ids[i], i)
	_map_list.select(0)

	## Wall height
	var height_label := Label.new()
	height_label.text = "Wall Height:"
	vbox.add_child(height_label)

	_height_spinbox = SpinBox.new()
	_height_spinbox.min_value = 0
	_height_spinbox.max_value = 8
	_height_spinbox.value = 0
	vbox.add_child(_height_spinbox)

	## Seed
	var seed_label := Label.new()
	seed_label.text = "Seed:"
	vbox.add_child(seed_label)

	_seed_spinbox = SpinBox.new()
	_seed_spinbox.min_value = 0
	_seed_spinbox.max_value = 999999
	_seed_spinbox.value = 0
	vbox.add_child(_seed_spinbox)

	ok_button_text = "Load"
	cancel_button_text = "Cancel"


func _on_load_pressed() -> void:
	var selected_index := _map_list.get_selected()
	var map_ids := MapCatalogClass.list_map_ids()
	if selected_index >= 0 and selected_index < map_ids.size():
		var selected_map_id := map_ids[selected_index]
		var height := int(_height_spinbox.value)
		var seed := int(_seed_spinbox.value)
		print("DEBUG: Loading map '%s' with height %d, seed %d" % [selected_map_id, height, seed])
		_room.load_map(selected_map_id, height, seed)


func _on_cancel_pressed() -> void:
	print("DEBUG: Map loader cancelled")
