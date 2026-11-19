# Timeline coat keys — names, locks, export (`coat_key_follow.py`)

Every `ASSETS/MODELS/actors/agent/<fig>/work/SEQ_*.blend` timeline corrects the coat with shape keys on `Outfit_Coat`, one key per pose, each keyed to
value 1 on its own frame. `tools/asset_generation/tripo/coat_key_follow.py` is embedded in each timeline as a module text (it registers
when the file opens; Blender asks once to allow auto-run scripts) and keeps the editing safe. Ruled by the Director on 2026-11-13
(the key follows the playhead) and 2026-11-15 (names carry the frame, wrong-key edits are blocked).

## Names

| Key | Name | Example | Editable |
|---|---|---|---|
| The clip's own key | `<Base>Fix_f<NN>`, NN = frame on THIS timeline | `CrouchFix_f09`, `CrouchFix_f16`, `DrawFix_f12` | only on frame NN |
| Shared key borrowed at the first frame | `<Base>Fix_f<NN> (inherited)`, NN = frame of the PREVIOUS clip | `IdleFix_f90 (inherited)`, `RunFix_f21 (inherited)` | never |
| Shared key borrowed at the last frame | `<Base>Fix_f<NN> (next)`, NN = frame of the NEXT clip | `RunFix_f14 (next)`, `IdleFix_f90 (next)` | never |

Shared keys are the game's per-clip keys (`IdleFix`, `RunFix`, `WalkFix`): editing one in a transition would change that clip
everywhere, so they stay locked here. The other clip's frame comes from the idle's reference frame (90) or the timeline's
`lab_run_start` record (`from_frame` / `to_frame`).

## What the script does

- **Follow:** on every frame change the active key becomes the one at home on that frame (nearest one between keys). A key's frame
  is read from the animation (its first keyframe at value 1); `_f<NN>` in the name is the fallback.
- **Lock:** every key is `lock_shape`d (Edit Mode refuses: "The active shape key of Outfit_Coat is locked") except the clip's own
  key at home on the current frame, and only ON that frame. Between keyframes nothing is editable. A manual lock / unlock is undone
  on the next frame change.
- **Rename:** `unify_names()` applies the table above (Blender carries the animation paths with the rename).

## Export

`tripo_pose_lab.py` (`clip_out`, `sequence`) sends the GAME's names through `game_key()`: a borrowed key goes out by its base name
(`IdleFix_f90 (inherited)` -> `IdleFix`; a borrowed POSE key keeps its frame: `CrouchFix_f16 (inherited)` -> `CrouchFix_f16`), and a clip's single key too (`DrawFix_f12` -> `DrawFix`). Checked 2026-11-15: run_start and
draw_pistol re-exported identical to the shipped sequences. A crouch key goes out as named (`CrouchFix_f16`).

## Commands

Install / refresh the script and the names in a timeline open in Blender (Python Console, then save):

```python
import importlib.util as u; s=u.spec_from_file_location("c","/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/tools/asset_generation/tripo/coat_key_follow.py"); m=u.module_from_spec(s); s.loader.exec_module(m); print(m.unify_names()); m.add_to_blend(); m.register()
```

⚠️ The builders in `tripo_pose_lab.py` (`crouch_new`, run / walk start-stop) still create keys under the old names
(`IdleFix`, `CrouchFix`); run `unify_names()` on a freshly built timeline.
