# Session summary 2026-11-26/27 — the short stock finished, the gun's phase fixed, the other pump shotgun, the family shotgun out of the coat

Picks up `RESUMO_SESSAO_2026-11-25_DOCS_AND_HEALTH.md` §7-§8 (the own grips in the game, early on 2026-11-26). The full record, with
every number, is `MOVEMENT_MASTER_PLAN`'s top blocks of 2026-11-26 ("later", "night", "night, later", "night, end", "night, install",
"night, the gun's phase", "night, 01's hip") and 2026-11-27 (01's raise).

## Commits (all on `main`)

| Commit | What |
|---|---|
| `4fcb43c5` | the short stock's ejection port closed; her short stock read back |
| `6b0affee` | the short stock's natural hip and coat-free raise as candidates; pump, bolt and reloads planned |
| `e30132de` | those installed on both figures; the builders in the repo; the gun's phase fix behind a flag |
| `fdaa63a7` | shotgun 02's own draw built with the pump mechanism, both figures (candidates) |
| `98d17f40` | shotgun 02 installed: row, read-back, takes |
| `24262d0d` | the gun's phase fix ON for good |
| `be6f6c65` | 01's hip tucked out of the coat, both figures |
| `c8f4ceec` | 01's raise turned out of the coat, both figures |

## What was done

- **The short stock's port closed; her short stock read back.** The pack's model had an open ejection port and the coat showed
  through it; `glb_close_opening.py` closes it with a black floor as a byte edit (*"poe o fundo preto na janela e pode instalar"*).
  Rulings on the actions after a shot: the pump guns rack the fore-end, 01 is a common shotgun, the sawed-off breaks open, the
  snipers' bolt later (`WEAPON` third note).
- **The short stock's hip made natural and its raise kept out of the coat, both figures** (*"o braço direito no hip da female que eu
  fiz ficou muito pra tras [...] evitar que as armas entrem no casaco durante as movimentações"*): a 15° chest turn and the gun forward
  to 97 % of the left arm's reach; her right hand's snap at 22-23 removed; the raise turned about the left palm. Installed on *"Pode
  instalar as duas"*.
- **A stricter cut check** (`gun_cuts.py`): the old rule (pairs more than 12 cm from both wrists) missed every cut near the hands; now
  a figure triangle counts unless it is a forearm or hand sleeve within 6 cm of its wrist. It showed every stocked long gun's raise
  taking the butt up the coat's front.
- **The tools** (`tools/asset_generation/weapons/`): `long_gun_pose.py` (`grip_donor`, `hip_probe`, `hip`, `drop`, `nudge`,
  `pump_grip`), `family_lab.py raise` with the mid-raise turn, `gun_cuts.py` (`scan` as Blender and as the game play it, `still`).
  Rebuilt from the backups they give the installed short stocks exactly.
- **Planned on his note:** the pump, the bolt and then every weapon's reload, after every weapon's draw / hip / aim (§11.6 step 12);
  the draws checked crouched (step 4).
- **The gun's phase fixed in the engine.** `ActorMesh3D` placed the gun (and the throw's grenade, and the coat's keys) at the LINEAR
  path weight while `ActorAimPose3D` eases the body: the gun showed out of the coat before the hand reached it and hung under the hands
  at the holster. The fix (`ActorAimPose3D.eased_weight`) was compared behind a dev flag at a quarter speed (`TIME_SCALE`, take
  `short_stock_draw_slow`), then turned ON for good on *"Pode ligar a correção do descompasso"*: the flag is gone. Proofs: the slow take
  on the new default is byte-identical to the corrected one on both figures (1324 of 1324 frames); the throw (`grenade_throw`) filmed
  on both reads shows no visible difference on either figure.
- **The pack's other pump shotgun, 02 (`shotgun_zmptnh7njl`)** (*"Para as outras shotguns que tem a bomba, usamos o mesmo mecanismo,
  adaptando onde for necessário"*): its own draw on both figures (`pump_grip` from his and her short stock hold; no chest turn needed;
  its FULL stock tucked out of the coat at the hip; two nudges on her at 17 and 18), installed on *"Tudo ok, não mexi em nada. Pode
  instalar."*: row from its `H3_OWN` entry, both timelines read back (9 and 11 stops), takes `shotgun_zmptnh7njl_draw` and
  `long_own_draws`. Six rows now play their own timeline.
- **The family shotgun (01) out of the coat, both figures.** The hip (*"Pode ligar [...] o hip da 01"*): his family timelines with
  02's tuck (up 2, side -2 cm, tilt -6°, no forward move); only 17-30 move; the butt no longer runs through the coat at the hip (the
  forearm's sleeve rests on the stock, as on 02; from behind, its end still shows behind the elbow, now beside the coat). The raise
  (*"Tudo ok, fechei sem salvar. Pode instalar."*, 2026-11-27): 02's mid-raise turn on his straight 23 -> 31 (him 25°, her 15°); in the
  game's read the raise cut the coat in 11 of 17 samples on him and 17 of 17 on her, now 2 of 15 and 6 of 17 (the butt meeting the
  shoulder at the end). Both read back after proving that the read-back of his untouched files reproduces the game; take
  `shotgun_draw_close` (new) and the four views (`shotgun_draw`) filmed before and after. His saves are kept in `temp/h3_family/s01/`.

## Methods worth keeping

- **An engine default changed behind a flag:** film a fixed-fps take with the flag ON before, and on the new default after; the two
  must be byte-identical (`framemd5`). It proves the default is the reviewed behaviour and nothing else moved.
- **A re-saved timeline differs everywhere by float noise** (1e-7 in every stop's rotations), so frame hashes all change; a per-frame
  PSNR under 45 dB isolates the frames that changed visibly (01's raise: only 112-130 and 209-249 of 334).
- **A "before" take from the same build:** put the read-back aside (`git stash` of `ASSETS/ANIMATIONS/`, its files copied first and
  compared after the pop).
- **Before installing over his timeline,** read back his untouched file first: no diff means the tool reproduces the game, so the
  install changes only what was edited.

## Found and fixed after the close

- **`gen_codemap.py` hid declarations** (pre-existing; fixed on 2026-11-27 on the Director's word, the `[FIX]` commit after
  `f508e500`): it counted brackets on whole lines, COMMENTS included, and took an apostrophe for a string quote, so a `##` line like
  "(the gun's phase A/B)" left a bracket open and every declaration after it was joined into that line and never parsed; a shader kept
  in a `"""` string did the same through its own `//` comments. Brackets are now counted on the code alone (`_code_skeleton`: strings
  and comments out, triple-quoted strings followed across lines, escaped quotes kept inside their string). `CODEMAP.md` went from
  2 869 to 4 298 entries in 88 of the 359 scripts (`room.gd` 88 -> 326, `board3d_live.gd` 12 -> 104, `voxel_board.gd` 45 -> 112,
  `grenade_controller.gd` 1 -> 53); every top-level declaration line is now parsed (4 298 by an independent scan), and none of the
  2 869 old entries changed. It surfaced because the flag's doc comment of `e30132de` hid some of `ActorMesh3D`'s entries.

## Found, not touched

- **The throw take ends with "ERROR: 8 resources still in use at exit"** (Godot's shutdown report): the same line in the takes of
  2026-11-16, so not from this session's change.
- **A trap for the rows:** `temp/h3_family/rows/rb_SHOTGUNS_m.json` (2026-11-26 01:27) still names the pack's short stock as its source;
  `family_rows.py --h3` on it would copy the open-port model over the closed one. 02's row was written from a read-back holding 02 alone.

## Next

1. The grenade launchers (his sizes); the snipers' hip shot in the engine; the H3 rows of the models without their own timeline.
2. Then step 12: the pump (the short stock and 02), the bolt (snipers 09-12), the reloads.
