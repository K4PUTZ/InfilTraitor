## BakeConfig — Unified bake system configuration
##
## Master kill-switch and feature toggles for the baking pipeline.
## Branch-exclusive (structural, not tested); values set at boot.

class_name BakeConfig

## Master kill-switch: enables baked atlas lookup in placement
static var enabled: bool = false

## Blend mode for composite (material × facade)
enum BlendMode { MULTIPLY, TEXTURE_ONLY, MATERIAL_ONLY, OVERLAY_EXPERIMENTAL, LINEAR_LIGHT }
static var blend_mode: BlendMode = BlendMode.LINEAR_LIGHT

## Feature toggles
static var theme_enabled: bool = true
static var variants_enabled: bool = true
static var facade_enabled: bool = true
static var material_pattern_enabled: bool = true

## Debug flags
static var debug_bake_set_dump: bool = false  # Log every key in bake_set


static func load_config() -> void:
	# Load from config file if it exists
	var config = ConfigFile.new()
	var err = config.load("user://bake_config.cfg")
	if err == OK:
		enabled = config.get_value("bake", "enabled", false)
		blend_mode = config.get_value("bake", "blend_mode", BlendMode.MULTIPLY)
		debug_bake_set_dump = config.get_value("bake", "debug_bake_set_dump", false)
		print("[BakeConfig] Loaded from config file")

	print("[BakeConfig] Enabled: %s, Blend Mode: %d" % [enabled, blend_mode])
