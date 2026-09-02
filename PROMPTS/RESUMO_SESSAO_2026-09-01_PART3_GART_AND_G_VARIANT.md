# Session 2026-09-01, part 3 — the art order, and the glass family

Part 1 is [`RESUMO_SESSAO_2026-09-01_OCC_FIX_AND_TEST_DEBT.md`](RESUMO_SESSAO_2026-09-01_OCC_FIX_AND_TEST_DEBT.md),
part 2 [`RESUMO_SESSAO_2026-09-01_PART2_GLASS_G3_COMPLETE.md`](RESUMO_SESSAO_2026-09-01_PART2_GLASS_G3_COMPLETE.md).
**This file is the current state.** `GLASS_MASTER_PLAN` went **v1.14 → v1.19**.

| | commit |
|---|---|
| G-ART | the art order glass never had, and a gate earned before the art |
| V-A | glass-ness is asked, never compared — and Stage B is inert on the real map |
| FIX | a hole does not stop a fracture, a frame does |
| V-B | four more glasses, zero new art, and the tint rides a channel nobody was using |
| V-C | armoured glass has no region, and a screen stops the round |
| V-D | a pane that was pierced remembers, and a screen's class is where it was put |

45 files, +2663 / −183. **G-ART and all four G-VARIANT stages are closed.**

---

## The finding that mattered most, and it was not planned work

**G3 Stage B was INERT on the real map, with thirteen green tests in its own
suite.** Found while verifying V-A — a refactor whose only job was to change
nothing.

`plan_pane_shatter`'s BFS queued a neighbour only `if lattice.has(nb)`, and
`lattice` holds SURVIVING glass, so the walk could not step across a hole. The
origin IS the shot's own fresh hole: `agent_shot_controller` applies the local
hole and only THEN calls `_maybe_shatter_pane`, and a rifle-class round takes
2–4 voxels plus the cascade. Measured, on a WON sniper roll:

    lattice=1143  own_frame=0  origin=(114, 84)  origin_in_lattice=false
    neighbours_in_lattice=0/8  flood=0  radius=23

1143 surviving voxels, a radius of 23, and the walk died at step one. **The
failure scaled the WRONG WAY** — a wider hole strangled the flood harder — so it
bit worst on the round most likely to win the roll in the first place.

The fix is one branch, and it had to split two absences that were the same
absence: a cell missing from `lattice` is either a HOLE (a fracture travels
through it) or the pane's own non-glass BAND (`own_frame`, which must keep
stopping it and was only doing so as a side effect).

**Why thirteen green tests walked past it, and this is the transferable part:**
[7], [8] and [9] all aim at an INTACT lattice cell, so their origin is in
`lattice` and the walk starts alive. The real path destroys the hole first. **The
fixture was built with the data that works** — CLAUDE.md's floor-dent lesson in a
new costume. Selftest [14] now punches the hole BEFORE rolling, the way the shot
does: intact origin 1128 flooded, after a 9-voxel hole 1119. It read **0 of 1128**
before the change.

`glass_flood_{before,after}_2026-09-01.png`, 109 486 px changed. ⚠️ `GlassFall`
had **never once fired** on the real shot path — it lives behind `if n > 0`, so
the strangled flood took it along.

---

## What was built

### G-ART — the order, and a gate earned before the art

[`ART_ORDER_GLASS.md`](ART_ORDER_GLASS.md) asks for **five files**: two 1024×512
grayscale fracture sheets (tight/wide, G-D14/G-D21) and three 256×256 shard
decals. Three consumer facts were found by reading the code rather than the spec,
and each would have cost an authoring night:

1. **The facade path DESTROYS alpha** (`bake_compositor.gd:556`). §7.3's
   *"generate on black, alpha = luminance"* recipe is right for the DECALS and
   would have delivered a sheet as a bright crack on **opaque black**.
2. **`TextureResolver` knows three filename prefixes and rejects the rest with no
   error at all** (`texture_resolver.gd:176`) — Tier.NONE, generic atlas,
   silently wrong.
3. **A sheet is authored 1:1 horizontally.** The *"detail dissolves at 1/16th
   linear"* warning is about the decals (256 → 16), not the sheets.

`check_decal.py` gained per-material family sets and the fracture-sheet class.
Proven red on seven modes with a **green control first** — a gate that rejects
everything would pass a rejection-only test — and all 54 shipped decals unchanged.
Its own check is the ORIGIN: G-D21 anchors by `(impact − centre)`, so an
off-centre fracture displaces every crack in the game by an invisible constant.

### G-VARIANT, four stages

**V-A — the family seam.** `GlassMaterials.is_glass()` replaced **25 bare
`== "glass"` comparisons** across render, geometry, occlusion, the guard phase,
the shot path and the cook. Against a literal, every new member would be a
silently OPAQUE wall that renders, occludes and stops rounds with no error.
Roster shipped with ONE member on purpose, so the sweep was behaviour-preserving
by construction — verified before/after on the same binary via a stash. New
invariant **L2 `glass-is-a-family`** (CLAUDE.md rule 10) parses the roster out of
the seam module rather than duplicating it.

**V-B — the roster and the tint.** `glass_armored` + `glass_screen_{green,red,amber}`,
**zero new art**. The tint rides the pane atom's free BLUE channel (R = dim,
G = G-D19's damage, B = the family index) into per-class shader uniforms: one
container, one shader, one layer per level, 80 atoms composed at load instead of
multiplying DRAW SUBMISSION.

**V-C — the behaviour.** ARMORED has no region (a won roll takes the lattice
whole); INDESTRUCTIBLE caps at CRACKED and **stops the round**.

**V-D — the placement tag and the primed pane.** `panels[].glass_class` rides to
`Slice.glass_class`; G-D15's pierce-and-prime works end to end, checkpoint-scoped
in `SaveState`.

---

## Three defects the family created, all closed before shipping it

1. **The pane union never read the material.** A plain pane touching an armoured
   one would have merged into ONE pane with two resistances and two classes, and
   a won roll would flood out of the ordinary glass straight through the armour —
   defeating it with nothing on screen to explain why.
2. **`uniform vec3 x[4]` prints a shader-compiler error every boot** while
   rendering correctly. Measured 0 before, 1 per boot with the array, 0 with four
   named scalars. `"Continuing."` makes it the kind of error a reader learns to
   scroll past.
3. **The bake composed one identical sheet per material** — `3 combos` →
   `7 combos × 2 directions in 1374.0 ms`, 16 384 atoms for materials whose panes
   never read a sheet. Collapsed to `3 combos … in 1263.0 ms`.

---

## Four lessons worth carrying out of this session

- **A rule that holds only because two independent constants happen to be equal
  is not a rule.** Glass never DENTED only because `DESTROY_MIN["glass"]` and
  `PUNCH_DENT_MIN` were both 0.30. §6.1 had flagged it. The edit that would have
  broken it came from somewhere else entirely — raising the ARMOURED breach.
- **Absence is not a stop.** Making a screen stop a round by REMOVING it from the
  pass-through set would have made every screen walk-through and still not stopped
  the round: a half-thickness panel is not in `blocked_edges` either, so an edge in
  neither dictionary is open air. One set feeding two questions is the same
  conflation G3 Stage D undid once already.
- **Dividing a total by a count measures nothing.** The bake saving was predicted
  at ~785 ms from a per-combo average and measured at **111 ms** — combos are
  wildly unequal. The comment carrying the wrong number was corrected in place.
- **A two-shot mechanic cannot be evidenced across two boots.** The shatter salt
  carries `_world_revision`, which the first shot bumps, so two boots are two
  independent rolls. `shot_filmstrip` — the only action that fires twice in one
  boot — gained the aiming overrides `agent_shot` already had.

---

## ⚠️ A hole in the selftest arbiter, found and NOT fixed

`run_selftests.py` deliberately treats `ERROR:` lines as non-failures, because
`push_error` is used on purpose in loud-fail paths (its header says so). But an
ENGINE error is indistinguishable: a `String formatting error` from a GDScript
`"a" + "b" % [...]` precedence slip **aborts the rest of that test function and
the suite still reports PASS**. Hit twice in one session; caught both times only
by reading the raw output. Same shape as the bare-`godot --script` trap CLAUDE.md
already warns about, one level down. Not fixed — out of scope, and the Director's
call.

---

## State at close

| gate | result |
|---|---|
| `project_lint.py` | PASS, 227 files |
| `run_selftests.py` | **49 clean, 0 failed**, NOT RUN empty |
| `check_invariants.py` | PASS (R1–R5, B1, B4, L1, **L2**) |
| `gen_codemap.py --check` | fresh |
| `check_decal.py --all` / `check_facade.py --all` | 54/54 · 10/10 |
| `glass_shatter_selftest` | 12 → **31** checks |
| `glass_transparency_selftest` | 9 → **11** checks |

Hand-named captures (rotation-proof): `glass_flood_{before,after}_`,
`glass_variants_`, `glass_armored_whole_pane_`,
`glass_screen_stops_round_2026-09-01.png`.

## Where to pick up

`GLASS_MASTER_PLAN` is **v1.19**. G3, G-ART and G-VARIANT are closed. What is
left, and what each waits on:

1. **The crack** (G-D19/G-D21/G-D23's clamp/G-D24) and **the shards on screen**
   (G-D16b) — the **ART DELIVERY**, five files, ordered. `glass.crack_factor`
   moves WITH the art, never before it: `voxel_decal_selftest` [12] demands data,
   wiring and art together. Two build steps are owed the day it lands, both in
   the order's §4: a `fracture_` category in
   `TextureResolver._validate_dimensions()`, and a constant naming the sheets so
   the gate can check their wiring.
2. **G-D8's last third** — the light bump and +1 detection when a passage opens.
   Needs the opening as an EVENT; Stage D landed a per-turn recomputed SET.
3. **G-D16c/d — skylights and sub-GU slab regions.** CEILING glass still renders
   opaque (`voxel_renderer.gd`), and there is no horizontal `pane_id`.
4. **A solid glass CUBE.** `PANE_BLOCK_*` has no run axis for
   `plan_pane_shatter`'s lattice, and `_note_glass_crossing()` dedupes by
   `pane_id`, so entering and leaving a block counts as one layer.
5. **`plastic`** (the black backing a screen's images are painted on, G-D17) —
   deferred to `MATERIALS_MASTER_PLAN`.
