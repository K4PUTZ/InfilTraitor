# Session 2026-09-06 — G4-4 + G6b-3: §18 closes

Previous session:
[`RESUMO_SESSAO_2026-09-05_G4_SHARDS.md`](RESUMO_SESSAO_2026-09-05_G4_SHARDS.md).
This one opened with *"Vamos seguir com o vidro. Leia a documentação"* and ran
**G4-4** (the scatter table + the shockwave impulse), **G-D45** (a remnant whose
frame is destroyed falls with it), the timing-video bench, and — after the
Director's review — the tuning and **G6b-3** (the dust puff). **§18 is closed.**

`GLASS_MASTER_PLAN` v1.41 → **v1.43**, new **§18.14**, register gains **G-D45**
and marks **G-D41 / G-D42** BUILT. Four commits + this doc.

| | commit |
|---|---|
| the scatter, the impulse, and G-D45 | `7f836b56` |
| the rain-timing bench (5 presets, one MP4 each) | `251d8636` |
| this doc | `eaa459b9` |
| `default` preset + 80% shard opacity + fuller pile + G6b-3 dust puff | *this session's last* |

---

## 1. What the Director ruled (answering the three open questions)

| | ruling |
|---|---|
| **timings** | *"Vamos gravar vídeos com timings diferentes e escolher."* Not a set of numbers — a bench. Built as `build_filmstrip.py --glass-rain <preset\|all>` |
| **G-D45** | *"Cair seria o ideal, mas se for mais fácil pode ser destruído junto com o frame… Se a moldura for destruída o caco grudado cai/some junto."* Taken as: the orphan becomes a DESTROYED voxel and joins the shard fall — "cai junto", and it reuses the G6b plumbing so falling costs almost nothing over deleting |
| **z_index** | after the mechanism was explained: **(a) leave it** — one band for the whole rain field, a 40-frame transient on multi-storey panes only, performance is the standing priority. Option (b), a MultiMesh per storey band, stays on the shelf |

## 2. What was built

**G4-4 — the scatter (§18.14).** A pane projects onto a LINE of grid cells and
until now that line was the whole pile. `GlassFall.plan_landings(destroyed, slabs,
impulse := {})` now scatters each shard first — one independent draw per grid axis
from `SCATTER_WEIGHTS` `[0.55, 0.30, 0.11, 0.04]`, so most stay on the column and a
tail reaches 3 cells. The symmetric draw is "perpendicular both ways and along the
run" for **any** face, so `GlassFall` never learns the pane orientation; it takes a
grid-space `impulse` instead. Rows gain `origin_pos`; `spawn_glass_rain()` launches
each shard from its own column and lands it at the scattered one — a diagonal fall.

**G4-4 — the impulse (G-D42).** The cook builds `{dir, strength, lift}` from
`origin_v.grid_pos - epicenter` and `ring_multipliers[ring]` — no second force
model. `strength` shifts the band's mean downrange, per-shard-scaled so a near
grenade lands the pile *"mais longe, mais espalhados"*, and the impulse is the one
term allowed past the 3-cell cap. Bullet shatters pass no impulse. **`lift`** (the
skylight term) is authored and **UNEXERCISED** — G-D16c/d is unbuilt — with a
synthetic selftest [9] that says so.

**G-D45 — the orphan.** `Room.reap_orphaned_remnants()` runs once per destruction
event — the cook's `commit()` (unconditionally: a frame the blast broke may hold an
old remnant even when the delta has no glass) and the shot pipeline after its own
base-record loop. It asks `remnant_anchor_mask()` (which reads the live world) per
base remnant; a 0 means the frame is gone, and the fragment becomes a DESTROYED
voxel that joins the fall — cut atom erased, base record dropped, freed voxel
base-recorded for VL-PERSIST.

**The bench (`251d8636`).** `GlassRainOverlay.timing_overrides` (a static dict
`spawn()` folds in), `Room._capture_glass_rain_timings()`, `RAIN_TIMING_PRESETS`
(`snappy` / `default` / `floaty` / `heavy` / `raked`), and
`build_filmstrip.py --glass-rain`. The pane is shattered for real (real scatter),
the pile decal laid, the rain played at ONE preset over a clean backdrop.

## 3. ⚠️ THE FINDINGS

### 3.1 The scatter offset is hashed in GRID space, and that is correct

Every other identity key on this track is base-space, because it is recomputed
after a rotation and a view-space cell is renumbered. The scatter is **not**
recomputed: `plan_landings()` runs in the cook, the result rides the Delta, and at
`commit()` the G6 pile is written in base coords and thereafter only re-laid
(`_respawn_base_shards()`), never re-planned. So the hash only has to be stable
across one event's many `build_plan()` calls — the cursor is on one target
throughout — and a grid key is. This is the same property the un-scattered landing
already had; the scatter did not change the state model, only the cell.

### 3.2 One number cannot hold "one column → one deep pile" after the scatter

`glass_fall_selftest` [6] asserted a 24-voxel column resolves to a SINGLE cell at
density 24. That is now false by design — the pile is a band. Rewritten to the
thing that still has to hold: the count is preserved (no shard lost off a surface
edge), every landing is within the tail of its own column, and the near cells hold
the strong majority. The fixtures for [1]–[4] also had to widen from one GU to a
3×3 block, because a shard scattering off a one-GU floor slab lands in a column
with no surface and gets dropped — a test about the FALL rule failing for a reason
that is not the fall rule.

### 3.3 A `+ 0.5` threshold is a measurement, not a constant

[9] first asserted `lift` widened the mean scatter radius by an absolute 0.5 cells.
It came back 1.14 → 1.64 — exactly on the line, and `>` is a coin toss there.
Rewritten as `> flat_mean * 1.25` (a proportional claim, 1.44× observed), which is
also the more meaningful statement: lift widens the spread by a FRACTION, not by a
fixed number of cells.

### 3.4 An unconditional call reaches every stub

`WorldDelta.commit()` now calls `room.reap_orphaned_remnants()` on EVERY commit,
not gated on the glass fields — because a brick wall the blast broke can be the
frame that held an old remnant. That broke `glass_shatter_selftest` [20], whose
`RoomStub` implements only the one call the test is about. The other glass claims
in `commit()` are all guarded by `if not …is_empty()` and so never reached the
stub; the reap is not, by design. Fixed by adding the no-op to the stub, with a
comment saying why it now has to answer.

### 3.5 The G4 session's harness lesson, applied

The 2026-09-05 summary's §4.1 was about a null capture result being a claim about
the invocation first (`INFILTRAITOR_AUTO_SCREENSHOT=1` is the gate). This session
hit the smaller cousin: `timeout` does not exist on macOS, so
`godot … 2>&1 | grep …` returned exit 127 and **no output**, read at first glance
as "the capture produced nothing". It was the pipeline failing on a missing
command. Ran it backgrounded without `timeout` and it worked first try.

## 4. Evidence

| | |
|---|---|
| `glass_fall_selftest` | 6 → **10**: [6] rewritten, [7] scatter shape (0/1/2/3 = 2150/1268/423/159, none past 3, mean −0.040), [8] impulse (mean X −0.04 → 1.93, 167 past the tail, base clean), [9] lift (synthetic, 1.44× wider), [10] determinism |
| `glass_shatter_selftest` [23] | G-D45: `remnant_anchor_mask()` → 0 the instant the concrete jamb is destroyed |
| all 51 selftests | clean; lint + invariants + codemap OK at every commit |
| the real map | `[GLASS-FALL] 1152 of 1152 shard(s) landed, on 284 cell(s)` — up from the ~48-cell line the storefront's foot is. `[GLASS-RAIN] 1152 flight(s) -> 2927 shard(s)` (2.54/voxel). No `[GLASS-REMNANT] G-D45` line — the storefront is free-standing, so the reap correctly found nothing to fell |
| the timing videos | `Screenshots/filmstrip_rain/rain_{snappy,default,floaty,heavy,raked}.mp4` (gitignored), spans 45 / 85 / 124 / 86 / 100 frames, all at `--fixed-fps 60` |

## 5. The Director's review, and the close (2026-09-06)

*"O segundo me parece o melhor"* → **`default` is the shipped preset** (its
`RAIN_TIMING_PRESETS` row is `{}` — the look `var`s already hold those values).
Two tuning notes, both done:

- *"tira um pouco da opacidade dos cacos, vamos começar já em 80%"*, then a second
  pass — *"tira mais opacidade… e ir aumentando durante a queda… mais translúcidos…
  parecem uma massa só"*. The field is `blend_mix`, so overlap is what makes the
  mass; four levers: `tint` alpha `0.95 → 0.55`, an `air_alpha` ramp (`0.28 → 1.0`
  over the fall), a per-shard `avar` `[0.55, 1.0]`, and `pieces_low_bias 1.6`
  (skews the 1..4 count low, 2927 → 2457 shards). A tumbling shard high up is now
  see-through; the settled pile decal carries the lasting read.
- *"queria deixar mais debris no lugar depois que eles sumirem. Ta muito vazio"* →
  the G6 pile decal's opacity formula was calibrated for ~24 shards/cell, and
  G4-4's scatter drops that to ~4, so every scattered cell was near-invisible.
  `VoxelRenderer.FLOOR_SHARD_ALPHA_{BASE,GAIN,MAX}` + `FLOOR_SHARD_SCALE` (`static
  var`) rebalanced — the settled band now reads as continuous debris rather than
  a thin dark line.

### G6b-3 — the dust puff

*"1 efeito de pozinho branco se espalha horizontalmente, saindo por baixo dos
cacos."* `DebrisOverlay.add_glass_dust(center, reach, color)` — a GROUND puff, not
a fall: each speck lerps to its own radial target (concentrated near the middle,
flattened to an ellipse), on an ease-out, then holds and fades. Reuses `add_dust`'s
machinery and its `CircleField` via a `"spread"` flag — not a new particle system.

⚠️ **The glass puff ages in FRAMES**, `1/60` per `_process` call — it is spawned on
the detonation's commit frame (the stall), and a `delta`-aged effect started there
burns its whole life in one frame. Blast dust/chips keep `delta` (they fire on
beat 3, not the stall). Same trap the rain and `EmberOverlay` already learned.

`Room.spawn_glass_rain()` buckets the landings on a ~44 px grid and spawns one
puff per dense bucket (`reach` 16→46 px by density, capped at 12) — the pane's
foot puffs hardest, the fringe barely. On the storefront: `[GLASS-DUST] 12 puff(s)
over 59 landing bucket(s), peak 65 shard(s)/bucket`.

**§18 is closed.** Glass rejoins the `MATERIALS_MASTER_PLAN` tail — `plastic`
screen backing and S-4's fracture art remain (G-D25's big shards were superseded
by G-D44); M5 voxel props and M6 fluids are the milestone's last two parts.

## 6. The review pass (2026-09-06)

*"dar mais uma revisada no código, checar por fios desencapados e pontas soltas,
e dar uma limpada no que não estiver mais em uso."*

- ⚠️ **The dust broke `glass_rain_demo`'s G-D43 gate — found in review, not on
  screen.** That capture re-lays a settled rain and asserts "0 differing pixels
  after the kill", but step 5 frees only the `GlassRainOverlay` — the puff lives in
  `_debris_overlay` and would still be settling. `spawn_glass_rain()` gained a
  `with_dust` flag (default true); the demo passes false. The reap and the real
  paths keep the dust.
- **`GlassFall.SCATTER_MAX_CELLS` was a `const 3` with a comment claiming it was
  "derived from the weight table's length".** It was not — [[two-equal-constants-is-not-a-rule]].
  Now `scatter_max_cells()`, a `static func` reading `SCATTER_WEIGHTS.size() - 1`.
- ✅ **G-D45 confirmed on the real map.** New instrument
  `INFILTRAITOR_CAPTURE_ACTION=glass_reap_demo`: weak shatter of a framed window
  (4 anchored remnants), destroy the 672-voxel brick jamb, `reap_orphaned_remnants()`.
  Log: `[GLASS-REMNANT] G-D45 — 4 orphaned remnant(s) fell with their frame, 4
  landed`, store `4 → 0`, `[GLASS-REAP] PASS`.
- **No dead code found** — every helper the session added has a caller. The four
  unshipped `RAIN_TIMING_PRESETS` are the bench's comparison set, kept like
  `glass_blast_demo` and its siblings.
- **Docs synced:** `docs/README.md`, `current_state.md` (§2/§3/§4 glass rows),
  `MATERIALS_MASTER_PLAN` (v1.8, M4 essentially done), `GLASS_MASTER_PLAN` (v1.43,
  §18.10 resolved, §18.14b), and three memory files.

### Findings that outlive the code

1. **A capture's assertion can be broken by a feature it doesn't test.** The dust
   goes into a sibling overlay; the demo's "0 pixels" diff never named it, so
   nothing on screen would have shown the regression until someone re-ran the gate
   and puzzled over a non-zero. The fix is a flag, but the lesson is to check every
   assertion a new side-effect can reach, not just the ones near the change.
2. **A comment that says "derived" is not a derivation.** `SCATTER_MAX_CELLS` had
   the right value and a comment describing the right rule — and was still a
   hardcoded literal that a fifth weight entry would silently desync. The project
   has a memory for exactly this and it still slipped in.
