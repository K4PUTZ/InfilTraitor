# SESSION SUMMARY — 2026-09-17
## RENDER3D: R3D-2 CLOSED, R3D-3 steps 1-4 of 7 CLOSED — Board3DLive is production code

**Director's requests, in order:** *"Vamos seguir com o R3D-3."* (after R3D-2 closed
earlier the same session — see `RESUMO_SESSAO_2026-09-17_R3D2.md`), then two look-call/
measurement decisions along the way, then *"Por enquanto deixa assim. Vamos documentar
tudo que foi feito e encerrar a sessão."*

**Full record:** [`RENDER3D_MASTER_PLAN`](PLANNING/RENDER3D_MASTER_PLAN.md), the R3D-3
section and its progress note.

---

## What R3D-3 found before any code moved

`godot/scripts/spikes/board3d_live.gd` was already far more built than the master plan's
own text implied: store-based geometry (no per-load dictionary), faces already merged by
material, light/soot already sampled per voxel from `CellPlaneStore` in a real spatial
shader, camera already orthographic at D26's 30°/45°. What was actually missing: it lived
in `spikes/`, had no chunk-size measurement, no threaded remesh, still built the hidden 2D
board unconditionally, and had never been checked against the web export.

## Step 1 — Relocated to production (commit `9ed0f809`)

`board3d_live.gd` (+ `.uid`) moved from `spikes/` to `geometry/`, alongside
`voxel_renderer.gd`. One preload site in `room.gd` updated. No behavioural change —
verified with a real PLAYGROUND `RENDER3D=1` detonation and `board_probe.py gate`.

## Step 2 — Vertical scale ratified (commit `642a2d9f`)

Built the A/B mechanism (`VERTICAL_SCALE`, applied only to a new `_geometry_root` child
node so the camera stays unaffected) and a dev-only one-storey marker standing in for the
baked agent (not wired into the 3D scene yet — flagged to the Director rather than
building a fuller stand-in without asking). Captured both variants, showed the Director.
**Ratified: the true-cube default, `VERTICAL_SCALE = 1.0`** — *"as duas versões estão
baixas, se considerarmos o chapéu... vamos trabalhar de novo no modelo... usa o valor mais
inteiro, que facilita o cálculo."*

## Step 3 — Chunk size measured (commit `a54b804a`)

`CHUNK_VOXELS` became a `DevFlags`-overridable var. Measured on the Moto g04s (real
PLAYGROUND load + both grenades): initial load is a wash either way, but a blast's
remesh — the part that stalls the main thread before step 4 threaded it — dropped from
108.4/104.4 ms (32) to 38.9/0.2 ms (16). **16 wins**, now the default.

## Step 4 — Remesh threaded (commit `73fa10dc`)

Split `_build_chunk()` into a pure-data `_collect_and_merge_chunk()` (safe off the main
thread — `SurfaceData` is a plain GDScript class of `Packed*Array`s, not a `Resource`) and
a main-thread-only `_commit_chunk_mesh()`. `_remesh()` now queues a `WorkerThreadPool`
task; `_process()` polls for completion. Only one task in flight ever — a request that
arrives mid-task coalesces into a queue rather than starting a second concurrent reader of
`_store`. `_exit_tree()` waits out any in-flight task before the node can be freed.

**Found and fixed a self-inflicted measurement bug before trusting the Moto numbers:** the
first pass measured "merge" as wall-clock from task start to main-thread detection, which
conflated real background compute time with however long a busy main thread took to
poll — this scene's own smoke/ember consequence effects already run 100–500 ms/frame
independent of board3d, so an idle poll delay briefly read as an 1100 ms merge. Fixed by
timing merge inside the task itself and reporting `poll-latency`/`background` separately.
Also fixed a real bug the same Moto run surfaced: `CHUNK_VOXELS`'s `DevFlags` fallback
string still said `"32"` despite step 3's default flip to 16.

**Clean Moto numbers after the fix:** the background work itself is cheap — 30.6 ms then
0.5 ms across both PLAYGROUND grenades — against the old synchronous path's 108.4/104.4 ms
(chunk 32) or 38.9/0.2 ms (chunk 16) added IN-LINE to whichever frame ran it. Quad/voxel
counts matched step 3's pre-threading numbers exactly on both desktop and Moto —
geometric correctness unchanged by the threading move.

## A curiosity, flagged and parked

The Director asked whether a hidden detonation during load could pre-warm whatever the
first real one pays for cold — the same trick this project already uses for the 2D
board's TileSet alternative cache during the aim window. For the 3D board the analogous
cold cost is shader compilation on first `ShaderMaterial` use (invisible in headless
captures, real on device GPU). Not measured this session; parked in the master plan as an
idea for whenever first-detonation cost becomes visible enough to be worth chasing.

## What's left in R3D-3 (3 of 7 steps)

- **Step 5** — stop building the hidden 2D board when the 3D board is on (today only its
  visibility is toggled; the tile placement still runs).
- **Step 6** — check the web export boots the 3D board (`Texture2DArray`, the custom
  spatial shader).
- **Step 7** — the full Moto gate: idle frame vs 22.9 ms, commit frame vs 262–279 ms, both
  grenades' worst frame, load time/memory, 3D run-a/run-b at 0 px, web export.

## Housekeeping

`godot/scripts/systems/cell_plane_store.gd.uid` (from R3D-2 step 3, two sessions ago) had
never been committed — caught and added this session before closing.

## Next session

Resume at R3D-3 step 5. The approved staged plan is still current — see the plan file
referenced in this session's transcript if it's still on disk, otherwise re-derive from
this summary and the master plan's own step list.
