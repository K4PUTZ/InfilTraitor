## Texture Resolver — Fallback chain for baked facade sources
## Part of BAKING_MASTER_PLAN: §4.2 TextureResolver
## See TEXTURE_CATALOG.md for the full texture contract

class_name TextureResolver

enum Tier { USER, DEFAULT, NONE }

class ResolvedTexture:
	var image: Image
	var tier: Tier
	
	func _init(p_image: Image, p_tier: Tier) -> void:
		image = p_image
		tier = p_tier


const MAX_FILE_SIZE_BYTES: int = 10 * 1024 * 1024  # 10 MB

var tex_user_dir: String = "user://textures/"
var tex_default_dir: String = "res://ASSETS/TEXTURES/defaults/"
var log_lines: PackedStringArray = []

## Constructor with optional path overrides (for testing)
func _init(p_user_dir: String = "", p_default_dir: String = "") -> void:
	if p_user_dir:
		tex_user_dir = p_user_dir
	if p_default_dir:
		tex_default_dir = p_default_dir


## Single entry point: resolve a texture by ID.
## Returns ResolvedTexture with image (or null) and tier.
## Logs evidence at every step.
func resolve(texture_id: String) -> ResolvedTexture:
	_log("")  # blank line for readability
	_log("Attempting to resolve: %s" % texture_id)
	
	# Attempt user:// tier (try PNG first, then WebP)
	for ext in [".png", ".webp"]:
		var user_path := tex_user_dir.path_join(texture_id + ext)
		var img := _try_load_and_validate(user_path, "USER")
		if img:
			_log("[RESOLVER] %s resolved from USER%s (dims %dx%d)" % [texture_id, ext, img.get_width(), img.get_height()])
			return ResolvedTexture.new(img, Tier.USER)
	
	# Attempt res://ASSETS/TEXTURES/defaults/ tier (try PNG first, then WebP)
	for ext in [".png", ".webp"]:
		var default_path := tex_default_dir.path_join(texture_id + ext)
		var img := _try_load_and_validate(default_path, "DEFAULT")
		if img:
			_log("[RESOLVER] %s resolved from DEFAULT%s (dims %dx%d)" % [texture_id, ext, img.get_width(), img.get_height()])
			return ResolvedTexture.new(img, Tier.DEFAULT)
	
	# Fallback: material-only
	_log("[RESOLVER] %s UNRESOLVED; wall will use MATERIAL-ONLY rendering" % texture_id)
	return ResolvedTexture.new(null, Tier.NONE)


## Try to load and validate an image from the given path.
## Returns the Image if valid, null otherwise.
## Logs each step (skip reason or success).
func _try_load_and_validate(path: String, tier_name: String) -> Image:
	# Convert path for file checking (handle both res:// and user:// paths)
	var check_path: String = path
	if path.begins_with("res://"):
		# For res:// paths, use ResourceLoader
		if not ResourceLoader.exists(check_path):
			_log("  [%s] File not found: %s" % [tier_name, path])
			return null
	elif path.begins_with("user://"):
		# For user:// paths, use FileAccess
		if not FileAccess.file_exists(check_path):
			_log("  [%s] File not found: %s" % [tier_name, path])
			return null
	else:
		# Unknown path scheme
		_log("  [%s] Unknown path scheme: %s" % [tier_name, path])
		return null
	
	# Try to load the image
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		_log("  [%s] Decode failed (%s): %s" % [tier_name, error_string(err), path])
		return null
	
	# Check file size (use a heuristic: image memory footprint)
	var file_size_estimate := img.get_width() * img.get_height() * 4  # RGBA estimate
	if file_size_estimate > MAX_FILE_SIZE_BYTES:
		_log("  [%s] Exceeds size cap (~%d MB): %s" % [tier_name, int(float(file_size_estimate) / (1024.0 * 1024.0)), path])
		return null
	
	# Validate grayscale (all pixels: R == G == B) — B2 scopes this to wall/ceiling
	# facades; "slab_" sources (D20, renamed from "ground_") are the floor-bake
	# full-color exception (see BAKE_SYSTEM_REFERENCE.md B2) and skip this
	# check on purpose.
	var is_slab_source: bool = path.get_file().begins_with("slab_")
	if not is_slab_source and not _is_grayscale(img):
		_log("  [%s] Not grayscale (colored facades violate D9); rejected: %s" % [tier_name, path])
		return null
	
	# Validate dimensions (category inferred from filename)
	if not _validate_dimensions(path, img):
		_log("  [%s] Dimension contract violation: %s" % [tier_name, path])
		return null
	
	# All checks passed
	_log("  [%s] Validation PASS: %s" % [tier_name, path])
	return img


## Check if image is purely grayscale (all pixels have R == G == B)
func _is_grayscale(img: Image) -> bool:
	# Sample every Nth pixel for speed (not every pixel)
	var step := maxi(1, int(float(img.get_width() * img.get_height()) / 1000.0))  # ~1000 samples
	var y := 0
	while y < img.get_height():
		var x := 0
		while x < img.get_width():
			var pixel := img.get_pixel(x, y)
			# Allow small tolerance for JPEG artifacts (±1/255 ≈ 0.004)
			var tolerance := 0.01
			if abs(pixel.r - pixel.g) > tolerance or abs(pixel.g - pixel.b) > tolerance:
				return false
			x += step
		y += step
	return true


## Validate image dimensions match the contract for its category.
## Category is inferred from filename prefix.
func _validate_dimensions(path: String, img: Image) -> bool:
	var filename := path.get_file()
	var expected_w: int
	var expected_h: int
	
	# Infer category from filename
	if filename.begins_with("facade_"):
		expected_w = 64 * GeometryCoords.TEX_AUTHORING_N
		expected_h = 32 * GeometryCoords.TEX_AUTHORING_N
	elif filename.begins_with("slice_"):
		expected_w = 8 * GeometryCoords.TEX_AUTHORING_N
		expected_h = 8 * GeometryCoords.TEX_AUTHORING_N
	elif filename.begins_with("slab_"):
		# Isotropic floor-bake plane: resolve_flat() folds both axes at
		# SHEET_COLS=64, so 64 * TEX_AUTHORING_N is the addressable domain
		# on BOTH axes (unlike the wall facade's anisotropic 64x32).
		expected_w = 64 * GeometryCoords.TEX_AUTHORING_N
		expected_h = 64 * GeometryCoords.TEX_AUTHORING_N
	else:
		_log("    WARN: unrecognized category prefix in filename: %s" % filename)
		return false
	
	var actual_w := img.get_width()
	var actual_h := img.get_height()
	
	if actual_w != expected_w or actual_h != expected_h:
		_log("    Expected %dx%d, got %dx%d" % [expected_w, expected_h, actual_w, actual_h])
		return false
	
	return true


## Log a message to console and append to log_lines.
func _log(msg: String) -> void:
	print(msg)
	log_lines.append(msg)


## Return the full log transcript.
func get_log() -> PackedStringArray:
	return log_lines.duplicate()


## Return the log as a single string (for easier inspection).
func get_log_string() -> String:
	return "\n".join(log_lines)
