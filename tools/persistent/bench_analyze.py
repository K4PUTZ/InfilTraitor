#!/usr/bin/env python3
"""bench_analyze.py — read a telemetry timeline and say what it measured.

TEL-07 (DEVICE_DIAGNOSTICS_MASTER_PLAN §14). This is the first slice, TEL-07a:
enough to turn a scenario run into a table. Percentiles per phase, hitch records
and `--compare` arrive with TEL-05 and the rest of TEL-07.

INPUT — any file holding `Telemetry` records, in either sink's shape:
  * a logcat capture (`device_run.py --save`) or a desktop stdout log: every line
    containing `[TEL] <seq> <frame> <t_us> <kind> k=v ...`
  * the JSONL file sink (`adb pull` of the app's `files/telemetry/`)

WHAT IT REPORTS, and why each one is there:
  * The session header — device, GPU, renderer, version, flags — because a number
    read without them is not comparable (plan §14.2 #1).
  * DROPPED LINES. logcat loses lines under load, and every record carries a gap-
    free sequence number, so a gap is a counted loss rather than a silent one.
  * One row per `scenario.mark` segment: the median of each `frame.window` column
    inside it, with the framing and the zoom it was read under.

⚠️ THE WINDOW THAT STRADDLES A CHANGE IS DROPPED BY ARITHMETIC, NOT BY HABIT. A
`frame.window` record is written when its window CLOSES and says how many frames
it covered and their mean ms, so its start is `t_us - frames * ms`. A window that
started before the segment's mark measured part of the previous zoom, and is
excluded and counted. "Skip the first window" would be wrong whenever the mark
happened to land exactly on a window boundary — or two windows after the change.

Exit status: 1 when the file holds no session, no windows, or an aborted scenario —
an analysis that silently reports nothing is a claim about the harness.

Usage:
    python3 tools/persistent/bench_analyze.py docs/measurements/<run>.log
    python3 tools/persistent/bench_analyze.py <dir>/tel_*.jsonl
"""

from __future__ import annotations

import argparse
import json
import re
import statistics
import sys

TEL_RE = re.compile(r"\[TEL\] (\d+) (\d+) (\d+) (\S+)(.*)$")

## Columns of a `frame.window` record summarised per segment, in print order.
WINDOW_COLUMNS = [
    ("ms", "ms/frame", "%.1f"),
    ("render_cpu", "render cpu", "%.1f"),
    ("render_gpu", "render gpu", "%.1f"),
    ("draws", "draws", "%d"),
    ("objects", "objects", "%d"),
    ("primitives", "primitives", "%d"),
    ("gu_visible", "cells on screen", "%d"),
]

SESSION_FIELDS = ["version", "model", "os", "os_version", "cpu", "gpu", "gpu_api",
                  "renderer", "screen", "refresh_hz", "window", "flags_file",
                  "file_sink", "overrides"]


def _value(text: str):
    """A logcat field back into a number or a vector where it was one."""
    for cast in (int, float):
        try:
            return cast(text)
        except ValueError:
            pass
    if "," in text:
        try:
            return [float(part) for part in text.split(",")]
        except ValueError:
            return text
    return text


def parse_line(line: str) -> dict | None:
    line = line.rstrip("\n")
    stripped = line.lstrip()
    if stripped.startswith("{"):
        try:
            record = json.loads(stripped)
        except json.JSONDecodeError:
            return None
        return record if "seq" in record and "kind" in record else None
    match = TEL_RE.search(line)
    if not match:
        return None
    record = {"seq": int(match[1]), "f": int(match[2]), "t_us": int(match[3]),
              "kind": match[4]}
    for token in match[5].split():
        if "=" in token:
            key, raw = token.split("=", 1)
            record[key] = _value(raw)
    return record


def sessions(records: list[dict]) -> list[list[dict]]:
    """Split on `session` records; a record before any session is kept in a
    headless first session so it is reported rather than dropped."""
    out: list[list[dict]] = []
    for record in records:
        if record["kind"] == "session" or not out:
            out.append([])
        out[-1].append(record)
    return out


def dropped(session: list[dict]) -> int:
    seqs = {r["seq"] for r in session}
    return (max(seqs) - len(seqs)) if seqs else 0


def segments(session: list[dict]) -> list[dict]:
    segs: list[dict] = []
    current: dict | None = None
    for record in sorted(session, key=lambda r: r["seq"]):
        kind = record["kind"]
        if kind == "scenario.mark":
            current = {"label": str(record.get("label", "?")), "t_us": record["t_us"],
                       "windows": [], "straddling": 0, "touched": 0}
            segs.append(current)
        elif kind in ("camera.pan_end", "camera.zoom_end") and record.get("via") != "scenario" \
                and current is not None:
            ## A camera gesture the scenario did not issue is a finger on the screen.
            ## DIAG-21's first Moto run: three drags inside one stop moved the camera
            ## off the agent for the rest of the ladder, and every later row compared
            ## a different view with its control. The segment is kept but flagged;
            ## its rows cannot be paired.
            current["touched"] = current.get("touched", 0) + 1
        elif kind in ("scenario.end", "scenario.abort", "view.framing", "camera.zoom_end"):
            ## Any of these changes what the next window measures, so it closes
            ## the segment; the next mark opens a new one.
            current = None
        elif kind == "frame.window" and current is not None:
            start_us = record["t_us"] - record["frames"] * record["ms"] * 1000.0
            if start_us >= current["t_us"]:
                current["windows"].append(record)
            else:
                current["straddling"] += 1
    return segs


def _median(windows: list[dict], key: str):
    values = [w[key] for w in windows if isinstance(w.get(key), (int, float))]
    return statistics.median(values) if values else None


def report(path: str, session: list[dict]) -> int:
    status = 0
    header = session[0] if session[0]["kind"] == "session" else None
    print("## %s" % path)
    if header is None:
        print("❌ no session record — this timeline has no header to read its numbers against")
        status = 1
    else:
        for key in SESSION_FIELDS:
            if key in header:
                print("- %s: %s" % (key, header[key]))
    lost = dropped(session)
    windows = [r for r in session if r["kind"] == "frame.window"]
    print("- records: %d · dropped lines: %d%s · frame windows: %d"
          % (len(session), lost, " ⚠️" if lost else "", len(windows)))
    if any(r["kind"] == "scenario.abort" for r in session):
        print("❌ the scenario ABORTED — see scenario.abort in the log")
        status = 1
    if not windows:
        print("❌ no frame.window records — was FRAME_PROBE=1 set with TELEMETRY=1?")
        return 1

    segs = segments(session)
    if not segs:
        print("(no scenario.mark segments — nothing to tabulate yet; TEL-05 adds phases)")
        return status
    print()
    columns = " | ".join(title for _, title, _ in WINDOW_COLUMNS)
    print("| segment | framing | visible | zoom | windows | %s |" % columns)
    print("|---|---|---|---|---|%s|" % "|".join("---" for _ in WINDOW_COLUMNS))
    touched_labels = []
    for seg in segs:
        ws = seg["windows"]
        if seg.get("touched", 0):
            touched_labels.append("%s (%d gesture(s))" % (seg["label"], seg["touched"]))
        if not ws:
            print("| %s | — | — | — | 0 (%d straddling) | %s |"
                  % (seg["label"], seg["straddling"], " | ".join("—" for _ in WINDOW_COLUMNS)))
            continue
        last = ws[-1]
        visible = last.get("visible")
        visible_text = ("%dx%d" % (visible[0], visible[1])
                        if isinstance(visible, list) and len(visible) == 2 else str(visible))
        cells = []
        for key, _, fmt in WINDOW_COLUMNS:
            med = _median(ws, key)
            cells.append("—" if med is None else fmt % med)
        print("| %s%s | %s | %s | %.2f | %d (+%d straddling) | %s |"
              % (seg["label"], " ⚠️ touched" if seg.get("touched", 0) else "",
                 last.get("framing", "?"), visible_text,
                 float(last.get("zoom", 0.0)), len(ws), seg["straddling"], " | ".join(cells)))
    if touched_labels:
        print("\n⚠️ camera gestures the scenario did not issue (a finger on the screen) in: %s — "
              "those rows measured a view their control did not" % ", ".join(touched_labels))
    return status


## TEL-07b — the detonation probe's report (`EVENT_FRAMES=1`). One summary line per
## detonation, then one line per beat mark on its frame timeline.
EFRAME_SUMMARY_RE = re.compile(
    r"\[E-FRAME\] (\S+) \S+ (\d+) frame\(s\), (\d+) ms wall clock, mean ([\d.]+) ms"
    r" \S+ WORST ([\d.]+) ms on frame (\d+)")
EFRAME_BEAT_RE = re.compile(
    r"\[E-FRAME\]\s+f(\d+)\s+(.+?)\s+its frame\s+([\d.]+) ms \S+ then\s+(\d+) f,"
    r"\s+([\d.]+) ms, max\s+([\d.]+) ms")


def detonations(lines: list[str]) -> list[dict]:
    """Every `[E-FRAME]` report in file order, each tagged with the scenario mark and
    the `detonate` step that preceded it, so a matrix row names its own blasts."""
    out: list[dict] = []
    mark = step = ""
    for line in lines:
        record = parse_line(line)
        if record is not None:
            if record["kind"] == "scenario.mark":
                mark = str(record.get("label", ""))
            elif record["kind"] == "scenario.step" and "detonate" in str(record.get("step", "")):
                step = str(record.get("step", ""))
            continue
        summary = EFRAME_SUMMARY_RE.search(line)
        if summary:
            out.append({"label": summary[1], "frames": int(summary[2]), "wall_ms": int(summary[3]),
                        "mean": float(summary[4]), "worst": float(summary[5]),
                        "mark": mark, "step": step, "beats": {}})
            continue
        beat = EFRAME_BEAT_RE.search(line)
        if beat and out:
            ## A beat name can repeat (BEAT 1, BEAT 1 ends); the first of each wins.
            out[-1]["beats"].setdefault(beat[2].strip(), {
                "frame": int(beat[1]), "its_ms": float(beat[3]), "then_f": int(beat[4]),
                "then_ms": float(beat[5]), "max_ms": float(beat[6])})
    return out


def detonation_table(dets: list[dict]) -> None:
    def beat(d, name, fmt):
        b = d["beats"].get(name)
        return "—" if b is None else fmt(b)
    print("| # | mark | step | frames | wall s | mean ms | worst ms | PUMP f · s | COMMIT frame ms"
          " | SOOT FADE 1st frame ms | CONSEQUENCE ms/f | LIGHT ms/f |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for i, d in enumerate(dets, 1):
        per_frame = lambda b: "%.1f" % (b["then_ms"] / b["then_f"]) if b["then_f"] else "—"
        print("| %d | %s | %s | %d | %.1f | %.1f | %.1f | %s | %s | %s | %s | %s |" % (
            i, d["mark"] or "—", d["step"] or "—", d["frames"], d["wall_ms"] / 1000.0,
            d["mean"], d["worst"],
            beat(d, "PUMP ends", lambda b: "%d · %.1f" % (b["then_f"], b["then_ms"] / 1000.0)),
            beat(d, "COMMIT", lambda b: "%.0f" % b["its_ms"]),
            beat(d, "SOOT FADE", lambda b: "%.0f" % b["its_ms"]),
            beat(d, "CONSEQUENCE", per_frame),
            beat(d, "LIGHT", per_frame)))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("paths", nargs="+", help="logcat capture, stdout log or JSONL file")
    args = parser.parse_args()
    status = 0
    for path in args.paths:
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = handle.readlines()
        records = [r for r in (parse_line(line) for line in lines) if r is not None]
        dets = detonations(lines)
        if not records and not dets:
            print("## %s\n❌ no [TEL] records and no [E-FRAME] reports in this file" % path)
            status = 1
            continue
        for session in sessions(records):
            status = max(status, report(path, session))
            print()
        if dets:
            print("### detonations — %s" % path)
            detonation_table(dets)
            print()
    return status


if __name__ == "__main__":
    sys.exit(main())
