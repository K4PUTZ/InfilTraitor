## FrameSplit — per-subsystem CPU attribution for the frame probe.
##
## PERF-DEV (2026-09-12). On the Moto g04s the idle frame was measured
## process-bound: `Performance.TIME_PROCESS` held ~42 ms while render gpu read
## 19 ms. That monitor is a MAXIMUM retained over roughly a second, not a mean
## (it read 246 ms inside a span whose frame mean was 92 ms), and it says nothing
## about WHERE the main thread goes. Each device cycle costs minutes, so ablating
## one subsystem per build is the slow way to find it; this names the share of
## each instrumented call site in a single run.
##
## Armed by `Room` from `FRAME_PROBE`. Call sites guard their own clock read with
## `FrameSplit.enabled`, so a disarmed build pays one static bool per site.
##
## ⚠️ The shares do not add up to the frame. Anything not wrapped is not counted,
## and `_draw()` callbacks run during the deferred flush, not inside the `_process`
## that queued them — read each label as a floor on that subsystem, never the
## remainder as "the engine".
class_name FrameSplit
extends RefCounted

static var enabled: bool = false
static var _usec: Dictionary = {}
static var _calls: Dictionary = {}


static func add(label: String, usec: int) -> void:
	_usec[label] = int(_usec.get(label, 0)) + usec
	_calls[label] = int(_calls.get(label, 0)) + 1


## One line for the window the probe just closed, then reset. Empty when disarmed
## or when nothing instrumented ran.
static func take_line(frames: int) -> String:
	if not enabled or _usec.is_empty() or frames <= 0:
		return ""
	var labels: Array = _usec.keys()
	labels.sort_custom(func(a, b): return int(_usec[a]) > int(_usec[b]))
	var parts: PackedStringArray = PackedStringArray()
	for label in labels:
		parts.append("%s %.2f ms (%d/f)" % [label,
			float(_usec[label]) / 1000.0 / float(frames),
			roundi(float(_calls[label]) / float(frames))])
	_usec.clear()
	_calls.clear()
	return "[FRAME-SPLIT] per frame: " + " · ".join(parts)
