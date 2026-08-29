extends RefCounted
class_name VfxDrawProbe

## PERF-P7a — SPLITTING THE VFX OVERLAYS' 25 ms/frame INTO ITS TWO HALVES.
##
## `PERFORMANCE_MASTER_PLAN` §3.4 measured the five VFX overlays at 25.1 ms per
## frame during a real fire, by hiding them. That says WHERE the time is and
## nothing about WHY, and §8.3 turns the "why" into a testable claim: the cost is
## `CanvasItem.draw_*` — one canvas command per particle per frame — rather than
## the per-particle GDScript around it. If that holds, the fix is the delivery
## channel (a `MultiMesh` draws the same particles in ~1 call) and the LOOK never
## has to change; if it does not hold, the loop is the cost and MultiMesh buys
## much less than §8.3 assumes.
##
## Two environment flags, and the split is their difference:
##
##   INFILTRAITOR_VFX_DRAW_PROBE=1   time every `_draw()` from the inside
##   INFILTRAITOR_VFX_DRAW_NOOP=1    keep the whole loop, skip the `draw_*`
##
##   A = probe on, noop off  ->  loop + submission
##   B = probe on, noop on   ->  loop alone
##   A - B                   ->  what the canvas commands cost
##
## ⚠️ **What this does NOT measure, stated so the number is not over-read.**
## `draw_us` covers the body of `_draw()` only: building the polygon for a
## `draw_circle` and appending the command are inside it, GPU rasterization is
## not. So `A - B` is SUBMISSION, not the total price of the pixels. That is the
## right term for §8.3's question — MultiMesh removes submission and keeps the
## pixels — but it is not the whole frame, and the FRAME-PROBE line printed
## beside it is what keeps that honest.
##
## ⚠️ **The per-particle branch is present in BOTH modes.** Each `_draw()` hoists
## `not VfxDrawProbe.noop` into a local and tests that local per particle, so the
## cost of the test itself cancels in the subtraction. Removing the branch in
## mode A would make A - B include the branch and overstate submission.
##
## ⚠️ **ONE CONSUMER AT A TIME.** `take_line()` RESETS the counters, so the two
## call site in `Room` is the FRAME-PROBE, which reports a rolling 60-frame
## window. `Room.begin_blast_lock()` calls `reset()` so a detonation's window
## starts at the fuse and nothing from the boot leaks into it. (The fire-scoped
## BURN-PROF that used to share these counters went with `BurnScheduler` in D-6.)
##
## The `--disable-vsync` warning that governs every reading here lives on
## `Room._frame_probe`.

## Live for the whole process. Read once: these are consulted per particle.
static var enabled: bool = OS.get_environment("INFILTRAITOR_VFX_DRAW_PROBE") == "1"
static var noop: bool = OS.get_environment("INFILTRAITOR_VFX_DRAW_NOOP") == "1"

## Accumulated inside `_draw()`, across every instrumented overlay.
static var draw_us: int = 0
## Particles walked, and canvas commands the walk would have issued. `commands`
## is counted in BOTH modes — in noop mode it is what was skipped — so the
## per-command figure divides by the same denominator on both sides.
static var particles: int = 0
static var commands: int = 0

## §8.4 — `EmberOverlay.add_ember()` walks every live ember to compute its height
## bias, so spawning N is O(N^2). Timed separately because it is a one-off at the
## spawn frame, not a per-frame cost, and §3.4's hiding experiments could not
## have seen it.
static var spawn_us: int = 0
static var spawn_n: int = 0

## §12.10 — THE SPLIT BY OVERLAY, because P7b converts ONE of the four.
##
## The counters above are global, so they price "the VFX" and cannot say what
## share of it `EmberOverlay` is — and P7b's whole scope is the ember. Sizing a
## Medium rewrite off a number that belongs to four overlays is the mistake §1.2
## made with the soot. Keyed by overlay name -> {"us": int, "cmds": int}.
static var per_overlay: Dictionary = {}


## §12.12 — the overlays' `_process`, which NOTHING has ever measured.
##
## Every number this class has produced is about `_draw()`. But each overlay also
## walks its whole particle array once per frame to age it and rebuild a survivor
## list, and with ~1 900 live particles that is a GDScript loop nobody has priced.
## After P7b the `_draw` side is 3.5 ms of a ~19.5 ms fire frame and the voxel
## layers measured at ~0, so the remainder has to be somewhere — this is the first
## place to look rather than the last.
static var proc_us: Dictionary = {}


static func note_process(who: StringName, us: int) -> void:
	if not enabled:
		return
	proc_us[who] = int(proc_us.get(who, 0)) + us


## One overlay's contribution, folded in at the end of its own `_draw()`.
static func note(who: StringName, us: int, cmds: int) -> void:
	if not enabled:
		return
	var e: Dictionary = per_overlay.get(who, {"us": 0, "cmds": 0})
	e["us"] = int(e["us"]) + us
	e["cmds"] = int(e["cmds"]) + cmds
	per_overlay[who] = e


## One line for the FRAME-PROBE, then reset. Returns "" when the probe is off so
## the caller can concatenate unconditionally.
static func take_line(frames: int) -> String:
	if not enabled or frames <= 0:
		return ""
	var per_frame_ms: float = float(draw_us) / 1000.0 / float(frames)
	var line: String = "[VFX-DRAW-PROBE] %s · %.2f ms/frame in _draw() · %.1f particle(s)/frame · %.1f command(s)/frame" % [
		"NOOP (loop alone)" if noop else "FULL (loop + submission)",
		per_frame_ms,
		float(particles) / float(frames),
		float(commands) / float(frames)]
	if spawn_n > 0:
		line += "\n[VFX-DRAW-PROBE] add_ember: %d call(s), %.2f ms total (%.1f us/call) — §8.4's O(N^2)" % [
			spawn_n, float(spawn_us) / 1000.0, float(spawn_us) / float(spawn_n)]
	## §12.10 — sorted by cost, so the line reads as a ranking rather than a dump.
	var names: Array = per_overlay.keys()
	names.sort_custom(func(a, b): return int(per_overlay[a]["us"]) > int(per_overlay[b]["us"]))
	for who in names:
		var e: Dictionary = per_overlay[who]
		line += "\n[VFX-DRAW-PROBE]   %-18s %6.2f ms/frame · %7.1f cmd/frame · %5.1f%% of _draw" % [
			who, float(e["us"]) / 1000.0 / float(frames),
			float(e["cmds"]) / float(frames),
			100.0 * float(e["us"]) / maxf(float(draw_us), 1.0)]
	var pnames: Array = proc_us.keys()
	pnames.sort_custom(func(a, b): return int(proc_us[a]) > int(proc_us[b]))
	for who in pnames:
		line += "\n[VFX-DRAW-PROBE]   _process %-14s %6.2f ms/frame" % [
			who, float(proc_us[who]) / 1000.0 / float(frames)]
	proc_us.clear()
	per_overlay.clear()
	draw_us = 0
	particles = 0
	commands = 0
	spawn_us = 0
	spawn_n = 0
	return line


## Drop everything accumulated so far. Called from `Room.begin_blast_lock()` so
## the window starts at the detonation and not at the boot.
static func reset() -> void:
	draw_us = 0
	particles = 0
	commands = 0
	spawn_us = 0
	spawn_n = 0
	per_overlay.clear()
	proc_us.clear()
