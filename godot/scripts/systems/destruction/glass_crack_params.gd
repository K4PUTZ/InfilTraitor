## GlassCrackParams — GLASS_MASTER_PLAN CRACK-02 / G-D27 (§13), as DATA.
##
## ONE crack event = ONE of these: every shader parameter the crack carries (the fracture sheet, its span, the pane's
## clip bounds, the craze field, the occupancy cut, the opening void, the hole-cut dial). `VoxelBoard` keeps it in
## the crack's record (`rec["params"]` is `params`, by reference), and `GlassCrackMirror3D` gives the record a quad on
## the pane's plane in the 3D board and copies `params` into it every frame.
##
## R3D-END (END-2): this was `GlassCrackSprite`, a Sprite2D laid over the pane in the pane's own canvas basis, with a
## ShaderMaterial on `glass_crack.gdshader` as the record's 2D consumer. The 2D board is gone, so the node, its
## transform and its material are too; what the 3D board reads was always only `params` (R3D-9).
class_name GlassCrackParams
extends RefCounted

## A pane's clip bounds are cell-centred, so its outer voxels reach half a cell
## past their own centre. Half a voxel of slack, not a nudge.
const PANE_CLIP_SLACK: float = 0.5

## Every shader parameter this crack carries.
var params: Dictionary = {}

## False when the sheet was missing at `setup()` (already loud-failed): nothing is bound after that, as before.
var valid: bool = false


func _param(param_name: String, value: Variant) -> void:
	params[param_name] = value


## `sheet` is the fracture texture, `span` how many (run, level) voxels it covers on the pane, and `pane_lo` /
## `pane_hi` the pane's bounds as (run, level) offsets from the impact, in voxels.
func setup(sheet: Texture2D, span: Vector2, pane_lo: Vector2, pane_hi: Vector2) -> void:
	if sheet == null:
		## B6 loud-fail — a crack that silently draws nothing is exactly the class
		## of failure §13.3 exists to prevent.
		push_error("[GlassCrackParams] CRACK-02: no fracture sheet — the crack cannot draw")
		return
	valid = true
	_param("crack_sheet", sheet)
	_param("crack_span", span)
	_param("crack_pane_lo", pane_lo - Vector2(PANE_CLIP_SLACK, PANE_CLIP_SLACK))
	_param("crack_pane_hi", pane_hi + Vector2(PANE_CLIP_SLACK, PANE_CLIP_SLACK))
	## ⚠️ THE OPACITY IS A DIRECTOR DIAL AND IT MOVED TWICE ALREADY (90% then 80%,
	## 2026-09-02). `INFILTRAITOR_GLASS_CRACK_OPACITY` overrides the shader default
	## so a sweep is one boot per value instead of an edit per value.
	var env := OS.get_environment("INFILTRAITOR_GLASS_CRACK_OPACITY")
	if env != "":
		_param("crack_opacity", clampf(float(env), 0.0, 1.0))


## ── G-D35 B-2 — THE FIELD MODE ──────────────────────────────────────────────
##
## A blast craze is not a crack at a place; it is the whole pane, crazed. So the
## quad is the PANE's rectangle and the sheet repeats across it on a lattice.
##
## `span` is the quad in voxels (symmetric about the pane's CENTRE CELL — the one anchor every other field in the
## record is measured from, so `_build_crack_occupancy()` serves both modes unchanged). `pane_lo`/`pane_hi` are the
## pane's bounds as (run, level) offsets from that centre, and `tile_span` is one tile in voxels.
##
## ⚠️ `field_origin` IS NOT `pane_lo`, AND IT USED TO BE. B-2 anchored the
## lattice at the low-run corner of the CURRENT view; B-2b anchors it at the
## corner that is minimal in BASE space and counts in the base direction, so
## the same glass wears the same craze from every camera angle. The room owns
## that conversion — this is handed the answer.
func setup_field(sheet: Texture2D, span: Vector2, pane_lo: Vector2, pane_hi: Vector2, tile_span: Vector2,
		field_origin: Vector2, field_dir: Vector2) -> void:
	setup(sheet, span, pane_lo, pane_hi)
	if not valid:
		return
	_param("crack_field", true)
	_param("crack_tile_span", tile_span)
	_param("crack_field_origin", field_origin)
	_param("crack_field_dir", field_dir)


## G-D30 — bind (or rebind) this crack's occupancy image. `origin` is
## (run_min, level_max) as offsets from the impact: the RAW pane bounds, not the
## clip bounds, because those carry half a voxel of slack and would shift the
## lookup by half a texel.
func set_occupancy(tex: Texture2D, size: Vector2, origin: Vector2) -> void:
	if not valid:
		return
	_param("crack_occupancy", tex)
	_param("crack_occ_size", size)
	_param("crack_occ_origin", origin)


## CRACK-04 / G-D34 — bind the opening's void. `origin`/`size` are in VOXELS from
## the impact, the same space `set_occupancy()` uses. Leaving it unbound is the
## correct state for a crack with no hole under it: the shader's mask defaults to
## black, so the sheet keeps its whole centre.
func set_opening(tex: Texture2D, origin: Vector2, size: Vector2) -> void:
	if not valid:
		return
	_param("crack_opening", tex)
	_param("crack_opening_origin", origin)
	_param("crack_opening_size", size)


## G-D30's dial, 0 (the web outlives the pane) .. 1 (the web lives only on glass
## that still exists). Continuous because the question it answers is fiction.
func set_hole_cut(v: float) -> void:
	if not valid:
		return
	_param("crack_hole_cut", clampf(v, 0.0, 1.0))

