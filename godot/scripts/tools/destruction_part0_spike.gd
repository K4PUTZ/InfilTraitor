## DESTRUCTION_MASTER_PLAN — Part 0 measurement spike.
##
## Not a standing gate, not a selftest suite. This is the one-shot investigation
## Part 0 calls for: "force the worst cases and measure... find where it breaks."
## No production code depends on this script; it exists to turn the plan's one
## real unknown (TileMapLayer count scaling) and its two other worst-case
## numbers into real, printed, reproducible evidence before Slab (Part 1) is
## written on top of a guess.
##
## Honesty boundary, stated once here instead of at every print: this runs
## `--headless` on a Mac, not on the target mobile device. Headless Godot has
## no display driver, so nothing here measures GPU draw cost — only the CPU-side
## bookkeeping cost (node creation, TileMapLayer.set_cell(), memory). The plan
## itself asks for target-device numbers (§5 Part 0); this script produces the
## Mac/CPU half of that, not a substitute for it.
extends SceneTree

const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const TextureResolverClass = preload("res://godot/scripts/systems/texture_resolver.gd")
const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")

const MAP_GU_SIZE: int = 26  ## matches the plan's §4 worst-case reference map


func _init() -> void:
	print("\n" + "=".repeat(78))
	print("DESTRUCTION_MASTER_PLAN — Part 0 measurement spike (%s)" % Time.get_date_string_from_system())
	print("=".repeat(78))

	_test_a_tilemaplayer_scaling()
	_test_b_full_floor_voxelization()
	_test_c_bake_combo_scaling()

	print("\n[SPIKE] Done. Numbers above are Mac-headless CPU/memory only — see file header.\n")
	quit(0)


func _mem_mb() -> float:
	return Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0


## TEST A — TileMapLayer count scaling. The plan's one stated real unknown
## (§4, §7.1): "the suspected real ceiling." floors + slabs + ceilings each
## add levels on top of what walls already use, so this measures the raw
## per-node cost of _ensure_voxel_layers() at increasing counts.
func _test_a_tilemaplayer_scaling() -> void:
	print("\n--- TEST A: TileMapLayer count scaling (VoxelRenderer._ensure_voxel_layers) ---")
	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)

	var checkpoints: Array[int] = [8, 16, 24, 32, 48, 64, 96, 128, 192, 256]
	var t_start := Time.get_ticks_usec()
	var mem_start := _mem_mb()
	var prev_t := t_start
	var prev_mem := mem_start

	print("  %8s %12s %12s %12s %12s" % ["layers", "cum_ms", "delta_ms", "cum_MB", "delta_MB"])
	for n in checkpoints:
		renderer._ensure_voxel_layers(n)
		var t_now := Time.get_ticks_usec()
		var mem_now := _mem_mb()
		print("  %8d %12.2f %12.3f %12.2f %12.4f" % [
			n,
			(t_now - t_start) / 1000.0,
			(t_now - prev_t) / 1000.0,
			mem_now - mem_start,
			mem_now - prev_mem,
		])
		prev_t = t_now
		prev_mem = mem_now

	print("  -> %d layers created, %.2f ms total, %.2f MB static memory delta" % [
		renderer.get_layer_count(), (prev_t - t_start) / 1000.0, prev_mem - mem_start,
	])
	renderer.queue_free()


## TEST B — a fully voxelised 26x26 floor (676 GU x 64 voxels = 43,264 cells,
## the plan's §4 worst-case number), placed as ONE destructible level (D13:
## floor is 2-layer, only the top level is destructible — not a full storey).
func _test_b_full_floor_voxelization() -> void:
	print("\n--- TEST B: Fully voxelised %dx%d floor, 1 destructible level ---" % [MAP_GU_SIZE, MAP_GU_SIZE])
	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)
	renderer._ensure_voxel_layers(1)

	var total_gu := MAP_GU_SIZE * MAP_GU_SIZE
	var mem_before := _mem_mb()
	var t_start := Time.get_ticks_usec()
	var placed := 0

	for gy in range(MAP_GU_SIZE):
		for gx in range(MAP_GU_SIZE):
			for voxel_pos in GeometryCoordsClass.gu_voxels(Vector2i(gx, gy)):
				renderer._set_voxel_cell(voxel_pos, 0, "concrete")
				placed += 1

	var t_end := Time.get_ticks_usec()
	var mem_after := _mem_mb()
	var total_ms := (t_end - t_start) / 1000.0

	print("  GUs=%d, cells placed=%d (expected %d)" % [total_gu, placed, total_gu * 64])
	print("  placement wall time: %.2f ms total, %.5f ms/cell" % [total_ms, total_ms / placed])
	print("  static memory delta: %.2f MB (%.2f KB/cell)" % [
		mem_after - mem_before, (mem_after - mem_before) * 1024.0 / placed,
	])
	print("  cells actually recorded by renderer diagnostics: %d" % renderer.get_placed_cell_count())
	renderer.queue_free()


## TEST C — bake cost scaling with material-combo count. Solid texturing (D2)
## generalises the SAME compositor rather than writing a new one, so combo
## count (not a new mechanism) is what would grow if block volumes add
## materials/directions to bake. This measures today's real per-combo cold
## cost on this machine and prints an explicitly-labelled EXTRAPOLATION for a
## larger combo count — it does not fabricate a "with blocks" measurement,
## because no block-volume bake path exists yet to measure (Part 2, not built).
func _test_c_bake_combo_scaling() -> void:
	print("\n--- TEST C: Bake cold-compose cost per combo (today's real baseline) ---")
	var resolver := TextureResolverClass.new()
	var registry := MaterialRegistryClass.new()
	var compositor := BakeCompositorClass.new()
	compositor.set_material_registry(registry)
	compositor.clear_cache()
	compositor.clear_disk_cache()

	var materials: Array[String] = ["concrete", "stone", "metal", "wood"]
	var combo_count := 0
	var t_start := Time.get_ticks_usec()

	for material_id in materials:
		var facade_id := "facade_" + material_id
		var resolved = resolver.resolve(facade_id)
		var facade = resolved.image if resolved else null
		if facade == null:
			continue
		for dir in range(2):
			compositor._compose_sheet_page(material_id, facade_id, facade, dir, Color.WHITE)
			combo_count += 1

	var t_end := Time.get_ticks_usec()
	var total_ms := (t_end - t_start) / 1000.0
	var per_combo_ms := total_ms / combo_count if combo_count > 0 else 0.0

	print("  measured: %d combos (4 materials x 2 directions), %.1f ms total, %.1f ms/combo" % [
		combo_count, total_ms, per_combo_ms,
	])
	print("  (2026-07-12 plan baseline for the same 4x2 shape: ~1104 ms — same order of magnitude,")
	print("   run-to-run variance on this machine is real; treat both as ballpark, not pinned.)")

	print("\n  EXTRAPOLATION ONLY (no block-volume bake path exists to measure directly):")
	for projected_combos in [8, 24, 48]:
		print("    %3d combos -> ~%.0f ms cold-compose (linear projection from measured per-combo cost)" % [
			projected_combos, per_combo_ms * projected_combos,
		])
