## GlassCrackSprite — GLASS_MASTER_PLAN CRACK-02 / G-D27 (§13, stage S-1).
##
## ONE crack event = ONE of these. A Sprite2D carrying the fracture sheet, laid
## over the pane in the pane's OWN basis, drawing additively and touching nothing
## about the glass underneath.
##
## ⚠️ THE TRANSFORM IS THE WHOLE TRICK, so it is here and not scattered:
## CRACK-01-D measured the wall face's basis — a voxel sits at
## `impact + run · RUN_STEP + level · (0, −VOXEL_STEP)`, RUN_STEP = (16, 8) for a
## run along X and (−16, 8) along Y — and CRACK-01's shader had to INVERT it per
## fragment. Baking the FORWARD basis into `transform` instead makes the quad the
## pane's parallelogram, so the sheet is already anchored, already sheared
## correctly, and the shader has no inverse in it at all.
##
## What this buys over CRACK-01's renderer-side plane (G-D27, all four
## measurable): the glass behind is untouched by construction; a crack is a NODE
## with a position, so a perspective rebuild can recreate it (S-3); N impacts are
## N sprites that alpha-composite, so the 16-group cap, the per-cell group plane
## and the RGBAF strip are gone; and every glass fragment on the map loses a
## `texture()` + branch.
class_name GlassCrackSprite
extends Sprite2D

## The canonical wall-face steps, in canvas pixels per voxel. Same numbers
## `VoxelRenderer.glass_cell_face_pos()` walks and `glass_crack_selftest` [10]
## pins — kept in one place so the sprite and the position can never disagree.
const RUN_STEP_X: Vector2 = Vector2(16.0, 8.0)    ## a run along X (SW / NE face)
const RUN_STEP_Y: Vector2 = Vector2(-16.0, 8.0)   ## a run along Y (SE / NW face)
const LEVEL_STEP: Vector2 = Vector2(0.0, -20.0)   ## GeometryCoords.VOXEL_STEP_PX, up

## A pane's clip bounds are cell-centred, so its outer voxels reach half a cell
## past their own centre. Half a voxel of slack, not a nudge.
const PANE_CLIP_SLACK: float = 0.5


## `sheet` is the fracture texture, `span` how many (run, level) voxels it covers
## on the pane, `origin` the impact's renderer-local position, `run_axis` 0 for a
## run along X / 1 along Y, and `pane_lo` / `pane_hi` the pane's bounds as
## (run, level) offsets from the impact, in voxels.
func setup(sheet: Texture2D, span: Vector2, origin: Vector2, run_axis: int,
		pane_lo: Vector2, pane_hi: Vector2, shader: Shader) -> void:
	texture = sheet
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if sheet == null or shader == null:
		## B6 loud-fail — a crack that silently draws nothing is exactly the class
		## of failure §13.3 exists to prevent.
		push_error("[GlassCrackSprite] CRACK-02: no %s — the crack cannot draw"
			% ("fracture sheet" if sheet == null else "shader"))
		return
	var w: float = maxf(float(sheet.get_width()), 1.0)
	var h: float = maxf(float(sheet.get_height()), 1.0)
	var run_step: Vector2 = RUN_STEP_X if run_axis == 0 else RUN_STEP_Y
	## texture pixel -> canvas: one texel of width is `span.x / w` voxels of run,
	## one texel of height is `span.y / h` voxels of level DOWNWARD (UV.y grows
	## down, level grows up), so the level column carries the sign.
	transform = Transform2D(
		run_step * (span.x / w),
		-LEVEL_STEP * (span.y / h),
		origin)

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("crack_sheet", sheet)
	mat.set_shader_parameter("crack_span", span)
	mat.set_shader_parameter("crack_pane_lo", pane_lo - Vector2(PANE_CLIP_SLACK, PANE_CLIP_SLACK))
	mat.set_shader_parameter("crack_pane_hi", pane_hi + Vector2(PANE_CLIP_SLACK, PANE_CLIP_SLACK))
	## ⚠️ THE OPACITY IS A DIRECTOR DIAL AND IT MOVED TWICE ALREADY (90% then 80%,
	## 2026-09-02). `INFILTRAITOR_GLASS_CRACK_OPACITY` overrides the shader default
	## so a sweep is one boot per value instead of an edit per value.
	var env := OS.get_environment("INFILTRAITOR_GLASS_CRACK_OPACITY")
	if env != "":
		mat.set_shader_parameter("crack_opacity", clampf(float(env), 0.0, 1.0))
	material = mat


## ── G-D35 B-2 — THE FIELD MODE ──────────────────────────────────────────────
##
## A blast craze is not a crack at a place; it is the whole pane, crazed. So the
## quad is the PANE's rectangle and the sheet repeats across it on a lattice.
##
## `span` is the quad in voxels (symmetric about `origin`, which is the pane's
## CENTRE CELL — the one anchor every other field in the record is measured from,
## so `_build_crack_occupancy()` serves both modes unchanged). `pane_lo`/`pane_hi`
## are the pane's bounds as (run, level) offsets from that centre, and
## `tile_span` is one tile in voxels.
##
## ⚠️ THE LATTICE IS ANCHORED AT `pane_lo`, NOT AT THE QUAD'S CENTRE. The quad is
## symmetric and the pane need not be (a centre CELL can sit half a voxel off the
## pane's true middle), so anchoring at the centre would move the pattern relative
## to the glass whenever that asymmetry changed. The pane's own corner does not
## move.
func setup_field(sheet: Texture2D, span: Vector2, origin: Vector2, run_axis: int,
		pane_lo: Vector2, pane_hi: Vector2, tile_span: Vector2, shader: Shader,
		field_origin: Vector2, field_dir: Vector2) -> void:
	setup(sheet, span, origin, run_axis, pane_lo, pane_hi, shader)
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("crack_field", true)
	mat.set_shader_parameter("crack_tile_span", tile_span)
	## ⚠️ `field_origin` IS NOT `pane_lo`, AND IT USED TO BE. B-2 anchored the
	## lattice at the low-run corner of the CURRENT view; B-2b anchors it at the
	## corner that is minimal in BASE space and counts in the base direction, so
	## the same glass wears the same craze from every camera angle. The room owns
	## that conversion — this node is handed the answer.
	mat.set_shader_parameter("crack_field_origin", field_origin)
	mat.set_shader_parameter("crack_field_dir", field_dir)


## G-D30 — bind (or rebind) this crack's occupancy image. `origin` is
## (run_min, level_max) as offsets from the impact: the RAW pane bounds, not the
## clip bounds, because those carry half a voxel of slack and would shift the
## lookup by half a texel.
func set_occupancy(tex: Texture2D, size: Vector2, origin: Vector2) -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("crack_occupancy", tex)
	mat.set_shader_parameter("crack_occ_size", size)
	mat.set_shader_parameter("crack_occ_origin", origin)


## G-D30's dial, 0 (the web outlives the pane) .. 1 (the web lives only on glass
## that still exists). Continuous because the question it answers is fiction.
## CRACK-04 / G-D34 — bind the opening's void. `origin`/`size` are in VOXELS from
## the impact, the same space `set_occupancy()` uses. Leaving it unbound is the
## correct state for a crack with no hole under it: the shader's mask defaults to
## black, so the sheet keeps its whole centre.
func set_opening(tex: Texture2D, origin: Vector2, size: Vector2) -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("crack_opening", tex)
	mat.set_shader_parameter("crack_opening_origin", origin)
	mat.set_shader_parameter("crack_opening_size", size)


func set_hole_cut(v: float) -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("crack_hole_cut", clampf(v, 0.0, 1.0))


## The forward basis, as a pure function — canvas offset for a (run, level)
## offset on a face whose run is along X (`run_axis` 0) or Y (1). Used by the
## selftest to prove the transform above and `VoxelRenderer.glass_cell_face_pos()`
## describe the same geometry, and available to anything that needs the face's
## own metric without building a node.
static func face_offset(run_off: float, level_off: float, run_axis: int) -> Vector2:
	var run_step: Vector2 = RUN_STEP_X if run_axis == 0 else RUN_STEP_Y
	return run_step * run_off + LEVEL_STEP * level_off
