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

const ShardField3DRef = preload("res://godot/scripts/geometry/shard_field3d.gd")
const ParticleMathRef = preload("res://godot/scripts/geometry/particle_math.gd")
const ShardShapes = preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")
const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")

## ── LOOK VALUES, ALL FRAMES, ALL `var` (Rule 1) ─────────────────────────────
## ── GRAVITY (Director, 2026-10-10: *"caindo em velocidades diferentes, simulando a gravidade"*) ──────────────
## The fall is a real one: y(t) = y0 + v0·t − ½·g·t², the time from the actual height (one GU ≈ 1 m, scale canon), and the
## horizontal travel linear in t (constant horizontal speed, as a thrown body). Each shard has its own DRAG (a flat piece of glass
## flutters: its effective g is a hashed fraction of g) and its own POP (a small upward speed from the break), so the pieces of one
## pane land at different times. Counted in drawn frames at 60 per second, never in seconds (the commit-frame stall, below).
var gravity_gu_s2: float = 9.8      ## g in GU / s² (1 GU ~ 1 m)
var drag_min: float = 0.55           ## a shard's effective g is g × hash[drag_min, 1]
var pop_max_gu_s: float = 1.2        ## upward launch speed, hash[0, this]
var fall_frames_floor: int = 6       ## a shard born at the floor still takes this long
var stagger_frames: int = 10         ## spread of launch times across the pane
var bounce_frames: int = 7           ## the "leve bounce"
var bounce_scale: float = 0.16       ## fraction of the fall's arc height
var hold_frames: int = 26            ## settled, before it starts to go
var fade_frames: int = 18            ## and the fade that reveals the pile
var arc_px_min: float = 6.0          ## the 2D path only (no board): lift at the top of the fall's parabola
var arc_px_max: float = 22.0
var spin_min: float = -0.22          ## radians per frame while airborne
var spin_max: float = 0.22

## ── OPACITY ────────────────────────────────────────────────────────────────
## Director, 2026-09-06: *"tira mais opacidade dos cacos, e ir aumentando durante
## a queda. Eu queria ver se dá pra eles ficarem mais translúcidos. Nosso
## mecanismo atual eles parecem uma massa só."*
##
## The field is `blend_mix`, so N overlapping shards at one alpha stack toward
## opaque fast — that is the "massa". Three levers, none of them the atlas:
##   1. a low base `tint.a`;
##   2. a RAMP over the fall — a tumbling shard high in the air is barely there,
##      a shard about to land is the full tint. `alpha = lerp(air, 1, ease(t))`;
##   3. per-shard variance, so the crowd is not one flat wash.
##
## ⏭️ 2026-10-10 (Director): *"surgem muito apagados […] começarem com uma aparência mais brilhante e similar ao vidro real"*.
## The ramp is now the other way: a shard leaves the pane BRIGHT (`air_alpha` > 1 of the landed tint, near white) and settles into
## the pane's tint as it lands; a GLINT — the light catching a face as it turns — flashes on each shard with its spin
## (`glint_*`: a sharp power of |sin(rotation)|, hashed phase), white over the shard, drawn by the field's shader.
var tint: Color = Color(0.80, 0.93, 1.0, 0.62)
var air_alpha: float = 1.35          ## a shard's opacity at the TOP of its fall (× tint.a), easing to 1 as it lands
var air_whiten: float = 0.55         ## how far toward white a shard starts (0 = the tint)
var alpha_var_min: float = 0.70      ## per-shard multiplier, hashed to [this, 1.0]
var pieces_low_bias: float = 1.0     ## 1 = the 1..max piece count uniform (was 1.6, skewed low)
var glint_power: float = 10.0        ## sharpness of the flash (higher = shorter)
var glint_strength: float = 0.9      ## its peak, added toward white
var glint_landed: float = 0.25       ## what is left of it once the shard rests

## ⚠️ A CAP, AND IT IS HONEST ABOUT WHAT IT IS FOR. Instance buffer writes are
## per-frame DURING FLIGHT, and under G-D43 the flight is the only cost there is —
## dropping shards under budget is free, because none of them are state.
var max_shards: int = 3000

## ── CAPTURE-ONLY: a timing preset the Director compares on video ─────────────
##
## `Room._capture_glass_rain_timings()` sets this to one row of its preset table
## before `spawn_glass_rain()`, and `spawn()` folds any key that matches a look
## `var` above into `self`. Empty on every play path — the defaults ship.
static var timing_overrides: Dictionary = {}


func _apply_timing_overrides() -> void:
	for k in timing_overrides:
		if k in self:
			set(k, timing_overrides[k])
		else:
			push_warning("[GlassRainOverlay] timing override '%s' names no look var: ignored" % k)

## RENDER3D R3D-4e-4 — the shards are drawn by a depth-tested `ShardField3D` (with no board nothing is drawn: the 2D `ShardField`
## was removed in RETIRE-2D; a selftest still drives `spawn()` and `_process()` without one). One rain event, one overlay: the 3D
## field is freed with it.
var _live: int = 0                  ## the shards alive at the last `_process()`, board or not
var _board: Node3D = null
var _field3d: RefCounted = null
## One shard = `_S` doubles at `i * _S` (the `_O_*` offsets), not a Dictionary: 2026-10-11, building 2192 seventeen-key dictionaries was
## 60 ms of the Moto's flash frame. Doubles, so every value is exactly what the dictionaries held (a Vector2/Vector3 component is a
## float, a hashed parameter a double).
var _shards := PackedFloat64Array()
var _count: int = 0
const _S: int = 25
const _O_FROM: int = 0       ## Vector2 (the 2D path)
const _O_FROM3: int = 2      ## Vector3
const _O_TO3: int = 5        ## Vector3
const _O_JITTER: int = 8     ## Vector2
const _O_TO: int = 10        ## Vector2, the landing plus its jitter (the 2D path)
const _O_ARC: int = 12
const _O_SPIN: int = 13
const _O_SIZE: int = 14
const _O_SHAPE: int = 15
const _O_FLIP: int = 16      ## 0 / 1
const _O_FLOP: int = 17      ## 0 / 1
const _O_ROT0: int = 18
const _O_AVAR: int = 19
const _O_T0: int = 20
const _O_FALL: int = 21
const _O_G: int = 22
const _O_V0: int = 23
const _O_GLINT: int = 24
var _frame: int = 0
var _span: int = 0                   ## the last frame any shard is still visible


## Hand this event the 3D board BEFORE `spawn()` (the room creates one overlay per event).
func set_board3d(board: Node3D) -> void:
	_board = board
	if board != null and _field3d == null:
		_field3d = ShardField3DRef.new()
		_field3d.attach(board, 5)


func _exit_tree() -> void:
	if _field3d != null:
		_field3d.detach()
		_field3d = null


## Spawn one event's worth of rain.
##
## `flights` — `Array[{"from": Vector2, "to": Vector2, "key": Vector3i}]` in world
## pixels; `key` is the shard's BASE-space cell, and every hashed parameter comes
## off it so the same event replays identically.
##
## G-D44: one destroyed voxel yields 1 to 4 pieces (area is conserved, and a piece
## of edge 0.5-1.0 has area 0.25-1.0), so the caller passes one flight per VOXEL
## and the split happens here. `pieces_low_bias > 1` skews the count toward the
## LOW end of 1..max — fewer pieces means less overlap means less "massa só", and
## it keeps G-D44's range intact rather than lowering the ceiling.
func spawn(flights: Array, pieces_per_voxel_max: int = 4) -> int:
	_apply_timing_overrides()
	for f in flights:
		var key: Vector3i = f["key"]
		## The state after the prefix every hash of this flight shares (`rain|x,y,z|`), hashed once.
		var base: int = FacadeSamplerClass._fnv1a_continue(2166136261, "rain|%d,%d,%d|" % [key.x, key.y, key.z])
		var from: Vector2 = f["from"]
		var to: Vector2 = f["to"]
		## R3D-4e-4 — the two real 3D ends of the fall: the pane's voxel and the landing.
		## G-D55: a shard born where a falling PIECE hit the floor carries its own 3D start (`from3`, board space).
		var from3: Vector3 = f["from3"] if f.has("from3") else ParticleMathRef.anchor(_board, from, f.get("from_floor", ParticleMathRef.NO_FLOOR))
		## A landing voxel's position is its BASE; a shard lies on its TOP, one voxel step up. The 2D board never
		## saw the difference (no depth test); on the 3D board a shard at the base is inside the slab, and the
		## floor hides it (measured: to3.y = -0.1276, 20 px under the floor surface).
		var to_top: Vector2 = to - Vector2(0.0, GeometryCoords.VOXEL_STEP_PX)
		var to3: Vector3 = ParticleMathRef.anchor(_board, to_top, f.get("to_floor", ParticleMathRef.NO_FLOOR))
		var n: int = 1 + int(pow(_unit(base, "count"), pieces_low_bias) \
			* float(maxi(CosmeticDensity.scaled(pieces_per_voxel_max), 1)) * 0.999)
		## Each field's name hashed ONCE per flight; a shard then adds only its digit (`_unit_p`). 2026-10-11: the 14 whole-name hashes per
		## shard were most of the rain's 221 ms on the Moto (858 flights, 2192 shards, in one flash frame).
		var pre := PackedInt64Array()
		pre.resize(_FIELDS.size())
		for i in range(_FIELDS.size()):
			pre[i] = FacadeSamplerClass._fnv1a_continue(base, _FIELDS[i])
		for p in range(n):
			if _count >= CosmeticDensity.scaled(max_shards):
				break
			assert(p < 10, "a shard's salt is one digit")
			var target: float = lerpf(ShardShapes.TARGET_MIN, ShardShapes.TARGET_MAX,
				_unit_p(pre[0], p))
			## Gravity: g_eff per frame², the pop per frame, and the frames to fall the real height (the positive root of
			## ½·g·f² − v0·f − h = 0). Without a board the height is unknown: the floor time stands in.
			var g_f: float = gravity_gu_s2 * lerpf(drag_min, 1.0, _unit_p(pre[1], p)) / 3600.0
			## `pop` (G-D55): a piece that shatters on the floor throws its shards UP, harder than a pane breaking in place.
			var v0_f: float = float(f.get("pop", pop_max_gu_s)) * lerpf(0.35, 1.0, _unit_p(pre[2], p)) / 60.0
			var h: float = maxf(from3.y - to3.y, 0.0) / maxf(_board_vscale(), 0.001) if _board != null else 0.0
			var fall: int = maxi(fall_frames_floor, int(ceil((v0_f + sqrt(v0_f * v0_f + 2.0 * g_f * h)) / maxf(g_f, 1e-6))))
			## G-D55: a shard of a voxel that hit the floor starts at its impact frame (`t0` from the event's start), a frame or two apart.
			var t0: int = int(f["t0"]) + int(_unit_p(pre[3], p) * 2.99) if f.has("t0") \
				else int(_unit_p(pre[3], p) * float(stagger_frames))
			## The pieces of one voxel do not all land on the same pixel: a small
			## sub-cell offset, hashed, so a pile reads as a scatter and not as a
			## stack. ⚠️ It moves only where the shard DRAWS, never the landing CELL
			## the G6 pile was recorded at — that one is state.
			var jitter := Vector2(
				(_unit_p(pre[4], p) - 0.5) * 22.0,
				(_unit_p(pre[5], p) - 0.5) * 11.0)
			var b: int = _count * _S
			if _shards.size() < b + _S:
				_shards.resize(maxi(b + _S, _shards.size() * 2))
			var to_j: Vector2 = to + jitter
			_shards[b + _O_FROM] = from.x
			_shards[b + _O_FROM + 1] = from.y
			_shards[b + _O_FROM3] = from3.x
			_shards[b + _O_FROM3 + 1] = from3.y
			_shards[b + _O_FROM3 + 2] = from3.z
			_shards[b + _O_TO3] = to3.x
			_shards[b + _O_TO3 + 1] = to3.y
			_shards[b + _O_TO3 + 2] = to3.z
			_shards[b + _O_JITTER] = jitter.x
			_shards[b + _O_JITTER + 1] = jitter.y
			_shards[b + _O_TO] = to_j.x
			_shards[b + _O_TO + 1] = to_j.y
			_shards[b + _O_ARC] = lerpf(arc_px_min, arc_px_max, _unit_p(pre[6], p))
			_shards[b + _O_SPIN] = lerpf(spin_min, spin_max, _unit_p(pre[7], p))
			_shards[b + _O_SIZE] = GeometryCoords.VOXEL_STEP_PX * target
			_shards[b + _O_SHAPE] = int(_unit_p(pre[8], p) * float(ShardShapes.ids().size()) * 0.999)
			_shards[b + _O_FLIP] = 1.0 if _unit_p(pre[9], p) < 0.5 else 0.0
			_shards[b + _O_FLOP] = 1.0 if _unit_p(pre[10], p) < 0.5 else 0.0
			_shards[b + _O_ROT0] = _unit_p(pre[11], p) * TAU
			_shards[b + _O_AVAR] = lerpf(alpha_var_min, 1.0, _unit_p(pre[12], p))
			_shards[b + _O_T0] = t0
			_shards[b + _O_FALL] = maxi(fall, 1)
			_shards[b + _O_G] = g_f
			_shards[b + _O_V0] = v0_f
			_shards[b + _O_GLINT] = _unit_p(pre[13], p) * TAU
			_count += 1
			_span = maxi(_span, t0 + fall + bounce_frames + hold_frames + fade_frames)
	return _count


## ⚠️ FNV-1a on the shard's BASE cell — B4's rule. `randf()` here would make the
## event unphotographable: a filmstrip stitched from one boot would still be
## right, but no two runs could ever be compared, and that is exactly the hole
## `glass_blast_demo` has.
func _hash_unit(key: Vector3i, what: String) -> float:
	return float(FacadeSamplerClass._fnv1a_hash(
		"rain|%d,%d,%d|%s" % [key.x, key.y, key.z, what]) % 100000) / 100000.0


## `_hash_unit(key, what)` continued from the prefix state `base` (see `spawn()`): the same value, without re-hashing the prefix.
func _unit(base: int, what: String) -> float:
	return float(FacadeSamplerClass._fnv1a_continue(base, what) % 100000) / 100000.0


## The per-shard fields, in the index order `spawn()` reads `pre` with. Their names are part of the hash: never rename one.
const _FIELDS: PackedStringArray = ["size", "drag", "pop", "t0", "jx", "jy", "arc", "spin", "shape", "flip", "flop", "rot", "avar", "glint"]


## `_unit(base, field + str(p))` for a one-digit `p`, given `field_state = _fnv1a_continue(base, field)`: FNV-1a is sequential, so the
## digit is one more FNV step (its ASCII byte, then the prime, kept to 32 bits). Exactly the same value (B4).
static func _unit_p(field_state: int, p: int) -> float:
	return float((((field_state ^ (48 + p)) * 16777619) & 0xFFFFFFFF) % 100000) / 100000.0


## G-D55: a rain laid ahead of its fall waits here (no frame counted, nothing drawn) until the fall starts.
var paused: bool = false


## G-D55: a rain laid AFTER its fall started catches up: its clock jumps to the fall's, so each flight still starts at its voxel's
## impact frame (a flight whose frame has passed starts at once).
func advance_to(frame: int) -> void:
	_frame = maxi(_frame, frame)


func _process(_delta: float) -> void:
	if paused:
		return
	_frame += 1
	var f3: RefCounted = _field3d
	var cam: Basis = Basis.IDENTITY
	var ppu: float = 1.0
	if f3 != null:
		f3.begin_on_board(_count)
		cam = _board.call("lattice_basis")  ## R3D-WORLD: a 2D displacement is a world one through the BASE view
		ppu = _board.call("px_per_unit")
	var live: int = 0
	var sh: PackedFloat64Array = _shards
	for i in range(_count):
		var b: int = i * _S
		var f: int = _frame - int(sh[b + _O_T0])
		if f < 0:
			continue
		var fall: int = int(sh[b + _O_FALL])
		var pos: Vector2
		var rot: float = sh[b + _O_ROT0]
		var alpha: float = 1.0
		## The same fall, read two ways: `pos` is the 2D screen position; `base3` and `lift_px` are its
		## world equivalent — the point on the way between the two 3D ends, plus the arc's height (a
		## screen-up lift of `lift_px` px is world-up by `lift_px / (ppu * cos 30)`).
		var base3: Vector3
		var lift_px: float = 0.0
		var jitter3: Vector3 = Vector3.ZERO
		if f3 != null:
			jitter3 = ParticleMathRef.displace(Vector2(sh[b + _O_JITTER], sh[b + _O_JITTER + 1]), cam, ppu)
		var landed: bool = f > fall
		if not landed:
			var t: float = float(f) / float(fall)
			pos = Vector2(sh[b + _O_FROM], sh[b + _O_FROM + 1]).lerp(Vector2(sh[b + _O_TO], sh[b + _O_TO + 1]), t * t) \
				- Vector2(0.0, sh[b + _O_ARC] * sin(PI * t))
			if f3 != null:
				## Horizontal: linear in time. Vertical: the ballistic curve from the pane down to the landing (world y).
				var a3 := Vector3(sh[b + _O_FROM3], sh[b + _O_FROM3 + 1], sh[b + _O_FROM3 + 2])
				var b3: Vector3 = Vector3(sh[b + _O_TO3], sh[b + _O_TO3 + 1], sh[b + _O_TO3 + 2]) + jitter3
				base3 = a3.lerp(b3, t)
				var vs: float = _board_vscale()
				base3.y = a3.y + (sh[b + _O_V0] * float(f) - 0.5 * sh[b + _O_G] * float(f) * float(f)) * vs
				base3.y = maxf(base3.y, b3.y)
			rot += sh[b + _O_SPIN] * float(f)
			alpha = lerpf(air_alpha, 1.0, t * t)
		else:
			rot += sh[b + _O_SPIN] * float(fall)
			pos = Vector2(sh[b + _O_TO], sh[b + _O_TO + 1])
			if f3 != null:
				base3 = Vector3(sh[b + _O_TO3], sh[b + _O_TO3 + 1], sh[b + _O_TO3 + 2]) + jitter3
			var bf: int = f - fall
			if bf < bounce_frames:
				var bt: float = float(bf) / float(bounce_frames)
				pos -= Vector2(0.0, sh[b + _O_ARC] * bounce_scale * sin(PI * bt))
				lift_px = sh[b + _O_ARC] * bounce_scale * sin(PI * bt)
			var age: int = bf - bounce_frames - hold_frames
			if age > 0:
				alpha = clampf(1.0 - float(age) / float(maxi(fade_frames, 1)), 0.0, 1.0)
				if alpha <= 0.0:
					continue
		var c: Color = tint
		## Bright when it leaves the pane, the tint once it lands (the whiten eases with the same curve as the alpha).
		var air: float = 0.0 if landed else 1.0 - pow(float(f) / float(fall), 2.0)
		c = c.lerp(Color(1, 1, 1, c.a), air_whiten * air)
		c.a = clampf(c.a * alpha * sh[b + _O_AVAR], 0.0, 1.0)
		var glint: float = glint_strength * pow(absf(sin(rot + sh[b + _O_GLINT])), glint_power)
		if landed:
			glint *= glint_landed
		if f3 != null:
			f3.push(base3 + Vector3.UP * (lift_px / (ppu * ParticleMathRef.COS_ELEVATION)),
				sh[b + _O_SIZE], rot, int(sh[b + _O_SHAPE]), c, sh[b + _O_FLIP] != 0.0, sh[b + _O_FLOP] != 0.0, glint)
		live += 1
	if f3 != null:
		f3.flush()
	_live = live
	if _frame > _span and live == 0:
		queue_free()


## The board's vertical scale (a storey is one world y unit × this): heights in the world are divided by it to get GU.
func _board_vscale() -> float:
	if _board == null:
		return 1.0
	var v: Variant = _board.get("VERTICAL_SCALE")
	return float(v) if v != null else 1.0


func live_count() -> int:
	if _field3d != null:
		return _field3d.live_count()
	return _live


## How many frames until the last shard is gone. Capture tooling asks this rather
## than guessing a wait.
func span_frames() -> int:
	return _span
