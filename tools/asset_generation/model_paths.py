"""Where every model lives under ASSETS/MODELS: the one place that knows (the Director, 2026-11-19).

A tool asks here instead of typing a path, so the next reorganisation is an edit of this file, not a hunt through the tools.
The game's twin is `godot/scripts/systems/model_paths.gd` (ModelPaths); the two must agree, and `--check` proves this file's
folders exist.

The layout: one folder per character, the stages inside it.

    ASSETS/MODELS/
      actors/
        agent/<figure>/        the Agent, figure = female | male
          source/              Tripo's downloads, untouched (Godot ignores it)
          base/                the A / T base .blend files, open while animating (ignored)
          work/                the working .blend files: fits, corrective frames, sequences, pose labs (ignored)
          game/                what the game loads: AGENT_<FIG>[_LIGHT].glb and the clean bases (imported)
          textures/            the painted maps and masters, FaceUV params (imported)
        agent/shared/          what both figures use: COAT_BASE, AGENT_SURFACE.json; source/ = shared downloads (ignored)
        shared/detail/         the tileable grain maps every actor's surface reads
        enemies/<FACTION>/<character>/   the same stages; skins/<skin>/ for a character's variations
      props/                   Tripo's prop and gadget generations, raw and split (ignored)
      history/                 earlier steps, kept as record (ignored)

    python3 model_paths.py --sh <figure>        shell variables for one Agent figure (eval in the build scripts)
    python3 model_paths.py --check              every folder above exists
"""
import os
import sys

MODELS = "ASSETS/MODELS"
STAGES = ("source", "base", "work", "game", "textures")
FIGURES = ("female", "male")


def _join(*parts: str) -> str:
    return "/".join(p.strip("/") for p in parts if p)


def agent(figure: str, stage: str, name: str = "") -> str:
    """an Agent figure's file (or folder when `name` is empty); `figure` in any case"""
    fig = figure.lower()
    if fig not in FIGURES or stage not in STAGES:
        raise ValueError(f"[model_paths] agent({figure!r}, {stage!r})")
    return _join(MODELS, "actors/agent", fig, stage, name)


def agent_shared(name: str = "") -> str:
    """what both Agent figures use (COAT_BASE, AGENT_SURFACE.json); source/<file> for shared downloads"""
    return _join(MODELS, "actors/agent/shared", name)


def detail(name: str = "") -> str:
    """the tileable grain maps (cotton, denim, leather...)"""
    return _join(MODELS, "actors/shared/detail", name)


def enemy(faction: str, character: str, stage: str, name: str = "") -> str:
    """an enemy's file: faction = FID | CALM_WATERS | BUNSEN | CORP, character = e.g. guard_male"""
    if stage not in STAGES and not stage.startswith("skins"):
        raise ValueError(f"[model_paths] enemy stage {stage!r}")
    return _join(MODELS, "actors/enemies", faction, character, stage, name)


def props(name: str = "") -> str:
    """Tripo's prop generations (tripo_props<n>_split / _zoned, hand_crossbow, the drone)"""
    return _join(MODELS, "props", name)


def history(name: str = "") -> str:
    return _join(MODELS, "history", name)


def res(path: str) -> str:
    """the same path as Godot names it"""
    return "res://" + path


def _sh(figure: str) -> str:
    v = {"SRC": agent(figure, "source"), "BASE": agent(figure, "base"), "WORK": agent(figure, "work"),
         "GAME": agent(figure, "game"), "TEX": agent(figure, "textures"), "SHARED": agent_shared(), "DETAIL": detail()}
    return "\n".join(f"{k}={val}" for k, val in v.items())


def _check(root: str) -> int:
    dirs = [agent(f, s) for f in FIGURES for s in STAGES] + [agent_shared(), detail(), props(), history()]
    missing = [d for d in dirs if not os.path.isdir(os.path.join(root, d))]
    for d in missing:
        print(f"[model_paths] missing {d}")
    return 1 if missing else 0


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["--sh"] and len(a) == 2:
        print(_sh(a[1]))
    elif a[:1] == ["--check"]:
        sys.exit(_check(os.getcwd()))
    else:
        print(__doc__)
        sys.exit(2)
