#!/usr/bin/env python3
##
## apk_audit.py — what is inside an exported APK, by weight, and what in it nobody references (roadmap A1, "export audit and size check").
##
## It reads the APK as a zip (COMPRESSED bytes: that is what the player downloads), groups every entry by category, and for each IMPORTED
## resource (`assets/.godot/imported/<source>-<hash>.<ext>`) asks `git grep` whether the source's file name appears in any tracked text file
## outside docs/ (scripts, scenes, json, tres, cfg). An entry nobody names is a CANDIDATE, not proof: a resource loaded by a built path
## (`"facade_%s" % id`) has no literal name, so every candidate is read before it is removed.
##
##     python3 tools/persistent/apk_audit.py export/steam6.apk            # the table and the candidates
##     python3 tools/persistent/apk_audit.py export/steam6.apk --max-mb 130   # exit 1 when the APK is larger (the size check)
##     python3 tools/persistent/apk_audit.py export/steam6.apk --top 40

import argparse
import re
import subprocess
import sys
import zipfile
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMPORTED = re.compile(r"^assets/\.godot/imported/(?P<src>.+?)-[0-9a-f]{32}\.(?P<ext>[^.]+)$")


def category(name: str) -> str:
    if name.startswith("lib/"):
        return "engine (native libs)"
    if name.endswith(".dex") or name.startswith(("META-INF", "AndroidManifest", "res/")):
        return "android shell"
    m = IMPORTED.match(name)
    if m:
        src, ext = m.group("src"), m.group("ext")
        if ext in ("mp3str", "oggvorbisstr", "sample"):
            return "audio"
        if ext in ("scn", "mesh", "res") and src.endswith((".glb", ".gltf", ".blend", ".fbx")):
            return "3D models / rigs"
        if ext == "ctex":
            return "textures (imported)"
        return "other imported (.%s)" % ext
    if name.startswith("assets/"):
        if name.endswith((".json", ".cfg", ".csv")):
            return "data (json / cfg / csv)"
        if name.endswith((".gdc", ".gd", ".tscn", ".scn", ".tres")):
            return "scripts and scenes"
        return "other files in assets/"
    return "other"


def referenced(sources: list) -> set:
    """The subset of `sources` (file names) that appear in a tracked text file outside docs/ and PROMPTS/."""
    text = subprocess.run(["git", "-C", str(ROOT), "grep", "-h", "-I", "-o", "-E", r"[A-Za-z0-9_ ./+()-]+\.(png|jpg|jpeg|webp|svg|glb|gltf|blend|fbx|mp3|ogg|wav|vox|tres|res|exr|hdr)",
                           "--", ".", ":!docs", ":!PROMPTS", ":!*.md"], capture_output=True, text=True).stdout
    names = {Path(t).name for t in text.splitlines()}
    return {s for s in sources if Path(s).name in names}


def import_sources() -> dict:
    """APK entry name (`assets/.godot/imported/<file>`) -> the project path it was imported from, read from every `*.import` file."""
    out = {}
    for imp in ROOT.rglob("*.import"):
        if any(part in (".git", "export", "ARCHIVE", "worktrees", ".claude") for part in imp.parts):
            continue
        src, dests = None, []
        for line in imp.read_text(errors="ignore").splitlines():
            if line.startswith("source_file="):
                src = line.split("=", 1)[1].strip().strip('"').replace("res://", "")
            elif line.startswith(("path=", "path.", "dest_files=")):
                dests += re.findall(r'res://\.godot/imported/([^"\]]+?)(?=["\]]|$)', line)
        for d in dests:
            if src:
                out["assets/.godot/imported/" + d.strip()] = src
    return out


def top_dir(src: str, depth: int = 2) -> str:
    parts = src.split("/")
    return "/".join(parts[:depth]) if len(parts) > depth else src


def main() -> int:
    ap = argparse.ArgumentParser(description="APK weight by category + unreferenced candidates (see the header)")
    ap.add_argument("apk")
    ap.add_argument("--top", type=int, default=25)
    ap.add_argument("--max-mb", type=float, default=0.0, help="fail when the APK file is larger than this many MB")
    args = ap.parse_args()
    apk = Path(args.apk)
    z = zipfile.ZipFile(apk)
    by_cat = defaultdict(lambda: [0, 0, 0])   # compressed, uncompressed, count
    imported = {}                             # source -> compressed bytes
    for info in z.infolist():
        c = category(info.filename)
        by_cat[c][0] += info.compress_size
        by_cat[c][1] += info.file_size
        by_cat[c][2] += 1
        m = IMPORTED.match(info.filename)
        if m:
            imported[m.group("src")] = imported.get(m.group("src"), 0) + info.compress_size
    total = apk.stat().st_size
    print("%s — %.1f MB on disk, %d entries\n" % (apk.name, total / 1e6, len(z.infolist())))
    print("%-28s %10s %12s %7s" % ("category", "MB (zip)", "MB (raw)", "files"))
    for c, (cz, raw, n) in sorted(by_cat.items(), key=lambda kv: -kv[1][0]):
        print("%-28s %10.1f %12.1f %7d" % (c, cz / 1e6, raw / 1e6, n))
    sources = import_sources()
    by_dir = defaultdict(lambda: [0, 0])
    unresolved = 0
    for info in z.infolist():
        if IMPORTED.match(info.filename):
            src = sources.get(info.filename)
            if src is None:
                unresolved += 1
                src = "(no .import found)"
            d = top_dir(src, 3 if src.startswith("ASSETS/") else 1)
            by_dir[d][0] += info.compress_size
            by_dir[d][1] += 1
    print("\nImported weight by SOURCE directory (zip MB):")
    for d, (b, n) in sorted(by_dir.items(), key=lambda kv: -kv[1][0])[:args.top]:
        print("  %8.2f MB %5d files  %s" % (b / 1e6, n, d))
    if unresolved:
        print("  (%d imported entries had no .import file to name their source)" % unresolved)
    refs = referenced(list(imported))
    cand = sorted(((b, s) for s, b in imported.items() if s not in refs), reverse=True)
    print("\nImported resources no tracked file names (CANDIDATES, %.1f MB zip of %.1f MB imported):" % (
        sum(b for b, _ in cand) / 1e6, sum(imported.values()) / 1e6))
    for b, s in cand[:args.top]:
        print("  %8.2f MB  %s" % (b / 1e6, s))
    if len(cand) > args.top:
        print("  ... and %d more" % (len(cand) - args.top))
    if args.max_mb and total / 1e6 > args.max_mb:
        print("\n[APK-SIZE] FAIL: %.1f MB is over the %.1f MB limit" % (total / 1e6, args.max_mb))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
