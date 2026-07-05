# MAP_MATTRESS_MASTER_PLAN
## Map Content, Persistence & Texture Supply — Master Plan v1.1 (CONSOLIDATED)

**Author:** Claude (architect), from authorial direction by Matt
**Date:** 2026-07-05 | **Supersedes:** v1.0 draft
**Status:** RATIFIED — D1–D14 resolved or explicitly deferred; ready for prompt generation
**Companion plans:** VOXEL_MASTER_PLAN (geometry), BAKING_MASTER_PLAN (surfaces, amended by D11), OCCLUSION & DESTRUCTION (next phase, receives §2.3 canon)

---

## 0. Purpose & Scope

1. **Texture supply** — the as-built authorial file contract, plus the latent gaps that must close first (G1–G4).
2. **Full-GU solid blocks** — true voxel blockers replacing SIGMA-01's one-asset tile blocks.
3. **Voxel props** — crates now; registry/format/importer plumbing for furniture and the future procedural room-supplier.
4. **MAPFILE persistence** — individual, versioned, migration-safe map files; seed + patch model for 90%-procedural maps with authorial control.
5. **PLAYGROUND 2.0** — showcase map and permanent visual-regression fixture.

**Out of scope:** map editor (post-Beta; format is editor-ready by design), runtime savegames, furniture content production, destruction *implementation* (next phase; its canon inputs are recorded here in §2.3).

**Precondition status:** FIX-BAKE-09b **verified closed** (v0.4.9). The E2E baked-hit was independently authenticated (FNV replica matches transcript origin `col=715 row=150` exactly — genuine execution). Two residuals folded into this plan: **G4** (live wiring key mismatch) and **D14** (NW offset ratification).

---

## PART 1 — Texture Supply: The As-Built Contract

### 1.1 Resolution chain (verified v0.4.9)

```
Tier 1  user://textures/<texture_id>.png         (player/modder override, per-machine)
Tier 2  res://textures/defaults/<texture_id>.png  (shipped authorial content — Matt's folder)
Tier 3  MATERIAL-ONLY                             (no file: base_color × pattern; always works)
```

Validation on load: ~10 MB cap, grayscale enforcement (~1000-sample R==G==B check), and dimension contract by filename prefix:

| Prefix | Category | Dimensions (N=16) |
|---|---|---|
| `facade_` | full facade plane (64×32 voxels) | **1024 × 512 px** |
| `slice_` | single GU face atom (reserved) | 128 × 128 px |

### 1.2 Latent gaps — all fold into MAT-DEFAULTS-01

- **G1 — facade prefix mismatch.** `BakePolicy.DEFAULT_FACADES` ids (`stone_base`, …) lack the `facade_` prefix the validator requires; no file can currently pass. **Canon (D1, ratified):** ids ARE filenames with prefix — `facade_concrete`, `facade_stone`, `facade_wood`, `facade_metal`; convention `facade_<material>[_<variant>].png`.
- **G2 — no default materials registered.** Nothing calls `MaterialRegistry.register()` at boot; `get_material()` returns null and the bake set empties. Required: `register_defaults()` at boot and in test setup, per the D2 table below.
- **G3 — `_render_solid_blocks` split-brain.** Duplicated in `room.gd:1411` and `room_builder.gd:283`. Consolidate to room_builder; delete the twin.
- **G4 — live bake wiring severed (found in 09b verification).** `BakeCompositor._extract_walls_from_spec()` reads `map_spec.wall_tiles` and `map_spec.room_geometry.walls`; `room_builder._bake_textures()` sends top-level `"walls"` and a `room_geometry` that EdgeExtractor never populates. **Live path bakes zero walls; only the E2E's hand-built spec works.** Fix: extractor also accepts top-level `"walls"` (one branch), plus a regression test that feeds the *room_builder-shaped* spec and asserts a non-empty bake set.

### 1.3 Default materials (D2, ratified)

| Material | base_color | Pattern |
|---|---|---|
| concrete | `#9E9E9E` | StonePattern (fine jitter) |
| stone | `#8D8D95` | StonePattern |
| wood | `#A8794F` | WoodPattern |
| metal | `#7E8790` | MetalPattern |

Moderate saturation only (BAKING D9): themes tint on top.

### 1.4 Blend canon — AMENDMENT to BAKING plan §2 (D11, ratified)

Authorial direction: *simplify* to a single canonical blend whose neutral is **mid-gray (0.5)**, so one facade can both darken and lighten (marble veins, metal sheen — the motivating cases multiply could never produce). Ratified variant: **linear-light**, the simpler of the two candidates:

```
out_rgb = clamp( material_rgb + 2.0 · (facade_lum − 0.5), 0.0, 1.0 )
```

- **Identity property:** facade_lum = 0.5 ⇒ no change. An absent facade (Tier 3) is treated as an implicit constant 0.5 — the fallback becomes mathematically exact, not an approximation.
- Applied in `_composite_tile()` (CPU) and mirrored in the deferred shader. One mode, no per-facade selection.
- Classic *overlay* (`b<0.5 ? 2bf : 1−2(1−b)(1−f)`) remains the documented alternative if first visual QA finds linear-light too harsh in the extremes; switching later is a one-function change plus re-bake, no file or schema impact. This is recorded so the amendment is loud, not silent.
- **BAKING_MASTER_PLAN §2 is formally amended** by this section (the multiplicative chain's `⊙ L_fac` term becomes the linear-light term; C_mat, P, T_theme unchanged).

### 1.5 What Matt provides + authoring guide (updated for D11)

**Minimum art drop — 4 files** in `godot/textures/defaults/`: `facade_concrete.png`, `facade_stone.png`, `facade_wood.png`, `facade_metal.png` — 1024×512, grayscale PNG.

**Authoring for linear-light (replaces the old 0.55–0.95 multiply band):**
- **0.5 is "no effect."** Paint the whole facade around mid-gray; excursions add or subtract light: 0.5 + x brightens by 2x, 0.5 − x darkens by 2x.
- Working band **0.30–0.70** for broad areas; reserve values outside it for thin accents (mortar shadow ≈ 0.25–0.35, marble vein highlight ≈ 0.70–0.85). Full 0/1 will clip against most base colors — use knowingly.
- Borders book-match under mirrored-repeat (folds at x=1024, y=512): keep border zones near 0.5 and low-contrast unless kaleidoscoping is desired.
- One voxel = 16×16 flat px; features under ~8 px shimmer at NEAREST.
- Strict grayscale (colored pixels fail resolution); color comes from material base + theme.

**File format (D13, ratified):** PNG is authoring canon. WebP-lossless is an accepted alternative (resolver probes `.webp` after `.png` — small MAT-DEFAULTS-01 addition). **AVIF rejected**: no core Godot loader (GDExtension dependency per platform), zero VRAM benefit, and lossy artifacts would poison a luminance channel entering a blend.

**Themes are not files.** `ThemeApplier` = one `modulate` per wall layer; instant switching, one atlas serves all themes. Palette v1 (D3, ratified): Neutral `#FFFFFF`, Warm `#FFE8CC`, Cold `#CFE0FF`, Alarm `#FFC4C4`.

**Voxel rendering paradigm (D12, ratified):** bitmap voxels via TileMapLayer stay — procedural cost is paid once at bake, render stays on the mobile-fast atlas path. Analytic/SDF per-fragment texturing rejected for this project. Standing measurement item: log baked pages-per-map after G4 lands and dedup is observed at real scale; if memory presses, shrink page size or apply runtime `Image.compress()` (ETC2/ASTC) — paradigm unchanged.

### 1.6 Geometry canon note (D14, ratified with reservation)

During 09b, the NW face offset was changed (32,0) → (16,0) without the mandated stop-and-report. The change is functionally benign (inverse-integer assert still holds; bake keys unaffected; only which flat texels NW samples shifts) and makes NW/SE symmetric like NE/SW. **Ratified:** (16,0) stands as canon; `TILE_ANATOMY.md` coverage table is consistent with it and with executed output (verified by independent replica). **Reservation:** no ground-truth extraction has ever validated any of these transforms against the real tileset; final settlement occurs at first visual QA on real walls (PLAYGROUND-02 District A is the fixture). Process note: this was silent canon change #3 — the stop-and-report rule is restated in every prompt of this plan.

---

## PART 2 — Solid Blocks & Voxel Props

### 2.1 SolidBlock — full-GU blocker (BLOCK-01)

**Spec:** `{ "type": "solid_block", "gu": [7,4], "storeys": 2, "material": "stone", "facade": null }`

**Compile:** a solid GU emits **exposed boundary faces only**, via the existing edge machinery — synthesize the 4 perimeter Edges (flagged `solid_interior` so JunctionResolver treats corners as filled) plus top cap; adjacent solids merge (shared edges emit nothing). Natural extension of `EdgeExtractor`, no parallel renderer.

**Gameplay:** GU enters `_blocked_cells` through the single existing writer (invariant M4, grep-enforced). Pathfinding, OCCLUDED_VOID vision class, and noise propagation inherit automatically.

**Render:** `_set_voxel_cell()` only (Rule #8) → blocks get baking, themes, and destructibility semantics for free.

### 2.2 VoxelProp — crates now, furniture plumbing (PROP-01, PROP-REG-01)

**PropDef resource:**
```json
{
  "id": "crate_full",
  "size_vox": [8, 8, 8],
  "layers": ["11111111/.../11111111", "..."],
  "material_zones": { "default": "wood" },
  "footprint_gus": [[0, 0]],
  "gameplay": { "cover": "full", "destructible": true },
  "tags": ["crate", "cover", "container"]
}
```

- Rendering: occupancy → `_set_voxel_cell()` (Rule #8; props are voxels, so bake/themes apply). Anchor = GU + voxel offset.
- **PropRegistry:** `res://props/*.json` + `user://props/` override tier (D9, ratified).
- **Furniture intake (deferred, plumbing now):** headless `.vox → PropDef.json` importer (MagicaVoxel is the de-facto interchange; palette → material_zones mapping table) **and** the parametric `PropGen` route (chair = seat + 4 legs + backrest) — both emit PropDefs, so the registry is agnostic (D5). Procedural room-supplier consumes the registry **by tags**: `needs(["bed"], ["wardrobe"], filler:["books","chair"])`.

### 2.3 Cover & destruction canon (D4 → RESOLVED; implementation = next phase)

Authorial ruling, recorded here as **input canon for the OCCLUSION & DESTRUCTION phase**:

**The cover ladder** — cover is a function of the object's *current* voxel height/mass, so destruction degrades it continuously:

| State | Cover |
|---|---|
| Full-GU crate (8-voxel height intact) | **FULL cover** |
| Smaller crate (e.g. half-height) | **HALF cover** |
| Semi-destroyed crate | **QUARTER cover** (prone/deitado only) |
| Destroyed | **none** |

Same ladder applies to any voxel prop and, in principle, to damaged walls. TicSystem exposure classes gain the intermediate rungs in that phase; PROP-01 v1 ships crates with a *static* declared `cover` value and the dynamic ladder lands with destruction.

**Destruction philosophy (authorial):** symbolic and stingy — on the order of **one voxel removed per shot**. Breaching a wall by gunfire should cost roughly the entire game's ammunition: scenario alteration is possible but never cheap, because the game is stealth. Explosives get a distinct (higher) potential, still tuned so reshaping the map is an event, not a tool. Exact numbers are that phase's tuning work; this paragraph is the design intent it must honor.

**Future UI note:** floating shield / half-shield / quarter-shield glyphs over objects will read out their current cover value. Not scheduled; recorded so PropDef's `gameplay.cover` field is understood as the eventual data source for those glyphs.

---

## PART 3 — MAPFILE: Persistence That Doesn't Break

### 3.1 Requirements (authorial, distilled)

Individual files in folders; save only essential/authorial variables (engine derives the rest — compiled edges, slices, nav, bakes are never serialized); 90% procedural with authorial detail control; updates that keep working after new features exist; editor-ready without rework.

### 3.2 Format (D6, ratified): JSON, sectioned, versioned

JSON over `.tres`: human-diffable, git-friendly, external-tool-friendly, and **safe from user folders** (`JSON.parse` is inert; `load()` on user `.tres` is an execution vector). Locations: `res://maps/*.map.json` (shipped) and `user://maps/*.map.json` (custom); user id wins on collision.

```json
{
  "format": "infiltraitor-map",
  "schema_version": 3,
  "id": "PLAYGROUND",
  "meta": { "title": "Playground 2.0", "author": "Matt" },
  "sections": {
    "board":  { "v": 1, "inner_size": [28,18], "buffer": 1, "floor_tile": "floor_SE" },
    "walls":  { "v": 2, "edges": [ { "a": [3,2], "b": [3,6], "material": "stone", "storeys": 2, "facade": null } ] },
    "blocks": { "v": 1, "items": [ { "gu": [7,4], "storeys": 2, "material": "stone" } ] },
    "props":  { "v": 1, "items": [ { "def": "crate_full", "gu": [9,4], "vox_offset": [0,0], "rot": 0 } ] },
    "actors": { "v": 1, "agent_start": [1,1], "guards": [ { "route": [[4,4],[4,9]], "class": "patrol" } ] },
    "procedural": null,
    "patches": []
  }
}
```

Internal coords throughout; buffer applied only in MapCompiler (rule #7 unchanged). Wall runs as `a→b` spans. `"facade": null` = material default via BakePolicy.

### 3.3 Procedural + authorial control: seed + patch

```json
"procedural": { "generator": "shell_v1", "seed": 881442, "params": { "rooms": 9 } },
"patches": [
  { "op": "set_wall_material", "a": [12,3], "b": [12,9], "material": "metal", "facade": "facade_metal_boss" },
  { "op": "add_prop", "def": "crate_full", "gu": [14,8] },
  { "op": "remove_edge", "a": [7,7], "b": [8,7] }
]
```

`generator(seed, params) → base spec → patches in order → MapCompiler`. **Determinism (M7):** same file ⇒ same map, always; a generator whose output changes for old seeds gets a new id (`shell_v2`) — generator ids are canon (D10, ratified). Boss-fight workflow: roll seeds, freeze, patch details. Patches are the future editor's native substrate.

### 3.4 Anti-breakage machinery

- **Section registry:** each subsystem registers `{section_id, version, serialize, deserialize, migrations[]}` with `MapFileService`; the core loader knows no section's contents. **New feature = new registered section** — this is how saving keeps pulling the right data after functions we haven't invented yet.
- **Migration chain:** ordered pure `v(n)→v(n+1)` per section + global schema_version; upgrade in memory, rewrite on disk only on explicit save.
- **Tolerant round-trip (M3):** unknown sections/keys preserved verbatim — files from newer builds survive older ones.
- **Loud-fail validation:** post-load pass (coords in range, materials known, prop defs resolvable, edges non-degenerate) with full report; never a half-loaded map.
- **`map_lint`:** headless validator over both folders + golden round-trip (load→save→compare) for shipped maps; joins `check_invariants.py` in pre-commit.

Invariants: **M1** files are declarative data only · **M2** every section versioned with total migration chain · **M3** round-trip preservation · **M4** `_blocked_cells` single-writer · **M5** props render via `set_cell` only · **M6** facade filename prefix canon · **M7** file+seed determinism.

### 3.5 Catalog

`MapCatalog` gains `FileMapSource` (scan folders, parse headers, list ids). Legacy `*_map.gd` remain as generators during migration; MAPFILE-02 exports PLAYGROUND and SIGMA_01 to `.map.json` golden files and flips the catalog file-first. Old 3×3 playground survives as `CALIB`.

---

## PART 4 — PLAYGROUND 2.0 (PLAYGROUND-02)

Inner **28×18**, buffer 1 (D7, ratified). Districts, each a permanent regression fixture:

| District | Contents | Tests |
|---|---|---|
| **A. Material Gallery** | 4 wall runs (5 GU, 2 storeys), one per material | bake per material, D11 blend, tiers, Tier-3 look — and the D14 visual settlement |
| **B. Theme Row** | stone run per theme zone (per-map theme v1; per-zone pending D8) | ThemeApplier, D9 discipline |
| **C. Junction Museum** | L, T, X, V-pair, column line | JunctionResolver regressions |
| **D. Blocker Field** | solid singles, 2×2 cluster, 1×3 row, 2-storey monolith | BLOCK-01 merging, pathing, occlusion |
| **E. Crate Yard** | full-GU crate, small crate, cover lane pair | PROP-01, §2.3 static cover values |
| **F. Vignettes** | courtyard, doored corridor, room-in-room, colonnade | composed architecture + guard routing |
| **G. Arena Sketch** | seeded pocket + 3–4 patches | seed+patch workflow end-to-end |

Authored directly as the first `.map.json`; one patrol guard routes through C–F.

---

## PART 5 — Decision Register (final)

| # | Decision | Resolution |
|---|---|---|
| D1 | Facade filename canon | ✅ `facade_` prefix; BakePolicy updated |
| D2 | Material base colors | ✅ table §1.3 |
| D3 | Theme palette v1 | ✅ Neutral/Warm/Cold/Alarm |
| D4 | Crate/cover semantics | ✅ **cover ladder §2.3**; dynamic ladder = OCCLUSION & DESTRUCTION phase |
| D5 | Furniture route | ✅ both (.vox importer + parametric PropGen) → PropDef; deferred |
| D6 | Map format | ✅ JSON sectioned/versioned |
| D7 | Playground size | ✅ 28×18 |
| D8 | Theme granularity | ⏳ per-map v1; per-zone investigation in BAKE v1.5 |
| D9 | Prop override tier | ✅ `user://props/` |
| D10 | Generator versioning | ✅ generator id is canon |
| D11 | Blend mode | ✅ **linear-light, 0.5 neutral** (§1.4); BAKING §2 amended; overlay = documented fallback |
| D12 | Voxel paradigm | ✅ bitmap/TileMap stays; memory measurement item post-G4 |
| D13 | Image format | ✅ PNG canon; WebP-lossless accepted; AVIF rejected |
| D14 | NW offset (16,0) | ✅ ratified with reservation; final settlement at District A visual QA |

---

## PART 6 — Prompt Sequence & Dependencies

```
DOC-HOOK-01 (independent; doc-on-push automation — separate prompt, already authored)

MAT-DEFAULTS-01 ──┐   G1 prefix · G2 register_defaults · G3 split-brain purge ·
                  │   G4 live wiring fix + room_builder-shaped regression test ·
                  │   D11 linear-light in _composite_tile (+ BAKING §2 amendment note) ·
                  │   WebP probe in resolver
                  ├──> BLOCK-01 (solid GU end-to-end)
MAPFILE-01 ───────┤        │
 (schema, service,│        ├──> PROP-01 (crate MVP, static cover values from §2.3)
  migrations,     │        │        │
  lint, tests)    │        │        ├──> PLAYGROUND-02 (first .map.json; District A settles D14)
                  └──> MAPFILE-02 ──┘
                       (FileMapSource; PLAYGROUND/SIGMA golden exports; CALIB kept)

Deferred: PROP-REG-01 (.vox importer + tag supply API) → pre-generator milestone
Next phase: OCCLUSION & DESTRUCTION (receives §2.3 canon: cover ladder, 1-voxel/shot intent)
Post-Beta: MAP-EDITOR-01
```

Effort: MAT-DEFAULTS-01 ~3h · MAPFILE-01 ~5h · MAPFILE-02 ~3h · BLOCK-01 ~4h · PROP-01 ~4h · PLAYGROUND-02 ~3h.

Every prompt carries the evidence rules forged in the BAKE saga: assertion-backed PASS lines, red-then-green, verbatim transcripts, independent auditor replicas, and the stop-and-report rule for any canon-adjacent value.

---

*End MAP_MATTRESS_MASTER_PLAN v1.1 — consolidated and ratified.*
