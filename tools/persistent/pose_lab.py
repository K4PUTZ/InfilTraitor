#!/usr/bin/env python3
"""pose_lab.py — pose the Tripo Agent by hand in Blender, and play it in the game (MOVEMENT, 2026-11-08).

The poses the game needs are a few KEY poses (`TripoFigure.POSES`: the draw and the aim of the pistol today); the engine blends between them. Their base is built in code (a
solver); the Director refines them here, in Blender, on the LIGHT Agent, with the weapon in the hand as an object he can move. His version, saved as
`ASSETS/ANIMATIONS/poses/<figure>/<id>.json`, REPLACES the solved one. The mechanism, the conversion and why it is trusted: `tools/asset_generation/tripo/tripo_pose_lab.py`.

    python3 tools/persistent/pose_lab.py open  aim_pistol [--figure male|female|both] [--no-open]
        Builds `ASSETS/MODELS/fit/POSE_<id>_<FIG>.blend` (the LIGHT Agent in the pose the game has today, the pistol as PROP_pistol, in Pose Mode) and opens it in Blender.
        A .blend that already exists is NEVER overwritten (it holds his work): it is opened as it is. Pose, move the pistol, SAVE (Ctrl+S).
    python3 tools/persistent/pose_lab.py save  aim_pistol [--figure ...] [--take]
        Reads the saved .blend, writes the pose file, rebuilds the game set (`tripo_game_clips.gd`) and, with --take, films the `pistol_aim` take with it.
    python3 tools/persistent/pose_lab.py sequence draw_pistol [--figure ...] [--take]
        Reads the timeline `SEQ_<name>_<FIG>.blend` (keyed idle -> draw -> ... -> aim) and writes `ASSETS/ANIMATIONS/sequences/<figure>/<name>.json` + one pose file per keyed frame
        (`seq_<name>_f<frame>.json`); the game then plays that sequence instead of the plain draw/aim path. Rules: `tripo_pose_lab.sequence`.
    python3 tools/persistent/pose_lab.py throw_new [--figure ...]
        Builds the STARTING timeline of the standing overhand throw, `SEQ_throw_overhand_<FIG>.blend` (idle -> cocked -> release -> follow -> idle, one
        `ThrowFix_f<frame>` coat key per pose), from the figure's draw timeline and the bank's `pitch_baseball`
        (`tripo_pose_lab.throw_new`; PROMPTS/THROW_STUDY_2026-11-12.md). An existing file is never overwritten.
    python3 tools/persistent/pose_lab.py render aim_pistol [--figure ...]
        Two stills of the saved .blend (front 3/4 and side), into temp/poses/.
    python3 tools/persistent/pose_lab.py reset aim_pistol --figure male
        Puts his pose file aside (temp/poses/set_aside/) so the game plays the solved pose again; his .blend stays.
    python3 tools/persistent/pose_lab.py status
        Which poses have his file, which .blend exist.

Disposable work (the dumps Blender starts from, the previews) goes to temp/poses/ (git-ignored, the Director may delete it).
"""
import argparse
import os
import shutil
import subprocess
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")
LAB = os.path.join(ROOT, "tools", "asset_generation", "tripo", "tripo_pose_lab.py")
FIGURES = ("male", "female")
POSES = ("draw_pistol", "mid_pistol", "aim_pistol")      # `TripoFigure.POSES`
TEMP = os.path.join(ROOT, "temp", "poses")


def blend_path(pose, figure):
    return os.path.join(ROOT, "ASSETS", "MODELS", "fit", f"POSE_{pose}_{figure.upper()}.blend")


def pose_file(pose, figure):
    return os.path.join(ROOT, "ASSETS", "ANIMATIONS", "poses", figure, f"{pose}.json")


def run(cmd, what):
    print(f"[pose_lab] {what} ...")
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    out = (r.stdout or "") + (r.stderr or "")
    for line in out.splitlines():
        if "[tripo_pose_lab]" in line or "[tripo_pose_dump]" in line or "[tripo_game_clips]" in line or "ERROR" in line or "Traceback" in line:
            print("  " + line)
    if r.returncode != 0:
        sys.exit(f"[pose_lab] FAILED: {what} (exit {r.returncode})")
    return out


def figures_of(arg):
    return list(FIGURES) if arg == "both" else [arg]


def check_pose(pose):
    if pose not in POSES:
        sys.exit(f"[pose_lab] unknown pose '{pose}' (have {', '.join(POSES)})")


def dump(figure, pose):
    os.makedirs(TEMP, exist_ok=True)
    run([GODOT, "--headless", "--path", ROOT, "--script", "godot/scripts/tools/tripo_pose_dump.gd", "--", figure, TEMP, pose], f"dumping the {figure} rest, idle and {pose} for Blender")


def cmd_open(a):
    check_pose(a.pose)
    for figure in figures_of(a.figure):
        path = blend_path(a.pose, figure)
        if os.path.exists(path):
            print(f"[pose_lab] {os.path.relpath(path, ROOT)} exists: it holds your work, so it is opened as it is (never rebuilt)")
        else:
            dump(figure, a.pose)
            run([BLENDER, "-b", "--python", LAB, "--", "build", figure, a.pose, TEMP, path], f"building {os.path.relpath(path, ROOT)}")
        if not a.no_open:
            subprocess.run(["open", "-a", "Blender", path])
            print(f"[pose_lab] opened in Blender. Pose Mode is on; the pistol is the object PROP_pistol. Save with Ctrl+S, then: pose_lab.py save {a.pose} --figure {figure}")


def cmd_save(a):
    check_pose(a.pose)
    for figure in figures_of(a.figure):
        path = blend_path(a.pose, figure)
        if not os.path.exists(path):
            sys.exit(f"[pose_lab] {os.path.relpath(path, ROOT)} does not exist: run `pose_lab.py open {a.pose} --figure {figure}` first")
        out = pose_file(a.pose, figure)
        run([BLENDER, "-b", "--python", LAB, "--", "extract", path, out], f"reading {os.path.relpath(path, ROOT)}")
        print(f"[pose_lab] wrote {os.path.relpath(out, ROOT)}")
    run([GODOT, "--headless", "--path", ROOT, "--script", "godot/scripts/tools/tripo_game_clips.gd"], "rebuilding the game set (the poses go into the APK's library)")
    if a.take:
        cmd_take(a)


def cmd_take(a):
    for figure in figures_of(a.figure):
        env = dict(os.environ, INFILTRAITOR_TRIPO_FIGURE=figure)
        print(f"[pose_lab] filming the take `pistol_aim` with the {figure} ...")
        r = subprocess.run([sys.executable, "tools/persistent/capture.py", "--map", "PLAYGROUND", "--take", "pistol_aim"], cwd=ROOT, env=env, capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit("[pose_lab] the take failed:\n" + r.stdout[-1500:] + r.stderr[-800:])
        src = os.path.join(ROOT, "temp", "videos", "PLAYGROUND_pistol_aim.mp4")
        dst = os.path.join(ROOT, "temp", "videos", f"pose_{a.pose}_{figure}.mp4")
        shutil.copy(src, dst)
        print(f"[pose_lab] {os.path.relpath(dst, ROOT)}")


def cmd_sequence(a):
    for figure in figures_of(a.figure):
        path = os.path.join(ROOT, "ASSETS", "MODELS", "fit", f"SEQ_{a.pose}_{figure.upper()}.blend")
        if not os.path.exists(path):
            sys.exit(f"[pose_lab] {os.path.relpath(path, ROOT)} does not exist")
        out = os.path.join(ROOT, "ASSETS", "ANIMATIONS", "sequences", figure, f"{a.pose}.json")
        poses = os.path.join(ROOT, "ASSETS", "ANIMATIONS", "poses", figure)
        run([BLENDER, "-b", "--python", LAB, "--", "sequence", path, a.pose, out, poses], f"reading {os.path.relpath(path, ROOT)}")
    run([GODOT, "--headless", "--path", ROOT, "--script", "godot/scripts/tools/tripo_game_clips.gd"], "rebuilding the game set (the poses go into the APK's library)")
    if a.take:
        cmd_take(a)


def cmd_throw_new(a):
    for figure in figures_of(a.figure):
        for part in ("overhand",):
            out = os.path.join(ROOT, "ASSETS", "MODELS", "fit", f"SEQ_throw_{part}_{figure.upper()}.blend")
            if os.path.exists(out):
                print(f"[pose_lab] {os.path.relpath(out, ROOT)} exists: it holds your work, so it is left as it is")
                continue
            base = os.path.join(ROOT, "ASSETS", "MODELS", "fit", f"SEQ_draw_pistol_{figure.upper()}.blend")
            clip = os.path.join(ROOT, "ASSETS", "ANIMATIONS", "bank", figure, "pitch_baseball.glb")
            run([BLENDER, "-b", "--python", LAB, "--", "throw_new", base, clip, out, part], f"building {os.path.relpath(out, ROOT)}")


def cmd_render(a):
    check_pose(a.pose)
    for figure in figures_of(a.figure):
        path = blend_path(a.pose, figure)
        if not os.path.exists(path):
            sys.exit(f"[pose_lab] {os.path.relpath(path, ROOT)} does not exist")
        os.makedirs(TEMP, exist_ok=True)
        png = os.path.join(TEMP, f"POSE_{a.pose}_{figure.upper()}.png")
        run([BLENDER, "-b", "--python", LAB, "--", "render", path, png], f"rendering {os.path.basename(path)}")


def cmd_reset(a):
    check_pose(a.pose)
    if a.figure == "both":
        sys.exit("[pose_lab] reset takes one --figure")
    path = pose_file(a.pose, a.figure)
    if not os.path.exists(path):
        print("[pose_lab] there is no pose file: the game already plays the solved pose")
        return
    aside = os.path.join(TEMP, "set_aside")
    os.makedirs(aside, exist_ok=True)
    dst = os.path.join(aside, f"{a.figure}_{a.pose}_{time.strftime('%Y%m%d_%H%M%S')}.json")
    shutil.move(path, dst)
    run([GODOT, "--headless", "--path", ROOT, "--script", "godot/scripts/tools/tripo_game_clips.gd"], "rebuilding the game set")
    print(f"[pose_lab] set aside to {os.path.relpath(dst, ROOT)}; the solved pose is back")


def cmd_status(_a):
    for pose in POSES:
        for figure in FIGURES:
            have = os.path.exists(pose_file(pose, figure))
            blend = os.path.exists(blend_path(pose, figure))
            print(f"  {pose:12s} {figure:7s} pose file: {'HIS' if have else 'solved (no file)':16s} .blend: {'yes' if blend else 'no'}")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    for name, fn in (("open", cmd_open), ("save", cmd_save), ("sequence", cmd_sequence), ("render", cmd_render), ("reset", cmd_reset)):
        s = sub.add_parser(name)
        s.add_argument("pose")
        s.add_argument("--figure", default="male", choices=list(FIGURES) + ["both"])
        if name == "open":
            s.add_argument("--no-open", action="store_true")
        if name in ("save", "sequence"):
            s.add_argument("--take", action="store_true")
        s.set_defaults(fn=fn)
    s = sub.add_parser("throw_new")
    s.add_argument("--figure", default="both", choices=list(FIGURES) + ["both"])
    s.set_defaults(fn=cmd_throw_new)
    s = sub.add_parser("status")
    s.set_defaults(fn=cmd_status)
    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
