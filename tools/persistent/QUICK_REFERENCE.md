# Quick Reference — INFILTRAITOR

Fast lookup for grid geometry, voxel constants, inviolable rules, and common patterns.

---

## Grid & Screen Coordinates

| Constant | Value | Purpose |
|----------|-------|---------|
| `VISUAL_GRID_OFFSET` | `Vector2(0, 512)` | Base screen offset, always received via parameter, never hardcoded |
| `WALL_FLOOR_STEP_PX` | `158.0` | Vertical pixel step per storey (cube face height) |
| `TILE_HW` (half-width) | `128` | Half the tile width in pixels |
| `TILE_HH` (half-height) | `64` | Half the tile height in pixels |

**Canonical screen positions** (always use these):

```gdscript
tile_center         = floor_layer.map_to_local(cell) + Vector2(0, 64) + VISUAL_GRID_OFFSET
tile_N_vertex       = floor_layer.map_to_local(cell) + VISUAL_GRID_OFFSET
tile_E_vertex       = floor_layer.map_to_local(cell) + Vector2(128, 64) + VISUAL_GRID_OFFSET
tile_S_vertex       = floor_layer.map_to_local(cell) + Vector2(0, 128) + VISUAL_GRID_OFFSET
tile_W_vertex       = floor_layer.map_to_local(cell) + Vector2(-128, 64) + VISUAL_GRID_OFFSET

ceiling_lift        = WALL_FLOOR_STEP_PX * (max_floors + 0.75)  # receive from room.gd
ceiling_lamp        = tile_center - Vector2(0, ceiling_lift)
temporal_fixture    = tile_center - Vector2(0, ceiling_lift + 72)
```

**Key rule:** `max_floors` comes from `_base_layout.get("max_floors", 1)`. Never hardcode a per-height lookup table.

---

## Voxel Constants

| Constant | Value | Notes |
|----------|-------|-------|
| `VOXEL_TILE_SIZE` | `Vector2i(32, 16)` | Voxel TileSet tile_size |
| `VOXELS_PER_UNIT_AXIS` | `8` | 8×8 voxels per GAME UNIT |
| `VOXEL_STEP_PX` | `20.0` | Vertical pixel height per voxel layer |
| `VOXEL_STOREY_HEIGHT_PX` | `160.0` | `8 × 20` |

**VoxelLayer position** (analytically derived, no calibration):
```gdscript
layer.position = Vector2(VISUAL_GRID_OFFSET.x, VISUAL_GRID_OFFSET.y - VOXEL_STEP_PX * float(level))
```

**Voxel addressing (hierarchical):**
```
HIGHWALL_012.WALL_NW_03_S0.VOXEL_034.visible = false
```

---

## Voxel Plane Alignment (SLICE-00 / Alpha OFFSET FIX, Calibrated SLICE-02)

**Issue:** Voxel layer initially offset from canonical grid due to tile_size difference.

**Why it happens:**
- `map_to_local()` returns **N-vertex** (diamond top), not tile origin
- Floor: N-vertex offset = (128, 64) = half of tile_size(256, 128)
- Voxel: N-vertex offset = (16, 8) = half of tile_size(32, 16)
- Visual delta X = (128-16) = **112** px
- Visual delta Y = **64** px (floor_half_h; no subtraction on Y component)

**Fix — Two Constants:**

```gdscript
# In _build_voxel_tileset():
td.texture_origin = Vector2i(0, 10)  # = (atom_h - tile_h) / 2 = (36 - 16) / 2

# In _ensure_voxel_layers():
const TILE_OFFSET: Vector2 = Vector2(112.0, 64.0)  # (floor_half_w - voxel_half_w, floor_half_h)
layer.position = Vector2(
    VISUAL_GRID_OFFSET.x + TILE_OFFSET.x,      # 0 + 112 = 112
    VISUAL_GRID_OFFSET.y + TILE_OFFSET.y - VOXEL_STEP_PX * level)
    # 512 + 64 - 20*k (note: Y is 64, not 56; empirically calibrated 2026-07-02)
```

**Result:** Both N-vertices align pixel-perfectly:
- Floor: (128, 64) + (0, 512) = **(128, 576)**
- Voxel: (16, 8) + (112, 564) = **(128, 572)** → with Y offset 64 = **(128, 576)** ✅

**Key:** The (112, 64) offset is empirically calibrated via DEBUG-02 ruler + nudge session. Pre-2026-07-02 derivation (112, 56) incorrectly subtracted voxel_half_h on Y. The new renderer is now better-aligned than the legacy baseline.

**Reference:** [VOXEL_MASTER_PLAN.md §10.4 — Transform Canon](../../docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md#104-slice-00--transform-canon-voxel-plane-alignment-alpha-offset-fix)

---

## Z-Index Slots (canvas draw order)

Two rules first, because three separate bugs in one day (2026-07-28/29) came from
not knowing them:

1. **Voxel layers encode HEIGHT, not depth.** Positive level `L` draws at
   `WALL_BASE_Z_INDEX + L` (= 10 + L); negative (floor) level `L` draws at
   `L + 1`, so the walkable top face (-1) lands on **z = 0**.
2. **z_index cannot express depth, and y-sorting is not enabled anywhere in the
   project** (only `y_sort_origin` is set, which does nothing on its own). Depth
   is `OcclusionSet` POLICY O5: `(x + y)` in view space, greater = nearer. A prop
   that must sort in front of / behind geometry asks
   `VoxelRenderer.classify_geometry_over_rect()` — see `FloatingCollectible`.

| z | occupant |
|---|---|
| −9 | `floor_layer` (legacy coarse plane) |
| −7 … 0 | voxel floor levels −8 … −1 (walkable top face at 0) |
| 1 | shadow tint layers, GU grid, `_tile_shadow`, **HEAT overlays** (same z, earlier in tree → below the others) |
| 2 | fog of war |
| 3 | `_tile_game` markers (exit/spawn) |
| 4 | shadow boundary |
| 5 / 6 / 7 | AP perimeter / path preview / selection |
| 8 | dev cell-number labels |
| 9 | occlusion wireframe panels (their level's z − 1) |
| 10 + L | voxel level L — walls, blocks, roofs. Also `structure_layer`, `enemies_root` at 10 |
| 24 / 25 / 27 / 28 | LIGHT-vision overlays: height / temporal / light / shadow |
| `max_voxel_z` + 1 | agent (OCC-03; props must stay below this) |
| +2 / +3 / +4 | light rays / ceiling props / embers |
| 100 | blast wireframe (= `Room.AIM_Z_FOOTPRINT`), guard noise indicator |
| 101 … 105 | grenade aiming stack, bottom to top: throw perimeter, aim dome, shrapnel rays, throw arc, virtual grenade (`Room.AIM_Z_*`). Absolute, not `max_voxel_z + n` — the footprint at 100 is already absolute, so a relative sibling drew *under* it |
| 140 / 150 | noise overlay / trail + occlusion overlay |
| 200 | dev hover label |

**Anything left at the default 0 is buried by the voxel floor** — that is exactly
how the HEAT heatmap and the dev cell labels disappeared under the concrete.

## Inviolable Rules — Summary

| # | Rule | Short enforcement |
|---|------|-------------------|
| **1** | Stats = `var`, never `const` | Gameplay values need difficulty scaling |
| **2** | `VISUAL_GRID_OFFSET` via parameter | Never copy into overlays |
| **3** | `WallEdgeData` only source of edge keys | Never recreate `_edge_key()` |
| **4** | Guard state transitions via `_enter_state()` | Never assign `state =` directly |
| **5** | `_alert_meter` only in `_apply_tic_result()` | No accumulation elsewhere |
| **6** | Mission structure independent of narrative | Logic ≠ text |
| **7** | Maps in internal coords (never raw) | Buffer applied only in `MapCompiler` |
| **8** | Wall voxels via `set_cell()` only | Never `blend_rect`, `Image.create()`, `Sprite2D` |

**Enforcement:** Rules 1–5 checked by `tools/persistent/check_invariants.py` (pre-commit hook). Rules 6–8 rely on review.

---

## What NOT to Do

**Code patterns to avoid:**

| ❌ Don't | ✅ Do |
|---------|-------|
| `const MAX_HP := 3` | `var max_hp: int = 3` |
| `const VISUAL_GRID_OFFSET := Vector2(0, 512)` in overlay | Receive via `setup(visual_offset)` parameter |
| `WallEdgeData.edge_key(a, b)` recreated locally | Use `WallEdgeData.edge_key(a, b)` directly |
| `state = STATE_SUSPICIOUS` | `_enter_state(STATE_SUSPICIOUS)` |
| Accumulate `_alert_meter` anywhere except `_apply_tic_result()` | Only in `_apply_tic_result()` |
| Guard-to-guard comms directly | Route via signals in `room.gd` |
| Hardcode player text | Use `tr("domain.key")` + CSV |
| `blend_rect`, `Image.create()` for walls | Always `set_cell()` on `_voxel_layers[level]` |
| `FACE_CENTER_OFFSET`, `is_x_varying`, `SUBCUBE_*` patterns | Eliminated — don't recreate |

---

## Common Patterns

### Creating an overlay that needs visual offset

```gdscript
class_name MyOverlay
extends CanvasLayer

var _visual_offset: Vector2

func setup(visual_offset: Vector2) -> void:
    _visual_offset = visual_offset

func _ready() -> void:
    z_index = 20  # set alongside other overlays

func draw_at_tile(cell: Vector2i) -> void:
    var floor_layer = get_tree().root.get_node("Room/FloorLayer")
    var screen_pos = floor_layer.map_to_local(cell) + Vector2(0, 64) + _visual_offset
    # ... draw at screen_pos
```

### Adding a player-facing string

1. Open `godot/localization/translations/ui.csv` (or create if missing)
2. Add row: `ui.button.attack,Attack,Atacar,Atacar`
3. In code: `button.text = tr("ui.button.attack")`
4. Register domain in `LocalizationManager.SOURCE_FILES` if new

### Registering a new guard-to-guard event

Don't call guards directly. Signal from `room.gd`:
```gdscript
# in room.gd, a guard detected the player
signal guard_detected_player(guard_node: Guard, player_pos: Vector2i)
# in other guards, connect to the signal
room.guard_detected_player.connect(_on_detected_player)
```

### Using edge queries

```gdscript
var blocked = blocked_edges.get(WallEdgeData.edge_key(from, to), [])
if WallEdgeData.is_edge_blocked(from, to, blocked_edges):
    # can't cross
```

---

## File References

- **Master Plans** (detailed subsystem specs): See [README.md](../../README.md#level-2-master-plans-canonical-subsystem-specifications)
- **CODEMAP.md** (API surface, tuning tables): `tools/persistent/CODEMAP.md` (auto-generated, never edit by hand)
- **Inviolable Rules detail + rationale**: [CLAUDE.md](../../CLAUDE.md#architecture--inviolable-rules)
- **Asset generation workflow**: [ASSET_PIPELINE_QUICK_REFERENCE.md](ASSET_PIPELINE_QUICK_REFERENCE.md)
