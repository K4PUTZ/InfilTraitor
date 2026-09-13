#!/usr/bin/env python3
##
## export_android.py — DIAG-06: the Android build, with the traps nailed shut.
##
## Director, 2026-09-12: "Eu refiz manualmente o export pra web, mas não o apk,
## esse vai ficar por sua conta. Vale um script python pra deixar fácil essa
## atualização?"
##
## WHY THIS IS NOT JUST A `godot --export-release` ALIAS
##
## On 2026-09-11 three export traps were found at once, and the build still
## booted and still looked like a game through all three. The preset was fixed,
## but a preset is a setting — nothing re-checks it, and the APK sitting in
## `export/` at the time this script was written (515 MB, 2026-09-11) is proof
## that a stale artifact outlives its own fix and gets measured by mistake.
##
## So this script ASSERTS what it produced rather than trusting what it asked
## for. `unzip -l` on that stale APK still lists
## `digital_00017_diffuse_2048.jpg-….ctex` at 10 MB with many siblings — 65
## source textures that `exclude_filter="ASSETS/TEXTURES/source/*"` is supposed
## to remove. That is the check in `_verify_contents()`, and it is the reason
## this file exists.
##
## The same reasoning covers the other two traps: `maps/*.json` must be present
## (without them the game silently falls back to the code maps — no GLASS, no
## RENDER_ORDER) and the localization `*.csv` must be present as raw files
## (without them the HUD renders raw keys like `ui.hud.ap_counter`).
##
## ⚠️ THE APK IS THE ONLY BUILD THAT ANSWERS A PERFORMANCE QUESTION. The web
## export runs the Compatibility (WebGL2) renderer with `thread_support=false`;
## the APK runs what `project.godot` asks for. See
## `PROMPTS/PLANNING/DEVICE_DIAGNOSTICS_MASTER_PLAN.md` §7 — establishing which
## renderer these handsets should actually use is an OPEN question there, and
## `--renderer` exists so that control run can be made without hand-editing
## `project.godot`.
##
## Usage:
##     python3 tools/persistent/export_android.py
##     python3 tools/persistent/export_android.py --install
##     python3 tools/persistent/export_android.py --contents
##     python3 tools/persistent/export_android.py --renderer gl_compatibility
##
## Exit code is non-zero when a content assertion fails, so this is safe to
## chain in front of a measurement run.

import argparse
import os
import re
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

GODOT_CANDIDATES = [
    "/Applications/Godot.app/Contents/MacOS/Godot",
    "/usr/bin/godot",
    "/usr/local/bin/godot",
]

ADB_CANDIDATES = [
    "/opt/homebrew/share/android-commandlinetools/platform-tools/adb",
    "/usr/local/bin/adb",
    "adb",
]

PRESET_NAME = "Android"

## SIGNING — why this is an env var and not a preset field.
##
## `--export-release` signs with the RELEASE keystore, and this project has no
## release keystore: only the debug one Godot generated for itself. Measured
## 2026-09-12, in this order:
##
##  1. With no release keystore at all, Godot prints `Could not find release
##     keystore, unable to export.`, exits 1 — AND STILL LEAVES A COMPLETE,
##     CORRECT-LOOKING, COMPLETELY UNSIGNED APK ON DISK. See `_run_export()`.
##  2. Writing `keystore/release=...` into `export_presets.cfg` did NOT work:
##     the fields persisted in the file and Godot reported the same "could not
##     find" failure. Not pursued further, because —
##  3. `GODOT_ANDROID_KEYSTORE_RELEASE_*` works, exit 0, `apksigner verify`
##     clean.
##
## Route 3 is also the one that belongs in a tracked repo: `export_presets.cfg`
## is committed, so route 2 would have put a keystore path and password into
## git history for no benefit.
##
## ⚠️ THIS SIGNS A RELEASE BUILD WITH THE **DEBUG** KEYSTORE. That is correct
## for installing on our own handsets and measuring them, and it is NOT
## publishable — a store build needs a real release keystore, which is a
## Director decision and does not belong to this script.
KEYSTORE_CANDIDATES = [
    Path.home() / "Library/Application Support/Godot/keystores/debug.keystore",
    Path.home() / ".android/debug.keystore",
]
KEYSTORE_USER = "androiddebugkey"
KEYSTORE_PASSWORD = "android"
DEFAULT_APK = REPO / "export" / "Infiltraitor.apk"
PACKAGE_NAME = "com.example.infiltraitor"

# A gradle-less export packs ~14 000 files. Generous, but not unbounded.
EXPORT_TIMEOUT_SECONDS = 900

# The three trap assertions. Each is (label, predicate-description, matcher).
# `forbidden` entries must match NOTHING in the archive; `required` must match
# at least one entry.
FORBIDDEN_PATTERNS = [
    ("source textures", re.compile(r"_diffuse_2048\.jpg")),
]
REQUIRED_PATTERNS = [
    ("map JSON", re.compile(r"(^|/)maps/[^/]+\.map\.json$")),
    ("localization CSV", re.compile(r"localization/translations/.*\.csv$")),
]

# Anything at or above this is almost certainly the source-texture trap back
# again, even if the filename pattern changed. A tripwire, not a spec.
SUSPICIOUS_SIZE_MB = 250


def _find(candidates, what):
    for c in candidates:
        if os.path.sep in c:
            if os.path.exists(c):
                return c
        else:
            found = shutil.which(c)
            if found:
                return found
    print("[DIAG-06] %s not found. Looked in:" % what)
    for c in candidates:
        print("[DIAG-06]   %s" % c)
    return None


PROJECT_FILE = REPO / "project.godot"
RENDERER_LINE = re.compile(r'^renderer/rendering_method="[^"]*"$', re.M)
RENDERER_OVERRIDE_KEY = "rendering_method.mobile"


## ⚠️ `--rendering-method` ON THE EXPORT COMMAND LINE IS NOT PACKED. The first
## version of this script passed it and claimed the export "honours it". Measured
## 2026-09-12: the APK built that way carried `rendering_method` = `mobile` in its
## `assets/project.binary`, identical to the default build — the flag changes the
## renderer of the EDITOR process doing the export, not the exported settings.
## Every DIAG-04 control run made with it would have measured Vulkan twice.
##
## What is packed is `project.godot`, so the override goes there, as the `.mobile`
## feature override (the key an Android runtime resolves), for the duration of the
## export only. Returns the original bytes to restore, or None when the file does
## not have the shape this expects — refusing is better than patching blind.
def _patch_renderer(renderer: str) -> bytes | None:
    original = PROJECT_FILE.read_bytes()
    text = original.decode("utf-8")
    if RENDERER_OVERRIDE_KEY in text:
        print("[DIAG-06] FAIL — project.godot already has a %s override; not "
              "stacking a second one." % RENDERER_OVERRIDE_KEY)
        return None
    m = RENDERER_LINE.search(text)
    if m is None:
        print("[DIAG-06] FAIL — no renderer/rendering_method line in project.godot.")
        return None
    patched = (text[:m.end()] + '\nrenderer/%s="%s"' % (RENDERER_OVERRIDE_KEY, renderer)
               + text[m.end():])
    PROJECT_FILE.write_bytes(patched.encode("utf-8"))
    print("[DIAG-06] project.godot temporarily overridden: renderer/%s=\"%s\""
          % (RENDERER_OVERRIDE_KEY, renderer))
    return original


def _run_export(godot: str, apk: Path, renderer: str | None) -> bool:
    apk.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        godot, "--headless", "--path", str(REPO),
        "--export-release", PRESET_NAME, str(apk),
    ]
    original_project = None
    if renderer:
        original_project = _patch_renderer(renderer)
        if original_project is None:
            return False
    try:
        return _run_export_command(cmd, apk)
    finally:
        if original_project is not None:
            PROJECT_FILE.write_bytes(original_project)
            print("[DIAG-06] project.godot restored")


def _run_export_command(cmd: list, apk: Path) -> bool:
    env = dict(os.environ)
    if "GODOT_ANDROID_KEYSTORE_RELEASE_PATH" not in env:
        keystore = next((k for k in KEYSTORE_CANDIDATES if k.exists()), None)
        if keystore is None:
            print("[DIAG-06] FAIL — no debug keystore found. Looked in:")
            for k in KEYSTORE_CANDIDATES:
                print("[DIAG-06]   %s" % k)
            print("[DIAG-06] Godot creates one on its first Android export; do "
                  "one from the editor, or set "
                  "GODOT_ANDROID_KEYSTORE_RELEASE_PATH yourself.")
            return False
        print("[DIAG-06] signing with %s" % keystore)
        env["GODOT_ANDROID_KEYSTORE_RELEASE_PATH"] = str(keystore)
        env["GODOT_ANDROID_KEYSTORE_RELEASE_USER"] = KEYSTORE_USER
        env["GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"] = KEYSTORE_PASSWORD
    else:
        print("[DIAG-06] signing with the keystore already in the environment")

    print("[DIAG-06] %s" % " ".join(cmd))
    started = time.time()
    try:
        proc = subprocess.run(
            cmd, cwd=str(REPO), capture_output=True, text=True, env=env,
            timeout=EXPORT_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        print("[DIAG-06] FAIL — export exceeded %d s." % EXPORT_TIMEOUT_SECONDS)
        return False
    elapsed = time.time() - started

    tail = (proc.stdout or "") + (proc.stderr or "")
    for line in tail.strip().splitlines()[-25:]:
        print("[godot] %s" % line)

    if not apk.exists():
        print("[DIAG-06] FAIL — no APK at %s after %.0f s." % (apk, elapsed))
        print("[DIAG-06] If Godot reports missing export templates, install them")
        print("[DIAG-06] via Editor -> Manage Export Templates (see EXPORT_ANDROID.md).")
        return False

    ## ⚠️ GODOT WRITES AN APK EVEN WHEN THE EXPORT FAILED, and says so only in
    ## the log. Measured 2026-09-12: a missing release keystore produced
    ## `ERROR: Project export for preset "Android" failed.` alongside a
    ## 129.3 MB APK that passed every content assertion below and had no
    ## META-INF at all — unsigned, installable on nothing. `apk.exists()` is
    ## not evidence the export succeeded, and neither is the file being the
    ## right size with the right contents.
    if "export for preset" in tail and "failed" in tail:
        print("[DIAG-06] FAIL — Godot reported the export FAILED. The file on "
              "disk is not a usable build; read the log above.")
        return False

    print("[DIAG-06] exported in %.0f s" % elapsed)
    return True


def _verify_contents(apk: Path, show: bool, renderer: str | None = None) -> bool:
    """The whole point of the script. Assert what came out, not what was asked."""
    size_mb = apk.stat().st_size / (1024.0 * 1024.0)
    print("[DIAG-06] %s — %.1f MB" % (apk.name, size_mb))

    try:
        with zipfile.ZipFile(apk) as z:
            names = z.namelist()
            infos = z.infolist()
    except zipfile.BadZipFile:
        print("[DIAG-06] FAIL — not a readable archive.")
        return False

    ok = True

    ## An unsigned APK installs on nothing. This is the cheapest possible check
    ## and it is the one that caught the keystore failure described in
    ## `_run_export()` — every other assertion passed on that build.
    signatures = [n for n in names
                  if n.startswith("META-INF/") and n.endswith((".RSA", ".DSA", ".EC", ".SF"))]
    if signatures:
        print("[DIAG-06] ok   — signed (%s)" % ", ".join(sorted(signatures)))
    else:
        ok = False
        print("[DIAG-06] FAIL — UNSIGNED (no META-INF signature block). This "
              "APK cannot be installed. See EXPORT_ANDROID.md on keystores.")

    for label, pattern in FORBIDDEN_PATTERNS:
        hits = [n for n in names if pattern.search(n)]
        if hits:
            ok = False
            print("[DIAG-06] FAIL — %d %s present, exclude_filter is not holding:"
                  % (len(hits), label))
            for n in hits[:5]:
                print("[DIAG-06]     %s" % n)
            if len(hits) > 5:
                print("[DIAG-06]     ... and %d more" % (len(hits) - 5))
        else:
            print("[DIAG-06] ok   — no %s" % label)

    for label, pattern in REQUIRED_PATTERNS:
        hits = [n for n in names if pattern.search(n)]
        if not hits:
            ok = False
            print("[DIAG-06] FAIL — no %s packed. The build will boot and be "
                  "silently wrong." % label)
        else:
            print("[DIAG-06] ok   — %d %s" % (len(hits), label))

    ## The renderer is asserted from the packed settings, never from what was
    ## asked for — asking is exactly what failed the first time (`_patch_renderer`).
    try:
        with zipfile.ZipFile(apk) as z:
            settings = z.read("assets/project.binary")
    except KeyError:
        settings = b""
    has_override = RENDERER_OVERRIDE_KEY.encode() in settings
    if renderer:
        if has_override and renderer.encode() in settings:
            print("[DIAG-06] ok   — renderer override packed: %s" % renderer)
        else:
            ok = False
            print("[DIAG-06] FAIL — --renderer %s was asked for and is NOT in the "
                  "packed project.binary. This APK runs the project default." % renderer)
    elif has_override:
        ok = False
        print("[DIAG-06] FAIL — a %s override is packed but none was asked for; "
              "project.godot was left patched by an interrupted export." % RENDERER_OVERRIDE_KEY)
    else:
        print("[DIAG-06] ok   — renderer: project default (no override packed)")

    if size_mb >= SUSPICIOUS_SIZE_MB:
        ok = False
        print("[DIAG-06] FAIL — %.1f MB is over the %d MB tripwire. Something "
              "large is packed that should not be; run --contents."
              % (size_mb, SUSPICIOUS_SIZE_MB))

    if show:
        print("[DIAG-06] --- 15 largest entries ---")
        for info in sorted(infos, key=lambda i: i.file_size, reverse=True)[:15]:
            print("[DIAG-06]   %8.2f MB  %s"
                  % (info.file_size / (1024.0 * 1024.0), info.filename))

    return ok


def _install(apk: Path, wanted: str | None = None) -> bool:
    adb = _find(ADB_CANDIDATES, "adb")
    if not adb:
        return False
    devices = subprocess.run([adb, "devices"], capture_output=True, text=True)
    serials = [l.split()[0] for l in devices.stdout.replace("\r", "").splitlines()[1:]
               if l.strip().endswith("device")]
    if not serials:
        print("[DIAG-06] FAIL — no device. Check, in this order: the cable "
              "carries data, the phone's USB mode is File Transfer (not "
              "Charging), Developer Options -> USB debugging is on, and the "
              "'Allow USB debugging?' dialog on the phone has been accepted.")
        return False

    ## ⚠️ With two handsets attached a bare `adb install` fails outright, and
    ## picking one silently would install a measurement build on whichever the
    ## cable order happened to enumerate first. Name it or be told.
    if wanted:
        serials = [s for s in serials if wanted == s or wanted in s]
    if len(serials) != 1:
        print("[DIAG-06] FAIL — %d device(s) match%s; name one with --device:"
              % (len(serials), " %r" % wanted if wanted else ""))
        for s in serials:
            model = subprocess.run([adb, "-s", s, "shell", "getprop", "ro.product.model"],
                                   capture_output=True, text=True).stdout.strip()
            print("[DIAG-06]   --device %-18s %s" % (s, model))
        return False
    serial = serials[0]
    print("[DIAG-06] device: %s" % serial)

    # -r reinstalls in place, keeping the package; -d allows a version downgrade,
    # which matters because the preset pins version/code=1 on every build.
    proc = subprocess.run([adb, "-s", serial, "install", "-r", "-d", str(apk)],
                          capture_output=True, text=True)
    out = (proc.stdout or "") + (proc.stderr or "")
    print(out.strip())
    if "Success" not in out:
        print("[DIAG-06] FAIL — install did not report Success.")
        return False
    print("[DIAG-06] installed %s" % PACKAGE_NAME)
    return True


def main() -> int:
    ap = argparse.ArgumentParser(description="Export (and optionally install) the Android APK.")
    ap.add_argument("--out", default=str(DEFAULT_APK), help="APK path (default: export/Infiltraitor.apk)")
    ap.add_argument("--install", action="store_true", help="adb install -r the result")
    ap.add_argument("--contents", action="store_true", help="print the 15 largest packed entries")
    ap.add_argument("--renderer", default=None,
                    help="override the rendering method for this build "
                         "(e.g. gl_compatibility) — DIAG-04's control run")
    ap.add_argument("--verify-only", action="store_true",
                    help="skip the export, just assert the existing APK")
    ap.add_argument("--device", default=None,
                    help="adb serial (or a substring) for --install — required "
                         "when more than one handset is attached")
    args = ap.parse_args()

    apk = Path(args.out)
    if not apk.is_absolute():
        apk = REPO / apk

    if not args.verify_only:
        godot = _find(GODOT_CANDIDATES, "Godot")
        if not godot:
            return 1
        if not _run_export(godot, apk, args.renderer):
            return 1
    elif not apk.exists():
        print("[DIAG-06] FAIL — nothing at %s to verify." % apk)
        return 1

    if not _verify_contents(apk, args.contents, args.renderer):
        print("[DIAG-06] BUILD REJECTED — do not measure with this APK.")
        return 1

    if args.install and not _install(apk, args.device):
        return 1

    print("[DIAG-06] done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
