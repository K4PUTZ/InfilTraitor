"""MOVEMENT_MASTER_PLAN §11.6 step 2 — a hold family's read-back written into its WEAPON ROWS (`weapons/<id>.json`).

Director, 2026-11-17: "vamos ter a família que usa a mesma postura, tipo empunhadura de pistola, e dentro dela variações de modelo
que são armas individuais. Todas vão usar o mesmo mecanismo da pistola normal, com algumas variações de stats [...] vamos precisar
acompanhar cada uma em uma ficha". So every model of the family is a row of its own, held like the family's reference
(`held_as`), its model placed by ONE product on the reference's placement at every stop of the family's timeline:
`model.held_like` = {weapon, scale, pos, quat}, the model's own glTF frame in the reference model's glTF frame, read off the
Director's lab file by `family_lab.py readback`. Its `muzzle` is the read-back's proposal (the centre of the foremost vertices
along the barrel, the model's own frame) and its size is certified the day of the read-back.

A row that does not exist yet is CREATED from the template its entry names (the shot numbers copied: GAMEPLAY-01 sets each
weapon's own), with the entry's tags and `gameplay`; a row that exists keeps every field but `held_as` and `model`. The model is
copied into `ASSETS/props/<id>/<id>.glb` (the game's import tree; the sources may sit under a `.gdignore`).

  python3 tools/asset_generation/weapons/family_rows.py <male readback .json> [--female <female readback .json>] [--dry]
  python3 tools/asset_generation/weapons/family_rows.py <male readback .json> --attachments [--dry]     -> attachments/<id>.json

`held_like.figures` names each figure's grip explicitly (Director, 2026-11-17): the male's read-back, and the female's with
`--female`; a figure left out is warned at load (`WeaponDef`), never filled from the other.
"""
import json, os, shutil, sys, datetime

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
WEAPONS = os.path.join(ROOT, "weapons")

PACK = {"Metal": "steel_dark", "Black": "rubber", "Black2": "rubber", "LightMetal": "metal", "DarkMetal": "steel_dark",
        "Wood": "wood", "DarkWood": "wood", "Grey": "painted_metal"}
SCIFI = {"White": "plastic", "Black": "rubber", "Grey": "painted_metal", "Main": "painted_metal"}

# lab name -> (row id, template row, extra tags, gameplay overrides, surface materials)
H1 = {
    "02 Pistol": ("pistol_compact", "pistol", [], {}, PACK),
    "03 Pistol-J3i9KDQ3kt": ("pistol_service", "pistol", [], {}, PACK),
    "04 Pistol-Z7aOjJu583": ("pistol_tactical", "pistol", [], {}, PACK),
    "05 Revolver": ("revolver", "revolver", [], {}, PACK),
    "06 Revolver-9C26wSpMS0": ("revolver_snub", "revolver", [], {}, PACK),
    "07 Revolver-XrnLUz6kQj": ("revolver_long", "revolver", [], {}, PACK),
    "08 Taser (Tripo)": ("taser", "pistol", ["stun", "nonlethal"], {"class": "stun", "projectile": "probe"},
                         {"Body": "rubber", "Cartridge": "plastic", "Muzzle": "rubber", "Contacts": "metal"}),
    "09 Hand crossbow": ("hand_crossbow", "pistol", ["dart", "silent"], {"class": "dart", "projectile": "dart"},
                         {"Body": "rubber", "Limbs": "steel_dark", "Cams": "steel_dark", "String": "fabric", "Trigger": "metal",
                          "DartShaft": "metal", "DartTail": "plastic", "DartNock": "plastic"}),
    "10 Flare gun": ("flare_gun", "pistol", ["flare"], {"class": "flare", "projectile": "flare"}, {"Red": "plastic", "Black": "rubber"}),
    "11 Scifi_Pistol-TuHM3CURcC": ("scifi_pistol_a", "pistol", ["scifi"], {}, SCIFI),
    "12 Scifi_Pistol-U0Q1BrKL1y": ("scifi_pistol_b", "pistol", ["scifi"], {}, SCIFI),
    "13 Scifi_Pistol-uw4B33Mm0d": ("scifi_pistol_c", "pistol", ["scifi"], {}, SCIFI),
    "14 Ray gun": ("ray_gun", "pistol", ["scifi"], {}, {"Main2": "painted_metal", "Muzzle": "metal", "Main": "painted_metal", "Detail": "plastic"}),
    "15 Grapple launcher (Tripo)": ("grapple_gun", "pistol", ["device", "grapple"], {"class": "device", "projectile": "hook"},
                                    {"Body": "rubber", "Drum": "fabric", "Hook": "metal"}),
}
NO_DAMAGE = ("stun", "dart", "flare", "device")    # these leave no bullet in a wall: their effect is GAMEPLAY-01's


def held_like(family_ref, r, f):
    """Both figures EXPLICIT (Director, 2026-11-17): each its own read-back, none inherited."""
    def grip(x):
        return {"scale": x["rel_scale"], "pos": x["rel_pos"], "quat": x["rel_quat"]}
    figs = {"male": grip(r)}
    if f is not None:
        figs["female"] = grip(f)
    return {"weapon": family_ref, "figures": figs}


def main():
    argv = sys.argv[1:]
    dry = "--dry" in argv
    fem = None
    if "--female" in argv:
        fem = json.load(open(argv[argv.index("--female") + 1]))["models"]
        argv = argv[:argv.index("--female")] + argv[argv.index("--female") + 2:]
    a = [x for x in argv if not x.startswith("--")]
    rb = json.load(open(a[0]))
    ref = rb["models"][rb["reference"]]
    family_ref = "pistol"
    today = datetime.date.today().isoformat()
    for lab, r in rb["models"].items():
        if r["role"] in ("reference", "muzzle"):
            continue
        if lab not in H1:
            print(f"[family_rows] ERROR: '{lab}' has no row entry"); sys.exit(1)
        wid, tmpl, tags, gp, surf = H1[lab]
        path = os.path.join(WEAPONS, wid + ".json")
        if os.path.exists(path):
            row = json.load(open(path))
        else:
            row = json.load(open(os.path.join(WEAPONS, tmpl + ".json")))
            row["id"] = wid
            row["tags"] = [t for t in row.get("tags", []) if t not in ("pistol", "revolver")] + [tmpl] + tags
            row["gameplay"] = dict(row.get("gameplay", {}), **gp)
            if gp.get("class") in NO_DAMAGE:
                row["destroy_multiplier"] = 0.0
                row["punch"] = 0.0
                row["soot_radius"] = 0
                row["tags"] = [t for t in row["tags"] if t != "firearm"]
        src = os.path.join(ROOT, r["source"])
        dst_rel = f"ASSETS/props/{wid}/{wid}.glb"
        row["held_as"] = "pistol"
        row["model"] = {
            "path": "res://" + dst_rel,
            "surface_materials": surf,
            "held_like": held_like(family_ref, r, fem.get(lab) if fem else None),
            "size_certified": today,
            "muzzle": r["muzzle_proposed"],
        }
        print(f"[family_rows] {wid:16s} <- {lab:30s} x{r['rel_scale']:.4f} turn {r['rel_turn_deg']:.2f}  muzzle {r['muzzle_proposed']}"
              f"  figures {sorted(row['model']['held_like']['figures'])}")
        if dry:
            continue
        os.makedirs(os.path.dirname(os.path.join(ROOT, dst_rel)), exist_ok=True)
        shutil.copyfile(src, os.path.join(ROOT, dst_rel))
        with open(path, "w") as f:
            json.dump(row, f, indent=2)
            f.write("\n")


if __name__ == "__main__" and "--attachments" not in sys.argv:
    main()


# ---- attachments (Director, 2026-11-17: the suppressor is a mountable accessory, on the bullet pistols only) ----------------------------------
BULLET_PISTOLS = ["pistol", "pistol_compact", "pistol_service", "pistol_tactical"]
SUPPRESSOR_MATS = {"M_PCL_Flat_Black_Lighter": "rubber", "M_PCL_Flat_Black": "steel_dark", "M_PCL_Flat_Grey_Dark": "steel_dark"}
ATTACHMENTS = {
    "16 Suppressor-QWfBIqy0VW": "suppressor_a",
    "17 Suppressor-VLiLj3j1tS": "suppressor_b",
}


def attachment_row(aid, r, ref_muzzle, source, surface_materials, today):
    """The row of a muzzle attachment read off the lab (`r`: its read-back, held by the carrier pistol): its mount relative to the
    reference's muzzle (so it sits on any family pistol's own muzzle), its own front as the new muzzle."""
    return {
        "id": aid, "kind": "muzzle", "fits": BULLET_PISTOLS,
        "gameplay": {"stealth": "suppressed"},
        "model": {
            "path": f"res://ASSETS/props/{aid}/{aid}.glb",
            "surface_materials": surface_materials,
            "mount": {"on": "pistol", "scale": r["rel_scale"], "quat": r["rel_quat"],
                      "pos": [round(a - b, 5) for a, b in zip(r["rel_pos"], ref_muzzle)]},
            "muzzle": r["muzzle_proposed"],
            "size_certified": today,
        },
    }


def write_attachments(rb, dry):
    ref_muzzle = json.load(open(os.path.join(WEAPONS, "pistol.json")))["model"]["muzzle"]
    today = datetime.date.today().isoformat()
    out = os.path.join(ROOT, "attachments")
    os.makedirs(out, exist_ok=True)
    for lab, aid in ATTACHMENTS.items():
        r = rb["models"][lab]
        row = attachment_row(aid, r, ref_muzzle, r["source"], SUPPRESSOR_MATS, today)
        print(f"[family_rows] {aid:16s} <- {lab:30s} x{r['rel_scale']:.4f} mount {row['model']['mount']['pos']} muzzle {r['muzzle_proposed']}")
        if dry:
            continue
        dst = os.path.join(ROOT, f"ASSETS/props/{aid}/{aid}.glb")
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(os.path.join(ROOT, r["source"]), dst)
        with open(os.path.join(out, aid + ".json"), "w") as f:
            json.dump(row, f, indent=2)
            f.write("\n")


if __name__ == "__main__" and "--attachments" in sys.argv:
    write_attachments(json.load(open([x for x in sys.argv[1:] if not x.startswith("--")][0])), "--dry" in sys.argv)
