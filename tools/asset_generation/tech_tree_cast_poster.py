# Proposal diagram: who introduces each tech-tree node and which enemy unit fields its counter. Generator: python3 tools/asset_generation/tech_tree_cast_poster.py DIAGRAMS/ELENCO_ARVORE.png
import sys
from PIL import Image, ImageDraw, ImageFont
OUT = sys.argv[1]
F = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FN = "/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf"
FR = "/System/Library/Fonts/Supplemental/Arial Narrow.ttf"
f = lambda s, p=F: ImageFont.truetype(p, s)
rgb = lambda h: tuple(int(h.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
FAC = [("FID", "#2E6FD8"), ("CALM WATERS", "#B3121E"), ("BUNSEN BURNERS", "#F08A24"), ("CORPORATION", "#6B2FA0")]
LANES = ["EYE", "HAND", "WALL"]
# per faction: lane -> (L1 specialist, L2 introducer, L3 introducer, counter unit, [3 counters])
D = {
 0: [("Cairn · K9 handler\ntrail reading", "Urn · evidence clerk\npredictive", "Captain w/ prototype\ntactical analysis",
      "FORENSIC TECH", ["decoy trails", "patrols re-rolled", "analysis jammer"]),
     ("Pyre · taser officer\ntaser", "Urn · evidence clerk\nsuppressor", "Captain w/ prototype\nsonic weapon",
      "RIOT OFFICER", ["insulated vest", "suppressor detector", "ear protection"]),
     ("Vault · dispatcher\nradio spoof", "Urn · evidence clerk\nlockpicks + zip ties", "Captain w/ prototype\nradio scrambler",
      "RADIO SERGEANT", ["analogue comms", "checks the downed", "foot runners"])],
 1: [("Ace Skyler · drone pilot\nscout drone", "Tank Mercer · armoury\nthermal module", "Captain w/ prototype\nX-ray module",
      "COUNTER-DRONE CREW", ["anti-drone gun", "insulation suit", "lead-lined rooms"]),
     ("Rex Hawke · marksman\nsuppressed rifle", "Tank Mercer · armoury\npulse carbine", "Captain w/ prototype\nlaser",
      "SPOTTER + HEAVY", ["counter-sniper", "insulated armour", "reflective plating"]),
     ("Chip Voltz · sensors\nEMP charge", "Tank Mercer · armoury\nsilent boots + vest", "Captain w/ prototype\nexoskeleton",
      "HARDENED TECH", ["hardened electronics", "pressure plates", "heavy pairs"])],
 2: [("Vespers · lookout\nfirework lure", "Tithe · chop shop\nmotion module", "Captain w/ prototype\nstreet eyes",
      "SENTRY", ["ignores lone noise", "still sentries", "informant hunts"]),
     ("Censer · chemist\ndart launcher", "Censer's lab · recipe\ngas + smoke", "Captain w/ prototype\nincendiary",
      "GAS-MASK COOK", ["antidote", "respirator", "foam crew"]),
     ("Sexton · trapper\ntripwire flash", "Tithe · chop shop\ngetaway bike", "Captain w/ prototype\nbreaching charge",
      "ROAD CREW", ["doorways swept", "roadblocks, spikes", "reinforced doors"])],
 3: [("Ledger · hacker\ncamera loop", "Margin · R&D floor\nWiFi module", "Captain w/ prototype\nspectral module",
      "FEED MONITOR", ["guards check feeds", "shielded rooms", "multi-spectrum camo"]),
     ("Hedge · envoy (seen)\nshadow generator", "Hedge · envoy, lap 2\nLED coat", "Captain w/ prototype\nplasma",
      "FLOODLIGHT TEAM", ["flares, floodlights", "high-watch zones", "heavy plating"]),
     ("Escrow · fixer\nbribe", "Margin · R&D floor\nforged credentials", "Captain w/ prototype\nmaster keycard",
      "COMPLIANCE OFFICER", ["incorruptible captain", "checkpoint check", "keypad + guard"])],
}
W, H = 3400, 1500
im = Image.new("RGB", (W, H), (22, 23, 27)); d = ImageDraw.Draw(im)
d.text((40, 28), "INFILTRAITOR · who introduces each node, and who fields its counter — ratified by the Director 2026-10-24", fill=(240, 240, 240), font=f(40))
d.text((40, 82), "L1 = a named specialist (lap 1)  ·  L2 = the store's keeper (needs access) or the envoy  ·  L3 = a Freelance captain carrying the prototype, researched by Zest  ·  red = the counter unit, three gear stages",
       fill=(185, 185, 190), font=f(24, FR))
gx0, gy0 = 200, 140
colw = (W - gx0 - 40) / 4; lanew = colw / 3
rows = [("L1", "specialist"), ("L2", "store / envoy"), ("L3", "Freelance"), ("COUNTER", "enemy unit")]
rh = [190, 190, 190, 330]
ys = [gy0 + 100]
for h in rh[:-1]: ys.append(ys[-1] + h)
for i, (a, b) in enumerate(rows):
    d.text((40, ys[i] + 40), a, fill=(240, 240, 240), font=f(28)); d.text((40, ys[i] + 80), b, fill=(170, 170, 175), font=f(20, FR))
for fi, (nm, col) in enumerate(FAC):
    cx = gx0 + fi * colw
    d.rectangle([cx + 6, gy0, cx + colw - 6, gy0 + 54], fill=rgb(col))
    d.text((cx + colw / 2, gy0 + 27), nm, fill=(250, 250, 250), font=f(28), anchor="mm")
    for la in range(3):
        lx = cx + la * lanew
        d.text((lx + lanew / 2, gy0 + 78), LANES[la], fill=(200, 200, 205), font=f(22, FN), anchor="mm")
        e = D[fi][la]
        for lv in range(3):
            bx, by = lx + 8, ys[lv]; bw, bh = lanew - 16, rh[lv] - 24
            d.rounded_rectangle([bx, by, bx + bw, by + bh], 10, fill=(36, 37, 44), outline=rgb(col), width=3)
            who, node = e[lv].split("\n")
            d.multiline_text((bx + 10, by + 10), who.replace(" · ", "\n"), fill=(235, 220, 160), font=f(20, FN), spacing=4)
            d.text((bx + 10, by + bh - 36), "→ " + node, fill=(245, 245, 245), font=f(20, FR))
        bx, by = lx + 8, ys[3]; bw, bh = lanew - 16, rh[3] - 24
        d.rounded_rectangle([bx, by, bx + bw, by + bh], 10, fill=(48, 30, 32), outline=(200, 90, 90), width=3)
        d.multiline_text((bx + 10, by + 10), e[3].replace(" + ", "\n+ "), fill=(245, 170, 170), font=f(21, FN))
        for k, c in enumerate(e[4]):
            d.text((bx + 10, by + 110 + k * 62), f"stage {k + 1}", fill=(170, 130, 130), font=f(17, FR))
            d.text((bx + 10, by + 132 + k * 62), c, fill=(235, 200, 200), font=f(20, FR))
ry = ys[3] + rh[3] + 10
for k, r in enumerate([
    "UNLOCK never needs a kill: see it used, survive it, or knock the author out and search him. Every introducer is SEEN one stage before he matters (§11.4).",
    "COUNTER: the author's faction fields it first (it knows its own tech's weakness), the others a stage later; the Agent's most-used technique first; a counter weakens, never nullifies.",
    "MODELS: 12 counter units x 3 gear stages are slot pieces on the faction's guard base (one skeleton), not 36 new characters. New cast: 4 store keepers (Urn, Tank Mercer, Tithe, Margin) + Zest."]):
    d.text((40, ry + k * 34), r, fill=(200, 200, 205), font=f(22, FR))
im.save(OUT); print("ok")
