## CAPTURE_RAILS CR-2 — `CaptureFramer`: for the four views and the shapes a capture frames (a box, a point grown to the detail box,
## a whole 18 x 36 segment, PLAYGROUND's 44 x 22 with its ring), every corner lands on the canvas with the requested margin, the
## target fills the frame on its tighter axis, and the zoom a segment needs is below the gameplay floor (0.20) — the measurement that
## made the capture range necessary (§6.2). The REAL camera's agreement is `frame_check` in a boot, not this test.
extends SceneTree

const F = preload("res://godot/scripts/systems/capture/capture_framer.gd")
const PROFILES = preload("res://godot/scripts/systems/capture/capture_profiles.gd")

const CANVAS := Vector2(1280, 720)
const PX := 181.019   ## 128 / cos 45°, Board3DLive's px_per_unit

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	print(("  ✓ %s" if ok else "  ✗ FAILED: %s") % label)
	if not ok:
		_failures += 1


func _init() -> void:
	print("\n== CAPTURE FRAMER SELFTEST (CAPTURE_RAILS CR-2) ==\n")
	var cases: Array = [
		["a 3-storey pane wing", [AABB(Vector3(8, 0, 8), Vector3(20, 3, 13))], "wide"],
		["a point POI (detail grows it)", [AABB(Vector3(18, 1.5, 15), Vector3.ZERO)], "detail"],
		["an 18 x 36 segment, 2 storeys", [AABB(Vector3(5, 0, 5), Vector3(18, 2, 36))], "wide"],
		["PLAYGROUND + ring, 2.5 storeys", [AABB(Vector3(0, 0, 0), Vector3(54, 2.5, 32))], "wide"],
		["two boxes together", [AABB(Vector3(5, 0, 5), Vector3(2, 1, 2)), AABB(Vector3(30, 0, 20), Vector3(2, 2, 2))], "fit"],
	]
	for view: String in ["N", "E", "S", "W"]:
		var yaw: float = F.VIEW_YAW[view]
		for c: Array in cases:
			var pose: Dictionary = F.frame(c[1], c[2], yaw, CANVAS, PX)
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for box: AABB in c[1]:
				var bx: AABB = F._grow_to_min(box) if c[2] == "detail" else box
				for i: int in range(8):
					var s: Vector2 = F.project(bx.get_endpoint(i), pose["ground_centre"], pose["zoom"], yaw, CANVAS, PX)
					lo = lo.min(s)
					hi = hi.max(s)
			var margin: float = minf(minf(lo.x, CANVAS.x - hi.x), minf(lo.y, CANVAS.y - hi.y))
			var fill: float = maxf((hi.x - lo.x) / CANVAS.x, (hi.y - lo.y) / CANVAS.y)
			var centred: bool = ((lo + hi) * 0.5).distance_to(CANVAS * 0.5) < 1.0
			_check(margin >= 0.0 and fill > 0.75 and fill <= 1.0 and centred,
				"view %s, %s: inside (margin %.0f px), fills %.0f%% of its tighter axis, centred" % [view, c[0], margin, fill * 100.0])
	var seg: Dictionary = F.frame([AABB(Vector3(5, 0, 5), Vector3(18, 2, 36))], "wide", 0.0, CANVAS, PX)
	_check(seg["zoom"] < 0.20 and seg["fits"], "a whole segment needs zoom %.3f, below the gameplay floor 0.20: the capture range is needed" % seg["zoom"])
	var centre_px: Vector2 = F.project(Vector3(seg["ground_centre"].x, 0.0, seg["ground_centre"].y), seg["ground_centre"], seg["zoom"], 0.0, CANVAS, PX)
	_check(centre_px.distance_to(CANVAS * 0.5) < 0.01, "the ground centre projects to the canvas centre")
	print("[2] the profiles file")
	var eng: Dictionary = PROFILES.resolve("engine")
	_check(eng["ok"] and eng["window"] == Vector2i(1920, 1080) and not eng["hud"] and eng["framing"] == "desktop" and eng["turn"] == "orbit",
		"engine: desktop 1920x1080, HUD hidden, orbit while developing (R6, R5, R9)")
	var ui_p: Dictionary = PROFILES.resolve("ui", "portrait")
	var ui_l: Dictionary = PROFILES.resolve("ui", "landscape")
	_check(ui_p["ok"] and ui_p["hud"] and ui_p["framing"] == "portrait" and ui_l["framing"] == "desktop", "ui: HUD shown, both shapes (R7)")
	_check(not PROFILES.resolve("cinema")["ok"], "an unknown profile is an error")
	print("\n%s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)
