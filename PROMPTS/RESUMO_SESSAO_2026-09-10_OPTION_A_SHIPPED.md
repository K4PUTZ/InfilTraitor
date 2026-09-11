# Session 2026-09-10 (late) — Option A shipped: glass is an ordinary tile

Previous session:
[`RESUMO_SESSAO_2026-09-10_RENDER_ORDER.md`](RESUMO_SESSAO_2026-09-10_RENDER_ORDER.md).
**Its resume point — build Option A's missing half, render A vs B vs today — is
DONE.** The Director judged the set, ratified A, and asked for it default ON and for
B's code to go. The live record is
[`RENDER_ORDER_MASTER_PLAN`](PLANNING/RENDER_ORDER_MASTER_PLAN.md) §10b.8–§10b.10.

| | commit |
|---|---|
| Option A built (gated) and all four candidates rendered — neither passed as built | `10119dce` |
| The seam: side sliver by exposure, not by `pos == 7` — the Director's diagnosis | `5ed461ef` |
| Option A ratified — tile, clip and seam cull default ON; 3 real-map defects fixed | `3f63af7c` |
| Option B removed; the clip's coplanar false positive (the Director's report) fixed | this session's last commit |

---

## 1. ⛔ RESUME POINT

**The depth track is closed as a mechanism.** Nothing is waiting on a Director call.
What is owed, in the order it would bite (plan §10b.10):

1. **The clip ignores OPAQUE destruction.** The crack occupancy rebuilds only when
   GLASS is erased, so destroying the wall that covered part of a pane leaves the web
   cut where the wall was, until the next glass erase. The fix costs one occluder
   index (~13 ms on GLASS) per flush while any crack exists — measure it on a
   detonation cook before choosing.
2. The seam index is built in `render()` and not refreshed by dirty passes: a pos-7
   voxel beside a NEW hole keeps no side sliver until the next full render.
3. A device run — every number in this session is M1 at 1280×720.
4. The hidden glass STATE layer holds a second copy of every glass cell; memory cost
   unmeasured (RAM is the mobile constraint).

---

## 2. What shipped

- **Glass is an ordinary tile in its level's opaque layer** (`INFILTRAITOR_GLASS_TILE`).
  A `TileMapLayer`'s own draw order IS iso depth order (Q8), so no container, no flat
  top z, no Y-sort. `_glass_layers[level]` stays the authority every glass system
  reads and is hidden; `_glass_tile_sync()` mirrors it into `_layers[level]`. Each
  glass atom carries `TileData.material` → `glass_tile.gdshader`, a plain-alpha fit
  of G-D1 exact over one reference grey.
- **The crack sprite is clipped** where an opaque cell covers the pane
  (`INFILTRAITOR_GLASS_CLIP`): it must be nearer, draw after (level ≥ the glass), and
  stand in front of the pane's PLANE.
- **The side sliver is painted by exposure** (`INFILTRAITOR_GLASS_SEAM_CULL`), which
  is what the ratified G1 rule always said.
- All three default ON; `=0` restores the old path for comparison. Option B's code is
  gone.
- **Accepted costs:** G-D1's coloured multiply → plain alpha; G-D18b stays relaxed
  (an agent behind a pane is no longer tinted); pane-over-pane now compounds (ratified
  as correct).

**Cost** (vsync OFF — see §3.3): `RENDER_ORDER` A 4.6 ms vs B 7.9 ms; GLASS grenade
frame A 3.1 ms / 1 386 draw calls vs the old path 3.3 ms / 1 632.

---

## 3. ⚠️ FINDINGS worth carrying

### 3.1 The fixture could not show the real map's defects

Every one of the four defects fixed on the way to default ON was invisible on
`RENDER_ORDER` and obvious on GLASS, because the fixture's panes stand alone and
GLASS has brick-framed windows, a room front wall and a floor stack:

| | defect | why the fixture missed it |
|---|---|---|
| 1 | occluder index 40 ms × 11 per grenade | a 16×12 map is cheap to walk |
| 2 | the floor "hid" every pane's foot row | same failure, but no crack reached a foot |
| 3 | the reap path erased glass with no mirror sync | the fixture has no frames to fall |
| 4 | coplanar bricks / window bands counted as occluders | no pane touches opaque wall in its own plane |

CLAUDE.md already says a green selftest does not mean a feature fires on the real
map. This is the same rule one level up: **a green FIXTURE is not the real map
either.** Flipping a default is the moment to run the real map's demos.

### 3.2 The Director diagnosed the seam, and the code agreed

*"a área dos voxels do fim de um painel se encontram e acabam se somando"* — exactly:
`_glass_face_mask()` put the side sliver on the last column of EVERY GU. Proven with
a kill switch first (`INFILTRAITOR_GLASS_NO_SIDE=1` removed the bands and the
triangles, and also a real pane end's thickness), then fixed by exposure. Two steps,
because the kill switch alone could not tell "the sliver" from "any sliver".

### 3.3 Vsync hid B's cost

At vsync ON every configuration read 16.7 ms and B looked cheaper by draw calls
(+3.5% vs A's +9%). With `INFILTRAITOR_NO_VSYNC=1` B was **+3.3 ms/frame** over A.
Draw calls are not frame time.

### 3.4 An absence check passed against the thing it was guarding against

`glass_transparency_selftest` [1] asserted "the opaque layer at the glass level holds
ZERO cells". Under Option A that is false — and it kept PASSING, because the mirror
is deferred and the suite asserted before it ran. Replaced by identity checks.

### 3.5 One max-depth number was enough, three times

The clip's index stores only the max depth per screen bucket. Within a bucket the
level, `x` and `y` all grow strictly with depth (`8d − 20L ∈ [8r, 8r+7]`, column
fixed), so the deepest cell is also the highest and the one furthest in front. Both
correctness fixes (level ≥ glass, in front of the plane) and the floor skip are EXACT
with no extra storage.

---

## 4. Instruments

| | |
|---|---|
| `INFILTRAITOR_GLASS_TILE=0` / `GLASS_CLIP=0` / `GLASS_SEAM_CULL=0` | the old path, per piece |
| `INFILTRAITOR_GLASS_CLIP=diag` | paints every glass cell the clip calls hidden |
| `INFILTRAITOR_GLASS_NO_SIDE=1` | the seam kill switch (strips real pane ends too) |
| `INFILTRAITOR_FRAME_PROBE=1 INFILTRAITOR_NO_VSYNC=1` | honest ms/frame |
| capture recipe | `INFILTRAITOR_AUTO_SCREENSHOT=1 INFILTRAITOR_MAP=<map> INFILTRAITOR_CAPTURE_ACTION=glass_crack_demo\|glass_blast_demo\|glass_reap_demo`; macOS has no `timeout` — `perl -e 'alarm shift; exec @ARGV' 150 <godot> …` |

**Every commit:** 52 selftests clean, `project_lint.py` clean, `check_invariants.py`
clean, CODEMAP fresh.
