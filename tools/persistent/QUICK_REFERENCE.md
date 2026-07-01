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
| `VOXEL_STOREY_HEIGHT_PX` | `160.0` | `8 × 20` — matches old subcube system |

**VoxelLayer position** (analytically derived, no calibration):
```gdscript
layer.position = Vector2(VISUAL_GRID_OFFSET.x, VISUAL_GRID_OFFSET.y - VOXEL_STEP_PX * float(level))
```

**Voxel addressing (hierarchical):**
```
HIGHWALL_012.WALL_NW_03_S0.VOXEL_034.visible = false
```

---

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
- **Inviolable Rules detail + rationale**: [OPERATOR_CONTEXT.md](OPERATOR_CONTEXT.md#architecture--inviolable-rules)
- **Asset generation workflow**: [ASSET_PIPELINE_QUICK_REFERENCE.md](ASSET_PIPELINE_QUICK_REFERENCE.md)
