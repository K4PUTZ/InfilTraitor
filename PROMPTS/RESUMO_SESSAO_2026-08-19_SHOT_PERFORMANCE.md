# RESUMO_SESSAO — 2026-08-19 (the shot's performance, and two fixes that were wrong)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-19_THROW_ANIMATION.md`
**Commits:** `7fd333f0`, `9975c4b9`, `62e6a34f`, `ed465ac7`, `2dc2926d` — all
pushed to `main`.
**Gates at close:** lint 210 ✅ · selftests 35 clean / 0 failed ✅ · invariants ✅
· CODEMAP ✅.

---

## Read this first if you are resuming

**One rule governs this whole subsystem, and everything else follows from it:**

> **The TileSet rebuild is charged once per FRAME THAT MINTS, not per mint.**

Measured: 412 `create_alternative_tile()` calls in one frame cost ~264 ms; 442
spread over 11 frames cost ~205 ms **each**. Any change that spreads minting is a
regression, however reasonable it sounds. This single fact explains the impact
frame's long-unaccounted cost, why the soot fade was catastrophic, and why the
first pre-production attempt made things worse.

**The one thing left to do** is named and small: the impact frame still mints
**12 alternatives**, all damage-VARIANT atlas coords. The warm reads each cell's
current tile and a dented voxel moves to another one. Zeroing those 12 is worth
as much as the 479 already warmed, because the rebuild does not care how many
there are. It needs the variant's real `(source, coords)` resolution including
the per-impact `variant` hash. **One attempt already failed** — it warmed 11 the
shot did not want while still missing the 13 it did — and was reverted rather
than left in. `INFILTRAITOR_MINT_TRACE=1` prints every alternative created; start
there.

---

## 1. The bug the Director reported, and it was real

*"Digamos que eu joguei duas granadas no chão. Quando eu der o primeiro tiro com
a shotgun, todos os voxels afetados pelas explosões soltam fumaça novamente."*

Measured before touching anything:

| event | `voxel_destroyed` dispatches |
|---|---|
| grenade 0 | 0 |
| grenade 1 | 0 |
| **the shot** (destroyed 5 voxels) | **498** |

`set_damage()` marks a voxel dirty, and dirty means SOMEBODY STILL HAS TO RENDER
THIS. For a blast nobody does — `DetonationChoreographer` writes cells straight
to the TileMapLayers from its plan and never touches the dirty pipeline. The
flags stayed set forever and the firearm path, the only unfiltered
`process_dirty_async()` caller in the game, walked the whole backlog.

Fixed at two levels: the commit clears `delta.touched_voxels`' flags, and
`voxel_destroyed` now fires only when a tile was **actually removed** — the
signal means "a voxel just disappeared", not "we processed a destroyed voxel",
which makes the class impossible whatever leaves a stale flag next. **498 → 6.**

Regression harness: `INFILTRAITOR_CAPTURE_ACTION=grenade_then_shot`.

---

## 2. Two fixes that were wrong, and how they were caught

### The hypothesis that measured false

The Director's read on the stall was that the shot was still *"processando a
destruição na parede"*. Instrumented:

    resolve+apply 1.32 ms · repaint 581.10 ms · 23 voxel(s)

Damage resolution is **0.2%** of a shot. Pre-computing it — the obvious analogue
of the grenade's P-COOK — would have saved nothing measurable.

### The optimisation that made it worse

Deferring the soot cut the trigger frame's CPU and **added five stalls of
240–420 ms behind it**. The per-phase profile could not see this because it timed
CPU inside a function; only a per-FRAME timeline shows it. Turned off, left
behind an A/B switch rather than deleted.

### The harness that measured itself

The first filmstrip saved a PNG per frame and reported 187 ms and 184 ms for the
two frames **before** the trigger — a flat baseline that is the encoder. A
frame-timing harness paying 180 ms/frame cannot see a 90 ms stall. Images are now
opt-in and the run says so when they are on.

**All three are the same lesson in three costumes: measure the thing the player
feels, not the thing that is easy to instrument.**

---

## 3. What shipped, and the Director's contract for it

Ratified priority order, and the path is now built to it:

- lag **after the button** — fine
- lag once the tiles have swapped and the smoke is out — fine
- lag **while the projectile is moving** — not fine

### The round was freezing because it outlived its own flight window

`TracerOverlay` lived 15 frames while `TRACER_FLIGHT_FRAMES` is 8, so the heavy
impact frame landed with the streak still on screen. Now 5 + 3 = 8: it leaves the
barrel with the flash, crosses what it crosses, and vanishes before anything
expensive runs. It does not reach the wall, by the Director's own permission.
**Keep `HOLD_FRAMES + FADE_FRAMES <= TRACER_FLIGHT_FRAMES`** — two files, one
decision.

### Pre-production, built against the measurement rather than the name

- `_build_shot_plan()` is PURE and runs the same functions the shot will (same
  salt, same picks, same punch ladder), so it is deterministic by construction.
- `build_occupancy(predict_destroyed)` and `_build_soot_snapshot(..., predicted)`
  build the post-shot inputs without writing a voxel.
- `warm_light_alts_for_gus()` mints everything in ONE frame, during the aim.
- **Two worlds are warmed** — soot-free (for the impact) and sooty (for the later
  pass) — because soot is part of the alternative id and a warm that predicts the
  wrong world is no warm at all.
- The **shared** `_voxel_light_field` is reused: a `new()` one has no state to
  invalidate against and rebuilt the whole map at **1450 ms**.
- `fire_at_active()` joins the warm before a frame of animation plays.

### Per-frame result

```
frame 06   16.1 ms   <-- FIRE, no lag at the button at all
frame 07-13  16-17 ms   the projectile flies and vanishes, at frame rate
frame 14  334 ms        the impact: tiles swap, smoke
frame 16  411 ms        the soot, explicitly sanctioned
```

Against where it started: one 581 ms stall at the trigger, and a projectile
frozen in the middle of it.

---

## 4. Instrumentation left behind, all env-gated

| Switch | What it answers |
|---|---|
| `INFILTRAITOR_CAPTURE_ACTION=shot_filmstrip` | per-frame timeline of a shot (`..._SHOT_FILM_SAVE=1` for images — timings then invalid) |
| `INFILTRAITOR_CAPTURE_ACTION=grenade_then_shot` | the VFX-leak regression, as a dispatch count |
| `INFILTRAITOR_REPAINT_PROFILE=1` | repaint phase split, cells written, alternatives minted |
| `INFILTRAITOR_MINT_TRACE=1` | every alternative actually created — the count cannot say WHY a warm missed |
| `INFILTRAITOR_SHOT_SCOPE_PROBE=1` | scoped-vs-full apply equivalence (192 543 cells, 0 differ) |
| `INFILTRAITOR_SHOT_SOOT_DEFER=1` | re-enables the deferral that regressed |

---

## 5. Open, in priority order

1. **The impact's last 12 mints** (§ "Read this first"). One TileSet rebuild,
   ~250 ms, on the frame the wall breaks.
2. **The warm frame itself is ~460 ms**, right after the target is selected. It
   is lag during aiming rather than during action, so it is within the
   Director's rules — but it is not free, and it is the next candidate after (1).
3. **`_build_soot_snapshot()` is ~140 ms and map-wide.** It must stay map-wide:
   D24 derives soot from absences anywhere, and scoping it would create a second
   soot producer — the drift `SOOT_MASTER_PLAN` §1.2 already caught once.
4. **The `aimed` grip's first load is ~150 ms** on the frame the menu opens.
   One-off per session, and a candidate for preloading with the posture sets.
