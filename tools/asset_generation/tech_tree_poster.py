# tech_tree_poster.py — the per-faction tech and skill tree (DESIGN_MASTER_PLAN §15, structure ratified 2026-10-23): four factions x three branches
# (EYE detect / HAND threat / WALL control) x three levels (lap 1, lap 2, Freelance), each node with its author, its §10 class, lethal or not, and
# the enemy counter; the track every character shares; the four backgrounds. The node data lives in this file (N, BG) — edit it with the canon.
# Usage: python3 tools/asset_generation/tech_tree_poster.py DIAGRAMS/ARVORE_TECNOLOGICA.png   (system Python with PIL; macOS Arial fonts)
import sys
from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1]
F = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FN = "/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf"
FR = "/System/Library/Fonts/Supplemental/Arial Narrow.ttf"
f = lambda s, p=F: ImageFont.truetype(p, s)
rgb = lambda h: tuple(int(h.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))

FAC = [
    ("FID", "Information", "#2E6FD8", "Lifelong policeman"),
    ("CALM WATERS", "Technology & force", "#B3121E", "Army veteran"),
    ("BUNSEN BURNERS", "Numbers & improvisation", "#F08A24", "Former biker"),
    ("CORPORATION", "Money & access", "#6B2FA0", "Former private security"),
]
LANES = ["EYE · detect", "HAND · threat", "WALL · control"]
LEVELS = [("L1 · LAP 1", "meet the specialist on that turf"), ("L2 · LAP 2", "the faction's store (access); or the envoy"),
          ("L3 · FREELANCE", "research; the endgame converges")]
# (name, §10 class, author, non-lethal, enemy counter) per faction -> lane -> level
N = {
 0: [[("Trail reading", "mask module · his own trail", "Cairn (K9)", 1, "decoy trails"),
      ("Predictive", "visor T5", "evidence room", 1, "patrols re-rolled"),
      ("Tactical analysis", "visor T5", "research", 1, "analysis jammers")],
     [("Taser", "weapon T2 · shock", "Pyre", 1, "insulated vests"),
      ("Suppressor", "weapon T2 · pistol", "evidence room", 0, "suppressor detector §11.3"),
      ("Sonic weapon", "weapon T6", "research", 1, "ear protection")],
     [("Radio spoof", "gadget · new", "Vault", 1, "analogue comms §11.3"),
      ("Lockpicks + zip ties", "gadgets", "evidence room", 1, "patrols check the downed"),
      ("Radio scrambler", "gadget T5", "research", 1, "runners on foot")]],
 1: [[("Scout drone", "gadget T4", "Ace Skyler", 1, "anti-drone guns"),
      ("Thermal", "mask module · T3", "armoury", 1, "insulation suits §11.3"),
      ("X-ray", "mask module · T4", "research", 1, "lead-lined rooms")],
     [("Suppressed rifle", "weapon T3", "Rex Hawke", 0, "counter-snipers"),
      ("Pulse carbine", "weapon · new", "armoury", 1, "insulated armour"),
      ("Laser", "weapon T4", "research", 0, "reflective plating")],
     [("EMP charge", "gadget T3", "Chip Voltz", 1, "hardened electronics"),
      ("Silent boots + vest", "armour T3", "armoury", 1, "pressure plates"),
      ("Exoskeleton", "armour T5 · on the battery", "research", 1, "heavy pairs")]],
 2: [[("Firework lure", "gadget T4 · radius, alert +1", "Vespers", 1, "lone noises ignored"),
      ("Motion vision", "mask module · T3", "chop shop", 1, "still sentries"),
      ("Street eyes", "lookouts · new", "research", 1, "informant hunts")],
     [("Dart launcher", "weapon T3", "Censer", 1, "antidote, respirator §11.3"),
      ("Gas + smoke", "gadgets T2", "lab (recipe)", 1, "respirators"),
      ("Incendiary", "gadget T3", "research", 0, "foam crews")],
     [("Tripwire flash", "gadget T2", "Sexton", 1, "doorways swept"),
      ("Getaway bike", "extraction points only", "chop shop", 1, "roadblocks, spikes"),
      ("Breaching charge", "gadget T3", "research", 0, "reinforced doors")]],
 3: [[("Camera loop", "gadget T5", "Ledger", 1, "guards check feeds"),
      ("WiFi vision", "mask module · T4", "R&D floor", 1, "shielded rooms"),
      ("Spectral", "mask module · T6", "research", 1, "multi-spectrum camo")],
     [("Shadow generator", "gadget · 1 charge (T6 at L3)", "Hedge (seen)", 1, "flares, floodlights"),
      ("LED coat", "armour T7 · adaptive", "Hedge, lap 2", 1, "highly watched zones"),
      ("Plasma", "weapon T5", "R&D research", 0, "heavy plating")],
     [("Bribe", "money · new", "Escrow", 1, "incorruptible captains"),
      ("Forged credentials", "access · 1 faction, 1 mission", "Escrow / R&D", 1, "checkpoint checks"),
      ("Master keycard", "gadget · new", "research", 1, "keypad + guard")]],
}
BG = [
    ("Lifelong policeman · FID", "Procedure: sees each radio guard's check-in countdown", "Interrogate: a knocked-out guard gives one intel (rounds, a code)"),
    ("Army veteran · Calm Waters", "Discipline: armour's stealth penalty one step lower", "Suppressing fire: pins a guard in cover for a turn, no hit"),
    ("Former biker · Bunsen Burners", "Road sense: +1 GU when sprinting on open ground", "Improvise: one smoke or flash per mission, from scrap"),
    ("Former private security · Corporation", "Systems: sees camera cones and blind spots", "Keycard spoof: opens one electronic door per mission"),
]

W, H = 3400, 1680
im = Image.new("RGB", (W, H), (22, 23, 27))
d = ImageDraw.Draw(im)
d.text((40, 28), "INFILTRAITOR · tech & skill tree per faction — structure ratified 2026-10-23 (DESIGN §15), built from §10", fill=(240, 240, 240), font=f(40))
d.text((40, 82), "Each node: the technique the Agent takes from its AUTHOR · its §10 class · the counter the factions field next (Phoenix Point co-evolution)", fill=(185, 185, 190), font=f(26, FR))

# universal track
y0 = 130
d.rounded_rectangle([40, y0, W - 40, y0 + 120], 14, fill=(34, 35, 41), outline=(90, 92, 100), width=2)
d.text((60, y0 + 14), "EVERY CHARACTER", fill=(240, 240, 240), font=f(26))
steps = [("START (crude, one-shot)", "pistol · chokehold / neck snap · stones · alarm clock · spray can · chloroform · balaclava · mustard coat"),
         ("OFFICIAL WORK", "the hat-MASK from the club's assassin: base mode night vision (T2); modules from the trees"),
         ("UPGRADE (when: open)", "the pack BATTERY: one charge for mask modules + LED coat"),
         ("LAP 2", "the LED COAT from Hedge: wardrobe of every uniform held + the cloak")]
x = 60
for i, (t, s) in enumerate(steps):
    d.text((x, y0 + 50), t, fill=(250, 200, 90), font=f(22))
    d.text((x, y0 + 80), s, fill=(215, 215, 220), font=f(19, FR))
    x += 830
    if i < 3:
        d.text((x - 46, y0 + 58), "→", fill=(200, 200, 200), font=f(40))

# grid
gx0, gy0 = 260, y0 + 150
colw = (W - gx0 - 40) / 4
lanew = colw / 3
rowh = 300
for li, (lt, ls) in enumerate(LEVELS):
    yy = gy0 + 110 + li * rowh
    d.text((40, yy + 40), lt, fill=(240, 240, 240), font=f(26))
    for k, line in enumerate(ls.split("; ")):
        d.multiline_text((40, yy + 80 + k * 26), line, fill=(170, 170, 175), font=f(19, FR))
for fi, (name, axis, col, bg) in enumerate(FAC):
    cx = gx0 + fi * colw
    d.rectangle([cx + 6, gy0, cx + colw - 6, gy0 + 54], fill=rgb(col))
    d.text((cx + colw / 2, gy0 + 27), f"{name} · {axis}", fill=(250, 250, 250), font=f(26), anchor="mm")
    for la in range(3):
        lx = cx + la * lanew
        d.text((lx + lanew / 2, gy0 + 82), LANES[la], fill=(200, 200, 205), font=f(20, FN), anchor="mm")
        for lv in range(3):
            nm, cl, au, nl, ctr = N[fi][la][lv]
            bx, by = lx + 10, gy0 + 110 + lv * rowh
            bw, bh = lanew - 20, rowh - 40
            d.rounded_rectangle([bx, by, bx + bw, by + bh], 12, fill=(36, 37, 44), outline=rgb(col), width=3)
            d.text((bx + 12, by + 12), nm, fill=(245, 245, 245), font=f(23, FN))
            d.text((bx + 12, by + 48), cl, fill=(190, 190, 198), font=f(19, FR))
            d.text((bx + 12, by + 78), "author: " + au, fill=(220, 210, 160), font=f(19, FR))
            tag, tc = ("NON-LETHAL", (60, 170, 90)) if nl else ("LETHAL", (205, 60, 60))
            d.rounded_rectangle([bx + 12, by + 112, bx + 12 + (130 if nl else 90), by + 140], 6, fill=tc)
            d.text((bx + 20, by + 115), tag, fill=(250, 250, 250), font=f(18, FN))
            d.line([bx + 12, by + 160, bx + bw - 12, by + 160], fill=(80, 80, 90), width=1)
            d.text((bx + 12, by + 172), "enemy counter:", fill=(200, 120, 120), font=f(17, FR))
            d.text((bx + 12, by + 198), ctr, fill=(235, 160, 160), font=f(19, FN))
            if lv < 2:
                ax = bx + bw / 2
                d.line([ax, by + bh, ax, by + bh + 40], fill=rgb(col), width=3)

# backgrounds
by0 = gy0 + 110 + 3 * rowh + 10
d.text((40, by0), "BACKGROUNDS (the class, stated in the deposition): ONE of its faction's L1 nodes from the start, plus a passive and an active ability",
       fill=(240, 240, 240), font=f(26))
for i, (t, p, a) in enumerate(BG):
    cx = gx0 + [0, 1, 2, 3][i] * colw
    col = FAC[i][2]
    d.rounded_rectangle([cx + 10, by0 + 44, cx + colw - 10, by0 + 200], 12, fill=(36, 37, 44), outline=rgb(col), width=3)
    d.text((cx + 24, by0 + 56), t, fill=(245, 245, 245), font=f(23, FN))
    d.text((cx + 24, by0 + 96), "passive · " + p, fill=(210, 210, 215), font=f(19, FR))
    d.text((cx + 24, by0 + 128), "active · " + a, fill=(210, 210, 215), font=f(19, FR))
    d.text((cx + 24, by0 + 160), "picks ONE own L1 node at the deposition", fill=(250, 200, 90), font=f(19, FN))
# rules
ry = by0 + 222
rules = ["UNLOCK: meet the author (see it used, survive it, or knock him out and search him) — never a kill. Stores need that faction's ACCESS.",
         "ENEMY SIDE: every node has a counter; the factions field it in the next stage, the Agent's most-used technique first, always telegraphed (§11.4); a counter weakens, never nullifies.",
         "BALANCE (adopted): same lanes and levels per faction; non-lethal options in every L1 row; charges on actives and comms gadgets; no kamikaze drone, no acid weapon."]
for k, r in enumerate(rules):
    d.text((40, ry + k * 34), r, fill=(200, 200, 205), font=f(22, FR))
im.save(OUT)
print("ok", OUT)
