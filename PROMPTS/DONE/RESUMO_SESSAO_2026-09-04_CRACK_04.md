# Session 2026-09-04 — CRACK-04: the hole becomes a named shape

The previous session is
[`RESUMO_SESSAO_2026-09-02_CRACK_02.md`](RESUMO_SESSAO_2026-09-02_CRACK_02.md).
It ended with CRACK-03 built, G-D32 ratified-and-unbuilt, and G-D33 proposed.

**This session replaced the mechanism under all three.** `GLASS_MASTER_PLAN`
v1.24 → **v1.25**, and the register gained **G-D34**.

| | commit |
|---|---|
| the capture harness, rebuilt as a committed tool | `a4434e21` |
| the opening family — the hole is a known shape | `20fe55d8` |
| four irregular members, and two defects only asymmetry could show | `061e7d6e` |
| a twelfth: `gash_wide`, the elongated one | `5efb6790` |
| the play path, keyed in BASE space | `87f01d30` |
| the decal's inner void IS the opening, cut at runtime | `a01f6868` |
| ⚠️ the shard rim had never once reached the screen | `29a147ab` |
| the sliver standing inside the hole; the sheet sized to the opening | `e16a7403` |
| a same-boot instrument for the crack's alignment | `ba43f167` |
| the guards' opening turn was the capture noise — 0 px | `a5a2b9c0` |
| 36 fracture sheets, each generated FROM its opening | `d2040002` |
| the per-opening sheets wired; the round-hole pair retired | `9bd5a751` |
| ⚠️ the crack's origin was half a run step off, on every face | `7103f9ac` |
| all twelve on the real map; the demo stops lying about the hole | `aeafa27d` |
| a diagnostic backdrop, and the fit closed at under a pixel | `21151e35` |
| ⚠️ the sheets were drawn vertically mirrored; the centre feathers | `14b6a4ec` |

---

## The ruling, and the correction inside it

The Director's finished diagram (`REFERENCES/Hole.png`) arrived first, and the
first reading of it was **wrong in a way worth recording**: it says *"inner decal
border slightly larger than the hole"*, and I took that to mean the decal owns the
shape. He confirmed it — *"o decal é o dono da forma"* — and then, watching me
start to flood-fill the shipped sheets' central voids to RECOVER that shape,
stopped me and refined it:

> *"Vamos usar formatos simples internos conhecidos […] Criamos uma família de
> aberturas para serem escolhidas. Os decals se adaptam a esses formatos internos
> […] Dessa forma já sabemos como construir o buraco sempre, independente de como
> vai ser o decal."*

That second step is the design. If the shape lived in the art, no hole could be
built until that class's art existed. A known family inverts it: the OPENING is
the authority, the decal adapts, and beyond the hole the art is free.

**The recovery was viable and is now moot** — measured on the two sheets that
existed, `fracture_glass_tight`'s void was 0.29 voxels across and `_wide`'s 2.02,
both cleanly enclosed. Recording it because "it could not have worked" would be
the wrong lesson; it could have, and it would have coupled the engine to art that
does not exist yet.

## Five defects, and what each one's shape teaches

Every one was invisible to a gate that existed, and every one failed in the
direction that looks right.

1. **The shard rim had never reached the screen, since CRACK-03.**
   `refresh_glass_rims()` said 12 cells cut; the tilemap said 0. The overwriter is
   the feature's own neighbour — the CRACKED ring a hole always crazes re-renders
   those cells. CRACK-03's commit celebrated needing *"no registry, no dirty flags
   and no per-cell state"*, which is precisely why nothing could restore them.
   ⚠️ And my first repair sat behind `refresh_glass_rims()`'s early return, so the
   board still read 0 with the fix written: **the pass that overwrites a shard
   flags no erase at all, so the seam that must repair it is the one where nothing
   happened.**
   → *A count of operations ISSUED is not a reading of the board.*

2. **The crack's origin was half a run step off, on every face, since CRACK-02.**
   One constant `(0, -6)` from a derivation whose rows were right and whose column
   was not — a face occupies HALF the quad's width. Selftest [10] reported
   0.00000 px throughout, because it compares the sprite against the function that
   builds it: exact and tautological at once.
   → *A test that asks one authority to confirm itself is green forever.*

3. **The sheets were drawn vertically mirrored.** The generator draws in image
   space (y down); the radii are sampled in pane space (y up). **The mirror is the
   identity on every regular star at phase 0**, so eight of twelve looked perfect
   and only the four asymmetric members showed it — exactly the four the Director
   circled.
   → *A defect that is the identity on most of its inputs cannot be found by
   sampling inputs.*

4. **An asymmetric opening's centroid is not its impact.** A claim matched to a
   region by centroid missed every asymmetric hole; and `chunk_bite`'s two
   swallowed cells touch only diagonally, so 6-connectivity split them and the
   orphan stamped a second opening three cells away. Both predated the irregular
   members and were invisible to all seven symmetric ones.
   → *Symmetry hides bugs. The first lopsided input is a test, not a feature.*

5. **The generator was not deterministic.** `hash(opening_id)` — Python randomises
   string hashing per process. Different art every run, through the standard
   library's front door.

## Three instruments earned, one of them the Director's

- **`count_glass_shards()`** — reads the tilemap back. The only reason (1) was
  findable.
- **`INFILTRAITOR_FREEZE_GUARD_TURN=1`** — his own diagnosis: guards ease from
  forward to their posted facing at boot, so two captures catch different points
  of the sweep. Measured, two boots of the same capture: **34 px free, 0 px
  frozen.** This project requires a pixel-diff gate to be EARNED by diffing two
  runs of the same code; no capture on this map could clear it before.
- **`INFILTRAITOR_GLASS_DIAG=1`** — his request, and not cosmetic. On a two-tone
  backdrop a colour mask of "what shows through the hole" is biased by which half
  the hole sits on; it returned a confident **+14.3 px that meant nothing**. Flat
  floor, and the hole reads NEUTRAL against BLUE glass.

⚠️ **I also over-generalised a number and used it to dismiss real measurements
twice:** "two boots of this map differ by tens of thousands of pixels" is from the
RIM A/B, a different capture action carrying the agent's selection marker. On the
crack demo it was 34.

## The fit, closed

Sprite centre (538.0, 354.9). The eight SYMMETRIC openings all land within
**1.0 px** of the impact, on a board where a voxel face is ~18 px across. The four
asymmetric ones read 5–23 px off and are not misaligned — a lopsided shape's
centroid has no reason to sit on its own impact, which also means **only a
symmetric member can test alignment**.

## Also destroyed and restored

`check_decal.py`, once. A span replacement took `s[s.index(A):s.index(B)]` with B
behind A in the file, so the slice was empty and `s.replace("", new)` inserted the
block between every character — 48 557 copies. Restored from git and redone with
an assertion that the anchors are in the right ORDER.

## Left open, both named rather than implied

- **The cook does not claim an opening.** Every blast hole takes
  `GLASS_OPENING_DEFAULT`, so a grenade repeats one shape.
- **G-D28's `armored` class.** A pane that only crazes borrows the smallest
  member's page — a 0.8-voxel void where a stopped round deserves a crushed-white
  core.

Full detail: `GLASS_MASTER_PLAN.md` §14.
