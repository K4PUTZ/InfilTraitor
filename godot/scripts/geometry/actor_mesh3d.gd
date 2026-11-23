## ActorMesh3D — an actor as a live skinned mesh on the 3D board (RENDER3D R3D-ACTORS, `ACTOR` D64).
##
## THE MESH SHOWS, `ActorPose` DECIDES (step 3, the bridge). The contract the retired `ActorBillboard3D` kept: the sprite still
## owns every decision — facing (D44's four, D47's snap at the GU boundary), posture, grip, weapon, the walk's progress,
## the throw and the head's grid angle — and this node reads them each frame through `ActorPose.mesh_state()` and turns
## them into a yaw, an action and a time. Nothing in the actor's logic knows which of the two draws it.
##
## THE RIG is `tools/asset_generation/r3d_live_rig_export.py`'s: one skinned mesh, every motion a keyed action
## (`<posture>_<weapon>_<grip>`, `walk_<weapon>`, `throw_raise_<weapon>`, `throw_release_<weapon>`), the weapons on
## `hand_R` and the grenade on `hand_L` as `BoneAttachment3D`s. An action is never PLAYED: it is SEEKED to the fraction
## the sprite is at, so the walk stays locked to the step's progress (one cycle per GU, D61) and the throw to the sprite's
## own clock, which is what fires `throw_released`.
##
## LIT the board's way (`actor_mesh3d.gdshader`: no Godot light, one cell-plane fetch; Moto: 9 walking rigs +1.0 ms),
## its materials kept in sync by `Board3DLive.register_prop_light_material()` exactly as a prop's are.
##
## PLACED in BASE world coordinates: the feet are the sprite's 2D position through `Board3DLive.ground_point()` (the N
## lattice in every view), the yaw is the base grid step's, so a camera yaw turns the figure with the board for free.
##
## A TRIPO AGENT (MOVEMENT MV-4, first slice, 2026-11-05; THE AGENT'S DEFAULT since 2026-11-08, the male unless `TRIPO_FIGURE=female`,
## `none` = the old rig; guards are never affected: the soldier keeps the white rig, the officer wears the old agent's `agent_live.glb`).
## The agent wears that LIGHT Agent instead (`TripoFigure`: 65 Mixamo joints, the dressed set, the coat two-sided, its emblem, the legs pushing it) and
## plays the game set's clips: `idle` on its own clock while the actor stands, the move clip (`TRIPO_MOVE`, `walk` by default)
## while it walks, phased by the GROUND it covers (one pass of the clip per its `travel_m`), so the feet do not slide at any step
## length. Facing (D44, D47's snap), position and gravity are this node's, unchanged. THE PISTOL (2026-11-08): with `weapon` `_pistol` and `grip` `_aimed` the aim layer
## (`ActorAimPose3D`, `AIM_STOPS`) takes the arms from the clip through the draw (fists at the sternum, the gun comes out of the coat) to a two-handed aim, and back on cancel.
## THE LONG GUNS (2026-11-22, `FAMILY_DRAWS`): a weapon held as the shotgun draws on its own timeline, out of the coat's right flap with the left hand, to the hip
## or on to the shoulder (`ActorPose.shot_stance`). Not yet on that figure: the rifles' and the sniper's own models (their rows have none: they are not drawn),
## a long gun crouched or prone, moving with a weapon.
## Not yet on that figure (2026-11-08): crouched and prone, the throw (a Tripo actor stands through it; the throw still releases on the sprite's clock), the clip
## transitions (a snap, D47's default) and the corrective coat keys (`ACTOR` D103, only on the base).
class_name ActorMesh3D
extends Node3D

const SHADER_PATH := "res://godot/shaders/actor_mesh3d.gdshader"
const SILHOUETTE_SHADER_PATH := "res://godot/shaders/actor_mesh_silhouette3d.gdshader"
## After the world's opaque geometry and the cutaway fill (10), before the cutaway lines (127): the billboard's slot.
const SILHOUETTE_PRIORITY := 20
const SHADOW_SHADER := "res://godot/shaders/ground_overlay3d.gdshader"
## Above the floor, under every ground overlay's lift (0.01+).
const SHADOW_LIFT: float = 0.005
## The contact shadow (Director, 2026-11-09): black, this opaque at the centre, this wide on the ground (world units), fading through the rings (share of the radius, share of the opacity) to
## nothing at the last one.
const CONTACT_SHADOW_OPACITY: float = 1.0
const CONTACT_SHADOW_RADIUS: float = 0.27
const CONTACT_SHADOW_RINGS: Array = [[0.35, 0.6], [1.0, 0.0]]
const CONTACT_SHADOW_SEGMENTS: int = 32
const HeadTurnRef = preload("res://godot/scripts/geometry/actor_head_turn3d.gd")
const RIG_DIR := "res://ASSETS/ISOMETRIC/source_assets/imported_models/agent/"
## `ActorPose.frame_family` -> the rig exported from that model. A family with no rig of its own falls back to the
## agent's, loudly, once.
const RIG_BY_FAMILY := {
	"": "agent_live.glb",
	## The field officer (2026-11-08): the old agent's model, promoted when the Tripo figure became the agent.
	"_officer": "agent_live.glb",
}
## A guard family that wears a Tripo body on the Agent's skeleton (ENEMIES_MASTER_PLAN §12.12-§12.13): the model, and the figure
## whose game clips it plays. `maps`: the model's material name -> its painted map in the character's textures/ folder, read by
## the game itself so the Director's edit of that PNG reaches the board on save (Godot reimports it); it replaces the copy inside
## the GLB. A head and a uniform are separate maps (2026-11-20), so one head goes with any uniform. The rank-and-file guard (2026-11-19) is the FID's male Standard, retiring `agent_live_enemy_white.glb`.
const TRIPO_BY_FAMILY := {
	"_enemy_white": {"figure": "male", "enemy": ["FID", "guard_male", "ENEMY_FID_MALE_LIGHT.glb"], "maps": {"Enemy_head": "enemy_fid_male_head.png", "Enemy_body": "enemy_fid_male_body.png"}},
}
## D61: a GU is 1.60 m, and a GU is one world unit; the rig is authored in metres.
const METRES_TO_UNITS: float = 1.0 / 1.6
const TripoFigureRef = preload("res://godot/scripts/geometry/tripo_figure.gd")
## Dev flags of the Tripo slice: which Agent every actor wears ("" = the r3d_live rig), and the clip it moves with.
const TRIPO_FIGURE_FLAG := "TRIPO_FIGURE"
## The Agent is the male LIGHT figure unless the flag says `female`; `none` puts the old r3d_live rig back on the agent (comparisons).
const AGENT_FIGURE_DEFAULT := "male"
const TRIPO_FIGURE_NONE := "none"
const TRIPO_MOVE_FLAG := "TRIPO_MOVE"
const TRIPO_MOVE_DEFAULT := "walk"
const TRIPO_RUN := "run"   ## the dash's clip: both AP spent on one move
const TRIPO_IDLE := "idle"
const CROUCH_CLIP := "crouch"
## THE AIM LAYER (MOVEMENT, 2026-11-08): while the actor holds the pistol AIMED the arms are pulled from whatever clip plays toward the pose
## `pose_aim_pistol` (`TripoFigure.POSES`, `ActorAimPose3D`); the pistol is in the right hand only then, and comes out as the fist rises
## (Director: no holster, it leaves the coat). `AIM_RAISE_S` / `AIM_LOWER_S` are the weight's travel; the gun shows from `PISTOL_SHOWN_FROM` of it.
const ActorAimPoseRef = preload("res://godot/scripts/geometry/actor_aim_pose3d.gd")
const AimSequenceRef = preload("res://godot/scripts/geometry/aim_sequence.gd")
## The path of the raise: the idle arms, then the fists at the sternum (`draw_pistol`, at half way: the gun appears here, out of the coat), then the aim. `step_pistol` is passed through
## without resting (the third element): the front foot off the floor between the two.
const AIM_STOPS: Array = [["draw_pistol", 0.5], ["step_pistol", 0.7, true], ["aim_pistol", 1.0]]
const AIM_RAISE_S: float = 0.36
const AIM_LOWER_S: float = 0.24
const PISTOL_SHOWN_FROM: float = 0.5
## The coat opens for the draw (Director, 2026-11-09: the left hand pulls the lapel, the right goes into the gap): the morph `DRAW_COAT_SHAPE`, full at the draw's stop, closed again by
## `DRAW_COAT_CLOSED_AT` as the left hand lets go. The gun is hidden AT that stop and in the hand from the next frame on, already at the aim's place and size (the poses carry the same placement).
const DRAW_COAT_SHAPE: String = "DrawFix"
const DRAW_COAT_CLOSED_AT: float = 0.75
## THE SHOT (MOVEMENT, 2026-11-12): `fire_kick()` kicks the body by the shot's recoil profile (`ActorRecoil3D.profiles`, chosen from the hold family
## and the stance: the pistol's arms and the gun in the hand, up about its grip and back along the barrel; since 2026-11-22 the long gun's trunk and
## arms, at the hip or aimed, the gun fixed in the hands) and throws a spent case (`ShellCasings3D`) from `EJECT_PORT` (a point of the pistol model,
## on top of the slide) when the row throws one. The aim is HELD `SHOT_HOLD_S` after the shot, so the body comes back to it before the controller's
## lowering takes it down.
const ActorRecoilRef = preload("res://godot/scripts/geometry/actor_recoil3d.gd")
const ShellCasingsRef = preload("res://godot/scripts/geometry/shell_casings3d.gd")
const ShotProjectilesRef = preload("res://godot/scripts/geometry/shot_projectiles3d.gd")
const SHOT_HOLD_S: float = 0.6
const EJECT_PORT := Vector3(0.06, 0.03, 0.0)
## The case's throw, metres/s: to the shooter's right, up, a little back.
const EJECT_RIGHT_M: float = 0.8
const EJECT_UP_M: float = 1.2
const EJECT_BACK_M: float = 0.2
## THE THROW (MOVEMENT, 2026-11-12, `PROMPTS/THROW_STUDY_2026-11-12.md` §5.1): the Director's timeline `throw_overhand` (`AimSequence`) on a second path layer. The raise
## goes idle -> cocked at the timeline's pace and HOLDS there while the player aims, the whole body turning in place to the aimed cell (`ActorPose.throw_aim_dir`,
## `THROW_TURN_RAD_S`); a drawn pistol is put away first (the raise waits for `_aim_t` to reach 0); the release runs cocked -> release on the pose's clock (so its
## `throw_released` lands on the timeline's release frame), then the follow-through and the way back to the idle at the timeline's pace; the cancel plays the raise back.
## The grenade rides the right hand as the timeline places it, and the coat takes the timeline's `ThrowFix_*` morphs.
const THROW_TURN_RAD_S: float = TAU

var _board: Node3D = null
var _source: ActorPose = null
var _body: Node3D = null
var _materials: Array[ShaderMaterial] = []
## the name of the model's material a board-lit one replaced (an enemy's `maps` key: Enemy_head, Enemy_body)
const SOURCE_MATERIAL_META := &"source_material"
var _player: AnimationPlayer = null
var _head: SkeletonModifier3D = null
var _weapons: Dictionary = {}       ## weapon name -> Node3D under hand_R
var _grenade: Node3D = null
var _action: String = ""
var _skeleton: Skeleton3D = null
var _head_bone: int = -1
var _stand_y: float = NAN            ## the height the feet rest at now (eased toward `Board3DLive.stand_height`)
var _yaw: float = 0.0                ## the body's yaw toward its grid facing (the head's clamp is relative to it)
var _front_yaw: float = 0.0          ## added to `_yaw` on the model: 0 for the r3d_live rig (front -Z), PI for a Tripo Agent (front +Z)
var _tripo: String = ""              ## the Tripo Agent this actor wears ("" = the r3d_live rig)
var _tripo_move: String = ""         ## the clip it moves with
var _tripo_units: float = 1.0        ## world units per metre of the 1 m Tripo export (its scale on the board)
var _aim: ActorAimPoseRef = null      ## the aim layer of a Tripo Agent (null: its game set carries no aim pose)
var _recoil: ActorRecoilRef = null  ## the shot's kick on the arms (null: no aim layer)
var _shot_t: float = INF             ## seconds since the last shot (the gun's own kick)
var _shot_hold: float = 0.0          ## the aim is held this long more after a shot
var _aim_t: float = 0.0              ## how far the aim has travelled, 0 (down) to 1 (held)
var _aim_target: float = 0.0         ## where it is heading this frame: 0, the long gun's hip stop, or 1 (`weapon_at_stance`)
var _pistol: Node3D = null           ## the pistol in the right hand (hidden until the fists reach the sternum)
var _pistol_holder: Node3D = null    ## carries the placement (the pose's, blended between the stops)
var _figure: String = ""            ## the Tripo figure ("male" / "female"): a family model's grip may be its own per figure
var _held_id: String = ""            ## the weapon row whose model is in `_pistol_holder` (the family's reference until another is chosen)
var _held_def: WeaponDef = null      ## its row: its model's place in the reference's frame (`held_rel_for`) and its muzzle
var _attach_id: String = ""          ## the attachment on its muzzle ("" = none)
var _attach_def: AttachmentDef = null
## MOVEMENT §11.6 step 5 — the held model's pieces a shot moves (`WeaponDef.fx_*`): the piece that flies (hidden from the shot until the
## weapon is put away, or until a hook is wound back), the bow string (its drawn and fired meshes), the drum that turns while a line winds.
var _fx_part: Node3D = null
var _fx_string: MeshInstance3D = null
var _fx_string_drawn: Mesh = null
var _fx_string_fired: Mesh = null
var _fx_spin: Node3D = null
var _fx_spin_axis: Vector3 = Vector3.FORWARD
var _fx_spin_centre: Vector3 = Vector3.ZERO
var _fx_spin_base: Transform3D = Transform3D.IDENTITY
var _fx_spent: bool = false            ## the piece has left (the gun is "unloaded" until it is put away)
var _hook_handle: Dictionary = {}
var drum_turns_per_s: float = 4.0
var _attach_node: Node3D = null      ## its model, a child of the holder beside the weapon's
var _throw: ActorAimPoseRef = null   ## the throw's path layer (null: the figure has no throw timeline)
var _throw_seq: AimSequenceRef = null
var _throw_w: float = 0.0            ## where along the throw's timeline the body is, 0..1
var _throw_phase: String = ""        ## "", "raise", "cancel", "release", "recover"
var _throw_grenade: Node3D = null    ## the grenade in the right hand (a BoneAttachment3D) and its placement holder
var _throw_grenade_holder: Node3D = null
var _throw_grenade_scale: float = 0.0   ## its certified size in the hand bone's frame (`TripoFigure.held_prop_scale`); 0 = the timeline's
var _throw_last_hand: Vector3 = Vector3.INF   ## where the grenade last was in the hand, global: the flight starts there
var _throw_coat: MeshInstance3D = null
var _throw_morphs: Dictionary = {}   ## morph name -> blend shape index on the coat
var _shown_yaw: float = NAN          ## the body's yaw on screen, eased toward the grid facing or the throw's aim
var _throw_turning_back: bool = false   ## a throw just ended and the body is still turning back to its grid facing
var _coat: MeshInstance3D = null     ## the Agent's coat, when it owns the draw's morph
var _coat_draw_shape: int = -1       ## that morph's index
var _pistol_stops: Array = []        ## [[weight, placement {bone, pos, quat, scale}], ...] one per aim stop, from the poses' `props` meta
var _sequence: AimSequenceRef = null    ## the Director's timeline of the draw (`AimSequence`), when the figure has one: it replaces `AIM_STOPS`, the coat curve and the gun's blend
var _lower_s: float = AIM_LOWER_S    ## and back: the sequence's own duration too (Director 2026-11-11: a draw is quick by nature, the way back is as quick as the way there)
var _raise_s: float = AIM_RAISE_S    ## how long the weight takes to go 0 -> 1 (the sequence's own duration when there is one)
## THE CROUCHED DRAW (Director, 2026-11-15): a second aim layer from the timeline `draw_crouch_pistol` (the crouch's last frame held, the arms of the
## standing draw). One set per hold FAMILY and posture (`_aim_key`: "pistol:standing", "pistol:crouch", "shotgun:standing"), a Dictionary
## {layer, seq, raise, lower, hip, coat, morphs}; the active one is in `_aim` / `_sequence` / `_raise_s` / `_lower_s` / `_aim_kind` and changes only with
## the gun away (`_aim_t` 0): a posture or weapon change while aimed lowers the gun, then raises it in the new set.
const DRAW_CROUCH := "draw_crouch_pistol"
## THE LONG GUNS (MOVEMENT §11.6 step 3, Director 2026-11-17/18): a second hold family on the same gun node. Its timeline (`AimSequence.LONG_DRAW`) takes
## the gun out of the coat's right flap with the LEFT hand (the node's bone follows the timeline's: `_use_aim_set`), turns it level at the HIP and goes on
## to the shoulder at the EYE. The draw stops at the `hip` marker for the hip shot (the stance "hip", where the draw ends) and runs to the end for the
## aimed one ("aimed"). A family is a weapon row's `held_as`, drawn only when the held row has a model. No kneeling long-gun timeline yet (step 4):
## crouched, a long gun is not drawn.
const FAMILY_DRAWS := {
	"pistol": {"standing": AimSequenceRef.PISTOL_DRAW, "crouch": DRAW_CROUCH},
	"shotgun": {"standing": AimSequenceRef.LONG_DRAW},
}
const RISE_CLIPS := {"run": "crouch_run", "walk": "crouch_walk"}   ## rising from the crouch into the gait (Director, 2026-11-15): a move ordered while fully crouched opens on it, not on the gait's start
var _aim_sets: Dictionary = {}
var _aim_kind: String = "pistol:standing"
var _aim_hip_w: float = 1.0          ## the active set's weight for the stance "hip" (its `hip` marker; 1 = the set has one stance)
var _aim_coat: MeshInstance3D = null ## the active set's own coat keys (the long draw's `LongDrawFix_f*`), with `_aim_morphs` name -> blend shape index
var _aim_morphs: Dictionary = {}
var _armed_id: String = ""           ## the weapon row `_armed` was read for
var _armed: bool = false             ## that row has a model to draw (a row without one is not drawn: the figure keeps its arms down, as before)
var _run_pass: float = 0.0           ## the `run` clip's ground per pass (0 = the game set has none: a dash walks)
var _walked: float = 0.0             ## ground covered while walking, world units: the move clip's phase
## THE PASSAGES (MOVEMENT 2026-11-14): a move from standing opens on its gait's authored START (played on its own clock, scaled like the actor's travel:
## `ActorPose.dash_rate`; the gait's clip carries on from the start's last frame) and ends on one of its STOPS, chosen at the move's first frame: the foot
## whose contact in the gait's clip falls nearest to where the stop must start (`ActorPose.dash_len` minus the stop's reach), the stride evened by
## `_phase_k` (option A) so the contact falls exactly there. The actor's last step follows the stop (`ActorPose.stop_t`); the idle resumes on its frame 90.
## The run has two stops (its cycle is ~3.8 GU, so a dash ends on either foot); the walk one (its cycle is one GU: every walk ends in the same phase).
const GAIT_PASSAGES := {
	"run": {"clip": "run", "start": "run_start", "stops": {"l": "run_stop_l", "r": "run_stop_r"}, "contacts": [[14.0, "r"], [21.0, "l"], [29.0, "r"], [36.0, "l"]]},
	"walk": {"clip": "walk", "start": "walk_start", "stops": {"l": "walk_stop"}, "contacts": [[22.0, "l"], [50.0, "l"]]},
}   ## contacts: the clip's footfalls, 24 fps frames (the run's 36 = its next loop's 6; the game walk is two cycles, 56 frames)
const PHASE_K_RANGE := Vector2(0.7, 1.4)   ## how far the stride may be evened; past it the move has no stop
var _gaits: Dictionary = {}          ## gait -> `_load_gait`'s row
var _gait: Dictionary = {}           ## the row of the move in progress
var _start_t: float = -1.0
var _was_walking: bool = false
var _phase_k: float = 1.0
var _stop_side: String = ""
var _was_stopping: bool = false
var _coat_keys: Dictionary = {}      ## coat morph name -> blend shape index, for the passage's keys and the run's own RUN_COAT_KEY
const IDLE_COAT_KEY := "IdleFix"     ## the idle's corrective coat key (one key for the whole idle, MOVEMENT 2026-11-13): on while the figure stands, off as the aim rises or it moves
const WALK_COAT_KEY := "WalkFix"     ## the walk's corrective coat key (`ACTOR` D103): on while the figure walks (not runs)
const RUN_COAT_KEY := "RunFix"       ## the run's corrective coat key (`ACTOR` D103), held at 1 while the figure runs so the passage hands over to the same coat
var _move_pass: float = 0.0          ## world units of ground one pass of the move clip covers
var _last_ground := Vector2(NAN, NAN)
var _idle_t: float = 0.0             ## the idle clip's own clock
## THE CROUCH (2026-11-15): idle frame 90 -> kneeling (`TripoFigure.FOOTED_CLIPS` "crouch"), played once when the posture becomes "crouch", its
## last frame held while it stays so, and played backwards to stand up. {} = the figure has no crouch clip (it stands through the posture).
## `_crouch_t`: clip seconds, -1 = neither crouched nor rising.
var _crouch: Dictionary = {}
var _crouch_t: float = -1.0
var _idle_cut: bool = false          ## the idle is held at `IDLE_REFERENCE_FRAME` while a pose layer is up
const IDLE_REFERENCE_FRAME := 90.0   ## the idle frame every pose layer starts from (24 fps)
## `FREEZE_IDLE` (the light gate, 2026-11-12): the idle clip holds its first frame, so a capture does not depend on how many frames a
## view change took.
var _freeze_idle: bool = DevFlag.on("FREEZE_IDLE")
const FALL_GU_S: float = 3.0          ## how fast an actor drops onto lower ground (GU of height a second)
const CLIMB_GU_S: float = 1.5         ## and climbs back up
## Gameplay decides WHO is revealed (vision, skills and progress are gameplay, not physics); this only draws it: every
## part of the mesh an opaque wall covers becomes a striped silhouette (`actor_mesh_silhouette3d.gdshader`, chained as
## the `next_pass` of each board-lit surface). Off, nothing extra is drawn or allocated.
var reveal_behind_walls: bool = false:
	set(value):
		reveal_behind_walls = value
		_apply_reveal()
## Added to the silhouette's stripe scroll, in stripes (the billboard's knob of the same name).
var silhouette_phase: float = 0.0:
	set(value):
		silhouette_phase = value
		if _silhouette != null:
			_silhouette.set_shader_parameter("phase", value)
var _silhouette: ShaderMaterial = null
## R3D-LOOK item 7 (Director, 2026-10-05): the reveal silhouette takes its colour from the actor's FACTION, so a revealed guard and a
## revealed agent never read alike. Per faction: the two stripe colours and the outline. Unknown ids keep the shader's own lilac.
const REVEAL_PALETTES: Dictionary = {
	&"agent": {"stripe_a": Color(0.86, 0.96, 1.0), "stripe_b": Color(0.16, 0.28, 0.38), "outline_color": Color(1.0, 1.0, 1.0)},
	&"agency": {"stripe_a": Color(0.46, 0.64, 1.0), "stripe_b": Color(0.08, 0.14, 0.40), "outline_color": Color(0.30, 0.56, 1.0)},
	&"militia": {"stripe_a": Color(1.0, 0.52, 0.36), "stripe_b": Color(0.40, 0.10, 0.06), "outline_color": Color(1.0, 0.34, 0.18)},
	&"corporation": {"stripe_a": Color(1.0, 0.84, 0.30), "stripe_b": Color(0.38, 0.28, 0.04), "outline_color": Color(1.0, 0.74, 0.12)},
	&"network": {"stripe_a": Color(0.46, 0.96, 0.62), "stripe_b": Color(0.06, 0.30, 0.14), "outline_color": Color(0.28, 0.90, 0.46)},
}
var reveal_faction: StringName = &"":
	set(value):
		reveal_faction = value
		_apply_reveal_palette()
static var _warned_family: Dictionary = {}
static var _warned_action: Dictionary = {}


## Drive this mesh from `source`. Returns false (and logs) when the rig cannot be loaded, leaving nothing half-built.
func setup_actor(board: Node3D, source: ActorPose) -> bool:
	## The AGENT (family "") wears the Tripo Agent; a guard family listed in TRIPO_BY_FAMILY wears its Tripo body; the others keep
	## the rig of their own family (the officer).
	var tripo: String = _dev_value(TRIPO_FIGURE_FLAG, AGENT_FIGURE_DEFAULT) if source.frame_family.is_empty() else ""
	if tripo == TRIPO_FIGURE_NONE:
		tripo = ""
	var tripo_rig: String = ""
	if TRIPO_BY_FAMILY.has(source.frame_family):
		tripo = String(TRIPO_BY_FAMILY[source.frame_family]["figure"])
		var where: Array = TRIPO_BY_FAMILY[source.frame_family]["enemy"]
		tripo_rig = ModelPaths.enemy(String(where[0]), String(where[1]), "game", String(where[2]))
	if not tripo.is_empty():
		if not TripoFigureRef.FIGURES.has(tripo):
			push_error("[ActorMesh3D] %s=%s: expected one of %s" % [TRIPO_FIGURE_FLAG, tripo, TripoFigureRef.FIGURES])
			return false
		if not _load_tripo(board, tripo, _dev_value(TRIPO_MOVE_FLAG, TRIPO_MOVE_DEFAULT), tripo_rig):
			return false
		if TRIPO_BY_FAMILY.has(source.frame_family) and TRIPO_BY_FAMILY[source.frame_family].has("maps"):
			var where_t: Array = TRIPO_BY_FAMILY[source.frame_family]["enemy"]
			var maps: Dictionary = TRIPO_BY_FAMILY[source.frame_family]["maps"]
			for m: ShaderMaterial in _materials:
				var src_name: String = String(m.get_meta(SOURCE_MATERIAL_META, ""))
				if not src_name.begins_with("Enemy_"):
					continue   ## what it carries (the weapon) keeps its own texture
				if not maps.has(src_name):
					push_error("[ActorMesh3D] %s: material %s has no map in %s" % [source.frame_family, src_name, maps.keys()])
					return false
				var map_path: String = ModelPaths.enemy(String(where_t[0]), String(where_t[1]), "textures", String(maps[src_name]))
				var map := load(map_path) as Texture2D
				if map == null:
					push_error("[ActorMesh3D] %s: map %s missing" % [source.frame_family, map_path])
					return false
				m.set_shader_parameter("albedo_tex", map)
				m.set_shader_parameter("has_tex", 1.0)
	else:
		var family: String = source.frame_family
		var file: String = String(RIG_BY_FAMILY.get(family, ""))
		if file.is_empty():
			file = String(RIG_BY_FAMILY[""])
			if not _warned_family.has(family):
				_warned_family[family] = true
				push_warning("[ActorMesh3D] no live rig for family '%s' — it wears the agent's (export one with P2_MODEL)" % family)
		if not _load_rig(board, RIG_DIR + file):
			return false
	_source = source
	for gait: String in _gaits:
		var row: Dictionary = _gaits[gait]
		if not (row["start_dist"] as Dictionary).is_empty():
			source.set("dash_start" if gait == "run" else "walk_start", row["start_dist"])
		if not (row["rise"] as Dictionary).is_empty():
			source.set("dash_rise" if gait == "run" else "walk_rise", (row["rise"] as Dictionary)["start_dist"])
		if not (row["pose_stops"] as Dictionary).is_empty():
			source.set("dash_stop" if gait == "run" else "walk_stop", row["pose_stops"])
	_build_contact_shadow(source.get_parent())
	name = "Mesh_%s" % (source.get_parent().name if source.get_parent() != null else source.name)
	process_priority = 100  ## after the actor has moved and the sprite has decided, this frame
	_sync()
	return true


func _load_rig(board: Node3D, path: String) -> bool:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("[ActorMesh3D] cannot load the rig %s (run tools/asset_generation/r3d_live_rig_export.py)" % path)
		return false
	var body := scene.instantiate() as Node3D
	var players := body.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("[ActorMesh3D] %s has no AnimationPlayer — re-export the rig" % path)
		body.free()
		return false
	_board = board
	_body = body
	_body.scale = Vector3.ONE * METRES_TO_UNITS
	add_child(_body)
	_apply_board_light(_body)
	_player = players[0] as AnimationPlayer
	_player.speed_scale = 0.0  ## seeked, never played
	var skeletons := _body.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0] as Skeleton3D
		_head_bone = _skeleton.find_bone("head")
		_head = HeadTurnRef.new()
		(skeletons[0] as Skeleton3D).add_child(_head)
	for attachment in _body.find_children("*", "BoneAttachment3D", true, false):
		var bone: String = (attachment as BoneAttachment3D).bone_name
		for child in attachment.get_children():
			if bone == "hand_R" and String(child.name).begins_with("Weapon_"):
				_weapons[String(child.name).trim_prefix("Weapon_")] = child
			elif bone == "hand_L":
				_grenade = child
	return true


## The Tripo Agent `figure` (LIGHT), dressed and board-lit, with the game set of its clips on its player (`TripoFigure`). False
## (loud) when the figure or its clips are missing, leaving nothing half-built. `rig` replaces the Agent's model with another body on
## his skeleton (a guard, TRIPO_BY_FAMILY); the clips stay the figure's.
func _load_tripo(board: Node3D, figure: String, move_clip: String, rig: String = "") -> bool:
	var path: String = rig if not rig.is_empty() else TripoFigureRef.rig_path(figure, true)
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("[ActorMesh3D] cannot load the Tripo Agent %s (run build_agents.sh)" % path)
		return false
	var lib: AnimationLibrary = TripoFigureRef.library(figure)
	if lib == null:
		return false
	_figure = figure
	for clip: String in [TRIPO_IDLE, move_clip]:
		if not lib.has_animation(clip):
			push_error("[ActorMesh3D] the %s game clips have no '%s' (have %s)" % [figure, clip, lib.get_animation_list()])
			return false
	var body := scene.instantiate() as Node3D
	var players := body.find_children("*", "AnimationPlayer", true, false)
	var skeletons := body.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skeletons.is_empty():
		push_error("[ActorMesh3D] %s has no AnimationPlayer or no skeleton" % path)
		body.free()
		return false
	_board = board
	_body = body
	_tripo = figure
	_tripo_move = move_clip
	_front_yaw = TripoFigureRef.FRONT_YAW
	_tripo_units = TripoFigureRef.WORLD_SCALE
	_move_pass = TripoFigureRef.travel_m(lib.get_animation(move_clip)) * _tripo_units
	if _move_pass <= 0.0:
		push_warning("[ActorMesh3D] the %s clip '%s' covers no ground: it will play frozen while the actor walks" % [figure, move_clip])
	if lib.has_animation(TRIPO_RUN):
		_run_pass = TripoFigureRef.travel_m(lib.get_animation(TRIPO_RUN)) * _tripo_units
	else:
		push_warning("[ActorMesh3D] the %s game clips have no '%s': a dash walks" % [figure, TRIPO_RUN])
	for gait: String in GAIT_PASSAGES:
		var g_pass: float = _run_pass if gait == "run" else (_move_pass if move_clip == "walk" else 0.0)
		if g_pass > 0.0:
			_gaits[gait] = _load_gait(lib, gait, g_pass)
	_body.scale = Vector3.ONE * _tripo_units
	add_child(_body)
	_apply_board_light(_body)
	TripoFigureRef.hide_pieces(_body, false)
	_skeleton = skeletons[0] as Skeleton3D
	_head_bone = TripoFigureRef.find_bone(_skeleton, "Head")
	_build_aim_layer(lib, figure)   ## before the head turn: a skeleton's modifiers run in child order
	_build_throw_layer(lib, figure)
	if _head_bone >= 0:
		_head = HeadTurnRef.new()
		_head.set("bone_name", _skeleton.get_bone_name(_head_bone))
		_skeleton.add_child(_head)
	TripoFigureRef.dress_coat(_body, _skeleton, true, true)
	var coat_mesh: MeshInstance3D = TripoFigureRef.coat_of(_body)
	if coat_mesh != null:
		var names: Array = [RUN_COAT_KEY, IDLE_COAT_KEY, WALK_COAT_KEY]
		if lib.has_animation(CROUCH_CLIP):
			var crouch_anim: Animation = lib.get_animation(CROUCH_CLIP)
			_crouch = {"len": crouch_anim.length, "fps": float(crouch_anim.get_meta(&"start_fps", 24.0)), "morphs": crouch_anim.get_meta(&"start_morphs", {})}
			names.append_array((_crouch["morphs"] as Dictionary).keys())
		for gait: String in _gaits:
			var row: Dictionary = _gaits[gait]
			names.append_array((row["start_morphs"] as Dictionary).keys())
			if not (row["rise"] as Dictionary).is_empty():
				names.append_array((row["rise"]["start_morphs"] as Dictionary).keys())
			for side: String in row["stops"]:
				names.append_array((row["stops"][side]["morphs"] as Dictionary).keys())
		for name: String in names:
			var idx: int = coat_mesh.find_blend_shape_by_name(name)
			if idx >= 0:
				_coat_keys[name] = idx   ## a passage key the coat lacks (an empty one never shaped) plays without it
	_player = players[0] as AnimationPlayer
	_player.add_animation_library(TripoFigureRef.LIBRARY_NAME, lib)
	_player.speed_scale = 0.0  ## seeked, never played
	return true


## One gait's passages read off the game set (`GAIT_PASSAGES`): its start and its stops, their ground per frame in GU and their coat keys.
func _load_gait(lib: AnimationLibrary, gait: String, g_pass: float) -> Dictionary:
	var spec: Dictionary = GAIT_PASSAGES[gait]
	var row: Dictionary = {"clip": spec["clip"], "pass": g_pass, "contacts": spec["contacts"], "start_clip": spec["start"], "stop_clips": spec["stops"],
		"start_len": 0.0, "start_handoff": 0.0, "start_morphs": {}, "start_fps": 24.0, "start_dist": {}, "stops": {}, "pose_stops": {}, "rise": {}}
	if lib.has_animation(String(RISE_CLIPS[gait])):   ## rising from the crouch into the gait: the start's fields, from its own timeline
		var rise: Animation = lib.get_animation(String(RISE_CLIPS[gait]))
		var rdist := PackedFloat32Array()
		for d: float in rise.get_meta(&"start_travel", PackedFloat32Array()):
			rdist.append(d * _tripo_units)
		var rfps: float = float(rise.get_meta(&"start_fps", 24.0))
		row["rise"] = {"start_clip": RISE_CLIPS[gait], "start_len": rise.length, "start_handoff": float(rise.get_meta(&"start_handoff", 0.0)),
			"start_morphs": rise.get_meta(&"start_morphs", {}), "start_fps": rfps, "start_dist": {"fps": rfps, "dist": rdist}}
	if lib.has_animation(String(spec["start"])):
		var start: Animation = lib.get_animation(String(spec["start"]))
		row["start_len"] = start.length
		row["start_handoff"] = float(start.get_meta(&"start_handoff", 0.0))
		row["start_morphs"] = start.get_meta(&"start_morphs", {})
		row["start_fps"] = float(start.get_meta(&"start_fps", 24.0))
		var dist := PackedFloat32Array()
		for d: float in start.get_meta(&"start_travel", PackedFloat32Array()):
			dist.append(d * _tripo_units)
		row["start_dist"] = {"fps": row["start_fps"], "dist": dist}
	for side: String in spec["stops"]:
		var id: String = spec["stops"][side]
		if not lib.has_animation(id):
			continue
		var stop: Animation = lib.get_animation(id)
		var sdist := PackedFloat32Array()
		for d: float in stop.get_meta(&"start_travel", PackedFloat32Array()):
			sdist.append(d * _tripo_units)
		if sdist.size() < 2:
			continue
		var sfps: float = float(stop.get_meta(&"start_fps", 24.0))
		row["stops"][side] = {"len": stop.length, "fps": sfps, "morphs": stop.get_meta(&"start_morphs", {}), "reach": sdist[sdist.size() - 1]}
		row["pose_stops"][side] = {"fps": sfps, "dist": sdist}
	return row


## The aim layer and the pistol in the right hand of a Tripo Agent, from the game set's `pose_aim_pistol`. Missing pose or model: said loudly, the agent
## simply does not aim (it stands through it, as before).
func _build_aim_layer(lib: AnimationLibrary, figure: String) -> void:
	var stops: Array = []
	_sequence = AimSequenceRef.new()
	if not _sequence.load_file(figure, AimSequenceRef.PISTOL_DRAW):
		_sequence = null
	if _sequence != null:
		for stop: Dictionary in _sequence.stops:
			var seq_pose: String = TripoFigureRef.POSE_PREFIX + String(stop["id"])
			if not lib.has_animation(seq_pose):
				push_warning("[ActorMesh3D] the %s game set has no '%s': the agent plays the plain draw (run pose_lab.py sequence %s)" % [figure, seq_pose, AimSequenceRef.PISTOL_DRAW])
				_sequence = null
				stops.clear()
				break
			stops.append([float(stop["weight"]), lib.get_animation(seq_pose), bool(stop["passing"])])
	if _sequence == null:
		for stop: Array in AIM_STOPS:
			var pose_id: String = TripoFigureRef.POSE_PREFIX + String(stop[0])
			if not lib.has_animation(pose_id):
				push_warning("[ActorMesh3D] the %s game set has no '%s': the agent will not aim (run godot/scripts/tools/tripo_game_clips.gd)" % [figure, pose_id])
				return
			stops.append([float(stop[1]), lib.get_animation(pose_id), stop.size() > 2])
	var layer: ActorAimPoseRef = ActorAimPoseRef.new()
	_skeleton.add_child(layer)
	if not layer.load_stops(_skeleton, stops):
		layer.queue_free()
		return
	_aim = layer
	var recoil: ActorRecoilRef = ActorRecoilRef.new()
	_skeleton.add_child(recoil)   ## after the aim, before the head turn
	if recoil.setup(_skeleton):
		_recoil = recoil
	else:
		recoil.queue_free()
	_raise_s = _sequence.raise_seconds() if _sequence != null else AIM_RAISE_S
	_lower_s = _raise_s if _sequence != null else AIM_LOWER_S
	_aim_kind = _aim_key("pistol", "standing")
	_aim_sets[_aim_kind] = {"layer": _aim, "seq": _sequence, "raise": _raise_s, "lower": _lower_s, "hip": 1.0, "coat": null, "morphs": {}}
	for family: String in FAMILY_DRAWS:
		for posture: String in FAMILY_DRAWS[family]:
			if not _aim_sets.has(_aim_key(family, posture)):
				_build_family_aim(lib, figure, family, posture)
	_build_pistol(stops)
	var coat: MeshInstance3D = TripoFigureRef.coat_of(_body)
	_coat_draw_shape = coat.find_blend_shape_by_name(DRAW_COAT_SHAPE) if coat != null else -1
	if _coat_draw_shape >= 0:
		_coat = coat
	else:
		push_warning("[ActorMesh3D] the %s coat has no '%s' morph: it stays closed through the draw" % [figure, DRAW_COAT_SHAPE])


## The aim set of a hold family in a posture (`FAMILY_DRAWS`): "pistol:standing", "shotgun:standing", ...
static func _aim_key(family: String, posture: String) -> String:
	return "%s:%s" % [family, posture]


## The posture an aim set is chosen for: the crouch has its own draws, every other posture the standing ones.
static func _posture_kind(state: Dictionary) -> String:
	return "crouch" if String(state["posture"]) == "crouch" else "standing"


## A further draw's layer (the crouched pistol, the long guns' draw), right after the standing pistol's, so the recoil still acts after all of them. No
## timeline or a missing pose: the set does not exist and the figure simply does not draw that family in that posture (said once when a pose is missing).
## A long draw also drives its own coat keys (`LongDrawFix_f<frame>`, each at its frame); the pistol's draws drive only `DrawFix` (`_coat_draw_shape`).
func _build_family_aim(lib: AnimationLibrary, figure: String, family: String, posture: String) -> void:
	var seq: AimSequenceRef = AimSequenceRef.new()
	if not seq.load_file(figure, String(FAMILY_DRAWS[family][posture])):
		return
	var stops: Array = []
	for stop: Dictionary in seq.stops:
		var pose_id: String = TripoFigureRef.POSE_PREFIX + String(stop["id"])
		if not lib.has_animation(pose_id):
			push_warning("[ActorMesh3D] the %s game set has no '%s': no %s draw %s (run godot/scripts/tools/tripo_game_clips.gd)" % [figure, pose_id, family, posture])
			return
		stops.append([float(stop["weight"]), lib.get_animation(pose_id), bool(stop["passing"])])
	var layer: ActorAimPoseRef = ActorAimPoseRef.new()
	_skeleton.add_child(layer)
	_skeleton.move_child(layer, _aim.get_index() + 1)
	if not layer.load_stops(_skeleton, stops):
		layer.queue_free()
		return
	layer.weight = 0.0
	var morphs: Dictionary = {}
	var coat: MeshInstance3D = TripoFigureRef.coat_of(_body) if family != "pistol" else null
	if coat != null:
		for morph: String in seq.at(0.5)["morphs"]:
			var idx: int = coat.find_blend_shape_by_name(morph)
			if idx >= 0:
				morphs[morph] = idx   ## a key the coat lacks (an empty one, never shaped) plays without it
	_aim_sets[_aim_key(family, posture)] = {"layer": layer, "seq": seq, "raise": seq.raise_seconds(), "lower": seq.raise_seconds(),
		"hip": seq.marker_weight("hip", 1.0), "coat": coat if not morphs.is_empty() else null, "morphs": morphs}


## The set `kind` becomes the active one (only with the gun away, `_aim_t` 0): its layer, timeline, paces, hip stop and coat keys, and the gun node
## follows its timeline's bone (a long gun rides the LEFT hand). The set it leaves gives its coat keys back.
func _use_aim_set(kind: String) -> void:
	_aim.weight = 0.0
	for morph: String in _aim_morphs:
		_aim_coat.set_blend_shape_value(int(_aim_morphs[morph]), 0.0)
	var aim_set: Dictionary = _aim_sets[kind]
	_aim_kind = kind
	_aim = aim_set["layer"]
	_sequence = aim_set["seq"]
	_raise_s = float(aim_set["raise"])
	_lower_s = float(aim_set["lower"])
	_aim_hip_w = float(aim_set["hip"])
	_aim_coat = aim_set["coat"]
	_aim_morphs = aim_set["morphs"]
	if _pistol == null or _sequence == null:
		return
	var bone: int = TripoFigureRef.find_bone(_skeleton, _sequence.gun_bone())
	if bone < 0:
		push_error("[ActorMesh3D] no bone '%s' for the %s draw: the gun stays on '%s'" % [_sequence.gun_bone(), kind, _pistol.bone_name])
	elif _skeleton.get_bone_name(bone) != _pistol.bone_name:
		_pistol.bone_name = _skeleton.get_bone_name(bone)


## The throw's timeline as a path layer and the grenade in its hand. No timeline or a missing pose: said once, the agent throws standing still as before.
func _build_throw_layer(lib: AnimationLibrary, figure: String) -> void:
	var seq: AimSequenceRef = AimSequenceRef.new()
	if not seq.load_file(figure, AimSequenceRef.THROW_OVERHAND):
		return
	var stops: Array = []
	for stop: Dictionary in seq.stops:
		var pose_id: String = TripoFigureRef.POSE_PREFIX + String(stop["id"])
		if not lib.has_animation(pose_id):
			push_warning("[ActorMesh3D] the %s game set has no '%s': no throw on this figure (run pose_lab.py sequence %s)" % [figure, pose_id, AimSequenceRef.THROW_OVERHAND])
			return
		stops.append([float(stop["weight"]), lib.get_animation(pose_id), bool(stop["passing"])])
	var layer: ActorAimPoseRef = ActorAimPoseRef.new()
	_skeleton.add_child(layer)
	if not layer.load_stops(_skeleton, stops):
		layer.queue_free()
		return
	_throw = layer
	_throw_seq = seq
	var hand: int = TripoFigureRef.find_bone(_skeleton, seq.gun_bone())
	var model: String = TripoFigureRef.prop_model(seq.prop)
	var scene := load(model) as PackedScene
	if hand < 0 or scene == null:
		push_error("[ActorMesh3D] no bone '%s' or no model for '%s' (%s): the agent throws empty-handed" % [seq.gun_bone(), seq.prop, model])
	else:
		var attach := BoneAttachment3D.new()
		attach.name = "GrenadeHand"
		attach.bone_name = _skeleton.get_bone_name(hand)
		_skeleton.add_child(attach)
		var holder := Node3D.new()
		attach.add_child(holder)
		holder.add_child(scene.instantiate() as Node3D)
		_apply_board_light(attach)
		attach.visible = false
		_throw_grenade = attach
		_throw_grenade_holder = holder
		_throw_grenade_scale = TripoFigureRef.held_prop_scale(seq.prop)
	_throw_coat = TripoFigureRef.coat_of(_body)
	if _throw_coat != null:
		for name: String in seq.at(0.5)["morphs"]:
			var idx: int = _throw_coat.find_blend_shape_by_name(name)
			if idx >= 0:
				_throw_morphs[name] = idx


## The throw this frame: where along the timeline the body is (`_throw_w`), from the pose's throw and our own pace (see `THROW_TURN_RAD_S`'s note).
func _update_throw(state: Dictionary) -> void:
	if _throw == null:
		return
	var dt: float = get_process_delta_time()
	var pace: float = _throw_seq.fps / float(_throw_seq.last - _throw_seq.first)   ## timeline weight per second
	var cocked: float = _throw_seq.marker_weight("cocked", 0.32)
	var released: float = _throw_seq.marker_weight("release", 0.56)
	var seq: String = String(state["throw"])
	if seq == ActorPose.THROW_RAISE:
		_throw_phase = "cancel" if bool(state["throw_reversed"]) else "raise"
	elif seq == ActorPose.THROW_RELEASE:
		if _throw_phase != "recover":
			_throw_phase = "release"
	elif _throw_phase == "release":
		_throw_phase = "recover"
	elif _throw_phase != "recover":
		_throw_phase = "cancel" if _throw_w > 0.0 else ""
	match _throw_phase:
		"raise":
			if _aim_t <= 0.0:   ## the pistol is away first
				_throw_w = move_toward(_throw_w, cocked, pace * dt)
		"cancel":
			_throw_w = move_toward(_throw_w, 0.0, pace * dt)
			if _throw_w <= 0.0:
				_throw_phase = ""
		"release":
			var u: float = clampf(float(state["throw_u"]) / ActorPose.THROW_RELEASE_FRACTION, 0.0, 1.0)
			_throw_w = maxf(_throw_w, lerpf(cocked, released, u))
			if u >= 1.0:
				_throw_phase = "recover"
		"recover":
			_throw_w = move_toward(_throw_w, 1.0, pace * dt)
			if _throw_w >= 1.0:
				_throw_w = 0.0
				_throw_phase = ""
	_throw.weight = _throw_w
	var here: Dictionary = _throw_seq.at(_throw_w) if _throw_w > 0.0 else {}
	if _throw_grenade != null:
		_throw_grenade.visible = _throw_w > 0.0 and bool(here["visible"])
		if _throw_w > 0.0:
			var xf: Transform3D = here["gun"] as Transform3D
			if _throw_grenade_scale > 0.0:   ## the row's one size (hand = flight = floor), not the timeline's per-figure scale
				xf.basis = xf.basis.orthonormalized().scaled(Vector3.ONE * _throw_grenade_scale)
			_throw_grenade_holder.transform = xf
		if _throw_grenade.visible and _throw_grenade_holder.is_inside_tree():
			_throw_last_hand = _throw_grenade_holder.global_position
	for name: String in _throw_morphs:
		if _throw_w <= 0.0 and _coat_keys.has(name):
			continue   ## outside the throw a shared key (IdleFix) is `_update_run_coat`'s
		_throw_coat.set_blend_shape_value(int(_throw_morphs[name]), float((here.get("morphs", {}) as Dictionary).get(name, 0.0)))


## Where the thrown grenade leaves: the last place it was in the hand (global), INF when this figure has thrown nothing yet with a timeline.
func throw_release_global() -> Vector3:
	return _throw_last_hand


## Whether the body is in the throw (raised, holding, releasing or coming back): the turn to the aim holds through it.
func _throwing() -> bool:
	return _throw_w > 0.0 or _throw_phase != ""


## The pistol in the hand: its placement comes from the poses (`props` meta: the Director's, set in Blender, or the default), one per stop, blended between the stops
## like the arms are. Missing model or bone: said loudly, the agent aims empty-handed.
func _build_pistol(stops: Array) -> void:
	_pistol_stops.clear()
	for stop: Array in stops:
		if bool(stop[2]):                   ## a passing stop carries no placement: the gun blends between the resting ones
			continue
		var props: Dictionary = (stop[1] as Animation).get_meta("props", {})
		_pistol_stops.append([float(stop[0]), props["pistol"] if props.has("pistol") else TripoFigureRef.prop_default("pistol")])
	var bone_name: String = _sequence.gun_bone() if _sequence != null else String((_pistol_stops[_pistol_stops.size() - 1][1] as Dictionary)["bone"])
	var hand: int = TripoFigureRef.find_bone(_skeleton, bone_name)
	var model_path: String = TripoFigureRef.prop_model("pistol")
	var scene := load(model_path) as PackedScene if model_path != "" else null
	if hand < 0 or scene == null:
		push_error("[ActorMesh3D] no bone '%s' or no pistol model (%s): the agent aims empty-handed" % [bone_name, model_path])
		_pistol_stops.clear()
		return
	var attach := BoneAttachment3D.new()
	attach.name = "PistolHand"
	attach.bone_name = _skeleton.get_bone_name(hand)
	_skeleton.add_child(attach)
	var holder := Node3D.new()   ## its transform is the pose's placement of the model's scene root
	attach.add_child(holder)
	attach.visible = false
	_pistol = attach
	_pistol_holder = holder
	_hold_model("pistol")


## MOVEMENT §11.6 step 2 — the model of the weapon row `id` in the hand, held like the family's reference: the timeline places the
## reference, the model sits in the reference's frame by its row's `held_rel_for(figure)`. Said loudly and left as it was when the row or its
## model is missing.
func _hold_model(id: String) -> void:
	if _pistol_holder == null or id == _held_id:
		return
	var w: WeaponDef = WeaponRegistry.shared().get_weapon(id)
	var scene := load(w.model_path) as PackedScene if w != null and w.model_path != "" else null
	if scene == null:
		push_error("[ActorMesh3D] weapon '%s' has no row or no model: the hand keeps '%s'" % [id, _held_id])
		_held_id = id   ## once, not every frame
		return
	for child in _pistol_holder.get_children():
		child.queue_free()
	_attach_node = null
	_attach_id = ""
	_attach_def = null
	var model := scene.instantiate() as Node3D
	model.transform = w.held_rel_for(_figure)
	_split_fx_pieces(model, w)   ## before the light: the split keeps the source materials the light converts
	_pistol_holder.add_child(model)
	_apply_board_light(model)
	_held_id = id
	_held_def = w


## The row's moving pieces split off the model it just loaded (`ShotProjectiles3D.split_part`); a named piece the model lacks is said once.
func _split_fx_pieces(model: Node3D, w: WeaponDef) -> void:
	_fx_part = null
	_fx_string = null
	_fx_spin = null
	_fx_spent = false
	_hook_handle = {}
	_fx_part = ShotProjectilesRef.split_part(model, w.fx_part)
	_fx_string = ShotProjectilesRef.split_part(model, w.fx_string) as MeshInstance3D
	_fx_spin = ShotProjectilesRef.split_part(model, w.fx_spin)
	for pair in [[w.fx_part, _fx_part], [w.fx_string, _fx_string], [w.fx_spin, _fx_spin]]:
		if String(pair[0]) != "" and pair[1] == null:
			push_error("[ActorMesh3D] weapon '%s' names the piece '%s' (fx) and its model has none: it does not move" % [w.id, pair[0]])
	if _fx_string != null:
		_fx_string_drawn = _fx_string.mesh
		_fx_string_fired = ShotProjectilesRef.fired_string_mesh(_fx_string)
	if _fx_spin != null and _fx_spin is MeshInstance3D:
		## The drum turns about the axis its box is longest or shortest along, the one unlike the other two (its round section is the pair).
		var box: AABB = (_fx_spin as MeshInstance3D).mesh.get_aabb()
		var e: Vector3 = box.size
		var odd: int = 0
		var best: float = -1.0
		for k in range(3):
			var others: Array = [e[(k + 1) % 3], e[(k + 2) % 3]]
			var diff: float = absf(e[k] - (float(others[0]) + float(others[1])) * 0.5)
			if diff > best:
				best = diff
				odd = k
		_fx_spin_axis = Vector3.ZERO
		_fx_spin_axis[odd] = 1.0
		_fx_spin_centre = box.get_center()
		_fx_spin_base = _fx_spin.transform


## A shot's own body leaves the gun (`WeaponDef.fx_projectile`): dart, probes, hook or flare, thrown at `to` (board-local; `normal`, `host`:
## the struck face and voxel, Vector3i.MAX none) by the board's `ShotProjectiles3D`. False when nothing could fly (no gun drawn, a tracer row).
func fire_projectile(to: Vector3, normal: Vector3, host: Vector3i) -> bool:
	if _held_def == null or _pistol == null or not _pistol.visible:
		return false
	var g: Vector3 = muzzle_global()
	if g == Vector3.INF:
		return false
	var from: Vector3 = _board.to_local(g)
	var upm: float = (_board.global_basis.inverse() * _pistol_holder.global_basis).x.length()
	var shots := ShotProjectilesRef.of(_board)
	var muzzle_now := func() -> Vector3:
		var m: Vector3 = muzzle_global()
		return Vector3.INF if m == Vector3.INF else _board.to_local(m)
	if _fx_spent:   ## fired again before it was put away: it reloads at once
		_fx_reload()
	var ok: bool = false
	match _held_def.fx_projectile:
		"dart":
			ok = shots.launch_dart(_held_def, _fx_part, from, to, normal, host)
		"hook":
			if not _hook_handle.is_empty() and not bool(_hook_handle.get("done", true)):
				return false   ## the hook is still out
			_hook_handle = shots.launch_hook(_held_def, _fx_part, from, to, muzzle_now, upm)
			ok = not _hook_handle.is_empty()
		"probes":
			ok = shots.launch_probes(_held_def, from, to, normal, host, muzzle_now, upm)
		"flare":
			ok = shots.launch_flare(_held_def, from, to, upm)
	if ok:
		_fx_spent = true
		if _fx_part != null:
			_fx_part.visible = false
		if _fx_string != null and _fx_string_fired != null:
			_fx_string.mesh = _fx_string_fired
	return ok


## The gun loaded again: the piece back on it, the string drawn, the drum at rest.
func _fx_reload() -> void:
	_fx_spent = false
	if _fx_part != null:
		_fx_part.visible = true
	if _fx_string != null and _fx_string_drawn != null:
		_fx_string.mesh = _fx_string_drawn
	if _fx_spin != null:
		_fx_spin.transform = _fx_spin_base


## Each frame: a gun put away comes back loaded; a hook wound back is on the gun again; the drum turns while its line winds.
func _update_fx(dt: float) -> void:
	if _pistol == null:
		return
	if not _hook_handle.is_empty():
		if bool(_hook_handle.get("winding", false)) and _fx_spin != null:
			var turn := Transform3D(Basis(_fx_spin_axis, -TAU * drum_turns_per_s * dt), Vector3.ZERO)
			var about := Transform3D(Basis.IDENTITY, _fx_spin_centre) * turn * Transform3D(Basis.IDENTITY, -_fx_spin_centre)
			_fx_spin.transform = _fx_spin.transform * about
		if bool(_hook_handle.get("done", false)):
			_hook_handle = {}
			_fx_reload()
	if _fx_spent and not _pistol.visible and _hook_handle.is_empty():
		_fx_reload()


## The attachment `id` on the held weapon's muzzle ("" takes it off): its model in the holder, placed on that weapon's own muzzle.
func _hold_attachment(id: String) -> void:
	if _pistol_holder == null or _held_def == null or id == _attach_id:
		return
	if _attach_node != null:
		_attach_node.queue_free()
		_attach_node = null
	_attach_id = id
	_attach_def = null
	if id == "":
		return
	var a: AttachmentDef = AttachmentRegistry.shared().get_attachment(id)
	var scene := load(a.model_path) as PackedScene if a != null and a.model_path != "" else null
	if scene == null or _held_def.muzzle == Vector3.INF:
		push_error("[ActorMesh3D] attachment '%s' has no row, no model, or '%s' has no muzzle: none mounted" % [id, _held_id])
		return
	var rel: Transform3D = _held_def.held_rel_for(_figure)
	_attach_node = scene.instantiate() as Node3D
	_attach_node.transform = rel * a.mount_in(_held_def, rel.basis.get_scale().x)
	_pistol_holder.add_child(_attach_node)
	_apply_board_light(_attach_node)   ## only the new model: a second pass over a lit one reads its ShaderMaterial as "no colour" (white)
	_attach_def = a


## Where the held model's round leaves, in the holder's frame (the reference's placement): the row's muzzle carried by `held_rel_for(figure)`.
## INF when the row has no measured muzzle.
func _held_muzzle() -> Vector3:
	if _held_def == null or _held_def.muzzle == Vector3.INF:
		return Vector3.INF
	if _attach_node != null and _attach_def != null and _attach_def.muzzle != Vector3.INF:
		return _attach_node.transform * _attach_def.muzzle   ## the round leaves the attachment's end
	return _held_def.held_rel_for(_figure) * _held_def.muzzle


## The pistol's placement at `weight` of the aim path: the stops' placements blended with the same easing the arms use (`ActorAimPose3D`): position and scale lerped,
## rotation slerped; before the first stop it is the first one.
func _pistol_placement(weight: float) -> Transform3D:
	var k: int = 0
	while k < _pistol_stops.size() - 1 and weight > float(_pistol_stops[k][0]):
		k += 1
	var to: Dictionary = _pistol_stops[k][1]
	var from: Dictionary = to if k == 0 else _pistol_stops[k - 1][1]
	var from_w: float = 0.0 if k == 0 else float(_pistol_stops[k - 1][0])
	var t: float = smoothstep(0.0, 1.0, clampf((weight - from_w) / (float(_pistol_stops[k][0]) - from_w), 0.0, 1.0)) if k > 0 else 1.0
	var q: Quaternion = (from["quat"] as Quaternion).slerp(to["quat"] as Quaternion, t)
	var s: float = lerpf(float(from["scale"]), float(to["scale"]), t)
	return Transform3D(Basis(q).scaled(Vector3.ONE * s), (from["pos"] as Vector3).lerp(to["pos"] as Vector3, t))


## The aim layer's weight this frame: toward the stance's stop while the held weapon is aimed and the figure stands (or kneels, fully down), toward 0
## otherwise (the raise and the lowering are the same travel read both ways), eased; the gun is drawn only once the hand is at it. The stance's stop is
## the end of the timeline, or the long gun's `hip` marker for the hip shot.
func _update_aim(state: Dictionary) -> void:
	if _aim == null:
		return
	## Standing still only: the aim is a whole-body stance (the idle sways and must not show through), so a walking figure keeps its legs and lowers the gun.
	var dt: float = get_process_delta_time()
	_update_fx(dt)
	_shot_hold = maxf(0.0, _shot_hold - dt)
	if _shot_t != INF:
		_shot_t += dt
	var posture_kind: String = _posture_kind(state)
	var kind: String = _aim_key(String(state["weapon"]), posture_kind)
	if _aim_t <= 0.0 and kind != _aim_kind and _aim_sets.has(kind):   ## the gun is away: the family's and the posture's own layer takes over
		_use_aim_set(kind)
	var ready: bool = kind == _aim_kind and float(state["walk"]) < 0.0 and (String(state["posture"]) == "standing" \
		or (posture_kind == "crouch" and not _crouch.is_empty() and _crouch_t >= float(_crouch["len"])))   ## crouched: once fully down
	var weapon_id: String = String(state.get("weapon_id", ""))
	if weapon_id == "":
		weapon_id = String(state["weapon"])   ## "" = the grip's default weapon (`ActorPose.weapon_id`): the family's reference row, `pistol` / `shotgun`
	if weapon_id != _armed_id:
		_armed_id = weapon_id
		var w: WeaponDef = WeaponRegistry.shared().get_weapon(weapon_id) if weapon_id != "" else null
		_armed = w != null and w.model_path != ""
	if kind == _aim_kind and _armed and _pistol != null and not _pistol.visible:
		_hold_model(weapon_id)   ## swapped only while the gun is out of sight (in the coat)
		_hold_attachment(String(state.get("attachment", "")))
	var stow: bool = bool(state.get("stow", false))   ## the actor is about to do something else: the gun goes away now (`ActorPose.stow_weapon`)
	if stow:
		_shot_hold = 0.0
	var want: bool = not stow and ready and _armed and (String(state["grip"]) == "_aimed" or _shot_hold > 0.0)
	_aim_target = 0.0
	if want:
		_aim_target = _aim_hip_w if String(state.get("stance", "aimed")) == "hip" else 1.0
	_aim_t = move_toward(_aim_t, _aim_target, dt / (_raise_s if _aim_target > _aim_t else _lower_s))
	_aim.weight = _aim_t
	if _sequence != null:   ## his timeline: the coat, the gun's visibility and placement are what he keyed
		var here: Dictionary = _sequence.at(_aim_t)
		if _coat != null:
			_coat.set_blend_shape_value(_coat_draw_shape, float(here["coat"]))
		var morphs: Dictionary = here["morphs"]
		for morph: String in _aim_morphs:
			_aim_coat.set_blend_shape_value(int(_aim_morphs[morph]), float(morphs.get(morph, 0.0)))
		if _pistol != null:
			var placed: Transform3D = here["gun"]
			_pistol.visible = bool(here["visible"])
			_pistol_holder.transform = placed * _gun_kick(placed.basis.get_scale().x)
		return
	if _coat != null:
		var opened: float = smoothstep(0.0, PISTOL_SHOWN_FROM, _aim_t) if _aim_t <= PISTOL_SHOWN_FROM else 1.0 - smoothstep(PISTOL_SHOWN_FROM, DRAW_COAT_CLOSED_AT, _aim_t)
		_coat.set_blend_shape_value(_coat_draw_shape, opened)
	if _pistol != null:
		_pistol.visible = _aim_t > PISTOL_SHOWN_FROM
		_pistol_holder.transform = _pistol_placement(_aim_t) * _gun_kick()


## MOVEMENT 2026-11-17 (Director: *"o agente saca, atira e guarda automaticamente antes de andar/correr/fazer outra coisa"*): whether the
## held weapon is still out: raised, held after a shot, or on its way back into the coat. The agent's move waits for false (`Agent._weapon_away`).
func weapon_out() -> bool:
	return _aim != null and (_aim_t > 0.0 or _shot_hold > 0.0)


## MOVEMENT §11.6 step 3: whether the held weapon is at the stance its shot is fired from (the long gun's hip, or the end of its draw), so the shot
## waits for it (`AgentShotController`). True when the figure is not drawing anything (no aim layer, a row with no model, a posture with no draw):
## there is nothing to wait for.
func weapon_at_stance() -> bool:
	return _aim == null or _aim_target <= 0.0 or absf(_aim_t - _aim_target) <= 1e-4


## The gun's own kick in its model space (barrel +X, up +Y), as the last shot's recoil profile says (`ActorRecoil3D.gun_kick_*`; none for a long
## gun, which the body carries): back along the barrel (the figure's units: the model's own scale `model_scale` in the hand is divided out) and up
## about the grip, on the body's envelope.
func _gun_kick(model_scale: float = 1.0) -> Transform3D:
	if _recoil == null or _shot_t == INF:
		return Transform3D.IDENTITY
	var e: float = _recoil.envelope(_shot_t)
	if e <= 0.0:
		return Transform3D.IDENTITY
	return Transform3D(Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(_recoil.gun_kick_deg() * e)),
		Vector3(-_recoil.gun_kick_back() * e / maxf(model_scale, 1e-6), 0.0, 0.0))


## A shot from the gun in the hand: the body (and the pistol in the hand) kick by the recoil profile of the held family and the stance the shot
## leaves from (a long gun at the hip or at the shoulder), the aim is held through it, a case flies when the row throws one. False when no gun is
## drawn (the old rig).
func fire_kick() -> bool:
	if _recoil == null or _pistol == null or not _pistol.visible or not _pistol_holder.is_inside_tree():
		return false
	var gt: Transform3D = _pistol_holder.global_transform
	var stance: String = "hip" if _aim_hip_w < 1.0 and _aim_target < 1.0 else "aimed"
	_recoil.kick(gt.basis.z, _recoil.profile_for(_aim_kind.get_slice(":", 0), stance))
	_shot_t = 0.0
	_shot_hold = SHOT_HOLD_S
	if _held_def == null or _held_def.fx_case:
		_eject_case(gt)
	return true


## The spent case, from the port, in the board's space and at the gun's scale (the model is in metres).
func _eject_case(gt: Transform3D) -> void:
	var to_board: Basis = _board.global_basis.inverse()
	var local_basis: Basis = to_board * gt.basis
	var units_per_m: float = local_basis.x.length()
	var held: Vector3 = _held_muzzle()
	var tip: Vector3 = held if held != Vector3.INF else Vector3(1.0, 0.0, 0.0)
	var barrel: Vector3 = (to_board * (gt.basis * tip)).normalized()   ## grip -> muzzle, as the round leaves
	var right: Vector3 = barrel.cross(Vector3.UP).normalized()
	var vel: Vector3 = right * EJECT_RIGHT_M * randf_range(0.8, 1.2) + Vector3.UP * EJECT_UP_M * randf_range(0.85, 1.15) - barrel * EJECT_BACK_M
	ShellCasingsRef.of(_board).call("eject", _board.to_local(gt * EJECT_PORT), vel, units_per_m)


## HERITAGE T2 W4 — where the held weapon's round leaves, in GLOBAL space: the weapon row's `muzzle` (a point of the model)
## carried by the gun's real placement in the hand (the pose / the Director's draw timeline). INF when no weapon with a
## measured muzzle is drawn in the hand (not aiming, the old rig): the caller falls back to its old anchor.
func muzzle_global() -> Vector3:
	if _pistol == null or _pistol_holder == null or not _pistol.visible or not _pistol_holder.is_inside_tree():
		return Vector3.INF
	var tip: Vector3 = _held_muzzle()
	if tip == Vector3.INF:
		return Vector3.INF
	return _pistol_holder.global_transform * tip


## A dev flag (`DevFlag`: the environment, then the APK's overrides file, then `fallback`).
func _dev_value(flag_name: String, fallback: String) -> String:
	return DevFlag.value(flag_name, fallback)


## Where the grenade in the raised hand is, in the world: the `hand_L` attachment's own origin, which the pose seeks every frame. Vector3(INF, INF, INF)
## ("none", the emitters' `NO_ANCHOR`) while that grenade is hidden (not in a throw's raise, or past the release).
func hand_grenade_world() -> Vector3:
	if _throw_grenade != null and _throw_grenade.visible and _throw_grenade_holder.is_inside_tree():
		return _throw_grenade_holder.global_position
	if _grenade == null or not _grenade.visible or not _grenade.is_inside_tree():
		return Vector3(INF, INF, INF)
	return _grenade.global_position


func _process(_delta: float) -> void:
	if not is_instance_valid(_source) or not is_instance_valid(_board):
		queue_free()
		return
	_sync()


func _sync() -> void:
	var parent: Node = _source.get_parent()
	visible = parent == null or (parent is CanvasItem and (parent as CanvasItem).is_visible_in_tree())
	if not visible:
		return
	## The pose node sits at its actor's origin, so the actor's 2D position IS where the feet are.
	position = _board.call("ground_point", (parent as Node2D).global_position)
	var ground := Vector2(position.x, position.z)
	## GRAVITY (Director, 2026-10-18): the feet rest on what is under them (`Board3DLive.stand_height`: a pit's bed, a crater, a crust's plate, ice, a
	## quicksand), reached at a walking pace up and a falling one down, never snapped mid-step.
	var target: float = float(_board.call("stand_height", position, parent))
	if is_nan(_stand_y):
		_stand_y = target
	else:
		var dt: float = get_process_delta_time()
		_stand_y = move_toward(_stand_y, target, dt * (FALL_GU_S if target < _stand_y else CLIMB_GU_S))
	position.y += _stand_y
	var state: Dictionary = _source.mesh_state()
	var step: Vector2i = state["step"]
	if step != Vector2i.ZERO:
		_yaw = yaw_for_direction(Vector2(step))
	## The throw turns the whole body in place to the aimed cell (Director 2026-11-12) and back to the grid facing after, at `THROW_TURN_RAD_S`.
	var want_yaw: float = _yaw
	var aim_dir: Vector2 = state.get("throw_dir", Vector2.ZERO)
	var throwing_now: bool = _throwing() or String(state["throw"]) != ""
	if aim_dir != Vector2.ZERO and throwing_now:
		want_yaw = yaw_for_direction(aim_dir)
	## The first tap on a destination turns the idle figure toward it; a move that starts mid-turn keeps turning to the step's facing.
	var turn_dir: Vector2 = state.get("turn_dir", Vector2.ZERO)
	var tapping: bool = turn_dir != Vector2.ZERO and not (throwing_now or float(state["walk"]) >= 0.0)
	if tapping:
		want_yaw = yaw_for_direction(turn_dir)
	var throwing: bool = throwing_now or tapping
	if is_nan(_shown_yaw) or not (throwing or _throw_turning_back):   ## outside a throw the facing snaps, as it always did (D47)
		_shown_yaw = want_yaw
	var turn: float = wrapf(want_yaw - _shown_yaw, -PI, PI)
	_shown_yaw += clampf(turn, -THROW_TURN_RAD_S * get_process_delta_time(), THROW_TURN_RAD_S * get_process_delta_time())
	_throw_turning_back = throwing or absf(wrapf(want_yaw - _shown_yaw, -PI, PI)) > 1e-4
	_body.rotation.y = _shown_yaw + _front_yaw
	var body_yaw: float = _shown_yaw
	if not _tripo.is_empty():
		_show_tripo(float(state["walk"]) >= 0.0, ground, state)
		_update_aim(state)
		_update_throw(state)
	else:
		var weapon: String = String(state["weapon"])   ## the grip the rig holds (`ActorPose.set_weapon`, the row's `held_as`)
		for held: String in _weapons:
			(_weapons[held] as Node3D).visible = held == weapon
		var throw_seq: String = state["throw"]
		var u: float = 0.0
		var action: String
		if throw_seq != "":
			action = "throw_%s_%s" % [throw_seq, weapon]
			u = float(state["throw_u"])
		elif float(state["walk"]) >= 0.0:
			action = "walk_%s" % weapon
			u = float(state["walk"])
		else:
			action = "%s_%s_%s" % [state["posture"], weapon, "aimed" if String(state["grip"]) == "_aimed" else "lowered"]
		if _grenade != null:
			_grenade.visible = throw_seq == ActorPose.THROW_RAISE \
				or (throw_seq == ActorPose.THROW_RELEASE and u < ActorPose.THROW_RELEASE_FRACTION)
		_show_or_fallback(action, u, weapon)
	if _head != null:
		var head: float = float(state["head"])
		var posture: String = state["posture"]
		if is_nan(head) or posture == "prone":
			_head.set("yaw", 0.0)
		else:
			## A grid angle: 0 = North (0, -1), +90 = East (1, 0), the guard's `vision_angle` convention.
			var rad: float = deg_to_rad(head)
			var want: float = yaw_for_direction(Vector2(sin(rad), -cos(rad)))
			var limit: float = deg_to_rad(ActorPose.HEAD_YAW_LIMIT_DEG)
			_head.set("yaw", clampf(wrapf(want - body_yaw, -PI, PI), -limit, limit))


## Where the head is above the feet in 2D canvas pixels on the N lattice (what `ActorPose.head_offset_px()` answers,
## and the agent's muzzle and throw origin are built on): the rig's `head` bone in its current pose, carried onto the
## lattice through the BASE view's basis, so it does not change when the camera turns. Standing, it reads about -165 px
## where the bake's head socket read -168.6 (the bone's head is the base of the skull, the socket a little above it).
func head_offset_px() -> Vector2:
	if _skeleton == null or _head_bone < 0:
		return Vector2.ZERO
	var head: Vector3 = (_skeleton.global_transform * _skeleton.get_bone_global_pose(_head_bone)).origin
	var d: Vector3 = head - global_position
	var lattice: Basis = _board.call("lattice_basis")
	var ppu: float = _board.call("px_per_unit")
	return Vector2(d.dot(lattice.x), -d.dot(lattice.y)) * ppu


## The yaw that turns the rig's front (its local -Z: the toes and the knee pole) toward a BASE grid direction. Grid x is
## world +X, grid y is world +Z (`Board3DLive.ground_point()`).
static func yaw_for_direction(dir: Vector2) -> float:
	return atan2(-dir.x, -dir.y)


func _show(action: String, u: float) -> void:
	if action != _action:
		if not _player.has_animation(action):
			if not _warned_action.has("!" + action):
				_warned_action["!" + action] = true
				push_error("[ActorMesh3D] the rig has no '%s' action, not even the fallback — re-export it" % action)
			return
		_action = action
		_player.play(action)
	_player.seek(clampf(u, 0.0, 1.0) * _player.current_animation_length, true)


## `_show()` for an action the rig may lack: a missing one is said ONCE (it would otherwise log every frame) and the
## figure falls back to standing with the lowered grip, which every rig has.
func _show_or_fallback(action: String, u: float, weapon: String) -> void:
	if _player.has_animation(action):
		_show(action, u)
		return
	if not _warned_action.has(action):
		_warned_action[action] = true
		push_warning("[ActorMesh3D] the rig has no '%s' action — showing standing; re-export it with r3d_live_rig_export.py" % action)
	_show("standing_%s_lowered" % weapon, 0.0)


## The Tripo Agent's clip this frame: the move clip while the actor walks, phased by the ground it has covered (`ground`: the feet
## on the board, world units), so one pass of the clip takes exactly its `travel_m` of ground; the idle on its own clock otherwise.
## The change between the two is a snap (D47's default; the transitions are MOVEMENT's next step).
func _show_tripo(walking: bool, ground: Vector2, state: Dictionary) -> void:
	var dash: bool = walking and _run_pass > 0.0 and bool(state.get("dash", false))
	if walking and not is_nan(_last_ground.x):
		_walked += ground.distance_to(_last_ground) * (_phase_k if _start_t < 0.0 else 1.0)
	_last_ground = ground
	## A move from standing opens on its gait's authored start; it hands over to the gait's clip on the start's last frame, its phase set to that frame.
	if walking and not _was_walking:
		_gait = _gaits.get("run" if dash else "walk", {})
		if not _gait.is_empty() and not (_gait["rise"] as Dictionary).is_empty() and not _crouch.is_empty() \
				and _crouch_t >= float(_crouch["len"]) - 0.001 and float(state.get("dash_rate", 0.0)) > 0.0:
			_gait = _gait.duplicate()   ## fully crouched: the start is the rise (the row's own start fields replaced by it)
			_gait.merge(_gait["rise"], true)
		_walked = 0.0
		_start_t = 0.0 if not _gait.is_empty() and float(_gait["start_len"]) > 0.0 and float(state.get("dash_rate", 0.0)) > 0.0 else -1.0
		_plan_stop(float(state.get("dash_len", 0.0)), _start_t >= 0.0, dash)
	elif not walking:
		_gait = {}
		_start_t = -1.0
		_phase_k = 1.0
		_stop_side = ""
	var stop_t: float = float(state.get("stop_t", -1.0)) if walking and _stop_side != "" else -1.0
	if _was_stopping and not walking:
		_idle_t = IDLE_REFERENCE_FRAME / 24.0   ## the stop ends on the idle's frame 90: the idle carries on from there
	_was_stopping = stop_t >= 0.0
	_was_walking = walking
	if _start_t >= 0.0:
		_start_t += get_process_delta_time() * float(state.get("dash_rate", 1.0))
		if _start_t >= float(_gait["start_len"]):
			_start_t = -1.0
			var g_len: float = _player.get_animation("%s/%s" % [TripoFigureRef.LIBRARY_NAME, _gait["clip"]]).length
			_walked = float(_gait["start_handoff"]) / g_len * float(_gait["pass"]) if g_len > 0.0 else 0.0
	var crouched: bool = not walking and not _crouch.is_empty() and String(state["posture"]) == "crouch"
	## The gun goes back into the coat BEFORE the kneel or the rise (Director, 2026-11-17): while the other posture's aim is still up, the body waits
	## (`_update_aim` lowers it the moment the posture changes, then the new posture's own aim takes over, raised again if the aim is still held).
	var gun_first: bool = _aim_t > 0.0 and not _aim_kind.ends_with(":" + _posture_kind(state))
	if gun_first and (crouched or (_crouch_t >= 0.0 and not walking)):
		pass   ## the kneel (or the rise) holds where it is
	elif crouched:
		_crouch_t = minf(maxf(_crouch_t, 0.0) + get_process_delta_time(), float(_crouch["len"]))
	elif _crouch_t >= 0.0 and not walking:
		## standing up is the crouch played BACKWARDS (Director, 2026-11-15), coat keys included; it ends on the crouch's first frame,
		## the idle's frame 90, where the idle carries on
		_crouch_t -= get_process_delta_time()
		if _crouch_t <= 0.0:
			_crouch_t = -1.0
			_idle_t = IDLE_REFERENCE_FRAME / 24.0
	elif _crouch_t >= 0.0:
		_crouch_t = -1.0   ## a move ordered while crouched or rising cuts to it (no crouch -> walk passage yet)
		_idle_t = IDLE_REFERENCE_FRAME / 24.0
	_update_run_coat(dash, walking, stop_t)
	if _crouch_t >= 0.0:
		var crouch_clip: String = "%s/%s" % [TripoFigureRef.LIBRARY_NAME, CROUCH_CLIP]
		if crouch_clip != _action:
			_action = crouch_clip
			_player.play(crouch_clip)
		_player.seek(_crouch_t, true)
		return
	var move_name: String = String(_gait["stop_clips"][_stop_side]) if stop_t >= 0.0 else (String(_gait["start_clip"]) if _start_t >= 0.0 else (TRIPO_RUN if dash else _tripo_move))
	var clip: String = "%s/%s" % [TripoFigureRef.LIBRARY_NAME, move_name if walking else TRIPO_IDLE]
	if clip != _action:
		_action = clip
		_player.play(clip)
	var length: float = _player.current_animation_length
	var t: float = 0.0
	if walking and stop_t >= 0.0:
		t = minf(stop_t, length)
	elif walking and _start_t >= 0.0:
		t = minf(_start_t, length)
	elif walking:
		var pass_m: float = _run_pass if dash else _move_pass
		if pass_m > 0.0:
			t = fposmod(_walked / pass_m, 1.0) * length
	else:
		## The pose layers (aim, draw, throw) all start from the idle's frame 90 (Director 2026-11-13: 145 was farthest from the legs but its stance is crooked
		## on the female): the moment one is asked for, the idle CUTS to it and holds, no blend, no wait.
		var layered: bool = _aim_t > 0.0 or _throwing() or String(state["throw"]) != "" \
			or (_armed and _aim_sets.has(_aim_key(String(state["weapon"]), "standing")) and String(state["grip"]) == "_aimed" and String(state["posture"]) == "standing")
		if layered:
			if not _idle_cut:
				_idle_t = minf(IDLE_REFERENCE_FRAME / 24.0, length)
			_idle_cut = true
		else:
			_idle_cut = false
			if not _freeze_idle:
				_idle_t = fposmod(_idle_t + get_process_delta_time(), length)
		t = _idle_t
	_player.seek(t, true)


## Which stop this move ends on, and how much its gait's stride is evened for it (see `GAIT_PASSAGES`). `length`: the move, GU; `started`: it opens on
## the authored start (whose ground and handoff phase come before the gait's own).
func _plan_stop(length: float, started: bool, dash: bool) -> void:
	_phase_k = 1.0
	_stop_side = ""
	if _source != null:
		_source.stop_side = ""
	var stops: Dictionary = _gait.get("stops", {})
	if stops.is_empty() or length <= 0.0:
		return
	var g_len: float = _player.get_animation("%s/%s" % [TripoFigureRef.LIBRARY_NAME, _gait["clip"]]).length
	var g_pass: float = float(_gait["pass"])
	if g_len <= 0.0:
		return
	var start_ground: float = 0.0
	var phase0: float = 0.0
	if started:
		var sd: PackedFloat32Array = (_gait["start_dist"] as Dictionary).get("dist", PackedFloat32Array())
		start_ground = sd[sd.size() - 1] if sd.size() > 0 else 0.0
		phase0 = float(_gait["start_handoff"]) / g_len
	var best: float = INF
	for side: String in stops:
		var ground: float = length - float(stops[side]["reach"]) - start_ground
		if ground <= 0.0:
			continue
		var phase: float = phase0 + ground / g_pass
		for loop in range(int(ceil(phase)) + 2):
			for contact: Array in _gait["contacts"]:
				if String(contact[1]) != side:
					continue
				var c: float = float(loop) + float(contact[0]) / 24.0 / g_len
				if c <= phase0:
					continue
				var k: float = (c - phase0) / (phase - phase0)
				if k < PHASE_K_RANGE.x or k > PHASE_K_RANGE.y or absf(k - 1.0) >= best:
					continue
				best = absf(k - 1.0)
				_phase_k = k
				_stop_side = side
	if _source != null:
		_source.stop_side = _stop_side
	print_debug("[RUN-PASSAGE] %s %s of %.0f GU: stop on the %s foot, stride x%.3f" % [_tripo, "dash" if dash else "walk", length, {"l": "left", "r": "right"}.get(_stop_side, "(none)"), _phase_k])


## The coat keys of a move: the passage's own per frame (a start or a stop), else the gait's corrective key held (none while standing but the idle's).
func _update_run_coat(dash: bool, walking: bool, stop_t: float = -1.0) -> void:
	var coat: MeshInstance3D = TripoFigureRef.coat_of(_body) if not _coat_keys.is_empty() else null
	if coat == null:
		return
	var passage: Dictionary = _gait.get("start_morphs", {})
	var frame: float = _start_t * float(_gait.get("start_fps", 24.0))
	if _crouch_t >= 0.0:
		passage = _crouch["morphs"]
		frame = _crouch_t * float(_crouch["fps"])
	elif stop_t >= 0.0:
		passage = _gait["stops"][_stop_side]["morphs"]
		frame = stop_t * float(_gait["stops"][_stop_side]["fps"])
	for name: String in _coat_keys:
		var v: float = 0.0
		if (_start_t >= 0.0 or stop_t >= 0.0 or _crouch_t >= 0.0) and passage.has(name):
			var vals: PackedFloat32Array = passage[name]
			var a: int = clampi(int(floor(frame)), 0, vals.size() - 1)
			var b: int = mini(a + 1, vals.size() - 1)
			v = lerpf(vals[a], vals[b], clampf(frame - float(a), 0.0, 1.0))
		elif name == RUN_COAT_KEY and dash:
			v = 1.0
		elif name == WALK_COAT_KEY and walking and not dash:
			v = 1.0
		elif name == IDLE_COAT_KEY and not walking:
			v = 1.0 - _aim_t   ## a throw's timeline takes it over while it plays (`_update_throw`)
		coat.set_blend_shape_value(int(_coat_keys[name]), v)


## Every surface becomes one board-lit material carrying the model's own albedo colour and texture (one per source
## material, shared across surfaces), registered with the board so the light rebuilds reach it.
func _apply_board_light(body: Node) -> void:
	var converted: Dictionary = {}
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in range(m.mesh.get_surface_count()):
			var src: Material = m.get_active_material(s)
			if not converted.has(src):
				var sm := ShaderMaterial.new()
				sm.shader = BoardLook.graded_shader(SHADER_PATH)
				var std := src as BaseMaterial3D
				if std != null:
					sm.set_shader_parameter("albedo", std.albedo_color)
					if std.albedo_texture != null:
						sm.set_shader_parameter("albedo_tex", std.albedo_texture)
						sm.set_shader_parameter("has_tex", 1.0)
				sm.set_meta(SOURCE_MATERIAL_META, src.resource_name if src != null else "")
				converted[src] = sm
				_materials.append(sm)
				_board.call("register_prop_light_material", sm)
			m.set_surface_override_material(s, converted[src])


## M6 F5 — what a liquid left on the actor, drawn over its board light: `color` (alpha = how much, 0 clears it), `pulse` 1 makes it breathe (a fire).
func set_status_tint(color: Color, pulse: float) -> void:
	for m: ShaderMaterial in _materials:
		m.set_shader_parameter("status_tint", color)
		m.set_shader_parameter("status_pulse", pulse)


## The actor's contact shadow (Director, 2026-11-09, replacing the diamond R3D-WORLD carried over from the 2D actor): a soft black disc flat on the ground under the feet, which the camera
## squashes into a horizontal ellipse in every view. The fade lives in the vertex colours, so it takes no texture and goes through the ground marks' own shader (depth-tested, never
## writing depth, not drawn behind a glass pane). The actor is also handed the board for its dev-vision draws.
func _build_contact_shadow(actor: Node) -> void:
	if actor == null:
		return
	add_child(contact_shadow_node())
	if actor.has_method("set_board3d"):
		actor.call("set_board3d", _board)


## The contact shadow as a node of its own, the same disc for every actor and (HERITAGE, 2026-11-11, Director: "a mesma
## sombrinha genérica que está embaixo dos atores") for a floating pickup, which scales it.
static func contact_shadow_node() -> MeshInstance3D:
	var verts := PackedVector3Array([Vector3(0.0, SHADOW_LIFT, 0.0)])
	var cols := PackedColorArray([Color(0.0, 0.0, 0.0, CONTACT_SHADOW_OPACITY)])
	var indices := PackedInt32Array()
	var n: int = CONTACT_SHADOW_SEGMENTS
	for r: int in range(CONTACT_SHADOW_RINGS.size()):
		var ring: Array = CONTACT_SHADOW_RINGS[r]
		var radius: float = CONTACT_SHADOW_RADIUS * float(ring[0])
		for s: int in range(n):
			var a: float = TAU * float(s) / float(n)
			verts.append(Vector3(cos(a) * radius, SHADOW_LIFT, sin(a) * radius))
			cols.append(Color(0.0, 0.0, 0.0, CONTACT_SHADOW_OPACITY * float(ring[1])))
			var next: int = (s + 1) % n
			var here: int = 1 + r * n
			if r == 0:
				indices.append_array(PackedInt32Array([0, here + s, here + next]))
			else:
				var inner: int = here - n
				indices.append_array(PackedInt32Array([inner + s, here + s, here + next, inner + s, here + next, inner + next]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = "ContactShadow"
	node.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADOW_SHADER)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _apply_reveal() -> void:
	if reveal_behind_walls and _silhouette == null:
		_silhouette = ShaderMaterial.new()
		_silhouette.shader = load(SILHOUETTE_SHADER_PATH)
		_silhouette.render_priority = SILHOUETTE_PRIORITY
		_silhouette.set_shader_parameter("phase", silhouette_phase)
		_apply_reveal_palette()
	for m: ShaderMaterial in _materials:
		m.next_pass = _silhouette if reveal_behind_walls else null


func _apply_reveal_palette() -> void:
	if _silhouette == null:
		return
	var palette: Dictionary = REVEAL_PALETTES.get(reveal_faction, {})
	for key: String in ["stripe_a", "stripe_b", "outline_color"]:
		if palette.has(key):
			_silhouette.set_shader_parameter(key, palette[key])


func _exit_tree() -> void:
	## Only if this mesh still owns the sprite: on a reload the NEW board's figure has already hidden it.
	if is_instance_valid(_source) and _source.has_meta("figure3d") and _source.get_meta("figure3d") == self:
		var actor: Node = _source.get_parent()
		if actor != null and actor.has_method("set_board3d"):
			actor.call("set_board3d", null)
	if is_instance_valid(_board):
		for m in _materials:
			_board.call("unregister_prop_light_material", m)
