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

With the female's read-back, a model whose grip she has apart (more than 0.1 mm or 0.01 of a degree in the reference's units)
gets `held_like.figures.female` (the same fields); the male's is the shared one.
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
    out = {"weapon": family_ref, "scale": r["rel_scale"], "pos": r["rel_pos"], "quat": r["rel_quat"]}
    if f is not None:
        apart = abs(f["rel_scale"] / r["rel_scale"] - 1.0) > 1e-3 \
            or max(abs(x - y) for x, y in zip(f["rel_pos"], r["rel_pos"])) > 1e-4 \
            or max(min(abs(x - y), abs(x + y)) for x, y in zip(f["rel_quat"], r["rel_quat"])) > 1e-4
        if apart:
            out["figures"] = {"female": {"scale": f["rel_scale"], "pos": f["rel_pos"], "quat": f["rel_quat"]}}
    return out


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
              f"{'  + its own female grip' if 'figures' in row['model']['held_like'] else ''}")
        if dry:
            continue
        os.makedirs(os.path.dirname(os.path.join(ROOT, dst_rel)), exist_ok=True)
        shutil.copyfile(src, os.path.join(ROOT, dst_rel))
        with open(path, "w") as f:
            json.dump(row, f, indent=2)
            f.write("\n")


if __name__ == "__main__":
    main()
