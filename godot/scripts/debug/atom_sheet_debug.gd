## ATOM-SHEET (2026-08-08, Director) — a contact sheet of EVERY pre-baked
## damage atom in the loaded map, grouped by material and by the surface it
## belongs to (WALL / CEILING / FLOOR), with its decal visible.
##
## Why a sheet and not more in-world geometry: `damage_gallery_debug.gd` (F5)
## forces damage onto real voxels scattered across the map, which proves the
## RENDER PATH works but can only ever show the handful of atoms the map's own
## geometry happens to expose, at whatever angle the camera is at. This reads
## the `VoxelVariantRegistry` directly, so what it displays IS the bake — every
## atom that exists, nothing that doesn't, and a count that can be checked
## against `registry.size()`. The two are complements: F5 answers "does a
## damaged voxel render correctly", F8 answers "what did the map actually
## bake".
##
## Atoms come back through `DamageCompositeCache.get_image_at()`, the same
## readback `DamageVariantBaker` already uses to persist its disk cache — the
## real composited pixels, not a re-derivation, so an atom that is wrong here
## is wrong in the game.
##
## Substrates: an atom exists once per (material, damage name, substrate) and
## the substrate axis is just a different crop of the same facade — three
## near-identical tiles per row, which triples the sheet's size for very
## little signal. Substrate 0 only by default; set
## `INFILTRAITOR_ATOM_SHEET_SUBSTRATES=all` to see the axis itself.
##
## Debug-only. Never called from gameplay.
class_name AtomSheetDebug
extends CanvasLayer

## Interactive default. The sheet scrolls, so this is about readability, not
## fit — but a CAPTURE has one screen, so `INFILTRAITOR_ATOM_SHEET_SCALE=1`
## exists to make the whole sheet fit in one frame for evidence.
const DEFAULT_ATOM_SCALE: int = 2
## The order surfaces are listed in, so a material's block always reads
## top-to-bottom the same way regardless of Dictionary iteration order.
const ELEMENT_ORDER: Array[String] = ["WALL", "CEILING", "FLOOR"]

var _atom_scale: int = DEFAULT_ATOM_SCALE

var _root: Control = null


## Instantiate-then-setup rather than a static factory: a `class_name` is not
## resolvable from inside its own file's static context, and self-preloading to
## work around that invites a cyclic load for no benefit. Returns false (having
## said why) when there is nothing to show, so the caller can free the node and
## report instead of adding an empty overlay.
func setup(room: Node) -> bool:
	var renderer = room._voxel_renderer if "_voxel_renderer" in room else null
	if renderer == null:
		push_warning("[ATOM-SHEET] room has no _voxel_renderer — is a map loaded?")
		return false
	var registry = renderer._damage_variant_registry
	if registry == null:
		push_warning("[ATOM-SHEET] no VoxelVariantRegistry — the map's damage_materials section may be empty (D13 opt-out)")
		return false
	var cache = renderer.get_damage_composite_cache()
	if cache == null:
		push_warning("[ATOM-SHEET] no DamageCompositeCache — nothing to read atoms back from")
		return false
	if registry.size() == 0:
		push_warning("[ATOM-SHEET] registry is empty — this map baked no damage atoms")
		return false

	layer = 128
	_populate(registry, cache)
	return true


## Groups the registry's flat key space into material -> element -> [rows],
## where a row is one damage NAME and its substrate tiles. Keys are
## "ELEMENT|material|damage_name|substrate" (VoxelVariantRegistry.
## make_variant_key) — parsed with split("|", true, 3) so a damage name can
## never be truncated by a stray separator it might grow later.
func _populate(registry, cache) -> void:
	var want_all_substrates: bool = OS.get_environment("INFILTRAITOR_ATOM_SHEET_SUBSTRATES") == "all"
	var scale_env := OS.get_environment("INFILTRAITOR_ATOM_SHEET_SCALE")
	if scale_env.is_valid_int() and scale_env.to_int() > 0:
		_atom_scale = scale_env.to_int()

	var by_material: Dictionary = {}
	var skipped_substrates := 0
	for key in registry.keys():
		var parts: PackedStringArray = String(key).split("|")
		if parts.size() < 4:
			push_warning("[ATOM-SHEET] unparseable variant key '%s' — skipped" % key)
			continue
		var element: String = parts[0]
		var material: String = parts[1]
		var damage_name: String = parts[2]
		var substrate: int = parts[3].to_int()
		if not want_all_substrates and substrate != 0:
			skipped_substrates += 1
			continue
		## The DECAL FAMILY is the row; the variant is a column within it.
		## "concrete_blast_dented_left_2" -> family "blast_dented_left",
		## variant 2. Three variants of one family are the same mark drawn
		## three ways, so stacking them vertically padded the sheet to three
		## times the height it needs for no added information.
		var family := _family_of(damage_name, material)
		if not by_material.has(material):
			by_material[material] = {}
		if not by_material[material].has(element):
			by_material[material][element] = {}
		if not by_material[material][element].has(family["name"]):
			by_material[material][element][family["name"]] = []
		by_material[material][element][family["name"]].append({
			"substrate": substrate, "variant": family["variant"],
			"entry": registry.get_variant(key),
		})

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.07, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 10)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_root)

	var shown := 0
	var materials: Array = by_material.keys()
	materials.sort()

	var header := Label.new()
	_root.add_child(header)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	_root.add_child(columns)

	for material in materials:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		columns.add_child(column)

		var material_label := Label.new()
		material_label.text = String(material).to_upper()
		material_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		column.add_child(material_label)

		## ELEMENT_ORDER first, then anything the registry holds that this list
		## does not know about — a new element_class must show up rather than
		## vanish from the sheet that is supposed to prove completeness.
		var elements: Array = []
		for e in ELEMENT_ORDER:
			if by_material[material].has(e):
				elements.append(e)
		for e in by_material[material].keys():
			if not elements.has(e):
				elements.append(e)
				push_warning("[ATOM-SHEET] element_class '%s' is not in ELEMENT_ORDER — appended" % e)

		for element in elements:
			var element_label := Label.new()
			element_label.text = "  %s" % element
			element_label.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0))
			column.add_child(element_label)

			var names: Array = by_material[material][element].keys()
			names.sort()
			for damage_name in names:
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 2)
				column.add_child(row)

				var tiles: Array = by_material[material][element][damage_name]
				tiles.sort_custom(func(a, b):
					if int(a["substrate"]) != int(b["substrate"]):
						return int(a["substrate"]) < int(b["substrate"])
					return int(a["variant"]) < int(b["variant"]))
				for tile in tiles:
					var rect := _atom_tile(cache, tile["entry"])
					if rect != null:
						row.add_child(rect)
						shown += 1

				var name_label := Label.new()
				name_label.text = "%s  (%d)" % [damage_name, tiles.size()]
				name_label.add_theme_font_size_override("font_size", 11)
				name_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
				name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				row.add_child(name_label)

	header.text = "ATOM SHEET — %d of %d registered atoms shown%s" % [
		shown, registry.size(),
		("" if want_all_substrates else "   (substrate 0 only; %d others hidden — INFILTRAITOR_ATOM_SHEET_SUBSTRATES=all)" % skipped_substrates)]
	header.add_theme_color_override("font_color", Color(1, 1, 1))

	print("[ATOM-SHEET] %d atoms shown of %d registered (%d materials)" % [
		shown, registry.size(), materials.size()])
	for material in materials:
		var per_element: Array[String] = []
		for element in by_material[material].keys():
			var count := 0
			for damage_name in by_material[material][element].keys():
				count += by_material[material][element][damage_name].size()
			per_element.append("%s=%d" % [element, count])
		per_element.sort()
		print("[ATOM-SHEET]   %-9s %s" % [material, ", ".join(per_element)])


## Splits a damage name into (family, variant): "concrete_blast_dented_left_2"
## -> {"blast_dented_left", 2}. The material prefix goes too — it is already
## the column title. A name with no trailing variant (the ceiling's
## variantless "blast_dented_bottom", D7's 3 shapes not being real yet) keeps
## its whole tail and reports variant 0, so it still forms one row.
static func _family_of(damage_name: String, material: String) -> Dictionary:
	var rest := String(damage_name)
	if rest.begins_with("%s_" % material):
		rest = rest.substr(material.length() + 1)
	var cut := rest.rfind("_")
	if cut > 0:
		var tail := rest.substr(cut + 1)
		if tail.is_valid_int():
			return {"name": rest.substr(0, cut), "variant": tail.to_int()}
	return {"name": rest, "variant": 0}


## ATOM EXPORT (Director, 2026-08-08) — writes every registered atom to disk as
## its own PNG plus a manifest, so the decals can be reviewed and iterated on
## OUTSIDE the game. This is the deliverable the in-game sheet above cannot be:
## a capture only ever shows one screenful, and the point here is to look at
## the baked result of each decal while editing its source art.
##
## Individual files rather than one pre-composed sheet on purpose: the sheet is
## built from these by `tools/persistent/build_atom_sheet.py` (which has real
## font rendering, unlike anything available to GDScript's Image API), and the
## individual atoms are themselves what an artist wants to open when a specific
## decal reads wrong.
##
## Always exports ALL substrates — the substrate axis is exactly the kind of
## thing art review needs to see, unlike the on-screen sheet where it is noise.
## Returns the number of atoms written.
static func export_atoms(room: Node, subdir: String = "Screenshots/atoms") -> int:
	var renderer = room._voxel_renderer if "_voxel_renderer" in room else null
	if renderer == null:
		push_error("[ATOM-EXPORT] room has no _voxel_renderer — is a map loaded?")
		return 0
	var registry = renderer._damage_variant_registry
	var cache = renderer.get_damage_composite_cache()
	if registry == null or cache == null:
		push_error("[ATOM-EXPORT] no VoxelVariantRegistry/DamageCompositeCache — nothing to export")
		return 0

	var out_dir: String = ProjectSettings.globalize_path("res://").path_join(subdir)
	var err := DirAccess.make_dir_recursive_absolute(out_dir)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("[ATOM-EXPORT] cannot create %s: %s" % [out_dir, error_string(err)])
		return 0

	var manifest: Array = []
	var written := 0
	var keys: Array = registry.keys()
	keys.sort()
	for key in keys:
		var parts: PackedStringArray = String(key).split("|")
		if parts.size() < 4:
			continue
		var element: String = parts[0]
		var material: String = parts[1]
		var damage_name: String = parts[2]
		var substrate: int = parts[3].to_int()
		var entry: Dictionary = registry.get_variant(key)
		var img: Image = cache.get_image_at(int(entry.get("source_id", -1)),
			entry.get("atlas_coords", Vector2i(-1, -1)))
		if img == null:
			push_warning("[ATOM-EXPORT] readback failed for %s — skipped" % key)
			continue
		var family: Dictionary = _family_of(damage_name, material)
		var fname := "%s__%s__%s__v%d__s%d.png" % [
			element.to_lower(), material, family["name"], int(family["variant"]), substrate]
		var save_err := img.save_png(out_dir.path_join(fname))
		if save_err != OK:
			push_warning("[ATOM-EXPORT] save failed for %s: %s" % [fname, error_string(save_err)])
			continue
		manifest.append({
			"file": fname, "element": element, "material": material,
			"family": family["name"], "variant": int(family["variant"]),
			"substrate": substrate, "damage_name": damage_name,
		})
		written += 1

	var mf := FileAccess.open(out_dir.path_join("manifest.json"), FileAccess.WRITE)
	if mf == null:
		push_error("[ATOM-EXPORT] cannot write manifest.json to %s" % out_dir)
	else:
		mf.store_string(JSON.stringify({
			"map_id": room.map_id if "map_id" in room else "",
			"registered": registry.size(),
			"exported": written,
			"atoms": manifest,
		}, "  "))
		mf.close()

	print("[ATOM-EXPORT] wrote %d of %d registered atoms to %s" % [written, registry.size(), out_dir])
	return written


## One atom, read back from the page it was composited onto. Returns null (and
## says so) rather than a blank tile when the readback fails — a silently empty
## cell on a sheet whose whole job is proving atoms exist would be the worst
## possible failure mode here.
func _atom_tile(cache, entry: Dictionary) -> Control:
	if entry.is_empty():
		return null
	var img: Image = cache.get_image_at(int(entry.get("source_id", -1)),
		entry.get("atlas_coords", Vector2i(-1, -1)))
	if img == null:
		push_warning("[ATOM-SHEET] readback failed for source_id=%s atlas=%s" % [
			entry.get("source_id"), entry.get("atlas_coords")])
		return null
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(img)
	rect.custom_minimum_size = Vector2(img.get_width() * _atom_scale, img.get_height() * _atom_scale)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect
