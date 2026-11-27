# Session summary 2026-11-26 — the short stock finished, the gun's phase in the engine, the other pump shotgun

Picks up `RESUMO_SESSAO_2026-11-25_DOCS_AND_HEALTH.md` §7-§8 (the own grips in the game, early on 2026-11-26). The full record, with
every number, is `MOVEMENT_MASTER_PLAN`'s top blocks of 2026-11-26 ("later", "night", "night, later", "night, end", "night, install").

## What was done

- **The short stock's port closed; her short stock read back** (`4fcb43c5`). The pack's model had an open ejection port and the coat
  showed through it; `glb_close_opening.py` closes it with a black floor as a byte edit (*"poe o fundo preto na janela e pode instalar"*).
  The PUMP grip: her left hand on the pump moved to his short stock (a candidate then). Rulings on the actions after a shot: the pump guns
  rack the fore-end, 01 is a common shotgun, the sawed-off breaks open, the snipers' bolt later (`WEAPON` third note).
- **The short stock's hip made natural and its raise kept out of the coat, both figures** (*"o braço direito no hip da female que eu
  fiz ficou muito pra tras [...] evitar que as armas entrem no casaco durante as movimentações"*). A 15° chest turn and the gun forward
  to 97 % of the left arm's reach; her right hand's snap at 22-23 removed; the raise turned about the left palm. Candidates
  (`6b0affee`), installed on *"Pode instalar as duas"* (`e30132de`).
- **A stricter cut check.** The old rule (pairs more than 12 cm from both wrists) missed every cut near the hands; now a triangle counts
  unless it is a forearm or hand sleeve within 6 cm of its wrist. It showed every stocked long gun's raise taking the butt up the
  coat's front, the family shotgun's in the game too.
- **The tools** (`tools/asset_generation/weapons/`): `long_gun_pose.py` (`grip_donor`, `hip_probe`, `hip`, `drop`, `nudge`,
  `pump_grip`), `family_lab.py raise` with the mid-raise turn, `gun_cuts.py` (`scan` as Blender and as the game play it, `still`).
  Rebuilt from the backups they give the installed short stocks exactly.
- **The gun's phase in the engine.** `ActorMesh3D` places the gun (and the throw's grenade, and the coat's keys) at the LINEAR path
  weight while `ActorAimPose3D` eases the body: the gun shows out of the coat before the hand reaches it and hangs under the hands at
  the holster. The fix (`ActorAimPose3D.eased_weight`) sits behind the dev flag `AIM_GUN_EASED`, OFF; `TIME_SCALE` slows a take
  (`short_stock_draw_slow`); the A/B at a quarter speed is in `temp/videos/gunphase/`.
- **Planned on his note:** the pump, the bolt and then every weapon's reload, after every weapon's draw / hip / aim (§11.6 step 12);
  the draws checked crouched (step 4).
- **The pack's other pump shotgun, 02 (`shotgun_zmptnh7njl`)** (*"Para as outras shotguns que tem a bomba, usamos o mesmo mecanismo,
  adaptando onde for necessário"*): its own draw on both figures (`pump_grip` from his and her short stock hold; no chest turn needed;
  its FULL stock tucked out of the coat at the hip; two nudges on her at 17 and 18). Candidates (`fdaa63a7`), installed on *"Tudo ok,
  não mexi em nada. Pode instalar."*: row from its `H3_OWN` entry, both timelines read back (9 and 11 stops), take
  `shotgun_zmptnh7njl_draw`, added to `long_own_draws`; seen in the game on both figures. Six rows play their own timeline.

## Found, not touched

- **01's hip in the game:** the family shotgun's full stock runs through the coat at the hip (10 coat triangles on him, 14 on her, the
  butt showing behind the coat). 02's tuck (`hip` up 2, side -2 cm, tilt -6°) would clear it; his hip, so his word.
- **A trap for the rows:** `temp/h3_family/rows/rb_SHOTGUNS_m.json` (2026-11-26 01:27) still names the pack's short stock as its source;
  `family_rows.py --h3` on it would copy the open-port model over the closed one. 02's row was written from a read-back holding 02 alone.

## Next

1. His ruling on the gun's phase fix; on a yes the flag goes and the eased read is the only one (pistol, long guns, throw).
2. His word on 01's hip.
3. The grenade launchers (his sizes); the snipers' hip shot in the engine; the H3 rows of the models without their own timeline.
4. Then step 12: the pump (the short stock and 02), the bolt (snipers 09-12), the reloads.
