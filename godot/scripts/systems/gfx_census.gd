## GfxCensus — PERFORMANCE_BUDGET PB-2: WHO owns the graphics memory.
##
## The Galaxy A16 reads ~590 MiB of `Graphics` PSS after a PLAYGROUND load and Android's release build has no engine counter
## for it (`RenderingServer.get_rendering_info` reads 0 there). This walks what the scene actually HOLDS on the GPU side and
## sizes it from the CPU-side description: every texture a material, a mesh or a canvas item points at (deduplicated by RID,
## sized with `Image.get_data_size()` so the format and the mipmaps are counted), every mesh's vertex / index arrays, every
## MultiMesh's instance buffer, and the viewports' render targets. Each item lands in a CATEGORY (asset folder or owning
## node), so the answer is a table, not a total.
##
## ⚠️ AN ESTIMATE OF THE CONTENT, NOT A DRIVER READ. The driver adds padding, its own copies, the shader cache and the
## render targets' intermediate buffers; compare the sum with the engine counters printed beside it (desktop) and with the
## handset's `GL mtrack` total, and treat the gap as "engine/driver", never as zero.
##
## Called from the scenario op `gfx_census <name>`. Diagnostic only: it reads images back from the GPU (slow), never in play.
class_name GfxCensus
extends RefCounted

const MIB: float = 1024.0 * 1024.0

## Textures made by `gpu_alloc`, held so the driver keeps them.
static var _probe_textures: Array[Texture2D] = []


## PB-2's allocator probe: one RGBA8 texture of `mib` MiB (no mipmaps), kept alive, so the driver's total (`GL mtrack`)
## can be read against a KNOWN step. A step of N that moves the total by much more than N is the allocator reserving a
## block, not the content.
static func gpu_alloc(mib: int) -> void:
	var side: int = int(sqrt(float(mib) * MIB / 4.0))
	var img: Image = Image.create(side, side, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	_probe_textures.append(ImageTexture.create_from_image(img))
	print("[GFX-CENSUS] gpu_alloc %d MiB (%dx%d), probe total %d texture(s); vram video %.1f MiB" % [mib, side, side,
		_probe_textures.size(), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / MIB])


static func report(root: Node, label: String) -> void:
	var tex_bytes: Dictionary = {}     ## category -> bytes
	var tex_count: Dictionary = {}
	var mesh_bytes: Dictionary = {}
	var mesh_count: Dictionary = {}
	var seen: Dictionary = {}          ## RID id -> true
	var top: Array = []                ## [bytes, description]
	var nodes: Array[Node] = []
	_collect(root, nodes)
	for node: Node in nodes:
		var cat: String = _node_category(node)
		for tex: Texture in _textures_of(node):
			var rid_id: int = tex.get_rid().get_id()
			if rid_id == 0 or seen.has(rid_id):
				continue
			seen[rid_id] = true
			var b: int = _texture_bytes(tex)
			var tcat: String = _texture_category(tex, cat)
			tex_bytes[tcat] = int(tex_bytes.get(tcat, 0)) + b
			tex_count[tcat] = int(tex_count.get(tcat, 0)) + 1
			top.append([b, "%s %s (%s)" % [tex.get_class(), _tex_desc(tex), tcat]])
		for mesh: Mesh in _meshes_of(node):
			var rid_id: int = mesh.get_rid().get_id()
			if rid_id == 0 or seen.has(rid_id):
				continue
			seen[rid_id] = true
			var b: int = _mesh_bytes(mesh)
			mesh_bytes[cat] = int(mesh_bytes.get(cat, 0)) + b
			mesh_count[cat] = int(mesh_count.get(cat, 0)) + 1
		if node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
			var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
			var floats: int = 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
			var b: int = mm.instance_count * floats * 4
			mesh_bytes[cat + " [instances]"] = int(mesh_bytes.get(cat + " [instances]", 0)) + b
	var rt_bytes: int = 0
	var rt_lines: PackedStringArray = []
	for node: Node in nodes:
		if node is Viewport:
			var size: Vector2i = (node as Viewport).get_visible_rect().size
			## colour (RGBA8) + depth (32-bit), the minimum a 3D viewport holds; HDR / MSAA / screen copies come on top.
			var b: int = size.x * size.y * 8
			rt_bytes += b
			rt_lines.append("%s %dx%d %.1f MiB" % [node.name, size.x, size.y, float(b) / MIB])
	print("[GFX-CENSUS] === %s ===" % label)
	print("[GFX-CENSUS] engine counters: texture %.1f · buffer %.1f · video %.1f MiB" % [
		float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / MIB,
		float(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)) / MIB,
		float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / MIB])
	var tex_total: int = _print_table("texture", tex_bytes, tex_count)
	var mesh_total: int = _print_table("mesh", mesh_bytes, mesh_count)
	print("[GFX-CENSUS] render targets (min) %.1f MiB: %s" % [float(rt_bytes) / MIB, ", ".join(rt_lines)])
	top.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	for i in mini(25, top.size()):
		print("[GFX-CENSUS] top %2d %7.2f MiB %s" % [i + 1, float(top[i][0]) / MIB, top[i][1]])
	_print_cached_textures()
	_print_shaders(nodes)
	## Pipelines compiled so far, by source: a pipeline costs driver memory (the shader binary) that no counter above sees.
	print("[GFX-CENSUS] pipelines compiled: canvas %d · mesh %d · surface %d · draw %d · specialization %d" % [
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))])
	print("[GFX-CENSUS] SUM textures %.1f + meshes %.1f + targets %.1f = %.1f MiB (nodes %d)" % [
		float(tex_total) / MIB, float(mesh_total) / MIB, float(rt_bytes) / MIB,
		float(tex_total + mesh_total + rt_bytes) / MIB, nodes.size()])


static func _print_table(kind: String, bytes: Dictionary, count: Dictionary) -> int:
	var keys: Array = bytes.keys()
	keys.sort_custom(func(a, b) -> bool: return int(bytes[a]) > int(bytes[b]))
	var total: int = 0
	for k in keys:
		total += int(bytes[k])
		print("[GFX-CENSUS] %-7s %8.2f MiB  x%-5d %s" % [kind, float(bytes[k]) / MIB, int(count.get(k, 0)), k])
	return total


static func _collect(node: Node, out: Array[Node]) -> void:
	out.append(node)
	for child in node.get_children():
		_collect(child, out)


## The first two named ancestors under the scene root: enough to tell the board from the actors from the props.
static func _node_category(node: Node) -> String:
	var path: String = str(node.get_path())
	var parts: PackedStringArray = path.trim_prefix("/root/").split("/")
	if parts.size() <= 2:
		return "/".join(parts) + " :" + node.get_class()
	return "%s/%s" % [parts[1], parts[2].left(32)]


static func _texture_category(tex: Texture, node_cat: String) -> String:
	var path: String = tex.resource_path
	if path.is_empty() or path.contains("::"):
		return "runtime @ " + node_cat
	var dirs: PackedStringArray = path.trim_prefix("res://").get_base_dir().split("/")
	return "/".join(dirs.slice(0, mini(3, dirs.size())))


static func _tex_desc(tex: Texture) -> String:
	if tex is Texture2D:
		return "%dx%d %s" % [(tex as Texture2D).get_width(), (tex as Texture2D).get_height(), tex.resource_path.get_file()]
	return tex.resource_path.get_file()


static func _textures_of(node: Node) -> Array[Texture]:
	var out: Array[Texture] = []
	var materials: Array[Material] = []
	if node is GeometryInstance3D:
		var gi: GeometryInstance3D = node
		if gi.material_override != null:
			materials.append(gi.material_override)
		if gi.material_overlay != null:
			materials.append(gi.material_overlay)
		if node is MeshInstance3D:
			var mi: MeshInstance3D = node
			for s in mi.get_surface_override_material_count():
				if mi.get_surface_override_material(s) != null:
					materials.append(mi.get_surface_override_material(s))
	for mesh: Mesh in _meshes_of(node):
		for s in mesh.get_surface_count():
			if mesh.surface_get_material(s) != null:
				materials.append(mesh.surface_get_material(s))
	if node is CanvasItem and (node as CanvasItem).material != null:
		materials.append((node as CanvasItem).material)
	for mat: Material in materials:
		_textures_in_object(mat, out)
		if mat.next_pass != null:
			_textures_in_object(mat.next_pass, out)
	_textures_in_object(node, out)
	return out


static func _textures_in_object(obj: Object, out: Array[Texture]) -> void:
	if obj is ShaderMaterial:
		var sm: ShaderMaterial = obj
		if sm.shader != null:
			for u: Dictionary in sm.shader.get_shader_uniform_list():
				var v = sm.get_shader_parameter(str(u["name"]))
				if v is Texture:
					out.append(v)
		return
	for p: Dictionary in obj.get_property_list():
		if int(p["type"]) != TYPE_OBJECT:
			continue
		var v = obj.get(str(p["name"]))
		if v is Texture and not (v is ViewportTexture):
			out.append(v)


static func _meshes_of(node: Node) -> Array[Mesh]:
	var out: Array[Mesh] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append((node as MeshInstance3D).mesh)
	elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null \
			and (node as MultiMeshInstance3D).multimesh.mesh != null:
		out.append((node as MultiMeshInstance3D).multimesh.mesh)
	return out


static func _texture_bytes(tex: Texture) -> int:
	if tex is Texture2D:
		var img: Image = (tex as Texture2D).get_image()
		if img != null:
			return img.get_data_size()
		return (tex as Texture2D).get_width() * (tex as Texture2D).get_height() * 4
	if tex is Texture3D:
		var total: int = 0
		for img: Image in (tex as Texture3D).get_data():
			total += img.get_data_size()
		return total
	if tex is TextureLayered:
		var tl: TextureLayered = tex
		var total: int = 0
		for i in tl.get_layers():
			var img: Image = tl.get_layer_data(i)
			if img != null:
				total += img.get_data_size()
		return total
	return 0


## Vertex and index arrays as stored CPU-side: an upper estimate of the GPU copy (the driver may pack normals and UVs).
static func _mesh_bytes(mesh: Mesh) -> int:
	var total: int = 0
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		for a in arrays:
			if a is PackedVector3Array:
				total += (a as PackedVector3Array).size() * 12
			elif a is PackedVector2Array:
				total += (a as PackedVector2Array).size() * 8
			elif a is PackedColorArray:
				total += (a as PackedColorArray).size() * 16
			elif a is PackedFloat32Array:
				total += (a as PackedFloat32Array).size() * 4
			elif a is PackedInt32Array:
				total += (a as PackedInt32Array).size() * 4
			elif a is PackedByteArray:
				total += (a as PackedByteArray).size()
	return total


## Every imported texture the ResourceLoader holds in its cache, whether or not a node points at it (a registry's
## dictionary, a preload in a script): walks res:// for texture files and asks `ResourceLoader.has_cached()`. On an
## exported pack the sources are listed as `<file>.import` / `<file>.remap`, so both suffixes are stripped.
static func _print_cached_textures() -> void:
	var files: PackedStringArray = []
	_walk("res://", files)
	var groups: Dictionary = {}
	var counts: Dictionary = {}
	var big: Array = []
	var total: int = 0
	for path: String in files:
		if not ResourceLoader.has_cached(path):
			continue
		var res: Resource = ResourceLoader.load(path)
		if not (res is Texture2D):
			continue
		var tex: Texture2D = res
		var img: Image = tex.get_image()
		var b: int = img.get_data_size() if img != null else tex.get_width() * tex.get_height() * 4
		total += b
		var key: String = path.trim_prefix("res://").get_base_dir()
		groups[key] = int(groups.get(key, 0)) + b
		counts[key] = int(counts.get(key, 0)) + 1
		big.append([b, "%s %dx%d fmt %d" % [path.get_file(), tex.get_width(), tex.get_height(), img.get_format() if img != null else -1]])
	var keys: Array = groups.keys()
	keys.sort_custom(func(a, b) -> bool: return int(groups[a]) > int(groups[b]))
	print("[GFX-CENSUS] cached imported textures: %.1f MiB" % (float(total) / MIB))
	for i in mini(30, keys.size()):
		print("[GFX-CENSUS] cached %8.2f MiB x%-4d %s" % [float(groups[keys[i]]) / MIB, int(counts[keys[i]]), keys[i]])
	big.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	for i in mini(15, big.size()):
		print("[GFX-CENSUS] cached-top %6.2f MiB %s" % [float(big[i][0]) / MIB, big[i][1]])


static func _walk(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		if sub.begins_with(".") or sub == "export" or sub == "Screenshots":
			continue
		_walk(dir_path.path_join(sub), out)
	for f: String in dir.get_files():
		var name: String = f.trim_suffix(".remap").trim_suffix(".import")
		if name.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "svg", "exr", "hdr", "tga", "ktx"]:
			var full: String = dir_path.path_join(name)
			if not out.has(full):
				out.append(full)


## Distinct Shader resources in use, and how many share one source text: every distinct Shader is compiled on its own
## (pipelines and driver binaries a texture counter never sees), even when its code is identical to another's.
static func _print_shaders(nodes: Array[Node]) -> void:
	var by_rid: Dictionary = {}
	var by_code: Dictionary = {}
	for node: Node in nodes:
		var mats: Array[Material] = []
		if node is GeometryInstance3D and (node as GeometryInstance3D).material_override != null:
			mats.append((node as GeometryInstance3D).material_override)
		if node is CanvasItem and (node as CanvasItem).material != null:
			mats.append((node as CanvasItem).material)
		for mesh: Mesh in _meshes_of(node):
			for s in mesh.get_surface_count():
				if mesh.surface_get_material(s) != null:
					mats.append(mesh.surface_get_material(s))
		for m: Material in mats:
			if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
				var sh: Shader = (m as ShaderMaterial).shader
				by_rid[sh.get_rid().get_id()] = true
				var h: int = sh.code.hash()
				by_code[h] = int(by_code.get(h, 0)) + (0 if by_rid.has(-sh.get_rid().get_id()) else 1)
				by_rid[-sh.get_rid().get_id()] = true
	print("[GFX-CENSUS] shaders: %d distinct Shader resources, %d distinct source texts" % [by_rid.size() / 2, by_code.size()])
