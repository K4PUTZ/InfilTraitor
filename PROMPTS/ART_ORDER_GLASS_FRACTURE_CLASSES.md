# ART ORDER — the four fracture classes (G-D28 / G-D29)

**Stage:** GLASS_MASTER_PLAN §13.2 **S-4**. Written 2026-09-02, immediately after
S-1/S-2/S-3 landed, because §13.2 says so in as many words: *"Written only AFTER
S-1, because S-1 is what makes the format contract real."*

**Status:** 🟡 ORDER WRITTEN, ART UNBUILT. Nothing below is delivered yet, and
§6 says plainly why I stopped at the order rather than generating six sheets.

The two sheets that exist (`fracture_glass_tight.png`, `fracture_glass_wide.png`,
delivered 2026-09-02 by [`ART_ORDER_GLASS.md`](ART_ORDER_GLASS.md)) stay in
service unchanged. This order is what turns them into a family of four.

---

## 0. What changed under the art, and it is all good news

CRACK-01 drew the crack inside the voxel shader off a re-anchored atlas page.
CRACK-02 (G-D27) made it a **sprite over the pane**, and that removed three
constraints the old order had to live with:

| was | is now | why |
|---|---|---|
| exactly **1024 × 512**, the facade page | **any size**, aspect 2:1 | the sprite is scaled to `GlassCrack.SHEET_SPAN_*` VOXELS; pixels are resolution, not geometry |
| exactly **two** sheets, and `check_decal.py` enforced the pair | as many as the roster declares | the count lives in `GlassMaterials.FRACTURE_WIDTHS`, which the gate READS rather than duplicates |
| alpha irrelevant, luma is the ink | **unchanged** | the sprite shader does luma→alpha at sample time; author grayscale on black, no matting |
| the ink centroid at the page centre | **unchanged for the impact classes** | `Sprite2D.centered` puts the page centre on the impact; an off-centre bore lands every crack a fixed distance from the round that made it |

Both halves of §13.3's contract moved in S-1's own commit (`a6cb797f`):
`TextureResolver`'s `fracture_` branch accepts any size (it must still EXIST — an
unrecognised prefix is `Tier.NONE`, the generic atlas, and **no error at all**),
and `check_decal.py` swapped the size rule for the aspect one. So new art will be
judged, not silently dropped.

---

## 1. The four classes (G-D28)

The Director's reading of `REFERENCES/Vidro`, 2026-09-02: *"o tiro a prova de
balas não é uniforme, ele tem um centro assim"*. **The distinguishing feature is
the CENTRE, not the spread.**

| id | centre | field | trigger, already in the code |
|---|---|---|---|
| `tight` | small **empty** bore, 1 voxel across | sparse; a few LONG runners | `WeaponDef.blowout < 0.5` — pistol, shotgun pellet (G-D14) |
| `wide` | **empty** bore, irregular outline, 2–4 voxels | radials **plus** concentric arcs | `blowout >= 0.5` — rifle-class (G-D14) |
| `armored` | an **OPAQUE CRUSHED-WHITE CORE** — pulverised glass, never a void | dense radial needles + a wider secondary craze field | `glass_armored`, and INDESTRUCTIBLE screens (G-D15 / G-D16): *"estilhaça mas não rompe"* |
| `blast_0` `blast_1` `blast_2` | **none at all** | spread crazing, the shockwave case | the cook's path, when a pane survives a blast (§6.2) |

⚠️ **`armored`'s core is the one that cannot be got wrong by half.** It is not a
smaller hole — it is the opposite of a hole. The round did not pass through, so
there is nothing to see behind: the centre must read as WHITE PULVERISED GLASS,
brightest at the middle, and the sprite is additive so white there means opaque
there. A void in that class contradicts the rule the class exists to express.

## 2. `blast` is three patterns and twelve looks (G-D29)

*"vamos usar um conjunto de padrões nos painéis, digamos 3, que podem ser
escolhidos aleatoriamente e flipados vertical e horizontal. Assim teremos uma
variação legal, sem consumir quase nada a mais de memória."*

Three textures, two flip bits, twelve apparent variants. **The choice is not new
machinery**: it comes from the B4 FNV-1a the destruction stack already uses
(`FacadeSampler._fnv1a_hash`) over `pane_id` + panel index, which makes it
deterministic and replay-safe by the same rule as every other per-cell choice in
the project — and the same hash yields the two flip bits for free.

Consequences for the ART, and they are the reason this is worth saying here:

- **Author the three so they do not rhyme.** Twelve looks from three images only
  works if the three are genuinely different fields; three variations on one
  layout will read as one texture flipped, which is worse than one texture.
- **A `blast` sheet must survive both flips.** No lettering, no lighting
  direction, no top-heavy composition — anything with an up or a left will
  announce the flip.
- **No centre.** Not a faint one, not an implied one. A centre is what makes it
  read as an impact, and this class is the one that was not hit.

## 3. What the reference set actually says (§13.4, read 2026-09-02)

Two findings that **contradict the art already shipped**, so they are the
substance of this order rather than a footnote:

1. **A real bullet hole is SPARSE with a few LONG runners.** In `bala-perdida-1`
   and `rachaduras-do-furo`, density collapses within a couple of voxels of the
   bore, and what remains is 4–8 fine lines running far — one reaches the frame.
   **The shipped procedural sheets are dense and even out to the edge: the exact
   opposite.** `check_decal.py` measures this today — `tight` covers 2.61% of its
   page and reaches 3.4 × 3.6 pane voxels from centre at its 20 × 10 span. The
   reference says that reach should be several times larger and the coverage
   near it several times lower.
2. **Asymmetry is the norm.** None of the six references is symmetric. The four
   "symmetry defects" the G-ART session fought (`ART_ORDER_GLASS.md` §6.2) were
   the generator pulling toward a regularity real glass does not have. Do not
   fight it again; spend the effort on the runners.

🔒 **`vidro buraco maior` (depositphotos) and `rachaduras-do-furo` (dreamstime)
are WATERMARKED STOCK COMPS.** Legitimate to read for vocabulary, illegitimate to
derive pixels from. Delivery stays procedural or Director-authored — the same
discipline D57 imposes, and the Freepik reference already cost this track once.

## 4. The format contract, in one block

```
name        ASSETS/materials/glass/fracture_glass_<id>.png
            <id> ∈ GlassMaterials.FRACTURE_WIDTHS — the roster the gate READS
size        free, aspect 2:1 ± 2% (the span is 2:1: 20x10 tight, 44x22 wide),
            at least 128 px on each axis. 1024x512 remains a good default.
colour      GRAYSCALE on BLACK. R==G==B within 2/255. Luma IS the ink; the
            sprite shader does luma -> alpha. Alpha in the PNG is ignored.
coverage    0.1% .. 90% of the page above luminance 8
origin      impact classes (tight/wide/armored): ink centroid within 6.25% of
            page width and 12.5% of page height of the centre — the sprite is
            `centered` on the impact.
            blast_*: the origin rule DOES NOT APPLY and the gate must be told
            so (see §5, step 2) — a blast field has no centre by definition.
gate        python3 tools/persistent/check_decal.py --material glass
```

## 5. The wiring that must land WITH the art, not after it

Six steps. Steps 1–2 are the ones that fail silently if skipped.

1. **`GlassMaterials.FRACTURE_WIDTHS`** grows to
   `["tight", "wide", "armored", "blast_0", "blast_1", "blast_2"]`. This is the
   roster; `check_decal.py` reads it off that one line, so a name only the art
   knows about is art nothing asks for.
2. **`check_decal.py` learns the class column.** `FRACTURE_ORIGIN_SLACK_*` must
   not be applied to `blast_*`, or correct art fails the origin rule. Add the
   exemption in the same commit as the roster, and make it a NAMED class rule
   rather than a special case on a string — G-D28 has four classes and this file
   currently knows two.
3. **`GlassCrack.SHEET_SPAN_*`** gains a span for each new class. `armored`
   should be near `tight`'s (a round that did not pass through did not spread far
   either); `blast_*` is a PANEL-sized field, so its span is the panel, not a
   radius — expect it to want its own selection path rather than
   `sheet_span(wide)`.
4. **The selector.** `GlassCrack.wide_for_blowout()` answers a two-way question
   and the family is now four-way. It becomes `sheet_for(material, glass_class,
   blowout, source)` — and `armored` is chosen by MATERIAL/CLASS
   (`GlassMaterials.shatters_whole_pane` / `stops_a_round`), never by blowout.
5. **The blast trigger.** Nothing calls the crack from the cook today: §6.2 of
   GLASS_MASTER_PLAN ("cracking near a blast it survives") is the caller
   `blast_*` exists for, and it is UNBUILT. Ordering the art without that trigger
   would ship a fourth class nothing can reach — the same "built but never
   triggered" trap this project has already paid for twice
   (`cleanup-2026-07-26-wiring-gaps`). **Build the trigger first or order
   `blast_*` last.**
6. **The hash.** `FacadeSampler._fnv1a_hash(pane_id + panel index)` → one of the
   three sheets plus two flip bits. Deterministic, replay-safe, no new machinery
   (G-D29). The flips are `Sprite2D.flip_h` / `flip_v`, which cost nothing —
   ⚠️ but the sprite's transform is the pane's basis (S-1), so flipping the NODE
   is not the same as flipping the TEXTURE. Flip in the shader's UV, or the quad
   mirrors instead of the image.

## 6. ⚠️ Why the art itself is not in this commit

The order is written; the six sheets are not. This is a stated stop, not an
omission:

- **The generator would have to produce the opposite of what it produces now.**
  §3.1 is not a tuning note — sparse-with-long-runners is a different
  distribution from dense-and-even, and `blast` (no centre) is not a preset of a
  radial generator at all. `tools/persistent/gen_fracture_sheet.py` builds
  everything outward from a hole; two of the four classes do not have one.
- **The look is the Director's, and it has been rejected three times already
  this track.** Six sheets generated against a guess is six rejections. One
  sample of the sparse/long-runner `tight` — the class that already exists, so
  the comparison is honest — is the cheap next step, and it needs his eye.
- **`blast_*` has no caller** (§5 step 5). Art for a trigger that does not exist
  is the trap named above.
- **G-D30's dial is still open** and it changes how much of any of this is
  visible on a broken pane. The triptych is captured and waiting
  (`glass_crack_cut_triptych_2026-09-02.png`).

**The next step is one `tight` sample at the reference's density, at true size on
the GLASS map, for a yes or no.** Everything in §5 follows the yes.
