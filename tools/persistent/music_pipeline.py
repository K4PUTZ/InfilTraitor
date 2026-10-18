#!/usr/bin/env python3
##
## music_pipeline.py — the production mechanism for INFILTRAITOR's music.
##
## Source of truth: ASSETS/AUDIO/MUSIC/INFILTRAITOR_Music_Authorship_Project_Paper.pdf
## (sections 8 prompting, 9 pipeline, 10 provenance) and ASSETS/AUDIO/MUSIC/bible.json (the Music Bible, paper §12).
##
## The loop: bible -> `prompt <context>` -> generate OUTSIDE (ACE-Step or a DAW) -> `register` the take
## (hash + tool/version/licence + prompt + parameters, one JSON per take under provenance/) -> `export` the
## selected take (ffmpeg, loudness-normalised OGG under Export/<context>/, the manifest records the export).
## Raw takes live in Raw/ (git-ignored); provenance/ and Export/ are versioned.
##
##   python3 tools/persistent/music_pipeline.py check
##   python3 tools/persistent/music_pipeline.py prompt stealth [--bpm 112]
##   python3 tools/persistent/music_pipeline.py register stealth path/to/take.wav --tool ACE-Step --tool-version 1.5 \
##       --license Apache-2.0 --prompt-file p.txt [--params seed=42,steps=60] [--notes "..."]
##   python3 tools/persistent/music_pipeline.py export <take-id>
##   python3 tools/persistent/music_pipeline.py list
##
## Stdlib only; needs ffmpeg for `register` (duration) and `export`. Exit code 1 on any failed check.
import argparse, hashlib, json, shutil, subprocess, sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MUSIC = ROOT / "ASSETS" / "AUDIO" / "MUSIC"
BIBLE = MUSIC / "bible.json"
RAW = MUSIC / "Raw"
PROV = MUSIC / "provenance"
EXPORT = MUSIC / "Export"
REQUIRED_PROV = ("id", "context", "created", "source_sha256", "tool", "tool_version", "license", "prompt", "params")


def fail(msg):
    print(f"[music] ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def load_bible():
    if not BIBLE.exists():
        fail(f"{BIBLE} missing")
    try:
        return json.loads(BIBLE.read_text())
    except json.JSONDecodeError as e:
        fail(f"{BIBLE}: {e}")


def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def probe_duration(p):
    if not shutil.which("ffprobe"):
        fail("ffprobe not found (install ffmpeg)")
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(p)],
                         capture_output=True, text=True)
    if out.returncode != 0 or not out.stdout.strip():
        fail(f"ffprobe cannot read {p}: {out.stderr.strip()}")
    return round(float(out.stdout.strip()), 3)


def build_prompt(bible, ctx_id, bpm=None):
    ctxs = bible["contexts"]
    if ctx_id not in ctxs:
        fail(f"unknown context '{ctx_id}' (have: {', '.join(ctxs)})")
    c, g = ctxs[ctx_id], bible["global"]
    motifs = "; ".join(f"{m}: {bible['motifs'][m]['role']}" for m in c["motifs"])
    # paper §8 template: function, tempo/meter, harmonic language, rhythmic engine, instrumentation,
    # melodic behaviour, emotional objective, production character, instrumental constraint.
    parts = [
        c["function"],
        f"{bpm or c['bpm']} BPM, {g['meter']}",
        f"{g['tonal_center']}, {g['harmonic_dna']}",
        f"{c['density']} arrangement density, " + ("seamlessly loopable" if c["loop"] else "full-length with a distinctive signature ending"),
        g["timbral_dna"],
        f"melodic material: {motifs}",
        "controlled suspense and confidence, never helplessness, forward momentum",
        g["constraint"],
    ]
    return ", ".join(parts)


def cmd_check(a):
    bible, errs = load_bible(), []
    for k in ("global", "motifs", "contexts"):
        if k not in bible:
            errs.append(f"bible.json: missing '{k}'")
    lo, hi = bible.get("global", {}).get("bpm_range", [0, 0])
    for cid, c in bible.get("contexts", {}).items():
        for k in ("function", "bpm", "motifs", "density", "loop"):
            if k not in c:
                errs.append(f"context {cid}: missing '{k}'")
        if not lo <= c.get("bpm", 0) <= hi and cid != "menu":
            errs.append(f"context {cid}: bpm {c.get('bpm')} outside global range {lo}-{hi}")
        for m in c.get("motifs", []):
            if m not in bible.get("motifs", {}):
                errs.append(f"context {cid}: unknown motif '{m}'")
    for f in sorted(PROV.glob("*.json")):
        try:
            d = json.loads(f.read_text())
        except json.JSONDecodeError as e:
            errs.append(f"{f.name}: {e}")
            continue
        errs += [f"{f.name}: missing '{k}'" for k in REQUIRED_PROV if k not in d]
        if d.get("context") not in bible.get("contexts", {}):
            errs.append(f"{f.name}: unknown context '{d.get('context')}'")
        ex = d.get("export")
        if ex:
            ep = ROOT / ex["path"]
            if not ep.exists():
                errs.append(f"{f.name}: export {ex['path']} missing")
            elif sha256(ep) != ex["sha256"]:
                errs.append(f"{f.name}: export {ex['path']} changed since export (hash mismatch)")
    for e in errs:
        print(f"[music] FAIL {e}")
    if errs:
        sys.exit(1)
    print(f"[music] OK: bible ({len(bible['contexts'])} contexts), {len(list(PROV.glob('*.json')))} take(s)")


def cmd_prompt(a):
    print(build_prompt(load_bible(), a.context, a.bpm))


def cmd_register(a):
    bible, src = load_bible(), Path(a.file)
    if a.context not in bible["contexts"]:
        fail(f"unknown context '{a.context}'")
    if not src.is_file():
        fail(f"{src} not found")
    prompt = Path(a.prompt_file).read_text().strip() if a.prompt_file else (a.prompt or build_prompt(bible, a.context))
    params = dict(kv.split("=", 1) for kv in a.params.split(",")) if a.params else {}
    digest = sha256(src)
    tid = f"{a.context}-{datetime.now(timezone.utc):%Y%m%d}-{digest[:8]}"
    if (PROV / f"{tid}.json").exists():
        fail(f"take {tid} already registered")
    dest = RAW / a.context / f"{tid}{src.suffix.lower()}"
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    PROV.mkdir(parents=True, exist_ok=True)
    rec = {"id": tid, "context": a.context, "created": datetime.now(timezone.utc).isoformat(timespec="seconds"),
           "source_sha256": digest, "raw_path": str(dest.relative_to(ROOT)), "duration_s": probe_duration(dest),
           "tool": a.tool, "tool_version": a.tool_version, "license": a.license,
           "prompt": prompt, "params": params, "human_edits": a.edits or "", "notes": a.notes or "", "export": None}
    (PROV / f"{tid}.json").write_text(json.dumps(rec, indent=2) + "\n")
    print(f"[music] registered {tid} ({rec['duration_s']} s) -> provenance/{tid}.json; raw copy in {rec['raw_path']} (git-ignored)")


def cmd_export(a):
    pf = PROV / f"{a.take}.json"
    if not pf.exists():
        fail(f"no take '{a.take}' (see `list`)")
    rec = json.loads(pf.read_text())
    raw = ROOT / rec["raw_path"]
    if not raw.exists():
        fail(f"raw take {rec['raw_path']} missing locally (Raw/ is not versioned)")
    if sha256(raw) != rec["source_sha256"]:
        fail("raw take hash differs from its provenance record")
    if not shutil.which("ffmpeg"):
        fail("ffmpeg not found")
    out = EXPORT / rec["context"] / f"{rec['id']}.ogg"
    out.parent.mkdir(parents=True, exist_ok=True)
    # -16 LUFS integrated, -1.5 dBTP: a mobile-speaker-friendly master; Vorbis q6.
    r = subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(raw), "-af", "loudnorm=I=-16:TP=-1.5:LRA=11",
                        "-c:a", "libvorbis", "-q:a", "6", str(out)], capture_output=True, text=True)
    if r.returncode != 0:
        fail(f"ffmpeg failed: {r.stderr.strip()}")
    rec["export"] = {"path": str(out.relative_to(ROOT)), "sha256": sha256(out), "format": "ogg vorbis q6, -16 LUFS",
                     "exported": datetime.now(timezone.utc).isoformat(timespec="seconds")}
    pf.write_text(json.dumps(rec, indent=2) + "\n")
    print(f"[music] exported {rec['export']['path']}")


def cmd_list(a):
    for f in sorted(PROV.glob("*.json")):
        d = json.loads(f.read_text())
        print(f"{d['id']:<36} {d['context']:<13} {d.get('duration_s', '?'):>8}s  {d['tool']} {d['tool_version']}  "
              f"{'EXPORTED' if d.get('export') else 'raw only'}")


def main():
    ap = argparse.ArgumentParser(description="INFILTRAITOR music production pipeline")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("check").set_defaults(fn=cmd_check)
    p = sub.add_parser("prompt"); p.add_argument("context"); p.add_argument("--bpm", type=int); p.set_defaults(fn=cmd_prompt)
    p = sub.add_parser("register"); p.add_argument("context"); p.add_argument("file")
    for k in ("tool", "tool-version", "license"):
        p.add_argument(f"--{k}", required=True)
    for k in ("prompt", "prompt-file", "params", "edits", "notes"):
        p.add_argument(f"--{k}")
    p.set_defaults(fn=cmd_register)
    p = sub.add_parser("export"); p.add_argument("take"); p.set_defaults(fn=cmd_export)
    sub.add_parser("list").set_defaults(fn=cmd_list)
    a = ap.parse_args(); a.fn(a)


if __name__ == "__main__":
    main()
