#!/usr/bin/env python3
# tripo_bank_catalog.py — MOVEMENT MV-1 §3.2 step 4: the animation bank's catalogue. Plain Python, no Blender: it reads what tripo_anim_bank.py measured (bank.json) and
# the hand-kept table (bank_tags.json, one row per clip id), writes the three fields into bank.json and a readable ASSETS/ANIMATIONS/bank/CATALOG.md (one table per category).
# A clip with no row, or a row with no clip, is an error: the table must never drift from the bank in silence. A variant (<id>_b, _c...) reads its base id's row.
# --sheets also stitches the frames of tripo_bank_sheets.py into bank/sheets/: one sheet per clip (clips/<id>.png: female | male, three-quarter and side) and index pages per category
# (<category>_NN.png: one row per clip, three-quarter), so the Director judges by looking.
# Usage (from the repo root): python3 tools/asset_generation/tripo/tripo_bank_catalog.py [--sheets] [bank_dir]
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "tools" / "persistent"))
from temp_dir import temp_path  # noqa: E402

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
SHEETS = "--sheets" in sys.argv
BANK = Path(ARGS[0]) if ARGS else Path("ASSETS/ANIMATIONS/bank")
CATEGORIES = ("locomotion", "combat", "reaction", "idle", "interaction", "gesture", "showcase")
PRIORITIES = ("P0", "P1", "P2", "")
FIGURES = ("female", "male")
TILE = (168, 196)
FRAMES_PER_CLIP = 4
ROWS_PER_PAGE = 12
LABEL_W = 250
BG = (40, 41, 44)
TEXT = (235, 235, 235)
DIM = (165, 167, 172)


def font(size: int):
    from PIL import ImageFont
    try:
        return ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", size)
    except OSError:
        return ImageFont.load_default()


def tiles(frames: Path, figure: str, cid: str, view: int) -> list:
    """the clip's frames for one figure and view; an empty list when that figure has no such clip"""
    from PIL import Image
    paths = [frames / figure / ("%s_%d_%d.png" % (cid, view, i)) for i in range(FRAMES_PER_CLIP)]
    return [Image.open(p).convert("RGB") for p in paths] if all(p.exists() for p in paths) else []


def paste_row(sheet, frames: Path, row: dict, cid: str, view: int, x0: int, y0: int) -> None:
    from PIL import ImageDraw
    draw = ImageDraw.Draw(sheet)
    for fi, figure in enumerate(FIGURES):
        got = tiles(frames, figure, cid, view)
        x = x0 + fi * (FRAMES_PER_CLIP * TILE[0] + 6)
        for i, im in enumerate(got):
            sheet.paste(im, (x + i * TILE[0], y0))
        if not got:
            draw.text((x + 12, y0 + TILE[1] / 2 - 8), "no %s clip" % figure if figure not in row else "no frames", fill=DIM, font=font(15))


def save(sheet, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("P", palette=1, colors=128).save(path, optimize=True)      # flat colours: 128 are plenty, and the sheets are versioned


def build_sheets(clips: dict, by_category: dict) -> None:
    from PIL import Image, ImageDraw
    frames = temp_path("work", "bank_frames")
    out = BANK / "sheets"
    width = 2 * FRAMES_PER_CLIP * TILE[0] + 6
    for cid, row in clips.items():
        sheet = Image.new("RGB", (width, 34 + 2 * TILE[1] + 4), BG)
        ImageDraw.Draw(sheet).text((8, 8), "%s   |   %s   |   %s   |   left: female, right: male   |   top: three-quarter, bottom: side" % (cid, row["category"], seconds(row) + " s"), fill=TEXT, font=font(16))
        for view in (0, 1):
            paste_row(sheet, frames, row, cid, view, 0, 34 + view * (TILE[1] + 4))
        save(sheet, out / "clips" / (cid + ".png"))
    pages = 0
    for category in CATEGORIES:
        ids = sorted(by_category[category], key=lambda c: (clips[c]["priority"] or "P9", c))
        for page in range(0, len(ids), ROWS_PER_PAGE):
            part = ids[page:page + ROWS_PER_PAGE]
            sheet = Image.new("RGB", (LABEL_W + width, 40 + len(part) * (TILE[1] + 4)), BG)
            draw = ImageDraw.Draw(sheet)
            draw.text((10, 10), "%s (%d clips), page %d   |   left: female, right: male" % (category, len(ids), page // ROWS_PER_PAGE + 1), fill=TEXT, font=font(20))
            for ri, cid in enumerate(part):
                y = 40 + ri * (TILE[1] + 4); row = clips[cid]
                draw.text((10, y + 8), cid if len(cid) < 27 else cid[:19] + "..." + cid[-5:], fill=TEXT, font=font(16))   # the end says which variant it is
                draw.text((10, y + 32), "%s s   %s" % (seconds(row), "loops" if any(row[f]["loops"] for f in FIGURES if f in row) else "ends elsewhere"), fill=DIM, font=font(14))
                if row["priority"]:
                    draw.text((10, y + 52), row["priority"], fill=(255, 200, 90), font=font(14))
                words, line, ly = row["use"].split(), "", y + 72
                for w in words:
                    if len(line) + len(w) > 30:
                        draw.text((10, ly), line, fill=DIM, font=font(13)); ly += 17; line = ""
                    line += w + " "
                draw.text((10, ly), line, fill=DIM, font=font(13))
                paste_row(sheet, frames, row, cid, 0, LABEL_W, y)
            save(sheet, out / ("%s_%02d.png" % (category, page // ROWS_PER_PAGE + 1)))
            pages += 1
    (out / ".gdignore").touch()
    print("[tripo_bank_catalog] sheets: %d clips, %d index pages in %s" % (len(clips), pages, out))


def base_id(cid: str) -> str:
    return re.sub(r"_[b-e]$", "", cid)


def seconds(row: dict) -> str:
    """the two figures' lengths, once when they agree"""
    vals = sorted({row[f]["seconds"] for f in FIGURES if f in row})
    return " / ".join("%.1f" % v for v in vals)


def main() -> int:
    path = BANK / "bank.json"
    doc = json.loads(path.read_text())
    table = json.loads((HERE / "bank_tags.json").read_text())["clips"]
    clips = doc["clips"]

    errors = []
    bases = {base_id(c) for c in clips}
    errors += ["clip with no row in bank_tags.json: %s" % c for c in sorted(bases - set(table))]
    errors += ["row with no clip in the bank: %s" % c for c in sorted(set(table) - bases)]
    for cid, (category, priority, _use) in table.items():
        if category not in CATEGORIES:
            errors.append("%s: unknown category %r" % (cid, category))
        if priority not in PRIORITIES:
            errors.append("%s: unknown priority %r" % (cid, priority))
    if errors:
        print("[tripo_bank_catalog] ERROR:\n  " + "\n  ".join(errors))
        return 1

    by_category = {c: [] for c in CATEGORIES}
    for cid, row in clips.items():
        category, priority, use = table[base_id(cid)]
        row.update({"category": category, "priority": priority, "use": use})
        by_category[category].append(cid)
    path.write_text(json.dumps(doc, indent=1, sort_keys=True))
    if SHEETS:
        build_sheets(clips, by_category)

    pairs = sum(1 for r in clips.values() if "missing" not in r)
    lines = ["# The animation bank", "",
             "Generated by `tools/asset_generation/tripo/tripo_bank_catalog.py` from `bank.json` and `bank_tags.json`: edit the table, not this file. "
             "Plan: `PROMPTS/PLANNING/MOVEMENT_MASTER_PLAN.md` §3. Category, priority and use are BY NAME until a clip's sheet has been judged; the priority is Claude's proposal until the Director ranks it.", "",
             "**%d clips, %d complete pairs**: female %d, male %d. `_b`, `_c` are other generations of the same clip name." % (
                 len(clips), pairs, sum(1 for r in clips.values() if "female" in r), sum(1 for r in clips.values() if "male" in r)), ""]
    for category in CATEGORIES:
        ids = sorted(by_category[category], key=lambda c: (clips[c]["priority"] or "P9", c))
        lines += ["## %s (%d)" % (category, len(ids)), "", "| Clip | F | M | Seconds | Loops | Travels | Priority | Use |", "|---|---|---|---|---|---|---|---|"]
        for cid in ids:
            row = clips[cid]
            rows = [row[f] for f in FIGURES if f in row]
            loops = "yes" if all(r["loops"] for r in rows) else ("no" if not any(r["loops"] for r in rows) else "one")
            travel = max(r["travel_hips_per_s"] for r in rows)
            name = "[`%s`](sheets/clips/%s.png)" % (cid, cid) if (BANK / "sheets" / "clips" / (cid + ".png")).exists() else "`%s`" % cid
            lines.append("| %s | %s | %s | %s | %s | %s | %s | %s |" % (
                name, "x" if "female" in row else "", "x" if "male" in row else "", seconds(row), loops, ("%.2f" % travel) if travel >= 0.05 else "", row["priority"], row["use"]))
        lines.append("")
    (BANK / "CATALOG.md").write_text("\n".join(lines))
    print("[tripo_bank_catalog] %d clips, %d pairs: %s" % (len(clips), pairs, ", ".join("%s %d" % (c, len(by_category[c])) for c in CATEGORIES)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
