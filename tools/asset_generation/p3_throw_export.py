"""CHARACTER_MASTER_PLAN Part 3 — the GRENADE THROW, exported for the Godot bake.

WHAT THE DIRECTOR ORDERED (2026-08-19), in full, because this script implements
the shape of it rather than a summary: *"temos que ter o bake de todas as
situações: ficar em pé e atirar a granada, agachar e atirar a granada, deitar e
atirar a granada (com penalidades de distância). E todos os estados
intermediários, isto é, segurando com o braço recuado durante toda a mira, com
arremesso, recoil, + cancelar a granada nas 3 situações (bem rapidinho, só pra
não sumir de repente). Podemos aproveitar os frames em reverso quando for
possível, tentando refinar com ease e outras ferramentas de animação."*

Then, the same day, a scope correction that this file obeys literally: *"precisamos
refinar as posturas agachado e deitado ainda, então pode deixar só o pipeline
dessas posições preparado. Por enquanto vamos fazer só o arremesso em pé."*

So POSTURES below lists all three and exports one. The other two are declared,
not deleted, and not silently skipped either — `main()` prints why each is held
back. Adding them is un-commenting a line once their base postures are refined;
nothing else in this file, in the manifest shape, or in AgentSprite's playback
has to change.

--------------------------------------------------------------------------------
THREE THINGS THIS DERIVES RATHER THAN ASSERTS:

1. THE IN-BETWEENS ARE GENERATED FROM KEY POSES, NOT AUTHORED. MOVEMENT_MASTER_PLAN
   §4: *"Key poses first, in-betweens second."* Five key poses per sequence are
   the artistic content; everything between them is a sampled interpolation with
   an ease curve, which is what the Director asked for in so many words
   ("refinar com ease"). Raising the frame count costs a re-run, not re-authoring.

2. THE CANCEL IS THE RAISE, REVERSED. Also the Director's own instruction
   ("aproveitar os frames em reverso"). It is not merely a saving: a cancel that
   is a genuinely separate animation can drift from the raise it is undoing, and
   then the arm takes one path up and a different path down. Reversal makes that
   impossible by construction, so the cancel is NOT baked at all — `AgentSprite`
   plays the RAISE phases backwards, which is why the manifest marks the raise
   sequence `reversible`.

3. THE LEFT ARM THROWS; THE RIGHT KEEPS THE SHOTGUN. The figure is an armed
   infiltrator, not an unarmed one — a throw that made the shotgun vanish would
   read as the agent putting his weapon away and taking it out again twice a
   turn. `p2.export_posed(left_arm=...)` forces the one-handed branch for a
   two-handed weapon precisely so this can be true.

Run (standing only, as scoped):
  P3_DEV_ONLY=0 /Applications/Blender.app/Contents/MacOS/Blender --background \\
    --python tools/asset_generation/p3_throw_export.py
"""

import json
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# ORDER MATTERS: p3_posture_export sets P2_MODEL for the dev-only default at
# import time, and p2_grip_spike reads it at ITS import time. Importing p2 first
# would pick the model up one run too late — silently, with the right filenames.
# Same hazard p3_walk_export.py's own header records.
import p3_posture_export as p3                                   # noqa: E402
import p2_grip_spike as p2                                       # noqa: E402

WEAPON = os.environ.get("P3_WEAPON", "shotgun")
GRIP = os.environ.get("P3_GRIP", "lowered")

SHEET_DIR = os.path.join(p2.REPO_ROOT, "Screenshots",
                         "p3_throw" + p2._MODEL.replace("agent_base", ""))


# --- The key poses. Left-arm bone DIRECTIONS in the rig's own frame. ----------
#
# Frame convention, read off p1_agent_model.py rather than assumed: the figure
# faces +Y, +Z is up, and the LEFT side is +X (p1 builds limbs with
# `for side, sx in (("L", 1.0), ("R", -1.0))`). So "cocked behind the head" is
# -Y and +Z, and "released forward" is +Y.
#
# Every vector is normalised on use by `aim_bone`, so these are directions and
# their magnitudes carry no meaning.
IDLE = p2.IDLE_L

# Arm drawn back and up, elbow high — the pose HELD for the whole aim. This is
# the one a player looks at longest, so it is the one worth being fussy about.
## ⚠️ REVISED after looking at the first bake. v1 had upperarm (0.30,-0.42,0.86)
## and forearm (0.22,-0.72,0.66) — two nearly PARALLEL directions, so the elbow
## never bent and the figure read as holding a lantern straight overhead rather
## than as an arm loaded to throw. A cocked throw is an L: the elbow leads UP AND
## FORWARD while the hand falls BACK behind the ear. The two bones must therefore
## point in nearly OPPOSITE Y directions, which is the property v1 lacked and the
## thing to preserve if these are ever retuned.
COCKED = dict(upperarm=(0.30, 0.10, 0.95),
              forearm=(0.20, -0.80, 0.10),
              hand=(0.15, -0.90, -0.12))

# Anticipation: a little FURTHER back than cocked, held for one or two frames.
# Without it the release reads as the arm teleporting forward — anticipation is
# what makes a fast motion legible at 200 px rather than merely quick.
WIND = dict(upperarm=(0.28, 0.04, 0.96),
            forearm=(0.18, -0.93, -0.06),
            hand=(0.12, -0.96, -0.24))

# The release: arm extended forward and high, the frame the grenade leaves on.
RELEASE = dict(upperarm=(0.26, 0.58, 0.77),
               forearm=(0.16, 0.95, 0.26),
               hand=(0.10, 0.99, 0.08))

# Follow-through — the recoil the Director named. The arm does not stop where it
# released; it carries past and down, which is the whole difference between a
# throw and a point.
FOLLOW = dict(upperarm=(0.20, 0.84, 0.05),
              forearm=(0.12, 0.90, -0.42),
              hand=(0.06, 0.84, -0.54))

## RAISE: idle -> cocked. Played FORWARD to enter the aim, BACKWARD to cancel it
## (Director: *"bem rapidinho, só pra não sumir de repente"*).
KEYS_RAISE = [IDLE, COCKED]
## RELEASE: cocked -> wind -> release -> follow-through -> idle. Ends AT idle so
## no separate return sequence exists to drift from this one.
KEYS_RELEASE = [COCKED, WIND, RELEASE, FOLLOW, IDLE]

## How many frames each sequence is sampled at. Knobs, not constants — the same
## reasoning p3_posture_export.py's LAYER_YAWS carries: raising the count costs a
## re-run and nothing downstream is pinned to it, because AgentSprite counts what
## is on disk.
RAISE_PHASES = int(os.environ.get("P3_THROW_RAISE_PHASES", "6"))
RELEASE_PHASES = int(os.environ.get("P3_THROW_RELEASE_PHASES", "10"))

## Seconds each sequence plays for. Authored here rather than in GDScript because
## the frame COUNT and the DURATION are one decision — 6 frames over 0.18 s is
## 33 Hz, which is D46's ratified authoring rate, and changing one number without
## the other silently changes the playback rate.
RAISE_SECONDS = float(os.environ.get("P3_THROW_RAISE_SECONDS", "0.18"))
RELEASE_SECONDS = float(os.environ.get("P3_THROW_RELEASE_SECONDS", "0.40"))

## Which postures throw. Standing ships; the other two are HELD, not dropped —
## see this file's header for the Director's own reason.
POSTURES = [
    ("standing", None, True),
    ("crouch", "crouch", False),
    ("prone", "prone", False),
]

OUT_DIR_FMT = ("res://ASSETS/ISOMETRIC/source_assets/actor_bakes/"
               "agent_throw%s/%s/%s/")

## The height gate's band for a throw phase, and BOTH ends are reasoned rather
## than tuned until it passes.
##
## LOWER = the standing figure exactly. These poses move the LEFT ARM and
## nothing else — legs, spine, head and hat are the standing export untouched —
## so an arm can only ADD height to the bounding box, never remove it. A phase
## measuring under 2.00 m means the posture or the scale broke, which is exactly
## what this gate is for.
##
## UPPER = MEASURED, not guessed. The first run printed every phase's height:
## 2.000 / 2.016 / 2.050 / 2.099 / 2.100 / 2.132 / 2.160 m. The tallest pose
## reaches 0.160 m past the standing crown, so 2.200 is the measurement plus a
## 4 cm margin — tight enough that a broken arm solve still trips it.
THROW_BAND_M = (
    float(os.environ.get("P3_THROW_BAND_LO", "1.985")),
    float(os.environ.get("P3_THROW_BAND_HI", "2.200")),
)


def log(m):
    print("[P3-THROW] %s" % m)


def fail(m):
    print("[P3-THROW][FAIL] %s" % m)
    sys.exit(1)


def ease(t):
    """Smoothstep. The 'ease' the Director asked for, and the cheapest honest one.

    Linear sampling between key poses makes an arm start and stop dead, which at
    six frames reads as a mechanism rather than a limb. Smoothstep eases both
    ends; the release sequence additionally spends its keys unevenly (see
    `sample`), because a throw is not symmetric in time — the wind-up is slow and
    the release is not.
    """
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def lerp3(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def sample(keys, t01, hold_last=False):
    """The pose at `t01` along a key list, eased between neighbours.

    `hold_last` exists for the RAISE sequence: its final frame IS the held aim
    pose, and a sampled sequence that never quite reaches its last key would
    leave the hold visibly short of the pose the cancel starts from.
    """
    if len(keys) == 1:
        return keys[0]
    span = len(keys) - 1
    x = min(max(t01, 0.0), 1.0) * span
    i = min(int(math.floor(x)), span - 1)
    local = ease(x - i)
    if hold_last and t01 >= 1.0:
        return keys[-1]
    a, b = keys[i], keys[i + 1]
    return {part: lerp3(a[part], b[part], local)
            for part in ("upperarm", "forearm", "hand")}


def phase_list(keys, count, hold_last=False):
    """`count` sampled poses spanning the key list end to end."""
    if count < 2:
        fail("a sequence needs at least 2 phases, got %d" % count)
    return [sample(keys, float(i) / float(count - 1), hold_last)
            for i in range(count)]


def _open_rig():
    return p3._open_rig()


def main():
    if not os.path.isfile(p2.BLEND):
        fail("model missing: %s — run p1_agent_model.py first" % p2.BLEND)
    key = (WEAPON, GRIP)
    if key not in p2.GRIPS:
        fail("P3_WEAPON/P3_GRIP = %s:%s is not one of %s"
             % (WEAPON, GRIP, ["%s:%s" % k for k in p2.ORDER]))

    _open_rig()
    p2.setup_render()
    os.makedirs(SHEET_DIR, exist_ok=True)
    facing = p2.measure_facings()
    export_facing = facing[p2.YAWS[0]]

    fam = p3.bake_family(p2._MODEL)
    sequences = [
        ("raise", phase_list(KEYS_RAISE, RAISE_PHASES, hold_last=True),
         RAISE_SECONDS, True),
        ("release", phase_list(KEYS_RELEASE, RELEASE_PHASES), RELEASE_SECONDS,
         False),
    ]

    entries = []
    for posture_name, posture_key, enabled in POSTURES:
        if not enabled:
            ## LOUD, not silent. A posture that is simply absent from the
            ## manifest looks identical to one the script forgot.
            log("posture %r: HELD — its base posture is still being refined "
                "(Director, 2026-08-19: only the standing throw for now). "
                "Flip its flag in POSTURES when it lands." % posture_name)
            continue
        posture = None if posture_key is None else p3.POSTURES[posture_key]
        for seq_name, poses, seconds, reversible in sequences:
            for i, pose in enumerate(poses):
                log("=" * 66)
                log("%s / %s / phase %02d of %d" % (posture_name, seq_name, i,
                                                    len(poses)))
                arm = _open_rig()
                grenade, _created = p2.import_grenade()
                parts_out = {}
                p2.export_posed(arm, key, export_facing, posture=posture,
                                parts=p3.PARTS, parts_out=parts_out,
                                left_arm=pose, hand_prop=grenade,
                                height_band=THROW_BAND_M,
                                tag="%s_%s_%02d" % (posture_name, seq_name, i))
                body = parts_out.get("body")
                if body is None:
                    fail("%s/%s phase %d exported no `body` part"
                         % (posture_name, seq_name, i))
                entries.append(dict(
                    name="%s_%s_%02d" % (posture_name, seq_name, i),
                    glb=os.path.relpath(body, p2.REPO_ROOT).replace(os.sep, "/"),
                    out_dir=OUT_DIR_FMT % (fam, "%s_%s" % (posture_name, seq_name),
                                           "phase%02d" % i),
                    headless=True,
                    height_m=round(p3._measure_glb_height(body), 4),
                    posture=posture_name,
                    sequence=seq_name,
                    phase=i,
                    seconds=seconds,
                    reversible=reversible,
                ))

    if not entries:
        fail("no posture was enabled — nothing to export")

    manifest = dict(
        grip="%s/%s" % (WEAPON, GRIP),
        frame=list(p3.PREVIEW_FRAME),
        px_per_screen_m=p2.PX_PER_SCREEN_M,
        voxel_m=p3.VOXEL_M,
        facings={str(k): v for k, v in facing.items()},
        ## The bake reads `postures`; the throw's own structure rides alongside
        ## in each entry. Same key name as the other two exporters on purpose —
        ## agent_frame_bake_spike.gd consumes ONE manifest shape, and a third
        ## spelling of "the list of things to bake" is how a bake quietly skips.
        postures=entries,
        sequences=[dict(name=n, phases=len(p), seconds=sec, reversible=rev)
                   for n, p, sec, rev in sequences],
    )
    with open(os.path.join(SHEET_DIR, "manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=2)

    log("=" * 66)
    log("%d phase(s) exported across %d sequence(s)"
        % (len(entries), len(sequences)))
    log("the CANCEL is not exported: it is `raise` played backwards "
        "(reversible=true), per the Director's own reuse instruction")
    log("next, ONE windowed Godot boot:")
    log("  AGENT_BAKE_MANIFEST=%s \\"
        % os.path.relpath(os.path.join(SHEET_DIR, "manifest.json"), p2.REPO_ROOT))
    log("  /Applications/Godot.app/Contents/MacOS/Godot --path . "
        "--position 4000,4000 \\")
    log("    --script res://godot/scripts/tools/agent_frame_bake_spike.gd")


if __name__ == "__main__":
    main()
