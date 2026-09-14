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
                       "windows": [], "straddling": 0}
            segs.append(current)
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
    for seg in segs:
        ws = seg["windows"]
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
        print("| %s | %s | %s | %.2f | %d (+%d straddling) | %s |"
              % (seg["label"], last.get("framing", "?"), visible_text,
                 float(last.get("zoom", 0.0)), len(ws), seg["straddling"], " | ".join(cells)))
    return status


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("paths", nargs="+", help="logcat capture, stdout log or JSONL file")
    args = parser.parse_args()
    status = 0
    for path in args.paths:
        with open(path, encoding="utf-8", errors="replace") as handle:
            records = [r for r in (parse_line(line) for line in handle) if r is not None]
        if not records:
            print("## %s\n❌ no [TEL] records in this file" % path)
            status = 1
            continue
        for session in sessions(records):
            status = max(status, report(path, session))
            print()
    return status


if __name__ == "__main__":
    sys.exit(main())
