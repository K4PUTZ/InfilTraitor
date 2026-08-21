## WorldDelta — PREDICTION_MASTER_PLAN §3.1, Task 3 (P-DELTA), 2026-08-09.
##
## **A description of what WOULD change, never a change.** An action is
## simulated into one of these; committing it is a separate, explicit act. That
## split is the whole plan: it is what lets the engine answer *"what would this
## grenade do"* without doing it, and therefore what lets a detonation be
## computed early (§4), cached (§5), thrown away when the player moves the
## cursor, or read by a HUD that must not damage anything to draw a number.
##
## It lives under `systems/prediction/`, not under `systems/destruction/`,
## deliberately — §0: *"Explosions are this layer's first consumer and its
## proving ground, not its owner."*
##
## ## The projection, and why it is not just a dictionary of new values
##
## Half of this class is `_by_voxel`: the answer to *"what would this voxel be
## if this Delta committed?"* Everything downstream of the damage step in
## `DetonationPlanBuilder` — soot derivation, occupancy, tile resolution, the
## census — used to read that answer off the real Voxel, because the damage had
## already been applied to it. With a pure builder there is nothing to read, so
## the projection has to answer instead.
##
## It models `Voxel.set_damage()` EXACTLY, including the two rules that are easy
## to miss and would silently produce a Delta that predicts the wrong thing:
##
##  - **the early return.** An entry naming a state the voxel is already in
##    writes nothing — and, critically, leaves the OTHER four fields at their
##    older values. A projection that just overwrote would invent a fresh
##    variant/substrate for a voxel that is going to keep its old one.
##  - **`visible` follows DESTROYED only.** Nothing sets it back to true, so a
##    voxel that was destroyed and is later marked DENTED stays invisible. That
##    is pre-existing behaviour, and the projection reproduces it rather than
##    tidying it up.
##
## ## What a Delta must not be trusted to survive
##
## `damage` entries and `touched_voxels` hold **live Voxel references**. They are
## valid only against the world revision the Delta was computed on — which is
## exactly what §5.2's cache key exists to enforce. A Delta that outlives a map
## reload points at freed objects; `touched` (plain `Vector3i` cells) is the
## field to read when a consumer needs to survive that.
class_name WorldDelta
extends RefCounted

const BlastCalculatorClass = preload("res://godot/scripts/systems/destruction/blast_calculator.gd")

## Projection tuple layout for `_by_voxel` — §2.1's mutable surface minus
## `dirty`, which is bookkeeping the commit owns and no reader projects.
const P_STATE: int = 0
const P_BLAST: int = 1
const P_SIDE: int = 2
const P_VARIANT: int = 3
const P_SUBSTRATE: int = 4
const P_VISIBLE: int = 5

## The ordered `set_damage()` calls this Delta would make
## (`BlastCalculator.damage_entry()` dictionaries). Order is load-bearing — see
## that function's own note.
var damage: Array = []

## The playback payload: `{kind: {ring: [entry]}}` for destroy / dented /
## cracked / smoke / ember / soot. Unchanged in shape from the Dictionary
## `DetonationPlanBuilder` returned before this class existed, which is why
## `DetonationChoreographer` and both plan selftests consume `delta.waves`
## and needed no other edit.
##
## `ember` and `debris` (E-EMBER-01 / E-DEBRIS-01, 2026-08-13) paint nothing on
## the TileMapLayer — they hand a glow to `EmberOverlay` and dust/chips/sparks to
## `DebrisOverlay`/`SmokeSparkOverlay`, exactly the way `smoke` hands a puff over.
## They ride here anyway because both have to arrive WITH the expanding front
## that produced them, and the queue is what carries that ordering.
## M3-3 (2026-08-21): `burn` is the one wave that is NOT playback. Every other
## kind here paints or spawns something in the frames right after the commit;
## `burn` is a SCHEDULE of world mutations the room plays out over the seconds
## afterwards — {voxel, cell, level, at} — because the whole point of fire is
## that it does not all happen in one frame. It rides in `waves` because it is
## produced by the same pure pass and has to arrive with the front that lit it.
var waves: Dictionary = {
	"destroy": {}, "dented": {}, "cracked": {}, "smoke": {}, "ember": {},
	"debris": {}, "soot": {}, "burn": {},
}

## §3.4 — the cheap summary. A consumer that only needs "how much of this cover
## survives" reads this and never walks `damage`.
## `{"SURFACE|material": {destroy, dented, cracked, baked, live}}`
var census: Dictionary = {}

## §3.4 — every cell this Delta touches, as plain coordinates. Safe to keep
## after the Voxel references in `damage` have gone stale.
var touched: Array[Vector3i] = []

## The real Voxel objects behind `touched`, in the same order — VL-PERSIST's
## seam (`room.record_voxel_damage_to_base()`), which needs the objects and runs
## immediately after the commit. See the class doc on lifetime.
var touched_voxels: Array = []

## §3.4 / §5.4 — what computing this Delta cost, in milliseconds. Set by the
## producer; the budget in §4.4 is measured against it.
var cost_ms: float = 0.0

## Voxel -> projected tuple. Only voxels this Delta actually changes appear.
var _by_voxel: Dictionary = {}


## Appends simulated entries and folds them into the projection immediately, so
## a producer can read the projection back mid-build (`DetonationPlanBuilder`
## does: the crater loop asks whether a slab has any destroyed voxel yet, right
## after simulating that slab).
func add_damage(entries: Array) -> void:
	for e in entries:
		damage.append(e)
		_fold(e)


## One entry through `Voxel.set_damage()`'s own semantics — see the class doc.
## Folds onto the projection so far, not onto the raw Voxel, so a second entry
## for the same voxel behaves the way a second call would.
func _fold(e: Dictionary) -> void:
	var v = e["voxel"]
	var current: Array = _by_voxel.get(v, [])
	var cur_state: int = int(current[P_STATE]) if not current.is_empty() else v.damage_state
	var new_state: int = int(e["state"])
	if cur_state == new_state:
		return   ## set_damage()'s early return — nothing changes, not even provenance
	var vis: bool = bool(current[P_VISIBLE]) if not current.is_empty() else v.visible
	if new_state == Voxel.DamageState.DESTROYED:
		vis = false
	_by_voxel[v] = [new_state, e["from_blast"], e["carved_side"], e["variant"],
		e["substrate"], vis]


## True when this Delta would change anything about `voxel`.
func changes(voxel) -> bool:
	return _by_voxel.has(voxel)


## The whole projected tuple in ONE lookup, or `[]` when this Delta does not
## touch the voxel — read it with the `P_*` constants above.
##
## This exists for a measured reason, not for tidiness. The map-wide passes in
## `DetonationPlanBuilder` run over ~100 000 voxels, so the difference between
## calling three accessors and calling one is ~200 000 dictionary lookups per
## detonation — measured at roughly 40 ms on the real PLAYGROUND blast, i.e.
## comparable to an entire phase of §1.1's table. Single-field accessors stay
## for the call sites that genuinely need one field.
func projection_of(voxel) -> Array:
	return _by_voxel.get(voxel, [])


## The projected value of each field. Falls through to the real Voxel for
## anything this Delta does not touch, which is the overwhelming majority — a
## blast reaches a couple of thousand voxels out of a map's hundred thousand.
func state_of(voxel) -> int:
	var p: Array = _by_voxel.get(voxel, [])
	return int(p[P_STATE]) if not p.is_empty() else voxel.damage_state


func visible_of(voxel) -> bool:
	var p: Array = _by_voxel.get(voxel, [])
	return bool(p[P_VISIBLE]) if not p.is_empty() else voxel.visible


func is_blast_of(voxel) -> bool:
	var p: Array = _by_voxel.get(voxel, [])
	return bool(p[P_BLAST]) if not p.is_empty() else voxel.damage_is_blast


## A detached Voxel carrying this Delta's projected fields, for the resolution
## code that takes a whole Voxel rather than individual fields
## (`VoxelRenderer.resolve_damage_voxel_swap()` and friends, which read five
## damage fields plus the cell and never write).
##
## Handing them a copy is what keeps the pure builder from needing a parallel
## set of renderer signatures — the resolver cannot tell the difference, and the
## alternative (threading a projection through every renderer entry point) would
## put prediction concerns inside the render path for no gain.
##
## `parent_container` is deliberately **null**: nothing here should ever write to
## a projected voxel, and a write would take `Voxel._set_dirty()` straight into a
## null dereference instead of silently bumping the real container's dirty count.
## Loud, per the project's B6 rule. LEAK-CYCLE-01 changed how Voxel stores that
## back-reference (an instance id, no longer the object) without changing this:
## null still lands on id 0, `instance_from_id(0)` still resolves to null, and a
## write still dies on the same loud SCRIPT ERROR. Verified, not assumed.
##
## Returns the ORIGINAL voxel — no allocation — when this Delta does not change
## it, since a copy would be identical by definition.
func project_voxel(voxel) -> Voxel:
	var p: Array = _by_voxel.get(voxel, [])
	if p.is_empty():
		return voxel
	var copy := Voxel.new(voxel.grid_pos, voxel.level, null)
	copy.damage_state = int(p[P_STATE])
	copy.damage_is_blast = bool(p[P_BLAST])
	copy.damage_carved_side = int(p[P_SIDE])
	copy.damage_variant = int(p[P_VARIANT])
	copy.damage_substrate = int(p[P_SUBSTRATE])
	copy.visible = bool(p[P_VISIBLE])
	copy.face_atlas_rect = voxel.face_atlas_rect
	return copy


## Makes this Delta real. The only state-changing call in the class, and the
## only one a caller has to think about — everything above is read-only by
## construction.
func commit() -> void:
	BlastCalculatorClass.commit_damage(damage)


func is_empty() -> bool:
	return damage.is_empty()
