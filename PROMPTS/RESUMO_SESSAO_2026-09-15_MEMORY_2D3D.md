# SESSION SUMMARY — 2026-09-14 / 15
## 2D vs 3D memory, the 3D architecture decision, and a documentation pass

**Director's requests, in order:**
1. *"Vamos seguir com a comparação 2D x 3D"*. Of the four open axes, the Director chose
   **memory**.
2. *"Me parece que o 3D é o caminho mais efetivo. E aí nesse caso, precisamos reconfirmar a
   arquitetura."* The Director also proposed solid walls with voxel zones.
3. *"Certo então vamos fazer isso. Faça o planejamento de todas as etapas e deixe
   documentado. Vamos gastar um tempo também dando uma atualizada na documentação mais
   antiga, tem muitos master plans desatualizados. Depois pode encerrar a sessão."*

**Full records:**
- [`DEVICE_DIAGNOSTICS_MASTER_PLAN`](PLANNING/DEVICE_DIAGNOSTICS_MASTER_PLAN.md) v1.7,
  §15.15–§15.17;
- **the new [`RENDER3D_MASTER_PLAN`](PLANNING/RENDER3D_MASTER_PLAN.md) v1.0**.

---

## 1. DIAG-23 — memory, 2D vs 3D (Moto g04s, idle, portrait zoom 0.5)

**What was built** (commit `b6b0b17c`):
- `drop2d`, a scenario step that clears the hidden 2D board's cells under the 3D board;
- a memory table in `bench_analyze.py`.

Skipping 2D placement at the source is not possible yet, for two reasons:
- the load-time light apply writes the cell planes only for cells present in a layer;
- the detonation plan skips cells without a tile.

So the atlas was removed at the source (`NO_BAKE`), the cells were dropped after the load,
and the 3D figure is an **upper bound**.

| runs a / b | 2D, bake ON (shipped look) | 2D, `NO_BAKE` | **3D `NO_BAKE`, 2D dropped** |
|---|---|---|---|
| TOTAL PSS | 2 201 / 2 171 MB | 1 107 / 1 101 MB | **1 099 / 1 036 MB** |
| GL mtrack | 734 MB | 318 MB | **272–277 MB** |
| swap | 721 / 1 395 MB | 0 | **0** |
| boot → map loaded | 54.0 / 52.2 s | 19.1 / 19.6 s | 22.9 / 22.8 s |
| idle frame | 60.0 ms | 76.0 ms | 22.9 ms |

- **At the shipped look, 3D is about half the memory and nothing is swapped.**
- **The half it saves is the bake atlas.** The 207 944 dropped cells free 59 MB of native
  heap and no graphics memory.
- **2D without the atlas loses the facade look,** according to the paired capture.

**Harness defects found and fixed** (commit `e588cdb8`):
- `device_run.py` sorted a capture that crossed midnight wrongly: one row's boot landed at
  the end of its log;
- the last memory poll read a process tearing down after `quit`.

## 2. The architecture decision

**Measured to answer the Director's proposal** (desktop debug build, two runs): 215 432 real
`Voxel` objects cost **316.4 MB, about 1 540 bytes each**. The same count packed costs 0.8 MB.

The prototype's logs already showed that an intact wall is one merged quad: 108 772 faces
become 367 quads.

**Ratified:**
1. **The board moves to Godot 3D.**
2. **Voxels stay the simulation unit, but in a packed store,** not as objects and not as
   zones.
3. **The 2D board and its canon retire at parity only** (R3D-8).

**Why the packed store and not zones:**
- one representation instead of two;
- prediction stays per voxel;
- floors and roofs are 145 992 of the voxels;
- the memory goal is met without zones.

**`RENDER3D_MASTER_PLAN` stages:**

| stage | what |
|---|---|
| R3D-0 | instruments: `BoardProbe`, the `Voxel` cost on the Moto |
| R3D-1 | the packed store, shadow → flip → delete |
| R3D-2 | render-neutral plan, light and glass; also fixes the cook's LIGHT step |
| R3D-3 | the production 3D board; web export checked here |
| R3D-4 | actors in depth |
| R3D-5 | overlays and picking |
| R3D-6 | look parity, ratified per item |
| R3D-7 | 3D cutaway |
| R3D-8 | retire the 2D board and its canon |
| R3D-9 | rotation returns |

Seven questions for the Director are in §8.

## 3. The documentation pass

**Updated with dated status blocks or corrections** — a status and consistency pass, not a
content rewrite:
- **Master plans:** PERFORMANCE (v2.5), PREDICTION, DESTRUCTION, DETONATION_PERFORMANCE,
  DETONATION_PRESENTATION, TOP_TEXTURE, OCCLUSION, MATERIALS, GLASS, SOOT_STORAGE_REFORM,
  ACTOR, INTERFACE, MOVEMENT, RENDER_ORDER, VOXEL_LIGHT, DEVICE_DIAGNOSTICS (v1.7);
- **CHARACTER:** its Part 2 row read IN PROGRESS a month after closing;
- **Canon and index:** VOXEL_MASTER_PLAN, BAKE_SYSTEM_REFERENCE, `docs/README.md` (the new
  plan row; INTERFACE and TOP_TEXTURE rows that were wrong), `CLAUDE.md` (a project line, a
  canon-in-force note, two reference-map rows);
- **`docs/ARCHITECTURE.md`:**
  - `VOXEL-08..11` read "pending";
  - bake and TIC were tagged "Planned";
  - the container classes and file map named files that do not exist;
  - line counts were 5× stale;
  - the status matrix lacked five systems;
- **Map, AI and light plans:**
  - `MAP_MASTER_PLAN`: maps load from JSON first; `_build_room` and
    `_layout_with_perspective` no longer exist;
  - `AI_MASTER_PLAN` and `LIGHT_MASTER_PLAN`: status headers added; exposure is still not
    consumed by detection;
  - all three linked the retired OPERATOR_CONTEXT;
- **Production and reference:** `milestones.md` (a 2026-09-15 next-steps section),
  `technical_debt.md`, `rendering.md`, `occlusion.md`, `QUICK_REFERENCE.md`.

**Not reconciled, and said so in the index:**
- the June–July `docs/systems/*.md` files (perception, lighting, noise, movement, stealth,
  ai);
- `roadmap.md`;
- ARCHITECTURE's sections on systems added since July.

## 4. Gates

- **Code commits** (`b6b0b17c`, `e588cdb8`): lint 0 errors, 55 selftests clean, invariants
  OK, CODEMAP fresh.
- **Desktop real path:** `drop2d` 0 px before/after; without 3D it aborts loudly.
- **This pass is documentation only;** the pre-commit hooks ran on it.

## 5. Where it stops — next session

1. **`RENDER3D_MASTER_PLAN` R3D-0:**
   - measure the `Voxel` cost on the Moto (release build);
   - build `BoardProbe` and prove it deterministic;
   - re-run the baseline tables on one APK.
2. **R3D-1a:** the store layout spike (dense per-level grid vs per-container arrays), with
   the collision census.
3. **Director calls:** `RENDER3D` §8, asked at the stage that needs each one.
