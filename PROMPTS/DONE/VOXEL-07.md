# VOXEL-07 — Dirty Flag + TIC Integration

> **Série:** VOXEL · **Prompt:** 07 de 11
> **Depende de:** VOXEL-06 (`VoxelRegistry` + container index) ✅
> **Desbloqueia:** VOXEL-08 (baking system) — conclui Phase 2 (Runtime System)
> **Arquivos tocados:** `voxel_ref.gd`, `wall_slice.gd`, `high_wall.gd`, `room.gd`, `tic_system.gd`
> **Natureza:** Per-voxel dirty tracking + TIC loop integration.
> Enables efficient runtime state updates (skips idle containers). Core for destructibility.

---

## CONTEXT

Após VOXEL-06, temos containers (WallSlice, HighWall) centralmente indexados mas **sem mecanismo de atualização**.
Todas as voxels estão na TileMapLayer com estado fixo.

Agora: Implementar **propagação de dirty flags** e **TIC loop** para permitir mudanças de estado em tempo real.

### Dirty Propagation Chain

```
VoxelRef.set_visible(false)
  → dirty = true
  → _parent_slice.dirty_count += 1
  → (if parent HighWall exists) _parent_hw.dirty_count += 1
```

TIC loop (executado uma vez por turno) itera apenas containers com `dirty_count > 0`.

---

## MODULE

**Arquivos tocados:**
1. `godot/scripts/world/voxel_ref.gd` — 1 str_replace (adicionar set_visible, set_damage, propagação)
2. `godot/scripts/world/wall_slice.gd` — 1 str_replace (adicionar increment_dirty)
3. `godot/scripts/world/high_wall.gd` — 1 str_replace (adicionar increment_dirty)
4. `godot/scripts/world/room.gd` — 2 str_replace (adicionar _tic_voxel_system, conectar ao TIC)
5. `godot/scripts/systems/tic_system.gd` — 1 str_replace (chamar room._tic_voxel_system)

---

## TASK

### File 1 — Modify `voxel_ref.gd` — Add dirty propagation

Adicionar:
- Variável `_parent_slice: WallSlice` (weak ref via parentheses)
- Método `_set_parent_slice(slice: WallSlice)`
- Método `set_visible(value: bool)` — seta `visible` e propaga dirty upward
- Método `set_damage(damage: int)` — seta `damage_state` e propaga dirty upward
- Método `clear_dirty()` — limpa `dirty = false`

old_str:
```gdscript
	visible: bool = true
	dirty: bool = false
	damage_state: int = DAMAGE_INTACT
	face_atlas_rect: Rect2i = Rect2i()
```

new_str:
```gdscript
	visible: bool = true
	dirty: bool = false
	damage_state: int = DAMAGE_INTACT
	face_atlas_rect: Rect2i = Rect2i()
	var _parent_slice: WallSlice = null


func _set_parent_slice(slice: WallSlice) -> void:
	## Called from WallSlice during voxel append. Enables dirty propagation.
	_parent_slice = slice


func set_visible(value: bool) -> void:
	## Set visible state and propagate dirty flag upward.
	if visible == value:
		return  ## no change
	visible = value
	dirty = true
	if _parent_slice != null:
		_parent_slice.increment_dirty()


func set_damage(damage: int) -> void:
	## Set damage state and propagate dirty flag upward.
	if damage_state == damage:
		return  ## no change
	damage_state = clamp(damage, DAMAGE_INTACT, DAMAGE_DESTROYED)
	dirty = true
	if _parent_slice != null:
		_parent_slice.increment_dirty()


func clear_dirty() -> void:
	## Called from TIC loop after voxel state applied.
	dirty = false
```

---

### File 2 — Modify `wall_slice.gd` — Add dirty propagation

Adicionar:
- Variável `_parent_hw: HighWall` (weak ref)
- Método `_set_parent_hw(hw: HighWall)`
- Método `increment_dirty()`
- Método `clear_dirty()`

old_str:
```gdscript
	dirty_count: int = 0
	baked: bool = false
	parent_high_wall: String = ""
```

new_str:
```gdscript
	dirty_count: int = 0
	baked: bool = false
	parent_high_wall: String = ""
	var _parent_hw: HighWall = null


func _set_parent_hw(hw: HighWall) -> void:
	## Called from HighWall during slice append. Enables dirty propagation.
	_parent_hw = hw


func increment_dirty() -> void:
	## Increment dirty counter when child voxel is marked dirty.
	## Propagate upward to HighWall.
	dirty_count += 1
	if _parent_hw != null:
		_parent_hw.increment_dirty()


func clear_dirty() -> void:
	## Called from TIC loop after slice processed.
	## Recursively clear all voxel dirty flags.
	for voxel in voxels:
		voxel.clear_dirty()
	dirty_count = 0
```

---

### File 3 — Modify `high_wall.gd` — Add dirty propagation

Adicionar:
- Método `increment_dirty()`
- Método `clear_dirty()`

old_str:
```gdscript
	dirty_count: int = 0
	voxel_bounds: Rect2i = Rect2i()
```

new_str:
```gdscript
	dirty_count: int = 0
	voxel_bounds: Rect2i = Rect2i()


func increment_dirty() -> void:
	## Increment dirty counter when child slice is marked dirty.
	dirty_count += 1


func clear_dirty() -> void:
	## Called from TIC loop after high wall processed.
	## Recursively clear all slice/extra dirty flags.
	for slice in slices:
		slice.clear_dirty()
	for extra in junction_extras:
		extra.clear_dirty()
	dirty_count = 0
```

---

### File 4 — Modify `room.gd` — Register parent refs during slice append

old_str:
```gdscript
		for pos in positions:
			for level in layer_count:
				ws.voxels.append(VoxelRef.new(pos, level))
		_voxel_wall_slices.append(ws)
```

new_str:
```gdscript
		for pos in positions:
			for level in layer_count:
				var voxel := VoxelRef.new(pos, level)
				voxel._set_parent_slice(ws)
				ws.voxels.append(voxel)
		_voxel_wall_slices.append(ws)
```

---

### File 5 — Modify `room.gd` — Set parent refs in _build_high_walls()

old_str:
```gdscript
	## Create HighWall for each group
	for group_key: String in hw_groups:
		var slices: Array = hw_groups[group_key]
		var hw := HighWallClass.new()
		hw.id = "HW_%s" % group_key.replace(" ", "_")
		hw.slices = slices
		hw.junction_extras = []
		hw.baked = false
		hw.dirty_count = 0
		_voxel_registry.register_high_wall(hw)
```

new_str:
```gdscript
	## Create HighWall for each group
	for group_key: String in hw_groups:
		var slices: Array = hw_groups[group_key]
		var hw := HighWallClass.new()
		hw.id = "HW_%s" % group_key.replace(" ", "_")
		
		## Set parent references for dirty propagation
		for slice in slices:
			slice._set_parent_hw(hw)
		
		hw.slices = slices
		hw.junction_extras = []
		hw.baked = false
		hw.dirty_count = 0
		_voxel_registry.register_high_wall(hw)
```

---

### File 6 — Add `_tic_voxel_system()` to `room.gd`

Adicionar nova função antes de `_has_any()`:

```gdscript
func _tic_voxel_system() -> void:
	## Called once per TIC by TicSystem. Process all dirty voxels.
	## Efficient: skips containers with dirty_count == 0.
	if _voxel_registry == null:
		return

	for hw in _voxel_registry.all_high_walls():
		if hw.dirty_count == 0:
			continue  ## skip idle high wall
		
		## Process slices
		for slice in hw.slices:
			if slice.dirty_count == 0:
				continue  ## skip idle slice
			_process_voxel_slice(slice)
		
		## Process junction extras (single voxels)
		for extra in hw.junction_extras:
			if extra.dirty:
				_apply_voxel_state(extra)
				extra.clear_dirty()
		
		hw.clear_dirty()


func _process_voxel_slice(slice: WallSlice) -> void:
	## Iterate slice voxels; apply state changes for dirty ones.
	for voxel in slice.voxels:
		if not voxel.dirty:
			continue
		_apply_voxel_state(voxel)
		voxel.clear_dirty()
	slice.dirty_count = 0


func _apply_voxel_state(voxel: VoxelRef) -> void:
	## Render or erase voxel based on visible + damage_state.
	## Renders: visible AND damage_state < DESTROYED (i.e., INTACT or CRACKED)
	## Erases: not visible OR damage_state == DESTROYED
	var layer := _voxel_layers[voxel.level]
	if voxel.visible and voxel.damage_state < VoxelRefClass.DAMAGE_DESTROYED:
		## Render voxel at the face_atlas_rect coordinates
		var source_id: int = _voxel_tile_ids.get("voxel_concrete", -1)
		var tile_coord: Vector2i = voxel.face_atlas_rect.position
		layer.set_cell(voxel.grid_pos, source_id, tile_coord)
	else:
		## Erase voxel (either invisible or destroyed)
		layer.erase_cell(voxel.grid_pos)
```

---

### File 7 — Integrate with `tic_system.gd`

Localizar `func tic_update()` e adicionar chamada ao voxel system:

old_str (procurar por padrão similar):
```gdscript
func tic_update() -> void:
	## Called once per TIC from game loop or test.
	_tick_guard_ai()
	_tick_perception()
	_tick_light_updates()
```

new_str:
```gdscript
func tic_update() -> void:
	## Called once per TIC from game loop or test.
	_tick_guard_ai()
	_tick_perception()
	_tick_light_updates()
	_room.tic_voxel_system()  ## Process dirty voxels (VOXEL-07)
```

---

## DO NOT TOUCH

- Corpo de `_build_wall_containers()` — não apagar
- `_place_wall_voxels()` exceto as linhas de set_parent indicadas
- `_build_voxel_junction_extras()` — não modificar
- `_build_high_walls()` exceto adicionar set_parent
- Qualquer `.tres`, `.tscn`
- Atributos de WallSlice/HighWall que não sejam os indicados
- Subcube system

---

## ACCEPTANCE

**A1 — VoxelRef.set_visible() presente:**
```bash
grep -c "func set_visible" godot/scripts/world/voxel_ref.gd
# Expected: 1
```

**A2 — VoxelRef.set_damage() presente:**
```bash
grep -c "func set_damage" godot/scripts/world/voxel_ref.gd
# Expected: 1
```

**A3 — VoxelRef._set_parent_slice() presente:**
```bash
grep -c "func _set_parent_slice" godot/scripts/world/voxel_ref.gd
# Expected: 1
```

**A4 — WallSlice.increment_dirty() presente:**
```bash
grep -c "func increment_dirty" godot/scripts/world/wall_slice.gd
# Expected: 1
```

**A5 — HighWall.increment_dirty() presente:**
```bash
grep -c "func increment_dirty" godot/scripts/world/high_wall.gd
# Expected: 1
```

**A6 — room.gd._tic_voxel_system() presente:**
```bash
grep -c "func _tic_voxel_system" godot/scripts/world/room.gd
# Expected: 1
```

**A7 — room.gd._apply_voxel_state() presente:**
```bash
grep -c "func _apply_voxel_state" godot/scripts/world/room.gd
# Expected: 1
```

**A8 — tic_system.gd chama _room._tic_voxel_system():**
```bash
grep -c "tic_voxel_system" godot/scripts/systems/tic_system.gd
# Expected: 1
```

**A9 — Parent refs setados em _place_wall_voxels():**
```bash
grep -c "_set_parent_slice" godot/scripts/world/room.gd
# Expected: 1
```

**A10 — Parent refs setados em _build_high_walls():**
```bash
grep -c "_set_parent_hw" godot/scripts/world/room.gd
# Expected: 1
```

**A11 — Runtime: Godot loads clean, selftest passes:**
```
Inspecção visual:
- Sem parse errors ou type warnings
- Selftest 425 checks passa
- Registry populated com high walls
```

**A12 — Git status clean — apenas 5 arquivos tocados:**
```bash
git status --short | wc -l
# Expected: 5 modified files
```

---

## DONE CRITERIA

A1..A10 passam via grep. A11 confirmado visualmente (Godot carrega sem erros).
A12 mostra apenas os 5 arquivos esperados modificados.

**Completa Phase 2:** Voxel containers agora processáveis em tempo real via TIC loop.
Próxima fase: Baking system (VOXEL-08).

Mover para `PROMPTS/DONE/VOXEL-07.md`.
