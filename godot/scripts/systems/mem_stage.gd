## MemStage — DIAG-09 §1b: where in the boot does the memory actually go?
##
## The device census (2026-09-12, Moto G04s) established that PLAYGROUND costs
## **2.22 GB with nothing detonated**, leaving 589 MB of headroom on a 3.83 GB
## handset — and that our own TileSet atlases account for at most 163.8 MB of the
## 734 MB of graphics memory. **~570 MB is unexplained**, and three candidates
## were written down as guesses, deliberately not acted on.
##
## This is how the guessing is avoided: a marker at each boot stage, printing the
## process's own memory and the DELTA since the previous marker. The stage whose
## delta is large is the answer; the other two candidates are eliminated in the
## same run, without anyone having to be right in advance.
##
## ⚠️ WHY IT READS `/proc/self/status` AND NOT A GODOT API.
## Both engine-side instruments tried first returned null and are recorded as
## null in the plan: `RenderingServer.get_rendering_info(...)` reads 0.0 MB on
## desktop Forward+ AND on the device while the atlas is provably 163.8 MB, and
## `OS.get_static_memory_usage()` is debug-only — 1 340 MB in the editor build,
## 0.0 MB in the release APK. `/proc/self/status` is readable by the app itself
## on Android with no permission, and is the same accounting `dumpsys meminfo`
## reports from outside.
##
## ⚠️ WHAT IT CANNOT SEE. `VmRSS` does not include graphics driver memory — the
## `GL mtrack` figure that grew 734 MB → 1.05 GB across three detonations. A
## stage that allocates only GPU-side will move these numbers hardly at all. That
## is why `device_run.py --mem-poll` samples `dumpsys meminfo` alongside: the two
## instruments see different halves, and a stage invisible to BOTH is genuinely
## not where the memory went.
##
## Called as `MemStage.mark("label")` — a `class_name`, not an autoload, so it is
## reachable from `room_builder.gd` and other non-Node classes and survives a
## `godot --script` context where autoloads do not exist.

class_name MemStage
extends RefCounted

## Set at boot by `DevFlags._ready()` from the `MEM_STAGES` flag. Static so the
## gate costs one bool test at every marker rather than a tree lookup.
static var enabled: bool = false

static var _last_rss_kb: int = 0
static var _first_rss_kb: int = 0
static var _stage_n: int = 0


## Prints one line: the stage, the process RSS and swap, and the change since the
## previous stage. Silent unless `MEM_STAGES=1`.
static func mark(label: String) -> void:
	if not enabled:
		return
	var stats: Dictionary = _read_proc_self_status()
	if stats.is_empty():
		## Loud once, then quiet: on a platform without /proc this instrument does
		## not exist, and a silent no-op would read as "this stage costs nothing".
		if _stage_n == 0:
			push_warning("[MEM-STAGE] /proc/self/status unavailable on %s — "
				% OS.get_name() + "stage markers will not report")
			_stage_n = 1
		return

	var rss_kb: int = int(stats.get("VmRSS", 0))
	var swap_kb: int = int(stats.get("VmSwap", 0))
	if _first_rss_kb == 0:
		_first_rss_kb = rss_kb
	var delta_kb: int = rss_kb - _last_rss_kb if _last_rss_kb > 0 else 0
	_last_rss_kb = rss_kb

	var mb: float = 1024.0
	print("[MEM-STAGE] %-34s RSS %7.1f MB  swap %7.1f MB   Δ %+8.1f MB   (since boot %+.1f MB)"
		% [label, float(rss_kb) / mb, float(swap_kb) / mb, float(delta_kb) / mb,
		float(rss_kb - _first_rss_kb) / mb])
	_stage_n += 1


## VmRSS / VmSwap / VmSize, in kB, parsed out of `/proc/self/status`. Empty when
## the file does not exist — macOS and Windows have no /proc.
static func _read_proc_self_status() -> Dictionary:
	var file: FileAccess = FileAccess.open("/proc/self/status", FileAccess.READ)
	if file == null:
		return {}
	var out: Dictionary = {}
	while not file.eof_reached():
		var line: String = file.get_line()
		for key in ["VmRSS", "VmSwap", "VmSize", "VmHWM"]:
			if not line.begins_with(key + ":"):
				continue
			## "VmRSS:\t  123456 kB" -> 123456
			var digits: String = ""
			for c in line:
				if c >= "0" and c <= "9":
					digits += c
			if digits.is_valid_int():
				out[key] = int(digits)
	return out
