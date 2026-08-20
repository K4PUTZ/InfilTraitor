# BAKE ORDER — the held weapon (rifle, pistol)

**Raised 2026-08-20**, when the Director asked for the held weapon to follow the
1/2/3 key selection and the code half was built. This file is the executable
request: it can be run on another machine with no other context.

**Read [`docs/pipelines/character_bake_pipeline.md`](../docs/pipelines/character_bake_pipeline.md)
first** for the stage-by-stage mechanism, every env var, and the traps common to
all character bakes. This file adds the weapon-specific ones.

---

## What is already done, and what is missing

| Piece | State |
|---|---|
| Keys 1/2/3/4 select the weapon | ✅ `ui_weapon_rifle/pistol/shotgun`, 4 joins G on `ui_grenade_mode` |
| The BALLISTICS switch | ✅ punch, breach threshold, blowout, penetration, pre-cook — all re-key on the new weapon |
| The runtime seam for the FIGURE | ✅ `AgentSprite.weapon` — a bake-directory suffix, in every path and every cache key |
| The export carries the weapon | ✅ `p3_posture_export.py` `WEAPON_SUFFIX` (`P3_WEAPON` existed; nothing carried it into the output path) |
| **The rifle's and pistol's posed frames** | ❌ **this order** |

So today: pressing `1` genuinely arms the agent with an assault rifle — it fires
one LINE round, breaches concrete in both slices, punches sheet metal — and the
figure on screen still holds a shotgun. `set_weapon_bake()` says so once, by
name, and keeps drawing rather than failing: the mechanic is finished and
testable, the art is a Blender run that has not happened.

> **The bakes are not in git.** `.gitignore:69` excludes
> `ASSETS/ISOMETRIC/source_assets/*`, so every PNG and `anchor.json` named here is
> a generated artifact that exists only on the machine that made it. A fresh
> clone has the code, the gates and this order — and no frames.

---

## The directory contract, which is the whole reason this file exists

`AgentSprite` assembles a posture root as

    agent_frames<family><weapon><grip>/<posture>/

and a layer root as

    agent_<layer><family><weapon><grip>/<group>/

**In that order.** `p3_posture_export.py::out_family()` now assembles the same
string the same way. A directory built in any other order is a directory the game
will not look in, and the failure is silent in the worst way — `_ensure_set()`
misses, `set_weapon_bake()` reverts, and the figure keeps the shotgun while the
log says the bake is missing even though the files are on disk.

`shotgun` and `lowered` earn **no** suffix, because they are what shipped and
every posed GLB is named `agent_posed_shotgun_lowered*`. Everything else earns
one. Expected targets:

| Weapon | Grip | Directory |
|---|---|---|
| shotgun | lowered | `agent_frames/` ✅ exists |
| shotgun | aimed | `agent_frames_aimed/` ✅ exists |
| pistol | lowered | `agent_frames_pistol/` ❌ |
| pistol | aimed | `agent_frames_pistol_aimed/` ❌ |
| rifle | lowered | `agent_frames_rifle/` ❌ |
| rifle | aimed | `agent_frames_rifle_aimed/` ❌ |

Plus the matching `agent_head_*` and `agent_hat_*` layer directories for the two
LAYERED postures (standing, crouch) — see the character-layers order for why each
posture needs its own set.

---

## A. The pistol — a grip solve already exists

`p2_grip_spike.ORDER` already carries `("pistol", "lowered")`, `("pistol",
"ready")` and `("pistol", "aimed")`, and `WEAPONS["pistol"]` already resolves a
model. So the pistol is a RUN, not an authoring job:

```bash
P3_WEAPON=pistol P3_GRIP=lowered blender -b -P tools/asset_generation/p3_posture_export.py
P3_WEAPON=pistol P3_GRIP=aimed   blender -b -P tools/asset_generation/p3_posture_export.py
```

then stage 3 (the windowed Godot frame bake) for each, exactly as the pipeline
doc describes. Check before trusting the result:

1. The output landed in `agent_frames_pistol[_aimed]/`, **not** over
   `agent_frames[_aimed]/`. This is the collision `WEAPON_SUFFIX` was added to
   prevent, and the pipeline doc's §8 trap table records that stage 2's closing
   log prints the WRONG out_dir — read the directory, not the log line.
2. `P2_EXPECTED_HEIGHT_M` still passes. The scale factor is fixed (D26/the
   pipeline doc), so a different held prop must not change the body's height; if
   the gate trips, the pose moved, not the weapon.
3. The pistol's **NE occlusion** case. `p3_posture_export.py` already carries a
   per-facing note about it — the shotgun has none and every facing shares one
   solve, the pistol does not. Look at all four facings, not one.

## B. The assault rifle — needs a grip solve first

There is no `("assault_rifle", *)` row in `p2_grip_spike.ORDER` and no
`WEAPONS["assault_rifle"]` entry, so the rifle is **authoring**, not a run. The
model exists (`Assault Rifle.glb` — `weapon_frames_bake.gd` already bakes it as a
standalone prop), so what is missing is the hand placement:

1. Add `WEAPONS["assault_rifle"]` beside the shotgun's entry. `import_weapon()`
   FAILS unless the model's longest axis is X — that gate is real and useful for
   a barrel, so a rifle should pass it unchanged.
2. Add the three `("assault_rifle", grip)` rows to `ORDER`.
3. Solve the grip per facing, the way the shotgun's is solved. A rifle is
   two-handed like the shotgun, so the shotgun's solve is the starting point,
   not the pistol's one-handed `IDLE_L`.
4. Then run A's two commands with `P3_WEAPON=assault_rifle`.

**The suffix must be `_rifle`, not `_assault_rifle`** — that is what
`AgentShotController.WEAPON_BAKE_SUFFIX` maps `assault_rifle` to, and the two
have to agree. If you would rather the directory carry the full id, change the
map; do not change one side alone.

---

## What to send back

The four directories (or two, if only the pistol is done), plus one capture per
weapon showing the figure in the `aimed` grip at all four facings — the same
shape `p2_grip_matrix.png` already has for the shotgun. Once the frames are on
the machine that runs the game, nothing in the code needs to change: press `1`
and the figure changes.
