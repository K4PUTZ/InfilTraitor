## CaptureFramer — framing that is COMPUTED, never typed (CAPTURE_RAILS_MASTER_PLAN §6.3). Pure: no nodes, no state.
##
## The board's camera (`Board3DLive._make_camera()` / `_process()`): orthographic, KEEP_HEIGHT, pitch -30°, yaw 45° + the view's yaw,
## looking at a GROUND point (y = 0) with `size = canvas_height / zoom / px_per_unit`. So a set of world points fits when their
## extents along the camera's right and up axes fit `size × aspect` by `size`; the centre of those extents is the screen centre, and
## the ground point that projects there is a 2 × 2 solve (always solvable: the pitch is not zero). Depth never matters (orthographic).
##
## Input boxes are WORLD AABBs (`MapLayout.to_world_box()`); output `ground_centre` is the world (x, z) the camera must look at.
extends RefCounted

const PITCH_DEG: float = -30.0
const BASE_YAW_DEG: float = 45.0
const VIEW_YAW: Dictionary = {"N": 0.0, "E": 90.0, "S": 180.0, "W": 270.0}   ## = Board3DLive.VIEW_YAW_DEG
const MARGIN: Dictionary = {"wide": 0.10, "detail": 0.05, "fit": 0.08}
## The capture's own zoom range (the gameplay clamp 0.20 .. 1.20 is right for the player and wrong for a capture: §6.2).
const ZOOM_MIN: float = 0.08
const ZOOM_MAX: float = 2.0
## A point framed in `detail` grows to this box around it (x, height, y in world units), so it still frames a scene.
const DETAIL_MIN_BOX: Vector3 = Vector3(3.0, 1.0, 3.0)


## The camera basis for a yaw in degrees (a view's yaw, or any yaw while a rail orbits). Node3D's rotation order is YXZ.
static func basis_for_yaw(yaw_deg: float) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(PITCH_DEG), deg_to_rad(BASE_YAW_DEG + yaw_deg), 0.0))


## `boxes`: world AABBs (a zero-size AABB is a point). `mode`: wide / detail / fit. Returns
## `{ground_centre: Vector2 (world x, z), zoom: float, fits: bool, size: float (world units of height)}`.
static func frame(boxes: Array, mode: String, yaw_deg: float, canvas: Vector2, px_per_unit: float) -> Dictionary:
	var b: Basis = basis_for_yaw(yaw_deg)
	var right: Vector3 = b.x
	var up: Vector3 = b.y
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for box: AABB in boxes:
		var bx: AABB = box
		if mode == "detail":
			bx = _grow_to_min(bx)
		for i: int in range(8):
			var p: Vector3 = bx.get_endpoint(i)
			var s := Vector2(p.dot(right), p.dot(up))
			lo = lo.min(s)
			hi = hi.max(s)
	var aspect: float = canvas.x / maxf(canvas.y, 1.0)
	var ext: Vector2 = hi - lo
	var margin: float = float(MARGIN.get(mode, 0.08))
	var size: float = maxf(ext.y, ext.x / aspect) * (1.0 + 2.0 * margin)
	size = maxf(size, 0.5)
	var mid: Vector2 = (lo + hi) * 0.5
	## T = (tx, 0, tz) with T·right = mid.x and T·up = mid.y.
	var det: float = right.x * up.z - right.z * up.x
	var tx: float = (mid.x * up.z - right.z * mid.y) / det
	var tz: float = (right.x * mid.y - mid.x * up.x) / det
	var zoom_raw: float = canvas.y / (size * px_per_unit)
	var zoom: float = clampf(zoom_raw, ZOOM_MIN, ZOOM_MAX)
	return {"ground_centre": Vector2(tx, tz), "zoom": zoom, "fits": is_equal_approx(zoom, zoom_raw) or zoom_raw > ZOOM_MAX,
		"size": canvas.y / (zoom * px_per_unit)}


## Where a world point lands on a canvas for a pose (the same projection the camera makes), in canvas pixels with (0, 0) top-left.
## The framer's own check; `frame_check` asks the REAL camera instead.
static func project(p: Vector3, ground_centre: Vector2, zoom: float, yaw_deg: float, canvas: Vector2, px_per_unit: float) -> Vector2:
	var b: Basis = basis_for_yaw(yaw_deg)
	var t := Vector3(ground_centre.x, 0.0, ground_centre.y)
	var px: float = zoom * px_per_unit
	return canvas * 0.5 + Vector2((p - t).dot(b.x), -(p - t).dot(b.y)) * px


static func _grow_to_min(box: AABB) -> AABB:
	var size: Vector3 = box.size.max(DETAIL_MIN_BOX)
	var c: Vector3 = box.get_center()
	var pos: Vector3 = c - size * 0.5
	pos.y = maxf(0.0, minf(box.position.y, c.y - size.y * 0.5))
	return AABB(pos, size)
