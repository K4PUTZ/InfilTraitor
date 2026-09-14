## WorldRenderScale — the world renders below the screen's resolution; the HUD does not.
##
## TEL-UI-02 (DEVICE_DIAGNOSTICS_MASTER_PLAN §13 Q9). Director, 2026-09-14: *"Pode
## seguir com o TEL-UI-02, escala 0,75"*. DIAG-17 (§10.17.4) measured pixel fill at
## 36–47 ms of the Moto's GPU frame at every zoom, and rendering the whole 2D at the
## canvas size took the idle frame 60 → 23.8 ms — but that instrument also upscaled
## the HUD. This renders only the WORLD at a fraction of the screen's pixels.
##
## HOW — the world is drawn once, by a SubViewport, and never by the root viewport:
##  - The SubViewport SHARES the root's World2D. No world node moves in the tree:
##    `get_viewport()` still answers the root, and input picking (`_screen_to_tile()`,
##    which reads the root's canvas transform) is untouched.
##  - Its canvas transform is the root's (the camera's), scaled to its own pixels, and
##    copied on `RenderingServer.frame_pre_draw` so it never lags the camera a frame.
##  - Its texture is shown by a TextureRect in a CanvasLayer at layer -1, beneath the
##    fog and the HUD.
##  - The root viewport's `canvas_cull_mask` keeps ONLY `MAIN_BIT`, which every
##    CanvasItem inside one of the root's CanvasLayers carries (added as it enters the
##    tree). So the root draws the HUD, the fog and the scaled world — and not the
##    world a second time.
##
## PROVEN before it was wired — a standalone spike on this engine build, desktop, real
## captures (2026-09-14): world content on the same pixel with the scale on and off, a
## HUD rect's pixel box identical, and with the displayed texture hidden the root
## viewport held ZERO world pixels. The root had really stopped drawing the world.
##
## ⚠️ EACH AXIS HAS ITS OWN SCALE. The spike scaled both axes by the width's ratio;
## rounding the SubViewport's height to whole pixels made the vertical ratio differ by
## 0.16%, and world content drifted ~1.5 px down the screen. Each axis is scaled by its
## own pixel ratio here, so a world point maps onto the display rect exactly.
##
## At 1.0 the mechanism is OFF — no SubViewport exists and the cull mask is every bit —
## so D (§13 Q8) is the unscaled path itself, not a 1.0 copy of this one.
##
## Shaders that read the screen (`glass_pane`, the explosion flash) are world nodes, so
## they read the SubViewport's own screen: the world, as before. `vision_fog` reads only
## SCREEN_UV and stays in the root, drawn over the scaled world.
extends Node

const MAIN_BIT: int = 1 << 31
const EVERY_BIT: int = 0xFFFFFFFF
const MIN_SCALE: float = 0.25

var _scale: float = 1.0
var _sub: SubViewport = null
var _layer: CanvasLayer = null
var _display: TextureRect = null
var _measure: bool = false


func current_scale() -> float:
	return _scale


func is_active() -> bool:
	return _sub != null


## The pixels the world is rendered at — the screen's own when inactive.
func render_size() -> Vector2i:
	return _sub.size if _sub != null else DisplayServer.window_get_size()


func viewport_rid() -> RID:
	return _sub.get_viewport_rid() if _sub != null else RID()


## The frame probe turns this on. A probe that read only the root viewport would stop
## counting the world's GPU time the moment the world moved into the SubViewport, and
## report a saving that never happened.
func set_measure(enabled: bool) -> void:
	_measure = enabled
	if _sub != null:
		RenderingServer.viewport_set_measure_render_time(_sub.get_viewport_rid(), enabled)


func apply(scale: float) -> void:
	var target: float = clampf(scale, MIN_SCALE, 1.0)
	if target >= 0.999:
		_disable()
		return
	_scale = target
	if _sub == null:
		_build()
	_sync()


func _build() -> void:
	var root: Window = get_tree().root
	_sub = SubViewport.new()
	_sub.name = "WorldSubViewport"
	_sub.world_2d = root.world_2d
	_sub.canvas_cull_mask = EVERY_BIT & ~MAIN_BIT
	_sub.canvas_item_default_texture_filter = root.canvas_item_default_texture_filter
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub)
	if _measure:
		RenderingServer.viewport_set_measure_render_time(_sub.get_viewport_rid(), true)

	_layer = CanvasLayer.new()
	_layer.name = "WorldRenderScaleLayer"
	_layer.layer = -1
	_display = TextureRect.new()
	_display.texture = _sub.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_display)
	add_child(_layer)

	for node in _descendants(root):
		_mark_if_root_layer_item(node)
	get_tree().node_added.connect(_mark_if_root_layer_item)
	root.canvas_cull_mask = MAIN_BIT
	RenderingServer.frame_pre_draw.connect(_sync)


func _disable() -> void:
	_scale = 1.0
	if _sub == null:
		return
	RenderingServer.frame_pre_draw.disconnect(_sync)
	if get_tree().node_added.is_connected(_mark_if_root_layer_item):
		get_tree().node_added.disconnect(_mark_if_root_layer_item)
	get_tree().root.canvas_cull_mask = EVERY_BIT
	_sub.queue_free()
	_layer.queue_free()
	_sub = null
	_layer = null
	_display = null


func _exit_tree() -> void:
	## A map reload or quit must not leave the root viewport culling the world.
	_disable()


## Copy the camera's transform into the SubViewport, scaled per axis to its pixels.
func _sync() -> void:
	if _sub == null or not is_inside_tree():
		return
	var root: Window = get_tree().root
	var visible: Vector2 = root.get_visible_rect().size
	if visible.x <= 0.0 or visible.y <= 0.0:
		return
	## The screen pixels the visible canvas actually covers — the whole window under
	## EXPAND, which is what M uses.
	var covered: Vector2 = visible * root.get_final_transform().get_scale()
	var want: Vector2i = Vector2i(maxi(1, roundi(covered.x * _scale)),
		maxi(1, roundi(covered.y * _scale)))
	if _sub.size != want:
		_sub.size = want
	var sx: float = float(want.x) / visible.x
	var sy: float = float(want.y) / visible.y
	_sub.canvas_transform = Transform2D(Vector2(sx, 0.0), Vector2(0.0, sy), Vector2.ZERO) \
		* root.get_canvas_transform()


## An item in one of the ROOT viewport's CanvasLayers is screen UI (HUD, fog, the
## display itself) and must stay visible to the root. A world item, or anything inside
## another viewport (the showcase panel's 3D SubViewport), is left alone.
func _mark_if_root_layer_item(node: Node) -> void:
	if not node is CanvasItem:
		return
	var item: CanvasItem = node
	if item.get_viewport() != get_tree().root or item.get_canvas_layer_node() == null:
		return
	item.visibility_layer = item.visibility_layer | MAIN_BIT


func _descendants(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_descendants(child))
	return out
