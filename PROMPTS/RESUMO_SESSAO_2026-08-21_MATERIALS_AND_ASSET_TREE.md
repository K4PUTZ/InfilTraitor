# RESUMO_SESSAO — 2026-08-21 (b) · SOFT MATERIALS, M3-1/M3-2, AND THE ASSET TREE

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-21_ALPHA_MATERIALS_MASTERPLAN.md`
**Commits:** `9b66d869`, `cda320b8`, `c7520ccd`, `7c7fb6ec`, `7abccf2d`,
`fd67e641`, `15cf23df`, `3d4cec50`, `0577336e` — all pushed to `main`.
**Gates at close:** lint 213 ✅ · selftests **37 clean / 0 failed** ✅ ·
invariants ✅ · CODEMAP ✅ · `check_facade --all` 10/10 ✅ ·
`check_decal --all` 45/45 ✅ · atom diff **0 of 363** ✅.

---

## Read this first if you are resuming

**The material art tree moved.** Everything for a material is now in
`ASSETS/materials/<id>/` — facade, slab, atom, halves, decals and its JSON row.
`ASSETS/*` is gitignored, so **the file moves are not in the repo**: on any other
machine run `python3 tools/asset_generation/migrate_asset_tree.py --apply`, then
`--import`, then both gates. Skipping that gives `Tier.NONE` on every material,
which renders something and reports nothing.

**Open and waiting on the Director:**
1. **M2b — the nine brick decals** (`PROMPTS/ART_ORDER_BRICK_DECALS.md`, paths
   already point at the new tree). The only thing blocking M2.
2. **Does a passage have to reach the ground?** (§3.2a) — `passage_class()`
   answers geometry, not reachability, and deliberately did not decide this.
3. **Ten orphan `.import` sidecars** in the old folders, dead by construction,
   left alone because deleting is the Director's call.

**Next unblocked build task: M3-2b, half-thickness elements** — still the
milestone's largest single item, and still not fire.

---

## 1. MAT-SOFT-01 — the ruling had teeth in the data (`9b66d869`)

> Director: *"Não vamos ter decals nos materiais moles porque eles não ficam
> cracked e nem dented, apenas furam ou queimam."*

Read as art it is a task-list edit. It is not one: `dent_factor` was
0.10/0.15/0.22 on fabric/cardboard/plywood, and a material with no authored
family is **not unmarked** — it falls to the GENERIC family. A blast was marking
cardboard with a grey dent nobody ordered.

Measured on the real map, both sides from one binary via a stash, same cells,
identical punch list (2.11–2.75):

```
BEFORE  fabric:s1  cracked=0 dented=17 destroyed= 1   (breach 2.75)
AFTER   fabric:s1  cracked=0 dented= 0 destroyed=18   (breach 0.00)
```

Every pellet sat just *under* the derived breach, which is why almost the whole
shot marked instead of going through. Plywood repeats it (38 voxels, all holes);
**brick is the control that must not move** and did not (15 dented + 8 destroyed).

**The threshold alone could not express it** — `damage_state_for()` returns
CRACKED *before* it reads `breach_min`, so a breach of 0.0 still leaves the
CRACKED floor underneath. The rule is a TIER capability (`HOLE_ONLY_MATERIALS`);
the threshold is downstream. The three derived `DESTROY_MIN` rows are retired
rather than zeroed — one source, not two.

**Glass is deliberately NOT in the array.** D22 gives it the same *no mark* half
but the other answer to a weak hit (*"buraco feito, ou não feito"*), which needs
an INTACT return the ladder has never produced. It joins at M4b, or not at all.

⚠️ **One measurement the milestone now owes itself:** fabric went from 19 to
**36** voxels per shotgun burst, because every pellet now breaches and takes its
neighbours *and* the sibling slice. `neighbour_count_for()` reads RAW punch, and
fabric's is ~7 against a ceiling of 1.60 — so every weapon is pinned at all 8
neighbours. Whether a *pistol* should erase 9 voxels of cloth belongs to M3-5's
matrix, per weapon, measured.

## 2. M2 became nine files, and the gate was earned first (`cda320b8`)

21 → **9**, brick only, following concrete exactly. `check_decal.py` is the decal
counterpart to `check_facade.py` and exists for the same reason: a mis-delivered
decal renders without erroring. It passes all 45 shipped decals unchanged and was
run red on five real failure modes.

**Two of its own checks were wrong and the shipped art caught them** — the
constant parser split on the `[` in `Array[String]` and reported concrete (wired
and complete) as unwired; and `earth` was called an orphan because it rides
`IMPACT_FLOOR_MATERIAL`, a different constant. That is `check_facade.py`'s own
first-run mistake repeating, and the reason a new gate is run against known-good
work before it is trusted.

## 3. M3-1 — the light win is half free (`c7520ccd`)

`INFILTRAITOR_CAPTURE_ACTION=light_burn_probe`, four passes in ONE boot:

```
CONTROL   (nothing destroyed)      cells_gone=   0  bucket_changed=  0
ONE VOXEL ((247, 24) lvl 0)        cells_gone=   1  bucket_changed=  2  (brighter 2)
WALLS     (2047 more voxels)       cells_gone=1984  bucket_changed=260  (brighter 260)
OBJECT    (+1672 slab voxels)      cells_gone=3080  bucket_changed=262  (brighter 262)
```

The control reporting **0** is what makes the rest mean anything. §3.4's **visual**
claim is confirmed. **The lamp's shadow does not move**: 3 burnt GUs are still in
`_blocked_cells`, a GU-resolution structure `RoomBuilder` builds and
`LightingController` re-feeds only on a rebuild. A burnt-away wall still throws a
shadow — M3-3 owns that and did not know it.

Three findings from *looking at the capture*:

- **"Burns entirely" is not "destroy the edges."** A fabric block is 16 `Slice`s
  **plus** FLOOR (1152) and CEILING (520) `Slab`s. M3-3's object scope must span
  both registries.
- **An object that burns entirely leaves its JUNCTION COLUMNS**, proven against an
  `INFILTRAITOR_SKIP_JUNCTIONS=1` control where they vanish.
- **`_tic_slab_system()` clears slab dirty flags without rendering them.** Its
  comment still claims `_slab_registry` is always empty. Measured: the OBJECT pass
  moved `cells_gone` by **zero** until the probe stopped going through the TIC
  pump, then by 1096. **Reported, not fixed.**

Also worth knowing when reading those captures: `voxel_destroyed` fires per voxel
and room.gd dispatches it to the smoke overlays, so erasing 3 080 cells in one
frame raises a dust cloud that **hides the hole**. Three runs photographed the
cloud; the census settled it. The probe now waits 240 frames.

## 4. M3-2 — `PassageQuery` (`7c7fb6ec`)

`passage_class(edge, registry) -> NONE | CROUCH | STANDING` plus
`clear_storeys()`. Pure. **Half-thickness-safe on day one at no cost** — it
iterates `slices_of_edge()`, *the storey-faces that exist*, so a one-faced fabric
panel satisfies "both sides clear" by clearing the one it has.

Real map, through the burn probe: `{"NONE": 8}` → `{"STANDING": 8}`. The 15
fixture assertions were proven able to fail against two real breaks.

**It refused to decide one thing** (§3.2a): must a passage reach the ground? Two
clear storeys at heights 2 and 3 are geometrically STANDING and practically a
hole in the sky — but a *window* is precisely a passage that does not reach the
ground. `clear_storeys()` says WHERE; whoever wires movement gets a ruling first.

## 5. ASSET_TREE_REFORM — one folder per material (`7abccf2d` … `0577336e`)

Director's ask, and the measurement said it was far smaller than it sounded:
**~113 files, six real path constants**, with `actor_bakes/` (~5 800 PNGs, a
different axis) explicitly out.

Three rulings: **only the folders move**, **do it now** before the brick art, and
**delete the `brics/` duplicates** (9 files, md5-identical to concrete's decals,
referenced by nothing).

### What the reform ran into

**`git mv` failed on the first file.** `.gitignore:52` excludes `ASSETS/*` — *no
material PNG is tracked*. So: a full backup first (123 files, aggregate md5
`fcc8110b1ab78c8290d65b3e237c9af1`), plain moves, and the migrator committed as a
tool because **another machine cannot get this tree from a pull**.

**The staging was revised, not followed.** "Code accepts both → move → flip" needs
a window where art lives in two places, which the plan rejects on its own terms.
Split by asset **family** instead: each lands as one commit that moves its files,
flips its code and passes all three gates.

**The gate was earned before it was trusted**: two `export_atoms` runs of the same
code, 363 atoms, byte-identical.

### And what it found on the way

- **The atom gate reported 0 differing while eight assets were broken.**
  `earth_0..7` are pseudo-materials, so "folder = atom id" built
  `materials/earth_0/`. B6's loud-fail caught what the gate could not; the rule is
  now `BakePolicy.material_folder_for_atom()`.
- **`voxel_decal_selftest` could not detect a missing decal.** It asked
  `ResourceLoader.exists(p) or FileAccess.file_exists(p)`, and `ResourceLoader`
  answers from the compiled `.ctex`, which outlives its source. Same binary, one
  deleted file: **lenient 37 PASS/0 FAIL, strict 36 PASS/1 FAIL.** Tightened.
- **`.gitignore` needed six new lines** or the move would have silently dropped
  every balance number out of version control.

### Proof

```
backed up (excluding brics): 99 unique (name, md5)
present after the move:      99      MISSING: 0   NEW: 0

same deterministic PLAYGROUND frame, before the reform vs after:
differing pixels: 0 of 921600   max channel delta: 0
```

New: `material_tree_selftest` — folder ↔ registration ↔ facade ↔ complete decal
family, each check proven red on a real defect, and the one weak direction
labelled as weak rather than quietly counted.

---

## Carried forward, unrelated

- **The rifle's and pistol's posed frames** —
  [`BAKE_ORDER_WEAPON_GRIPS.md`](BAKE_ORDER_WEAPON_GRIPS.md).
- **The aim warm is ~500 ms**, still the largest number in a shot.
