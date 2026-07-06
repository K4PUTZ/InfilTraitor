# FIX-DIVIDER-MATERIAL-01: Dividers Become Real `solidblock_` Material, Not Fake `block_SE`

**Status:** Ready for implementation
**Predecessor:** FIX-EXTERIOR-WALLS-01 (exterior walls now first-class Edges), BLOCK-01/01b (the `solidblock_<material>` primitive this migrates dividers onto)
**Directive:** part of "make the whole world voxels" before OCCLUSION & DESTRUCTION — dividers are the last interior-wall primitive still on the degraded legacy path.
**Scope:** `MapCompiler`'s `dividers` loop always emits `"block_SE"`, a sprite-suffix convention with no material — it lands in `EdgeExtractor`'s untouched legacy `block_` branch, which extracts a fake "material" (`"SE"`, never a real `MaterialRegistry` entry) and renders via `render_block()` with no `Edge` — no baking, no theming. Add a `material` field to each divider group; emit `solidblock_<material>` instead, so dividers go through the exact same proven, baked, themed pipeline solid GU blockers already use.
**Effort:** ~1 hour
**Risk:** Low — additive field, one string change in `MapCompiler`; the legacy `block_` branch in `EdgeExtractor` is untouched (still there for anything else that might use it, though after this change nothing in this repo should)

---

## Item 0 — Ground truth

`map_compiler.gd:95-103`:

```gdscript
for divider: Dictionary in spec.get("dividers", []):
    for raw_cell in divider.get("cells", []):
        var cell: Vector2i = Vector2i(raw_cell) + offset
        if blocked_map.has(cell):
            continue
        wall_tiles.append({"cell": cell, "tile_name": "block_SE"})
        blocked_map[cell] = true
        blocked_edges.append({"from": cell, "to": cell + Vector2i(0, -1)})
        blocked_edges.append({"from": cell, "to": cell + Vector2i(0,  1)})
```

No per-divider field selects material — `"block_SE"` is hardcoded. Compare `edge_extractor.gd:96-98` (legacy branch, explicitly preserved untouched by BLOCK-01's Finding B):

```gdscript
elif tile_name.begins_with("block_"):
    var material := tile_name.substr(6)  # "SE" from "block_SE" — never a real material
```

vs. the proven, wired, bakeable path used by solid blocks (`edge_extractor.gd:90-92`):

```gdscript
elif tile_name.begins_with("solidblock_"):
    var material := tile_name.substr(11)  # e.g. "concrete", a real MaterialRegistry id
```

`SIGMA_01` (`sigma_01_map.gd:28-50`) is the only real content currently using `dividers` — 3 divider groups (Divider A/B/C), no material distinction between them today (all silently "SE").

---

## Item 1 — `MapCompiler`: emit `solidblock_<material>` for dividers

```gdscript
for divider: Dictionary in spec.get("dividers", []):
    var material: String = String(divider.get("material", "concrete"))
    for raw_cell in divider.get("cells", []):
        var cell: Vector2i = Vector2i(raw_cell) + offset
        if blocked_map.has(cell):
            continue
        wall_tiles.append({"cell": cell, "tile_name": "solidblock_%s" % material})
        blocked_map[cell] = true
        blocked_edges.append({"from": cell, "to": cell + Vector2i(0, -1)})
        blocked_edges.append({"from": cell, "to": cell + Vector2i(0,  1)})
```

Default `"concrete"` preserves current visual behavior for anyone who doesn't set `material` explicitly (concrete was already the de facto look, and is `DEFAULT_FACADES`'s first entry). Storey height: dividers get whatever the surrounding wall-cell mechanics already assume for a single course — confirm (don't assume) whether a divider needs an explicit `storeys` field or should implicitly behave like the old single-ground-course convention (1 storey; with FIX-VOXEL-HEIGHT-01 in place, 1 storey is now correctly ~158px, a normal full-height interior partition — this is very likely already correct with no further change needed, but verify against a screenshot, not just code reading).

## Item 2 — `SIGMA_01`: assign real materials to its 3 dividers (content, not required, but do it — this is the actual content this prompt exists to fix)

`sigma_01_map.gd`'s dividers currently have no material variety. Pick something reasonable per divider (e.g. Divider A/B/C could each get a distinct material for visual variety and to prove the field works, or all stay `"concrete"` if that's the intended look) — **ask if genuinely unsure which materials Matt wants here; a wrong guess is cheap to fix, but don't spend more than one round-trip on it.** If no preference is given, `"concrete"` for all three is a safe, faithful-to-current-look default.

---

## Acceptance Criteria (assertion-backed, real execution evidence only)

1. **`MapCompiler` divider loop emits `solidblock_` tiles**: real printed `wall_tiles` entries for a compiled `SIGMA_01`, confirming `tile_name` starts with `solidblock_`, never `block_SE`, for every divider cell.
2. **Dividers reach the Edge pipeline with real material**: real printed `Edge.material` values (from `EdgeExtractor.extract()`'s output) for divider-derived edges — must be a real `MaterialRegistry` id (`concrete`/`stone`/`wood`/`metal`), never `"SE"`.
3. **Baking reachable**: with `BakeConfig.enabled = true` and real textures (per `BAKE-LIVE-BOOT-01`), confirm a divider-derived edge resolves through `BakedTileLookup` the same way BLOCK-01b proved for solid blocks (paste the resolve() result, `source_id`/`atlas_coords`, not just "should work").
4. **Non-regression, topology**: `SIGMA_01`'s `blocked_cells` count and gate/gap positions (the deliberately-open cells in each divider) are unchanged — dividers still gate movement exactly where they did before, only the rendering path changed.
5. **`check_invariants.py` / `map_lint.gd`**: clean, verbatim.
6. **Screenshot**: SIGMA_01's Zone A/B/C dividers, confirming they render as proper full-height walls (not the old thin/miscolored legacy look) — this is what actually proves the fix, not just the log lines.
7. **Legacy `block_` branch left alone**: confirm by reading the diff that `edge_extractor.gd`'s `block_` branch was not touched — this prompt makes it unreachable in practice (nothing emits `"block_SE"` anymore after this change), but deleting the dead branch itself is a separate, later cleanup step, not this prompt's job.

---

## Explicitly out of scope

- Deleting the now-dead legacy `block_` branch in `EdgeExtractor` — that's the upcoming dead-code cleanup pass, not this prompt.
- Adding a `storeys` field to dividers (multi-storey interior partitions) — not requested; dividers stay single-storey unless a real need comes up.
- Any change to exterior walls or `EXTERIOR_WALL_STOREYS` — unrelated, already closed by `FIX-EXTERIOR-WALLS-01`.

---

*End FIX-DIVIDER-MATERIAL-01 prompt.*
