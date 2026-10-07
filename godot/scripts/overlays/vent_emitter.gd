## VentEmitter — a steady plume rising from a floor vent (R3D-SURFACES SM-6, 2026-10-06; DS-14: "um vapor subindo pela grade por enquanto").
##
## The map's `ground_vents` section places vents (a grating over a vent shaft, a roof outlet) and this node makes each one breathe: every
## `interval` seconds a vent releases a small puff through `emit`, which the `Room` turns into `SmokeSparkOverlay.add_smoke()` (the existing
## world-space, depth-tested smoke, one draw call). COSMETIC like every floor mark: nothing is saved and nothing is gameplay. Each vent has its
## own phase (a hash of its position, never a RNG), so a row of vents does not pulse in step and every run looks the same (B4).
##
## The timing is pure (`step()` returns what to emit and touches nothing else), so the selftest pins it without a renderer.
class_name VentEmitter
extends Node

## Per kind: the puff's colour, size, rise and how often the vent releases one. `steam` is the only kind (water, lava and the liquid
## materials are a parked track, DS-14).
static var KINDS: Dictionary = {
	"steam": {"color": Color(0.94, 0.96, 0.98, 0.5), "scale": 2.4, "duration_scale": 3.2, "blobs": 2, "drift_scale": 1.0, "interval": 0.26,
			"style": {"growth": 4.2, "wind": Vector2(-30.0, 0.0), "damp": 0.92, "fade": 1.0}},
}

var _vents: Array = []        ## {"at": Vector2 (GU), "kind": String, "next": float}
var _clock: float = 0.0
var _emit: Callable = Callable()


## `instances`: the compiler's `ground_vent_instances` (`at` in raw GU, `depth` "floor" or "shaft": where the plume is born, at the floor top or at the
## bottom of a `floor_openings` shaft, so the bars hide it and release it by depth). `emit`: `Callable(at: Vector2, kind: String, params: Dictionary, depth: String)`.
func setup(instances: Array, emit: Callable) -> void:
	_emit = emit
	_vents.clear()
	_clock = 0.0
	for inst in instances:
		var kind: String = String(inst.get("kind", ""))
		if not KINDS.has(kind):
			push_error("[VentEmitter] vent kind '%s' is not one of %s: skipped" % [kind, KINDS.keys()])
			continue
		var at: Vector2 = inst["at"]
		var interval: float = float(KINDS[kind]["interval"])
		_vents.append({"at": at, "kind": kind, "depth": String(inst.get("depth", "floor")), "next": _phase(kind, at) * interval})
	set_process(not _vents.is_empty())


func count() -> int:
	return _vents.size()


func clear() -> void:
	_vents.clear()
	set_process(false)


func _process(delta: float) -> void:
	for emission: Dictionary in step(delta):
		if _emit.is_valid():
			_emit.call(emission["at"], emission["kind"], KINDS[emission["kind"]], emission["depth"])


## Advances the clock by `delta` seconds and returns the puffs released in it: `[{"at", "kind"}]`. A long `delta` (a hitch) releases a vent's
## puffs one after the other, never a burst on one frame beyond what the interval allows.
func step(delta: float) -> Array:
	var out: Array = []
	_clock += delta
	for vent: Dictionary in _vents:
		var interval: float = float(KINDS[vent["kind"]]["interval"])
		var guard: int = 0
		while float(vent["next"]) <= _clock and guard < 4:
			out.append({"at": vent["at"], "kind": vent["kind"], "depth": vent["depth"]})
			vent["next"] = float(vent["next"]) + interval
			guard += 1
		if guard == 4:
			vent["next"] = _clock + interval
	return out


## A vent's phase in [0, 1): a hash of where it is, so neighbours are out of step and a rerun is identical.
static func _phase(kind: String, at: Vector2) -> float:
	return float(FacadeSampler._fnv1a_hash("%s|%d|%d" % [kind, int(round(at.x * 8.0)), int(round(at.y * 8.0))]) % 100003) / 100003.0
