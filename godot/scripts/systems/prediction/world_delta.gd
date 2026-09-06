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
## `DetonationPresenter` and both plan selftests consume `delta.waves`
## and needed no other edit.
##
## `ember` and `debris` (E-EMBER-01 / E-DEBRIS-01, 2026-08-13) paint nothing on
## the TileMapLayer — they hand a glow to `EmberOverlay` and dust/chips/sparks to
## `DebrisOverlay`/`SmokeSparkOverlay`, exactly the way `smoke` hands a puff over.
## They ride here anyway because both have to arrive WITH the expanding front
## that produced them, and the queue is what carries that ordering.
##
## ⚠️ **THE FIRE IS NOT A WAVE.** M3-3 once carried it as a `burn` schedule the
## room played out over ~1.4 s; D-2 (2026-08-28) folded it into damage on this
## Delta (`burnt_cells` below) and D-6 (2026-08-29) deleted the schedule path and
## `BurnScheduler` outright. Which voxels the fire consumes is committed with
## everything else; `burnt_cells` carries the visual `at` order the embers read.
var waves: Dictionary = {
	"destroy": {}, "dented": {}, "cracked": {}, "smoke": {}, "ember": {},
	"debris": {}, "soot": {},
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

## SS-3 (`SOOT_STORAGE_REFORM` §3.1) — THE SCORCH THIS BLAST PROPOSES, as data.
##
## `level -> {view_cell: PackedInt32Array}`, the six-direction record
## `BlastCalculator.build_soot_field()`'s `out_full` produces. Filled by
## `DetonationPlanBuilder._phase_soot()` while the plan is still PURE, and written
## to `Room._soot_map` by `commit()` and nowhere else.
##
## ⚠️ **NOT `waves["soot"]`, AND THE TWO MUST NEVER BE MERGED.** That one is a
## VISUAL bucket — the ordered list of cells the choreographer will paint, with
## its alt, its ring and its radius — and it is thrown away once the animation has
## played. This is STATE. The names were kept deliberately far apart because the
## plan predicted that the first person to see both would try to unify them.
var scorch_writes: Dictionary = {}

## CRACK-05 (`GLASS_MASTER_PLAN` §14.5) — THE SHAPE OF EVERY HOLE THIS BLAST OPENS
## IN GLASS, as a proposal.
##
## `Array[{"cell": Vector2i, "level": int, "wide": bool}]` — one entry per pane
## `DetonationPlanBuilder._shatter_glass_panes()` decided to take, naming the
## voxel the fracture started at. `commit()` turns each into
## `Room.claim_glass_opening_for_hit()`, which is what makes a grenade's hole a
## picked member of G-D34's family instead of the one default shape every blast
## repeated.
##
## ⚠️ **IT IS A PROPOSAL FOR THE SAME REASON `scorch_writes` IS, AND THE REASON
## BITES HARDER HERE.** Claiming is a WRITE — it puts an entry in the renderer's
## `_glass_region_openings` and a record in `Room._base_openings` — and
## `build_plan()` runs on every cursor move, cached and thrown away. Claiming
## from the builder would leave one pending claim per previewed GU, all of them
## for holes that were never opened, and the first real blast anywhere on the map
## would wear whichever of them happened to match its region.
##
## ⚠️ AND THE CELL IS THE FLOOD'S ORIGIN, NOT THE REGION'S CENTROID. For an
## asymmetric member the two are far apart (§14.4), so an unclaimed region is not
## merely default-shaped — it is default-shaped in the wrong place.
var glass_openings: Array = []

## G-D35 B-1 (`GLASS_MASTER_PLAN` §6.2 / §16.3) — THE PANES THIS BLAST CRAZED
## BUT DID NOT TAKE.
##
## `Array[{"pane_id": String, "cell": Vector2i, "level": int, "ring": int,
## "intensity": float}]` — one entry per pane, naming the voxel nearest the
## epicenter and how hard the blast crazed it (`GlassShatter.blast_craze_intensity`).
##
## ⚠️ **THE CRACKED STATE IS NOT HERE — IT IS IN `damage`, WITH EVERYTHING ELSE.**
## The state is a gameplay fact that VL-PERSIST already saves and a perspective
## flip already restores; routing it through a second channel would make the glass
## the one material whose damage commits by its own path. What this carries is the
## ATTRIBUTION — which pane, which ring, how hard — the way `burnt_cells` carries
## the fire's, and for the same reason: once committed, a blast-crazed pane is
## indistinguishable from any other cracked glass.
##
## ⚠️ **ITS VISUAL CONSUMER IS WIRED (B-2, 2026-09-05) AND STILL DRAWS NOTHING,
## WHICH IS THE ORDERING RATHER THAN A GAP.** `commit()` hands each entry to
## `Room.claim_glass_craze()`, which plans a TILED field over the pane's own
## rectangle and asks the renderer for it — and `spawn_glass_craze()` returns 0
## until `fracture_manifest.json` carries a `blast_*` row, because G-D35's sheet
## is centreless and today's bullet page over a crazed pane would be the wrong art
## wired to a real trigger (§16.5). B-3 delivers the mesh and this lights up with
## no code change.
var glass_crazes: Array = []

## G6 (`GLASS_MASTER_PLAN` §7.1) — WHERE THE GLASS THIS BLAST BROKE LANDED.
##
## `Vector3i(cell, landing_level) -> count`, in the CURRENT view's coords, merged
## across every pane the blast took. `GlassFall.pile_by_cell()`'s own shape.
##
## ⚠️ **A PROPOSAL, FOR THE SAME REASON `glass_openings` IS.** Drawing a pile is a
## WRITE — it adds a node and a base-coord record — and `build_plan()` runs on
## every cursor move, cached and thrown away. Piles made in the builder would
## leave glass on the floor of every GU the cursor ever hovered.
var glass_shard_piles: Dictionary = {}

## ── G4-2 / G-D38 + G-D39 — THE GLASS THAT STAYED STUCK TO THE FRAME ─────────
##
## `Array[{"cell": Vector2i, "level": int}]`, in the CURRENT view's coords. Each
## one is a voxel `GlassShatter.plan_pane_shatter()` SPARED because a neighbouring
## non-glass material holds it (G-D13b, which is the Director's G4 rule verbatim).
##
## ⚠️ **POSITION ONLY — THE ANCHOR IS NOT CARRIED.** The mask is a READ of the
## live geometry (`GlassShatter.remnant_anchor_mask()`), asked again at claim and
## at every rebuild, and that is what makes a remnant survive a perspective flip
## for nothing: a stored mask would be in the PANE's (run, level) frame, and a
## pane's run axis is grid-X for SW/NE faces and grid-Y for SE/NW ones, so a
## quarter turn changes what `RUN_POS` means. The frame the fragment hangs from
## does not move; asking the world again is cheaper AND correct by construction.
##
## ⚠️ A PROPOSAL, like every field around it. Stamping a cut atom is a WRITE and
## `build_plan()` runs on every cursor move.
var glass_remnants: Array = []

## ── G6b-2 / G-D43 — THE FLIGHTS, WHICH ARE NOT STATE ────────────────────────
##
## `GlassFall.plan_landings()`'s own rows — `{grid_pos, from_level, landing_level}`
## — carried through so the rain knows where each shard STARTED. The pile record
## alone cannot say: it is keyed by landing cell and a six-storey pane empties onto
## one tile from twenty-four different heights.
##
## ⚠️ NOTHING HERE IS PERSISTED, and that is G-D43: the rain fades over the pile
## decal and is freed. These rows exist for exactly one commit and are never
## written to `SaveState`, never converted to BASE coords, and never replayed on a
## rotation — because there is nothing left to replay.
var glass_shard_flights: Array = []

## D-2 (`DETONATION_PRESENTATION_MASTER_PLAN` §6) — WHICH VOXELS THE FIRE ATE.
##
## `{Vector3i: {"at": seconds, "ring": int}}`. Every one of these is also a
## DESTROYED entry in `damage`, so this changes nothing about what commits; it is
## the **attribution**, kept because the destruction it describes is now
## indistinguishable from the blast's own once committed.
##
## §6.2: with everything destroyed in one frame, *which voxels wear an ember is
## what tells the story*. `at` is the pace the schedule used to run at and is what
## D-4's symbolic fire reads for its per-instance phase. **Nothing may mutate the
## world off this** — that is the property D-2 exists to establish.
var burnt_cells: Dictionary = {}

## D-7 (`DETONATION_PRESENTATION_MASTER_PLAN` §7.4) — THE LIGHT COOK.
##
## `_phase_light` builds the whole board's final `VoxelLightField` from the
## post-blast occupancy (`build_occupancy(predict_destroyed)`), and `_phase_soot_wave`
## then makes it compute the bucket of every cell this blast changes — which it
## already did, to fill `waves["soot"]`. Both were thrown away once the animation
## had its alt ids. Kept here so `Room.play_consequence_light()` applies THIS field
## to `light_changed_cells` in ~18 ms instead of re-deriving occupancy + soot +
## the field map-wide (the ~158 ms freeze D-8 only hid).
##
## `light_field` is only VALID for `light_changed_cells` — its occupancy is
## map-wide but its bucket cache was only warmed for the blast neighbourhood, and
## the room does not adopt it (`_voxel_light_field` is untouched; the next full
## repaint rebuilds that from scratch, as it always has).
##
## `light_field_usable` is FALSE when any light feeding the field is TEMPORAL
## (flicker / pulse / rotation): those change every frame, so a field fixed
## seconds ago at cook time would freeze that light's contribution at a stale
## value — "wrong everywhere", the exact risk §7.4 is scoped around. On that path
## `play_consequence_light()` takes the full re-derivation, unchanged.
var light_field = null
var light_changed_cells: Dictionary = {}
var light_field_usable: bool = false

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
## SS-3 — `room` is optional so the purity selftest and any caller with nothing to
## scorch keep working unchanged. When it is supplied, the proposed scorch lands
## through `Room.scorch_cell()`'s min-wins, which is the store's ONLY writer.
##
## ⚠️ The world revision does NOT get bumped here. `TestZoneController` already
## calls `room.bump_world_revision()` after this returns, and adding a second bump
## inside would be a silent extra invalidation of every cached prediction on a
## path where performance is the standing priority. The requirement is that a
## committed mutation is followed by a bump, not that it performs one.
func commit(room = null) -> void:
	BlastCalculatorClass.commit_damage(damage)
	if room != null and not scorch_writes.is_empty():
		room.absorb_scorch(scorch_writes)
	## CRACK-05 — the glass holes this blast opened take their SHAPE here.
	##
	## ⚠️ ORDER IS LOAD-BEARING AND IT IS THE ORDER OF THIS FUNCTION, NOT A
	## COINCIDENCE. `commit_damage()` above is what marks the pane's voxels
	## DESTROYED; the renderer's erase pass then flags each cell and
	## `DetonationEntryWriter.flush()` calls `refresh_glass_rims()`, which CONSUMES
	## every pending claim and clears the table. A claim made after that flush
	## would be picked up by whatever glass broke next, on some other pane.
	if room != null:
		for c in glass_openings:
			room.claim_glass_opening_for_hit(c["cell"], int(c["level"]), bool(c["wide"]))
		## G-D35 B-2 — and the craze FIELDS over the panes this blast did not take.
		## Same split, same reason: spawning a sprite is a WRITE, and `build_plan()`
		## runs on every cursor move. AFTER the openings, so a pane that both
		## crazed and took a hole has its rim already cut when the field's occupancy
		## is walked.
		for z in glass_crazes:
			room.claim_glass_craze(z["cell"], int(z["level"]), float(z["intensity"]))
		## G6 — and the glass that fell. AFTER the openings, so a floor cell that
		## is about to be revealed by a crater is already the surface the pile is
		## drawn on.
		if not glass_shard_piles.is_empty():
			room.record_glass_shards(glass_shard_piles)
		## G4-2 — and the glass that did NOT fall. LAST: a remnant swaps the atom
		## on a cell that survived, so every erase and every rim cut around it has
		## to have happened first or the opening walk would overwrite it.
		if not glass_remnants.is_empty():
			room.claim_glass_remnants(glass_remnants)
		## G6b-2 — and the rain, LAST of all: the pile decals above are already on
		## the floor, which is what makes the fall safe to interrupt (G-D43).
		if not glass_shard_flights.is_empty():
			room.spawn_glass_rain(glass_shard_flights)


func is_empty() -> bool:
	return damage.is_empty()
