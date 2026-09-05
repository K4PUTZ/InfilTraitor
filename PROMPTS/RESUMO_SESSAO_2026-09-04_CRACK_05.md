# Session 2026-09-04 (2) — CRACK-05: cooking, and the pane that holds

The previous session is
[`RESUMO_SESSAO_2026-09-04_CRACK_04.md`](RESUMO_SESSAO_2026-09-04_CRACK_04.md).
It closed CRACK-04 and left **exactly two things open**, both named rather than
implied. The Director asked for both: *"Cooking + armored glass."*

`GLASS_MASTER_PLAN` v1.25 → **v1.27**, new **§15** and **§16**, register gains **G-D35**.

| | commit |
|---|---|
| the cook names its hole; the claim rides the Delta | `c1089d67` |
| the pane that held, and the core that says so (G-D28) | `155663c7` |
| the Director's three rulings, and the calibre split | (this commit) |

---

## 1. The cook names its hole — and the measurement is the more useful half

`WorldDelta.glass_openings` carries the blast's holes as a **proposal**, and
`commit(room)` is the only claimer. The split is `scorch_writes`' own, and it
bites harder here: claiming is a WRITE, `build_plan()` runs on every cursor move,
so a claim made in the builder would leave one pending hole per previewed GU and
the next real blast anywhere on the map would wear whichever one matched.

The cell is the flood's **origin**, never the region's centroid — §14.4 measured
asymmetric members 5–23 px from their own centroid, so an unclaimed hole is not
merely default-shaped, it is default-shaped in the wrong place.

### ⚠️ And then the real map said the claim is LATENT

Measured on `maps/GLASS.map.json`, through a new capture action rather than
reasoned from the constants:

    ring 0   glass_punch 8.50   region_radius 42 voxels   flooded 1152 of 1152
    ring 1   glass_punch 5.10   region_radius 22 voxels   flooded  966 of 1152
    ring 2   glass_punch 2.12   region_radius  4 voxels   P(shatter) 5.9 %
    ring 3   glass_punch 0.00   — the blast does not reach

The pane is 48 × 24 voxels, so at rings 0 and 1 **the flood is bigger than the
pane** — it goes whole, and a hole with no glass around it has no rim to shape.
Only ring 2 leaves one, and its roll is deterministic in `(source_gu, pane_id)`:
reproducing the FNV-1a offline over every in-line grenade cell against all three
of the map's panes, **no cell wins it.**

So the claim's effect today is the **record** — a blast hole now keeps its shape
through a perspective flip, which the shot path's holes have done since CRACK-04
and the cook's had not. This is written down rather than left implicit because a
reader of the code would reasonably assume shapes were now varying on screen.

**It also names the next piece.** The fringe is exactly where §6.2's *crack near
a blast it survives* belongs, which is the caller G-D29's `blast_*` sheets exist
for — and it is now one branch away, because a pane that rolled and HELD says so
in the log. Before, "out of reach" and "rolled and held" were the same silence.

## 2. G-D28's `armored` — the class that fixes something already on screen

`ART_ORDER_GLASS_FRACTURE_CLASSES.md` §1 named this the priority of that order
and §6 named it the exception to the "wait for the Director's eye" ordering: it
is the only one of the four that repairs a visible defect, and its vocabulary
does not depend on the open sparse/long-runner question.

**The class needed no new plumbing, and one rule is why it must not get any.**
CRACK-04 already looks a sheet up by a KEY in `fracture_manifest.json`, so
`armored` is a key that is not an opening. What it must never be is a member of
`GlassOpening.FAMILY` — a member is pickable by `pick()` and cuttable by
`refresh_glass_rims()`, and G-D15's whole point is that this pane loses no voxel.
Selftest [17] asserts the absence, and `check_decal.py` now reads the
non-opening ids out of `glass_crack.gd` and REQUIRES the row.

### The two authorities that had to become one

The "a crack with no hole borrows the smallest member's page" fallback was
written once in `sheet_span_for()` and again in `spawn_glass_crack()` — the PAGE
and the QUAD chosen by two copies of one rule, which draws a sheet at another
sheet's scale the day only one of them is edited. **G-D28 is that day.**
`GlassCrack.sheet_id_for()` answers for both now: opening wins › armoured core ›
the smallest member's page.

Chosen by the pane's MATERIAL/CLASS, never by the weapon. [17] pins both edges: a
rifle's `blowout` cannot reach the flag, and V-D's per-placement `breakable`
override beats the material's default (the GLASS map's amber screen).

### The art

An opaque crushed-white core — a solid heart, ~500 facets fading outward, a
ragged lip straddling the boundary — then 26 dense radial needles at a fine
stroke, and a secondary craze field of ~900 short TANGENTIAL cracks between 2.2
and 8.5 core radii. ⚠️ The page was 24 × 12 voxels when he first saw it; §7 is
what it became.

⚠️ **The craze field is its own population, and the first version proved why.**
Reusing the wave generator at a bigger radius drew a handful of long zigzag
polylines out in the dark — the mandala trap's opposite number, reading as
scattered lightning rather than as a field.

## 3. The one that nearly cost 36 files

Threading a stroke width through the presets first derived the TWIN's width as
`w0 * 0.58`, which reproduces the shipped `1.4` only to three decimals. Nothing
would have failed; the twelve openings' 36 sheets would simply have come back
byte-different, for a rounding error in a default, in a generator whose entire
claim is that re-running it reproduces the art.

`stroke_twin` is its own key. Proven rather than argued: `star_deep`,
`chunk_bite` and `crescent_wide` hashed **identically to HEAD's own output, 9 for
9**, and `armored` reproduces itself across runs.

## 4. Evidence

- `glass_armored_sheet_ab_2026-09-04.png` — a **same-binary A/B**: one map, one
  weapon, the armoured branch switched off for the left half. Before, a dark bore
  ringed by a crush rim on glass nothing pierced; after, the crushed core.
- `shot_c05_armored_3_damage.png` — the REAL shot path (`agent_shot`, pistol,
  agent 6,13 → guard 6,7): `glass_armored:s1 cracked=72 dented=0 destroyed=0`,
  and the round carries on into the concrete behind it.
- `glass_armored_span_strip_2026-09-04.png` — the size ruling, one boot, four
  spans, only the quad moving.
- `glass_armored_calibres_2026-09-04.png` — the approved frame beside the
  regenerated `armored_tight` and its `armored_wide` sibling.
- `glass_crack_demo_armored_{before,after,tight_after,wide_after}.png` ·
  `glass_blast_demo_{before,after}.png`.
- Selftests: `glass_shatter` **[20]** and `glass_crack` **[17]**, both proven RED
  with the change removed. **50 clean, 0 failed** across the suite.

## 5. Tools added, and why each is committed rather than scratch

- **`INFILTRAITOR_CAPTURE_ACTION=glass_blast_demo`** — one dev grenade in front
  of a chosen pane, detonated through the real test-zone path, before/after, and
  the shard count **read off the board** rather than counted as issued (CRACK-04's
  lesson). `INFILTRAITOR_GLASS_BLAST_{GU,PANE}` aim it. It exists because the
  selftest cannot answer the question the change is about: whether a claim
  survives the four real seams (commit → erase → flag → flush).
- **`INFILTRAITOR_CRACK_DEMO_MATERIAL`** — the crack demo, aimed at one member of
  the family. The GLASS map's biggest pane is plain `glass`, so without it the
  armoured sheet cannot be photographed at all.
- **A pane that rolled and HELD prints it.** Two silences that were
  indistinguishable, and the second is §6.2's hook.

## 6. Left open

- **§6.2 / G-D29 `blast_*`** — the fringe crack, now one branch away. See §15.2.
- ~~**The armoured page's SIZE is a dial.**~~ Ruled the same day — §7.
- **G-D35, the blast craze family** — §8, and `GLASS_MASTER_PLAN.md` §16.
- ⚠️ **`check_decal.py --material glass` still reports one WIRING FAIL, and it is
  PRE-EXISTING** — verified by running HEAD's own copy of the gate against a
  manifest with the `armored` row removed. It is the shard family's
  `IMPACT_DECAL_MATERIALS` branch, whose own comment says glass must NOT be added
  to that list; the gate has no third state for "correctly absent".

## 7. The Director's rulings on the delivered sheet, same day

Shown the class on the real pane he kept the art and changed three things —
§15.5 carries them, and §15.5a carries the trap inside the first:

1. **10 × 5 voxels**, picked off a one-boot span strip (24 / 18 / 14 / 10, only
   the quad moving).
2. **The core at 64 % opaque**, tuned in the ART (luma 205) and NOT in the
   shader: `crack_opacity` 0.80 is a whole-track dial ruled once.
3. **Two calibre classes** on G-D14's own blowout split — `armored_tight` and
   `armored_wide`, three variants each, differing in nothing but the span.

⚠️ **The strip he chose from moved only the QUAD.** Regenerating at span 10 with
the core still measured in voxels would have kept it at 0.6 voxels while the
needles shrank with the page — a core 2.4× larger relative to its own needles than
the frame he approved (2.5 % of the page at span 24 against 6.0 % at span 10). So
`ARMORED_CORE` became a fraction of the page's half-width. **The distinction is
the class's own:** every other member is anchored in voxels because it is
generated from a real opening, and a hole is a fixed size on the pane whatever
page it is drawn on. `armored` has no hole. That same property is what lets one
preset body serve both calibres with the span as the only difference.

## 8. G-D35 — the last piece of glass, ratified and staged

The Director's brief for the explosion family, with two reference photos of
shattered tempered glass. It is **not** a variation on the bullet classes: no
centre, two axes (destruction × granularity), perforation chosen per voxel, and
**tileable** — which is exactly what makes it cheap where twelve openings × three
variants were not. `GLASS_MASTER_PLAN.md` §16 carries the spec and the B-1..B-5
staging; **B-1 is the trigger**, because art without its caller is the trap this
project has already paid for twice.

Full detail: `GLASS_MASTER_PLAN.md` §15 and §16.
