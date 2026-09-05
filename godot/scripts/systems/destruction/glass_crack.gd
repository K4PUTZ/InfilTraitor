## GlassCrack — GLASS_MASTER_PLAN CRACK-02 (§13, G-D14 / G-D24 / G-D26 / G-D27).
##
## A round that lands on a pane and does NOT breach the voxel (a weak hit, or a
## rifle round whose shatter roll was lost) leaves the pane STANDING and crazes
## the glass around the hole. That is this file: given the pane, the hit and the
## weapon's hole width, it returns the still-standing glass cells to mark CRACKED
## and everything the crack SPRITE needs to be placed.
##
## PURE by construction — it takes slice lists, never the registry — so the shot
## path applies the result the way `agent_shot_controller` applies
## `GlassShatter.plan_pane_shatter()`, and the selftest hands it a synthetic
## frame (PREDICTION_MASTER_PLAN's rule for `build_plan()`).
##
## ⚠️ STATE AND RENDER ARE DECOUPLED HERE, AND THAT IS THE POINT OF CRACK-02.
## `plan_pane_crack()` decides which voxels enter the CRACKED STATE — a gameplay
## fact, saved by VL-PERSIST, unrelated to pixels. The RENDER is a
## `GlassCrackSprite` laid over the pane in the pane's own basis (G-D27), whose
## reach is `SHEET_SPAN_*` and has nothing to do with the state radius. CRACK-01
## conflated the two through a per-cell group plane; that plane is deleted.
##
## G-D24 — a cell already covered by a DIFFERENT crack, reached by this fracture,
## is not crazed: it is DESTROYED (crossed cracks drop the piece) and falls
## through `GlassFall` like any other break. With no per-cell plane the test is
## geometric, against the renderer's crack registry (`glass_crack_covering`).
class_name GlassCrack

const GeometryCoordsMod = preload("res://godot/scripts/geometry/geometry_coords.gd")
## CRACK-04 — B4's one hash, for the variant pick. Same owner the bake uses.
const FacadeSampler = preload("res://godot/scripts/systems/facade_sampler.gd")

## G-D14 — the crack web's reach, per hole width, as (run, level) voxel radii.
## This is the set of voxels that enter the CRACKED STATE, and — since CRACK-02
## — nothing else: it no longer gates where the sheet may draw, because the sheet
## is a sprite with its own extent. It is also G-D24's region: a later fracture
## that reaches inside this rectangle is a crossing.
##
## Sized against `SHEET_SPAN_*` below so the state roughly covers the ink. Tuned
## 2026-09-02: *"está muito grande o padrão visual pra um buraco de pistola. Ele
## tem que ser mais compacto."* All `static var` — Director dials.
static var CRACK_RADIUS_TIGHT := Vector2i(4, 4)
static var CRACK_RADIUS_WIDE := Vector2i(10, 8)

## How many (run, level) VOXELS the full fracture sheet spans on the pane. This
## is the compactness dial the Director tunes by looking, and since CRACK-02 it
## is a NODE SCALE rather than a shader uniform — the sprite's transform is built
## from it. The sheets carry their ink in the middle ~34% of the page, so a
## `tight` span of 20 x 10 puts a pistol's web inside ~3-4 voxels.
## ── CRACK-04 — ONE SHEET FAMILY PER OPENING ─────────────────────────────────
##
## (Director, 2026-09-04: *"Vamos refazer todos os decals, adaptando eles pra cada
## abertura […] 3 decals pra cada tipo de buraco"*, and then *"aposenta as duas
## antigas"*.)
##
## `fracture_manifest.json` is written by `gen_fracture_sheet.py` beside the
## sheets, and carries each opening's page SPAN in voxels. It is read rather than
## recomputed on purpose: the span is a property of the page the art was actually
## drawn on, and an engine-side formula would be a second opinion about it — free
## to drift the day the generator's ratio is retuned, with nothing failing.
##
## ⛔ `fracture_glass_tight.png` / `_wide.png` ARE RETIRED. They drew a ROUND hole,
## which no member of the family is.
const MANIFEST_PATH: String = "res://ASSETS/materials/glass/fracture_manifest.json"
const SHEET_TEMPLATE: String = "res://ASSETS/materials/glass/fracture_glass_%s_%d.png"

static var _manifest: Dictionary = {}
static var _manifest_loaded: bool = false


static func _manifest_data() -> Dictionary:
	if _manifest_loaded:
		return _manifest
	_manifest_loaded = true
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		## B6 loud-fail: without the manifest every crack would silently fall back
		## to one span and draw its web at the wrong size on every opening.
		push_error("[GlassCrack] CRACK-04: %s is missing — run tools/persistent/gen_fracture_sheet.py --all"
			% MANIFEST_PATH)
		return _manifest
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[GlassCrack] CRACK-04: %s is not valid JSON" % MANIFEST_PATH)
		return _manifest
	_manifest = parsed
	return _manifest


## How many variants each opening ships. Read from the manifest so adding a fourth
## is a generator run, not an edit here.
static func variant_count() -> int:
	return maxi(1, int(_manifest_data().get("variants", 1)))


## Which variant this hole draws. ⚠️ B4 FNV-1a on a BASE-space key, the same rule
## and the same reason as the opening's own pick — a variant re-rolled on a
## perspective flip would redraw a standing crack every time the camera turned.
## Salted apart from the opening pick, or the two would correlate and an opening
## would only ever be seen with one of its three sheets.
static func pick_variant(base_key: String) -> int:
	return FacadeSampler._fnv1a_hash("variant|%s" % base_key) % variant_count()


## The sheet for one (opening, variant), or "" when the opening is unknown.
static func sheet_path(opening_id: String, variant: int) -> String:
	if opening_id == "" or not _manifest_data().get("openings", {}).has(opening_id):
		return ""
	return SHEET_TEMPLATE % [opening_id, variant % variant_count()]


## `WeaponDef.blowout` at or above this takes the WIDE sheet (rifle-class). The
## shipped arsenal: pistol/shotgun 0.0, assault rifle 0.65 — so the split is
## exactly pistol/pellet → tight, rifle → wide (G-D14).
static var WIDE_BLOWOUT_MIN: float = 0.5


static func wide_for_blowout(blowout: float) -> bool:
	return blowout >= WIDE_BLOWOUT_MIN


## ── G-D28's `armored` CLASS (CRACK-05, 2026-09-04) ──────────────────────────
##
## The manifest key of the sheet a stopped round leaves. ⚠️ IT IS NOT AN OPENING
## AND MUST NEVER BE ONE: `GlassOpening.FAMILY` holds HOLES, and this class exists
## precisely because armoured glass loses no voxel (G-D15) — *"estilhaça mas não
## rompe"*. Adding it to the family would make it pickable by `pick()` and
## cuttable by `refresh_glass_rims()`, which is the one pane that must never be
## cut. It is a sheet id, chosen here, and nowhere else knows the difference.
## ⚠️ TWO OF THEM, ON G-D14's OWN AXIS (Director, 2026-09-04: *"3 versões
## diferentes pra cada calibre"*). A rifle leaves a bigger crush mark than a
## pistol, and the split that already exists — `WeaponDef.blowout` — is the one
## that says so. Nothing else about the two sheets differs: the composition is
## page-relative, so the SPAN is the whole size decision (10 x 5 voxels against
## 16 x 8, ruled off `glass_armored_span_strip_2026-09-04.png`).
const ARMORED_SHEET_TIGHT: String = "armored_tight"
const ARMORED_SHEET_WIDE: String = "armored_wide"


## WHICH SHEET this crack draws, as a manifest key.
##
## ⚠️ ONE DEFINITION, AND IT USED TO BE TWO. The "a crack with no hole borrows the
## smallest member's page" fallback was written once in `sheet_span_for()` and
## again in `VoxelRenderer.spawn_glass_crack()`, so the PAGE and the QUAD were
## chosen by two copies of one rule — the arrangement that silently draws a sheet
## at another sheet's scale the day only one of them is edited. G-D28 is that day.
##
## The three cases, and the order matters:
##   * a hole was opened → the opening's own page, because the sheet's void IS
##     that polygon (G-D34);
##   * no hole, and the pane STOPS rounds or shatters whole → the `armored` pair,
##     an opaque crushed-white core. WHETHER it is armoured is decided by
##     MATERIAL/CLASS and never by the weapon — G-D28's trigger is
##     `glass_armored` and the INDESTRUCTIBLE screens. ⚠️ WHICH OF THE TWO is the
##     weapon's business, and only its size: `wide` is G-D14's blowout split, so
##     a rifle's crush mark is a bigger page than a pistol's;
##   * no hole, ordinary glass → the smallest member's page, whose 0.8-voxel void
##     is too small to read as a feature. Unchanged.
static func sheet_id_for(opening_id: String, wide: bool, armored: bool = false) -> String:
	if opening_id != "":
		return opening_id
	if armored:
		return ARMORED_SHEET_WIDE if wide else ARMORED_SHEET_TIGHT
	return "chamfer_45_wide" if wide else "chamfer_45"


## The page span, in voxels, for the sheet this crack actually draws.
##
## ⚠️ `wide` NO LONGER SIZES ANYTHING. It still chooses the opening's size CLASS
## (G-D14: pistol/pellet small, rifle large), but the span now comes from the
## opening itself, because a `crescent_wide` page is twice a `chamfer_45_wide`
## page and one number for both would draw one of them at the wrong scale.
static func sheet_span_for(opening_id: String, wide: bool, armored: bool = false) -> Vector2:
	return page_span(sheet_id_for(opening_id, wide, armored))


## The page span of ONE manifest key, in voxels — the single reader every caller
## goes through. ⚠️ It is a property of the page the art was drawn on and is read,
## never recomputed: an engine-side formula would be a second opinion about a
## number the generator owns, free to drift the day its ratio is retuned with
## nothing failing. B-2 shares it, where the same number means "one TILE".
static func page_span(sheet_id: String) -> Vector2:
	var row: Dictionary = _manifest_data().get("openings", {}).get(sheet_id, {})
	var span: Array = row.get("span", [])
	if span.size() == 2:
		return Vector2(float(span[0]), float(span[1]))
	return Vector2(20.0, 10.0)


## ── G-D35 B-2 — THE BLAST CRAZE FIELD ───────────────────────────────────────
##
## A blast that a pane SURVIVES crazes it whole (B-1). What draws that is not a
## page centred on anything — there is nothing to centre on — but a TILED field
## over the pane's own rectangle. These are the two manifest keys G-D37 ruled:
## one generator, two parameter sets, fine and coarse.
##
## ⚠️ FINE IS THE NEAR BLAST. §16.2: *"a near blast crazes into small polygons, a
## far one into large ones"*, and `CRAZE_RING_INTENSITY` runs 1.0 at ring 0 down
## to 0.30 at ring 3 — so intensity and granularity move TOGETHER, and a high
## intensity is the FINE mesh. Getting this backwards is invisible in every test
## that does not look at a picture.
const CRAZE_SHEET_FINE: String = "blast_fine"
const CRAZE_SHEET_COARSE: String = "blast_coarse"

## Intensity at or above this crazes FINE — a Director dial like every other
## balance row here, calibrated by looking.
##
## ⚠️ 0.67, AND THE FIRST VALUE WAS WRONG IN A WAY ONLY THE REAL TABLE SHOWS.
## B-2 shipped 0.5 with a comment claiming it put rings 0/1 fine and 2/3 coarse.
## `CRAZE_RING_INTENSITY` is [1.0, 0.80, 0.55, 0.30], so 0.5 actually made THREE
## of the four rings fine and left the coarse mesh reachable at ring 3 alone —
## half of G-D37's art almost never drawn, and nothing anywhere would have said
## so. 0.67 sits between 0.80 and 0.55, which is the split the comment always
## described. Read the table, not the midpoint of its endpoints.
static var CRAZE_FINE_MIN: float = 0.67


static func craze_sheet_id_for(intensity: float) -> String:
	return CRAZE_SHEET_FINE if intensity >= CRAZE_FINE_MIN else CRAZE_SHEET_COARSE


## Whether B-3 has delivered the craze art yet.
##
## ⚠️ THIS IS A STAGE GATE, NOT A LOUD FAILURE, AND THE DISTINCTION IS DELIBERATE.
## B6 says a missing dependency fails loudly — but this dependency is not missing,
## it is NOT BUILT YET, and the ordering is on purpose (§16.5: the wrong art wired
## to a real trigger is worse than no art, because it looks finished). So the
## trigger is fully wired and the field simply does not spawn until the manifest
## carries a `blast_*` row, at which point it lights up with no code change.
static func has_craze_art() -> bool:
	var o: Dictionary = _manifest_data().get("openings", {})
	return o.has(CRAZE_SHEET_FINE) or o.has(CRAZE_SHEET_COARSE)


## Pure, and shaped like `plan_pane_crack()` so the two cannot disagree about what
## a pane is. Given a pane's slices and the blast's intensity, everything the
## FIELD sprite needs.
##
## ⚠️ THE QUAD IS CENTRED ON A REAL CELL, NOT ON THE PANE'S TRUE MIDDLE. A pane
## with an even number of cells has its middle on a half-voxel, and every other
## field in the record — `_build_crack_occupancy()`'s world lookup above all — is
## measured in whole cells from one anchor. Picking the centre CELL keeps ONE
## anchor for the whole record at the cost of at most one voxel of extra quad,
## which the pane clip discards anyway.
##
## Returns {} when the pane holds no glass at all.
static func plan_pane_field(pane_slices: Array, face: int, intensity: float) -> Dictionary:
	if pane_slices.is_empty():
		return {}
	var run_is_x: bool = (face == Face.SW or face == Face.NE)
	var run_lo: int = 0
	var run_hi: int = 0
	var lvl_lo: int = 0
	var lvl_hi: int = 0
	var cross: int = 0
	var seen: bool = false
	var pane_id: String = ""
	for s in pane_slices:
		if pane_id == "":
			pane_id = s.pane_id
		var s_base: int = GeometryCoordsMod.storey_level_base(s.start_storey)
		for v in s.voxels:
			## ⚠️ `material_at()`, never `slice.material` — a G-D9 banded window
			## keeps its brick sill and head in these same slices, and the field
			## must not reach across them. Same rule `plan_pane_crack()` walks.
			if not GlassMaterials.is_glass(s.material_at(v.level - s_base)):
				continue
			var run: int = v.grid_pos.x if run_is_x else v.grid_pos.y
			## The EXTENT counts DESTROYED glass, exactly as the crack's does: a
			## hole is still part of the pane, and clipping the field to the
			## standing glass would shrink it every time the pane took a hit.
			if not seen:
				run_lo = run
				run_hi = run
				lvl_lo = v.level
				lvl_hi = v.level
				cross = v.grid_pos.y if run_is_x else v.grid_pos.x
				seen = true
			else:
				run_lo = mini(run_lo, run)
				run_hi = maxi(run_hi, run)
				lvl_lo = mini(lvl_lo, v.level)
				lvl_hi = maxi(lvl_hi, v.level)
	if not seen:
		return {}
	var c_run: int = (run_lo + run_hi) / 2
	var c_lvl: int = (lvl_lo + lvl_hi) / 2
	var centre_cell := Vector2i(c_run, cross) if run_is_x else Vector2i(cross, c_run)
	var lo := Vector2(float(run_lo - c_run), float(lvl_lo - c_lvl))
	var hi := Vector2(float(run_hi - c_run), float(lvl_hi - c_lvl))
	## The quad is symmetric about the centre cell (`Sprite2D.centered`), so it has
	## to reach the FARTHER side on each axis; +1 turns a cell-centre radius into
	## whole cells.
	var span := Vector2(
		2.0 * maxf(absf(lo.x), absf(hi.x)) + 1.0,
		2.0 * maxf(absf(lo.y), absf(hi.y)) + 1.0)
	var sheet: String = craze_sheet_id_for(intensity)
	return {
		"pane_id": pane_id,
		"run_axis": 0 if run_is_x else 1,
		"face": face,
		"centre_cell": centre_cell,
		"centre_level": c_lvl,
		"centre_run": c_run,
		"pane_lo": lo,
		"pane_hi": hi,
		"span": span,
		"intensity": intensity,
		"sheet": sheet,
		## One TILE, in voxels — the same manifest number a page span is, because
		## for this class the page IS the tile. B-3 owns it.
		"tile_span": page_span(sheet),
	}


## Pure. `pane_slices` share one `pane_id`; `face` fixes the run axis (X for
## SW/NE, Y for SE/NW — the same rule GlassShatter uses). `hit_grid_pos` /
## `hit_level` are the struck voxel. Returns:
##   cells       Array[{level:int, cell:Vector2i, voxel:Voxel}] — standing glass
##               to mark CRACKED (or DESTROY, on a G-D24 crossing)
##   run_axis    0 (run along X) or 1 (along Y)
##   impact_run  the struck voxel's coord along the run axis
##   hit_cell / hit_level   the struck voxel, for the sprite's placement
##   radius      the (run, level) rectangle above — G-D24's region
##   wide        passed through, picks the sheet
##   pane_id     the pane these slices belong to
##   pane_lo / pane_hi   the pane's own extent as (run, level) OFFSETS from the
##               impact, in voxels — what clips the sprite to the pane (G-D27's
##               one named cost: a sprite is a rectangle and a pane is not)
static func plan_pane_crack(pane_slices: Array, face: int, hit_grid_pos: Vector2i,
		hit_level: int, wide: bool) -> Dictionary:
	var run_is_x: bool = (face == Face.SW or face == Face.NE)
	var impact_run: int = hit_grid_pos.x if run_is_x else hit_grid_pos.y
	var radius: Vector2i = CRACK_RADIUS_WIDE if wide else CRACK_RADIUS_TIGHT
	## G-D28 — is this an ARMOURED-family pane? Read from the pane's own slices,
	## the way `GlassShatter.plan_pane_shatter()` reads them: a pane is
	## single-material by construction (`GlassPaneGrouper` splits the union on
	## material), and V-D's per-placement override rides the same slice.
	##
	## ⚠️ BOTH CLASSES, NOT JUST `glass_armored`. G-D28 names the trigger as
	## *"`glass_armored`, and INDESTRUCTIBLE screens"* — a control interface stops
	## the round outright (V-C), which is the same statement the crushed core makes.
	var pane_material: String = pane_slices[0].material if not pane_slices.is_empty() \
		else GlassMaterials.BASE
	var pane_class: int = pane_slices[0].glass_class if not pane_slices.is_empty() \
		else GlassMaterials.CLASS_UNSET
	var armored: bool = GlassMaterials.stops_a_round(pane_material, pane_class) \
		or GlassMaterials.shatters_whole_pane(pane_material, pane_class)
	var cells: Array = []
	var run_lo: int = impact_run
	var run_hi: int = impact_run
	var lvl_lo: int = hit_level
	var lvl_hi: int = hit_level
	var pane_id: String = ""
	for s in pane_slices:
		if pane_id == "":
			pane_id = s.pane_id
		var s_base: int = GeometryCoordsMod.storey_level_base(s.start_storey)
		for v in s.voxels:
			## A G-D9 banded pane keeps its brick sill/head in these same slices —
			## a fracture does not cross the frame, and neither does the pane's own
			## extent.
			if not GlassMaterials.is_glass(s.material_at(v.level - s_base)):
				continue
			var run: int = v.grid_pos.x if run_is_x else v.grid_pos.y
			## ⚠️ The EXTENT counts destroyed glass; the WEB does not. A hole the
			## round already made is still part of the pane, so clipping the sprite
			## to the standing glass would shrink the web every time the pane takes
			## a second hit.
			run_lo = mini(run_lo, run)
			run_hi = maxi(run_hi, run)
			lvl_lo = mini(lvl_lo, v.level)
			lvl_hi = maxi(lvl_hi, v.level)
			if v.damage_state == Voxel.DamageState.DESTROYED:
				continue
			if absi(run - impact_run) > radius.x:
				continue
			if absi(v.level - hit_level) > radius.y:
				continue
			cells.append({"level": v.level, "cell": v.grid_pos, "voxel": v})
	return {
		"cells": cells,
		"run_axis": 0 if run_is_x else 1,
		## ⚠️ THE FACE, NOT JUST THE RUN AXIS. `run_axis` collapses SW with NE and
		## SE with NW, and the point a crack radiates from — the centre of the
		## voxel's visible face — differs between the members of each pair. It was
		## dropped here and the renderer used one constant for all four.
		"face": face,
		"impact_run": impact_run,
		"hit_cell": hit_grid_pos,
		"hit_level": hit_level,
		"radius": radius,
		"wide": wide,
		## G-D28 — the pane held rounds by its CLASS, so a hit that opened no hole
		## draws the crushed-white core instead of borrowing a bullet page.
		"armored": armored,
		"pane_id": pane_id,
		"pane_lo": Vector2(float(run_lo - impact_run), float(lvl_lo - hit_level)),
		"pane_hi": Vector2(float(run_hi - impact_run), float(lvl_hi - hit_level)),
	}


## The RENDER half of a plan, as `VoxelRenderer.spawn_glass_crack()` wants it.
## Separated from `apply()` because CRACK-02 decoupled state from render (§13.1)
## and S-3 needs the render half ALONE: after a perspective flip the CRACKED
## states are already back (VL-PERSIST re-applied them), and re-running `apply()`
## would set them a second time and re-run G-D24 against the cracks it is in the
## middle of rebuilding.
static func sprite_spec(plan: Dictionary) -> Dictionary:
	return {
		"pane_id": String(plan.get("pane_id", "")),
		"run_axis": int(plan["run_axis"]),
		"wide": bool(plan.get("wide", false)),
		"impact_run": int(plan["impact_run"]),
		"impact_level": int(plan["hit_level"]),
		"impact_cell": plan["hit_cell"],
		"face": int(plan.get("face", 0)),
		"radius": plan["radius"],
		"span": sheet_span_for(String(plan.get("opening", "")), bool(plan.get("wide", false)),
			bool(plan.get("armored", false))),
		"armored": bool(plan.get("armored", false)),
		"variant": int(plan.get("variant", 0)),
		"pane_lo": plan["pane_lo"],
		"pane_hi": plan["pane_hi"],
		## CRACK-04 / G-D34 — the opening this hole was cut with, or "" when the
		## round opened no hole at all. The sheet's inner void is cut from it, so
		## the hole's shape and the decal's internal shape are the same polygon.
		"opening": String(plan.get("opening", "")),
	}


## Apply a plan: set the voxel states, resolve G-D24's crossings against the
## cracks already live, and spawn the crack SPRITE. Shared by the shot path
## (`agent_shot_controller._craze_pane_around_hole`) and the demo capture, so the
## sequence has ONE definition. `renderer` is the VoxelRenderer; it must expose
## `glass_crack_covering()` and `spawn_glass_crack()`.
##
## ⚠️ ORDER IS LOAD-BEARING: every crossing is tested BEFORE the new crack is
## registered, or the fracture would cross itself and destroy its own web.
##
## Returns { crack_id, crazed, crossed, voxels:Array[Voxel], fallen:Array }. The
## caller folds `voxels` into its own bookkeeping (the shot's cell dicts /
## VL-PERSIST); `fallen` is the G-D24 drop-outs for GlassFall. `crack_id` is 0
## when nothing was crazed — a fracture whose every cell crossed an older one has
## opened a hole, not left a web, so it gets no sprite.
static func apply(renderer, plan: Dictionary) -> Dictionary:
	var run_is_x: bool = int(plan["run_axis"]) == 0
	var pane_id: String = String(plan.get("pane_id", ""))
	var crazed: int = 0
	var crossed: int = 0
	var touched: Array = []
	var fallen: Array = []
	for c in plan["cells"]:
		var v: Voxel = c["voxel"]
		if v.damage_state == Voxel.DamageState.DESTROYED:
			continue
		var run: int = v.grid_pos.x if run_is_x else v.grid_pos.y
		if renderer.glass_crack_covering(pane_id, run, int(c["level"])) != 0:
			## G-D24 — two fractures cross here; the piece drops out.
			v.set_damage(Voxel.DamageState.DESTROYED, false, Voxel.CarvedSide.NONE, 0, 0)
			fallen.append({"grid_pos": v.grid_pos, "level": v.level})
			crossed += 1
		else:
			if v.damage_state != Voxel.DamageState.CRACKED:
				v.set_damage(Voxel.DamageState.CRACKED, false, Voxel.CarvedSide.NONE, 0, 0)
			crazed += 1
		touched.append(v)
	var crack_id: int = 0
	if crazed > 0:
		crack_id = renderer.spawn_glass_crack(sprite_spec(plan))
	return {"crack_id": crack_id, "crazed": crazed, "crossed": crossed,
		"voxels": touched, "fallen": fallen}
