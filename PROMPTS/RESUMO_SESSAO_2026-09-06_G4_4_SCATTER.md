# Session 2026-09-06 — G4-4: the pile becomes a band, and a stranded remnant falls

Previous session:
[`RESUMO_SESSAO_2026-09-05_G4_SHARDS.md`](RESUMO_SESSAO_2026-09-05_G4_SHARDS.md).
This one opened with *"Vamos seguir com o vidro. Leia a documentação"* and ran
**G4-4** (the scatter table + the shockwave impulse) and **G-D45** (a remnant
whose frame is destroyed falls with it) end to end, then built the timing-video
bench the Director asked for.

`GLASS_MASTER_PLAN` v1.41 → **v1.42**, new **§18.14**, register gains **G-D45**
and marks **G-D41 / G-D42** BUILT. Two code commits + this doc.

| | commit |
|---|---|
| the scatter, the impulse, and G-D45 | `7f836b56` |
| the rain-timing bench (5 presets, one MP4 each) | `251d8636` |

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

## 5. 🟡 WHERE TO PICK UP

1. **The Director picks a timing preset** from the five videos (or asks for a
   sixth / a tweak). `RAIN_TIMING_PRESETS` in `room.gd` and the look `var`s in
   `glass_rain_overlay.gd` are where the winner lands. He may also want the shard
   DENSITY down — a 6-GU storefront is 2927 shards and reads as a dense mass; a
   framed window (`--glass-rain <preset> … INFILTRAITOR_GLASS_BLAST_PANE=framed`)
   is a calmer picture.
2. **G6b-3** — the white dust puff on landing, on `DebrisOverlay`'s existing
   `CircleField` (`add_dust`), most on the pane's own cell. The last piece of §18.
3. Then §18 is closed and glass rejoins the `MATERIALS_MASTER_PLAN` tail
   (G-D25/plastic/S-4 art, M5 props, M6 fluids).
