## FrameRate — the player's frame-rate cap (Director, 2026-10-08).
##
## The default is 30 fps on every platform: the ratified target (`DEVICE_DIAGNOSTICS` §0.5), and on the floor device
## (Moto g04s) 30 and 60 are the same run, because a frame costs ~23 ms of GPU and vsync already holds it at 30. On a faster
## phone or a desktop the cap saves power and heat. A player with better hardware may choose 60 or no cap (0); the choice
## is kept in `user://settings.cfg` (the file `LocalizationManager` already writes), section `display`, key `max_fps`.
##
## ⚠️ NO CHOICE UNDER 30. Measured 2026-10-08 (`PERFORMANCE_BUDGET_MASTER_PLAN` §0c): below 30 the cost per frame does not
## fall and the blast's effects, which age in drawn frames, stretch in wall time (6.9 s -> 9.3 s at 15 fps).
##
## `MAX_FPS=<n>` (DevFlags) still overrides this for a measurement (`Room._apply_perf_ablations()`).
class_name FrameRate
extends RefCounted

const CHOICES: Array[int] = [30, 60, 0]   ## 0 = uncapped (the display's refresh, through vsync)
const DEFAULT_CAP: int = 30
const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "display"
const SETTINGS_KEY: String = "max_fps"


## The saved choice, or the default when there is none or it is not one of `CHOICES`.
static func saved_cap() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return DEFAULT_CAP
	var value: int = int(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY, DEFAULT_CAP))
	if not CHOICES.has(value):
		push_warning("[FrameRate] %s: max_fps %d is not one of %s — using %d" % [SETTINGS_PATH, value, CHOICES, DEFAULT_CAP])
		return DEFAULT_CAP
	return value


## Applies the saved choice. Called once at boot.
static func apply_saved() -> void:
	Engine.max_fps = saved_cap()


## Applies and saves a choice (for the options UI). Keeps the file's other sections (the language).
static func set_cap(cap: int) -> void:
	if not CHOICES.has(cap):
		push_error("[FrameRate] set_cap: %d is not one of %s" % [cap, CHOICES])
		return
	Engine.max_fps = cap
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY, cap)
	var err: int = cfg.save(SETTINGS_PATH)
	if err != OK:
		push_error("[FrameRate] could not save %s (error %d)" % [SETTINGS_PATH, err])
