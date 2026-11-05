# Session record, 2026-11-04/05: the base, the A <-> T transition, corrective coat keys

## Resume here
Order ruled by the Director at the close ("Tendo IDLE, WALK e RUN prontas pros dois agentes, mais as transições entre elas (MOVEMENT milestone), a gente já pode partir pra texturização (ACTOR milestone), e depois testar os modelos no game/moto"):
1. **MOVEMENT:** the female's `walk` corrective; the male's `idle`, `walk`, `run`; the transitions between the three clips.
2. **ACTOR:** texturing.
3. The models in the game and on the Moto.

The backpack under the coat stays planned (`ACTOR` D100). Still to rule: how the game drives the keys (per clip recommended, or by body angle). Risk to watch: the keys' cost on the Moto is unmeasured and step 3 is the first place it shows, after the work of steps 1 and 2.

## State of the files
- `ASSETS/MODELS/base/AGENT_<FIG>_<A|T>.blend`: the base, OPEN (D102), last frozen at `2ee3cf25`. No build reads it: `AGENT_*.glb` still come from `build_agents.sh`.
- The female's A has the keys `RunFix` and `IdleFix`, value 0. The T has no correctives, and her A's chest edit (hers, 22:32) did not go to the T.
- `fit/RUN_FIX_FEMALE.blend`, `RUN_FIX2_FEMALE.blend`, `IDLE_FIX_FEMALE.blend`: the baked frames the Director edited.

## What was done
- The Director welded and fitted the A poses by hand. By script: the female's right sleeve moved back up to 2.1 cm (the arms are symmetric, the sleeve was not), 503 flat shirt faces of the male smoothed, each T took its A's belt and buckle. D99.
- `tripo_transition.py`: the T's mesh carries both shapes. Matching by closest point tore the A end; matching by UV found every vertex on the differing pieces.
- `tripo_coat_torso_weights.py` (D101): the coat's torso takes the shirt's skin. It reduced the chest leak, did not end it.
- `tripo_pose_fix_back.py` (D103): an edit on a baked frame goes back through the skin (error 0.0001 cm or less on the edited frame). Written into the rest it spoiled the calm poses (open skirt, lumps), so the Director ruled: "só pode valer pra pose extrema". As a key at value 0 the coat equals the file before it, 0.000000 cm at rest and on six walk frames.
- Results, in Blender only: `run` clean on the ten frames looked at; `idle` belt's worst frame 356 -> 113 visible pixels.

## Not done or not verified
- `run` with `RunFix`: the surface is creased and the skirt stays open for the whole clip.
- A chest metric by signed distance was noise (it counts the coat's inner folds); visible belt pixels per frame worked for the idle. Use a render count to pick a frame.
- The D94 leg push exists only in the engine, so the trousers against the skirt are not judged in Blender renders.
- The male's forearm skin near the cuff and the mark beside the female's tie were seen at sheet size, never zoomed.
- Extreme clips (dive, kick) untested on the new weights.
