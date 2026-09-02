## DetonationEntryWriter — ONE plan entry's real work, and the only place in the
## whole pipeline that calls `layer.set_cell()`/`erase_cell()` or hands a puff to
## an overlay.
##
## Extracted from `DetonationChoreographer._apply_entry()` on 2026-08-28 for D-3
## (`DETONATION_PRESENTATION_MASTER_PLAN` §3), unchanged in behaviour. It exists
## because the reform replaces the choreographer's PACING, not its writing:
## §3's table says the cell writes "survive as one loop inside the commit" and the
## VFX dispatch "survives and MOVES". Two paths now need this code and they have
## to run from one binary (D-3's gate), so copying it would have created exactly
## the second place for them to drift — and D-6 would then have to reconcile two
## versions instead of deleting one file.
##
## ⚠️ **KIND IS THE ONLY THING THAT DECIDES WHAT HAPPENS HERE — there is no
## ordering, no pacing and no frame in this class.** That is what makes it shared:
## everything the reform is removing lives in the caller.
##
## The two families are worth naming because the reform separates them:
##   - **cells** (`destroy`, `expose`, `dented`, `cracked`, `soot`) — mutate the
##     board, and after D-3 they all land in ONE frame;
##   - **VFX** (`smoke`, `ember`, `debris`) — write nothing, and are what the
##     consequence channel animates afterwards.
## `is_cell_kind()` is that split, in code, so a caller cannot get it wrong by
## listing kinds by hand.
class_name DetonationEntryWriter
extends RefCounted

const SMOKE_COLOR := Color(0.62, 0.60, 0.57, 0.2)
const DEBRIS_FALLBACK_COLOR := Color(0.6, 0.6, 0.6)
const SURFACE_SPARK_SPEED_SCALE: float = 1.3
const SURFACE_SPARK_DURATION_SCALE: float = 0.6

## The kinds that MUTATE THE BOARD. Everything else is drawing.
const CELL_KINDS: Array[String] = ["destroy", "expose", "dented", "cracked", "soot"]

var ember_overlay: EmberOverlay = null
var debris_overlay: DebrisOverlay = null
## `{"<effect>:<material>": Color}` — see Room.blast_debris_palette().
var debris_colors: Dictionary = {}
## `{material_id: Color}`, resolved by whoever owns a MaterialRegistry.
var smoke_tints: Dictionary = {}

## §13.4 — write CLEAN geometry and leave the scorch to a later beat. The
## choreographer sets this true because its soot arrives in a ramp; the presenter
## leaves it FALSE, because §7.1 puts the scorch in the commit and there is no
## later beat to leave it to.
var soot_clean: bool = false


static func is_cell_kind(kind: String) -> bool:
	return CELL_KINDS.has(kind)


## D-3b — the cells whose scorch a caller is about to RAMP IN, as {Vector3i: true}.
##
## ⚠️ **PER-CELL, NEVER A BLANKET FLAG, AND §9.11a IS WHY.** The choreographer
## writes clean everywhere (`soot_clean`) because its ramp then repaints
## everything. The presenter cannot do that: the soot wave admits cells whose
## LIGHT BUCKET moved with their scorch unchanged — a cell in an OLD crater on the
## far side of the map — and writing those clean and walking them back is the
## Director's own 2026-08-23 report (*"a segunda explosão influencia na fuligem da
## primeira"*), measured at 180 cells flashing to near-clean for five frames and
## returning to exactly their old value. So only cells that are actually CHANGING
## are allowed to start clean.
var soot_ramp_cells: Dictionary = {}


## The scorch an entry should write RIGHT NOW — its own, or clean.
func _wave_soot(entry: Dictionary) -> int:
	if soot_clean:
		return VoxelRenderer.FACE_SOOT_CODE_CLEAN
	if not soot_ramp_cells.is_empty():
		var cell: Vector2i = entry.get("cell", Vector2i.ZERO)
		if soot_ramp_cells.has(Vector3i(cell.x, cell.y, int(entry.get("level", 0)))):
			return VoxelRenderer.FACE_SOOT_CODE_CLEAN
	return int(entry.get("soot", VoxelRenderer.FACE_SOOT_CODE_CLEAN))


## One rung down the ladder: every face `by` tones fainter, clamped at clean.
## A face already clean stays clean, so a cell only fades on the faces it is
## actually going to scorch.
static func lightened(faces: Vector3i, by: int) -> Vector3i:
	var clean: int = BlastCalculator.FACE_SOOT_CLEAN
	return Vector3i(
		mini(faces.x + by, clean), mini(faces.y + by, clean), mini(faces.z + by, clean))


func apply(kind: String, entry: Dictionary, voxel_renderer, smoke_overlay) -> int:
	match kind:
		"destroy":
			var layer: TileMapLayer = voxel_renderer.get_layer(entry["level"])
			if layer == null:
				return 0
			layer.erase_cell(entry["cell"])
			voxel_renderer.note_external_write(int(entry["level"]), entry["cell"])
			## GLASS G3 — a shattered glass voxel lives on `_glass_layers`, which
			## `get_layer()` above does not reach; erase it there too. A no-op for
			## every non-glass cell (no glass sublayer at that level).
			voxel_renderer.erase_glass_cell(int(entry["level"]), entry["cell"])
			return 1
		"expose":
			## §2's exposure fallback (B5). Its own step since E-ORGANIC-01 —
			## see flatten_plan() for why nesting these was the spike.
			var elayer: TileMapLayer = voxel_renderer.get_layer(entry["level"])
			if elayer == null:
				return 0
			voxel_renderer._ensure_light_alt(entry["source_id"], entry["atlas_coords"], entry["alt"])
			elayer.set_cell(entry["cell"], entry["source_id"], entry["atlas_coords"], entry["alt"])
			## PERF-P2b: the alt carries bucket and flip; the scorch travels beside it.
			voxel_renderer._write_cell_soot(int(entry["level"]), entry["cell"],
				_wave_soot(entry))
			## PERF-10: this bypassed the light field, so the field's stale set
			## cannot know the cell moved. Say so, or the next stale-driven apply
			## walks past a cell only a map-wide walk would have corrected.
			voxel_renderer.note_external_write(int(entry["level"]), entry["cell"])
			return 1
		"dented", "cracked", "soot":
			var layer2: TileMapLayer = voxel_renderer.get_layer(entry["level"])
			if layer2 == null:
				return 0
			## _ensure_light_alt() mints the (source_id, atlas_coords, alt)
			## TileData alternative if it doesn't exist yet — the SAME call
			## VoxelRenderer._apply_light_to_layer() makes right before its own
			## set_cell(). Cheap/memoized, not a "lookup" in §2's sense (no
			## resolution decision happens here, the triple already arrived
			## fully resolved).
			voxel_renderer._ensure_light_alt(entry["source_id"], entry["atlas_coords"], entry["alt"])
			layer2.set_cell(entry["cell"], entry["source_id"], entry["atlas_coords"], entry["alt"])
			voxel_renderer._write_cell_soot(int(entry["level"]), entry["cell"],
				_wave_soot(entry))
			voxel_renderer.note_external_write(int(entry["level"]), entry["cell"])
			return 1
		"smoke":
			if smoke_overlay == null:
				return 0
			## E-SMOKE-01: scale and alpha are per-entry, not a flat 1.0 —
			## DetonationPlanBuilder derives both from the voxel's damage tier,
			## its ring, and a per-cell hash (see _append_voxel_smoke()).
			## `blobs` is 0 for the GU-level remainder puffs, which means "use
			## the overlay's own 2-3 range"; only per-voxel puffs pin to 1.
			## E-SMOKE-TINT-01 (2026-08-13): the hue comes from the material, the
			## ALPHA does not. VFX-01's per-material tint (wood reads as dark
			## smoke, masonry and metal as light) stopped reaching explosions on
			## 2026-08-05 — the choreographer erases cells directly and never
			## emits `voxel_destroyed`, so `Room._dispatch_destruction_vfx()` has
			## only fired for firearms since. Reinstating it by reconnecting that
			## dispatch would double every puff against the staged smoke waves;
			## tinting the wave entry is the same look without the double.
			##
			## SMOKE_COLOR's own alpha is kept deliberately, and this is the trap:
			## it is 0.2 because per-voxel smoke gets its density from OVERLAP
			## (see that constant's note — at VFX-01's alpha the ring-0 puffs read
			## as a heap of hard-edged discs). VFX-01's `vfx_smoke_alpha` was tuned
			## for one puff per destroyed voxel through a completely different
			## path. Taking the tint's alpha along would silently undo that.
			var puff_color: Color = smoke_tints.get(entry.get("material", ""), SMOKE_COLOR)
			## D-4 — CLAMPED, because `SMOKE_ALPHA_GAIN` can push the entry past 1.0
			## on purpose (see that constant). The ceiling is what keeps "more
			## visible" from becoming the heap of hard-edged discs the 0.2 was
			## chosen to avoid: a puff may be legible, never solid.
			puff_color.a = minf(SMOKE_COLOR.a * float(entry.get("alpha", 1.0)), 0.72)
			## D-4 — `drift_scale` is the HEIGHT axis. This argument has existed on
			## `add_smoke()` since E-SPARK-04 and no blast ever passed it: every puff
			## in every explosion rose at exactly the same rate.
			smoke_overlay.add_smoke(entry["world_pos"], puff_color,
				float(entry.get("scale", 1.0)), entry["duration"],
				int(entry.get("blobs", 0)), float(entry.get("drift", 1.0)))
			return 1
		"ember":
			## E-EMBER-01. No duration is passed: the overlay's own 1.5-4.0 roll
			## plus its height bias is what makes a scorched patch cool unevenly
			## instead of as a bank of identical dots, and that is the VL-D4 look
			## the Director asked to keep ("a gente já tinha um visual bom").
			## `duration_scale` is the material's flammability, 1.0 for wood —
			## an exact no-op today, and the seam the cardboard/fabric materials
			## will use later.
			if ember_overlay == null:
				return 0
			## E-EMBER-02: `delay` is the upward creep's stagger, already rolled
			## deterministically per cell in the plan — the choreographer only
			## forwards it. Velocity/drag/rise stay zero: a scorch ember is
			## PINNED to its voxel (the rising fire is the burst's job, and
			## E-EMBER-02 raised that one instead precisely so it clears the
			## crater and stops hiding these).
			## D-4 — `burnt` is `DetonationPlanBuilder._mark_burnt_embers()`'s flag:
			## this ember sits on a cell the fire ATE, not on a surviving edge, so it
			## gets `EmberOverlay`'s boosted profile (bigger, longer, slower to cool).
			## An unflagged edge ember passes 1.0 / 1.0 and is byte-for-byte
			## unchanged, which is what keeps wood's ratified VL-D4 look untouched.
			var burnt: bool = bool(entry.get("burnt", false))
			var life_gain: float = ember_overlay.burnt_ember_life_gain if burnt else 1.0
			var radius_gain: float = ember_overlay.burnt_ember_radius_gain if burnt else 1.0
			var cool: float = ember_overlay.burnt_ember_cool_rate if burnt else 1.0
			ember_overlay.add_ember(entry["world_pos"], -1.0, Vector2.ZERO, 0.0, 0.0,
				float(entry.get("duration_scale", 1.0)) * life_gain,
				float(entry.get("delay", 0.0)), radius_gain, cool)
			return 1
		"debris":
			## E-DEBRIS-01. The plan already decided WHICH effect this voxel
			## throws and HOW MANY, hashed per cell — this only dispatches.
			## Colour comes from the palette rather than the entry for the same
			## reason smoke's tint does: the builder runs headless, without a
			## MaterialRegistry to ask.
			var effect: String = String(entry.get("effect", ""))
			var color: Color = debris_colors.get(
				"%s:%s" % [effect, entry.get("material", "")], DEBRIS_FALLBACK_COLOR)
			match effect:
				"dust":
					if debris_overlay == null:
						return 0
					debris_overlay.add_dust(entry["world_pos"], entry["floor_pos"], color)
					return 1
				"chips":
					if debris_overlay == null:
						return 0
					debris_overlay.add_chips(entry["world_pos"], entry["floor_pos"],
						int(entry.get("count", 1)), color)
					return 1
				"sparks":
					if smoke_overlay == null:
						return 0
					## E-SPARK-04: a blast's sparks come off a struck SURFACE, same
					## as a bullet's, so they take the same faster/shorter profile
					## — the muzzle's own are the exception and are not routed
					## through here.
					smoke_overlay.add_sparks(entry["world_pos"],
						int(entry.get("count", 1)), color,
						SURFACE_SPARK_SPEED_SCALE, SURFACE_SPARK_DURATION_SCALE)
					return 1
			return 0
	return 0


## GPU-UPLOAD-01 (2026-08-08): every dented/cracked/soot entry's
## source_id/atlas_coords was resolved by DetonationPlanBuilder against
## DamageVariantBaker's pre-bake OR live-composited on the spot — either way it
## was written through DamageCompositeCache.store(), which blits into a CPU-side
## Image and marks the page dirty but leaves the GPU texture upload for
## flush_dirty_pages() (that class's own doc comment). This choreographer is the
## ONLY place a plan ever reaches set_cell() (this file's own header), and it
## never called that flush — every real detonation's marks rendered whatever the
## page texture already held (stale content, or nothing), unless some UNRELATED
## event happened to flush the same page first. Root-caused via
## damage_gallery_debug.gd hitting the identical gap directly.
##
## Called once per FRAME now rather than once per wave (E-ORGANIC-01) — same
## contract, fewer calls, and still a cheap no-op when nothing composited
## (flush_dirty_pages() checks an empty dirty-page set itself).
func flush(voxel_renderer) -> void:
	voxel_renderer.flush_damage_composite_pages()
	## PERF-P2b: one soot upload per flushed frame, never one per cell.
	voxel_renderer.flush_cell_soot()
	## G-D30 — the cook's own batch seam. `erase_glass_cell()` above only flags;
	## this is where a blast that took glass out from under a standing crack
	## re-cuts it, once, instead of once per erased cell.
	voxel_renderer.refresh_glass_crack_occupancy()
