## D33 Part 1 — DamageCompositeCache selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/damage_composite_cache_selftest.gd
##
## Part 1's scope (PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §5/§11) is the
## cache + its dynamic page, NOT the pixel math (Part 2) or the render-path
## wiring (Part 3) — so this suite proves allocation, idempotence, page
## overflow, real TileSet registration, and the reset prune_baked_sources()
## now drives, without composing a single real decal.
extends SceneTree

const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const DamageCompositeCacheClass = preload("res://godot/scripts/geometry/damage_composite_cache.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("D33 PART 1 — DAMAGE COMPOSITE CACHE SELFTEST")
	print("=".repeat(70) + "\n")

	test_empty_cache_reports_nothing()
	test_store_registers_a_real_tile_and_is_idempotent()
	test_two_distinct_keys_land_in_distinct_slots_with_correct_pixels()
	test_wrong_sized_image_is_rejected_without_corrupting_state()
	test_page_overflow_allocates_a_second_page()
	test_reset_clears_everything_and_next_store_starts_fresh()
	test_prune_baked_sources_drives_the_reset_for_real()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ DAMAGE COMPOSITE CACHE SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ DAMAGE COMPOSITE CACHE SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


func _new_renderer() -> VoxelRenderer:
	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)
	return renderer


## Solid-color 32x36 RGBA8 image — a real composite's math (Part 2) is not
## this suite's concern; a flat color is enough to prove slot placement and
## pixel fidelity through blit_rect() + the TileSet round trip.
func _solid_atom(color: Color) -> Image:
	var img := Image.create(DamageCompositeCacheClass.ATOM_W, DamageCompositeCacheClass.ATOM_H, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img


func test_empty_cache_reports_nothing() -> void:
	print("[1] A fresh cache has nothing cached and no pages\n")
	var renderer := _new_renderer()
	var cache := renderer.get_damage_composite_cache()

	if not cache.has("anything") and cache.resolve("anything").is_empty() \
			and cache.size() == 0 and cache.page_count() == 0:
		_pass("has()/resolve()/size()/page_count() all report empty on a fresh cache")
	else:
		_fail("a fresh cache reported non-empty state")

	if renderer.get_damage_composite_cache() == cache:
		_pass("get_damage_composite_cache() returns the same lazily-created instance")
	else:
		_fail("get_damage_composite_cache() created a second instance")

	renderer.queue_free()
	print("")


func test_store_registers_a_real_tile_and_is_idempotent() -> void:
	print("[2] store() allocates a slot, registers a real tile, and repeats are free\n")
	var renderer := _new_renderer()
	var cache := renderer.get_damage_composite_cache()

	var entry := cache.store("wall_1", _solid_atom(Color.RED))
	if entry.has("source_id") and entry.has("atlas_coords") and cache.size() == 1 and cache.page_count() == 1:
		_pass("first store() → source_id=%d atlas_coords=%s, 1 page" % [entry["source_id"], entry["atlas_coords"]])
	else:
		_fail("first store() did not return a well-formed entry: %s" % entry)

	if cache.has("wall_1") and cache.resolve("wall_1") == entry:
		_pass("has()/resolve() agree with the entry store() returned")
	else:
		_fail("has()/resolve() disagree with store()'s own return value")

	## Same key, different pixels — must be a pure cache hit (Part 1 owns
	## allocation only; Part 3 decides when a key is allowed to repeat).
	var repeat := cache.store("wall_1", _solid_atom(Color.BLUE))
	if repeat == entry and cache.size() == 1:
		_pass("a repeat store() with the same key is a no-op cache hit (still size 1)")
	else:
		_fail("a repeat store() re-allocated or changed the entry: %s" % repeat)

	renderer.queue_free()
	print("")


func test_two_distinct_keys_land_in_distinct_slots_with_correct_pixels() -> void:
	print("[3] Two different keys get two different slots, each with its own pixels\n")
	var renderer := _new_renderer()
	var cache := renderer.get_damage_composite_cache()

	var red_entry := cache.store("dent_a", _solid_atom(Color.RED))
	var green_entry := cache.store("dent_b", _solid_atom(Color.GREEN))

	if red_entry["atlas_coords"] != green_entry["atlas_coords"] or red_entry["source_id"] != green_entry["source_id"]:
		_pass("dent_a and dent_b resolved to distinct (source_id, atlas_coords)")
	else:
		_fail("dent_a and dent_b collided on the same slot: %s" % red_entry)

	var page: Image = cache.get_page_image(0)
	var red_px := page.get_pixel(
		red_entry["atlas_coords"].x * DamageCompositeCacheClass.ATOM_W + 1,
		red_entry["atlas_coords"].y * DamageCompositeCacheClass.ATOM_H + 1)
	var green_px := page.get_pixel(
		green_entry["atlas_coords"].x * DamageCompositeCacheClass.ATOM_W + 1,
		green_entry["atlas_coords"].y * DamageCompositeCacheClass.ATOM_H + 1)

	if red_px.is_equal_approx(Color.RED) and green_px.is_equal_approx(Color.GREEN):
		_pass("each slot's page pixels match what was stored there (no cross-slot bleed)")
	else:
		_fail("page pixels do not match: at dent_a=%s, at dent_b=%s" % [red_px, green_px])

	renderer.queue_free()
	print("")


func test_wrong_sized_image_is_rejected_without_corrupting_state() -> void:
	print("[4] A wrong-sized composite is rejected (B6-style loud fail), not silently placed\n")
	var renderer := _new_renderer()
	var cache := renderer.get_damage_composite_cache()

	var bad := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var result := cache.store("bad_size", bad)

	if result.is_empty() and not cache.has("bad_size") and cache.size() == 0 and cache.page_count() == 0:
		_pass("a %dx%d image was rejected and left the cache untouched" % [16, 16])
	else:
		_fail("a wrong-sized image was accepted or left partial state: %s" % result)

	renderer.queue_free()
	print("")


func test_page_overflow_allocates_a_second_page() -> void:
	print("[5] Filling a small page forces a second page, and slots keep resolving correctly\n")
	var renderer := _new_renderer()
	## 2 cols x 1 row = 2 slots/page — forces overflow on the 3rd distinct key
	## without allocating thousands of composites just to prove the boundary.
	var tiny_cache := DamageCompositeCacheClass.new(renderer,
		DamageCompositeCacheClass.ATOM_W * 2, DamageCompositeCacheClass.ATOM_H)

	var e1 := tiny_cache.store("k1", _solid_atom(Color.RED))
	var e2 := tiny_cache.store("k2", _solid_atom(Color.GREEN))
	if tiny_cache.page_count() == 1:
		_pass("2 keys fit on 1 page of 2 slots, as expected")
	else:
		_fail("expected 1 page for 2 keys on a 2-slot page, got %d" % tiny_cache.page_count())

	var e3 := tiny_cache.store("k3", _solid_atom(Color.BLUE))
	if tiny_cache.page_count() == 2:
		_pass("the 3rd key overflowed onto a second page")
	else:
		_fail("expected page overflow to 2 pages, got %d" % tiny_cache.page_count())

	if e1["source_id"] == e2["source_id"] and e3["source_id"] != e1["source_id"]:
		_pass("k1/k2 share page 1's source_id; k3 got page 2's distinct source_id")
	else:
		_fail("source_id assignment across the overflow boundary is wrong: %s / %s / %s" % [e1, e2, e3])

	## All three must still resolve correctly after the overflow, not just the
	## most recent page.
	if tiny_cache.resolve("k1") == e1 and tiny_cache.resolve("k2") == e2 and tiny_cache.resolve("k3") == e3:
		_pass("all 3 keys still resolve correctly after crossing the page boundary")
	else:
		_fail("a key's resolved entry drifted after the page overflow")

	renderer.queue_free()
	print("")


func test_reset_clears_everything_and_next_store_starts_fresh() -> void:
	print("[6] reset() clears bookkeeping; the next store() allocates from a clean slate\n")
	var renderer := _new_renderer()
	var cache := renderer.get_damage_composite_cache()
	cache.store("before_reset", _solid_atom(Color.RED))

	cache.reset()
	if not cache.has("before_reset") and cache.size() == 0 and cache.page_count() == 0:
		_pass("reset() cleared entries and pages")
	else:
		_fail("reset() left stale state behind")

	var fresh := cache.store("after_reset", _solid_atom(Color.GREEN))
	if fresh.get("atlas_coords") == Vector2i(0, 0) and cache.page_count() == 1:
		_pass("post-reset store() re-allocates slot (0,0) on a brand new page")
	else:
		_fail("post-reset store() did not start from a clean page: %s" % fresh)

	renderer.queue_free()
	print("")


## The real integration point (voxel_renderer.gd's prune_baked_sources()),
## not just the standalone class — this is what actually runs every
## build_from_layout() pass (room_builder.gd:716).
func test_prune_baked_sources_drives_the_reset_for_real() -> void:
	print("[7] prune_baked_sources() resets the SAME cache instance a real rebuild uses\n")
	var renderer := _new_renderer()
	var cache := renderer.get_damage_composite_cache()
	cache.store("will_be_pruned", _solid_atom(Color.RED))

	if cache.size() != 1:
		_fail("setup for this test is wrong — expected 1 entry before pruning")
		renderer.queue_free()
		print("")
		return

	renderer.prune_baked_sources()

	if cache.size() == 0 and cache.page_count() == 0:
		_pass("prune_baked_sources() reset the damage composite cache as a side effect")
	else:
		_fail("prune_baked_sources() left the damage composite cache non-empty")

	if renderer.get_damage_composite_cache() == cache:
		_pass("the cache instance itself survives a prune (only its contents reset)")
	else:
		_fail("prune_baked_sources() replaced the cache instance instead of resetting it")

	renderer.queue_free()
	print("")
