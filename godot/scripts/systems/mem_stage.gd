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

## Why the last read failed, for the one-time warning. A null instrument has to
## say WHICH null it is, or the next person re-runs the same failing thing.
static var _read_failure: String = "not attempted"

## System-wide available bytes at the previous marker, for the Android path.
static var _last_available: int = 0

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
		## ⚠️ ANDROID CANNOT USE THE PER-PROCESS READER, measured 2026-09-12:
		## `FileAccess.open("/proc/self/status")` returns null with error 1. The
		## engine's path sandbox allows `/sdcard/...` — DevFlags reads its
		## overrides from there — but not `/proc`, and there is no stock Godot
		## API for per-process memory in a release build (`get_static_memory_usage`
		## is debug-only, `get_rendering_info` reads 0).
		##
		## `OS.get_memory_info()` DOES work there, and answers a different but
		## genuinely useful question: how much memory the SYSTEM has left. On a
		## handset with 589 MB of headroom that curve is most of the story, and
		## the per-process half is covered by `device_run.py --mem-poll` reading
		## `dumpsys meminfo` from the host. Neither is a substitute for the other;
		## printed together they bracket the truth.
		var sys_info: Dictionary = OS.get_memory_info()
		var available: int = int(sys_info.get("available", -1))
		if available > 0:
			var mb_sys: float = 1024.0 * 1024.0
			var delta_avail: float = 0.0
			if _last_available > 0:
				delta_avail = float(available - _last_available) / mb_sys
			_last_available = available
			print("[MEM-STAGE] %-34s system available %8.1f MB   Δ %+8.1f MB   %s"
				% [label, float(available) / mb_sys, delta_avail,
				"(per-process unreadable here — see [MEM-POLL])"])
			_stage_n += 1
			return
		## ⚠️ THE LABEL STILL PRINTS. Measured 2026-09-12: the first version
		## returned here, and on Android — where the read failed for a reason
		## that took another build to find — that silently removed the entire
		## TIMELINE as well as the numbers. The timeline is half the instrument:
		## `device_run.py --mem-poll` samples `dumpsys meminfo` from the host,
		## and correlating those samples to the boot stages needs the stage
		## timestamps to exist in the log. Losing the numbers is a degraded
		## measurement; losing the timeline is no measurement at all.
		print("[MEM-STAGE] %-34s (process memory unreadable — correlate with "
			% label + "[MEM-POLL] by timestamp)")
		if _stage_n == 0:
			push_warning("[MEM-STAGE] /proc/self/status unreadable on %s: %s"
				% [OS.get_name(), _read_failure])
		_stage_n += 1
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
		_read_failure = "FileAccess.open returned null, error %d" % FileAccess.get_open_error()
		return {}

	## ⚠️ procfs FILES REPORT A LENGTH OF ZERO. They are generated on read, so
	## `stat()` cannot know their size — and Godot's FileAccess derives
	## `eof_reached()` from that length, so a `while not eof_reached()` loop over
	## this file exits before reading a single byte. That is what produced
	## "unavailable on Android" on a file the process can plainly read.
	## `get_buffer()` reads from the stream itself and is not bound by the
	## stat size, so it gets the real content.
	var reported_length: int = file.get_length()
	var text: String = ""
	while true:
		var chunk: PackedByteArray = file.get_buffer(4096)
		if chunk.size() == 0:
			break
		text += chunk.get_string_from_utf8()
	file.close()
	if text.is_empty():
		## Read BEFORE the close — `get_length()` on a closed handle is not a
		## number, and a diagnostic that lies about why is worse than none.
		_read_failure = "opened, but read 0 bytes (stat length %d)" % reported_length
		return {}
	_read_failure = ""

	var out: Dictionary = {}
	for line in text.split("\n"):
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
