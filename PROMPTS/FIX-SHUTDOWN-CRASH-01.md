# FIX-SHUTDOWN-CRASH-01: Engine.set_meta Pseudo-Singletons Crash on Quit — Convert to Real Autoloads

**Status:** Ready for implementation
**Severity:** Critical — crashes (SIGABRT) on every game close, confirmed via macOS crash report, not a cosmetic bug.
**Predecessor:** none specific — this is a pre-existing defect, confirmed present since at least 2026-07-05 20:12 (before FIX-VOXEL-HEIGHT-01/FIX-EXTERIOR-WALLS-01 existed), made universal (every session, not just some) once `BAKE-LIVE-BOOT-01` started populating the same pattern at real game boot.
**Scope:** Replace `Engine.set_meta()`-based pseudo-singletons (`GLOBAL_MATERIAL_REGISTRY`, `GLOBAL_PROP_REGISTRY`, and the bake-atlas globals) with real Godot autoloads. No behavior change for gameplay — this is a lifecycle/cleanup-ordering fix only.
**Effort:** ~2 hours
**Risk:** Medium — touches how several systems obtain their shared registry instance; must verify every read site still resolves correctly after the change

---

## Item 0 — Ground truth: the crash, confirmed root cause

macOS crash reports (`~/Library/Logs/DiagnosticReports/Godot-2026-07-06-164511.ips` and an earlier, identical-signature one from `2026-07-05-201225.ips`) both show:

```
SIGABRT — abort() called
std::__1::recursive_mutex::lock() → throws system_error → uncaught → terminate → abort
  called from: GDScript::UpdatableFuncPtr::~UpdatableFuncPtr()
  called from: Callable::~Callable() → GDScriptInstance::~GDScriptInstance() → Object::_predelete()
  ...repeated several times (nested Dictionary/Variant cleanup)...
  called from: GDScript::clear() → GDScriptLanguage::finish() → ScriptServer::finish_languages() → Main::cleanup()
```

This is the well-known Godot 4.x footgun: objects stored via `Engine.set_meta()` are held in a table that survives past normal scene-tree teardown and gets cleared during `Main::cleanup()`, **after** `ScriptServer::finish_languages()` has already begun tearing down GDScript classes/instances. If the stored object is itself a GDScript `RefCounted` instance (not a primitive), its destructor runs during this window and can hit a `recursive_mutex` that the script language server has already begun dismantling — hence the abort.

**Confirmed present since before this session's work** — the earlier crash (07-05 20:12) predates `FIX-VOXEL-HEIGHT-01`/`FIX-EXTERIOR-WALLS-01` entirely; `GLOBAL_PROP_REGISTRY` (`room_builder.gd:343-347`, from `PROP-01`) is old enough to be the original trigger. `BAKE-LIVE-BOOT-01` widened the blast radius by adding `GLOBAL_MATERIAL_REGISTRY` at real game boot (`room.gd:371-374`), so a crash that may have been intermittent (dependent on whether a map had props) became universal (every real play session populates `MaterialRegistry` at `_ready()` now).

### Every call site storing a script instance via `Engine.set_meta` (found by grep, verify none were missed)

```
room.gd:374                    Engine.set_meta("GLOBAL_MATERIAL_REGISTRY", material_registry)
room_builder.gd:220-222        Engine.set_meta("GLOBAL_BAKED_ATLAS"/"BAKED_ATLAS_SOURCE_IDS"/"BAKE_TIMESTAMP", ...)
room_builder.gd:347            Engine.set_meta("GLOBAL_PROP_REGISTRY", reg)
```

Read sites (must all keep working after the fix): `bake_compositor.gd:339-352`, `baked_tile_lookup.gd:154-170`, `theme_applier.gd:26-27` (`WALL_TILEMAPS`, a fourth meta key not yet accounted for above — check what sets it, it wasn't in the `set_meta` grep results above, meaning it might be set from a `Dictionary`/primitive rather than a script instance, or set somewhere the grep pattern missed; confirm before deciding whether it needs the same fix), `debug/theme_matrix_debug_view.gd:17-18`.

**Test scripts also use this pattern** (`BAKE_TEST_REGISTRY` and others, self-managed with their own `set_meta`/`remove_meta` cleanup) — these are short-lived headless script runs, not full windowed sessions with the same `Main::cleanup()` shutdown path exposure; **leave test-owned metas alone** unless Item 2's verification shows they're also affected.

---

## Item 1 — Convert `MaterialRegistry` and `PropRegistry` to real autoloads

These two are the ones confirmed active in every normal play session (registry population is unconditional — it doesn't depend on `BakeConfig.enabled`). Fix these first; they're the confirmed, reproducible cause.

**Naming collision to resolve carefully:** `MaterialRegistry` and `PropRegistry` are currently `class_name`-declared `RefCounted` scripts. A Godot autoload registered under the same name would collide with the existing global class identifier. Options (pick based on what's cleanest, verify it actually resolves in the editor before committing):

- (a) Keep `MaterialRegistry`/`PropRegistry` as-is (the data/logic classes), and create a thin `Node`-based autoload with a **different** name (e.g. `Registries` or `GameRegistries`) that holds `material_registry`/`prop_registry` as properties, populated in its own `_ready()`. Consumers change from `Engine.get_meta("GLOBAL_MATERIAL_REGISTRY")` to `Registries.material_registry` (or via `get_node("/root/Registries")` if autoload isn't globally addressable in the calling context — GDScript autoloads registered in `project.godot` *are* globally addressable by name from any script, same as any other global class, so direct reference should work).
- (b) Rename the existing classes (e.g. `MaterialRegistryData`) and let the autoload itself be named `MaterialRegistry`/`PropRegistry`, exposing the same public methods (`get_material()`, `register()`, etc.) by delegating to an internal instance, so call sites barely change (`MaterialRegistry.get_material(id)` still reads naturally).

Prefer (a) — smaller diff, doesn't rename a class referenced in tests/docs throughout the codebase. But verify: do any existing tests do `preload(".../material_registry.gd").new()` and expect a **fresh, isolated** instance (not the shared autoload)? Several test files do exactly this (`bake_compositor_test.gd:53` calls `material_registry.register_defaults()` on a locally-created instance) — **this must keep working**, autoloads don't replace the ability to instantiate the class directly for isolated tests. Confirm the class itself stays instantiable via `.new()` regardless of which naming option you pick.

**`project.godot` addition:**
```ini
[autoload]
Registries="res://godot/scripts/systems/registries_autoload.gd"
```

(or whatever final name/path Item 1 settles on).

**`room.gd:_ready()`:** replace the `Engine.set_meta("GLOBAL_MATERIAL_REGISTRY", ...)` block with a call into the autoload (e.g. `Registries.ensure_material_registry()` or simply reading `Registries.material_registry` if the autoload's own `_ready()` already populates it — decide which side owns the `register_defaults()` call and don't have both room.gd and the autoload doing it redundantly).

**`room_builder.gd:_get_prop_registry()`:** same change — delegate to the autoload instead of `Engine.get_meta`/`Engine.set_meta`.

**All read sites** (`bake_compositor.gd`, `baked_tile_lookup.gd`, `theme_matrix_debug_view.gd`): update to read from the autoload.

## Item 2 — Verify the crash is actually gone (not just plausible)

This is the part that actually matters — a plausible-sounding fix for a rare crash needs real reproduction evidence, not just "should work now":

1. Run the actual windowed game (not headless), load a map with props (PLAYGROUND), let it sit a moment, close the window normally.
2. Confirm no crash report appears in `~/Library/Logs/DiagnosticReports/Godot-*.ips` with a timestamp after your fix.
3. Do this at least 3 times in a row (the original crash was consistent, not flaky, but 3 clean closes is minimal real confidence, not proof by one lucky run).
4. If it still crashes, check whether the bake-atlas globals (`GLOBAL_BAKED_ATLAS` etc., Item 0's third group) are the actual remaining cause — test with `BakeConfig.enabled = true` (via `user://bake_config.cfg`) specifically, since those only populate when baking runs. If so, apply the same autoload conversion to those and re-verify.

## Item 3 — Confirm nothing else regressed

- `bake_selftest.gd` and any other test that relies on `Engine.set_meta("GLOBAL_MATERIAL_REGISTRY", ...)`/`BAKE_TEST_REGISTRY` for test isolation must still pass unchanged — these are short-lived script runs and were explicitly left alone (Item 0), but confirm the autoload's mere existence (even if unused by the test) doesn't interfere (e.g. a test that does `Engine.remove_meta("GLOBAL_MATERIAL_REGISTRY")` expecting `_get_material_registry()` to fall through to a fresh dummy registry — if that fallback logic in `bake_compositor.gd:_get_material_registry()` still checks `Engine.has_meta(...)` first, and nothing sets that meta key anymore, confirm the fallback chain (`GLOBAL_MATERIAL_REGISTRY` meta → `BAKE_TEST_REGISTRY` meta → dummy) still makes sense, or update it to check the autoload instead of the now-unused meta key).

---

## Acceptance Criteria (assertion-backed, real execution evidence only)

1. **Root cause identified and cited**: report quotes the actual crash log frames (not paraphrased) and names the specific `Engine.set_meta` call sites responsible.
2. **Autoload registered and resolves**: `project.godot` diff shown; confirm via real run that the autoload initializes (print/log its `_ready()`) before any registry consumer needs it.
3. **All read/write sites migrated**: grep confirms zero remaining `Engine.set_meta`/`get_meta` calls for `GLOBAL_MATERIAL_REGISTRY`/`GLOBAL_PROP_REGISTRY` in non-test code.
4. **Crash reproduction, before and after**: confirm the crash reproduced on the pre-fix build (if not already obvious from the existing crash logs, one deliberate repro is enough — don't need to hunt for more), then confirm 3 clean closes post-fix, per Item 2.
5. **Isolated test instantiation still works**: existing tests that do `MaterialRegistry.new()`/`PropRegistry.new()` directly (not via the autoload) still pass unchanged — paste their output.
6. **`check_invariants.py` / `map_lint.gd` / `bake_selftest.gd`**: clean, verbatim.
7. **If bake-atlas globals also needed the same fix** (Item 2.4): documented explicitly, with the same before/after crash evidence.

---

## Explicitly out of scope

- Converting `BAKE_TEST_REGISTRY` or other test-owned, self-cleaning `Engine.set_meta` usages — those are short-lived script contexts, different risk profile, leave alone unless Item 2 proves otherwise.
- Any gameplay/rendering behavior change — this prompt is purely about object lifecycle at shutdown.

---

*End FIX-SHUTDOWN-CRASH-01 prompt.*
