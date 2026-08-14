## CHARACTER_MASTER_PLAN Part 0 / S1 — do normal maps survive mobile texture
## compression?
##
## THE QUESTION. D17's entire relight technique reads a baked normal map per
## pixel. Lossy VRAM compression corrupts normals in a way that surfaces as
## WRONG LIGHTING rather than as visible blur — so it can pass a "looks fine"
## eyeball check and still be broken. If it does not survive, the character's
## normal maps need an uncompressed budget, which changes CHARACTER_MASTER_PLAN
## §8's RAM arithmetic materially.
##
## WHAT IS MEASURED. Not the normal maps — the LIT OUTPUT, through the real
## `flat_normal_relight.gdshader`, because what matters is what the player sees.
## Source frames are the shotgun's real bake (120 colour + 120 normal pairs),
## produced by actor_frame_bake_spike.gd at the real camera convention. No
## synthetic fixture: this is the actual art the actual shader consumes.
##
## THE PIXEL-DIFF GATE IS EARNED, NOT ASSUMED (CLAUDE.md). Every run first
## renders the SAME uncompressed config twice and diffs it. If that is not 0,
## the harness is non-deterministic and every other number in the run is noise
## wearing a number — the script says so and stops trusting itself. This project
## measured 36 733 pixels of difference between two identical captures on
## 2026-08-09; the discipline exists because it was paid for.
##
## THE SECOND VALIDITY GATE (D22's trap). A light direction that happens to
## back-light the object produces a nearly flat lit image, and a diff against a
## flat image is ~0 for the WRONG REASON — it measures "nothing was lit", not
## "compression is safe". So each light direction reports the reference image's
## own luma spread, and any direction that fails to produce real directional
## variation is reported as INVALID rather than as a pass.
##
## Grazing light is included deliberately: normal error is amplified at grazing
## angles, so a technique that survives head-on light can still fail there.
##
## Must run WINDOWED (real GPU rasterizer). Run via:
##   godot --path . --position 4000,4000 \
##     --script res://godot/scripts/tools/s1_normal_compression_spike.gd
extends SceneTree

const FRAMES_DIR := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/shotgun_frames/"
const EVIDENCE_DIR := "res://Screenshots/history/"

## Four frames spread across the 120-frame rotation — one angle is not evidence.
const TEST_FRAMES: Array[int] = [0, 30, 60, 90]

## Camera-space light directions. `grazing` is the stress case.
const LIGHT_DIRS: Array[Dictionary] = [
	{"name": "front", "dir": Vector3(0.0, 0.0, 1.0)},
	{"name": "side45", "dir": Vector3(0.707, 0.0, 0.707)},
	{"name": "grazing", "dir": Vector3(0.95, 0.10, 0.30)},
]

## Opaque-pixel threshold, matching the shader's own `outline_threshold` default
## (0.4) — the shader only relights pixels above it, so anything below is not
## part of the question.
const ALPHA_CUTOFF := 102  ## 0.4 * 255

## A lit reference whose luma spread is below this is not exercising the normal
## map enough for a diff against it to mean anything (D22's trap).
const MIN_VALID_LUMA_SPREAD := 12.0

## A shader variant that RECONSTRUCTS Z from RG, which is the contract
## COMPRESS_SOURCE_NORMAL is written against: it packs the normal into two
## channels and expects the consumer to rebuild the third. The shipped
## flat_normal_relight.gdshader reads .rgb directly, so it does NOT hold up its
## end — which is why the first run measured SOURCE_NORMAL as catastrophically
## worse instead of better. This variant exists to ask the real question: with a
## shader that honours the contract, does two-channel normal compression (the
## industry-standard way to compress normals) beat compressing them as colour?
##
## Deliberately mirrors the shipped shader's lighting maths EXACTLY and skips
## only the outline branch — which never executes inside the silhouette, the
## only region this spike measures. Not a substitute for the real shader
## elsewhere; a spike-local variant, and the production shader is untouched.
const RECONSTRUCT_SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D normal_tex : source_color, filter_nearest;
uniform vec3 light_dir = vec3(0.0, 0.0, 1.0);
uniform vec3 light_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float light_intensity : hint_range(0.0, 3.0) = 1.0;
uniform float ambient : hint_range(0.0, 1.0) = 0.55;
uniform float specular_strength : hint_range(0.0, 2.0) = 0.4;
uniform float specular_shininess : hint_range(1.0, 128.0) = 16.0;

void fragment() {
	vec4 albedo = texture(TEXTURE, UV);
	vec4 n_sample = texture(normal_tex, UV);
	vec2 nxy = n_sample.rg * 2.0 - 1.0;
	float nz = sqrt(max(0.0, 1.0 - dot(nxy, nxy)));
	vec3 n = normalize(vec3(nxy, nz));
	vec3 l = normalize(light_dir);
	float ndotl = clamp(dot(n, l), 0.0, 1.0);
	vec3 view_dir = vec3(0.0, 0.0, 1.0);
	vec3 half_vec = normalize(l + view_dir);
	float spec = pow(clamp(dot(n, half_vec), 0.0, 1.0), specular_shininess) * specular_strength;
	vec3 lit = albedo.rgb * (ambient + ndotl * light_intensity * light_color) + spec * light_color;
	lit = clamp(lit, 0.0, 1.0);
	COLOR = vec4(lit, albedo.a);
}
"""

var _viewport: SubViewport
var _rect: TextureRect
var _material: ShaderMaterial
var _material_reconstruct: ShaderMaterial
var _vp_size := Vector2i(160, 160)


func _init() -> void:
	print("=== S1 — normal maps under mobile texture compression ===")
	print("Source: %s (real bake, not a fixture)" % FRAMES_DIR)
	_run.call_deferred()


func _run() -> void:
	var shader: Shader = load("res://godot/shaders/flat_normal_relight.gdshader")
	if shader == null:
		push_error("[S1] could not load flat_normal_relight.gdshader — aborting")
		quit(1)
		return

	# Size the rig from the real frames rather than assuming the bake's constant.
	var probe := _load_raw(FRAMES_DIR + "frame_00_color.png")
	if probe == null:
		push_error("[S1] could not load frame_00_color.png — aborting")
		quit(1)
		return
	_vp_size = Vector2i(probe.get_width(), probe.get_height())
	print("Frame size: %dx%d" % [_vp_size.x, _vp_size.y])

	_build_rig(shader)
	await process_frame

	var formats := _candidate_formats()
	var determinism_ok := true
	var results: Array[Dictionary] = []
	## Lit images kept from the stress case, for the side-by-side the Director
	## actually judges "is this acceptable?" against. The numbers decide the
	## architecture; the strip decides the tolerance.
	var strip: Array[Dictionary] = []

	for frame_idx in TEST_FRAMES:
		var color_img := _load_raw(FRAMES_DIR + "frame_%02d_color.png" % frame_idx)
		var normal_img := _load_raw(FRAMES_DIR + "frame_%02d_normal.png" % frame_idx)
		if color_img == null or normal_img == null:
			push_warning("[S1] frame %d missing — skipped" % frame_idx)
			continue

		var color_tex := ImageTexture.create_from_image(color_img)
		var ref_tex := ImageTexture.create_from_image(_as_rgb8(normal_img))

		for entry in LIGHT_DIRS:
			var ldir: Vector3 = entry["dir"]
			var lname: String = entry["name"]

			var lit_ref: Image = await _render(color_tex, ref_tex, ldir)
			var lit_ref2: Image = await _render(color_tex, ref_tex, ldir)

			# --- Gate 1: earn the diff. Same config, twice. ---
			var self_diff := _compare(lit_ref, lit_ref2, color_img)
			if self_diff["max"] != 0:
				determinism_ok = false
				print("  [HARNESS] frame %d %s — SAME-CONFIG DIFF max=%d mean=%.3f (NOT deterministic)"
					% [frame_idx, lname, self_diff["max"], self_diff["mean"]])

			# --- Gate 2: is this light direction exercising the normal map? ---
			var spread := _luma_spread(lit_ref, color_img)
			var valid := spread >= MIN_VALID_LUMA_SPREAD

			for fmt in formats:
				var comp_img := _as_rgb8(normal_img)
				var err: int = comp_img.compress(fmt["mode"], fmt["src"])
				if err != OK:
					print("  [%s] compress failed (err %d) — format unavailable here" % [fmt["name"], err])
					continue
				var comp_tex := ImageTexture.create_from_image(comp_img)
				# Ground truth is ALWAYS the uncompressed normal through the
				# SHIPPED shader — that is what the player should see. Only the
				# candidate side swaps in the Z-reconstructing variant.
				var mat: ShaderMaterial = _material_reconstruct if fmt["rebuild_z"] else null
				var lit_comp: Image = await _render(color_tex, comp_tex, ldir, mat)
				if frame_idx == TEST_FRAMES[0] and lname == "grazing":
					strip.append({"label": fmt["name"], "img": lit_comp})
				var d := _compare(lit_ref, lit_comp, color_img)
				results.append({
					"frame": frame_idx, "light": lname, "format": fmt["name"],
					"max": d["max"], "mean": d["mean"], "over2": d["over2"],
					"pixels": d["pixels"], "spread": spread, "valid": valid,
				})

			if frame_idx == TEST_FRAMES[0] and lname == "grazing":
				strip.push_front({"label": "UNCOMPRESSED (truth)", "img": lit_ref})

	_build_comparison_strip(strip)
	_report(results, determinism_ok)
	quit(0)


## One PNG: every candidate side by side at the grazing angle (the stress case),
## at 4x nearest-neighbour so per-pixel error is actually visible, composited
## over mid-grey so transparency does not read as a difference.
func _build_comparison_strip(entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		return
	# Zoom is overridable because the two questions need different views:
	# 8x FINDS an artifact, 1x decides whether it MATTERS at the size the player
	# actually sees (the shotgun's real silhouette is 66x33 px). Director,
	# 2026-08-14: "queria ver em tamanho real ... pra decidir."
	var zoom_env := OS.get_environment("S1_ZOOM")
	var ZOOM: int = maxi(1, int(zoom_env)) if zoom_env != "" else 8
	const PAD := 6
	# Crop to the silhouette before zooming — the object fills a small part of
	# the 160x160 canvas, and a strip where it is 40 px wide cannot be judged.
	# One crop rect shared by every cell, so the comparison stays aligned.
	var crop: Rect2i = entries[0]["img"].get_used_rect().grow(2)
	crop = crop.intersection(Rect2i(Vector2i.ZERO, entries[0]["img"].get_size()))
	if crop.size.x <= 0 or crop.size.y <= 0:
		crop = Rect2i(Vector2i.ZERO, entries[0]["img"].get_size())
	var cell_w: int = crop.size.x * ZOOM
	var cell_h: int = crop.size.y * ZOOM
	var strip := Image.create(
		cell_w * entries.size() + PAD * (entries.size() + 1),
		cell_h + PAD * 2, false, Image.FORMAT_RGB8)
	strip.fill(Color(0.10, 0.10, 0.12))

	for i in range(entries.size()):
		var src: Image = entries[i]["img"]
		var cell := Image.create(cell_w, cell_h, false, Image.FORMAT_RGB8)
		cell.fill(Color(0.45, 0.45, 0.45))
		for y in range(cell_h):
			for x in range(cell_w):
				var c := src.get_pixel(crop.position.x + x / ZOOM, crop.position.y + y / ZOOM)
				if c.a > 0.01:
					# Composite over the grey so alpha is not mistaken for error.
					var g := Color(0.45, 0.45, 0.45)
					cell.set_pixel(x, y, Color(
						c.r * c.a + g.r * (1.0 - c.a),
						c.g * c.a + g.g * (1.0 - c.a),
						c.b * c.a + g.b * (1.0 - c.a)))
		strip.blit_rect(cell, Rect2i(Vector2i.ZERO, Vector2i(cell_w, cell_h)),
			Vector2i(PAD + i * (cell_w + PAD), PAD))

	_save_evidence(strip, "s1_normal_compression_comparison_%dx" % ZOOM)
	print("")
	print("Comparison strip order (left to right):")
	for e in entries:
		print("  - %s" % e["label"])


## ETC2 is the Android/GLES3-era baseline; ASTC is what modern iOS and Android
## actually ship. S3TC is desktop-only and included as a control, not a target.
##
## EACH IS TESTED TWICE, and the pair is the whole point of this spike. Block
## compressors are built for PERCEPTUAL colour; a normal map is correlated
## geometric data, and compressing it as if it were colour
## (COMPRESS_SOURCE_GENERIC) is a known way to wreck it. COMPRESS_SOURCE_NORMAL
## packs to two channels and reconstructs Z — valid here precisely because these
## are VIEW-SPACE normals facing the bake camera, so Z is always positive and
## reconstructable. Testing only the generic path would have measured a mistake
## rather than the technique.
func _candidate_formats() -> Array[Dictionary]:
	return [
		{"name": "ETC2/generic", "mode": Image.COMPRESS_ETC2, "src": Image.COMPRESS_SOURCE_GENERIC, "rebuild_z": false},
		{"name": "ETC2/nrm+rebuildZ", "mode": Image.COMPRESS_ETC2, "src": Image.COMPRESS_SOURCE_NORMAL, "rebuild_z": true},
		{"name": "ASTC/generic", "mode": Image.COMPRESS_ASTC, "src": Image.COMPRESS_SOURCE_GENERIC, "rebuild_z": false},
		{"name": "ASTC/nrm+rebuildZ", "mode": Image.COMPRESS_ASTC, "src": Image.COMPRESS_SOURCE_NORMAL, "rebuild_z": true},
		{"name": "S3TC/nrm+rbZ(ctl)", "mode": Image.COMPRESS_S3TC, "src": Image.COMPRESS_SOURCE_NORMAL, "rebuild_z": true},
	]


func _build_rig(shader: Shader) -> void:
	_viewport = SubViewport.new()
	_viewport.size = _vp_size
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.disable_3d = true

	_material = ShaderMaterial.new()
	_material.shader = shader
	# Leave every grade/outline uniform at its default: the question is the
	# normal map, and a non-default grade would fold its own clamping into the
	# measurement.

	var rshader := Shader.new()
	rshader.code = RECONSTRUCT_SHADER_CODE
	_material_reconstruct = ShaderMaterial.new()
	_material_reconstruct.shader = rshader

	_rect = TextureRect.new()
	_rect.material = _material
	_rect.size = Vector2(_vp_size)
	_rect.stretch_mode = TextureRect.STRETCH_KEEP
	_viewport.add_child(_rect)
	root.add_child(_viewport)


func _render(color_tex: Texture2D, normal_tex: Texture2D, light_dir: Vector3,
		mat: ShaderMaterial = null) -> Image:
	var use_mat: ShaderMaterial = mat if mat != null else _material
	_rect.material = use_mat
	_rect.texture = color_tex
	use_mat.set_shader_parameter("normal_tex", normal_tex)
	use_mat.set_shader_parameter("light_dir", light_dir.normalized())
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	# Two frames: one to submit, one to guarantee the target is resolved before
	# read-back. Same "wait a real frame" discipline every rig in this repo
	# needed (actor_part0_spike, showcase_panel, actor_frame_bake_spike).
	await process_frame
	await process_frame
	return _viewport.get_texture().get_image()


func _load_raw(path: String) -> Image:
	# CLI-baked PNGs never pass the editor import scan, so plain load() fails on
	# them — the raw Image.load() route is the established workaround.
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return img


func _as_rgb8(src: Image) -> Image:
	var copy := Image.new()
	copy.copy_from(src)
	# The shader samples normal_tex.rgb only; dropping alpha keeps the
	# comparison about the normal itself and lets every candidate format apply.
	copy.convert(Image.FORMAT_RGB8)
	return copy


## Compares two lit images over the silhouette only, using the SOURCE colour
## frame's alpha as the mask — the shader does not relight anything below its
## own alpha threshold, so transparent margin is not part of the question.
func _compare(a: Image, b: Image, mask_src: Image) -> Dictionary:
	var max_d := 0
	var total := 0.0
	var over2 := 0
	var counted := 0
	for y in range(mini(a.get_height(), b.get_height())):
		for x in range(mini(a.get_width(), b.get_width())):
			if int(mask_src.get_pixel(x, y).a * 255.0) < ALPHA_CUTOFF:
				continue
			counted += 1
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var d := maxi(maxi(
				absi(int(ca.r * 255.0) - int(cb.r * 255.0)),
				absi(int(ca.g * 255.0) - int(cb.g * 255.0))),
				absi(int(ca.b * 255.0) - int(cb.b * 255.0)))
			max_d = maxi(max_d, d)
			total += float(d)
			if d > 2:
				over2 += 1
	var mean := (total / float(counted)) if counted > 0 else 0.0
	return {"max": max_d, "mean": mean, "over2": over2, "pixels": counted}


## Luma spread (max − min) across the silhouette. A near-flat lit image means
## the light direction is not exercising the normal map, so a diff against it
## proves nothing (D22).
func _luma_spread(lit: Image, mask_src: Image) -> float:
	var lo := 999.0
	var hi := -1.0
	for y in range(lit.get_height()):
		for x in range(lit.get_width()):
			if int(mask_src.get_pixel(x, y).a * 255.0) < ALPHA_CUTOFF:
				continue
			var c := lit.get_pixel(x, y)
			var luma := (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) * 255.0
			lo = minf(lo, luma)
			hi = maxf(hi, luma)
	return maxf(0.0, hi - lo)


func _save_evidence(img: Image, name: String) -> void:
	var dir := DirAccess.open(EVIDENCE_DIR)
	if dir == null:
		push_warning("[S1] evidence dir unavailable: %s" % EVIDENCE_DIR)
		return
	# Non-`auto_` name on purpose: the screenshot rotation keeps only the 50 most
	# recent auto_ files, and a cited capture that gets rotated away is a dead
	# citation (CLAUDE.md).
	var path := EVIDENCE_DIR + name + ".png"
	if img.save_png(path) != OK:
		push_warning("[S1] could not write evidence %s" % path)
	else:
		print("Evidence written: %s" % path)


func _report(results: Array[Dictionary], determinism_ok: bool) -> void:
	print("")
	print("=== HARNESS ===")
	if determinism_ok:
		print("Same-config re-render diff: 0 across every frame and light direction.")
		print("The pixel-diff gate is EARNED — the numbers below mean something.")
	else:
		print("NOT DETERMINISTIC — see [HARNESS] lines above.")
		print("Every number below is noise wearing a number. Do not cite this run.")

	print("")
	print("=== LIT-OUTPUT DELTA (compressed normal vs. uncompressed) ===")
	print("frame  light    format         maxΔ   meanΔ   px>2    of      spread  valid")
	for r in results:
		print("%-6d %-8s %-14s %-6d %-7.3f %-7d %-7d %-7.1f %s" % [
			r["frame"], r["light"], r["format"], r["max"], r["mean"],
			r["over2"], r["pixels"], r["spread"],
			"yes" if r["valid"] else "NO (flat — invalid)",
		])

	# Verdict only from directions that actually exercised the normal map.
	var valid_rows := results.filter(func(r): return r["valid"])
	if valid_rows.is_empty():
		print("")
		print("VERDICT: INCONCLUSIVE — no light direction produced real directional")
		print("variation, so nothing here measures compression. Retune LIGHT_DIRS.")
		return

	var by_format: Dictionary = {}
	for r in valid_rows:
		var f: String = r["format"]
		if not by_format.has(f):
			by_format[f] = {"max": 0, "mean": 0.0, "n": 0}
		by_format[f]["max"] = maxi(by_format[f]["max"], r["max"])
		by_format[f]["mean"] += r["mean"]
		by_format[f]["n"] += 1

	print("")
	print("=== VERDICT (valid light directions only) ===")
	for f in by_format:
		var m: Dictionary = by_format[f]
		print("%-14s worst maxΔ=%d   avg meanΔ=%.3f  over %d measurements"
			% [f, m["max"], m["mean"] / float(m["n"]), m["n"]])
	print("")
	print("Read this against what it decides: a large delta on ETC2/ASTC means the")
	print("character's normal maps need an uncompressed budget, and")
	print("CHARACTER_MASTER_PLAN §8's RAM arithmetic changes. A small one means D17")
	print("is safe to scale. The threshold is a judgment call for the Director, not")
	print("a number this script should assert on its own.")
