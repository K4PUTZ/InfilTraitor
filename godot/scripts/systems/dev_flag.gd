## DevFlag — the ONE way a dev flag is read, and the registry of every flag (HERITAGE T3, 2026-11-11).
##
## A dev flag is a diagnostic switch: `INFILTRAITOR_<NAME>` in the environment on desktop, `<NAME>=<value>` in
## `dev_flags.cfg` on a handset (the `DevFlags` autoload loads that file at boot and hands it to `install()`).
## Resolution order, unchanged from DIAG-01: the environment, then the file, then the registry's default.
##
## WHY A STATIC CLASS NEXT TO THE AUTOLOAD. Half the reads were `OS.get_environment("INFILTRAITOR_*")` straight:
## static var initialisers, worker-thread code (the detonation plan), classes that are not nodes. None of those
## can reach `/root/DevFlags`, so a flag they read never reached an APK. `DevFlag` needs no scene tree: the
## overrides are a Dictionary written once on the main thread at boot and only read after, so a worker may call
## it (the Godot 4.6.1 / 4.7.2 worker race is about untyped operators, and every value here is typed).
##
## THE REGISTRY. `FLAGS` names every flag with its default and what it does. A name that is not in it is a loud
## `push_error`, at the read and for a `dev_flags.cfg` key at boot (a typo used to read "" in silence and a
## measurement quietly ran without its switch);
## `check_invariants.py` F1 fails a commit that reads a raw `INFILTRAITOR_` variable or a flag the registry does
## not hold, and one the registry holds that nothing reads.
##
## A default here is the value the flag has when it is set nowhere. A call site that passes its own fallback
## overrides it (`value("X", "fallback")`); new code should not, so the default lives in one place.
class_name DevFlag

const PREFIX: String = "INFILTRAITOR_"

## name -> [default, description]. Sorted by name. Dev-only: nothing here is a gameplay setting.
const FLAGS: Dictionary = {
	"AGENT_START_GU": ["", "\"x,y\": puts the agent's spawn (and so the camera's first centre) there without editing the map"],
	"BENCHMARK": ["", "1: run the detonation benchmark (`_run_detonation_benchmark`) once the map is up, then quit"],
	"BENCH_GRENADE": ["0", "the benchmark's grenade index among the dev grenades"],
	"BENCH_RUNS": ["3", "how many detonations the benchmark times"],
	"BENCH_SETTLE_FRAMES": ["60", "frames the benchmark waits between runs"],
	"BLAST_MAX_RING": ["-1", "caps a bomb's blast rings (a smaller blast for a measurement); -1 = the bomb's own"],
	"BLAST_REPORT": ["", "1: print the blast's report in a release build (debug builds always print it)"],
	"BLAST_SEASON": ["1", "0: the blast without the per-material shot seasoning (RF-S rubble), an A/B"],
	"BOARD_STEP_MS": ["0", "holds the main thread this many ms after each phase of the 3D board's build (PB-2: a slow load watched step by step)"],
	"CAPTURE_PROFILE": ["", "the capture profile a take plays under, over the take's own (device_record.py --take uses `perf`)"],
	"CAPTURE_SHAPE": ["", "portrait / landscape: the shape a capture profile is applied in"],
	"CAPTURE_TIMING": ["", "1: a take records each frame's real duration to user://captures/<take>_timing.csv (capture.py --realtime)"],
	"CAPTURE_WINDOW_FIXED": ["", "1: the capture profile does not resize the window (capture.py sets the size itself)"],
	"CONE_REDRAW_ALWAYS": ["", "1: a guard's vision cone redraws every frame, not only when it changes (a cost A/B)"],
	"CONSEQUENCE": ["", "1: log the consequence beats of a blast (soot, then light) as they play"],
	"COSMETIC_DENSITY": ["", "decorative particle density per device (CosmeticDensity.parse); gameplay is never scaled"],
	"DEV_PANELS": ["", "1: show the dev hover label and the dev panels on the HUD"],
	"ENEMY_FAMILY": ["", "the guards' figure family (an actor_bakes folder suffix), to compare looks"],
	"EVENT_FRAMES": ["", "1: report the worst frames of an event (a detonation, a shot): the device track's main instrument"],
	"FIRE_LIGHT": ["1", "0: a fire casts no light (an A/B of the fire light's cost)"],
	"FIRE_SURFACE": ["0.1", "the liquid fire's surface glow strength on the sheet"],
	"FLAME_EMBER_RATE": ["1.3", "the liquid flames' ember rate scale"],
	"FLAME_H": ["0.75", "the liquid flames' tongue height, GU"],
	"FLAME_STYLE": ["both", "the liquid flames: embers | tongues | both"],
	"FLAME_W": ["0.38", "the liquid flames' tongue width, GU"],
	"FLAT_LIGHT": ["", "1: every light bucket at one tone (a look diagnostic)"],
	"FLUID_AUTO_TICK": ["0", "seconds of real time per liquid turn (0 = only the game's turns)"],
	"FLUID_PREROLL": ["0", "liquid turns already run when the map opens (a capture)"],
	"FLUID_THREAD": ["1", "0: the liquid sheets step on the main thread, not a worker"],
	"FLUID_VALVE": ["", "\"seconds:body:source:rate;...\": turns a liquid source's valve at those real-time seconds"],
	"FRAME_PROBE": ["", "1: print per-frame timing lines (DIAG-01's frame probe)"],
	"FRAMING": ["", "portrait | landscape | desktop: forces the boot viewport framing"],
	"FREEZE_GUARD_TURN": ["", "1: a guard snaps to its facing instead of easing (a capture of the cone)"],
	"GLASS_CRACK_CUT": ["", "0..1: how much of a crack's hole is cut from the pane (a look dial); default 1"],
	"GLASS_CRACK_OPACITY": ["", "the crack web's opacity (a Director look dial, moved twice)"],
	"GLASS_CRAZE_SHEET": ["", "forces one craze sheet for every crazed pane (photographing the family one at a time)"],
	"GLASS_CRAZE_TESTTILE": ["", "1: the crazes use the square wrap test tile"],
	"GLASS_CRAZE_TILE_VOXELS": ["", "the craze wrap tile's span in voxels"],
	"GLASS_DIAG": ["", "1: dump the glass slices / panes as numbers (a diagnostic of a rotated or sheared pane)"],
	"GLASS_DIM_SIDE": ["", "a glass voxel's side-face dimness against its main face (look calibration)"],
	"GLASS_DIM_TOP": ["", "a glass voxel's top-face dimness against its main face (look calibration); default 0.60"],
	"GLASS_OPENING": ["", "forces one opening shape of the family on every hit (photographed one at a time)"],
	"GLASS_RIM": ["", "the glass rim treatment A/B on a cut glass voxel"],
	"GLASS_RING_DIAG": ["", "1: log which blast ring breaks which glass voxel"],
	"GLASS_SHARD": ["", "forces one shard shape id for every shard (capture-only override)"],
	"GRADE": ["", "the board's colour grade parameters, \"a,b,c\" (BoardLook.grade_params)"],
	"GRENADE_GUS": ["", "\"x,y;x,y\": the cells the dev grenades are seeded at (dev captures)"],
	"GROUND_SCATTER": ["1", "0: no ground scatter (an A/B)"],
	"GROUND_SCATTER_X": ["1", "multiplies every zone's scatter density (handset measurement at several stamp counts)"],
	"GROUND_TRANSITIONS": ["1", "0: hard GU edges between grounds (an A/B of the feathered transitions)"],
	"GUARD_FACTIONS": ["", "\"a,b,...\": the factions dealt to the guards in order (a look comparison)"],
	"GUARD_REVEAL": ["1", "0: guards are not revealed by the reveal pass"],
	"HIDE_NODES": ["", "\"pattern,...\": hides every CanvasItem whose name matches (a cost ablation)"],
	"HIDE_NON_VOXEL": ["", "1: hides everything outside the voxel renderer (a cost ablation)"],
	"HIT_STOP": ["1", "0: no hit-stop on a bomb tagged hit_stop"],
	"HOLE_EQUIV": ["", "1: check the fast hole path against the reference one after a blast (an equivalence probe)"],
	"LAYOUT_RAIL": ["", "the rail id the layout overlay shows"],
	"LIGHT_BULK": ["1", "0: the light planes are written cell by cell, not in bulk (an A/B)"],
	"LIGHT_BULK_CHECK": ["", "1: compare the bulk light write with the cell-by-cell one"],
	"LIGHT_COOK_GATE": ["", "1: check the cooked light against a full repaint (costs a repaint)"],
	"LIGHT_EQUIV_PROBE": ["", "1: check the scoped light repaint's neighbourhood against a full one"],
	"LIGHT_SECONDS": ["", "the seconds the consequence light takes to settle (DIAG-19)"],
	"LIQUID_END_TURNS": ["0", "ends n turns where the agent stands, logging the statuses after each"],
	"LIQUID_FALLS": ["1", "0: no waterfall effects (an A/B of their cost; the flow is the plane's either way)"],
	"LIQUID_IGNITE": ["", "\"seconds:x,y,radius;...\" (inner GU): lights the flammable liquids at those real-time seconds"],
	"LIQUID_WALK": ["", "\"x,y;x,y;...\" (inner GU): walks the agent along that path once the map is up"],
	"LIQUID_WALK_FROM": ["", "\"x,y\" (inner GU): where LIQUID_WALK starts"],
	"MAP": ["", "the map to boot (capture-only: never rewrites the persisted choice)"],
	"MAX_FPS": ["", "caps the frame rate (0 = uncapped); measure the GPU uncapped"],
	"MEM_CENSUS": ["", "1: print the memory census once the map is loaded"],
	"MEM_STAGES": ["", "1: mark the memory stages from boot (MemStage)"],
	"NODE_CENSUS": ["", "1: print every node's class, canvas items and process state"],
	"NO_BURN": ["", "1: blasts set nothing alight (an ablation)"],
	"NO_CONSEQUENCE_LIGHT": ["", "1: the consequence light is not played (an instrument, never a look)"],
	"NO_LIGHT": ["", "1: the board's light is disabled (an ablation; the board is wrong on purpose)"],
	"NO_LIGHT_COOK": ["", "1: a committed blast does not cook its light change"],
	"NO_SOOT": ["", "1: the presenter paints no soot"],
	"NO_VSYNC": ["", "1: vsync off (a CPU-cost question only)"],
	"NO_WALK_CACHE": ["", "1: the walk cache warmer stays off (the control for its RAM cost)"],
	"OCC_DISABLE": ["", "1: no occlusion (a capture pair isolates the erased pixels)"],
	"OCC_LIVE_PROBE": ["", "1: log the live occlusion set against the store"],
	"OPENED_EDGES_CHECK": ["", "1: check the blast's fast opened-edge set against the slow one"],
	"PASS_SPLIT": ["1", "0: no depth-reading pass split, the transparent pass merges into the opaque one (the A/B control)"],
	"PICK_CHECK": ["0", "1: run the touch-picking check from every view after the map loads"],
	"PLAN_DIGEST": ["", "1: print a digest of each detonation plan (determinism checks)"],
	"PREDICTION_PROFILE": ["", "1: the prediction's per-phase profile and its worst frame"],
	"PROPS_MESH_DEMO": ["", "1: the static-props-as-meshes prototype (R3D-PROPS), no map data"],
	"PROP_DEBUG": ["", "1: log where each mesh prop is placed and how it breaks"],
	"PROP_SHATTER_DEMO": ["", "1: the prop shatter burst in isolation (R3D-PROPS)"],
	"RELEASE_VOXELS": ["1", "0: the containers keep their persistent Voxel objects (R3D-CLAIMS C2's A/B, ~990 B each)"],
	"RENDER3D_CHUNK": ["16", "the 3D board's chunk size in voxels per side"],
	"RENDER3D_LOAD_PARALLEL": ["1", "0: the board's chunk merge runs serially, not on the WorkerThreadPool (PB-6's A/B)"],
	"RENDER3D_VSCALE": ["1.0", "the board mesh's vertical scale: matched (158 / 156.8) or a float; 1.0 = true cubes (R3D-3)"],
	"RENDER3D_VSCALE_MARKER": ["0", "1: a bright one-storey box at a fixed cell, the reference for the vertical-scale look-call"],
	"RENDER_SCALE": ["", "the 3D render scale on a handset framing (default: the map's)"],
	"REPAINT_PROFILE": ["", "1: time each phase of a light repaint"],
	"RNG_SEED": ["", "the run's random seed (captures, device tables)"],
	"ROOF_FIRE": ["1", "0: fire does not spread across roofs"],
	"SCALE_3D": ["", "the 3D viewport scale (the canvas stays native)"],
	"SCALE_3D_MODE": ["fsr", "fsr | bilinear: how SCALE_3D upscales"],
	"SCENARIO": ["", "a scripted run: steps separated by ';' (ScenarioRunner)"],
	"SEED_GRENADES": ["0", "1: seed the dev grenades on load"],
	"SELECT_EQUIV": ["", "1: check the ranked voxel selection against the reference one"],
	"SELFTEST_DEVFLAG": ["", "dev_flags_selftest's own flag (it sets and reads it)"],
	"SELFTEST_DEVFLAG_NEVER_SET": ["", "never set: dev_flags_selftest's proof that an unset flag reads its fallback"],
	"SHOT_AGENT_CELL": ["", "\"x,y\": puts the agent there before a scripted shot"],
	"SHOT_GUARD_CELL": ["", "\"x,y\": puts the target guard there before a scripted shot"],
	"SHOT_SCOPE_PROBE": ["", "1: check a scoped repaint after a shot against a full one"],
	"SHOT_SETTLE_FRAMES": ["30", "frames a scripted shot waits for its impact to settle"],
	"SHOT_WEAPON": ["", "the weapon a scripted shot fires"],
	"SKIP_JUNCTIONS": ["", "1: junction columns are left out of the walk (a 2D-era capture instrument)"],
	"SMOKE_ALPHA_GAIN": ["2.4", "the blast smoke's alpha gain (read once at class load)"],
	"SMOKE_CHANCE": ["", "a global smoke chance over every material row; < 0 or unset = the rows'"],
	"SMOKE_FEATHER": ["", "the smoke field's edge feather (default 0.75)"],
	"SMOKE_SCALE": ["1.7", "the blast smoke's base scale (read once at class load)"],
	"SOFT_REST": ["1", "0: soft sheets are not settled at load"],
	"SOFT_REST_CACHE": ["1", "0: soft sheets settle without the rest cache"],
	"SOFT_SHEET_RELEASE": ["1", "0: a blast does not release the soft roofs (the cloth stays up)"],
	"SOFT_SHEET_THREAD": ["1", "0: soft sheets simulate on the main thread"],
	"SOFT_WALLS": ["1", "0: cloth / cardboard walls are not sheets"],
	"SOOT_SMOOTH": ["1", "0: a floor top reads one cell's soot instead of blending its four nearest (an R3D-LOOK handset A/B)"],
	"STRETCH_VIEWPORT": ["", "1: the window's content scale mode is VIEWPORT (a cost A/B)"],
	"STRUCT_CASCADE_S": ["0.04", "seconds between the steps of a structural fall"],
	"STRUCT_CUT": ["", "\"x,y,level,...\": the cells the struct_cut scenario cuts"],
	"STRUCT_GRAVITY": ["1", "0: what loses its support does not fall (RF-G)"],
	"STRUCT_GRAVITY_SCALE": ["1.0", "the structural fall's gravity scale"],
	"STRUCT_UNIVERSAL": ["1", "0: only the legacy support rule decides what falls"],
	"SURFACE_PATCH_DEMO": ["", "1: the one-leaf-patch decal prototype (R3D-SURFACES), no map data"],
	"TELEMETRY": ["", "1: telemetry on"],
	"TEL_CHANNELS": ["", "\"a,b,...\": the telemetry channels to record"],
	"TEL_FILE": ["1", "0: telemetry is not written to its file"],
	"TEL_LOGCAT": ["1", "0: telemetry is not echoed to the log"],
	"THROW_PROFILE": ["", "1: the throw's timeline (DIAG-22)"],
	"TRIPO_FIGURE": ["male", "the Agent every actor wears: male | female | none (none = the old r3d_live rig, for comparisons)"],
	"TRIPO_MOVE": ["walk", "the clip the Tripo figure moves with"],
	"VENT_STEAM": ["1", "0: no steam plumes from the vents (a handset A/B)"],
	"VENT_STEAM_KIND": ["", "every vent takes this kind (steam, steam_big)"],
	"VENT_STEAM_RATE": ["1", "> 1 spaces the puffs out (fewer live puffs)"],
	"VENT_STEAM_SIZE": ["1", "multiplies the steam puffs' size"],
	"VFX_DRAW_NOOP": ["", "1: the VFX draw calls do nothing (an ablation)"],
	"VFX_DRAW_PROBE": ["", "1: count the VFX draw calls"],
	"WALK_EQUIV": ["", "1: check the fast map walk against the reference one"],
	"WATER_RAIN": ["", "forces the liquid rain kind (a look study)"],
	"WATER_STUDY": ["", "forces the liquid look kind (a look study)"],
	"ZOOM": ["", "the camera zoom (a capture or a cost measurement)"],
}

## The overrides file's pairs, installed by the `DevFlags` autoload at boot (main thread), read-only after.
static var _overrides: Dictionary = {}


## Called once by `DevFlags._ready()` with the file's pairs.
static func install(overrides: Dictionary) -> void:
	_overrides = overrides.duplicate()


## True when `name` is a registered flag. An unregistered one is reported loudly.
static func known(name: String) -> bool:
	if FLAGS.has(name):
		return true
	push_error("[DevFlag] '%s' is not a registered dev flag: add it to DevFlag.FLAGS (dev_flag.gd)" % name)
	return false


## What `value()` is passed when the caller has no fallback of its own: the registry's default stands. A typed
## sentinel rather than a Variant `null`, because this runs on worker threads (no untyped operator there).
const REGISTRY_DEFAULT: String = "\u0001registry"


## The flag's raw value: the environment, then the overrides file, then `fallback` (or the registry's default).
static func value(name: String, fallback: String = REGISTRY_DEFAULT) -> String:
	var registered: bool = known(name)
	var from_env: String = OS.get_environment(PREFIX + name)
	if not from_env.is_empty():
		return from_env
	if _overrides.has(name):
		return String(_overrides[name])
	if fallback != REGISTRY_DEFAULT:
		return fallback
	if registered:
		return String((FLAGS[name] as Array)[0])
	return ""


## True when the flag resolves to "1" (the project's standing convention).
static func on(name: String) -> bool:
	return value(name, "") == "1"


## The flag as an integer; a value that is not one is reported and `fallback` stands.
static func num(name: String, fallback: int = 0) -> int:
	var raw: String = value(name, "")
	if raw.is_empty():
		return fallback
	if not raw.is_valid_int():
		push_warning("[DevFlag] %s=%s is not an integer; using %d" % [name, raw, fallback])
		return fallback
	return int(raw)


## The flag as a float, with the same contract as `num()`.
static func real(name: String, fallback: float = 0.0) -> float:
	var raw: String = value(name, "")
	if raw.is_empty():
		return fallback
	if not raw.is_valid_float():
		push_warning("[DevFlag] %s=%s is not a float; using %f" % [name, raw, fallback])
		return fallback
	return float(raw)


## Every override in `dev_flags.cfg` that names no registered flag: a typo that would otherwise read "" in
## silence. (Godot cannot list the environment, so a mistyped `INFILTRAITOR_*` variable is caught at its read
## instead, by `known()`.) Called once at boot by the autoload; returns the unknown names.
static func report_unknown() -> PackedStringArray:
	var unknown: PackedStringArray = PackedStringArray()
	for key: String in _overrides:
		if not FLAGS.has(key):
			unknown.append(key)
			push_error("[DevFlag] dev_flags.cfg sets '%s', which is not a registered dev flag" % key)
	return unknown
