# BAKE-FIX-08 — Documentation Correction: Undo BAKE-FIX-04's Overstated Claims

> **Corrective prompt, replaces/corrects BAKE-FIX-04. Depends on BAKE-FIX-05, 06, 07 —
> write this last, once their real results are known. An Overlord audit (2026-07-07)
> found BAKE-FIX-04's own prompt mandated "DO NOT TOUCH: any production `.gd` file —
> documentation-only" and "ACCEPTANCE: git diff --name-only shows only .md files," but
> the actual commit (`c8a9467`) modified `junction_resolver.gd`, `voxel_renderer.gd`,
> `baked_tile_lookup.gd`, `room_builder.gd`, `map_compiler.gd`, plus added/archived
> several `.gd` tool files — a direct breach of its own stated scope. It also left
> stale claims in place and propagated BAKE-FIX-02/03's unearned "complete" status
> into `current_state.md`. This prompt is doc-only, for real this time.**

---

## CONTEXT

Three concrete documentation defects, found by direct comparison against the actual
code (not just re-reading other docs):

1. `tools/persistent/OPERATOR_CONTEXT.md`'s Implementation section (~line 494) still
   reads: *"BAKE-FIX-01: Strip baking pipeline (TextureResolver → PerFaceProjector →
   FacadeSampler → BakeCompositor)"* and *"Silhouette alpha matches canonical form from
   PerFaceProjector."* This is backwards: BAKE-FIX-01's entire point was **retiring**
   `PerFaceProjector` and sourcing alpha directly from the real voxel PNG
   (`bake_compositor.gd::_get_canonical_alpha()`), never touching `PerFaceProjector` at
   all. The doc reconciliation pass that was supposed to scrub exactly this kind of
   stale claim left it in place.

2. `docs/production/current_state.md` (~lines 106-114) claims VOXEL-08 "COMPLETE"
   citing BAKE-FIX-02 "Junction column implementation: multi-edge silhouette handling +
   material overrides" and BAKE-FIX-03 "Pixel-identical validation: B3 closure" — both
   overstated per the 2026-07-07 audit (mirroring was a stub until BAKE-FIX-06;
   pixel-diff never ran a real comparison until BAKE-FIX-07). These claims need to
   reflect whatever BAKE-FIX-06/07 actually landed by the time this prompt runs, not
   what was originally hoped.

3. `OPERATOR_CONTEXT.md`'s "✅ B3 CLOSED" line (~line 465) was set on the strength of
   config-toggle tests, not a real pixel diff — same issue as #2, corrected by
   BAKE-FIX-07's real output.

Additionally: this prompt's own predecessor (BAKE-FIX-04) committed production code
changes it was explicitly forbidden from making. Whatever the actual state of that
production code is now (after BAKE-FIX-05/06/07 land), this prompt does not touch it
— only the documentation describing it.

---

## MODULE

- `tools/persistent/OPERATOR_CONTEXT.md`
- `docs/production/current_state.md`
- `tools/persistent/CODEMAP.md` (if it also references PerFaceProjector or the old
  pipeline shape — check)
- `docs/technical/VOXEL_MASTER_PLAN/` or wherever `BAKING_MASTER_PLAN.md` lives now
  (confirm current location — it may have moved during BAKE-FIX-04)

---

## TASK

### 1. Fix the PerFaceProjector claim

In `OPERATOR_CONTEXT.md`'s Implementation section, correct the BAKE-FIX-01 line to
describe what actually happened: master-strip pre-baking with alpha copied verbatim
from the real voxel atom PNG, `PerFaceProjector` and `material_atlas_generator.gd`
retired to `_archive/` as geometrically broken/dead code. Grep the rest of
`OPERATOR_CONTEXT.md` and `CODEMAP.md` for any other lingering `PerFaceProjector`
references and correct them too.

### 2. Reconcile current_state.md against what BAKE-FIX-05/06/07 actually delivered

Read the real completion reports from BAKE-FIX-05, 06, and 07 (once they exist) and
rewrite the VOXEL-08/09 section of `current_state.md` to state precisely what's true
as of that point — not what was originally planned, not what BAKE-FIX-02/03 originally
(incorrectly) claimed. If B3 is still open per BAKE-FIX-07's honest result, say so.

### 3. Add a process note

Add a short note (in `OPERATOR_CONTEXT.md` or wherever process learnings are tracked
in this repo) documenting the actual failure pattern from this round: substantive code
changes landing under an unrelated commit label (BAKE-FIX-02's work inside the
BAKE-FIX-04 commit), and a "documentation-only" prompt breaching its own stated scope.
This isn't about assigning blame — it's so the same drift is easier to catch earlier
next time (e.g., a reviewer checking `git diff --name-only` against a prompt's stated
DO NOT TOUCH list before accepting a completion report).

---

## DO NOT TOUCH

- Any `.gd` file. `git diff --name-only` at the end of this prompt must show only
  `.md` files — this is the same acceptance bar BAKE-FIX-04 was given and broke; it is
  not optional this time.

---

## ACCEPTANCE

```bash
git diff --name-only
# expected: only .md files listed, nothing else
grep -rn "PerFaceProjector" tools/persistent/OPERATOR_CONTEXT.md tools/persistent/CODEMAP.md
# expected: no hits, or only hits inside a clearly-labeled historical/archive note
```

- Completion report quotes the exact before/after text for each corrected claim.
- Bump `VERSION` per repo convention.

---

**Scope:** ~3-4 doc files · closes out the BAKE-FIX-0X corrective wave once 05/06/07
have landed.
