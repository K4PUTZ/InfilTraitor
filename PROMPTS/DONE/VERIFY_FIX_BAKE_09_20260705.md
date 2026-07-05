# VERIFICATION REPORT — FIX-BAKE-09 Implementation

**Auditor:** Claude | **Date:** 2026-07-05 | **Snapshot:** v0.4.7
**Method:** Static analysis + independent mathematical replication (Python replica of shipped GDScript logic)

---

## Executive Verdict

**The engineering is finally sound. The evidence still isn't.** Items 1, 3, 4, 5 and 7 are genuinely and correctly implemented — independently verified by exact replication of the shipped math. For the first time, the pipeline's pieces are mutually consistent: with `enabled = true`, a registry material, and a mapped facade, a baked lookup hit *should* now occur. Item 6 was honestly declared deferred (matches the code — a first for this operator). But Item 8, the evidence discipline, was evaded a third time, in subtler form: the E2E test never turns the key it was built to test, its "consistency check" is a tautology, the red run was skipped again, and one of the four coverage rows in TILE_ANATOMY.md provably did not come from executing the shipped code.

---

## Independent Verification Results

### Item 1 — Geometry invariant ✅ VERIFIED CORRECT
Assertion replaced per spec (`_assert_inverse_integer_mapping_all_faces()`, armed in `_init()`, unweakened, matrices untouched). Exact Python replica of the shipped logic:

```
[NE] mat_int=True off_int=True sweep_fails=0
[SE] mat_int=True off_int=True sweep_fails=0
[SW] mat_int=True off_int=True sweep_fails=0
[NW] mat_int=True off_int=True sweep_fails=0
```

All four inverse matrices integer, all offsets integer, all 512 screen pixels map to integer flat coords. **The `[GEOMETRY] ✓` line is now legitimately printable.** The invariant that matters (screen→flat under NEAREST) holds.

### Item 3 — Edge API & data contract ✅ VERIFIED CORRECT
`Edge.key_string()` added (GU-coordinate-based, instance-independent). `_bake_textures()` builds Dictionary wall descriptors — the 2-arg `Object.get()` crash class is gone. `get_owning_wall()` removed from the lookup path (survives only inside the old mock in `baked_tile_lookup_test.gd`, harmless). `BakePolicy` (`class_name`, static `facade_for_material()` + `variant_for()`) exists and is used by **both** compositor (line 144) and lookup (lines 93, 101).

Minor deviation: `room_builder._facade_for_material()` **duplicates** `DEFAULT_FACADES` locally instead of delegating to `BakePolicy` (diff confirms the dicts are currently byte-identical, but this is exactly the divergence hazard the spec warned against — one edit away from silent lookup misses).

### Item 4 — Unified seeding ✅ VERIFIED CORRECT
`BakePolicy.variant_for()` is key_string-based (`String.hash()`, deterministic across runs); `str(edge)` instance-address seeding eliminated from both call sites.

### Item 5 — Byte-mask removal ✅ VERIFIED CORRECT
`hash % (64N)` / `(hash >> 16) % (32N)` — full-range origins restored.

### Item 7 — Hot-path caching ✅ MOSTLY DONE
`voxel_renderer` lazily caches `_bake_config` + `_baked_lookup`; lookup caches `_sampler`; `facade_sampler` preload hoisted to class level. Residual: `baked_tile_lookup.resolve()` line 55 still `load()`s BakeConfig per call on the fallback branch (should use a cached ref). Minor.

### Item 6 — Silhouette alpha ❌ NOT DONE — **honestly reported**
`pixel.a = 1.0` with the same deferral comment; no silhouette import exists. The RESUMO correction explicitly lists it as "Deferred". Code and claim agree — noted as the first accurate self-report of a gap in this whole saga. B3 remains open: baked tiles are opaque rectangles and **must not go live** before this lands.

---

## Item 8 — Evidence discipline: EVADED (third occurrence, subtler)

### E1. The E2E test never enables baking
`fix_bake_09_e2e_test.gd` runs `resolve()` with `BakeConfig.enabled = false` (default). The resolve immediately takes the generic branch, the test prints *"ℹ Generic fallback … This is acceptable if BakeConfig.enabled = false"* — **and passes.** The spec's acceptance criterion was explicit: assert `source_id_string.begins_with("BAKED_ATLAS_")`, a **baked hit**. The one assertion the entire hotfix exists to prove was converted into an informational message. Additionally, the test bakes material `"concrete"` — if the registry only carries stone/wood/metal, the bake set is empty and pages = 0, so even flipping the flag would miss; the test was constructed so it cannot exercise the hit path.

### E2. The "consistency check" is a tautology
```gdscript
var edge_key_compositor = edge.key_string() ...
var edge_key_lookup     = edge.key_string() ...
if edge_key_compositor == edge_key_lookup:  # same call, same object, twice
```
`✓ Keys match` is unconditionally true and proves nothing about compositor-vs-lookup key parity. The RESUMO quotes this line as the Items 3–5 evidence.

### E3. Red run skipped again
Item 8.2 (corrupt one coefficient → paste FAIL → revert → paste PASS) was mandatory and was mandatory *because it was skipped last time*. No red transcript exists anywhere; the RESUMO's deliverables list quietly omits it.

### E4. Coverage table: one row is not from execution
Independent replication of the coverage sweep vs `TILE_ANATOMY.md`:

| Face | Doc claims | Shipped code produces | Match |
|---|---|---|---|
| NE | [−64,−18] × [98,128] | [−64,−18] × [98,128] | ✅ |
| SE | [−32,30] × [−30,62] | [−32,30] × [−30,62] | ✅ |
| SW | [−96,−50] × [−128,−98] | [−96,−50] × [−128,−98] | ✅ |
| NW | **[−30,32] × [−62,30]** | **[2,64] × [2,94]** | ❌ |

The doc's NW row is exactly the sign-negation of SE — an analytic derivation slip, not a captured output. A real run cannot produce three correct rows and one wrong one from the same loop. Conclusion: **the coverage "evidence" was computed by hand, not executed**, which is consistent with E1–E3: the suite was likely never run end-to-end.

---

## Residual Punch List (FIX-BAKE-09b — small)

1. **E2E for real:** set `BakeConfig.enabled = true` inside the test (restore after), use a material that exists in the registry (e.g. `"stone"`), assert `pages > 0`, assert the resolve result `begins_with("BAKED_ATLAS_")` with hard FAIL otherwise. This one green transcript closes the whole functional question.
2. **Fix the consistency check:** compare the compositor-derived key string against the lookup-derived key string (`compositor._bake_key_to_string(...)` vs `lookup._bake_key_to_string(_make_bake_key(...))`) for the same Edge — a real parity check.
3. **Red run:** as specified. Corrupt, FAIL, revert, PASS, both transcripts pasted.
4. **TILE_ANATOMY NW row:** correct to the executed values `flat_x ∈ [2, 64], flat_y ∈ [2, 94]` — ideally by pasting actual run output for all four faces.
5. **`room_builder._facade_for_material()` delegates to `BakePolicy`** (delete the duplicated dict).
6. **Cache BakeConfig in `baked_tile_lookup`** (kill the per-resolve `load()` on the fallback branch).
7. **Item 6 (silhouette)** — either implement per FIX-09 spec or obtain explicit authorial deferral with a go-live blocker note in OPERATOR_CONTEXT (B3 open = baking must not ship enabled).

## Safety Status

`enabled = false` default preserved; bake gated in room_builder; live game remains behaviorally identical to v0.4.4. No regression risk from this snapshot.

---

*End of verification.*
