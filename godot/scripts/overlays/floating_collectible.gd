## ACTOR_MASTER_PLAN D21/D17/D14 — floating/rotating collectible, the
## reusable "simplification" display for any object (Part 6, still otherwise
## unspecified). First proven with the shotgun; STANDARDIZED (Director,
## 2026-07-28) to take its bake folder and visual scale per-instance via
## setup(), so every future collectible reuses this same class instead of a
## per-object copy.
##
## Cycles pre-rendered flat-color + normal-map frame pairs (produced by a
## bake tool following actor_frame_bake_spike.gd's template) through a
## per-pixel relighting shader (flat_normal_relight.gdshader) so the sprite
## shades directionally against the world's real light data — no voxel
## geometry, no live 3D scene at runtime, matching D16's "simplification"
## concept exactly. Floats with a vertical sine bob and spins continuously
## (Director, 2026-07-27).
##
## GROUND SHADOW (Director, 2026-07-28, re-tuned twice same day). Uses two
## dedicated frame_%02d_shadow_{sharp,soft}.png per frame instead of the
## oblique COLOR frame reused-and-squashed (that shears diagonal silhouettes
## and rotates their apparent angle) — a true top-down bake
## (actor_frame_bake_spike.gd), which has no directional foreshortening to
## shear when squashed. Pinned to floor height independent of the bob. Two
## Sprite2D layers crossfade by the object's CURRENT bob height (Director's
## corrected spec, replacing an earlier "wider at bottom" misread): near the
## floor (bottom of the bob) the shadow is small and SHARP at 80% opacity;
## at the top of the bob it's bigger and SOFT/diffuse at 50% opacity — real
## depth needs size AND focus to change together, not size alone. A fixed
## HOVER_HEIGHT_PX lift keeps a visible gap between object and shadow even
## at the bob's lowest point.
##
## Frame count and rotation speed come from CollectibleBakeConfig
## (godot/scripts/systems/collectible_bake_config.gd) — the bake tool that
## produced frames_dir MUST have used the exact same FRAME_COUNT/camera
## convention, or the frame index math and the light-direction math below
## both go wrong silently.
##
## Light-direction simplification, stated plainly rather than hidden: the
## game has no real 3D world space — gameplay is a 2D grid + an isometric
## screen projection. To relight a normal map baked from a fixed 3D camera,
## this maps grid-x -> bake-world-x and grid-y -> bake-world-z (an explicit,
## documented choice, not a derived one).
##
## PERSPECTIVE-AWARE FIX (Director, 2026-07-28, closes ACTOR_MASTER_PLAN
## open question #16 / D22): the grid delta between light and object is
## computed in the room's CURRENT view-space cells, then de-rotated back to
## base (North) orientation via PerspectiveMapper.cell_to_base() before the
## grid-x/grid-y -> world-x/world-z mapping is applied — the bake camera's
## fixed azimuth was always derived against a canonical N view, so feeding
## it a raw view-space delta from a rotated (E/S/W) perspective silently
## picked the wrong world direction. Same idea as
## TestZoneController.reposition_for_perspective(): this object also now
## tracks its own base_cell and re-derives its view-space gu_cell on every
## perspective flip (see reposition_for_perspective() below), so gu_cell
## never goes stale the way it used to before this fix.
##
## STATIC FACING MODE (Director, 2026-07-29 — "colocar 4 shotguns estáticas
## [...] apontando para [os blocos]"). The bake already contains every facing:
## actor_frame_bake_spike.gd renders FRAME_COUNT yaws of a full turn, so a prop
## that must POINT somewhere instead of spinning is the same flipbook frozen on
## the matching frame — no second bake, no second class. Pass a compass edge to
## setup()'s optional p_static_facing and the object stops spinning, stops
## bobbing, and holds the frame whose muzzle runs along that edge; everything
## else (relighting, ground shadow, depth-aware z) is shared with the spinning
## path byte-for-byte. See FACING_YAW_DEG for how those yaws were measured.
class_name FloatingCollectible
extends Node2D

const CollectibleBakeConfig = preload("res://godot/scripts/systems/collectible_bake_config.gd")
const PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")
const SHADER_PATH := "res://godot/shaders/flat_normal_relight.gdshader"

## Bumped 6.0 -> 18.0 (Director, 2026-07-28: "aumenta o BOB_AMPLITUDE_PX pra
## sombra ficar mais evidente") — the previous range was too subtle to read
## as real separation between the object and its ground shadow.
const BOB_AMPLITUDE_PX := 18.0
const BOB_PERIOD_SEC := 2.0

## Fixed lift above the floor GU point, independent of the bob — without
## this the sprite's resting position sits exactly ON the floor point, so
## even at the bottom of the bob there's no real gap for the shadow to read
## against. The shadow itself is NOT lifted — it stays pinned at the true
## floor Y.
##
## 14.0 -> 60.0 (Director, 2026-07-28: 14px read as "practically stuck to
## the ground" — wanted the object floating noticeably higher, "dentro da
## própria GU"). 3 * GeometryCoords.VOXEL_STEP_PX (20px/voxel layer) rather
## than an arbitrary pixel count — puts the resting height at roughly a
## third of a storey (WALL_FLOOR_STEP_PX=158), comfortably inside the GU's
## own vertical space instead of an arbitrary guess. Combined with
## BOB_AMPLITUDE_PX=18, the object now never dips below floor_y - 42, so it
## no longer touches the shadow's anchor even at the bottom of the bob.
const HOVER_HEIGHT_PX := 60.0

## Ground-shadow tuning, same visual-judgment-call convention as
## SPRITE_SCALE — first guess, tune once seen in a real capture.
##
## Director's corrected spec (2026-07-28): bottom of the bob (nearest the
## floor) = small + sharp; top of the bob (farthest from the floor) = big +
## diffuse. Two peak alphas, one per shadow layer (_shadow_sharp/
## _shadow_soft) — each fades to 0 at the OTHER end of the bob so only one
## reads as dominant at a time, with a smooth crossfade through the middle.
##
## Narrowed again same day (Director: both extremes read as "exagerado" —
## too crisp/small at the bottom, too blurred/big at the top; wanted the
## whole effect more discreet, not just a smaller/bigger swing). Alpha
## peaks 80/50 -> 55/40 (lower overall, closer together), then the top
## peak alone lowered once more, 40 -> 28 (Director: still too visible at
## the top of the bob). Scale range
## 0.85..1.05 -> 0.90..1.00 (narrower, and no longer bigger than the
## resting 1.0x baseline). See CollectibleBakeConfig for the matching
## bake-time blur/dilate narrowing.
const SHADOW_ALPHA_SHARP_AT_BOTTOM := 0.55
const SHADOW_ALPHA_SOFT_AT_TOP := 0.28
const SHADOW_SCALE_AT_TOP := 1.00     ## at the top of the bob
const SHADOW_SCALE_AT_BOTTOM := 0.90  ## at the bottom of the bob

## COLLECTIBLE-OUTLINE-01 (Director, 2026-07-29): the relit sprite disappears
## into a dark floor, so the silhouette gets a constant-colour stroke that does
## NOT dim with the room — see the outline block in flat_normal_relight.gdshader
## for why it lives in the shader rather than as a scaled-up second sprite.
##
## Width is in TEXELS of the 160×160 baked frame. The sprite draws at
## _sprite_scale (1.15 for the shotgun), so 1 texel ≈ 1.15 screen px at 1× zoom —
## the "1 pixel" asked for, and it stays proportional as the camera zooms instead
## of thinning out. The frames leave 43–68 px of transparent margin on every side
## (measured), so a stroke of this width can never be clipped by the frame edge.
## COLLECTIBLE-OUTLINE-02 (Director, 2026-07-29): the stroke is now a per-instance
## COLOUR, not a fixed one — "vamos mudar de cor depois, conforme a raridade dos
## itens, então a gente já pode deixar essa cor variável". The rarity tier → colour
## table itself does not exist yet (WEAPON_MASTER_PLAN D9 defers rarity), so this
## blue stands in as the default until it does; a caller sets `outline_color`
## before add_child() to override it.
##
## ...and it is a COLLECTIBLE affordance, not decoration: "o stroke pode aparecer
## só nos objetos coletáveis, as armas normais não precisa". A transparent colour
## (alpha 0) disables it — the shader is shared (GrenadeProp relights through it
## too), so this resolves to the width-0 default D28 already established rather
## than to a second code path.
const OUTLINE_COLOR_DEFAULT := Color(0.35, 0.72, 1.0, 1.0)
const OUTLINE_DISABLED := Color(0.0, 0.0, 0.0, 0.0)
const OUTLINE_WIDTH_TEXELS := 1.0

## STATIC FACING MODE — sentinel and the measured yaw table.
##
## "" means "spin like a collectible", the original and still-default behaviour.
## Any other value must be a key of FACING_YAW_DEG.
const STATIC_FACING_NONE := ""

## Compass edge -> the bake yaw whose muzzle points along that edge, at the N
## perspective. MEASURED from the real shotgun frames on 2026-07-29, not
## derived: a GLB's own forward axis is arbitrary art data, so there is no
## formula to derive this from — but it is also not a guess. Method: PCA of each
## frame's alpha silhouette gives its on-screen principal axis; the thinner end
## (barrel, vs. the heavier stock) gives the DIRECTED muzzle vector; that was
## matched against the screen angle each grid edge projects to
## (docs/DIRECTION_GLOSSARY.md §1/§3 — NE = grid (0,-1) = screen (+512,-256) =
## -26.6°). Result: frame 28 (yaw 84°) measured -26.0° for NE, and the compass
## walks NE->SE->SW->NW in steps of -90° of yaw (frame 118 measured 28.4° vs
## SE's 26.6°, frame 58 measured -144° vs NW's -153°; the NW/SW pair is the
## foreshortened orientation where PCA is noisiest, hence the looser fit).
##
## Only the NE entry is exercised today (the test-zone bench aims north at the
## wall row). The other three come from the measured -90° step, and the first
## real use of one should be confirmed by a capture the same way NE was.
const FACING_YAW_DEG := {"NE": 84.0, "SE": -6.0, "SW": -96.0, "NW": -186.0}

## Active perspective -> extra yaw, so a static prop keeps aiming at the same
## BASE-space cell while the whole scene rotates around it.
##
## E/W are the OPPOSITE SIGN from GrenadeProp.YAW_BY_DIRECTION, which this was
## first written to copy. Measured, not assumed: with the grenade's signs the
## muzzle came out 170.6° off in view E and 178.2° off in view W — aiming
## backwards, away from the wall — while N and S were already correct. Flipping
## E/W takes the worst error across all 4 views × 4 bench columns from 178.2°
## to 9.4°, and the residual is the expected quantisation noise (3° of yaw is
## many degrees of SCREEN angle near the foreshortened orientation, which is
## exactly where S and W sit).
##
## GrenadeProp is NOT wrong to fix — it is wrong to notice. A grenade does not
## POINT anywhere, so a 180° error in its yaw is invisible on screen and its
## table was never under a test that could catch it. A weapon aiming at a
## specific block is the first object in the project whose facing is falsifiable.
const PERSPECTIVE_YAW_DEG := {"N": 0.0, "E": -90.0, "S": 180.0, "W": 90.0}

## FLOAT-PROP-Z-01 — inputs to the depth-aware sort in _apply_z_index().
##
## Sprite half-extents in world pixels, MEASURED per instance at load time from
## the baked frames' own alpha bounds (see _measure_sprite_extents()) rather
## than hardcoded: these two were the shotgun's numbers, and the class now
## displays other objects (the grenade collectible fills 44×48 of its frame, not
## 66×33), so a shared constant silently describes the wrong silhouette. The
## constants below survive only as the fallback if measurement comes back empty.
## Approximate on purpose either way — they only size the rect used to ask "does
## this voxel overlap me", and the error being guarded against there is off by
## 128px, not by 5.
const SPRITE_HALF_WIDTH_FALLBACK_PX := 38.0
const SPRITE_HALF_HEIGHT_FALLBACK_PX := 19.0
## How far the overlap scan reaches, in VOXELS (8 per GU). Two GUs in every
## direction: one GU sideways already moves a voxel 128px on screen against a
## 76px-wide sprite, so nothing past that can overlap.
const Z_SCAN_RADIUS_VOXELS := 16

## Silhouette stroke colour — set before add_child(). OUTLINE_DISABLED turns it
## off entirely (placed weapons); a rarity tier will drive it once rarity exists.
var outline_color: Color = OUTLINE_COLOR_DEFAULT

## COLOR-GRADE-02 — set before add_child(). 1.0/1.0 = no-op, matching the
## shader's own default; a runtime nudge on top of D31's baked grade, opt-in
## per material the same way outline_color is (weapons only, see
## WeaponBenchController.add_weapon() — the grenade already reads with real
## colour and stays at the neutral default).
var grade_saturation: float = 1.0
var grade_contrast: float = 1.0

var room: Node = null
var gu_cell: Vector2i = Vector2i.ZERO
## Perspective-independent anchor (North orientation) — gu_cell is derived
## from this plus the room's active perspective, same pattern as
## TestZoneController's grenade registry.
var base_cell: Vector2i = Vector2i.ZERO

var _frames_dir: String = ""
var _sprite_scale: float = 1.0
## Corrects for the shadow bake using a different SHADOW_ORTHO_SIZE/
## SHADOW_VIEWPORT_SIZE than the color/normal bake (a top-down view of an
## elongated object needs more frustum room, with no perspective
## foreshortening to compensate) — see setup()'s docstring for the formula.
var _shadow_scale_factor: float = 1.0

var _sprite: Sprite2D
var _shadow_sharp: Sprite2D
var _shadow_soft: Sprite2D
var _material: ShaderMaterial
## FRAME-MEM-01: frame_index -> Texture2D, and the textures themselves belong to
## the shared CollectibleFrameCache, not to this instance. Sparse on purpose —
## a static prop only ever holds the four frames it can display.
var _color_frames: Dictionary = {}
var _normal_frames: Dictionary = {}
var _shadow_sharp_frames: Dictionary = {}
var _shadow_soft_frames: Dictionary = {}
var _frame_time := 0.0
var _bob_time := 0.0
## STATIC_FACING_NONE ("") = the original spinning collectible; a FACING_YAW_DEG
## key = a motionless prop aimed along that compass edge.
var _static_facing: String = STATIC_FACING_NONE
var _sprite_half_w := SPRITE_HALF_WIDTH_FALLBACK_PX
var _sprite_half_h := SPRITE_HALF_HEIGHT_FALLBACK_PX
## Floor GU world Y — the shadow's fixed anchor. Distinct from _base_y
## (the sprite's own resting Y, lifted above the floor by HOVER_HEIGHT_PX).
var _floor_y := 0.0
var _base_y := 0.0

## Fixed camera basis (world-space), derived once from
## CollectibleBakeConfig.ELEVATION_DEG/AZIMUTH_DEG — see file header for the
## exact derivation this mirrors.
var _cam_right := Vector3.ZERO
var _cam_up := Vector3.ZERO
var _cam_toward_viewer := Vector3.ZERO


func _init() -> void:
	var elev := deg_to_rad(CollectibleBakeConfig.ELEVATION_DEG)
	var azim := deg_to_rad(CollectibleBakeConfig.AZIMUTH_DEG)
	var to_camera := Vector3(sin(azim) * cos(elev), sin(elev), cos(azim) * cos(elev)).normalized()
	var forward := -to_camera  ## direction the camera looks, into the screen
	_cam_right = forward.cross(Vector3.UP).normalized()
	_cam_up = _cam_right.cross(forward).normalized()
	_cam_toward_viewer = to_camera


## frames_dir: folder containing frame_%02d_{color,normal,shadow}.png,
## CollectibleBakeConfig.FRAME_COUNT of each, produced by a bake tool
## following actor_frame_bake_spike.gd's template. sprite_scale: per-object
## visual judgment call (same convention as the bake's own MESH_SCALE).
## shadow_scale_factor: corrects for the shadow pass's own
## SHADOW_ORTHO_SIZE/SHADOW_VIEWPORT_SIZE differing from the color pass's —
## compute as (SHADOW_ORTHO_SIZE / SHADOW_VIEWPORT_SIZE.y) / (ORTHO_SIZE /
## VIEWPORT_SIZE.y) using the SAME bake script that produced frames_dir; 1.0
## if a future object's shadow bake happens to use identical framing.
## static_facing: STATIC_FACING_NONE ("") keeps the spinning/bobbing collectible
## behaviour every existing caller gets today; a FACING_YAW_DEG key ("NE", ...)
## makes it a motionless prop aimed along that compass edge — see the file
## header's STATIC FACING MODE note.
func setup(p_room: Node, p_gu_cell: Vector2i, p_frames_dir: String, p_sprite_scale: float,
		p_shadow_scale_factor: float, p_static_facing: String = STATIC_FACING_NONE) -> void:
	room = p_room
	gu_cell = p_gu_cell
	_frames_dir = p_frames_dir
	_sprite_scale = p_sprite_scale
	_shadow_scale_factor = p_shadow_scale_factor
	if p_static_facing != STATIC_FACING_NONE and not FACING_YAW_DEG.has(p_static_facing):
		push_error("[FloatingCollectible] unknown static facing '%s' — expected one of %s" %
			[p_static_facing, FACING_YAW_DEG.keys()])
		return
	_static_facing = p_static_facing
	base_cell = room._cell_to_base(gu_cell, room._active_perspective)
	## z is NOT applied here — see the note at the end of _ready(): the sort needs
	## a real world position, which setup() runs too early to have.


## Mirrors TestZoneController.reposition_for_perspective(): called from
## room.gd::_set_perspective() so this runtime-instantiated overlay follows
## rotation the same way the test-zone grenades do, instead of gu_cell
## silently going stale (pre-fix behavior).
func reposition_for_perspective(direction: String) -> void:
	var base_size: Vector2i = room._base_layout.get("size", Vector2i.ZERO)
	gu_cell = PerspectiveMapperClass.cell_from_base(base_cell, direction, base_size)
	if room != null and room.agent != null:
		var world_pos: Vector2 = room.agent._cell_to_world(gu_cell)
		_floor_y = world_pos.y
		position = Vector2(world_pos.x, _floor_y - HOVER_HEIGHT_PX)
		_base_y = position.y
	## A static prop's frame encodes its aim in SCREEN space, so it has to be
	## re-picked whenever the scene rotates or the muzzle keeps pointing where
	## the target used to be. The spinning path re-picks every _process() frame
	## anyway and needs nothing here.
	_apply_frame(_current_frame_index())
	_apply_z_index()


## Which baked frame to show right now: the spin angle for a collectible, the
## measured aim yaw for a static prop.
func _current_frame_index() -> int:
	var step := 360.0 / float(CollectibleBakeConfig.FRAME_COUNT)
	if _static_facing != STATIC_FACING_NONE:
		var perspective: String = "N"
		if room != null:
			perspective = String(room._active_perspective)
		var view_yaw: float = float(FACING_YAW_DEG[_static_facing]) \
			+ float(PERSPECTIVE_YAW_DEG.get(perspective, 0.0))
		return int(round(fposmod(view_yaw, 360.0) / step)) % CollectibleBakeConfig.FRAME_COUNT
	var rotation_deg := fmod(_frame_time * CollectibleBakeConfig.ROTATION_DEG_PER_SEC, 360.0)
	return int(rotation_deg / step) % CollectibleBakeConfig.FRAME_COUNT


## Point every layer at one frame index. Both shadow layers always match the
## sprite's current rotation, "girando na mesma velocidade" (Director), using
## their OWN true top-down bake (see file header).
func _apply_frame(frame_index: int) -> void:
	if _sprite == null or not _color_frames.has(frame_index):
		return
	_sprite.texture = _color_frames[frame_index]
	_material.set_shader_parameter("normal_tex", _normal_frames[frame_index])
	_shadow_sharp.texture = _shadow_sharp_frames[frame_index]
	_shadow_soft.texture = _shadow_soft_frames[frame_index]


## FRAME-MEM-01 — which frame indices this prop can EVER display.
##
## A collectible spins through all of them. A static prop shows exactly one per
## N/E/S/W perspective, so it has no reason to hold the other 116 — and with 4
## bench columns per weapon type, that is the difference between the bench
## costing a few MB and costing hundreds.
func _displayable_frame_indices() -> Array:
	if _static_facing == STATIC_FACING_NONE:
		return range(CollectibleBakeConfig.FRAME_COUNT)
	var step := 360.0 / float(CollectibleBakeConfig.FRAME_COUNT)
	var out: Array = []
	for perspective in PERSPECTIVE_YAW_DEG:
		var view_yaw: float = float(FACING_YAW_DEG[_static_facing]) \
			+ float(PERSPECTIVE_YAW_DEG[perspective])
		var idx: int = int(round(fposmod(view_yaw, 360.0) / step)) % CollectibleBakeConfig.FRAME_COUNT
		if not out.has(idx):
			out.append(idx)
	return out


## FLOAT-PROP-Z-01 (Director-reported 2026-07-29: "a arma está entrando dentro
## da parede") — depth-aware sorting.
##
## History, because this is the third rule here and each fixed the previous one's
## real bug. OCC-03's "always above everything" was copied from the agent and
## rejected (D22-FOLLOWUP, 2026-07-28): the object showed through geometry it was
## genuinely behind. That was replaced by "sort like level-0 geometry" — correct
## while the object rested at floor height, but its premise expired the same day,
## when HOVER_HEIGHT_PX went 14 → 60 at the Director's request. A prop floating
## three voxel levels up, standing in the cell directly SOUTH of a 2-storey block,
## was drawn under all 16 of that block's levels: it read as sunk into the wall.
##
## Neither rule could be right, because z_index in this project encodes HEIGHT
## (level + WALL_BASE_Z_INDEX) while what a prop needs is DEPTH. The two are
## independent, and y-sorting — which would resolve depth for free — is not
## enabled anywhere in the project (only y_sort_origin is set, which does nothing
## on its own).
##
## So depth is decided here, using OcclusionSet's POLICY O5 (canon): depth is
## (x + y) in view space, greater sum = nearer the camera. A column NEARER than
## the prop must cover it; a column at the same depth or FARTHER must not. Only
## columns whose on-screen band actually overlaps the prop's sprite count — a tall
## block two cells behind is drawn far enough up the screen to miss it entirely,
## and one two cells in front is drawn far enough down.
##
## Re-applied on every rotation, not just at setup: _set_perspective() rebuilds
## every voxel TileMapLayer from scratch AND changes which cells are behind.
func _apply_z_index() -> void:
	if room == null or room._voxel_renderer == null:
		return
	var voxel_renderer = room._voxel_renderer
	var ground_layer: TileMapLayer = voxel_renderer.get_layer(0)
	if ground_layer == null:
		return
	var base_z: int = ground_layer.z_index

	## The sprite's own world-space rect, taken at the bob's extremes so the
	## answer doesn't flicker as the object rises and falls. A static prop never
	## bobs, so its rect is just the sprite.
	var bob_reach := 0.0 if _static_facing != STATIC_FACING_NONE else BOB_AMPLITUDE_PX
	var sprite_rect := Rect2(
		position.x - _sprite_half_w,
		_base_y - bob_reach - _sprite_half_h,
		_sprite_half_w * 2.0,
		(bob_reach + _sprite_half_h) * 2.0)

	## Centre voxel of my own GU — the reference for O5 depth at voxel scale.
	var center_voxel: Vector2i = GeometryCoords.gu_to_voxel_origin(gu_cell) \
			+ Vector2i(GeometryCoords.VOXELS_PER_UNIT_AXIS / 2, GeometryCoords.VOXELS_PER_UNIT_AXIS / 2)
	var verdict: Dictionary = voxel_renderer.classify_geometry_over_rect(
			center_voxel, sprite_rect, Z_SCAN_RADIUS_VOXELS)

	if bool(verdict["covered_from_front"]):
		## Something NEARER really overlaps me: I belong behind all of it,
		## including its ground level. This is the case D22-FOLLOWUP protected.
		z_index = base_z - 1
		return

	var behind_top_z: int = int(verdict["behind_top_z"])
	if behind_top_z == voxel_renderer.EMPTY_COLUMN:
		## Open ground: keep the old floor-level slot.
		z_index = base_z
		return

	## Sit just above the tallest thing behind me, capped at the top voxel layer
	## so the agent (max + 1, OCC-03) still draws over every prop.
	z_index = mini(behind_top_z + 1, voxel_renderer.get_max_voxel_z_index())


func _ready() -> void:
	## FRAME-MEM-01: ask the shared cache for only the frames this prop can ever
	## show, instead of reading 480 PNGs into textures nobody else can reuse.
	var indices := _displayable_frame_indices()
	var cache = Registries.get_frame_cache()
	var by_pass: Dictionary = cache.request(_frames_dir, indices)
	_color_frames = by_pass["color"]
	_normal_frames = by_pass["normal"]
	_shadow_sharp_frames = by_pass["shadow_sharp"]
	_shadow_soft_frames = by_pass["shadow_soft"]
	if _color_frames.is_empty():
		push_error("[FloatingCollectible] no frames loaded from %s" % _frames_dir)
		return
	var extents: Dictionary = cache.extents_of(_frames_dir)
	if bool(extents.get("have", false)):
		_measure_sprite_extents(extents["used_rect"], extents["frame_size"])
	var first_index: int = int(indices[0])

	## Both added BEFORE _sprite so they draw underneath at the same z_index
	## (Godot resolves same-z siblings in tree order) — sit on the floor,
	## under the object, unaffected by the bob (see _process()). NO mirror
	## on either — see actor_frame_bake_spike.gd's shadow-pass comment (an
	## earlier mirrored version measured 46° RMS angle error and spun
	## opposite the object; verified via real baked-frame PCA measurement).
	_shadow_soft = Sprite2D.new()
	_shadow_soft.texture = _shadow_soft_frames[first_index]
	_shadow_soft.centered = true
	add_child(_shadow_soft)

	_shadow_sharp = Sprite2D.new()
	_shadow_sharp.texture = _shadow_sharp_frames[first_index]
	_shadow_sharp.centered = true
	add_child(_shadow_sharp)

	_sprite = Sprite2D.new()
	_sprite.texture = _color_frames[first_index]
	_sprite.centered = true
	_sprite.scale = Vector2.ONE * _sprite_scale

	var shader := load(SHADER_PATH)
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("normal_tex", _normal_frames[first_index])
	_material.set_shader_parameter("outline_color", outline_color)
	_material.set_shader_parameter("outline_width",
		OUTLINE_WIDTH_TEXELS if outline_color.a > 0.0 else 0.0)
	_material.set_shader_parameter("saturation", grade_saturation)
	_material.set_shader_parameter("contrast", grade_contrast)
	_sprite.material = _material
	add_child(_sprite)

	_apply_frame(_current_frame_index())

	if room != null and room.agent != null:
		var world_pos: Vector2 = room.agent._cell_to_world(gu_cell)
		_floor_y = world_pos.y
		position = Vector2(world_pos.x, _floor_y - HOVER_HEIGHT_PX)
	_base_y = position.y

	## AFTER position/_base_y exist: FLOAT-PROP-Z-01 builds the sprite's real
	## world rect to test what overlaps it, and setup() runs before _ready(), when
	## both are still zero — the scan would have been run against a rect sitting at
	## the world origin.
	_apply_z_index()

	set_process(true)


func _process(delta: float) -> void:
	var is_static := _static_facing != STATIC_FACING_NONE
	if not is_static:
		_frame_time += delta
		_apply_frame(_current_frame_index())

	## bob_phase: -1 (top of the bob) .. +1 (bottom, nearest the floor).
	## Pinning it to 0.0 is the WHOLE static branch below this line — the prop
	## then rests at exactly _base_y (= floor - HOVER_HEIGHT_PX, "na mesma
	## altura da instância coletável", Director) and every shadow term that
	## follows resolves to the midpoint of its own crossfade. Deliberately not
	## a second code path: a static prop's shadow is the spinning one's, frozen
	## halfway, so there is nothing here that can drift out of sync with it.
	var bob_phase := 0.0
	if not is_static:
		_bob_time += delta
		bob_phase = sin((_bob_time / BOB_PERIOD_SEC) * TAU)
	var bob := bob_phase * BOB_AMPLITUDE_PX
	position.y = _base_y + bob
	## Counter the parent's (lifted + bobbing) position in local space so
	## both shadows' WORLD position stays pinned exactly at the floor
	## regardless of HOVER_HEIGHT_PX or the current bob — that
	## fixed-vs-floating contrast is the whole point (Director: "deixar
	## claro onde está posicionada a arma em relação ao chão").
	_shadow_sharp.position.y = _floor_y - position.y
	_shadow_soft.position.y = _floor_y - position.y

	## bottom_frac: 1.0 at the bottom of the bob (bob_phase=+1, nearest the
	## floor), 0.0 at the top (bob_phase=-1). Both shadow layers share the
	## same size (small at bottom, big at top); each layer's OWN opacity
	## peaks at its end of the bob and fades to 0 at the other, so only one
	## reads as dominant at a time with a smooth crossfade between —
	## Director's corrected spec: small+sharp+80% at the bottom, big+soft+
	## 50% at the top.
	var bottom_frac := (bob_phase + 1.0) * 0.5
	var shadow_mult := lerpf(SHADOW_SCALE_AT_TOP, SHADOW_SCALE_AT_BOTTOM, bottom_frac)
	var shadow_base_scale := _sprite_scale * _shadow_scale_factor * shadow_mult
	var shadow_scale := Vector2(shadow_base_scale, shadow_base_scale * CollectibleBakeConfig.SHADOW_SQUASH_Y)
	_shadow_sharp.scale = shadow_scale
	_shadow_soft.scale = shadow_scale
	_shadow_sharp.modulate = Color(0.0, 0.0, 0.0, lerpf(0.0, SHADOW_ALPHA_SHARP_AT_BOTTOM, bottom_frac))
	_shadow_soft.modulate = Color(0.0, 0.0, 0.0, lerpf(SHADOW_ALPHA_SOFT_AT_TOP, 0.0, bottom_frac))

	_update_light_uniform()


## D17: find the strongest active light affecting this cell and express its
## direction in the bake camera's fixed view space (see file header for the
## grid->world simplification and the perspective-rotation caveat).
func _update_light_uniform() -> void:
	if room == null or room._lighting_controller == null:
		return
	var registry = room._lighting_controller.get_light_registry()
	if registry == null:
		return

	var best_light = null
	var best_energy := -1.0
	for light in registry.get_active_lights():
		if not light.affects_cell(gu_cell):
			continue
		var energy: float = light.get_effective_tactical_energy()
		if energy > best_energy:
			best_energy = energy
			best_light = light

	if best_light == null:
		## No active light reaches this cell — flat ambient only, matching
		## the flat baseline the color frames were rendered with.
		_material.set_shader_parameter("light_intensity", 0.0)
		return

	## De-rotate both cells from the room's CURRENT view-space back to base
	## (North) orientation before taking the delta — the bake camera's fixed
	## azimuth was derived against a canonical N view, so the grid-x/grid-y
	## -> world-x/world-z mapping below is only valid in that same base
	## orientation (see file header, D22/open question #16).
	var base_size: Vector2i = room._base_layout.get("size", Vector2i.ZERO)
	var base_light_cell: Vector2i = room._cell_to_base(best_light.cell, room._active_perspective, base_size)
	var grid_delta: Vector2i = base_light_cell - base_cell
	## Explicit grid->bake-world mapping (file header): grid-x -> world-x,
	## grid-y -> world-z, light assumed roughly floor-height (no Y term).
	var light_dir_world := Vector3(float(grid_delta.x), 0.0, float(grid_delta.y)).normalized()
	if grid_delta == Vector2i.ZERO:
		light_dir_world = _cam_toward_viewer

	var light_dir_view := Vector3(
		light_dir_world.dot(_cam_right),
		light_dir_world.dot(_cam_up),
		light_dir_world.dot(_cam_toward_viewer)
	).normalized()

	_material.set_shader_parameter("light_dir", light_dir_view)
	_material.set_shader_parameter("light_intensity", clampf(best_energy, 0.0, 3.0))


## FLOAT-PROP-Z-01 — half-extents of the object as actually drawn, from the
## union of every color frame's alpha bounds.
##
## Measured rather than declared, because the object is NOT centred in its own
## canvas: the sprite is centered=true, so the frame's CENTRE is what lands on
## this node's position, and what the depth sort needs is the farthest the
## drawn pixels reach from that centre — not the used rect's own size. Taking
## the max of both edges' distance is what makes an off-centre bake (or a
## future object with a very different silhouette) come out conservative
## instead of wrong.
func _measure_sprite_extents(used: Rect2i, frame_size: Vector2) -> void:
	var cx := frame_size.x / 2.0
	var cy := frame_size.y / 2.0
	_sprite_half_w = maxf(absf(float(used.position.x) - cx), absf(float(used.end.x) - cx)) * _sprite_scale
	_sprite_half_h = maxf(absf(float(used.position.y) - cy), absf(float(used.end.y) - cy)) * _sprite_scale
