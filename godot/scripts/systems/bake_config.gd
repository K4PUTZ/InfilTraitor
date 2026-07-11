## BakeConfig — Unified bake system configuration
##
## Master kill-switch and feature toggles for the baking pipeline.
## Branch-exclusive (structural, not tested); values set at boot.

class_name BakeConfig

## Master kill-switch: enables baked atlas lookup in placement.
## DEV DEFAULT = true, ratified by the Director 2026-07-09 for the facade
## calibration phase (boot straight into baked TEXTURES). The shipped-build
## canon remains enabled=false — flip this back before any release build.
static var enabled: bool = true

## Blend mode for composite (material × facade)
## DEV DEFAULT = TEXTURE_ONLY (same ratification as above).
enum BlendMode { MULTIPLY, TEXTURE_ONLY, MATERIAL_ONLY, OVERLAY_EXPERIMENTAL, LINEAR_LIGHT }
static var blend_mode: BlendMode = BlendMode.TEXTURE_ONLY

## Feature toggles
static var theme_enabled: bool = true
static var variants_enabled: bool = true
static var facade_enabled: bool = true
static var facade_tops: bool = false  # TOP-01b: WIP - reverse map works but cell bounds are non-rectangular after shear
static var material_pattern_enabled: bool = true

## Debug flags
## BAKE-DIAG-01: verbose checkpoint logging across the full pipeline —
## extraction (edge count) -> compositor (combos/facades/lookup keys) ->
## registration (tileset source ids) -> placement (baked-hit vs generic-fallback
## counts per render() call). Set via user://bake_config.cfg [bake] debug_bake_set_dump=true.
static var debug_bake_set_dump: bool = false

## OVERLORD-PROBE-01: replace every facade with a synthetic grayscale marker
## (brightness staircase per 16-px column block + gridlines) so the on-screen
## wall reveals exactly which facade window each placed atom displays and in
## which reading order. Diagnostic only; never ships enabled.
## Set via user://bake_config.cfg [bake] debug_marker_facade=true.
static var debug_marker_facade: bool = false

## BAKE-CACHE-01: one-shot flag to clear the disk cache on next boot.
## Set via user://bake_config.cfg [bake] debug_clear_bake_cache=true.
## After boot completes, this flag is reset to false (one-shot behavior).
static var debug_clear_bake_cache: bool = false


static func load_config() -> void:
	# Load from config file if it exists
	var config = ConfigFile.new()
	var err = config.load("user://bake_config.cfg")
	if err == OK:
		# Defaults mirror the static dev defaults above so a partial config
		# file doesn't silently flip them
		enabled = config.get_value("bake", "enabled", enabled)
		blend_mode = config.get_value("bake", "blend_mode", blend_mode)
		facade_tops = config.get_value("bake", "facade_tops", facade_tops)
		debug_bake_set_dump = config.get_value("bake", "debug_bake_set_dump", debug_bake_set_dump)
		debug_marker_facade = config.get_value("bake", "debug_marker_facade", debug_marker_facade)
		debug_clear_bake_cache = config.get_value("bake", "debug_clear_bake_cache", debug_clear_bake_cache)
		print("[BakeConfig] Loaded from config file")

	print("[BakeConfig] Enabled: %s, Blend Mode: %d, Facade Tops: %s" % [enabled, blend_mode, facade_tops])
