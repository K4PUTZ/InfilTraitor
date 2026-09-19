# SESSION SUMMARY — 2026-09-18
## RENDER3D: R3D-4 (actors, props, in-world VFX) and R3D-5 (ground overlays, fog, picking) BUILT

**Director's requests, in order:** *"Vamos continuar com R3D-4"* → *"Pode começar pelo R3D-4a, spike A vs B"* → *"Segue pelos quatro em ordem"* (bias sweep, lint, Moto, commit) → *"Ratifico o A, segue para o R3D-4b"* → *"Ratifico o agente 3D, segue para o R3D-4c"* → *"Ratifico o look, segue para o R3D-4d"* → the overlay-over-grenade note: *"Queremos a engine 100% rodando mais leve… mantenha o foco na qualidade do sistema"* → the real-3D-objects question, parked → *"Sim, segue para o 4e"* → *"Sem condições de ficar por cima do muro. Podemos fazer agora ou depois, mas deixa registrado como pendente"* → *"Pode planejar a ordem e as etapas conforme achar mais conveniente"* → *"Pode seguir com o 5b"*, *"…5c"*, *"…5a"* → *"Vamos documentar tudo… e encerrar a sessão."*

**Full record:** [`RENDER3D_MASTER_PLAN`](PLANNING/RENDER3D_MASTER_PLAN.md) — the status block and register of open items at its top, §R3D-4, §R3D-5 (with the decision table), and revision v1.7. Measurements: `docs/measurements/device_2026-09-18_moto_g04s_*` (local; Moto g04s over USB for most of the session).

**Environment note:** `adb` is at `/opt/homebrew/share/android-commandlinetools/platform-tools/adb`. The device was reachable until R3D-5a; at the end there was no device, so the pick check on the Moto was not run.

---

## What was built (commits `ad60daf2` … `414f9d7f`)

| stage | what | evidence |
|---|---|---|
| **R3D-4a** | spike `SPIKE=r3d4a`: billboard (A) vs depth-composited sprite (B) on a wall/glass/roof/column fixture | A and B agree except glass (only A tints); Moto: none 21.8 ms, A 22.2, **B 31.7**; B's depth pass decoded 0.235 u off on the Mali. **Director ratified A.** |
| **R3D-4b** | `ActorBillboard3D` + `actor_billboard3d.gdshader` (D17 relight, spatial); the agent | camera-parallel quad failed live (glass tinted the hat, floor cut the shoes) → **world-vertical quad**, 1/cos30° stretch, 0.15 lift; Moto +0.2 ms; relight moved to `actor_relight.gdshaderinc`, actor pixel-identical after |
| **R3D-4c** | guards + `VisionCone3D` (the guard publishes its own polygon) | Moto +0.2 ms; `Room._attach_actor_billboards()` idempotent across reloads |
| **R3D-4d** | `PropBillboard3D`: grenade (flight, tumble, ground shadow), floating collectible (outline shader) | 2D hidden by material swap, not `visible` (game uses it as logic); Moto +0.4 ms |
| **R3D-4e** | in-world VFX in world space: `ParticleMath`, `CircleField3D`/`QuadField3D`/`ShardField3D` | wall-face capture clean; selftest 0.0005 px; **Moto detonation 30.2 vs 32.3 ms**; empty MultiMeshes hidden (+6 draws found) |
| **R3D-5b** | `GroundCanvas3D` + 8 overlays on the ground; decision table (45 scripts) | selftest 0.005 px; movement outline no longer cuts the agent; **dark "roof tops" and GU grid across block faces fixed** |
| **R3D-5c** | fog of war (`draw_polygon` per-vertex colours), layering = 2D z-order | luminance 76.4 vs 74.8 |
| **R3D-5a** | `Board3DLive.pick_cell`, `GroundGrid` (lattice without a TileMapLayer) | `PICK_CHECK` 35 840 points / 16 framings, 0 disagreements; 41 calls replaced, 0 px moved outside noise |

Verification at close: `project_lint.py` clean, **60 selftests clean** (57 → 60: `particle_space`, `ground_canvas3d`, `ground_grid`), `check_invariants.py` clean, CODEMAP current.

## Found on the way (worth knowing)

1. **Rule 9, again, silently.** The VFX asked for the floor under a voxel with `voxel_world_position(grid, 0)`. Level 0 died at the renumber → `Vector2.ZERO` → every caller fell back: **330 of 330**. Fixed in four sites with `ground_plane_level()`. Side effect, intended by the original design: the 2D dust falls to the floor again.
2. **Under `RENDER3D=1` the 2D glass rain never drew** (child of the hidden `_voxel_renderer`), and the crack sprite still draws nothing (0 of 921 600 px differ). The rain now draws in 3D; the crack is an R3D-6 item.
3. **An unrequested `.replace()` that silently did nothing** cost two debug loops (a missing `flush()`, a floor level). Every scripted edit after that asserts its match.
4. **An "unlit" control must be designed, not assumed:** the first "behind the wall" test hid nothing because at a 30° view a particle 1 unit high just behind a 2-unit wall clears it. The valid controls are in the plan.
5. **Measure before blaming:** a 2 100 px capture noise (flickering lights) made a 37 px diff meaningless until a same-code control was run.

## Rulings and decisions recorded

- **R3D-4e was ruled blocking** ("sem condições de ficar por cima do muro") — built, gate passed.
- **Delegated:** the order and steps of the rest (4e → 5b → 5a → 5c, then 5c/5a swapped in practice: 5b, 5c, 5a).
- **Focus:** engine weight and system quality first, cosmetics later; the Moto not run at every step (memory: `r3d-focus-system-quality-not-cosmetics`).
- **Parked** ("investigate at the end of R3D"): real 3D objects (GLB) in the scene — needs a spike (light from the board's planes, Moto cost) and the Director's call on the D35/D42/D44 direction.
- **Stay in screen space by decision:** aim dome, throw arc, shrapnel preview, tracer, noise icons, cursor.

## Open items (also the register at the top of the plan)

- `AgentProbeProp` and the collectible have no production instance (`TEST_ZONE_COLLECTIBLES_ENABLED = false`, empty probe bracket); the collectible was verified with the constant flipped locally; the probe path has no capture.
- Muzzle-flash floor is an estimate (`muzzle_floor_drop_px = 96`); shrapnel has no capture of its own.
- **`floor_layer` is not retired** — it owns tile data (walkable, used cells, `set_cell`); retires with the 2D board at R3D-8.
- **Wall picking by ray** not built: needs the Director's call (select the wall's cell or the floor behind it, as today?).
- **Not run on the Moto:** the R3D-5a pick check and touch/pinch/pan through TEL; R3D-5b/5c cost.
- **Not from these stages:** the detonation's worst frame is ~1 s in both 2D and 3D VFX (light/consequence cost) — a future perf target.
- The 2D overlay nodes still exist and their `_draw()` publishes the 3D frame; they retire with the 2D board (R3D-8). Rotation (R3D-9) must re-derive VFX anchors per view.

## Housekeeping

`docs/production/current_state.md` has uncommitted changes from BEFORE this session and was left untouched. Dev seams added (all `DevFlags`): `SPIKE=r3d4a`, `R3D4A_BENCH`, `ACTORS3D`, `ACTORS3D_BIAS`, `VFX3D`, `GROUND3D`, `PICK3D`, `PICK_CHECK`, `SEED_GRENADES`. Test flags were removed from the handset after every run.

## Next session

Open **R3D-6 (look parity)**: each item behind a flag until the Director ratifies it from paired Moto captures — the glass look and the crack (moved here), the 3D cone's saturation vs the 2D, the flight shadow, light rays. Then **R3D-7** (the 3D cutaway; the glass roof over the agent on GLASS is its first visible case). Before or alongside: put the Moto back on USB and run the pending pick/touch/overlay checks.
