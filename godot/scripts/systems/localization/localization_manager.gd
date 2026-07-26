extends Node
class_name LocalizationManager
## LocalizationManager — autoload singleton, registered as "Localization".
##
## Single entry point for the game's multi-language text. Wraps Godot's
## TranslationServer so that `tr("domain.key")` works engine-wide (O(1) hash
## lookup, mobile-friendly) while keeping the human-editable source in
## per-domain CSV files that translators can edit in any spreadsheet.
##
## Source of truth: godot/localization/translations/*.csv
##   - row 0 is the header:  keys,<locale>,<locale>,...   (e.g. keys,en,pt_BR)
##   - column 0 is the semantic key (e.g. ui.hud.ap_counter)
##   - one column per supported locale; an empty cell falls back to default_locale
## On boot we parse the CSVs, build one Translation resource per locale and
## register them with the TranslationServer. The chosen locale is persisted to
## user://settings.cfg so it survives restarts.
##
## See tools/persistent/OPERATOR_CONTEXT.md → "Localization (i18n)" for the
## conventions and the step-by-step on adding strings / languages.

signal language_changed(locale: String)

const SOURCE_DIR := "res://godot/localization/translations/"
## Domains loaded at boot. Add a new file name here when a new domain is created.
const SOURCE_FILES: Array[String] = ["system.csv", "ui.csv"]

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "localization"
const SETTINGS_KEY := "locale"

## Source language: every key MUST exist in this column. Used as the fallback
## when another locale is missing a key. Kept as `var` (config, runtime-tunable).
var default_locale: String = "en"
var supported_locales: PackedStringArray = ["en", "pt_BR"]

var _current_locale: String = "en"
## locale -> { key: text } — retained for direct lookups (e.g. endonyms).
var _messages: Dictionary = {}


func _ready() -> void:
	_load_sources()
	## Seed the server with the source language, then apply the resolved choice.
	TranslationServer.set_locale(default_locale)
	_apply_locale(_resolve_initial_locale(), false)


## Active locale code (e.g. "pt_BR").
## Switches the active language, persists the choice and notifies listeners.
## Unsupported locales are ignored with a warning (no state change).
func set_language(locale: String) -> void:
	if not supported_locales.has(locale):
		push_warning("Localization: unsupported locale '%s', ignoring." % locale)
		return
	if locale == _current_locale:
		return
	_apply_locale(locale, true)


## Rotates to the next supported language. Handy for quick testing (room: key K).
func cycle_language() -> void:
	var idx := supported_locales.find(_current_locale)
	var next: String = supported_locales[(idx + 1) % supported_locales.size()]
	set_language(next)


# ── internals ────────────────────────────────────────────────────────────────

func _apply_locale(locale: String, persist: bool) -> void:
	_current_locale = locale
	TranslationServer.set_locale(locale)
	if persist:
		_save_locale(locale)
	language_changed.emit(locale)


func _resolve_initial_locale() -> String:
	var saved := _load_saved_locale()
	if saved != "" and supported_locales.has(saved):
		return saved
	## First run: honor the OS language when we support it.
	var os_lang := OS.get_locale_language()  ## 2-letter code, e.g. "pt", "en"
	for loc in supported_locales:
		if loc.substr(0, 2) == os_lang:
			return loc
	return default_locale


func _load_sources() -> void:
	for loc in supported_locales:
		_messages[loc] = {}
	for file_name in SOURCE_FILES:
		_load_csv(SOURCE_DIR + file_name)
	_register_translations()


func _load_csv(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("Localization: missing source file %s" % path)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Localization: cannot open %s" % path)
		return
	var header := f.get_csv_line()
	## Map column index -> locale (column 0 is the key column, skipped).
	var col_locale: Dictionary = {}
	for i in range(1, header.size()):
		col_locale[i] = header[i].strip_edges()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.is_empty():
			continue
		var key := row[0].strip_edges()
		if key == "" or key.begins_with("#"):
			continue  ## blank line or comment row
		for i in col_locale.keys():
			if i < row.size() and row[i] != "":
				var loc: String = col_locale[i]
				if _messages.has(loc):
					_messages[loc][key] = row[i]
	f.close()


func _register_translations() -> void:
	for loc in _messages.keys():
		var t := Translation.new()
		t.locale = loc
		for key in _messages[loc].keys():
			t.add_message(key, _messages[loc][key])
		TranslationServer.add_translation(t)


func _load_saved_locale() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return ""
	return cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY, "")


func _save_locale(locale: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  ## ignore error: file may not exist yet
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY, locale)
	cfg.save(SETTINGS_PATH)
