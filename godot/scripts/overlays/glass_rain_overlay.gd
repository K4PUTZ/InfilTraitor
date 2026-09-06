extends Node2D
class_name GlassRainOverlay

## GLASS G6b-2 / G-D43 + G-D44 — THE FALLING SHARDS.
##
## (Director, 2026-09-05: *"caem no chão, dão um leve bounce […] Os cacos caem no
## chão, apagam e revelam um sprite padrão por trás."*)
##
## One `ShardField` (G6b-1, one draw call) plus a closed-form trajectory. Nothing
## here is state: G-D43 makes the rain DISPOSABLE — the G6 pile decal is the only
## permanent record of "there is broken glass here", it is already drawn beneath
## these shards before the first one moves, and this overlay frees itself when the
## last piece has faded.
##
## ⚠️ **THAT IS WHY IT IS SAFE TO INTERRUPT.** A rain cut short by a stall, by an
## off-screen pane or by a perf budget leaves the floor exactly right. Pinned by
## `glass_rain_demo`'s control, which kills the rain mid-flight and diffs the floor
## against the frame before it was ever spawned.
##
## ── AGED IN FRAMES, NEVER IN SECONDS ────────────────────────────────────────
##
## ⚠️ It is spawned on the detonation's COMMIT FRAME — the frame that mints, applies
## the light field and stalls. A `delta`-driven animation started there plays its
## entire life inside one stalled frame and the player sees the resting floor with
## no fall at all. `EmberOverlay` and the strobe learned this the same way.
##
## ⚠️ And the standing consequence, which no gate can catch: a frame-denominated
## look value is silently retuned by every perf change. The detonation's own blast
## was shortened 4.9x once for exactly this reason.
##
## ── THE TRAJECTORY IS CLOSED FORM ───────────────────────────────────────────
##
## *"acho que a gente conseguiria manipular essas animações pra elas ficarem
## padronizadas e pré-computadas, já que a aparência vai ser sempre parecida."*
## One scalar per shard and a handful of constants — no integration, no
## per-particle state machine, no collision:
##
##     fall    p(t) = lerp(from, to, ease_out(t)) - arc * sin(PI * t)   [t in 0..1]
##     bounce  one damped repeat at BOUNCE_SCALE of the arc
##     spin    theta0 + omega * min(t, 1), frozen the moment it lands
##     fade    hold, then alpha to zero over the pile decal beneath it
##
## Every parameter is hashed off the shard's own cell (B4's FNV-1a, never `randf`),
## so a filmstrip of one event replays exactly — which is the only reason this
## animation can be photographed at all (`glass_blast_demo` cannot: it rolls its
## embers with `randf_range`).

const ShardFieldClass = preload("res://godot/scripts/overlays/shard_field.gd")
const ShardShapes = preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")
const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")

## ── LOOK VALUES, ALL FRAMES, ALL `var` (Rule 1) ─────────────────────────────
var fall_frames_min: int = 14        ## the drop itself
var fall_frames_max: int = 26
var stagger_frames: int = 10         ## spread of launch times across the pane
var bounce_frames: int = 7           ## the "leve bounce"
var bounce_scale: float = 0.16       ## fraction of the fall's arc height
var hold_frames: int = 26            ## settled, before it starts to go
var fade_frames: int = 18            ## and the fade that reveals the pile
var arc_px_min: float = 6.0          ## lift at the top of the fall's parabola
var arc_px_max: float = 22.0
var spin_min: float = -0.16          ## radians per frame while airborne
var spin_max: float = 0.16
var tint: Color = Color(0.77, 0.91, 0.96, 0.95)

## ⚠️ A CAP, AND IT IS HONEST ABOUT WHAT IT IS FOR. Instance buffer writes are
## per-frame DURING FLIGHT, and under G-D43 the flight is the only cost there is —
## dropping shards under budget is free, because none of them are state.
var max_shards: int = 3000

var _field = null
var _shards: Array = []              ## [{from, to, arc, spin, size, shape, flip, flop, t0, fall}]
var _frame: int = 0
var _span: int = 0                   ## the last frame any shard is still visible


## ⚠️ LAZY, NOT `_ready()`-ONLY. The overlay has to be usable the instant it is
## constructed — a selftest drives `spawn()` and `_process()` without waiting a
## frame, and with the field built only in `_ready()` the first `_process` reached
## a null and raised a SCRIPT ERROR that left the suite printing "0 FAIL". (The
## runner caught it, which is the entire reason `run_selftests.py` is the arbiter
## and a bare `godot --script` run is not.)
func _ensure_field():
	if _field == null:
		_field = ShardFieldClass.new()
		_field.attach(self)
	return _field


func _ready() -> void:
	_ensure_field()


## Spawn one event's worth of rain.
##
## `flights` — `Array[{"from": Vector2, "to": Vector2, "key": Vector3i}]` in world
## pixels; `key` is the shard's BASE-space cell, and every hashed parameter comes
## off it so the same event replays identically.
##
## G-D44: one destroyed voxel yields 1 to 4 pieces (area is conserved, and a piece
## of edge 0.5-1.0 has area 0.25-1.0), so the caller passes one flight per VOXEL
## and the split happens here.
func spawn(flights: Array, pieces_per_voxel_max: int = 4) -> int:
	_ensure_field()
	for f in flights:
		var key: Vector3i = f["key"]
		var from: Vector2 = f["from"]
		var to: Vector2 = f["to"]
		var n: int = 1 + int(_hash_unit(key, "count") * float(maxi(pieces_per_voxel_max, 1)) * 0.999)
		for p in range(n):
			if _shards.size() >= max_shards:
				break
			var salt := "%d" % p
			var target: float = lerpf(ShardShapes.TARGET_MIN, ShardShapes.TARGET_MAX,
				_hash_unit(key, "size" + salt))
			var fall: int = int(lerpf(float(fall_frames_min), float(fall_frames_max),
				_hash_unit(key, "fall" + salt)))
			var t0: int = int(_hash_unit(key, "t0" + salt) * float(stagger_frames))
			## The pieces of one voxel do not all land on the same pixel: a small
			## sub-cell offset, hashed, so a pile reads as a scatter and not as a
			## stack. ⚠️ It moves only where the shard DRAWS, never the landing CELL
			## the G6 pile was recorded at — that one is state.
			var jitter := Vector2(
				(_hash_unit(key, "jx" + salt) - 0.5) * 22.0,
				(_hash_unit(key, "jy" + salt) - 0.5) * 11.0)
			_shards.append({
				"from": from,
				"to": to + jitter,
				"arc": lerpf(arc_px_min, arc_px_max, _hash_unit(key, "arc" + salt)),
				"spin": lerpf(spin_min, spin_max, _hash_unit(key, "spin" + salt)),
				"size": GeometryCoords.VOXEL_STEP_PX * target,
				"shape": int(_hash_unit(key, "shape" + salt) * float(ShardShapes.ids().size()) * 0.999),
				"flip": _hash_unit(key, "flip" + salt) < 0.5,
				"flop": _hash_unit(key, "flop" + salt) < 0.5,
				"rot0": _hash_unit(key, "rot" + salt) * TAU,
				"t0": t0,
				"fall": maxi(fall, 1),
			})
			_span = maxi(_span, t0 + fall + bounce_frames + hold_frames + fade_frames)
	return _shards.size()


## ⚠️ FNV-1a on the shard's BASE cell — B4's rule. `randf()` here would make the
## event unphotographable: a filmstrip stitched from one boot would still be
## right, but no two runs could ever be compared, and that is exactly the hole
## `glass_blast_demo` has.
func _hash_unit(key: Vector3i, what: String) -> float:
	return float(FacadeSamplerClass._fnv1a_hash(
		"rain|%d,%d,%d|%s" % [key.x, key.y, key.z, what]) % 100000) / 100000.0


func _process(_delta: float) -> void:
	## ⚠️ FRAMES. `_delta` is deliberately ignored — see the class note.
	_frame += 1
	_ensure_field().begin(_shards.size())
	var live: int = 0
	for s in _shards:
		var f: int = _frame - int(s["t0"])
		if f < 0:
			continue
		var fall: int = int(s["fall"])
		var pos: Vector2
		var rot: float = float(s["rot0"])
		var alpha: float = 1.0
		if f <= fall:
			## The drop: eased along the line, lifted by half a sine.
			var t: float = float(f) / float(fall)
			var e: float = 1.0 - (1.0 - t) * (1.0 - t)
			pos = (s["from"] as Vector2).lerp(s["to"], e) - Vector2(0.0, float(s["arc"]) * sin(PI * t))
			rot += float(s["spin"]) * float(f)
		else:
			## Landed. The spin is frozen — a shard skidding on the floor reads as
			## a bug, not as physics.
			rot += float(s["spin"]) * float(fall)
			pos = s["to"]
			var b: int = f - fall
			if b < bounce_frames:
				var bt: float = float(b) / float(bounce_frames)
				pos -= Vector2(0.0, float(s["arc"]) * bounce_scale * sin(PI * bt))
			var age: int = b - bounce_frames - hold_frames
			if age > 0:
				## G-D43 — it fades over the pile decal that is already beneath it.
				alpha = clampf(1.0 - float(age) / float(maxi(fade_frames, 1)), 0.0, 1.0)
				if alpha <= 0.0:
					continue
		var c: Color = tint
		c.a *= alpha
		_field.push(pos, float(s["size"]), rot, int(s["shape"]), c,
			bool(s["flip"]), bool(s["flop"]))
		live += 1
	_field.flush()
	## Done: the rain is disposable and takes nothing with it.
	if _frame > _span and live == 0:
		queue_free()


## How many shards are on screen this frame — the board, not the counter.
func live_count() -> int:
	return 0 if _field == null else _field.live_count()


## How many frames until the last shard is gone. Capture tooling asks this rather
## than guessing a wait.
func span_frames() -> int:
	return _span
