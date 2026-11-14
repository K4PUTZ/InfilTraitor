# RESUMO_SESSAO 2026-11-13 — the idle reference frame (90), the female's throw coat, the follow script

## Decisions (Director)
- The idle is the start of every pose layer. Measured: **frame 145** has the coat farthest from the legs on BOTH figures, but its stance is
  crooked on the female, so the Director chose **frame 90**. The idle's `IdleFix` is ONE key for all 368 frames (no per-frame keys).
- **A jump cut, not a wait.** Waiting for the idle to reach the reference (up to ~7.6 s) was refused (*"7s é muito pra cada inimigo"*);
  the idle cuts to the reference frame the moment a pose layer is asked for, no blend. Done.
- No existing animation is left to redo; the four timelines below are the scope. The next animations start from the idle 90.

## Built
- `ActorMesh3D._show_tripo`: `IDLE_REFERENCE_FRAME = 90.0` (24 fps). While a layer is up (aim wanted, `_aim_t > 0`, a throw), the idle holds that
  frame; on leaving, it runs again from there.
- `tripo_pose_dump.gd --idle-frame=N` (idle dump at any frame) and `tripo_pose_lab.py rebase_idle <blend> <idle.json> <out.blend> <frames>`
  (replaces the idle key values of those frames, writes ANOTHER file). The four timelines were rebased at frame 1:
  `SEQ_draw_pistol_{FEMALE,MALE}_idle90.blend`, `SEQ_throw_overhand_{FEMALE,MALE}_idle90.blend` (the Director's originals untouched).
- **`coat_key_follow.py`**: the coat's active `<Name>Fix_f<frame>` key follows the playhead, embedded (module text) by `throw_new`,
  `sequence_new`, `rebase_idle` (`embed_coat_follow()`); `embed_follow <blend> <out>` for an existing file.
- The female throw: the Director edited `ThrowFix_f09/12/15/18` and the poses at 9, 15, 18, 26; read back (`sequence`) into
  `sequences/female/throw_overhand.json` + `poses/female/seq_throw_overhand_f*.json`, the four keys byte-added to `AGENT_FEMALE_LIGHT.glb`
  (`glb_add_morph.py`), backup of the old GLB kept in `temp/`. Takes: `grenade_throw` (female), `pistol_shot` (male).
- The female's idle `IdleFix` v2 and the arms opened 6 deg (`ARM_OPEN_DEG`), closed earlier the same day (`36df9149`).

## Failed on purpose
- `coat_autofix.py` (automatic push of the skirt off the legs by position): failed in bent poses; kept as the record. Coat polish is deferred
  (see memory `coat-polish-deferred-2026-11-12`).

## Traps (Blender)
- Edit Mode edits the ACTIVE shape key, not the frame: four edits made with `ThrowFix_f12` active all land in `f12`. The follow script fixes it.
- Under an armature the transform gizmo sits at the REST-pose position of the selection (the mesh is drawn deformed); G / R / S still move true.
- A shape key is a rest-space delta, skinned after: it follows the bones. Fix the pose first, then the coat.
- Auto-keying a pose replaces the key only at keyed frames; at an unkeyed frame it creates a new key.

## Owed / open
- Frame 26 (the idle at the end) of the four timelines is still the old idle 0; the game does not read it.
- The game's live idle carries the 6 deg arm opening; the timelines (bank idle) do not.
- The clearance at frame 90 was not measured (the female's skirt may press the legs more than at 145); the female's remaining coat slivers
  are the deferred polish.
- Other throws (underhand, bowl, kneeling) and the idle <-> walk / run transitions are not built.

## Commits
`47c6458f` (jump cut, tools), `f8b53d76` (follow script, idle145 timelines, female throw), `ddf302c3` (reference 90, idle90 timelines, GLB + poses).
