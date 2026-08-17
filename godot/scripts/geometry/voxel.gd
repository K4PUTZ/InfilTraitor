## Geometry Module — Voxel: single 32×32 voxel in a wall slice
## Port from voxel_ref.gd with damage state tracking
class_name Voxel

## CRACKED = flat surface mark, voxel stays full height ("voxel atingido ficou
## só marcado com a textura especial da bala"). DENTED = sunken special piece,
## more severe than CRACKED but short of DESTROYED ("1 voxel ficou meio
## afundado, pecinha especial com textura da bala") — DESTRUCTION_MASTER_PLAN
## D22 (Director, 2026-07-30). Appended rather than inserted so existing
## ordinals (used in persisted base-coord damage dicts) never shift.
enum DamageState { INTACT = 0, CRACKED = 1, DESTROYED = 2, DENTED = 3 }

var grid_pos: Vector2i           ## voxel cell coordinate
var level: int                   ## vertical storey index
var visible: bool = true         ## render state
var dirty: bool = false          ## marked for TIC processing
var damage_state: int = DamageState.INTACT
var face_atlas_rect: Rect2i      ## assigned by BakeSystem (VOXEL-08), null until baked
## VL-D1/D24: soot is NOT a field on Voxel — it is derived fresh every repaint
## from which nearby voxels are currently absent (room._build_soot_snapshot()
## -> BlastCalculator.derive_soot_rings()), never stored here. A destroyed
## voxel's absence already survives rotation via room._base_damage, so there
## is nothing extra to persist for soot to travel with the hole.

## DESTRUCTION_MASTER_PLAN D23 (Director, 2026-07-30): a DENTED/CRACKED mark
## reads differently depending on what caused it — a bullet leaves a round
## puncture, a blast leaves an irregular chip/crack ("a gente pode criar
## estados intermediários do material em explosões, mas não com furos
## redondos"). Sets which texture family VoxelRenderer.damage_variant_material()
## picks. Irrelevant for INTACT/DESTROYED (a hole is a hole regardless of
## cause), so only DENTED/CRACKED callers need to pass true.
var damage_is_blast: bool = false

## D25 (Director diagram, 2026-07-31): a blast-DENTED voxel is a HALF voxel,
## and this is WHICH SIDE the blast ate — the side that faced the explosion.
## Picks one of VoxelRenderer's four carved half-voxel textures.
##
## VIEW space, not base space: LEFT/RIGHT mean screen-left/screen-right, so
## this value is only valid for the perspective it was computed under.
## room._reapply_base_damage() recomputes it from the persisted base-space
## direction on every rotation — see room._base_damage's own doc.
## NONE means "direction unknown" (no epicentre bias was supplied), which
## renders the flat pre-D25 blast mark rather than guessing a side.
enum CarvedSide { NONE = 0, TOP = 1, BOTTOM = 2, LEFT = 3, RIGHT = 4 }
var damage_carved_side: int = CarvedSide.NONE

## D32 (Director, 2026-08-02): WHICH of the three authored decals this mark uses
## — "até 5 variações... se tiver mais, randomiza", fixed at 3 the same session.
##
## Stored rather than derived at render time, and that is deliberate. The
## obvious cheap alternative — hashing the voxel's grid_pos at paint time — is
## wrong here: grid_pos is VIEW space, so rotating the camera would silently
## re-roll every mark's art. The damaging caller picks this from its own salt
## (one roll per projectile, per voxel) and room._base_damage persists it
## alongside is_blast and the carved side, so a mark keeps its art forever.
var damage_variant: int = 0

## D3/§3.3 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): WHICH of the 3 pre-baked
## substrate crops this mark's decal sits on — the atom-bake model's whole
## premise is that a damaged voxel shows a RANDOMLY CHOSEN facade crop for its
## material, not its own. Same storage rationale as damage_variant above
## (grid_pos is view-space, rotation would re-roll it) and the same read-once
## rule in set_damage(). Rolled from a DIFFERENT hash salt than damage_variant
## (BlastCalculator.substrate_for()) so substrate choice never correlates with
## decal choice.
var damage_substrate: int = 0

## Back-reference for dirty propagation, held as an INSTANCE ID and never as a
## reference. D1 (DESTRUCTION_MASTER_PLAN) makes Voxel the single class shared
## by wall voxels (parent = Slice, owned by an Edge), floor/ceiling/interior
## voxels (parent = Slab, D1 — no edge) and junction columns (parent =
## JunctionColumn, E-JUNCTION-01). GDScript has no shared interface type, so
## whatever this resolves to is duck-typed; increment_dirty()/decrement_dirty()
## is the entire contract Voxel needs from its container.
##
## LEAK-CYCLE-01 (2026-08-17): this used to hold the container object itself,
## which closed a reference cycle — the container holds `voxels`, each Voxel
## held the container back — and Godot's RefCounted has no cycle collector, so
## neither side's refcount ever reached zero. Nothing external kept them alive;
## each container plus its voxels was a self-sustaining island that outlived
## the room, the registry and every other owner. Measured on the real
## PLAYGROUND build/free path: 2232 Slabs / 143 392 Voxels retained ~301 MB
## per build, growing linearly across rebuilds (301 → 602 → 907 MB over three
## rounds) and reclaiming 0.02 MB. Storing the id instead breaks the cycle by
## construction, everywhere the pattern is used, at zero extra allocation —
## the alternative (a WeakRef per Voxel) would have cost 143 392 extra objects.
##
## Every container is owned by something that outlives its voxels — Slabs by
## SlabRegistry, Slices by EdgeRegistry, JunctionColumns by room's own array —
## so the id always resolves while the graph is in use. A Voxel deliberately
## built with no container (WorldDelta.project_voxel()'s projected copy) keeps
## id 0, and a write to one still dies loudly on the null, exactly as before.
var _parent_container_id: int = 0


func _init(p_grid_pos: Vector2i, p_level: int, parent_container):
	grid_pos = p_grid_pos
	level = p_level
	_parent_container_id = 0 if parent_container == null else parent_container.get_instance_id()


## Set visibility; no-op if unchanged; propagates dirty upward
func set_visible(v: bool) -> void:
	if visible == v:
		return
	visible = v
	_set_dirty()


## Apply damage state; DESTROYED forces visible=false; propagates dirty upward.
## from_blast only matters for DENTED/CRACKED (see damage_is_blast above) and
## is read once, on the transition into that state — reapplying the same
## state (D20 stacking a second hit into an already-DENTED voxel, say) keeps
## whichever source marked it first, same as the early-return already did for
## damage_state itself.
## D25: carved_side travels with from_blast for the same reason and under the
## same rule — read once, on the transition, so a second blast never rotates an
## already-carved voxel's hole to a new side.
## D32: variant rides the same read-once rule for the same reason — a second
## hit on an already-marked voxel must not swap the art out from under it.
## D3/§3.3: substrate rides the same rule for the same reason.
func set_damage(new_state: int, from_blast: bool = false,
		carved_side: int = CarvedSide.NONE, variant: int = 0, substrate: int = 0) -> void:
	if damage_state == new_state:
		return
	damage_state = new_state
	damage_is_blast = from_blast
	damage_carved_side = carved_side
	damage_variant = variant
	damage_substrate = substrate
	if new_state == DamageState.DESTROYED:
		visible = false
	_set_dirty()


## Clear dirty flag (called by TIC loop after render update)
func clear_dirty() -> void:
	if dirty:
		dirty = false
		instance_from_id(_parent_container_id).decrement_dirty()


## Internal: mark dirty and propagate
func _set_dirty() -> void:
	if not dirty:
		dirty = true
		instance_from_id(_parent_container_id).increment_dirty()


func _to_string() -> String:
	return "Voxel{pos=%s, level=%d, visible=%s, damage=%d}" % [grid_pos, level, visible, damage_state]
