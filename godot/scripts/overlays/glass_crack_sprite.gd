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
	material = mat


## The forward basis, as a pure function — canvas offset for a (run, level)
## offset on a face whose run is along X (`run_axis` 0) or Y (1). Used by the
## selftest to prove the transform above and `VoxelRenderer.glass_cell_face_pos()`
## describe the same geometry, and available to anything that needs the face's
## own metric without building a node.
static func face_offset(run_off: float, level_off: float, run_axis: int) -> Vector2:
	var run_step: Vector2 = RUN_STEP_X if run_axis == 0 else RUN_STEP_Y
	return run_step * run_off + LEVEL_STEP * level_off
