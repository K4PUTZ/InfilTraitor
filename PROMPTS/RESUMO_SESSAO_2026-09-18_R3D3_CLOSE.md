# SESSION SUMMARY — 2026-09-17 / 2026-09-18
## RENDER3D: R3D-3 steps 5, 6, 7 CLOSED — the whole stage is done

**Director's requests, in order:** *"Vamos continuar com R3D-3"* (resuming from
`RESUMO_SESSAO_2026-09-17_R3D3_PART1.md`, which left steps 5–7 open) → *"Faz o step 6 e
o step 7 nessa ordem"* → *"Investigar o step 5 em detalhe pra planejar a sessão
dedicada"* → *"Pode fazer o step 5 agora"* → *"Vamos documentar tudo o que foi feito e
encerrar a sessão."*

**Full record:** [`RENDER3D_MASTER_PLAN`](PLANNING/RENDER3D_MASTER_PLAN.md), the R3D-3
section — steps 5, 6 and 7 each have their own dated entry with the full evidence this
summary condenses.

**Environment note:** this session had a physical Moto g04s reachable over USB (adb found
at `/opt/homebrew/share/android-commandlinetools/platform-tools/adb`, not on `PATH` by
default) — every device number below is real, not simulated.

---

## Step 6 — Web export checked on the real Compatibility renderer

Re-exported `export/web`, served it locally, booted it in a real browser. `Board3DLive`
built its mesh (`Texture2DArray` + the custom spatial shader) with zero console errors:
`114120 voxel(s) → 232 quad(s)`. `MobileTesting.md` already documented that the web export
always forces the Compatibility (WebGL2) renderer regardless of `project.godot`'s
`"mobile"` setting — confirmed rather than assumed, and it's the renderer R3D-6/R3D-8's
web gate will always exercise.

**Side finding, not fixed (flagged for later):** `DevFlags` has no resolution path on Web
(no env, no filesystem for the overrides file) — no `INFILTRAITOR_*` flag, `RENDER3D`
included, can be toggled on a web build today. Verified this by temporarily editing
`room.gd`'s call-site fallback to force `RENDER3D=1` for the test, then reverting cleanly
(`git diff` came back empty) before the real export.

## Step 7 — Full Moto gate

- **Commit frame**: within budget (181/219 ms vs the 262–279 ms reference).
- **Both grenades' worst frame**: alarmingly large at first glance (2935/945 ms), but a
  same-scenario 2D control run reproduced an equally large spike (3548 ms) in the identical
  phase (`PUMP`, the prediction's own pre-production loop, unrelated to board3d) — traced to
  a pre-existing `PREDICTION_MASTER_PLAN` cost shared by both renderers, not a 3D defect.
- **Idle frame**: found the instrument already in the codebase, `FRAME_PROBE=1`
  (`room.gd`'s `_process()`) — the same source DIAG-21/23's tables always came from. 3D:
  `22.9 ms/frame · gpu 21.4 ms · 225 draws`; 2D control: `76.0 ms/frame · gpu 74.5 ms ·
  11 308 draws` — both match the reference table to the decimal.
- **Pixel-identity**: two independent cold boots, identical scenario, captured PNGs pulled
  off the device and diffed with PIL — **0 of 1 160 640 pixels differ, max channel delta 0.**

Step 7 closed with all six gate items in hand.

## Step 5 — investigated, planned, then built the same session

**Investigation** (Director asked for detail before committing to build): read
`_set_voxel_cell()`, `apply_damage_voxel_swap()`, `columns_with_structure()`,
`VoxelStore.occupancy_dict()`/`cell_index()`, and the render-time glass query surface,
file by file. Found the earlier session's "both readers are R3D-5 scope" call was too
pessimistic:
- `columns_with_structure()` (VL-D3 sun exposure) turned out to be a five-minute store swap,
  no A/B risk.
- Glass placement never read the opaque layer at all (`_glass_face_mask()` →
  `_glass_side_covered()` uses its own `_glass_seam_index`) — the glass branch inside
  `_set_voxel_cell()` needed zero changes.
- The actual blocker was narrower than first assessed: only the render-time "is glass still
  here" query (`_glass_cell_present()`) reads `_glass_layers` as its live authority — and
  skipping opaque placement doesn't require touching that at all, since R3D-6 hasn't given
  glass a 3D look yet anyway.

Landed a concrete 5-step build plan from this, then built it the same session on the
Director's go-ahead.

**Built:**
1. `columns_with_structure()` → `VoxelStore.occupancy_dict()`, filtered to
   `level >= _ground_plane_level`.
2. `VoxelRenderer.SKIP_BOARD_WRITES` auto-engages whenever `RENDER3D=1` (wired in
   `dev_flags.gd`); `RENDER3D_2D_BUILD=1` forces the old build back on for an A/B in the
   same binary.
3. Guarded every opaque-placement call site, glass routed around each guard: the dirty-
   reprocess path (`_process_dirty_slice_voxel()`, `_process_dirty_slab_voxel()`) **and** —
   found only by actually profiling the load, not assumed from the plan text — a completely
   separate INITIAL-BUILD path (`_render_slice()`, `render_slab()`, `render_slab_solid()`,
   `render_fixed_earth_level()`, `render_block()`, `_render_junction_column()`) that
   `process_dirty()` never touches at all. Gave `voxel_destroyed`'s tile-backed idempotence
   check a tile-free equivalent (`_render3d_gone_cells`), so the 2026-08-19 double-VFX bug
   class stays impossible under `RENDER3D` too.
4. `apply_light_field()`'s full/initial pass got a store-backed counterpart,
   `_apply_light_field_pass_store()` — without it Board3DLive's first load would have read
   empty cell planes, since the existing `SKIP_BOARD_WRITES` branch in
   `apply_light_field_cells()` only ever ran off an incremental stale set.

**A real bug, found and fixed before closing.** The first version moved each guard's
early-return *before* that function's `_ensure_layer()`/`_ensure_voxel_layers()` call.
`DetonationPlanBuilder._resolve_damaged_tile()` — the render-neutral plan's own resolve-only
seam, still load-bearing because R3D-2's plan-entry rekey was explicitly deferred — calls
`_set_voxel_cell()` directly, bypassing every guarded wrapper, and needs the layer node to
exist even though it never writes to it. This reproduced **deterministically** on the Moto:
two separate live-detonation runs both closed with `WARNING: ObjectDB instances leaked at
exit` and `ERROR: 3 resources still in use at exit`. Root-caused on **desktop** with
`--verbose` in minutes (much faster than iterating on-device): `VoxelRenderer._set_voxel_cell:
level 79 has no layer` immediately followed by `SCRIPT ERROR: Invalid access to property or
key 'source_id' on a base object of type 'Dictionary'` at
`detonation_plan_builder.gd:2178`, aborting a cook phase mid-execution and leaving state
partially built. **Fix:** `_ensure_layer()`/`_ensure_voxel_layers()` now always run first,
unconditionally, in all six guarded functions — only the per-voxel cell write is skippable.
Re-verified clean: 0 script errors/leak lines on desktop `--verbose`, 0 on the Moto across
two repeat detonation runs, 57/57 selftests, invariants clean.

**Moto evidence (PLAYGROUND, `NO_BAKE=1`):**
- The 2D board drops from 151 240 cells to 64 (glass residue only — expected, not a miss).
- The 3D mesh is byte-for-byte identical either way (108 772 faces → 367 quads, 72 chunks);
  `BoardProbe` diffs 0 real differences (the only diff is 6 cosmetically-empty plane levels,
  72–77, that neither the old nor the new Board3DLive mesh has ever read).
- **The real win lives in the segment BEFORE `VOXEL-STORE built`, not after it** — this
  session's own step 7 write-up had guessed wrong about where the ~15 s gap was. Measured:
  `DevFlags`-read → `VOXEL-STORE built` drops from ~11.0 s to ~4.4 s. That segment is
  `_room_builder.build_from_layout()`, which runs the initial-build functions this step
  guards, *before* the voxel store even exists. The segment after `VOXEL-STORE built`
  (~15 s either way) is the full light/soot apply pass — real cost, but out of this step's
  scope, flagged as a future perf target.
- Total `DevFlags`-to-3D-ready time: ~19.8 s (skip) vs ~26.1 s (forced old) — a real
  ~24% cut for this map.
- Two live detonations with glass mechanics exercised, clean after the fix.

## R3D-3 — fully closed

All 7 steps built, measured, and verified: relocate out of `spikes/`, vertical scale
ratified, chunk size, threaded remesh, web export checked, hidden 2D board skipped, full
device gate. **Next: R3D-4 and R3D-5 can run in either order** (the master plan's own
dependency graph, §5).

## Housekeeping

Cleaned up the device between measurement runs (removed the test `dev_flags.cfg` each time
a probe finished) so nothing test-only was left active for the Director's next manual
session. Several intermediate device logs from this session live under
`docs/measurements/device_2026-09-1{7,8}_moto_g04s_r3d3_*.log` (gitignored, local only).

## Next session

R3D-3 needs nothing further. Pick up `RENDER3D_MASTER_PLAN`'s R3D-4 (actors/props/VFX in
depth) or R3D-5 (overlays, picking, the floor layer) — either order is fine per the
dependency graph; no staged plan is pre-approved for either yet, so the first move is the
same kind of scoping investigation this session did for step 5 before touching code.
