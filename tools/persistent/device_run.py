#!/usr/bin/env python3
##
## device_run.py — DIAG-02: launch the APK on a handset and bring the log back.
##
## The measurement half of `export_android.py`. It checks the preconditions a
## device run silently fails without, launches the game, streams the log while
## filtering the handset's own noise out, and reports.
##
## THE THREE PRECONDITIONS, each one learned by watching it fail (2026-09-12,
## Moto G04s / Unisoc T606 / Android 14):
##
##  1. THE SCREEN MUST BE ON AND THE DEVICE UNLOCKED. This is not cosmetic. With
##     the screen off, the activity took `OnResume` and then `OnPause` 33 ms
##     later, and Godot then failed to create its Vulkan surface:
##
##         E vulkan : native_window_api_connect() failed: No such device (-19)
##         ERROR: Failed to create vulkan window.
##         ERROR: Unable to create DisplayServer, all display drivers failed.
##
##     ⚠️ **That log reads exactly like a broken Vulkan driver on a cheap SoC,
##     and it is not.** It is a missing surface, because there was no visible
##     window to attach to. A device harness that does not check this will
##     eventually report a renderer verdict that is really a screensaver. The
##     check is here so that mistake cannot be made twice.
##
##  2. `am start -n <pkg>/com.godot.game.GodotApp` IS DENIED. Godot's main
##     activity is `exported=false`; the launchable entry is the alias
##     `com.godot.game.GodotAppLauncher` (`exported=true`, MAIN/LAUNCHER).
##     Starting the activity directly returns `SecurityException: Permission
##     Denial: ... not exported`.
##
##  3. LOGCAT ON A REAL HANDSET IS FLOODED. This device emits `audio_hw_record_nr`
##     and `BLASTBufferQueue` lines roughly every 10 ms, all day, with the game
##     idle. An unfiltered capture is mostly that, and the probe lines this
##     harness exists to collect are what gets dropped. Filter by tag, and raise
##     the buffer.
##
## Usage:
##     python3 tools/persistent/device_run.py --seconds 90
##     python3 tools/persistent/device_run.py --check         # preconditions only
##     python3 tools/persistent/device_run.py --seconds 120 --save run1.log
##
## Exit code is non-zero when a precondition fails or the engine reported a
## fatal error, so this is safe to chain in front of a parser.

import argparse
import os
import re
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

ADB_CANDIDATES = [
    "/opt/homebrew/share/android-commandlinetools/platform-tools/adb",
    "/usr/local/bin/adb",
    "adb",
]

PACKAGE = "com.example.infiltraitor"
## Precondition 2 — the alias, never the activity.
LAUNCH_COMPONENT = "%s/com.godot.game.GodotAppLauncher" % PACKAGE

## Precondition 3 — Godot logs under `godot` (engine, lowercase) and `Godot`
## (the Java side, capitalised). Everything else on this handset is noise.
LOG_TAGS = ["godot:V", "Godot:V", "vulkan:E", "AndroidRuntime:E"]

## The properties that identify the hardware a number came from. A result with
## no hardware block is an orphan number.
SPEC_PROPS = [
    "ro.product.manufacturer", "ro.product.model", "ro.product.device",
    "ro.soc.manufacturer", "ro.soc.model", "ro.product.cpu.abi",
    "ro.build.version.release", "ro.build.version.sdk",
]

FATAL_PATTERNS = [
    re.compile(r"Unable to create DisplayServer"),
    re.compile(r"FATAL EXCEPTION"),
    re.compile(r"Failed to create vulkan window"),
]


def _find_adb():
    for c in ADB_CANDIDATES:
        if os.path.sep in c:
            if os.path.exists(c):
                return c
        else:
            import shutil
            found = shutil.which(c)
            if found:
                return found
    return None


def _sh(adb, args, timeout=30):
    proc = subprocess.run([adb] + args, capture_output=True, text=True, timeout=timeout)
    return (proc.stdout or "").replace("\r", "")


def _device(adb) -> str | None:
    out = _sh(adb, ["devices"])
    rows = [l for l in out.splitlines()[1:] if l.strip().endswith("device")]
    if not rows:
        return None
    return rows[0].split()[0]


def _specs(adb) -> dict:
    out = {}
    for p in SPEC_PROPS:
        out[p] = _sh(adb, ["shell", "getprop", p]).strip()
    mem = _sh(adb, ["shell", "grep", "MemTotal", "/proc/meminfo"]).strip()
    out["MemTotal"] = mem.split()[1] + " kB" if mem else "?"
    out["screen"] = _sh(adb, ["shell", "wm", "size"]).strip().replace("Physical size: ", "")
    out["density"] = _sh(adb, ["shell", "wm", "density"]).strip().replace("Physical density: ", "")
    return out


def _check_awake(adb) -> bool:
    """Precondition 1. The check that stops a screensaver being read as a driver bug."""
    power = _sh(adb, ["shell", "dumpsys", "power"])
    awake = "mWakefulness=Awake" in power
    trust = _sh(adb, ["shell", "dumpsys", "trust"])
    locked = "deviceLocked=1" in trust

    if awake and not locked:
        print("[DIAG-02] ok   — screen on, device unlocked")
        return True

    if not awake:
        print("[DIAG-02] FAIL — the screen is not awake (%s)."
              % next((l.strip() for l in power.splitlines()
                      if "mWakefulness=" in l), "unknown"))
    if locked:
        print("[DIAG-02] FAIL — the device is LOCKED (deviceLocked=1). It has a "
              "secure lock; unlock it by hand — this harness will not type a "
              "PIN.")
    print("[DIAG-02] ⚠️  Running anyway produces a Vulkan surface failure that "
          "reads like a broken driver. It is not one. See this file's header.")
    return False


def _launch(adb) -> bool:
    out = _sh(adb, ["shell", "am", "start", "-n", LAUNCH_COMPONENT])
    if "Error" in out or "Exception" in out:
        print("[DIAG-02] FAIL — launch refused:")
        print(out.strip())
        return False
    print("[DIAG-02] launched %s" % LAUNCH_COMPONENT)
    return True


def _capture(adb, seconds: int) -> list[str]:
    """Stream the filtered log for `seconds`, then stop.

    Note the shape: `logcat` is left running and killed on a deadline rather than
    dumped afterwards with `-d`, so a run longer than the ring buffer cannot lose
    its early lines.
    """
    cmd = [adb, "logcat", "-v", "time"] + LOG_TAGS + ["*:S"]
    lines: list[str] = []
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, bufsize=1)
    deadline = time.time() + seconds
    try:
        while time.time() < deadline:
            line = proc.stdout.readline()
            if not line:
                break
            line = line.rstrip("\n")
            lines.append(line)
            print("[dev] %s" % line)
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
    return lines


def main() -> int:
    ap = argparse.ArgumentParser(description="Launch the APK on a handset and capture its log.")
    ap.add_argument("--seconds", type=int, default=90, help="how long to capture (default 90)")
    ap.add_argument("--check", action="store_true", help="preconditions only, do not launch")
    ap.add_argument("--save", default=None, help="also write the captured log to this file")
    ap.add_argument("--no-stayon", action="store_true",
                    help="do not ask the device to stay awake while on USB")
    args = ap.parse_args()

    adb = _find_adb()
    if not adb:
        print("[DIAG-02] FAIL — adb not found.")
        return 1

    serial = _device(adb)
    if not serial:
        print("[DIAG-02] FAIL — no device. Check, in this order: the cable "
              "carries data, the USB mode is File Transfer, Developer Options "
              "-> USB debugging is on, and the 'Allow USB debugging?' dialog "
              "has been accepted on the phone.")
        return 1

    specs = _specs(adb)
    print("[DIAG-02] device %s — %s %s (%s %s), Android %s / SDK %s, %s, %s @ %s dpi"
          % (serial, specs["ro.product.manufacturer"], specs["ro.product.model"],
             specs["ro.soc.manufacturer"], specs["ro.soc.model"],
             specs["ro.build.version.release"], specs["ro.build.version.sdk"],
             specs["MemTotal"], specs["screen"], specs["density"]))

    if not args.no_stayon:
        ## Does not unlock anything; it stops the device dozing back off mid-run.
        _sh(adb, ["shell", "svc", "power", "stayon", "usb"])

    if not _check_awake(adb):
        return 1
    if args.check:
        print("[DIAG-02] preconditions OK.")
        return 0

    _sh(adb, ["logcat", "-G", "16M"])
    _sh(adb, ["logcat", "-c"])
    if not _launch(adb):
        return 1

    lines = _capture(adb, args.seconds)

    if args.save:
        out = Path(args.save)
        if not out.is_absolute():
            out = REPO / out
        out.write_text("\n".join(lines) + "\n")
        print("[DIAG-02] log -> %s" % out)

    joined = "\n".join(lines)
    fatal = [p.pattern for p in FATAL_PATTERNS if p.search(joined)]
    if fatal:
        print("[DIAG-02] FAIL — the engine reported: %s" % ", ".join(fatal))
        return 1
    if not lines:
        print("[DIAG-02] FAIL — captured nothing. A harness that writes nothing "
              "is a claim about the harness, not about the game.")
        return 1

    print("[DIAG-02] captured %d line(s), no fatal error." % len(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
