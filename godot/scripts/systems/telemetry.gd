## Telemetry — the one timeline every diagnostic run writes into.
##
## TEL-01 (DEVICE_DIAGNOSTICS_MASTER_PLAN §14). Autoload singleton, registered as
## `Telemetry` after `DevFlags` (which arms it) and `VersionInfo` (which it
## reports).
##
## WHY THIS EXISTS
##
## The device track lost sessions to numbers read without their context. DIAG-15
## tied a ×6.6 jump in draw calls to a grenade throw because the log held the
## counters and nothing else; DIAG-16 found the jump came with a change of framing
## and zoom that no line recorded (plan §10.16). A counter is only comparable with
## the view, the command and the phase it was read under, so each of those becomes
## an EVENT on one clock here, and "what happened when the counter moved" becomes a
## join instead of a guess.
##
## THE RECORD — every event carries, in this order:
##
##   seq   per-session sequence number. logcat drops lines under load (plan §5), so
##         a gap in `seq` is a dropped line — counted, never silently absent.
##   f     `Engine.get_process_frames()`
##   t_us  `Time.get_ticks_usec()` — the clock `FrameSplit` and the frame probe
##         read, so their windows join against events exactly.
##   kind  `<channel>.<name>` — `input.tap`, `view.framing`, `frame.window` ...
##   ...   the event's own fields.
##
## TWO SINKS, because neither is enough alone:
##
##  - logcat: `[TEL] <seq> <f> <t_us> <kind> k=v ...` — lands in the capture
##    `device_run.py` already takes, but is lossy under load.
##  - a JSONL file, one record per line — lossless. On Android it goes to the app's
##    EXTERNAL files dir (where `DevFlags` already reads its overrides from, and
##    `adb pull` reaches without a debuggable build); elsewhere to `user://`. If it
##    cannot be opened the run says so and continues on logcat alone.
##
## FLAGS (through `DevFlags`, so every one of them reaches a release APK):
##   TELEMETRY=1        arm it. Disarmed, every call costs one bool test.
##   TEL_CHANNELS=a,b   only these channels (default: all). `session` always.
##   TEL_FILE=0         no file sink.
##   TEL_LOGCAT=0       no logcat lines (the file only).
##
## ⚠️ PRICED, NOT FREE. `stats()` reports the events written, their bytes and the
## microseconds spent writing them. §14.2 #4 requires that cost to be measured on
## the Moto before a telemetry-on number is quoted beside a telemetry-off one.
extends Node

const FILE_DIR_NAME: String = "telemetry"
## How stale the file sink may get before it is flushed. `device_run.py` ends a run
## with a force-stop, so anything still buffered then is lost; half a second bounds
## that loss without flushing on every event.
const FLUSH_INTERVAL_USEC: int = 500_000

var enabled: bool = false

var _channels: Dictionary = {}  ## channel -> true; empty = every channel
var _logcat: bool = true
var _seq: int = 0
var _file: FileAccess = null
var _file_path: String = ""
var _dirty: bool = false
var _last_flush_usec: int = 0
var _write_usec: int = 0
var _bytes: int = 0
var _counters: Dictionary = {}  ## name -> int, taken and reset per probe window


func _ready() -> void:
	if not DevFlags.on("TELEMETRY"):
		set_process(false)
		return
	var sink: String = ""
	if DevFlags.value("TEL_FILE", "1") == "1":
		sink = _default_file_path()
	start(DevFlags.value("TEL_CHANNELS", "").split(",", false),
		sink, DevFlags.value("TEL_LOGCAT", "1") == "1")


## Arm the timeline. `_ready()` calls this from the flags; `telemetry_selftest`
## calls it directly, which is why it is not folded into `_ready()`.
## An empty `sink_path` means no file sink.
func start(channels: PackedStringArray, sink_path: String, to_logcat: bool) -> void:
	stop()
	enabled = true
	_logcat = to_logcat
	_channels.clear()
	for channel in channels:
		var channel_name: String = channel.strip_edges()
		if not channel_name.is_empty():
			_channels[channel_name] = true
	_seq = 0
	_write_usec = 0
	_bytes = 0
	_counters.clear()
	if not sink_path.is_empty():
		_open_file(sink_path)
	set_process(true)
	event("session", session_fields())


## Close the file sink and disarm. Safe to call when already stopped.
func stop() -> void:
	if _file != null:
		_file.flush()
		_file.close()
		_file = null
	_dirty = false
	enabled = false
	set_process(false)


## True when an event of this kind would be written.
func wants(kind: String) -> bool:
	if not enabled:
		return false
	if _channels.is_empty() or kind == "session":
		return true
	return _channels.has(kind.get_slice(".", 0))


## Write one event to every armed sink.
func event(kind: String, fields: Dictionary = {}) -> void:
	if not wants(kind):
		return
	var t0: int = Time.get_ticks_usec()
	_seq += 1
	var frame: int = Engine.get_process_frames()
	if _logcat:
		print(format_line(_seq, frame, t0, kind, fields))
	if _file != null:
		var record: Dictionary = {"seq": _seq, "f": frame, "t_us": t0, "kind": kind}
		for key in fields:
			record[str(key)] = _jsonable(fields[key])
		var line: String = JSON.stringify(record)
		_file.store_line(line)
		_bytes += line.length() + 1
		_dirty = true
	_write_usec += Time.get_ticks_usec() - t0


## Add to a named counter. Counters are taken — and reset — by whoever closes a
## measurement window (the frame probe), so a count always belongs to one window.
func count(counter: String, amount: int = 1) -> void:
	if not enabled:
		return
	_counters[counter] = int(_counters.get(counter, 0)) + amount


func take_counters() -> Dictionary:
	var taken: Dictionary = _counters.duplicate()
	_counters.clear()
	return taken


## What the timeline has cost so far this session.
func stats() -> Dictionary:
	return {"events": _seq, "bytes": _bytes, "write_ms": float(_write_usec) / 1000.0}


## Where the file sink is writing, or "" when it is not.
func file_path() -> String:
	return _file_path if _file != null else ""


## The logcat line, as a pure function so the selftest can pin its exact shape —
## `bench_analyze.py` (TEL-07) parses it.
static func format_line(seq: int, frame: int, t_us: int, kind: String,
		fields: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("[TEL] %d %d %d %s" % [seq, frame, t_us, kind])
	for key in fields:
		parts.append("%s=%s" % [str(key), _text(fields[key])])
	return " ".join(parts)


## The session header: everything a number from this run must be read beside.
## A value the platform cannot report is the string "unavailable", never a zero
## (see the null-instrument lesson in plan §10.7).
func session_fields() -> Dictionary:
	var refresh: float = DisplayServer.screen_get_refresh_rate()
	var fields: Dictionary = {
		"version": VersionInfo.version_string,
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"model": OS.get_model_name(),
		"cpu": OS.get_processor_name(),
		"cores": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"gpu_api": RenderingServer.get_video_adapter_api_version(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"screen": DisplayServer.screen_get_size(),
		"refresh_hz": refresh if refresh > 0.0 else "unavailable",
		"dpi": DisplayServer.screen_get_dpi(),
		"window": DisplayServer.window_get_size(),
		"flags_file": DevFlags.source_path() if not DevFlags.source_path().is_empty() else "none",
		"file_sink": _file_path if _file != null else "none",
	}
	var overrides: Dictionary = DevFlags.overrides()
	var pairs: PackedStringArray = PackedStringArray()
	for key in overrides:
		pairs.append("%s:%s" % [str(key), str(overrides[key])])
	pairs.sort()
	fields["overrides"] = "|".join(pairs) if not pairs.is_empty() else "none"
	return fields


func _process(_delta: float) -> void:
	if not _dirty or _file == null:
		return
	var now: int = Time.get_ticks_usec()
	if now - _last_flush_usec < FLUSH_INTERVAL_USEC:
		return
	_file.flush()
	_dirty = false
	_last_flush_usec = now


## Android can kill a backgrounded app without another frame, so the buffered tail
## is flushed on every signal that the process may be going away.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, \
				NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE:
			if _file != null:
				_file.flush()
				_dirty = false


func _default_file_path() -> String:
	var dir: String = DevFlags.external_files_dir()
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://")
	var stamp: String = Time.get_datetime_string_from_system(false, true) \
		.replace(":", "-").replace(" ", "_")
	return "%s/%s/tel_%s.jsonl" % [dir.trim_suffix("/"), FILE_DIR_NAME, stamp]


func _open_file(path: String) -> void:
	var dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var err: int = DirAccess.make_dir_recursive_absolute(dir)
		if err != OK:
			push_warning("[Telemetry] file sink unavailable — cannot create %s (error %d); "
				% [dir, err] + "logcat only")
			return
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_warning("[Telemetry] file sink unavailable — cannot open %s (error %d); "
			% [path, FileAccess.get_open_error()] + "logcat only")
		_file_path = ""
		return
	_file_path = path
	_last_flush_usec = Time.get_ticks_usec()
	## `[Telemetry]`, not `[TEL]`: every `[TEL]` line is a record the analyzer parses.
	print("[Telemetry] file sink: %s" % path)


## A field value as logcat text: compact, no spaces, so a line splits on spaces.
static func _text(value: Variant) -> String:
	match typeof(value):
		TYPE_FLOAT:
			return "%.3f" % float(value)
		TYPE_BOOL:
			return "1" if bool(value) else "0"
		TYPE_VECTOR2:
			var v: Vector2 = value
			return "%.1f,%.1f" % [v.x, v.y]
		TYPE_VECTOR2I:
			var vi: Vector2i = value
			return "%d,%d" % [vi.x, vi.y]
		TYPE_RECT2:
			var r: Rect2 = value
			return "%.1f,%.1f,%.1f,%.1f" % [r.position.x, r.position.y, r.size.x, r.size.y]
		TYPE_RECT2I:
			var ri: Rect2i = value
			return "%d,%d,%d,%d" % [ri.position.x, ri.position.y, ri.size.x, ri.size.y]
	return str(value).replace(" ", "_")


## A field value JSON can carry. Vectors and rects become arrays, not the strings
## `JSON.stringify` would otherwise make of them.
static func _jsonable(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2:
			var v: Vector2 = value
			return [v.x, v.y]
		TYPE_VECTOR2I:
			var vi: Vector2i = value
			return [vi.x, vi.y]
		TYPE_RECT2:
			var r: Rect2 = value
			return [r.position.x, r.position.y, r.size.x, r.size.y]
		TYPE_RECT2I:
			var ri: Rect2i = value
			return [ri.position.x, ri.position.y, ri.size.x, ri.size.y]
		TYPE_STRING_NAME:
			return str(value)
	return value
