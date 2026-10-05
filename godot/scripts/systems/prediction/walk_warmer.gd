## WalkWarmer - builds the detonation WALK's geometry indexes in idle frames, so the first grenade's cook does not.
##
## R3D-LIGHT (2026-09-26, Moto g04s): the WALK visits every claim (~215 000) to build `cell_to_voxel`, `flammable_cells` and
## `burn_cells`, ~950 ms of a cook's ~1.9 s. They depend on geometry alone, so `VoxelStore.walk_cache` keeps them for the store's
## life and a warm cook enumerates only the claims that can be a hole. The FIRST cook of a board would still pay the build, so
## `Room._rebuild_voxel_store()` hands the store here and the same walk runs `budget_ms` a frame until it is done. A cook that
## starts first simply walks cold (and publishes the cache itself); a rebuilt board abandons the job.
class_name WalkWarmer
extends RefCounted

## Milliseconds of warming one frame may spend. `var` (Rule 1).
static var budget_ms: float = 3.0

static var _job: Dictionary = {}
static var _armed: bool = false


static func begin(store: VoxelStore, containers: Array) -> void:
	_job = {"store": store, "containers": containers, "ci": 0, "vi": 0, "flam": {}, "burn": {}}
	if _armed:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		_job = {}
		return
	_armed = true
	tree.process_frame.connect(_tick)


static func _tick() -> void:
	var job: Dictionary = _job
	if job.is_empty() or VoxelStore.active != job["store"] or not (job["store"] as VoxelStore).walk_cache.is_empty():
		_stop()
		return
	var deadline: int = Time.get_ticks_usec() + int(budget_ms * 1000.0)
	if not DetonationPlanBuilder.warm_walk_step(job, deadline):
		return
	var store: VoxelStore = job["store"]
	store.walk_cache = {
		"flammable": job["flam"], "burn": job["burn"],
		"sig": DetonationPlanBuilder._walk_signature(job["containers"]),
	}
	print("[WALK-WARM] %d claim(s) indexed in idle frames" % store.claims)
	_stop()


static func _stop() -> void:
	_job = {}
	if _armed:
		_armed = false
		(Engine.get_main_loop() as SceneTree).process_frame.disconnect(_tick)
