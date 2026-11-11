# Session 2026-09-05 — G4 and the shards: the glass that stays, and the glass that falls

The previous session is
[`RESUMO_SESSAO_2026-09-04_CRACK_05.md`](RESUMO_SESSAO_2026-09-04_CRACK_05.md).
This one opened with the Director asking for the GLASS map's **test windows**, and
then ran G4 and the shard rain end to end.

`GLASS_MASTER_PLAN` v1.37 → **v1.41**, new **§18** (nine subsections), register
gains **G-D38 … G-D44**. Eight commits.

| | commit |
|---|---|
| four test windows on the GLASS map, framed and subdivided | `71fd4c06` |
| the mechanism plan — G4's rule is built and its answer is discarded | `f62dbaa8` |
| the Director's two rulings: the pile is the only permanent thing | `3e3cc88b` |
| **G4-1** the shard shape family | `b50d32ee` |
| **G4-2 + G4-3** the survivors leave the function, and stop being squares | `a050b72e` |
| **G4-3** it fires on the real map — and my hang diagnosis was wrong | `8d473c8f` |
| **G6b-1** the shard field: one texture, one draw call, an earned gate | `1cfd71f5` |
| **G6b-2** the fall, and G-D43 proved instead of asserted | `63de3048` |

---

## 1. The finding the whole session rests on

**G4's RULE was already implemented, and its answer was thrown away.**

`GlassShatter.plan_pane_shatter()` computed `spared` — G-D13b's anchored
survivors, which is the Director's *"voxels de vidro tocando outros materiais têm
uma chance de ficarem grudados"* word for word — and then discarded the local at
`glass_shatter.gd:542`. `if spared.has(k): continue` was its only use in the whole
repository. So a remnant was not a thing the world knew about: it was a voxel that
happened to be ABSENT from the destroy list, indistinguishable from one the blast
never reached, drawn as the ordinary square atom.

G4 was therefore two verbs, not a new rule: **surface** the decision that was
already made, and **shape** it.

## 2. What the Director ruled

| | ruling |
|---|---|
| **G-D43** | *"Vamos padronizar a pilha no chão. Os cacos caem no chão, apagam e revelam um sprite padrão por trás."* The pile decal is the only permanent record; the rain is disposable. This RESOLVED a two-authorities question by deleting a claim rather than reconciling — and it makes the whole effect safe to interrupt |
| **G-D44** | *"Não precisam existir mais cacos grandes… partes com tamanhos entre 1 e 1/2 voxel."* Supersedes G-D25. ⚠️ Not a subtraction: conserving area, a 0.5-1.0 voxel piece means **1 to 4 pieces per voxel**, so the population falls out of the ruling instead of out of a knob. Measured on the real blast: **2.55 per voxel** |
| **sub-GU** | *"a Godot tile, where 1 voxel belongs"* — so every distance in his brief is in voxel cells, and the whole scatter tail stays inside half a GU |

## 3. What was built

- **G4-1** `glass_shard_shapes.gd` — five members, `polygon()` for the rain and
  `anchored_polygon()` for the remnant. One family, two consumers (G-D38),
  oriented by its anchor (G-D39).
- **G4-2** `plan_pane_shatter()` returns `{"destroyed", "remnants"}`; the chain
  Delta → room → `SaveState` → respawn. ⚠️ **The anchor is DERIVED, never stored**
  — a stored mask would be in the pane's (run, level) frame and a quarter turn
  changes what `RUN_POS` means. The store is position only.
- **G4-3** the cut remnant atom, on the bullet-hole rim's own path, registered in
  the SAME `_glass_shard_cells` so it inherits `restamp_glass_shards()`.
- **G6b-1** `ShardField` — the five members in one atlas, one MultiMesh, one draw
  call; flip/flop/scale/rotation are the instance transform and therefore free.
- **G6b-2** `GlassRainOverlay` — a closed-form trajectory aged in FRAMES, the
  bounce, the fade over the pile decal, and the freeing.

## 4. ⚠️ THE FINDINGS THAT OUTLIVE THE CODE

These are the reason this file exists; the code is in git either way.

### 4.1 A null result from a harness is a claim about the HARNESS first

I reported *"no windowed Godot run completes on this machine"* on four runs that
each sat at a steady 44% CPU and wrote nothing. All four were launched without
**`INFILTRAITOR_AUTO_SCREENSHOT=1`**, which is the gate on
`_run_auto_screenshot_capture()` — the function holding the ENTIRE
`INFILTRAITOR_CAPTURE_ACTION` dispatch. Nothing was hanging.

Every symptom was a running game read backwards:

| what I saw | what I concluded | what it was |
|---|---|---|
| a steady 44% CPU | "a spin" | one core rendering a game |
| the log stopping at 5 204 lines, twice | "the same hang point" | the last thing `_ready()` prints |
| PLAYGROUND failing identically | "the machine, not the map or the change" | the same missing variable |
| repeated `[GLASS-SHATTER-BLAST]` lines | *(not noticed)* | `build_plan()` previewing on cursor moves — **proof the game was live** |

The control was well chosen and its answer was correct; I attached it to a
conclusion it did not support. **Before blaming the environment, run the harness in
the configuration known to work** — one grep for what gates the entry point would
have cost a minute against the half hour this took. The Director's *"não está
travando aqui não"* is what settled it.

### 4.2 One number cannot hold three degeneracies

"Too small" for a shard turned out to be three separate things. A single
`AREA_MIN` rejected the family's one deliberately ELONGATED member; its
replacement, a fill ratio, then failed its own control because a 1.0 x 0.1
rectangle has fill 0.70 — a rectangle IS its own bounding box. Now `MAJOR_MIN`,
`ASPECT_MAX` and `FILL_MIN`, each with a control that the other two would pass.

### 4.3 A band applied as a fraction is not the band

G-D44 says pieces are 1 to 1/2 voxel. A single `scale in [0.5, 1.0]` over members
of DIFFERENT authored sizes does not produce that: `chip` is authored 0.534 across,
so half of it is 0.267. An instance asks for a **target size** and `size_scale()`
finds that member's multiplier, so the band is exact by construction for whatever
the family grows into.

### 4.4 Every number can be green while the picture is wrong — and the reverse

- The numbers were all green when the capture showed `sliver` was a four-pointed
  star (two long radii opposite each other on an evenly spaced ring make a
  sparkle; elongation lives in the ANGLE table), and then a smooth lens (the
  flanks have to ZIGZAG, not ease).
- The numbers were all green when half the anchored placements read as fragments
  FLOATING near the brick. "Flush and flat" was true of all twenty — a flat cut two
  hundredths of a voxel long is a nub and satisfies both words. **The push depth is
  solved now, not authored**, and contact length is a number in the suite.
- And the reverse: the atlas gate caught 84 texels of bleed the eye would never
  have found until a shard fringed into its neighbour at 12 px.

### 4.5 A literal for an enum is Rule 9's trap in another costume

`Face` is `{NW, NE, SE, SW}`, so a literal `0` is **NW**. Two new tools wrote
`var face: int = 0  ## Face.SW`. ⚠️ The cut stays SELF-CONSISTENT either way — the
same face goes to the builder and to the cutter — which is exactly why it is
silent. It surfaced only because a test hand-rolled the SW basis to check the
result and the two halves then disagreed about which wall they were looking at.

### 4.6 A gate has to be able to reach the failure

P7b's culling defect shipped under a green 0-pixel gate whose circles all sat near
the node origin. So both new gates run their own control **in the same boot**:

| gate | real | control |
|---|---|---|
| `shard_field_demo` (custom_aabb) | 2 757 shard px | **12** |
| `glass_rain_demo` (G-D43's disposability) | 13 244 differing px mid-flight | **0** after the kill |

Both `push_warning` if the control ever matches the real run.

### 4.7 Two silent failures worth remembering

- **`blit_rect()` between mismatched image formats copies nothing and returns
  nothing.** The filmstrip's first sheet was a perfectly valid PNG of pure
  background while the log reported 8 frames. A viewport image is not RGBA8.
- **A SCRIPT ERROR while the suite printed "0 FAIL".** The rain overlay built its
  field only in `_ready()`, so a test driving `spawn()`/`_process()` without waiting
  a frame hit a null. `run_selftests.py` failed the run; a bare `godot --script`
  would have reported success. Exactly the case CLAUDE.md's selftest rule
  describes, met in the wild.

## 5. Evidence

| | |
|---|---|
| `g4_shard_mechanism_2026-09-05.png` | the mechanism, three panels |
| `glass_shard_family_2026-09-05.png` | the 5 members, every anchor, at true size |
| `glass_remnant_atoms_2026-09-05.png` | the real cut ATOMS, production path, column 0 is the uncut square |
| `glass_remnant_w3_2026-09-05.png` | **the real map** — W3 before/after, ring 0, 383 voxels, registry 49 = board 49 |
| `glass_shard_field_{,nobox_}2026-09-05.png` | the field, and its culling control |
| `glass_rain_filmstrip_2026-09-05.png` | the fall, 8 frames 5 apart, one boot |
| `glass_rain_{settled,midair,after_kill}_2026-09-05.png` | G-D43's diff, all three sides of it |

51 selftests clean, lint and invariants OK at every commit.

## 6. 🟡 WHERE TO PICK UP

**The next task is `G4-4` — the impulse and the scatter table (G-D41 / G-D42).**
It is the one that changes what is on screen: until the shards spread perpendicular
to the pane and along the run, **a pane's rain lands on a LINE**, because that is
what the foot of a pane is. `plan_landings()` gains `{dir, strength, lift}` off the
bomb's own `ring_multipliers` — no second force model — and the landing CELL is
STATE, so the scatter is pure and lives there, never in the presentation.

⚠️ `lift` (skylights) **will be unexercised**: G-D16c/d is unbuilt, CEILING glass
renders opaque and has no horizontal `pane_id`, so no skylight can shatter yet. It
gets a synthetic test and an explicit unbuilt-consumer note.

Then `G6b-3` — the white dust puff on landing, on `DebrisOverlay`'s existing
`CircleField` mechanism, not a new particle system.

### Open questions for the Director

1. **Every rain timing is a placeholder** (`fall_frames_*`, `hold_frames`,
   `fade_frames`, `bounce_scale`, `arc_px_*`). Worth his eye once G4-4 spreads the
   landing — reviewing them before that would be judging the wrong picture.
2. **A remnant whose frame is later destroyed** hangs from nothing. Today it is
   drawn as nothing and reported. Should it FALL instead? That is a behaviour
   decision, not mine.
3. **One `z_index` for the whole rain field** — the trade for the single draw call.
   A rain spanning two storeys draws its upper shards in the lower plane's band for
   the ~40 frames it lives.
4. **A one-voxel-column mullion is not expressible** (`bands` is level-ranged
   only). A thin mullion needs a second authoring axis, which is a format change.
