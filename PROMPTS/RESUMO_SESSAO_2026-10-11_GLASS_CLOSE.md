# Session summary — 2026-10-11 (afternoon): the glass optimised on both handsets; the glass track CLOSED

Continues `PROMPTS/RESUMO_SESSAO_2026-10-11_GLASS_DEVICE_OPT.md`. Detail: `PROMPTS/PLANNING/GLASS_MASTER_PLAN.md` 1h-1k and its top block.

## 1. Numbers (GLASS `glass_blast` take, release APK, uncapped, two runs each)
| | Moto g04s worst frames (ms) | Galaxy A16 worst frames (ms) |
|---|---|---|
| session start (morning) | 679 / 430 / 343 / 277 | — |
| round 3 (rain as a job) | 200 / 185 / 182 / 178 | — |
| round 4 (collapse frame) | 182-200, the collapse out of the top list (211 -> ~106) | — |
| round 5 (blast glass tail) | ~183 | 465-487 (first measurement) |
| flash snapshot on the GPU | **184-191** | **144-171** |

## 2. What was built (commits on `main`)
- `e22bcdfd` — the collapse frame: opening masks cached per (opening, size) in `GlassCrackMirror3D`; the presenter's leftover queue drained at 16 ms a frame; the blast's dirty flags dropped in the persistence's FIRST step; the collapse's board commit a frame after its dirty pass.
- `8561d4dc` — the blast's glass tail 102 -> 70 ms: the second full remesh removed (the mesher reads only the store); the region walk with a static neighbour table; only the cracks an erase touched rebuilt.
- `b573605f` — the negative flash's snapshot is a texture copy on the GPU (`RenderingDevice.texture_copy` -> `Texture2DRD`, 0.2 ms; the readback stalled ~360 ms on the Galaxy's first blast), readback kept as fallback; flash warmed at map load.
- `003c7733` — the crossfade softened: eight smoothstep steps.

## 3. Proofs
`verify.py` smoke PASSED after each round (selftests clean). Desktop take frame hashes vs the code before: collapse one frame later (same picture, side by side); the remesh removal changes only transient sparks / shard glints (last frame identical); the region walk, the crack occupancy and the GPU snapshot change 0 frames (904 identical, the copy path confirmed running).

## 4. Method worth keeping
Attribute a frame by marking script steps against `RenderingServer.frame_post_draw` and the viewport's measured GPU time: the collapse frame's 177 ms was 40 ms of collapse code + 30 ms GPU, the rest a `_process` (the opening masks). A diagnostic readback itself stalls: never leave one in a measured run.

## 5. Open (none blocking)
`hit_stop_frame_budget_us` (Director's call), COMMIT `damage`/`crazes`, the Galaxy first-blast readback stall's root cause, glass roofs (G-D53), `plastic`, S-4 art.
