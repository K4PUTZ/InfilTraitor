# MOVEMENT_MASTER_PLAN
## How the characters move: the animation bank, the map of what the game needs, and the path from a Tripo clip to a move on the grid — v1.5

> ⏭️ **2026-11-27 — 01's RAISE turned out of the coat on both figures (Director: *"Tudo ok, fechei sem salvar. Pode instalar."*):** the night's candidate installed over the tucked hip as built (both files untouched): 02's mid-raise turn on the family's raise (`family_lab.py raise <tucked> <out> 23 31 25,27,29 0.03 <25|15>`: him 25°, her 15°, a 3 cm forward bow; breakdowns 25, 27, 29 added, his 23 and 31 kept). In the game only the raise changes (the gun up to 6.5 cm from its old path mid-raise). In the game's read the raise had the butt up the coat's front in 11 of 17 samples on him (up to 24 triangles) and 17 of 17 on her (up to 23); now 2 of 15 (up to 12) and 6 of 17 (up to 13): the butt meeting the shoulder at the end, as on the short stock and 02. Read back (11 stops each, 25 / 27 / 29 passing), filmed on both figures (`shotgun_draw_close`). §11.6 step 2.
> ⏭️ **2026-11-26 (night, 01's hip) — the FAMILY shotgun's (01) hip TUCKED out of the coat on both figures, as 02's (Director: *"Pode ligar [...] o hip da 01"*):** `long_gun_pose.py hip` on his family timelines (`SEQ_draw_shotgun_{MALE,FEMALE}.blend`; his saves kept as `temp/h3_family/s01/SEQ_draw_shotgun_*_his_2327.blend`) with 02's numbers and no forward move (01 IS the family's hip): up 2, side -2 cm, tilt -6°, eased in from 16 (his 18 and 20 take 20 % and 61 % of it). Only 17-30 move (the hands at most 6 cm; the head and the chest not at all); 1-16 and 31 stay as he posed them. In the game's read the hip (21.5-24) had the butt through the coat in every sample (up to 11 triangles on him, 16 on her); now none on him and at most 5 on her (the upper sleeve over the butt's end, under the arm), the forearm's sleeve resting on the stock left as on 02. The read-back of his files as they were changed nothing (the tool reproduces the game); the tucked files read back. Filmed before and after on both figures, close (`shotgun_draw_close`, PLAYGROUND, new) and in the four views (`shotgun_draw`; the before side from the same build with the read-back put aside): from the front and the side the stock now lies whole outside the coat under the forearm (it went into the coat); from behind its end still shows behind the elbow, now beside the coat instead of out of it. **Not changed, a candidate for his word:** the RAISE is his straight 23 -> 31 and still takes the butt up the coat's front (in the game's read: 11 of 17 samples on him, up to 24 triangles; 17 of 17 on her, up to 23), as before the tuck; 02's mid-raise turn (`family_lab.py raise ... 23 31 25,27,29 0.03`, him 25°, her 15°) leaves 2 of 15 samples on him (up to 12) and 6 of 17 on her (up to 13), the butt meeting the shoulder at the end: `temp/h3_family/s01/SEQ_draw_shotgun_{MALE,FEMALE}_raise_candidate.blend`. §11.6 step 2.
> ⏭️ **2026-11-26 (night, the gun's phase) — the gun's phase fix ON for good (Director: *"Pode ligar a correção do descompasso e o hip da 01"*):** `ActorMesh3D` always reads a timeline's gun (and the throw's grenade) and the coat's keys at the body's eased path weight (`ActorAimPose3D.eased_weight`); the dev flag `AIM_GUN_EASED` and its row are gone, and `gun_cuts.py scan`'s `game` mode is that read (`gamefix` gone). Proof: take `short_stock_draw_slow` filmed on the new default is byte-identical to the A/B's flag-ON take on both figures (1324 of 1324 frames each) and shares only 361 (female) / 667 (male) frames with the old default. The throw (take `grenade_throw`, both figures) filmed on both reads (the old one by swapping the two calls back for the take only): no frame differs visibly (PSNR at least 45 dB throughout), the grenade riding the hand at a fixed place and its release falling on a resting stop. `TIME_SCALE` stays for slow takes. The flag's doc comment had made `gen_codemap.py` drop some of `ActorMesh3D`'s entries since `e30132de` (`GAIT_PASSAGES`, `weapon_out()`, ...); they are back. §11.6 step 2.
> ⏭️ **2026-11-26 (night, install) — shotgun 02 IN THE GAME on both figures (Director: *"Tudo ok, não mexi em nada. Pode instalar."*):** his two files byte-identical to the candidates of `fdaa63a7`. Row `shotgun_zmptnh7njl` (the shotgun's numbers, `held_as` shotgun, `model.draw` = `draw_shotgun_zmptnh7njl`) from 02's new `H3_OWN` entry (`family_rows.py --h3`), its model copied to `ASSETS/props/shotgun_zmptnh7njl/`; written from a read-back holding 02 ALONE, because the lab read-back of 2026-11-26 01:27 still names the pack's short stock as its source and `--h3` on it would copy the open-port model over the closed one. Both timelines read back (him 9 stops; her 11, her two nudges at 17 and 18), the game set rebuilt. Take `shotgun_zmptnh7njl_draw` (PLAYGROUND, close); 02 added to `long_own_draws`. Seen in the game on both figures (`temp/videos/shotgun02/`), no engine error; the load says, as for the other own rows, that the female has no `held_like` grip (unused: she plays her own timeline). Six rows now play their own timeline. Still open: the gun's phase fix (`AIM_GUN_EASED`, off); the same tuck on 01's hip. §11.6 step 2.
> ⏭️ **2026-11-26 (night, end) — the pack's other PUMP shotgun (02, `Shotgun-ZmPTnh7njL`) gets its OWN draw on both figures, as candidates opened for the Director; a FULL stock runs through the coat at the HIP, the family shotgun's too (Director: *"Para as outras shotguns que tem a bomba, usamos o mesmo mecanismo, adaptando onde for necessário"*):** `family_lab.py seq` on his family timeline with his sized lab scenes, 18/20 dropped (`long_gun_pose.py drop`), the female in step (`family_lab.py in_step`); the left hand put on 02's pump the way the short stock's hold sits on its own (`long_gun_pose.py pump_grip`: the same share along the pump, the same offsets in figure units, the hand's turn against the barrel, the fingers; the male from his short stock, the female from hers). 02's pump sits further back, so the gun slides only 3.2-3.5 cm at the hip, and at the aim the left arm reaches the rest (97 %). Adapted: no chest turn (3.25-3.5 cm forward already takes the right arm to the family's own angle: -31 deg hers, -38 his). **Found with the stricter check:** a FULL stock at the hip runs through the coat's front and out of its back, on the family shotgun in the game as well (01: 10 coat triangles on him, 14 on her, the butt showing behind the coat), and 02 swinging level (frame 20: 26). 02's hip takes the butt out beside the coat, tucked under the forearm (`hip`'s `up` 2, `side` -2 cm, `tilt` -6 deg): nothing shows; the forearm's sleeve over the stock is the contact left (hidden). Her 16.5-18 (the butt at the thigh while the gun is still upright, the inherited 18/20 gone) needed two `nudge` stops (17: 3.5 / 2 / 1 cm, 18: 1 / 0 / 0.5). The raise turned about the left palm (him 3 cm and 25 deg, her 3 cm and 15 deg): the coat's front clear; left are the sleeve contact, the butt meeting the shoulder at the end, and the aim's own contact (as on the family's). `SEQ_draw_shotgun_zmptnh7njl_{MALE,FEMALE}.blend`; not in the game (no row, no read-back). Open for the Director: the same tuck on 01's hip (in the game); 02's poses. §11.6 step 2.
> ⏭️ **2026-11-26 (night, later) — the SHORT STOCK's new hip and raise INSTALLED on both figures; the builders in the repo; the GUN'S PHASE fix behind a flag, compared in slow motion (Director: *"Tudo ok, não mexi em nada. Pode instalar as duas"*; *"Preciso ver a diferença entre o descompasso e a correção. Grava um video comparativo, com velocidade reduzida. Mas a princípio estou inclinado a fazer a correção. Como sempre nosso lema é fazer CERTO e não rápido"*; *"Para as outras shotguns que tem a bomba, usamos o mesmo mecanismo, adaptando onde for necessário"*):** both candidates copied over the timelines (his female and the installed male kept as `temp/h3_family/SEQ_draw_shotgun_short_stock_{FEMALE_his,MALE_inst}_2132.blend`) and read back (12 stops each), take `short_stock_draw` (PLAYGROUND, close). The scratch builders are tools now, and rebuilt from those two backups they give the installed files exactly (every key and every evaluated hand and gun place, 0 difference): `tools/asset_generation/weapons/long_gun_pose.py` (`grip_donor`, `hip_probe`, `hip`, `drop`, and `pump_grip`, a hold on one model's pump put on another's), `family_lab.py raise` with the mid-raise turn (`turn deg`, `turn end`, `bulge end`), `gun_cuts.py` (`scan` as Blender and as the game play it, `still`). **The engine:** `ActorAimPose3D.eased_weight()` gives the path weight the body is at; `ActorMesh3D` reads the gun (and the throw's grenade) and the coat's keys there when `AIM_GUN_EASED=1`; the default is unchanged until the Director rules. `TIME_SCALE=<f>` slows the whole game for a take (Movie Maker still writes 60 fps, each frame a quarter of a sixtieth apart: every in-between its own frame); take `short_stock_draw_slow` runs at 0.25. The A/B on both figures (`temp/videos/gunphase/*_gunphase_quarter.mp4`): today the gun shows OUT of the coat before the hand reaches it (the draw) and hangs under the hands after they have closed (the holster), and sits a little differently in the hand while it swings level; corrected, it appears and goes with the hand. Nothing differs at the rests or in the raise (the gun does not slide in the hand there). Next: his ruling on the fix (then the flag goes and the eased read is the only one); the pack's other PUMP shotgun (`Shotgun-ZmPTnh7njL`, model 02, no row yet) gets its own draw with the same mechanism. §11.6 step 2.
> ⏭️ **2026-11-26 (night) — the SHORT STOCK's HIP made natural and its RAISE kept out of the coat, both figures, as CANDIDATES opened for the Director; the pump, the bolt and the reloads PLANNED (Director: *"o braço direito no hip da female que eu fiz ficou muito pra tras. Veja se consegue deixar a pose mais natural, com os dois braços e a arma um pouco mais pra frente. Checa se ainda da pra suavizar ou melhorar os movimentos, e evitar que as armas entrem no casaco durante as movimentações"*):** at her hip (23) the right upper arm pointed 70° BACK (his family hip: 30°) and the right hand sat 9.6 cm behind the family's: the pump is far ahead of the grip and the left hand on it is at 93 % of its reach, so the gun can go only ~2 cm forward before the left arm is straight (the right elbow's swing and the left clavicle buy little). The chest now turns 15° (the left shoulder forward, a shotgun's bladed stance; the neck turned back, the head keeps its look) and the gun and both hands come forward as far as the left arm allows at 97 % (hers 3.75 cm, his 5 cm plus 1.5 cm out of the coat's skirt): the right arm at -46° / -49° (yesterday's male candidate: -75°). Her right hand was held ahead at 21-22 and taken 11 cm back to the grip in the last frame (127 mm in one frame); it now comes down to the grip from her 19. A stricter cut check (a figure triangle cut by the gun counts unless it is a sleeve within 6 cm of its wrist; the old rule, pairs more than 12 cm from both wrists, missed every cut near the hands) found the raise from the hip to the aim taking the butt up the coat's right front on every stocked long gun: the family shotgun's own raise in the game (up to 22 triangles at 25), her short stock (17), his (15); the stockless sawed-off is clean. Her raise also dipped the muzzle to -21° with the right hand 4-7 cm off the grip. The raise is rebuilt with a turn about the vertical through the left palm in mid-raise (the butt out beside the coat's flank, back into the shoulder at the end): her 4 cm bow and 15°, his 3 cm and 25° (his coat is wider); the barrel level, both hands on the gun, the left arm at most 98 %. Blender, 13-31 at four samples a frame: her cutting samples 31 -> 5, his 42 -> 13; left are his draw out from behind the flap (13.5-14.25) and the butt meeting the shoulder (29.25-31), as in the installed ones. His aim keeps the left hand on the pump with the gun 6.7 cm back (less leaves the hand 0.8-2.6 cm short), the cheek on the stock (9 head triangles; hers, his pose: 6). Candidates `temp/h3_family/hipfwd/SEQ_draw_shotgun_short_stock_{FEMALE,MALE}_v2.blend` (scripts `hip_natural`, `raise2`, `cut_scan`, `cut_still` in `temp/h3_family/scripts/`). **Found in the ENGINE, not changed:** `ActorMesh3D` reads the gun's place in the hand and the coat's morphs at the LINEAR path weight (`AimSequence.at(_aim_t)`) while `ActorAimPose3D` eases the body by a smoothstep between resting stops, so in the game the gun leads or lags the hand by up to about a frame: on her short stock it appears at frame 13's place while the body is at 12.3 (the belt, shirt, trousers and coat cut for ~0.03 s), and a chest cut at 28.5-29 comes from it too; read at the eased weight (simulated), both go. Planned on his word: the pump, the bolt and then every weapon's reload (§11.6 step 12), after draw / hip / aim are done for every weapon; the crouched draws checked (step 4). §11.6 steps 2, 4, 12.
> ⏭️ **2026-11-26 (later) — the SHORT STOCK's PORT CLOSED, the female's short stock READ BACK, the PUMP GRIP on the male as a candidate (Director: *"tem um buraco no corpo da arma"*, *"poe o fundo preto na janela e pode instalar"*, *"Terminei o modelo feminino. A mão esquerda já está corretamente posicionada no pump da shotgun. Tente fazer essa adaptação para as outras mãos do male, usando o mesmo shape dos ossos, e aplicando nas demais shotguns da femea"*):** the pack's short stock modelled its ejection port as an open 8-edge loop in the receiver's right wall, and the game culls back faces, so the coat showed through the gun (of the 21 H3 models only this one has a real hole). `tools/asset_generation/weapons/glb_close_opening.py` closes it with a Black floor as a BYTE edit (6 triangles appended to the Black primitive, every other byte kept and checked), installed as `ASSETS/props/shotgun_short_stock/shotgun_short_stock.glb`; `tripo_pose_lab.PROP_GLB` and `family_lab`'s H3 model 04 now read that copy (so `family_rows.py --h3` copies it onto itself instead of over it), and both short-stock SEQ files carry it. His female short stock is read back as he saved it (stops 11, 12, 13, 16, 19, 21, 22, 23, 27, 31): the left palm on the pump at 28 % of its length, 0.5 cm off, from 13 to 31, the gun 9.5 cm nearer the body at the hip and 6.4 cm at the aim, no cut from 10 to 31. **Two findings in his raise, shown, not changed:** without the breakdowns 25 and 29 the barrel dips to −21° at 26 and the right palm leaves the grip by up to 7 cm (the sawed-off's dip of 2026-11-24 again); `family_lab.py raise` on his own 23 and 31 keeps it level with both palms on (one coat triangle at 26), a candidate for his choice. **The male short stock with her grip, a candidate (not installed):** his body kept; the gun slides along its barrel until his palm is on her point (+2.5 cm at 13-16, −9.55 cm from 23), his left hand takes her turn against the gun and her finger joints, his right hand stays on the grip; at 19, 21, 22, 23 and 24 (21, 22, 24 new stops, as in her file) gun and hands move 0.7-1.6 cm to clear the coat: no cut from 13 to 31 (his file had 2 triangles at 23), the left hand's skin at most 6 vertices 3 mm into the pump (his had 27 at 4.9 mm). **The actions worked by hand after a shot (rulings):** a PUMP on the short stock (and on 02, which has no row): the recoil will rack it with the support hand, the shell out of the port; the certified shotgun 01 is a COMMON shotgun (*"tem um anel ali abraçando ela. Acho que é uma shotgun comum"*), no pump; the sawed-off breaks open; the pack's four snipers (09-12) have a bolt, its animation later (*"Deixa pra depois a animação do ferrolho das snipers"*). Open: the other shotguns' support hand (01 is the family timeline every H3 row without its own plays; the sawed-off's fore-end is twice the pump's height, so her curl would sink into it). `WEAPON_MASTER_PLAN` has the actions' note.
> ⏭️ **2026-11-25 (later) — the SNIPERS' scene: the rifles' grip, the HEAD lifted to the SCOPE, opened for his sizes (Director: *"Tenta encaixar a pegada deles na pose da mira, e já abre a cena com todos, pra gente validar os tamanhos"*):** the family shotguns stay as they are. The pack's four snipers have glass lenses, so the scope's axis is exact; on the family's aim the eye sat 1.1-1.4 cm under it. One turn of the neck (9°) and the head (-17°), the same on every sniper Agent, lifts the eye to the eyepiece with the look along the barrel; the two sci-fi snipers' housings pass through the face and the hat (a size for him). `FAMILY_H3_SNIPERS_aim_MALE.blend`. §11.6 step 2.
> ⏭️ **2026-11-25 — the SHORT STOCK's raise rebuilt and READ BACK; the long-gun draws' GUN-THROUGH-BODY cuts FIXED (Director: *"Pode conferir"*, *"Grava os videos com a parte que atravessa a cintura e cruza o casaco"*, then *"pode instalar a correção em todas as instâncias que precisarem"*):** a new check (the gun's triangles crossing the figure's, away from the hands) found the long guns passing through the belt, buckle, trousers, shirt and tie at 13-15, where they appear out of the coat (hidden there by design and by the camera, the Director says), and through the coat in the slide. Fixed by moving the left hand with the gun by the smallest offset that leaves 0.6 cm, keyed at the cutting frames: the short stock and both bullpups installed and read back. The two family SHOTGUNS need the stock swung forward too (up to 30° at 13), and from the game camera the stock then shows below the coat where his version hides the cut: built and shown, not installed (advised: leave them). §11.6 step 2.
> ⏭️ **2026-11-24 (late night) — the FEMALE's SAWED-OFF built IN STEP, its RAISE rebuilt from the gun, posed by the Director and READ BACK (Director: *"Depois da uma conferida na feminina"*, then *"Abre no Blender"* and *"Ajustei e salvei"*):** `family_lab.py in_step` carried his sawed-off onto her shotgun keys (her own hold kept at 23 and 31), but at the raise's breakdowns 25/27/29 it has no departure of hers to carry, so her right hand swung ~20° aside and back; `family_lab.py raise` run after it fixed that (the hand at most 3.5° a frame, the barrel level within 1.4°, both palms on). He then re-posed her draw before the lapel (new keys at 8, right forearm, and 9, left arm; the left forearm at 11 and 12). `ASSETS/ANIMATIONS/sequences/female/draw_shotgun_sawed_off.json` + eleven stops. Then her 13 FIXED on his word (*"Corrige o 13"*, then *"Pode instalar"*): her coat crossed the gun there (from the build; the male is clear); the left hand and the gun moved 1.5 cm to her left (the arm two-bone solved, the turn kept), 0.9 cm clear of the coat; read back again. §11.6 step 2.
> ⏭️ **2026-11-24 (night, later) — the SAWED-OFF posed by the Director, smoothed and READ BACK; the SHORT STOCK's scene built (Director: *"Ajustei e salvei"*, then *"Pode instalar"*):** he re-posed the left arm at 13 and 16 and the fingers, and kept the aim as built (the gun at the eyes, both hands on it). The shotgun's inherited keys at 18/20 dropped (his bullpup ruling) and the raise rebuilt by `family_lab.py raise` (3 cm bow): the barrel no longer dips 18°, the right hand stays on. `ASSETS/ANIMATIONS/sequences/male/draw_shotgun_sawed_off.json` + nine stops; 11-23 and 31 = his. `SEQ_draw_shotgun_short_stock_MALE.blend` built the same way (`seq 04`, 18/20 dropped) and opened for him. §11.6 step 2.
> ⏭️ **2026-11-24 (night) — the FEMALE's BULLPUP posed by the Director, its RAISE SMOOTHED and READ BACK (Director: *"Ajustei o saque e a mira feminina, mas o movimento nos últimos frames está meio duro. Da uma conferida e veja se consegue suavizar. As poses estão corretas"*, then *"Pode instalar"*):** his breakdown at 27 took the gun out of her body by turning it ~50° aside, so it whipped back in the last three frames (through the hat and head at 30) while the right hand hung off the grip. `family_lab.py raise` rebuilds a raise FROM THE GUN between two stops he keeps: the muzzle on the target, an arc bowed 6 cm forward on a smoothstep, both hands solved onto it at 25, 27 and 29, the slide re-keyed. A leftover of the deleted stop 11 (right forearm and hand) snapped the right hand 36° in one frame; removed. `ASSETS/ANIMATIONS/sequences/female/draw_bullpup.json` + nine stops; 12, 13, 16, 23, 31 = his. §11.6 step 2.
> ⏭️ **2026-11-24 (evening) — the FEMALE's BULLPUP built IN STEP, and the two STOCKLESS SHOTGUNS brought forward from the polish (Director: *"Vamos começar primeiro fazendo a versão feminina. E depois eu queria abrir as duas shotguns de cano curto que a gente adiou ontem para a fase de polimento, e fazer agora. É pouca coisa"*):** `family_lab.py in_step` puts his CHANGE from his family timeline to his model timeline on HER family timeline (her hip and aim by his hand kept, her right hand's own departure on the grip kept; with no change her file comes back key for key) -> `SEQ_draw_bullpup_FEMALE.blend`, the bullpup in her hand exactly at his place. The sawed-off's own timeline is built (`SEQ_draw_shotgun_sawed_off_MALE.blend`, `family_lab.py seq`; both hands on it at the hip and the aim) for him to pose its aim (arms forward, at the eyes); the short stock follows its scheme. §11.6 step 2.
> ⏭️ **2026-11-26 — the OWN GRIPS IN THE GAME (Director: *"vamos ja instalar todas as pegadas próprias que estiverem prontas, o polish vai ser só pra o que ainda não foi feito"*; the numbers *"copia da família"*):** five weapon rows, held as the shotgun, each naming its own timeline in `model.draw` (`WeaponDef.draw`): `bullpup` (assault_rifle's numbers), `shotgun_sawed_off`, `shotgun_short_stock` (shotgun's), `scifi_sniper_46615jyfm7`, `scifi_sniper_vu7qizyae0` (sniper_rifle's), written by `family_rows.py --h3` from the lab read-backs. `ActorMesh3D` builds one aim set per own timeline (`_own_draws`, key `<draw>:standing`) and picks it for the held row (`_set_key_for`); that timeline places the model itself (no `held_like`); a figure without the file (the female's short stock) draws it on the family's timeline at its `held_like` place. `TripoFigure.build_library` adds those timelines' poses to the game set. Seen in the game on both figures, take `long_own_draws` (PLAYGROUND). The sci-fi snipers have a hip stop but the game still gives snipers the aimed shot alone (the `sniper` tag): the Director's hip for snipers (2026-11-25, *"vão errar mais ainda"*) is not wired. POLISH-01 keeps only what is not done.
> ⏭️ **2026-11-24 (afternoon) — the BULLPUP's DRAW posed by the Director and READ BACK (Director: *"Ajustei e salvei"*, then *"A 3, sem 18/20"*):** his save moved the left hand's hold at 12, 13 and 16 (the hand on another part of the grip, the bullpup still upright at 16). The slide 17-22 was re-baked from his 16: a baked slide is DERIVED from the two stops beside it, so moving the gun at one of them leaves a jump until it is re-baked (here 87° in the hand at 17). By his choice, the left arm's keys at 18 and 20 (the shotgun's, inherited) are gone, so the ~90° turn to the hip spreads over 16-23 instead of two frames. `ASSETS/ANIMATIONS/sequences/male/draw_bullpup.json` + six stop poses; played only at POLISH-01. §11.6 step 2.
> ⏭️ **2026-11-24 (later) — the RIFLES DONE and the BULLPUP's OWN DRAW TIMELINE built (Director: *"Vamos montar no Blender toda a sequência da mira só com essa arma. As demais estão prontas"*):** his hip grip saved too (`grip_bullpup_hip.json`); `SEQ_draw_bullpup_MALE.blend` = his shotgun timeline with the bullpup, its hip (23) and aim (31) from the lab scenes, the draw to the centre the family's (`family_lab.py seq`); he poses the bullpup's draw next. Not in the game until POLISH-01. §11.6 step 2.
> ⏭️ **2026-11-24 — the RIFLES sized and the BULLPUP's own GRIP SAVED; the rifles' HIP scene built (Director: *"A última arma especificamente tem um design diferente, então eu tive que modificar o esqueleto. Vamos já deixar essa empunhadura salva. Precisamos checar o hip em seguida"*):** the three assault rifles moved a few millimetres at their built size; the bullpup x0.75 on a body of its own (26 bones). That body is kept as a pose file for POLISH-01, `ASSETS/ANIMATIONS/poses/male/grip_bullpup_aim.json` (`family_lab.py grip`; nothing in the game reads it yet), and the read-back gives such a model twice (`rel_*` on the family's body, `own_grip` in its own hand). `FAMILY_H3_RIFLES_hip_MALE.blend` stands the line at the hip on his sizes. §11.6 step 2.
> ⏭️ **2026-11-23 (night, later) — the Director's own hands on the FEMALE's HIP and AIM are IN THE GAME (Director: *"Primeiro eu vou ter que ajustar o hip e a mira feminina também"*, then *"Ajustei e salvei"*): his save of her timeline changed her keys at 23 and 31 only (the arms, the hands, the right fingers, the trunk; at the aim also the neck and the shoulders); from now on those two stops are his, never the recipe's. §11.6 step 3.**
> ⏭️ **2026-11-23 (night) — the Director's GRIP at the long gun's AIM is IN THE GAME on both figures, and H3's FIVE SCENES are BUILT on it (Director: *"Ajustei e salvei"*): his save changed the aim only (frame 31: both hands turned ~33°, the arms, the neck, the trigger finger), the female in step by the 11-22 recipe; `FAMILY_H3_{SHOTGUNS,RIFLES,SNIPERS,SCIFI}_aim_MALE.blend` and `FAMILY_H3_LAUNCHERS_hip_MALE.blend` wait for his sizes. §11.6 steps 2 and 3.**
> ⏭️ **2026-11-23 (later still) — H3 SPLITS INTO FIVE LAB SCENES by animation (Director: *"vamos separar um pouco as armas porque as animações vão ter que ser um pouco diferentes"*): shotguns, rifles, snipers, sci-fi, grenade launchers; the GRENADE LAUNCHERS have NO aimed stage (the hip only), probably on a grip of their own. First the Director re-checks the grip at the certified AIM in his `SEQ_draw_shotgun_MALE.blend`. §11.6 step 2.**
> ⏭️ **2026-11-23 (later) — the shotgun's size CERTIFIED and H3's LAB FILE BUILT (Director: *"A certificação do tamanho da escopeta está ok. Vamos conferir as demais armas da família"*): `FAMILY_H3_aim_MALE.blend`, 21 Agents in the long gun's aim, each with one long gun on the left hand, its trigger guard on the shotgun's (the pack's shotguns, rifles, bullpup and snipers; the sci-fi rifles, snipers and lightning gun; the three grenade launchers). The Director sizes and grips each one; then the read-back, the female, the rows. §11.6 step 2.**
> ⏭️ **2026-11-23 — THE SHOT IN STAGES (Director: *"Durante o jogo vamos pausar em cada etapa"*; `WEAPON_MASTER_PLAN` D43, `DESIGN_MASTER_PLAN` §8.7): the weapon's choice draws it; a long gun stops at the hip and waits (fire from the hip, or aim, +1 AP); at the target the whole body turns in place to it; the shot; the weapon stays where it fired until a walk or another item. The pistol the same from the target on. §11.6 step 3; take `shot_stages`.**

> ⏭️ **2026-11-22 (later) — the Director's fine adjustment of the shotgun's draw is IN THE GAME: the male as he saved it, the female in step with it (his rotations, his gun in the left hand, her right hand put back on the grip, his coat flap), and the long gun's RECOIL at the hip and aimed (`ActorRecoil3D` profiles: the trunk rocks back, the arms add the climb, the gun fixed in the hands; ratified by him as they are). ⚠️ A finger moved with G is not keyed and the game never reads it. §11.6 step 3; record: the same summary's last section.**
> ⏭️ **2026-11-22 — the SHOTGUN's draw is IN THE GAME on both figures (§11.6 step 3): the long-gun family in `ActorMesh3D` (the gun on the left hand, the draw stopping at the hip or running on to the shoulder), the hip and aimed shots in the menu, takes `shotgun_draw` / `shotgun_shot`. Read back from the timelines as they stood (the Director's fine adjustment of the male still to come). Record: `PROMPTS/RESUMO_SESSAO_2026-11-22_SHOTGUN_DRAW_IN_GAME.md`.**
> ⏭️ **v1.5, 2026-11-16 — the BASIC MOVES IN USE are CLOSED on both figures (Director: "a gente fechou os movimentos básicos em uso") and what is left is PLANNED in §11, docs only:** every held item of the canon sorted into eight HOLD families, the body postures still to make (beside cover and at a corner, standing and crouched), the throws left (from the kneel; the bowl, standing only), the fixed interactions (computer, alarms, buttons, levers, valves), the weapon models already on disk, the grenade's size defect measured (3.0× the hand's in flight), and the order of work (§11.6). **PRONE is SUSPENDED** until GAMEPLAY-01 rules whether it is viable. **Step 0 DONE (the grenade is the hand's size everywhere, 0.065 GU); step 1 ruled: ALL 21 pack firearms are used on their families' holds; then every weapon in the figure's hands (size, grip, muzzle). Nine questions wait on the Director (§11.8).**
> ⏭️ **2026-11-14 — the DASH is built: a move that spends both AP plays the Tripo figure's `run` (0.32 s/GU, phased by the ground); the idle <-> move passage is still a snap (an `AnimationPlayer` crossfade over `seek` failed: the run never showed). NEXT, by the Director: the characters turn, then idle -> run / walk passages. Record: `PROMPTS/RESUMO_SESSAO_2026-11-14_DASH.md`.**
> ⏭️ **2026-11-15 — the CROUCH is in the game on both figures (16 frames, held; standing up = the crouch backwards), and so are the crouched draw / aim / shot / holster (`draw_crouch_pistol`, a second aim layer chosen by posture; the recoil unchanged). Next: the crouch -> walk / run passage. Record: `PROMPTS/RESUMO_SESSAO_2026-11-15_CROUCH_DRAW_SHOT.md`.**

> 📌 **2026-11-15 — REMINDER, every timeline: the coat's keys follow [`docs/pipelines/timeline_coat_keys.md`](../../docs/pipelines/timeline_coat_keys.md)** (`coat_key_follow.py`): each key named by its frame (`CrouchFix_f16`), a key borrowed from the previous / next clip labelled `(inherited)` / `(next)` with that clip's frame and always locked; only the current frame's own key is editable. Run `unify_names()` on every new timeline (the builders still write the old names).

> ⏭️ **2026-11-13 — the idle's frame 90 is the start of every pose layer (a jump cut in `ActorMesh3D`, `IDLE_REFERENCE_FRAME`); the four timelines (draw / throw, both figures) are rebased to it; the female's throw coat (`ThrowFix_f09-f18`) and poses are in the game; `coat_key_follow.py` makes the active coat key follow the playhead in every new timeline. Record: `PROMPTS/RESUMO_SESSAO_2026-11-13_IDLE_REFERENCE_90.md`.**

> ⏭️ **2026-11-11 — the draw + aim PLAYS in the game from the Director's timeline, on both figures** (`AimSequence`, `sequences/<fig>/draw_pistol.json`; no finger joints in a sequence; the return as fast as the draw; the female's coat has her own `DrawFix`). The traps (edit the shape key, never the Basis; a stale prop in an old file) and the pose-lab commands are in the record: `PROMPTS/RESUMO_SESSAO_2026-11-11_DRAW_SEQUENCE.md`.**

> ⏭️ **2026-11-09 (end) — the male's draw is on one editable timeline: `ASSETS/MODELS/actors/agent/male/work/SEQ_draw_pistol_MALE.blend` (idle, draw, in-between, aim; pistol and `DrawFix` keyed). One-way so far: the read-back to the game's stops is owed once the Director has edited it; then the female's draw. Record: `PROMPTS/RESUMO_SESSAO_2026-11-09_POSE_FIXES_MOTO_ROUND.md` (last section).**

> ⏭️ **2026-11-08 (later) — the pistol aim is made IN-HOUSE (Director: "testar o que a gente consegue fazer na casa"; no credit spent).** The Tripo Agent is now the game's agent (the male by default); with the pistol selected the aim draws it from the coat (fists to the sternum, the gun appears), aims with both hands and puts it away on cancel, on both figures: a pose layer over any clip (`ActorAimPose3D`), poses from a bank frame or SOLVED from hand targets (`TripoPoseKit`), a path of stops. §4.1's "In-house levers" has what it proved, what it taught (`fire` is a long-gun hold, `shoot` a kneel) and what only credits can make. Record: `PROMPTS/DONE/RESUMO_SESSAO_2026-11-08_AIM_IN_HOUSE.md`.

> ⏭️ **2026-11-05 (later) — MV-4's first slice is BUILT and measured on the Moto (Director: board + Moto before transitions and texturing).** `TripoFigure` (one authority for dressing a Tripo Agent and decoding the bank), the game set `ASSETS/ANIMATIONS/game/agent_<fig>.res` (idle / walk / run, in place, `travel_m`; written by `tripo_game_clips.gd`, carried by the APK), `ActorMesh3D` wears the LIGHT Agent under `TRIPO_FIGURE=<female|male>` (old rig stays default: no weapons, crouch, prone, throw on the Tripo figure yet), the walk phased by the ground covered (no slide), the scenario's `walk <x,y>`, PLAYGROUND take `agent_walk`. Moto (`ACTOR` D105): 9 LIGHT Agents on a real clip +5.0 ms vs the shipped agent +6.2; the room's 10 actors as Tripo +0.2-0.3; the corrective keys ~+0.5 for 9. **The TEMPO is RATIFIED (Director, 2026-11-05: "O video está perfeito, vamos manter assim"):** the bank's `walk`, phased by the ground at D61's step (it plays at about 2.1x its own pace; D61's 2.86 m/s stands). Record: `PROMPTS/DONE/RESUMO_SESSAO_2026-11-05_MV4_BOARD_MOTO.md`.

> ⏭️ **2026-11-05 (end) — the six corrective keys are done (female `IdleFix`/`RunFix`/`WalkFix`, male `IdleFix`/`WalkFix`/`RunFix`, `ACTOR` D103) and the male's front flaps skin uniformly (D104). Next, by the Director's order: the transitions between idle / walk / run (MOVEMENT), then texturing (ACTOR), then the models in the game and on the Moto. Record: `PROMPTS/DONE/RESUMO_SESSAO_2026-11-05_CORRECTIVES_FLAP.md`.**

> 🟢 **v1.4 (2026-11-04): MV-1's bank is SAVED and CATALOGUED (Director: "temos um montão de animações que precisam ser catalogadas e salvas"; "salvas" = versioned).** `ASSETS/ANIMATIONS/bank/` is in git: 218 GLBs (female 102, male 116; 39.6 MB), `bank.json`, `CATALOG.md` and the review sheets (`sheets/`: 13 index pages by category, one sheet per clip; 11 MB). 116 clip ids, 102 complete pairs, 14 male-only variants. §3.2 has the results. Nothing in the engine changed. **Next here: the Director looks at the sheets and picks the canonical generation of the three stealth clips.**

> 🧭 **2026-11-03 — a note for MV-4 from the T-pose work (`ACTOR` D97).** Each figure carries a `TFix` shape key (the shirt's and hands' correction at the raised-arm T, value 0 = the A exactly): when the game plays a clip with the arms raised (climb, dive, the T itself), the key's value must follow the shoulder's abduction. The measured way: value = how far the Arm bone has turned from its A rest toward the T (0 at the A, 1 at the T). Nothing of this is built.

> **Status: 🟢 MILESTONE OPENED 2026-10-27 (Director: "vamos abrir a milestone de movimento e escrever o MASTER PLAN"; "vamos fazer
> um banco de animações, e depois mapear o que precisa, o que tem e o que falta").** Nothing in §3-§9 is built yet. The brief this
> ⏸ **PARKED until the models are done (Director, 2026-10-27: "vamos deixar planejado, pra fazer depois que os modelos estiverem
> prontos").** MV-1 starts once the male (with coat and hat, and without) and the female are assembled (`CHARACTER`, §9 items 1-2).
> 🟢 **2026-11-01: the two Agents are assembled, finished and measured (`ACTOR` D91-D93; light and full `.glb` in `ASSETS/MODELS/actors/agent/<fig>/game/`): the precondition for MV-1 is met; starting it is the Director's call.** First job when it starts: the bank's per-clip review sheets on the OFFICIAL files (built 2026-11-04 without coat or hat, because the coat is being replaced: the coat in motion and the armpit panel under a raised arm are still to be looked at).
> replaces (v0.1, 2026-08-16, written for the retired sprite bake) is `docs/history/MOVEMENT_BRIEF_v0.1_2026-08-16.md`; what in it is
> still design is carried into §2 below and cited there, never restated twice.
>
> **v1.3 (2026-11-02): the male's missing clips are PLANNED (§3.2), docs only.** The Director delivered `ASSETS/MODELS/actors/agent/male/source/tripo_male_ANIMATIONS.glb` (the male counterpart of the female's `tripo_female_ANIMATIONS.glb`: 100 clips on the 65-joint Mixamo rig, 21.5 MB): 30 of them are not in the bank's male side yet. Extraction and organisation: §3.2.
> **v1.1 (2026-10-28):** MV-2's map is §4.1, by clip NAME only (to confirm on MV-1's sheets), with the credits ranking and the
> Director's open questions. Docs only; nothing built.
>
> **v1.2 (2026-10-29): the bank keeps clips in PAIRS, one per figure (Director: "vamos ter que guardar elas em pares").** Test
> (Blender, clay renders, the male's `walk` on the three female models, plongée / front / side videos; the males on their own `walk`):
> a male clip PLAYS on the female with no error (same 65 joints), but even the plain female base (model 1) walks oddly with it. So
> "store rotations, any figure plays it" (§1.3, §3) is not enough for the look: the Director will re-export the animations onto the
> female from Tripo, and each clip is kept per figure. Retargeting a clip across figures stays a FALLBACK for a clip one figure lacks.

---

## 0. Ownership boundary

| Document | Owns |
|---|---|
| `ACTOR_MASTER_PLAN` §2 | the **decision register** (D-rows). Cite by number, never restate |
| `CHARACTER_MASTER_PLAN` | the **figure**: the model, the rig, the slots, how a Tripo character is assembled (`tripo_assemble.py`) |
| **this document** | **what the figure DOES**: the animation bank, the catalogue of situations, which clip plays where, how a clip is made game-ready, and how motion is judged |

The engine's actor today (`ActorMesh3D`, `godot/scripts/geometry/actor_mesh3d.gd`) drives the old 20-bone rig from `agent_live*.glb`
(D64). Moving it onto the Mixamo rig is this milestone's work (§6), because the bank is useless until the engine plays it.

---

## 1. What changed since the brief, and what it settles

1. **Characters come from Tripo on the Mixamo skeleton (`ACTOR` D85).** The motion comes with them: Tripo's AI clips, generated on the
   paid plan, so they are ours (D85's licence reading; D57 widened to geometry and outputs we own).
2. **One skeleton for every figure — MEASURED, 2026-10-27.** The female base (`female+no+coat.glb`) and the male
   (`MaleCharacterNoCoat.glb`) have the same 65 joints with the same `mixamorig:` names; their joint positions differ by about 2 % of
   the height (hips at 0.557 vs 0.552 on the 1 m figure Tripo exports). D85's open question "is Tripo's Mixamo rig identical on every
   biped" is answered for these two.
3. **A clip of one figure plays on the other — MEASURED, 2026-10-27.** The male's `walk` and `box_01` on the female, in Blender: as
   exported and with rotations only (the Hips' location scaled by the ratio of the two hips' heights, 1.009) read the same. **Rule for
   the bank (§3): keep the ROTATIONS, and the Hips' translation normalised by hip height.** Tripo keys a location on all 65 bones;
   those carry the source figure's bone lengths, and a 2 % difference is invisible today but would not be on a child, a giant or a
   cosmetic that changes the proportions.
4. **Motion is authored as ACTIONS on the live rig (D64), not baked frames.** In-betweens are interpolation; blends, layers and
   transitions happen in the engine. The brief's argument for key-poses-first (bakes are the expensive step) no longer holds as
   stated; the method survives for authored clips (§7).
5. **What stays ratified, cited:** four facings and diagonal = two orthogonal steps (D44, kept for gameplay by D64); facing changes by
   SNAP at the GU boundary, no transition frames (D47); the step is 0.56 s per GU (D61).

---

## 2. The design inputs (Director's rulings, carried from the brief)

Each is in the archived brief in full; here is the list the catalogue (§4) must cover.

| Source (brief §) | What |
|---|---|
| §2.1 M1 | A **quiet little run** on open ground: hunched head and shoulders, weapon pointing down but ready, head looking around |
| §2.1 M2 | At a GU with a **wall**: pressed against it, to show less |
| §2.1 M3 | At a **corner**: the Wolfenstein 3D cover pose |
| §2.1 M4 | **Crouched with no wall**: one knee down, the other up and bent, pistol raised, the other hand on the ground on five fingertips |
| §2.1 M5 | **Crawling**: one leg extended, the other pushing back, the weapon in front of the head |
| §2.1 | M2 / M3 depend on what is ADJACENT to the GU; `agent.gd`'s `cover_state` / `cover_direction` exist and have never driven a visual |
| §5 | The quality bar: *"falta mais 'molejo' nas articulações, mais micro movimentos"*; the 2026-08-16 hand-keyed refinement did not reach it |
| §6.4 | A looping **idle** for every entity standing still (the revealed-actor silhouette is the mesh itself on the live rig, so it follows) |
| §6.5 | **Equip, aim, fire, return, and the CANCEL of everything**: every weapon / accessory change animates both ways; the resting / alert pose depends on the situation (hurried: weapon down, two hands, head scanning; stealthy: another) |
| §7a | From liquids and gravity: down into a pit and out, wading, quicksand, crust, ice / oil slips, the agent on fire, the muzzle / throw origin at the figure's real height, rope and hook, perches |
| `DESIGN_MASTER_PLAN` | Confrontation and cover, distractions (§5.4), rope & hook + perches (§10.0), the LED cloak's crouch (D72) |

Also ruled (Director, 2026-10-26, D85's record): **Tripo's clips give the raw motion; we make them game-ready** (strip the root
motion, loops, D61's step timing, mirrors); **for cover → run → cover, generate ONE multi-segment take, cut it into pieces and chain
the pieces in code.**

---

## 3. MV-1 — the ANIMATION BANK

**What:** every clip we hold, extracted from every Tripo GLB into one place, on the canonical skeleton, with a catalogue row each.
Clips arrive inside character files (66 in `MaleCharacterNoCoat.glb` on 2026-10-27, 2 in `female+no+coat.glb`) and the same name can
come from several files; the bank makes a clip independent of the figure it was generated with.

**Design (proposed, Claude):**
- **Tool:** `tools/asset_generation/tripo/tripo_anim_bank.py` (Blender, `blender -b -P`), sharing `tripo_common.py`. Input: any number
  of Tripo GLBs. Output: `ASSETS/ANIMATIONS/bank/` (versioned since 2026-11-04): one GLB per clip (the canonical
  skeleton + that action, rotations + normalised Hips translation, §1.3) and `bank.json`, the catalogue.
- **The canonical skeleton:** the Mixamo joint NAMES and hierarchy, with the hips' height as the one length the bank records.
  Not a figure: a clip is stored as rotations, so any figure on these names plays it.
- **A catalogue row:** `id`, the source file and its original name, frames, fps, duration, the root's travel (metres per second
  horizontally, and its height range: a jump, a crouch), whether it loops (first and last pose within a measured tolerance), the
  side that leads (for a mirror), tags (locomotion / combat / reaction / gesture / interaction / idle), and a contact sheet path.
- **Pairs (v1.2, Director 2026-10-29):** a clip is stored PER FIGURE: `bank/<figure>/<id>.glb` (`figure` = `female` / `male`), and
  the catalogue row is the clip `id` with one entry per figure (`source`, frames, travel, loop, sheet). A clip the game needs exists
  for both figures; a figure missing one is flagged in the catalogue (`missing: [female]`) and may play the other figure's clip
  retargeted (rotations + Hips normalised by hip height) only as a marked fallback, never silently. The review sheet shows the pair
  side by side.
- **Duplicates:** the same name from two files is kept once if the curves match within a tolerance, both kept (`_b`) otherwise,
  reported either way.
- **Review:** a contact sheet per clip (4 frames, 3/4 and side, on ONE reference figure) and an index sheet of the whole bank, so the
  Director judges by looking (`render-dont-describe`).
- **Done:** every clip of every Tripo GLB in `ASSETS/MODELS/` is in the bank under its figure, every pair is complete or its gap
  flagged, each plays on its own base with no joint flipped
  (checked on the sheets), the catalogue is complete, a re-run is byte-identical.

---

**Built (2026-10-30):** `tripo_anim_bank.py` + `bank_sources.json` (the source GLBs and their figure). First run: 83 clips (male 83,
female 5), 5 complete pairs (`box_01`, `climb`, `dive`, `fall`, the stealth pistol run), 2 duplicates found by their rotations (not by
name), the 13 `Male+detective…` clips kept as `_b` variants. The sheets came on 2026-11-04 (§3.2).
First use, the coat stress test (`tripo_dress.py` on `COAT_BASE`, both figures; torn triangles = an edge > 1.6x and > 2 cm, per frame,
the skirt the worst region): `jump` 22-24, `fall` 31-35, `box_01` 39-46, `flip` 53-54, `front_kick_01` 59-61, `dive` 118, `climb` 111,
`sit` 150-156 (the legs through the skirt when seated).

### 3.1 What we held, in pairs (survey of 2026-10-30, before the two `ANIMATIONS` files; today's counts are in `ASSETS/ANIMATIONS/bank/CATALOG.md`)

Clip names as Tripo wrote them; a `.001` suffix is Blender's import of a second copy. The bases carry the clips Tripo generated with them.

| Clip | Female (file) | Male (file) | Pair? |
|---|---|---|---|
| `dive` (run, dive, roll, run) | `FEMALE_BASE`, `female+no+coat` | `MALE_BASE` / `MALE_AGENT_BASE`, `MaleCharacterNoCoat` | **yes** |
| `climb` | `FEMALE_BASE` | `MaleCharacterNoCoat` | **yes** |
| `fall` | `female+no+coat` | `MaleCharacterNoCoat`, `Male+detective…` | **yes** |
| `box_01` | `female+detective+figure…` | `MaleCharacterNoCoat`, `Male+detective…` | **yes** |
| stealth run, pistol pointed down (`Correr furtivamente segurando uma pistola…`) | `female+detective+figure…` | `MaleCharacterHatAndCoat` | **yes** |
| `heart_pose` | — | `MALE_BASE` / `MALE_AGENT_BASE` | male only |
| stealth hurried walk (`Caminhar apressado furtivamente`), brisk stealth walk with pistol | — | `MaleCharacterHatAndCoat`, `Male+detective…` | male only |
| the other 60 of `MaleCharacterNoCoat` (`walk`, `run`, `idle`, `jump`, `jump_down`, `flip`, `swim`, `press-up`, `sit`, `dig`, `lift_heavy`, `front_kick_01/02`, `pitch_baseball`, `run_upstairs`, hits, greetings, emotions…) and `Male+detective…`'s (`agree`, `angry_03`, `box_02/03`, `cast_a_spell`, `chop`, `defeat_03`, `fire`, `front_kick_02`, `run`) | — | as named | male only |

**Five pairs existed then** (`dive`, `climb`, `fall`, `box_01`, the stealth pistol run); since the `ANIMATIONS` files there are 102, and the female has her own `walk`, `run` and `idle`.

**Coat stress test (Director, 2026-10-30: "testar as mais absurdas, porque as normais vão funcionar sem problemas"):** before ~100 new
clips per figure are generated, the dressed coat (`tripo_dress.py` on `COAT_BASE`) is judged on the most extreme clips that exist as
pairs, `dive`, `climb`, `fall`, `box_01`, and the male-only extremes retargeted to the female only as a marked fallback (§3): `flip`,
`front_kick_01`, `jump`, `press-up`, `sit`, `swim`. A clip of another generation plays on a base by rotations (same 65 joints, §1.3).

### 3.2 The male's `ANIMATIONS` file: extract and organise (planned 2026-11-02, Director: "extrair e organizar as outras animações do male que faltavam")

**DONE 2026-11-04: steps 1-5 below, and the bank versioned; the sheets wait on the Director's eye.**
- **The dry run (`BANK_OUT=temp/work/bank_dry`, 105 s):** the new file gives exactly the 30 predicted ids, repeats 67 clips within `DUP_DEG`, and brings 3 other generations, all of the stealth clips, which land as variants and replace nothing. **A re-run is byte-identical: 218 of 218 GLBs** (§3's done line).
- **A bug the dry run would have hidden:** a third generation overwrote `<id>_b` in silence. The male's `caminhar_apressado_furtivamente` has three; the tool now finds the first free variant (`_c`) or the one a take repeats.
- **The same id is not always the same generation across figures:** the female's `correr...`, `walking...` and `caminhar...` come from her `ANIMATIONS` file, the male's from `coat_hat`; his `ANIMATIONS` takes are `correr..._b`, `walking..._b` and `caminhar..._c`, and her `correr..._b` is the `coat_hat` one. **For the Director, on the sheets: which generation is canonical for each.** `CATALOG.md` lists them all; `source` in `bank.json` says which is which.
- **The female's file has 99 clips:** the male's 100 without `dive`, which she has in `tripo_female_base.glb` and `tripo_female_nocoat.glb`. Nothing is missing.
- **Built:** `tripo_bank_catalog.py` + `bank_tags.json` (step 4: `[category, priority, use]` per id, BY NAME; a clip with no row or a row with no clip fails loudly; `priority` is §4.1's, Claude's proposal until ranked; a table edit needs only this script, nothing is extracted again), `tripo_bank_sheets.py` (step 5, 30 s for all: the LIGHT Agent without coat or hat, 4 frames, three-quarter and side, the camera following the hips, a disc on the floor so a jump reads), `--sheets` in the catalogue. Order after a new source: `tripo_anim_bank.py`, `tripo_bank_sheets.py`, `tripo_bank_catalog.py --sheets`, `godot --headless --path . --import`.
- **Seen on the sheets, for the review:** `flee_02` ends in the air (its source's Hips reach 1.85 hip heights, in both figures: the data, not the render). `loops` is only "first and last pose within 12 degrees": `run` reads "ends elsewhere" though it is a run cycle, and `climb` reads "loops" though it is not.
- **Not done:** the side that leads (for a mirror, MV-3); §4.1's rows from BY NAME to HAVE (the sheets now allow it); one sheet of a clip in motion (`actor_video.py` records one clip on the real game camera; there is no all-clips video).

**What arrived (measured 2026-11-02 by reading the file's JSON, nothing extracted yet):** `ASSETS/MODELS/actors/agent/male/source/tripo_male_ANIMATIONS.glb`, 100 clips, one skinned mesh set on the 65 Mixamo joints (the same file shape as the female's, which gave the bank its 102 female clips). The bank's male side holds 83 (from `tripo_male_nocoat` and the coat / detective files), the female's 102. Every clip of the new file already exists on the FEMALE side: with it the male side reaches the female's roster.

**The 30 the male bank lacks** (the gap is exactly the female's list minus the male's): the six `dance_01..06`; four `sing_01..04`; ball and sport, `basketball_shot`, `crossover_dribble`, `dribble`, `football_catch`, `football_pass`, `football_save`, `volleyball`, `jump_rope_01`, `jump_rope_02`; social and gesture, `clap`, `cry`, `sob`, `hug`, `swagger`, `wave_goodbye_01`, `wave_goodbye_02`; everyday, `make_a_call_01`, `play_mobile_game`, `shovel`, `surf`. None is a stealth-core clip (they would serve the hub, the ranking portrait, the shop's preview and emotes rather than the board's turn: Claude's reading, to confirm against §4.1 on the sheets), which is why the extraction is cheap and needs no engine work.

**The other 70 are clips the male already has** (from the older sources). They are NOT assumed identical: Tripo generates a clip per figure and per generation. The bank rule (§3, Duplicates) decides by rotations, not by name: identical within `DUP_DEG` = kept once, different = a `_b` copy. The male side already carries 12 `_b` (the detective file), so a careless run could double a roster the Director has already looked at. The plan therefore runs it on a SCRATCH output first and reports what it would add before anything lands in the real bank.

**Steps, in order (each a Director-visible result, none touches the engine):**
1. **Register the source:** one row in `tools/asset_generation/tripo/bank_sources.json` (`"ASSETS/MODELS/actors/agent/male/source/tripo_male_ANIMATIONS.glb"`, figure `male`). `tripo_anim_bank.py` is not edited; Blender runs with `--python-exit-code 1`.
2. **Dry run into a scratch folder** (`BANK_OUT=<scratch>`): list the new ids (expected: the 30 above), every `_b` it would add (the clip, its rotation difference to the clip it duplicates), and confirm that a re-run on the real bank's inputs is unchanged (the done line's byte-identical re-run, §3). Show the Director the `_b` list; he decides, clip by clip, which generation is the canonical one when the two differ (a clip the Director has already judged, such as the male `walk` D61's step was set from, is NOT replaced without his word).
3. **Land the 30** in `ASSETS/ANIMATIONS/bank/male/` and `bank.json` (the real run); the catalogue's pairs then read complete for every clip both figures have; the one clip the female still lacks is the second stealth pistol run (`_b`).
4. **Organise:** the catalogue's `tags` field (MV-1's design, never filled): a category per clip (locomotion, combat, reaction, gesture, interaction, idle, and a seventh, `showcase`, for dance / sing / sport / social, the clips for the hub and the shop, never the board), the side that leads, and the stealth-core flag from §4.1. Done by a script from the names plus the Director's edits to one small table, so a new file only needs its rows added.
5. **Review sheets** for the 30 (4 frames, three-quarter and side, the pair male | female), on the official figures' own bases, rendered, not described (`actor_video.py` records a bank clip in the four real facings; a Blender contact sheet is the cheaper first look). The Director marks what is wrong (a joint flipped, a foot sliding, a pose that is wrong for the character); a rejected clip is flagged in the catalogue, never deleted.
6. **Update §3.1 and §4.1** with the real counts (male 113 or fewer, female 102) and the new `showcase` rows; §4.1's questions about the Tripo-credits ranking are unchanged (these 30 cost no credits).

**Traps recorded:** a clip id is a slug cut at 48 characters, so the two long stealth names collapse to the same id as before (already handled: `correr_furtivamente_...`, `caminhar_...`); Blender's `.001` suffix marks a copy and is removed from the id; the bank, its catalogue and its sheets are versioned since 2026-11-04 (Godot's sidecars stay out), and so are the source GLBs (Director, 2026-11-02: "vamos guardar no git porque tem as principais animações. Os modelos eu acho que podemos guardar todos"): `tripo_male_ANIMATIONS.glb` (21.5 MB), `tripo_female_ANIMATIONS.glb` (21.8 MB) and the Tripo bases / no-coat generations (`.gitignore` no longer excludes them; the JPEGs Godot extracts beside a GLB stay out, they are regenerated on import); Godot's import cache must be refreshed after the bank changes (`godot --headless --path . --import`) before any capture; the hip height differs per figure (male 0.5525 m, female 0.5575 m): a clip's Hips translation is stored divided by it, so the pair plays at each figure's own scale.

## 4. MV-2 — THE MAP: what the game needs, what the bank has, what is missing

**What:** one table, the situation catalogue the brief asked for (brief §3) crossed with the bank. Lives in this plan as §4.1 once
built. Each row:

| Column | Meaning |
|---|---|
| Situation | a game state that needs its own motion (posture × tempo × cover × weapon × stealth, and the world: pit, liquid, rope) |
| Need | the clip(s): a loop, a one-shot, an enter / exit pair, a transition |
| Have | the bank clip that serves it as is, or with processing (§5) |
| Combine | how to get it from bank clips with no generation: layers, blend, mirror, retime, a cut (§5) |
| Missing | what only a new generation gives; priced in Tripo credits |
| Priority | what the demo needs first |

**The first pass, from the bank's names alone (2026-10-27; to be checked against the clips themselves):**
- **Probably have:** `idle`, `standing_relax`, `wait`, `look_around` (idle family); `walk`, `run`, `run_upstairs`, `turn`, `jump`,
  `jump_down`, `climb`, `flee_01/02` (locomotion); `shoot`, `fire`, `box_01-03`, `front_kick_01/02`, `slash`, `chop` (combat);
  `hit_to_body_01/02`, `hit_to_head`, `hit_to_side`, `hit_to_stomach`, `fall`, `dive`, `defeat_02/03` (reactions); `sit`, `dig`,
  `lift_heavy`, `swim`, `press-up`, `make_a_call_02` (interactions); a set of gestures and emotions for the cast (`agree`, `bow`,
  `greet_*`, `laugh_*`, `angry_*`, `scared_*`, `afraid`, `frightened`, `fold_arms`, `complain_*`, `frustrated_*`, `depressed`, `cheer`).
- **Missing, the stealth core (the credits' priority, Claude's proposal):** (1) a crouched / sneaking walk (M1; the old male model
  had "Caminhar apressado furtivamente", not in the new 66); (2) wall cover: press against it, peek, fire from it, and the
  multi-segment cover → run → cover take of §2 (M2, M3); (3) a takedown from behind; (4) a grenade throw (`pitch_baseball` is a stand-in);
  (5) crawl (M5) and the one-knee crouch (M4); (6) rope and hook. Equip / holster / reload / aim-idle per weapon class are likely
  missing too.

### 4.1 The map (v1.1, 2026-10-28) — BY NAME, to confirm on the bank's sheets (MV-1)

> **2026-11-16:** this map is the survey of 2026-10-28, made from the clips' names. What has been built since (§11.0) and the plan for what is left (§11: hold families, body postures, interactions, the order of work) are the later word: where a row here and §11 disagree, §11 wins. The rows §11 does not touch (reactions, the world, cast gestures, the guards' idles) stand.

**Every "Have" below was matched on the clip's NAME only; no motion was looked at.** A row moves from BY NAME to HAVE when its
sheet (§3; `ASSETS/ANIMATIONS/bank/sheets/`, since 2026-11-04) shows the motion fits. Sources: `MaleCharacterNoCoat.glb` (66 clips, plain names), `MaleCharacterHatAndCoat.glb` (three
custom stealth takes, names truncated by the exporter; written here as **S1** "Caminhar apressado furtivamente", **S2** "Correr
furtivamente segurando uma pistola apontada para baixo e…", **S3** "Walking briskly and stealthily, holding a pistol with both
hand…"), `female+no+coat.glb` (`dive`, `fall`, duplicates of the male's: §3's duplicate rule). Correction to §4's first pass: the
stealth walk was NOT lost, S1-S3 are in the coat-and-hat file. Every locomotion clip also gets §5.1 (root motion out) and §5.2 (tempo);
the Combine column names only what comes on top. Priority: **P0** = the demo cannot ship without it, **P1** = the demo is poorer
without it, **P2** = after the demo. Priorities are Claude's proposal, for the Director to rank (§10's done line).

#### Locomotion on the grid (D44 four facings, D47 snap, D61 0.56 s / GU)

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Walk, open ground | loop | `walk` | loop cut (§5.3) | — | P0 |
| Run (hurried, chase) | loop | `run`, `flee_01/02` (panic run, guards / civilians) | loop cut; tempo from design | — | P0 |
| Start / stop a move | enter / exit | — | snap (D47) from idle; author only if the snap reads badly | maybe a stop, judged blind | P2 |
| Facing change | snap | `turn` (in place) | D47 says snap: `turn` only for an idle actor turning without a step, if ever | — | P2 |
| Stairs (up / down) | loop | `run_upstairs` | down = ? (reverse plays badly on stairs) | walk up / down stairs, if the maps keep stairs (single plane canon: question 6) | P2 |
| Step down into a pit / climb out (brief §7a.1) | one-shot each | `jump_down`, `climb` | retime to the depth; threshold open | — until §7a.1's depth rule is set | P2 |
| Jump a gap | one-shot | `jump` | — | — | P2 |

#### Stealth (M1, the LED cloak D72, styles D70)

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Sneak walk, no weapon out (M1) | loop | **S1** | loop cut; head scan as an additive (§5.6) if S1 has none | — if S1 is hunched enough | P0 |
| Sneak, pistol down two hands (M1, brief §6.5 item 5) | loop | **S3** (walk), **S2** (run) | S2 / S3 upper body over S1's legs gives "sneak + weapon" at every tempo (§5.6) | — | P0 |
| Look around while standing (M1 scanning) | additive / loop | `look_around` | head / neck-only mask as an additive on any idle or move | — | P1 |
| Crouch, no wall (M4: one knee, hand on the fingertips) | enter / loop / exit | — | — | the M4 pose as a hold + down / up | P1 |
| Crouched move | loop | — | — | a crouch walk (half cover's transit, §8.2) | P1 |
| Crawl / prone (M5, minimal cover §8.2) | enter / loop / exit | `dive` (a way down?) | `dive` cut to its landing as the enter, if it lands prone | crawl loop, get up (1 AP and a pin, §8.2) | P1 |
| Cloak on / off (D72, 1 AP each, standing still) | one-shot each + held still | `idle` underneath | the cloak is a shader on a still figure; the switch may be a gesture layer | a small "activate" gesture, if wanted (question 4) | P1 |
| Style swap normal ↔ black (D70: the pack takes the coat, gloves on) | one-shot each way | — | — | both directions (D70's two-way rule; brief §6.5) | P1 |
| Mask on / off (D71: hat forward, plates rise) | one-shot each way | — | upper-body layer over any idle | both directions | P2 |

#### Cover (`DESIGN` §8.2-§8.4; M2, M3)

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Full cover against a wall (M2) | enter / loop / exit | — | mirror for the other side (§5.4) | pressed-to-wall hold, in and out | P0 |
| Corner cover (M3, Wolfenstein) | enter / loop / exit | — | mirror (§5.4) | corner hold | P0 |
| Peek and fire from full cover (§8.3) | enter / one-shot / exit | `shoot` (upper body) | `shoot` masked over a lean-out pose | the lean-out | P0 |
| Cover → run → cover (§2: one take, cut) | one multi-segment take | — | cut into enter / run / exit and chained (§5.5) | the one take, both sides by mirror | P0 |
| Half cover, crouched behind a low object (§8.2) | enter / loop / exit | — | could reuse M4 (question 3) | a crouch-behind hold | P1 |
| Fire from half cover | one-shot | `shoot` | upper body over the crouch hold | — if the mask holds | P1 |
| Fire from prone (50 % aim, §8.2) | one-shot | — | — | prone fire | P2 |

#### Weapon flow (brief §6.5: select, aim, fire, return, cancel; `WEAPON` classes)

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Draw / holster, pistol (both ways) | one-shot each | — | holster = draw reversed only if it reads right (the grenade's cancel does this today) | draw, holster | P0 |
| Draw / holster, long gun (shotgun) | one-shot each | — | — | draw, holster | P1 |
| Aim, held while the hit chances are computed (brief §6.5 item 3) | loop | `shoot` (first frames?) | cut its aim frames into a held loop + breathing additive | an aim idle, if `shoot` has no clean hold | P0 |
| Fire with recoil | one-shot | `shoot`, `fire` | upper-body mask so it plays standing, crouched, in cover | — | P0 |
| Alert rest, weapon up (in cover) / down (moving) | loop | **S2** / **S3** (down) | their upper body over idle | weapon-up rest | P1 |
| Reload | one-shot | — | upper-body layer | reload per class | P2 |
| Grenade: raise, throw, cancel (exists today on the old rig) | one-shot ×3 | `pitch_baseball` (stand-in, §4) | cancel = raise reversed (today's `play_throw_cancel`) | an overhand / lob grenade throw | P0 |
| Throw a stone (distraction, `DESIGN` §5.4) | one-shot | `pitch_baseball` | shorter, underhand if possible: retime / cut | a lob (could share the grenade's) | P1 |
| Dart launcher (knockout at range) | one-shot | `shoot` | as the pistol | — | P2 |
| Place C4 / set the alarm clock (`DESIGN` §5.4) | one-shot | `dig` (crouch and work?) | cut a short kneel-and-place | a place-on-floor / on-wall | P2 |
| Melee: chokehold (knockout), neck snap (`DESIGN` §10, the knockout every class must hold) | paired one-shot (agent + guard) | `box_01-03`, `front_kick_01/02`, `slash`, `chop` (none is from behind) | — | **the takedown from behind, paired** | P0 |

#### Reactions

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Hit (body / head / side / stomach) | one-shot | `hit_to_body_01/02`, `hit_to_head`, `hit_to_side`, `hit_to_stomach` | additive flinch over any pose (§5.6); mirror for the other side | — | P1 |
| Death / knocked down | one-shot + held | `defeat_02/03`, `fall` | hold the last frame as the body (it is minimal cover, §8.4) | a death from cover / prone | P1 |
| Knocked out, then waking after N turns (`DESIGN` §10) | one-shot + loop + one-shot | `fall` | hold; reverse to get up? | wake up / get up | P1 |
| Surprised / startled guard (PATROL → SUSPICIOUS, AI FSM) | one-shot | `afraid`, `frightened`, `scared_01/02` | cut to a short start | — | P1 |
| On fire (brief §7a.3) | loop | `flee_01/02`, `freaky`? | + the status tint already built | patting down / running to water | P2 |
| Smoke / gas (gas bomb knocks out, 2 turns) | one-shot + held | `fall` | — | coughing | P2 |

#### The world (brief §7a)

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Rope and hook: throw, cross, land (`DESIGN` §10.0) | one-shot ×3 | `pitch_baseball` (throw), `climb` | cut `climb` for the cross; the rope is a mesh | the hand-over-hand cross, the hook throw | P1 |
| Perches: climb up, watch, swing, drop onto a guard | several | `climb`, `jump_down` | — | swing, the drop takedown (paired) | P2 (later, by the canon) |
| Wading (legs under the surface) | loop | `walk` | slower retime + the surface clips the legs | — maybe | P2 |
| Quicksand: sinking, the 2 AP escape | loop + one-shot | — | — | struggle, pull out | P2 |
| Slipping on ice / oil | one-shot | `fall` | cut the slip | a slip-and-recover | P2 |
| Swimming (`MATERIALS` F9) | loop | `swim` | — | — | P2 |

#### Interactions

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Open a door / use a switch, a valve (`DESIGN` §5.4 scenery) | one-shot | — | — | a reach-and-turn | P1 |
| Pick up an item / search a knocked-out guard | one-shot | `lift_heavy` (too heavy?), `dig` | cut a crouch-reach | a pick-up, a search-the-body | P1 |
| Drag / carry a body | loop | `lift_heavy` (the lift only) | — | drag loop (question 5) | P2 |
| Knock an object over (a distraction) | one-shot | `front_kick_01` | cut | — maybe | P2 |
| Lockpick (`DESIGN` evidence room) | loop | — | — | a kneel-and-pick | P2 |
| Phone (the phone cloner; a guard's radio) | loop | `make_a_call_02` | upper body only | — | P2 |
| Sit (civilians, guards on a break) | enter / loop | `sit` | — | — | P2 |

#### Idle

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Agent idle (brief §6.4) | loop | `idle`, `wait` | loop cut; breathing additive | — | P0 |
| Guard idle on post / patrol pause (AI PATROL) | loop | `standing_relax`, `idle`, `fold_arms`, `scratch` | variety by picking a different one per guard | — | P0 |
| Guard searching (SEARCH, SUSPICIOUS) | loop | `look_around` | over a slow walk (upper body) | — | P1 |
| Guard alert, weapon raised (ALERT, CHASE) | loop | — | S3's upper body? (it is the agent's two-hand pistol) | an alert idle with a weapon | P1 |
| Civilians idle (crowd sets, `COSMETICS` §8) | loops | `play_video_game`, `warm_up`, `press-up`, `standing_relax`, `make_a_call_02` | variety | — | P2 |

#### Cast gestures (NPCs, the cutscene-free dialogue of `DESIGN` §2.3)

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Agree, greet, bow | one-shot | `agree`, `greet_01-04`, `bow` | upper body over idle | a "no" (disagree) | P2 |
| Anger, complaint, frustration | one-shot | `angry_01-03`, `complain_01/02`, `frustrated_01/02` | — | — | P2 |
| Joy, fear, sadness | one-shot | `laugh_01/02`, `cheer`, `scared_01/02`, `afraid`, `depressed`, `defeat_02/03` | — | — | P2 |
| Civilian flees and trips the alarm (AI table) | loop | `flee_01/02` | — | — | P1 |
| Unassigned (no situation yet) | — | `cast_a_spell`, `flip`, `freaky`, `dig` beyond its uses above | kept in the bank, unused | — | — |

#### In-house levers (2026-11-08, Director: "como podemos otimizar isso, e testar o que a gente consegue fazer na casa"; the pistol aim was the test)

**The test, built and seen on both figures** (`pistol_aim` take, PLAYGROUND; record `PROMPTS/DONE/RESUMO_SESSAO_2026-11-08_AIM_IN_HOUSE.md`): with the pistol selected, the aim opens and the agent
brings both fists to the sternum, the gun comes OUT OF THE COAT there (no holster: the Director's ruling), the arms extend into a two-handed aim, and cancel / firing runs the same
path back, the gun going away at the chest. No clip was generated. What carries it:

| Lever | What it is | Status |
|---|---|---|
| **A pose from a clip frame** | one key of any bank clip, for the bones listed, kept as `pose_<id>` in the game set (`TripoFigure.POSES`) | built, proven (the fingers' grip) |
| **A pose SOLVED from where the hands go** | `TripoPoseKit`: two-bone IK on the rig's rest data (law of cosines, an elbow pole), the hand turned as asked, each bone's twist kept from the idle arm; both wrists land on their targets to the millimetre (`tripo_figure_selftest`) | built, proven (aim, draw) |
| **A layer over any clip** | `ActorAimPose3D` (a `SkeletonModifier3D`): a bone subset pulled toward the pose by a weight, over idle / walk / run | built; over the idle proven, over a walk not looked at |
| **A path of stops** | a list of poses at weights (idle -> fists at the sternum -> aim), a smoothed slerp between, so the arms come to rest at each stop; the reverse is the lowering | built, proven (draw, hold, stow) |
| **A prop tied to the weight** | the pistol in the right hand, hidden below a weight, grown in from 35 % at the chest | built, proven |
| Mirror, reverse, retime, cut, loop (§5) | pure transforms of a bank clip | not built, cheap |
| Aim at the target's real angle | the same kit with the target in the figure's frame: the arms could follow the guard past D44's four facings | not built |
| Additives (breathing, a head scan, a flinch) | small bone offsets over anything | not built |

**Refining the key poses by hand, in Blender (Director, 2026-11-08: "eu monto a base, você faz o ajuste fino"; built the same day).** The solver is the BASE, the Director's pose is the truth:
`python3 tools/persistent/pose_lab.py open aim_pistol --figure male` builds `ASSETS/MODELS/actors/agent/<fig>/work/POSE_<id>_<FIG>.blend` (the LIGHT Agent in the pose the game has today, the unnamed bones as the idle has them,
the dressed pieces only, the pistol as the object `PROP_pistol` parented to the hand) and opens it; he poses in Pose Mode, moves the pistol, saves; `pose_lab.py save aim_pistol --figure male --take` writes
`ASSETS/ANIMATIONS/poses/<figure>/<id>.json`, rebuilds the game set and films the take. A pose file REPLACES the solved pose (`TripoFigure.POSE_FILE`); the weapon's placement is IN the pose (one per stop,
blended between the stops like the arms), so "push the pistol forward" is a move of that object; an existing .blend is never rebuilt over his work; `reset` sets his file aside. **The conversion is not guessed:**
Godot dumps every bone's rest rotation, the Blender script derives each bone's frame correction from it, and the result was checked against Blender's OWN glTF exporter read back in Godot (26 bones to 6e-7, the
prop's placement to 1e-7), and by a rehearsal (a pistol pushed 3 cm in Blender showed 3 cm further on the board). The same pose file plays on both figures; the female has her own .blend when she needs a retouch.
Files: `tools/persistent/pose_lab.py`, `tools/asset_generation/tripo/tripo_pose_lab.py`, `godot/scripts/tools/tripo_pose_dump.gd`; a pose needs only the key poses, the engine blends (§4.1 levers).

**The two-handed grip (2026-11-08, Director's references: cup and grip, arms extended, sights on the line of the eyes).** `tools/asset_generation/tripo/tripo_pose_grip.py` writes it into a lab `.blend`: the pistol first (level, rear sight at the eyes' height, on the head's mid-plane), then the hands from it (right palm on the flank, index on the trigger, three fingers wrapped, thumb along the left flank; left palm up under the butt, fingers curled over the right hand's), both figures. `ASSETS/ANIMATIONS/poses/<figure>/aim_pistol.json` now plays in the game. `ActorAimPose3D` takes the bones of every stop, because the hand-made aim keys the last finger joints and the draw's clip has none. The Director's earlier `.blend` (the pistol 1.4 cm forward) is kept as `ASSETS/MODELS/actors/agent/male/work/POSE_aim_pistol_MALE_HAND_v1.blend`. Not done: the head does not tilt into the sights (it would need the draw stop keyed too); the draw pose keeps the solved grip.

**The stance (2026-11-08, Director: the idle sways, it must not be mixed in).** The aim and draw poses key the WHOLE body (all 65 bones and the Hips' place, `hips_pos` in the pose file, a position track `ActorAimPose3D` reads): the left foot stays, the right goes half a step back (0.115 of the figure's height) with the toes turned out 74°, the pelvis follows and the spine turns back to the target; `tripo_pose_grip.py` solves the legs and then the grip on the new torso. The draw stop is the middle of the step, foot in the air. The aim is for standing still only: walking lowers the gun (`ActorMesh3D._update_aim`). Superseded above: the head does tilt now, and the draw has its own file.

**What the lab must count, and the Moto (2026-11-09).** A prop's mesh node is part of its placement, ROTATION as much as scale: `pistol.glb`'s node is turned -90 degrees about X, and a lab that divided only the scale out gave a pistol right in Blender and a quarter turn off in the game (`prop_node_matrix`). A joint is a ROTATION: the game plays rotations and the Hips' place only, so a bone moved with G shows a gap in Blender and lands elsewhere in the game (`extract` warns). The draw stop holds the pistol exactly as the aim does (same grip, barrel pitched up 46 degrees). **Moto g04s, uncapped: the aim layer + pistol cost nothing measurable** (19.55 ms, GPU 17.9, before and during; render CPU +0.55, PSS +0). Opening the shot menu holds one frame for 72-134 ms, the same with the old rig (A/B): `technical_debt.md`. Record: `PROMPTS/RESUMO_SESSAO_2026-11-09_POSE_FIXES_MOTO_ROUND.md`.

**What the test taught (so it is not rediscovered):**
- **`fire` is a standing LONG-GUN hold, not a pistol aim, and it has no recoil:** its two hands are 30 cm apart (a rear grip and a fore-end), its torso twisted and its pelvis yawed and leaned
  25 degrees; its keys vary by < 0.002. It is the shotgun / rifle aim, once those have a model on the new figure. **`shoot` is a run into a KNEEL**, not a standing aim.
  `walking_briskly...pistol` (S3) and `correr_furtivamente...pistol` (S2) hold the fists at the belt / chest, 17 cm apart: a close carry.
- **Copying a pose's arms onto another torso fails when the clip's pelvis is not ours:** `fire`'s arms laid on the idle torso pointed 31 degrees down and 17 sideways; re-solving only the clavicles
  left the hands 20 cm apart in depth (the clip's torso was twisted so that they met). The arms are SOLVED, not copied.
- Godot traps met: a headless script cannot trust `Skeleton3D.get_bone_global_pose` after setting poses (forward kinematics on the rest data is used instead); `Quaternion.angle_to` leaves a ~7e-4 rad
  floor between two IDENTICAL quaternions (compare components); a `SkeletonModifier3D` outside the engine's frame has no skeleton (`apply_to(skeleton)` is the testable entry); the pistol glb's mesh node
  carries a x100 scale (its AABB reads 100x too small unless the node is in the tree).

**What this changes in the credits' ranking below:** item 3 (draw / holster, pistol, an aim hold) is **done in-house for the pistol**. By the same rule the upper-body-only rows (hands up, a radio at the ear, reload at the
belt, a point, a head scan, a flinch) are candidates for the kit before a generation. **What the kit cannot make** is whole-body motion with weight, ground contact and timing: crouch / crawl and their transitions, the takedown from
behind, cover enter / peek / exit, the real grenade throw, climbing, hit and fall reactions. Those are where credits go. Two more savers: **a clip generated for ONE figure serves the other** (the bank stores rotations and the
Hips normalised by height; the 102 pairs are half the spend if the female shares the male's), and **mirroring doubles** every asymmetric one (a corner on either side).

#### Credits: what to generate first (Claude's ranking, for the Director)

1. **The cover take** (§2's ruling): wall press → lean out and fire → back → run → corner, one multi-segment take, cut and mirrored.
   One generation serves four P0 rows (full cover, corner, peek, cover → run → cover).
2. **The takedown from behind, paired** (agent + guard as one take): the non-lethal option every class must hold; nothing in the bank
   comes close.
3. ~~**Draw / holster, pistol**, plus an aim hold~~ **done in-house for the pistol (2026-11-08, the lever table above)**; a shotgun / rifle draw and the aim of a crouched or prone figure remain.
4. **The grenade throw** (overhand, with a lob variant that also serves the stone): replaces `pitch_baseball`.
5. **Crouch (M4) with crouch walk, and prone / crawl (M5) with get up**: half and minimal cover.
6. **Style swap (D70) and the knocked-out guard waking up.**
7. **Interactions**: door / valve, pick up / search a body.
8. **Rope and hook** (throw, cross), then the world rows.

Before spending on 1-5: confirm S1-S3 on their sheets. If S1 is not hunched enough for M1, a sneak walk goes to the top of this list.

#### Open questions for the Director (nothing here is decided)

1. **This ranking**: is the stealth core (cover, takedown, weapon flow) the demo's first, as proposed, and P0 / P1 / P2 right per row?
2. **One figure's clips for both sexes and the guards?** The rig allows it (§1.3); is a female walk / run a separate generation, or
   does the female share the male's clips?
3. **Half cover and M4:** is the crouched-behind-a-low-object pose the same as M4 (one knee, hand on the fingertips), or its own?
4. **The cloak (D72) and the style swap (D70):** does switching on the cloak have a visible gesture, or only the shader? Is the
   style swap a full-body take (the pack absorbs the coat) or an upper-body layer?
5. **Bodies:** can the agent drag / carry a knocked-out guard? (It decides a loop and its AP cost; `DESIGN` does not say.)
6. **Stairs:** do the maps keep walkable stairs on the one playable plane, or is `run_upstairs` a cast clip only?
7. **Guards' weapon poses:** do guards draw / holster as the agent does (brief §6.5's two-way rule), or start ALERT with the weapon
   already up?
8. **The pit threshold (brief §7a.1):** from what depth is a step down a drop (`jump_down`) and a step up a climb (`climb`)?
9. **Unassigned clips** (`cast_a_spell`, `flip`, `freaky`): keep for the cast, or drop from the bank?

---

## 5. MV-3 — making a clip GAME-READY (the processing, all in our code)

Each item is a transform on a bank clip; the bank keeps the raw clip, the game uses the processed one (so a better rule re-runs).

1. **Root motion stripped:** Tripo bakes the travel in the Hips (D85: the run goes 3 m in 1.29 s). The engine moves the actor (D61);
   the clip keeps the Hips' vertical motion and loses the horizontal, and its measured speed is recorded (it decides the playback
   rate on the grid).
2. **Step timing (D61):** a locomotion loop is retimed so its stride lands on 0.56 s per GU (walk); run and sneak get their own
   tempo from the design, never from the clip.
3. **Loops:** the cut points chosen where the pose repeats (measured), and a short cross-fade where it does not.
4. **Mirror:** left / right by the Mixamo names (`Left*` ↔ `Right*`); doubles every asymmetric pose (a corner on either side, M3).
5. **Cut and chain:** one long take cut into enter / loop / exit pieces, chained by the engine (the cover take of §2).
6. **Layers:** lower body from one clip, upper body from another, by bone mask (walk + aim, run + weapon down, idle + reload);
   additive layers for small overlays (breathing, a flinch, looking around: M1's scanning head may be an additive, not a clip).
7. **Transitions:** D47's default is snap; a transition is authored only where the Director judges a snap bad, blind (the D47
   method).

---

## 6. MV-4 — the engine plays the bank

- **`ActorMesh3D` on the Mixamo rig:** bone names (`mixamorig:Head`, `mixamorig:RightHand`, `mixamorig:LeftHand` replace `head`,
  `hand_R`, `hand_L`), the weapon and hand attachments, the head turn (`actor_head_turn3d.gd`), the muzzle / throw origin read from
  the real head (fixes §7a item 4 for free if it reads the posed bone, as it already does).
- **One `AnimationLibrary` built from the bank, shared by every actor** (one skeleton), loaded once.
- **An `AnimationTree` per actor:** the state machine (idle / move / cover / aim / fire / react), blend spaces for tempo, the layer
  masks of §5.6.
- **Scale and import:** the 1 m Tripo figure to the game's height (D85's import steps); the four facings and the snap (D44, D47) are
  the actor's yaw, untouched by the clip.
- **✅ Measured 2026-11-05 (`ACTOR` D105): it fits** (9 LIGHT Agents on a real clip +5.0 ms, under the shipped agent's +6.2). The original note: **65 joints against today's 20**, on every actor, with an `AnimationTree` each. RAM is the constraint (D42),
  and the Moto g04s is the floor device (`PERFORMANCE_BUDGET` PB-0). Measure before building the state machine: N actors on the
  Mixamo rig playing a clip, on the Moto, against today's rig (`device_run.py`), uncapped (`MAX_FPS=0`). If it does not fit, the
  options are a reduced skeleton for guards (the fingers are 30 of the 65 joints) or fewer distinct clips loaded at once, and the
  Director chooses.
- **🏁 CLOSED 2026-11-12 (Director: "Podemos fechar então idle + saque + mira + tiro + holster para os dois modelos"): the pistol cycle on BOTH
  figures** — idle, the draw (the Director's timeline, `SEQ_draw_pistol_<FIG>.blend`, coat `DrawFix`), the aim, the shot (below) and the
  holster (the same timeline read back, as quick as the draw). The male's `DrawFix` was re-edited the same day (103 vertices, in the GLB).
- **✅ The pistol SHOT (2026-11-12, Director: "o recoil, o braço reage levemente, e volta pra posição AIM", and a spent case):** procedural, no
  clip. `ActorRecoil3D` (a modifier after the aim layer) pitches both arms, forearms and wrists about the gun's lateral axis (1.5 / 3 / 7 deg,
  up in 35 ms, eased back by ~0.3 s); the gun itself kicks 6 deg about the grip and 12 mm back; the aim is held 0.6 s after the shot
  (`ActorMesh3D.SHOT_HOLD_S`) before the controller's lowering. `ShellCasings3D` (one `MultiMeshInstance3D` per board) throws the case from
  the port to the shooter's right, it bounces on `stand_height` up to three times and STAYS for the map (cap 256, oldest reused; a lying case is
  its 48-byte transform, no per-frame cost). Not kept by the checkpoint (HERITAGE T5, built later). Take `pistol_shot`.

---

## 7. MV-5 onwards — the situations (after the map ranks them)

Built in the map's priority order; each one done = the Director has seen it on the board (a capture through `capture.py`, desktop,
HUD off) and ratified it. Expected order, to confirm on the map: locomotion on the grid (walk / run / sneak, the idle, the stop) →
cover (M2, M3) → weapon flow (§6.5 of the brief: equip, aim, fire, return, cancel) → reactions (hit, fall) → crouch and crawl (M4,
M5) → the world (pit, liquid, rope: brief §7a).

**The throw (2026-11-12, BUILT standing overhand on both figures; take `grenade_throw`):** one timeline per figure
`SEQ_throw_overhand_<FIG>.blend` (the Director's), coat keys `ThrowFix_f<frame>` on the same timeline, read back by `pose_lab.py sequence
throw_overhand`; rulings (right hand, automatic style, whole body turns, bowl = low toss and roll, the in-play flow) in the study's §5.1/§6.
NEXT: the female's skirt fix, then underhand, bowl, kneeling. The study: [`PROMPTS/THROW_STUDY_2026-11-12.md`](../THROW_STUDY_2026-11-12.md): styles
(overhand, underhand, bowl, sidearm) x postures, the trajectory picks the animation, the grenade leaves the posed hand, `pitch_baseball`
cut to frames 36-48, fingers never keyed, four open questions.
**2026-11-16 (Director):** the female's throw is in the game (2026-11-13). The throws to make next are **the throw from the kneel** and
**the bowl, STANDING ONLY** ("jogar granada boliche (somente em pé)": this narrows the study's §4 table, where the bowl was also kneeling
and prone). The underhand toss and the sidearm are not scheduled (§11.8, question 7); the prone throw is suspended with prone (§11.1).

**For a clip we have to make (credits or none):** key poses first, in-betweens second (the brief's method, §2.2), now meaning: the
pose stills are agreed before a generation is spent.

---

## 8. Quality, and how it is judged

- **The bar is the Director's eye:** *"molejo"*, micro-movement, coherence with the situation (an infiltrator under threat, not a
  neutral cycle: brief §2). Tripo's clips are AI-generated whole-body motion, which is the kind of secondary motion the hand-keyed
  pass lacked; whether they reach the bar is judged on the bank's sheets, not assumed.
- **Blind comparisons** where there is a choice (the D47 / D61 method).
- **On the handset:** motion is judged at the zoom of play on a real phone video (`device_record.py`) before a situation is closed.

---

## 9. Prerequisites and open questions

1. **The model lock (brief §6.0, Director 2026-10-08).** D85 settles the SOURCE (Tripo, Mixamo) and the skeleton is shared (§1.2), so
   the bank (MV-1) and the map (MV-2) do not wait on it. What does wait: anything keyed to a figure's attachments (the weapon in the
   hand, the hat, the coat's skirt in motion). The male with coat and hat is being generated (2026-10-27).
2. **The assembly's rules on the male** (`tripo_assemble.py`, measured 2026-10-27): the forearm sleeves went to the hands, the hair to
   the hat on a hatless model, the ears to the hair, and Tripo segmented his belt as a part of its own, which the band search does
   not expect. `CHARACTER`'s work; it blocks the male's figure, not the bank.
3. **The brief's §6 "five items first"** (2026-08-16) predate the later milestones: the shot from the agent that misses into a wall is
   on the board (the `SHOT_AGENT_CELL` / `SHOT_GUARD_CELL` captures), glass, fabric and cardboard closed with `MATERIALS` (M2,
   2026-10-11; soft materials 2026-10-17). The enemy variant: to confirm against the guards' current look. None blocks the bank.
4. **How much of the catalogue is a layer, not a clip** (§5.6). M1's scanning head, the weapon held down while running, breathing:
   each one that works as an overlay saves a clip on every tempo.
5. **Can the numbers be computed without disturbing the animation** (brief §7 item 6: the prediction on a worker): stands.
6. **The cost of 65 joints on the Moto** (§6): ✅ measured 2026-11-05, `ACTOR` D105.
7. **⏳ OWED — every weapon's size, set in the Agent's hands (Director, 2026-11-11).** A weapon is ALWAYS the size it was given in the
   Agent's hands: in the hand, on the floor, on a table, as a pickup (`HERITAGE_AND_LOOSE_ENDS_PLAN` §5 item 2; no readability factor
   for the floor copy). Only the **pistol** is certified (2026-11-09, x1.107; the method is in the session record
   `PROMPTS/RESUMO_SESSAO_2026-11-09_POSE_FIXES_MOTO_ROUND.md`): the shotgun, the rifle, the grenade and every later import are each
   certified the same way, by hand, once, with the figure holding it, and its MUZZLE measured off the model at the same time (`weapons/<id>.json` `model.muzzle`, HERITAGE T2 W4). Until then a weapon is drawn at its model's own size and the
   engine WARNS that its hand size is not certified (built with HERITAGE T2 W2). Lands with each weapon's pose on the Tripo figure.
   **2026-11-16: the grenade is measured (in flight 3.0× its size in the hand, §11.5) and the certification round is planned: §11.6
   steps 0 to 2 (the models already on disk and where the lab opens each: §11.5).**

---

## 10. Stages

| Stage | Deliverable | Done when |
|---|---|---|
| **MV-1** | The bank: `tripo_anim_bank.py`, `ASSETS/ANIMATIONS/bank/`, `bank.json`, the sheets | 🟡 **2026-11-04: built, versioned and catalogued (§3.2).** Done when the Director has looked at the sheets (no joint flipped) and picked the canonical generations |
| **MV-2** | The map (§4.1): need / have / combine / missing / priority; the credits list | 🟡 **v1.1 (2026-10-28): §4.1 written, BY NAME (clips not yet seen); waits on the Director's ranking and §4.1's open questions** — done when the Director ranks it |
| **MV-3** | The processing (§5) on the first situations' clips | each processed clip judged on a sheet |
| **MV-4** | The engine plays the bank (§6), the Moto measured first | 🟡 **2026-11-05: first slice built and measured** (D105: an actor walks the grid on the Mixamo rig, `TRIPO_FIGURE`); open: the tempo, weapons / postures / throw, the AnimationTree, the LIGHT with the corrective keys |
| **MV-5+** | The situations in the map's order (§7) | 🟡 **2026-11-16: the basic moves in use are CLOSED on both figures (§11.0)**; each further one ratified on the board and on a handset video |
| **MV-6** | What is left (§11): every weapon in the hand (size, grip, muzzle), the poses and the shot per hold family, the cover bodies, the throws left, the devices and the fixed interactions | 🟡 **planned 2026-11-16, nothing built**; done step by step in §11.6's order, each on both figures and ratified on the board. Prone is suspended (GAMEPLAY-01) |

---

## 11. What is left after the basic moves: the arsenal's postures, cover, throws, interactions (planned 2026-11-16)

> **Director, 2026-11-16:** *"agora a gente fechou os movimentos básicos em uso"*; *"Vamos dar uma organizada no que ainda falta"*; *"antes
> vamos fazer o planejamento e registrar os próximos passos no MOVEMENT MASTER PLAN"*. **Docs only: nothing in this section is built.** What
> is the Director's is quoted or marked; the rest is Claude's proposal until he rules (§11.8).

### 11.0 Closed: the basic moves in use (both figures, in the game)

| Move | What is in the game | Record |
|---|---|---|
| Idle | the loop; its frame 90 is where every pose layer starts and ends | 2026-11-13 |
| Walk | 0.56 s / GU, phased by the ground; an authored start and stop | 2026-11-05, 2026-11-14 |
| Run (the dash) | 0.32 s / GU; an authored start, two stops (one per foot), the stride evened so the stop lands on the cell | 2026-11-14 |
| Turn | on the first tap, toward the destination; standing and kneeling | 2026-11-14, 2026-11-16 |
| Crouch | the kneel (16 frames, held); standing up is the crouch backwards | 2026-11-15 |
| Crouch → walk, crouch → run | the rise, chosen by the gait | 2026-11-15, 2026-11-16 |
| Pistol | draw, aim, shot (recoil, spent case), holster; standing and kneeling | 2026-11-12, 2026-11-15 |
| Throw | overhand, standing (the grenade); the cancel is the raise backwards | 2026-11-12, 2026-11-13 |

Their small tails (coat keys left empty, the re-kneel at the end of a move begun from the crouch, takes never filmed) are in the session
records and wait for the polish or for GAMEPLAY; none blocks what follows.

### 11.1 The Director's list (2026-11-16)

1. **PRONE is SUSPENDED.** *"Ainda temos o modo deitado, atingido a partir do agachado, mas precisamos ver se isso vai ser viável no
   gameplay. [...] podemos deixar suspenso por enquanto, com uma nota na milestone de gameplay."* Nothing prone is made (M5, §4.1's prone
   rows, the throw study's prone row) until GAMEPLAY-01 rules it (`docs/production/milestones.md`; `DESIGN` §8.2). The code keeps the
   state (`Agent.Posture.PRONE` with its multipliers; the Z key lowers standing → crouch → prone); the Tripo figure has no prone motion.
2. **Body postures to make:** standing beside cover; crouched beside cover; standing at a corner; crouched at a corner.
3. **Throws to make:** the grenade thrown from the crouch; the bowl, **standing only**.
4. **The other weapons:** draw, holding and aim for each ("as posturas aim/holding/draw com as outras armas"), then the shot.
5. **Interactions:** operating a computer, switching off alarms, pressing buttons, operating levers and valves.
6. **A defect:** the grenade leaves the hand giant (§11.5).
7. **The order:** survey the canon's items, weapons, gadgets and each faction's technology for the postures they need (this section)
   → one public model per weapon → each mounted in the figure's hand for its size, and its muzzle marked → the postures and the shot
   animation of each.

### 11.2 How a posture is counted: HOLD × BODY × STOP

The canon names about 45 held items (`MODEL_INVENTORY` §3). They are not 45 sets of poses:

- **HOLD** = what the hands do with the object: a two-handed pistol grip, a shouldered long gun, a thrown object. Eight families cover
  every item, and a ninth row lists what needs no hold (§11.3).
- **BODY** = what the legs and the trunk do: standing, the kneel, at a wall, at a corner. Made once each, whatever is in the hands (§11.4).
- **STOP** = where in the flow: **draw → hold → aim → fire / use → stow**.

The pistol is already built this way: the aim is a layer over the body, and the crouched draw is the kneel's legs under the standing
draw's arms (2026-11-15). The plan makes it the rule: **a body posture is paid once and every hold lies on it; a hold is paid once per
family and every item of the family reuses it.**

**What differs between two items of one family is DATA in the item's row, never a pose:**
- the model and its certified size (§9 item 7);
- up to five POINTS OF THE MODEL: the **grip** (the right hand's placement, today's `model.hand`), the **support** (where the left hand
  holds), the **butt** (where a stock meets the shoulder), the **muzzle** (`model.muzzle`, built with HERITAGE T2 W4) and the **port**
  (where a spent case leaves);
- the **recoil**: how far it kicks, how many times, whether a case flies.

With those points the pose kit (`TripoPoseKit`: the hands go to targets) SOLVES the family's poses for any member; the Director's
timeline on the family's reference weapon stays the truth the others inherit.

### 11.3 The hold families, and every item of the canon in one

Sources: `DESIGN` §5.4 (distractions), §10.0 (the start kit), §10.2-§10.4 (weapons, visors, gadgets), §11.6-§11.7 (specialists, stores,
counter units), §15 (the tree); `WEAPON` §5 (the engine's catalogue); `MODEL_INVENTORY` §3. Where the canon has not said how an item is
USED (the EMP, the shadow generator, the camera-loop rig, the sound and firework lures, the sonic weapon), its family is Claude's reading.

| # | Family: the hold | Items | Status |
|---|---|---|---|
| **H1** | **Handgun, two hands:** cup and grip, arms out, the sights at the eyes | common pistol (start kit) ✅ · suppressed pistol = the pistol + the suppressor (FID L2: an attachment, so the muzzle moves forward) · revolver (`WEAPON`: more kick, no case) · taser (FID L1) · the dart launcher if it is a pistol (§11.8 Q5) | ✅ the pistol, standing and kneeling. The others are rows of data |
| **H2** | **Compact automatic, two hands close** (the "uzi"): the right hand on the grip, the left under the magazine well or on a fore-grip, the gun at the chest line | `smg` (`WEAPON`) | to make: H1's body with other hand targets; the shot is a BURST |
| **H3** | **Long gun, shouldered:** the butt in the right shoulder, the left hand on the fore-end, the cheek on the stock, the body bladed | shotgun (`CONE`; a pump after the shot, optional) · assault rifle (burst) · sniper rifle (the eye goes to the scope; the kneel is its natural stance) · suppressed rifle (Calm Waters L1) · pulse carbine (L2) · laser (L3) · plasma (Corporation L3) · sonic weapon (FID L3, shape undefined) · the pack's bullpup · the guards' anti-drone gun | to make, the largest block. The bank's `fire` IS this hold (measured 2026-11-08: hands 30 cm apart, the torso twisted, the pelvis yawed 25°, no recoil in it); `shoot` ends in a kneel |
| **H4** | **Thrown object:** one hand, the right | frag grenade ✅ · smoke, flashbang, gas, incendiary · the EMP if thrown (Q6) · sound lure, firework lure · **stone**, baseball, glass or bottle, can (`DESIGN` §5.4: "the bread and butter") · the rope's hook | ✅ overhand, standing. To make: from the kneel; the bowl (standing only). The item is a prop and its size; the throw is shared |
| **H5** | **Placed object:** on the FLOOR (kneel and place) or on a WALL (stuck at chest height) | C4 (`WEAPON` §5.2: "placed rather than thrown") · breaching charge (Bunsen Burners L3) · the EMP if placed (Q6) · tripwire flash (L1) · alarm clock, radio-clock (start kit) · shadow generator, camera-loop rig (Corporation L1) · a bug (`DESIGN` §14.2: "planting bugs") | to make. From the kneel the floor reach is the arms alone. Bank `dig`, BY NAME |
| **H6** | **Hand device, one hand,** three ways: POINT AND PRESS (the arm out at a target), PRESS AT THE CHEST, TO THE EAR OR MOUTH | point: universal remote (`DESIGN` §5.4), spray can (start kit: at a camera, the arm raised) · chest: the **detonator** (Director, 2026-11-16; not yet an item of the canon, Q4), phone cloner, radio scrambler · ear or mouth: radio (the spoof, FID L1), phone · shown or handed over: keycards and forged credentials (the swipe itself is I1), the cash envelope (a bribe) | to make. The point is H1's right arm alone. Bank `make_a_call_01/02`, BY NAME |
| **H7** | **Two-hand device:** both hands at the belly, the head down | the scout drone's controller (Calm Waters L1; `DESIGN` §10.4's recon drone) · the guards' tablets (forensic tech, feed monitor) | to make. Bank `play_mobile_game`, BY NAME |
| **H8** | **Contact, PAIRED with the victim** | chokehold, neck snap, chloroform (start kit) · shock weapon, knife, fist (`DESIGN` §10.2) · zip ties, searching and interrogating a downed guard · the perch drop (later) | not on today's list. Whole-body motion for two: credits (§4.1's ranking, item 2) |
| — | **No hold** | goggle modes, motion and noise detectors (passive) · the LED coat (cloak, wardrobe), the turning tie, the reversible coat (`DESIGN` §10.5-§10.6) · silent boots, armour, the exoskeleton | at most a small gesture (§4.1's stealth rows stand) |

**The world's objects (fixed interactions).** The Director's four (computer, alarms, buttons, levers and valves) and what the canon adds:

| # | Interaction | Objects | How |
|---|---|---|---|
| **I1** | **PRESS / FLIP:** one hand to a point | button · light switch · **alarm panel** · electrical panel (`DESIGN` §4.4) · keypad · card reader (the swipe) · fire alarm · a door's handle | ONE pose solved to the object's point, at any height from the knee to overhead; never one per object |
| **I2** | **TYPE:** two hands at desk height, a loop | **terminal / computer** (`DESIGN` §14.2: "reach a terminal") · control panel · server console | a short loop, with its way in and out |
| **I3** | **LEVER:** grab, then pull or push | wall lever (shoulder height) · floor lever (hip height, two hands) · a breaker's handle | one or two takes, by height |
| **I4** | **WHEEL:** two hands turning, a loop | **valve** (`DESIGN` §5.4: steam, water) · the sluice gate's wheel (§14.2) | a loop, with its way in and out |
| **I5** | **KNEEL AND WORK:** both hands low, a loop | lockpick (FID L2) · tying or searching a body (with H8) · a floor hatch | the kneel's legs + the arms |
| **I6** | **PICK UP** | from the floor (a stone pile, a dropped item, the alarm clock taken back) · from a table (a glass, a weapon lying as scenery) | two reaches |
| **I7** | **MOUNT / RIDE** | the getaway bike (Bunsen Burners L2; an extraction at marked points, `DESIGN` §15) | later, with the bike's model |

**What the interactions need from the props** (owner: `PROP_PIPELINE_PLAN`, PP7's stateful props; a note for that plan, not designed
here): an interactive slot names its INTERACTION ANCHOR, which is the point the hand reaches, the type (I1-I7), and the cell and facing
the actor stands on. The pose is solved to the anchor; no pose is authored per object.

**Added 2026-11-16 (Director, through `ITEMS_MASTER_PLAN` §2.9):** **H9 shoulder launcher** (the bazooka), **M1 one-hand melee** (knives,
daggers, batons, coshes), **M2 two-hand melee** (the katana, a bat), **W worn on the forearm** (the wrist blade: lethal, tranquiliser or a
berserk poison; maybe the grapple). The hand crossbow for tranquiliser darts is H1 (the pistol's grip); brass knuckles are the FIST (the
punch, a mesh on the hand); the grapple also PULLS guards and objects and triggers things at a distance (its hold is open there, §5 Q3).

### 11.4 The body postures, and what lies on each

| # | Body | Status | To make |
|---|---|---|---|
| **B1** | Standing (the idle's frame 90) | ✅ | — |
| **B2** | The kneel | ✅ with its rises | — |
| **B3** | Standing beside cover (M2: pressed to the wall; `DESIGN` §8.2's full cover) | to make | in, hold, out; the LEAN OUT and back (§8.3's peek) |
| **B4** | Crouched beside cover (`DESIGN` §8.2's half cover, behind a low object) | to make | from the kneel: in, hold, out; the RISE OVER the top and back |
| **B5** | Standing at a corner (M3) | to make | in, hold, out; the lean around the corner |
| **B6** | Crouched at a corner | to make | the same, from the kneel |
| **B7** | Moving with the weapon out (M1: "weapon pointing down but ready") | **PLANNED, later** (Director, 2026-11-17: §11.6 step 10) | gaits of its own, at least a stealth run with the weapon; NOT the gun fixed in the hand of today's walk and run (tried and rejected the same day). Until then the convention of §11.6 step 10: the weapon goes away before any move |
| **B8** | Prone | **SUSPENDED** (§11.1) | — |

What lies where:

| | B1 standing | B2 the kneel | B3-B6 cover | B7 moving |
|---|---|---|---|---|
| **H1** pistol family | ✅ | ✅ | the lean out, under B1's / B2's arms | later (step 10) |
| **H2** compact | to make | to make | as H1 | later (step 10) |
| **H3** long gun | to make | to make (the kneel already has the left forearm over the left knee: one move from the braced rifle kneel, the elbow on the knee) | as H1 | later (step 10) |
| **H4** throw | ✅ overhand; the bowl to make | overhand to make | later, with the cover (the study's step-out and sidearm) | — |
| **H5** placed | to make | to make | — | — |
| **H6** hand device | to make | to make | free (one hand) | — |
| **H7** two-hand device | to make | to make | — | — |
| **I1-I6** | to make | I5 | — | — |

- **The other side of a cover posture** is the BODY mirrored by the joint names (§5.4). The hold is NOT mirrored: the right hand stays the
  gun hand (the throw's ruling, 2026-11-12) and the kit solves the arms on the mirrored trunk. Whether a right-handed lean around a LEFT
  corner reads right is judged on the first one built. (`ACTOR` D45 rejected mirroring baked FRAMES, which flipped the figure's own
  asymmetries; a mirrored pose leaves the mesh as it is.)
- **Coat keys:** a new timeline gets its keys by `docs/pipelines/timeline_coat_keys.md`, created EMPTY, and they are edited only where the
  Director asks (the coat's polish is deferred, 2026-11-12). A mirrored pose has no key of its own.
- **The size of the work (Claude's estimate, to scope it, not a count):** about 25 to 30 authored timelines per figure: the four cover
  bodies with their lean-outs, H2 and H3 standing and kneeling, two throws, the small ones of H5-H7, I2-I6. Plus one solver (I1) and the
  shots, which are data. H8 is apart (credits).

### 11.5 The models on disk, their sizes, and the grenade's defect

**The firearms are already on disk.** The pistol in the game is one of 25 CC0 models of Quaternius's Ultimate Guns Pack
(`ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_ultimate_guns_pack/extracted/`; local only, like all of `ASSETS/`):
pistols ×4, revolvers ×3, submachine guns ×2, shotguns ×4 (two full, a short stock, a sawed-off), assault rifles ×3, a bullpup, sniper
rifles ×4, and four attachments (scope, bipod, tripod, bayonet); the guns are 746 to 2 778 triangles each. **For the rifle, the shotgun, the sniper
and the "uzi" nothing needs downloading unless the Director rejects a look** (whether either submachine gun reads as an Uzi is for his
eye, on the sheet of step 1).

Measured 2026-11-16 from the files (each model's box through its node transforms). The certified pistol is the pack's
`Pistol-52kQzphmeF` at ×0.0600: 0.180 GU long in the hand. The same factor on the others is where the lab OPENS them, not their size:

| Model (the pack's plain one of each) | Native length | Triangles | At the pistol's factor |
|---|---|---|---|
| Pistol (certified 2026-11-09) | 2.45 | 1 878 | 0.180 GU / 0.29 m ✅ |
| Revolver | 1.98 | 1 046 | 0.146 GU / 0.23 m |
| Submachine Gun | 4.04 | 1 374 | 0.297 GU / 0.48 m |
| Shotgun Sawed Off | 3.69 | 956 | 0.271 GU / 0.43 m |
| Shotgun | 5.78 | 746 | 0.425 GU / 0.68 m |
| Assault Rifle | 5.42 | 1 304 | 0.398 GU / 0.64 m |
| Bullpup | 5.25 | 2 778 | 0.386 GU / 0.62 m |
| Sniper Rifle (two of the four are longer: 7.29) | 6.34 | 1 344 | 0.466 GU / 0.75 m (0.536 GU / 0.86 m) |

The Agent stands 1.225 GU (1.96 m). ⚠️ The sheet of step 1 measures the male LIGHT Agent at **1.08 GU with the hat** (0.882 GLB
units × `WORLD_SCALE` 1.225), not 1.225: the gun-to-body PROPORTION is the game's either way (both hang off the same bones), but a
length in metres derived from 1.225 GU = 1.96 m reads ~12 % short. Which height is canon is not settled here. **The pack is not to one real scale: its pistol is large for its long guns** (a 0.29 m pistol beside
a 0.64 m rifle), so a long gun will probably grow in the Director's hands. That is what the by-hand rule is for (§9 item 7).

**To source or to make (nothing on disk):** the suppressor; the taser; the dart launcher; the late guns (pulse carbine, laser, plasma,
sonic: L2-L3, they reuse H3 and can wait); the other grenades' bodies; C4 and its detonator; the universal remote, the spray can, the
chloroform bottle, the alarm clock, the radio, the phone, the drone's controller, lockpicks, zip ties, cards; the stone, the baseball,
the bottle, the can; the rope and hook. CC0 only (`ACTOR` D57); the sources already used and recorded in `props/MODEL_SOURCES.md` are
Quaternius (through Poly Pizza) and Poly Haven. **The simple ones (a stone, a can, a card, the remote, the detonator, the C4 block, a
suppressor) are cheaper MADE by a script than searched.**

**The grenade leaves the hand giant: measured 2026-11-16.**
- In the hand it is the size the Director gave it in the throw timeline: 0.066 GU tall on the male, 0.064 on the female
  (`sequences/<fig>/throw_overhand.json`, the prop's scale 0.0897 / 0.0868, on a model 0.605 tall in its own units).
- In flight and on the floor `GrenadeProp.FIT_SIZE` fits it into a 0.2 GU box (its own comment: "a handheld at twice its real size
  reads"): **3.0× the hand's** on the male, 3.1× on the female.
- The ruling already exists (`HERITAGE_AND_LOOSE_ENDS_PLAN` §5 item 2: a weapon is always the size it has in the Agent's hands, with no
  readability factor). The grenade simply has no certified row yet: `TripoFigure.HELD_PROPS` carries only its path.
- **The fix:** the grenade gets a row with ONE certified size (the two timelines' 3 % difference becomes one number); the hand and
  `GrenadeProp` both read it and `FIT_SIZE` goes; its shadow and its fuse point follow the size. It changes a look: the `grenade_throw`
  take before and after.
- ✅ **FIXED 2026-11-16 (step 0).** `bombs/frag_grenade.json` has a `model` block (path, materials, `height_gu` **0.065**, the two
  timelines' 0.066 / 0.064 made one, `size_certified` 2026-11-12, the day the Director sized it in the throw timeline). `BombDef`
  reads it; `BombRegistry.shared()` is the process's one registry (the weapons' W1 pattern). `GrenadeProp` (flight, floor), the aim's
  ghost (`TargetCursorOverlay`) and the hand (`TripoFigure.held_prop_scale`, applied by `ActorMesh3D` over the timeline's per-figure
  scale) all draw that one height; `FIT_SIZE` is gone, the shadow is 0.7 × the height, the fuse point follows the fitted box. Before /
  after: the `grenade_throw` take on PLAYGROUND (male), frames 160-172 (`temp/grenade_size/`). The hand changes by ~2 % on each figure.

### 11.6 The order of work (the Director's order, detailed)

Each step lands on both figures before the next; a step with a look ends in a capture shown in the chat.

0. ✅ **The grenade's size** (§11.5, fixed 2026-11-16).
1. ✅ **The model sheet** (rendered 2026-11-16, `tools/asset_generation/weapons/gun_model_sheet.py` -> `temp/model_sheet/`).
   **Director, 2026-11-16: "Vamos usar todas, aproveitando as mesmas empunhaduras"** — ALL 21 firearms of the pack are used (pistols ×4,
   revolvers ×3, submachine guns ×2, shotguns ×4, assault rifles ×3 + the bullpup, sniper rifles ×4), each on its family's hold
   (§11.3): one set of poses per family, a model only brings its points (size, grip, muzzle, support, butt, port). Each model is a
   WEAPON of its own (Q10, ruled: its shot results are GAMEPLAY-01's). Open: whether the size is set by hand per model or per family (Q11). One contact sheet of the pack's 25 models and the grenade, to scale beside the figure. The Director picks one
   model per weapon (the pistol stays). The list of what to source or make for H5-H7, each source recorded in `props/MODEL_SOURCES.md`.
2. **Each weapon in the figure's hands** (the 2026-11-09 method, once per weapon): a lab file per weapon, the figure in the family's
   base pose (solved by the kit), the weapon opened at the pistol's factor. The Director sets the size and the grip by hand. Read back
   into the weapon's row: `model.hand` and `size_certified`; `model.muzzle`, proposed by a script (the centre of the foremost vertices
   along the barrel) and confirmed on a render with a marker; and the points its family needs (`support`, `butt`, `port`). The table
   copy and the pickup take the same size by themselves (HERITAGE T2 W2).
   **2026-11-17: H1's lab file BUILT** (`tools/asset_generation/weapons/family_lab.py`, `ASSETS/MODELS/actors/agent/male/work/FAMILY_H1_aim_MALE.blend`):
   a line of 17 Agents frozen in the game's aim (`SEQ_draw_pistol_MALE_arm6.blend` @ `aim` = 23), one model each on the RightHand,
   opened at the pack factor 0.0600 or a length relative to the certified pistol, its origin at its GRIP ANCHOR (top-back of the grip)
   placed on the reference's: 4 pistols, 3 revolvers, taser, hand crossbow, flare gun, 3 sci-fi pistols, ray gun, grapple launcher
   (ITEMS Q3 open), 2 suppressors on a copy of the pistol's muzzle. Next: the Director sizes them; the READ-BACK (fit each source
   model's vertices to their final place in hand space: size + grip offset vs the reference) is written then; the female's file is
   built from the male's sizes, for the grip check.
   **2026-11-17 (later): H1 SIZED by the Director, read back and ON THE BOARD.** Ruling: *"vamos ter a família que usa a mesma
   postura [...] e dentro dela variações de modelo que são armas individuais. Todas vão usar o mesmo mecanismo da pistola normal,
   com algumas variações de stats [...] acompanhar cada uma em uma ficha, inclusive porque algumas não disparam bullets"*. So each
   model is a ROW (`weapons/<id>.json`, `held_as: "pistol"`): pistol_compact, pistol_service, pistol_tactical, revolver (the existing
   row, now with a model), revolver_snub, revolver_long, taser, hand_crossbow, flare_gun, scifi_pistol_a/b/c, ray_gun, grapple_gun.
   `family_lab.py readback` fits each source to its place in the hand (Umeyama; every residual ~1e-7: no reshaping) relative to the
   reference; `family_rows.py` writes `model.held_like` {weapon, scale, pos, quat} (the model's glTF frame in the pistol model's),
   `muzzle` (the foremost vertices' centre, shown as beads on the lab render) and `size_certified`; new rows copy the template's shot
   numbers (GAMEPLAY-01 sets each one's), the taser / crossbow / flare / grapple with no wall damage and `gameplay.projectile`.
   Engine: `ActorMesh3D._hold_model` swaps the model in the pistol's holder (the timeline places the reference, the model rides by
   `held_rel`) while the gun is in the coat; the muzzle and the case follow. Dev key 2 pressed again walks the family. Take
   `h1_family` (PLAYGROUND) draws all 15. Not done: the suppressors (attachments, no row yet), a shot fired from each muzzle on the
   board, the female's file.
   **2026-11-17 (end): the female's file built FROM the male's sizes** (`family_lab.py build ... <male readback>`), sized by the
   Director and read back: 9 models sit 1 to 5 mm apart in her hand (pistol_compact, the revolvers, taser, flare, two sci-fi, ray,
   grapple), so a row may carry `held_like.figures.female` (`WeaponDef.held_rel_for(figure)`; `family_rows.py --female`). The
   crossbow is the DIRECTOR'S edited one (`temp/inspect/hand_crossbow.blend` exported into `sources/hand_crossbow/hand_crossbow.glb`;
   the script's v1 kept as `hand_crossbow_v1_script.glb`; re-running `hand_crossbow.py` would overwrite his), put into both lab files
   by `family_lab.py swap` (old source fitted to the placed mesh, the new one given the same transform). Both figures filmed firing
   all 15 (`h1_family_shot`, `INFILTRAITOR_TRIPO_FIGURE`): every shot leaves from the model's muzzle.
   **Grips EXPLICIT per figure (Director, 2026-11-17):** the grip stays RELATIVE TO THE REFERENCE (the timeline places the pistol at
   every stop; an absolute hand place would only fit the aim), but each row names `held_like.figures.male` AND `.female`, none
   inherited (*"eu conferi nos dois na realidade, mas por acaso às vezes estava certo"*): a figure a row leaves out is warned at load.
   The Director's grapple is swapped in too (`grapple_launcher_v1_tripo.glb` keeps Tripo's).
   **The SUPPRESSOR (Director, 2026-11-17): a mountable ACCESSORY, on the bullet pistols only** (pistol, pistol_compact,
   pistol_service, pistol_tactical; not the revolvers, the taser, the crossbow, the flare, the sci-fi or the grapple). Rows
   `attachments/<id>.json` (`AttachmentDef` / `AttachmentRegistry`: `kind` muzzle, `fits`, `gameplay`, `model.mount` = the model
   in the reference pistol's frame relative to its muzzle, read off the lab; on another pistol it sits on THAT pistol's muzzle in
   its units; `model.muzzle` = where the round now leaves). Two from the lab (suppressor_a / _b) and six by script
   (`tools/asset_generation/items/suppressor_variants.py`: round short / long, square, square long, triangle, hex, in suppressor
   A's frame and mount). In game: `ActorMesh3D._hold_attachment`; dev key 5 cycles what fits the held weapon; take step
   `attach <id|none>`; takes `suppressed_shot`, `suppressor_variants`. Filmed on both figures: the round leaves the suppressor's
   end. Each suppressor will have its own attributes (silences more or less, takes more or less damage, hurts accuracy):
   **the attribute sheet of every weapon and attachment is the GAMEPLAY milestone's** (Director, same day).
   **2026-11-23: the shotgun's size CERTIFIED and H3's lab file BUILT** (Director: *"A certificação do tamanho da escopeta está ok.
   Vamos conferir as demais armas da família"*; and *"Não vamos fazer playtest por enquanto. Se tiver algum erro corrigimos depois"*: the
   stages of the shot are not played by hand for now). `weapons/shotgun.json` `size_certified` 2026-11-23 (x0.085 of the pack's units,
   the size the timeline holds; its load warning is gone). `family_lab.py build H3 male` ->
   `ASSETS/MODELS/actors/agent/male/work/FAMILY_H3_aim_MALE.blend`: 21 Agents in the long gun's AIM as the game plays it (the
   Director's `SEQ_draw_shotgun_MALE.blend` at `aim` = 31, opened and never saved), each with one model on the LEFT hand (the timeline
   keys the long gun there): 01 the certified shotgun as the timeline holds it, then the pack's 3 other shotguns, 3 assault rifles, the
   bullpup, 4 sniper rifles, and the sci-fi set's 3 rifles, 2 snipers and the lightning gun, and the 3 grenade launchers (`ITEMS` §2.10
   files them all under H3). Every model with its TRIGGER GUARD on the shotgun's and its barrel along the shotgun's, its mesh in the
   figure's units about the trigger guard (Scale 1.0 at the start, S scales about the trigger); the pack's at the shotgun's own factor,
   the others at a length relative to it (sci-fi rifles 0.95, snipers 1.1, lightning gun 0.8, launchers 0.8, the stockless MGL 0.65).
   **The frames and anchors are EXPLICIT per model** (`FAMILIES["H3"]`), measured on side renders: the H1 guesses fail on long guns (the
   grip-low rule put the bullpup, one sniper, three sci-fi rifles and the lightning gun barrel-backwards; one launcher lies on its side in
   its file; the grip anchor lands on the butt); the trigger guard is the side silhouette's hole in front of the grip, picked by eye
   where there are several. The read-back stores and reads those frames (`lab_mesh_frame`, `lab_gun_frame`); checked on the untouched
   file (every model x1.0 of its start, residuals under 4·10⁻⁷) and on H1's file (the 14 rows' grips and muzzles reproduced exactly).
   Render: the tiles only (`render ... temp/h3_family/<prefix>`; a long gun seen from the front reads as nothing). **For the Director's
   eye:** the bullpup and the two P90-style sci-fi rifles have the trigger far forward of the butt, so with the right hand on the trigger
   their butt goes into the body (the one pose cannot move the hand); the sawed-off, the short stock and the MGL-style launcher have no
   shoulder stock (sized here in the shouldered aim only; their aim is H2's way). Next: he sizes and grips each model and saves; the
   read-back; the female's file built from the male's sizes; then the rows (`family_rows.py` gets an H3 table) and the engine's long-gun
   holder for `held_like`. ⚠️ H1's file names its sources by the layout before 2026-11-19 (`ASSETS/MODELS/sources/`): its read-back
   stops at the taser until those paths are mapped (`props/`).
   **2026-11-23 (later still): H3 splits into FIVE lab scenes, one per animation group** (Director: *"vamos separar um pouco as
   armas porque as animações vão ter que ser um pouco diferentes. Shotguns, rifles, sniper, scyfi e grenade launcher. Este último não
   tem posição mirada, vai ser só cintura, e provavelmente usando outra empunhadura"*): shotguns, rifles, snipers, sci-fi, grenade
   launchers, in place of the one 21-Agent file above for the sizing (nothing was sized in it: its md5 unchanged). **The grenade
   launchers have NO aimed stage: the hip only** (the snipers stay the aim only, the shotguns and the rifles both), probably on a grip
   of their own, not yet designed. Before the split the Director re-checks the grip at the certified AIM (*"acho que o cabo da arma
   não está bem posicionado"*) in his `SEQ_draw_shotgun_MALE.blend` (opened for him at `aim` = 31, never saved by Claude): if he
   moves it, the shotgun's clips are read back again (the female in step) and the five scenes are built on the new aim. The groups
   (Director, on the two sci-fi snipers: *"Com os snipers"*): shotguns = the certified shotgun, `Shotgun-ZmPTnh7njL`, the sawed-off and
   the short stock; rifles = the three assault rifles and the bullpup; snipers = the pack's four and the two sci-fi snipers; sci-fi = the
   three sci-fi rifles and the lightning gun; grenade launchers = the three, the sci-fi one included (its hip-only animation sets its
   group: Claude's reading, stated to him with the launchers' scene at the hip, `hip` = 23, on the shotgun's grip until theirs exists).
   **Built 2026-11-23 (night), on his new aim** (step 3's last bullet): `family_lab.py build H3_<GROUP> male` ->
   `FAMILY_H3_SHOTGUNS_aim_MALE.blend` (01-04), `FAMILY_H3_RIFLES_aim_MALE.blend` (01, 05-08), `FAMILY_H3_SNIPERS_aim_MALE.blend` (01,
   09-12, 16, 17), `FAMILY_H3_SCIFI_aim_MALE.blend` (01, 13-15, 18) and `FAMILY_H3_LAUNCHERS_hip_MALE.blend` (01, 19-21, at `hip` = 23);
   `H3_GROUPS` derives each from H3's one list and keeps its numbers. Checked: every model read back from its group file sits, relative
   to the reference, where it sits in the one H3 file, rebuilt on the new aim and as first built on the old one (50 comparisons: scale
   identical, position within 2·10⁻⁵ of the reference's units, turn 0.0000°); his timeline's md5 unchanged by the builds. The one
   21-Agent file stays on disk as it is (nothing was sized in it). Tiles: `temp/h3_family/h3s_male_groups_sheet.png`. Next: he sizes and
   grips each scene and saves; then each read-back, the female's five files from the male's, the H3 rows, the engine's holder.
   **The grip per weapon goes to the POLISH (Director, 2026-11-23: *"Vamos colocar essa questão da pegada individual por arma pra fase
   de polimento e seguir como está"*).** The lab's read-back reads the guns only (each one's size, place and turn against the
   reference, in the left hand); every model of a family plays the family's one body (the shotgun's timeline), so a skeleton changed in
   a lab scene stays in the file. A body per weapon (each lab Agent's changed bones read as that model's own stop poses, the hip in a
   scene of its own, the female per weapon, the draw's lapel and centre still the family's) is POLISH-01's
   (`docs/production/milestones.md`). Until then a lab scene sizes and places the guns only. **The shotguns' scene:** his save of 22:43
   changed no gun and no bone (`lab_diff` against the build), then *"Pode abrir a próxima cena"*: the four stay as built, each x1.0 of
   the reference's units (the sawed-off 0.64 of the reference's length, the short stock 0.77).
   **The rifles' scene, and the first grip of its own (2026-11-24).** His save of 00:37: the three assault rifles moved 4-9 mm at their
   built size (x1.0 of the reference's units: 0.94, 0.89 and 0.95 of its length); the BULLPUP x0.75 (0.68 of the shotgun's length) on a
   body of its own, 26 bones re-posed (both arms, both hands, the fingers; nine finger joints also moved with G, which the game
   ignores). The Director: *"A última arma especificamente tem um design diferente, então eu tive que modificar o esqueleto. Vamos já
   deixar essa empunhadura salva. Precisamos checar o hip em seguida."* So the grip is SAVED and the polish ruling above stands:
   `family_lab.py grip` writes that Agent's whole pose, the bullpup in its own left hand, as a pose file,
   `ASSETS/ANIMATIONS/poses/male/grip_bullpup_aim.json` (`TripoFigure`'s format, `tripo_pose_lab.Rig`'s maths; proven on Agent 01,
   which gives back `seq_draw_shotgun_f31.json`: the 65 bones and the Hips identical, the shotgun within 6·10⁻⁸). Nothing in the game
   reads it before POLISH-01; its prop key is the lab model's name until the H3 rows name the weapon. The read-back now gives a
   re-posed Agent's model twice: `rel_*` on the FAMILY's body (where he put it, read in the reference Agent's hand: what the one body
   shows; the bullpup turned 19.6° against the reference) and `own_grip` in its own hand (turned 103°: that hand turned 111°). A probe of
   the H1 files (both figures) and of the shotguns' save found no re-posed Agent, so nothing read before changes. **The rifles' HIP:**
   `build H3_RIFLES male <out> <read-back> --marker hip` -> `FAMILY_H3_RIFLES_hip_MALE.blend`, the line at the timeline's `hip`
   (frame 23) on his sizes, every Agent on the family's hip (the bullpup on the family's body too); read back as built, every model sits
   exactly where the aim's read-back put it; his timeline's md5 unchanged. Next: he checks the rifles at the hip (the bullpup's hands at
   least) and saves; a bullpup re-posed there is kept the same way, as `grip_bullpup_hip.json`.
   **The rifles DONE; the bullpup's own timeline (2026-11-24, later).** His save of the hip scene (01:34) left 05-07 as built (*"As
   demais estão prontas"*: the three assault rifles are sized, x1.0 of the reference's units, the aim's places at the hip too) and
   re-posed the bullpup's Agent (30 bones; four fingers also moved with G): `grip_bullpup_hip.json`. Then: *"Ainda vai ficar faltando o
   draw, porque ele vai ter que segurar em outra parte do cabo. Vamos montar no Blender toda a sequência da mira só com essa arma."*
   `family_lab.py seq <family timeline> 08 <out> hip=<hip lab> aim=<aim lab>` -> `SEQ_draw_bullpup_MALE.blend`: his shotgun timeline
   with the bullpup in the shotgun's place. At 23 and 31 the lab Agents (the rotations and the Hips; a finger moved with G is not
   carried) with the bullpup in their hands; up to the centre (16) the family's body, the bullpup held at its own hold point (0.82 of its
   length, in the lab's explicit gun frame: the guessed one turns it barrel-backwards) wherever the shotgun is held; the hand slides along
   it from 16 to 23 (38 mm) and from 23 to 31 (14 mm). Read back by `sequence` (into `temp/`): 23 and 31 give the two grip files back
   exactly (bones, Hips, the bullpup in the hand), 11-16 the shotgun's stops; at 18 and 20 his keys stand (the left arm, forearm and
   hand at 18, the forearm at 20) and the bones he left unkeyed there move toward the bullpup's hip. In `tripo_pose_lab`:
   `PROP_GLB["bullpup"]` (the pack's source until the H3 rows copy it), `draw_bullpup` in `LONG_GUN_SEQUENCES` (its read-back keeps the
   fingers), `_gun_frame_points(turn=)`. Not in the game: a model's own timeline is POLISH-01's (the long-gun holder plays the family's).
   Next: he poses the bullpup's draw (where the left hand takes it) and saves; `pose_lab.py sequence draw_bullpup` reads it back. The
   female has no bullpup grip yet.
   **The bullpup's draw, his (2026-11-24, afternoon).** His save (14:01; the one before, 13:51, and this one kept in `temp/h3_family/`)
   changed only the left side: the arm, forearm, hand and index at 12, the arm, forearm, hand and every finger at 13, the hand and
   fingers at 16, and the bullpup at 13 and 16. The hand now holds it on another part of the grip, near where the hip grip holds it
   (10 mm and ~19° off), with the bullpup still upright at 16, so the hand is ~90° from the hip. Two faults followed, both measured on
   the gun's corners and the hand frame by frame:
   - **The slide was stale.** 17-22 were baked from the OLD 16, so the bullpup jumped 87° in the hand at 17. A baked slide is derived
     from the two stops beside it: whoever moves the gun at one of them must re-bake it (`tripo_pose_lab._bake_slide` from the stops as
     saved, the palm's point on the gun at each end). Re-baked, the hand slides 10 mm, 2.7° a frame.
   - **The turn was a whip.** His keys at 18 (left arm, forearm, hand) and 20 (forearm) are the shotgun's, its hand already near the
     hip, so the hand turned 84° between 16 and 18. Three versions were shown side by side (his save; the slide re-baked; re-baked and
     those keys removed); he chose the third (*"A 3, sem 18/20"*): the turn spreads over 16-23, at most 19° a frame. Those were the only
     keys at 18 and 20, so the stops are now 11, 12, 13, 16, 23, 31.
   The chosen file replaced his (he authorized it by choosing). `pose_lab.py sequence draw_bullpup` ->
   `ASSETS/ANIMATIONS/sequences/male/draw_bullpup.json` + `seq_draw_bullpup_f{11,12,13,16,23,31}.json`: 23 and 31 = the two grip files
   exactly; the gun's samples move at most 28 mm / 12.5° a frame (13-16, his own keys); the game set rebuilt byte-identical (nothing
   reads `draw_bullpup` until POLISH-01). Next: the snipers, the sci-fi and the launchers; the female's bullpup.
   **The female's bullpup, in step (2026-11-24, evening).** *"Vamos começar primeiro fazendo a versão feminina."* Her shotgun timeline
   already holds his own hands at her hip and aim (2026-11-23), so the 11-22 recipe (his rotations over hers) would undo them. Instead,
   `family_lab.py in_step <his family timeline> <his model timeline> <her family timeline> <out>` (the recipe's scratch scripts made
   into a command) carries only his CHANGE: at each stop of his bullpup timeline but the idle, every bone, fingers included, takes
   his turn from his shotgun timeline to his bullpup timeline, left-multiplied on her own key; the Hips her place plus his change
   (hip heights 1.0091). The stops he dropped (18, 20) are dropped on hers. The bullpup rides her left hand at HIS place against the
   hand's bone, read off his KEYS: a hidden object is not re-evaluated, so reading its place at a hidden frame gave the in-between
   13-16 a 1.5° difference through the key at 12. Her right hand goes onto the grip at the stops where his palm is within 4 cm (23,
   31), at his hand's place on the model times HER OWN departure from his on the shotgun there (2.2 cm / 20° at the hip, 3.3 cm / 20°
   at the aim), by the recipe's two-bone solve. Her coat stays hers; his model timeline must keep his family's coat (checked). Proof:
   run with no change (his shotgun timeline as both of his), it gives her shotgun timeline back key for key; the only difference is
   the hidden gun at 1 and 12, which her file holds stale. Built: `SEQ_draw_bullpup_FEMALE.blend`. Read back in `temp/`: the stops
   are his (11, 12, 13, 16, 23, 31); the bullpup sits in her hand at his place on every shown frame (3·10⁻⁴ mm, 10⁻⁴°); her coat's
   values are his; her right palm is 2.8 cm from the grip at the hip and 3.3 cm at the aim (his 2.0 and 2.2). The largest turns from
   her shotgun pose are the bullpup's own (the left hand 112° at the aim, the right arm and forearm 48°). Opened for the Director.
   **The stockless shotguns, now (2026-11-24, evening).** *"Depois eu queria abrir as duas shotguns de cano curto que a gente adiou
   ontem para a fase de polimento, e fazer agora. É pouca coisa ... vamos abrir uma delas na cena completa, e depois a outra shotgun
   segue o mesmo esquema. Como a empunhadura é igual as outras provavelmente o ajuste vai ser só no aim, e talvez algo no hip."* The
   sawed-off goes first. The hip stop needs a lab scene: with only `aim=`, the family's draw would run on to the hip with the model at
   the TIP's hold point, where the shotgun is held at the pump. So `family_lab.py build H3_SHOTGUNS male <temp> <his 22:43 read-back>
   --marker hip` stands the line at 23 in `temp/` (a builder input, not a scene to edit). Then `family_lab.py seq <his shotgun
   timeline> 03 SEQ_draw_shotgun_sawed_off_MALE.blend hip=<temp> aim=FAMILY_H3_SHOTGUNS_aim_MALE.blend`: the draw to 16 the family's,
   the sawed-off (0.313 long) held at its own hold point; 23 and 31 the family's body with it where the lab put it, both palms on it
   (left 0.9 cm, right 1.3-1.4; the shotgun's 0.7 and 1.5-2.6). The hand slides 89 mm from 16 to 23 and none from 23 to 31. Its aim is
   still the shouldered one; the Director poses it H2's way (both arms forward, at the eyes; step 3's ruling). `tripo_pose_lab`:
   `PROP_GLB` `shotgun_sawed_off` / `shotgun_short_stock` (the pack's sources), both draws in `LONG_GUN_SEQUENCES`. Next: his
   female bullpup save, or his word that it stands -> `pose_lab.py sequence draw_bullpup --figure female`. Then the sawed-off opened
   for his aim (and hip), read back; the short stock on the sawed-off's scheme; the females of both.
   **The female's bullpup, posed and smoothed (2026-11-24, night).** His save (17:35, kept as `temp/h3_family/SEQ_draw_bullpup_FEMALE_his_1735.blend`)
   re-posed her draw (the stop at 11 deleted; the left shoulder, arm and forearm and the right upper arm keyed at 9; 12 and 16
   moved), her hip (23) and aim (31), moved the bullpup in her hand at 31 and added a breakdown of the left arm (shoulder to hand) at
   27. *"O movimento nos últimos frames está meio duro. Da uma conferida e veja se consegue suavizar. As poses estão corretas."*
   Measured from 23 to 31: the breakdown took the gun clear of her body by turning it ~50° to her left (the barrel's yaw 0 -> 50 at 27
   -> 0); it came back in the last three frames at ~20° a frame, cut through the hat and the head at 30 (113 triangle pairs away from
   the hands) and still moved 27 mm in the last frame; the right palm hung up to 7.5 cm off the gun while the left hand carried it
   alone. Without the breakdown the raise is even, but the right palm hangs up to 9.9 cm off, the barrel yaws 15° and the gun touches
   the coat about as much as after the rebuild below (250 triangle pairs over 24-31 against 253, counted more than 12 cm from both
   wrists: a cuff round a hand that holds the gun is not a clip). `family_lab.py raise <timeline> <out> 23 31 25,27,29`
   (`raise_from_gun`) rebuilds the raise FROM THE GUN: the stops untouched; the gun's turn slerped straight from the hip's to the
   aim's (the muzzle stays on the target), its origin on a cubic arc bowed 6 cm forward (`RAISE_BULGE_M`: 8 cm takes all of her left
   arm's reach, 10 cm more than it has, the wrist then 1.3 cm short), timed by a smoothstep; at 25, 27 and 29 both arms solved onto it
   (the left at the slide's place, the right at its own place on the gun mixed from the hip's to the aim's; in_step's two-bone
   solve), their keys replacing his left arm, forearm and hand at 27 (his shoulder's key there stays); the slide re-keyed on 24-30 on
   the same smoothstep. Result: the gun turns at most 4.2° a frame (his 20.7), its travel a bell that settles into the aim (10, 22,
   37, 41, 37, 29, 17, 7 mm a frame); both palms on it all the way (left 0.5-1.0 cm, right 2.1-2.8, as at the stops); away from the
   hands it touches the shirt at 27-31 (20-59 pairs a frame) and the head only at 30-31 (8, 3: the cheek coming onto the stock); the
   male's raise, as he accepted it, cuts his coat at every frame (41-117). The draw's leftover at 11 (his delete kept the right
   forearm's and hand's keys there, at the built values) snapped the right hand 36° from 11 to 12; removed, it slows into the lapel
   at 8-10° a frame. The tool reproduces the file he saw key for key (1 883 keys, no difference). Read back:
   `sequences/female/draw_bullpup.json` + nine stop poses (9 passing, 12 rests, 13 and 16 passing, 23 rests, 25, 27, 29 passing, 31
   rests); 12, 13, 16, 23 and 31 equal his save's read-back to 1.5·10⁻⁷ (the hidden gun's stale place at 9 and 12 aside); the
   samples differ only at 24-30, the gun; the game set rebuilt byte-identical. A breakdown is a PASSING stop: when the game plays a
   model's own timeline (POLISH-01), `ActorAimPose3D`'s smoothstep over 23-31 eases the spacing these breakdowns already carry a
   second time. Next: the sawed-off opened for his aim (and hip), read back; the short stock on its scheme; the females of both.
   **The sawed-off, his, smoothed; the short stock's scene (2026-11-24, night, later).** *"Em seguida vamos pra cena da shotgun de
   cano curto"*, then *"Ajustei e salvei"* (20:46, kept as `temp/h3_family/SEQ_draw_shotgun_sawed_off_MALE_his_2046.blend`): the left
   arm and hand at 13 and 16, the left hand's fingers at 12, 23 and 31, the right index at 23; the gun untouched. The aim stays as
   built: the family's aim body with the stockless gun in its hand puts the pistol grip in front of the face, the gun at the eyes,
   both hands on it (left palm 0.9 cm, right 1.3); he kept it. Measured: the shotgun's keys inherited at 18 (left arm, forearm,
   hand) and 20 (forearm) held the gun upright to 19 and crowded the turn to the hip into 20-23 (the hand at 30° a frame, still 22°
   at 23); in the raise the barrel dipped 18° (26) and the right palm hung up to 4.9 cm off. Fixed in a new file, shown side by side
   and installed on his word (*"Pode instalar"*): 18 and 20 dropped (his bullpup ruling, *"sem 18/20"*), the turn now 13-23° a frame
   across 17-23, slowing into the hip; the raise by `family_lab.py raise <his save, 18/20 dropped> <out> 23 31 25,27,29 0.03` (3 cm
   bow: nothing touches the coat here; 0 cm reads the same), the barrel level within 1.5°, the gun turning at most 1.7° a frame,
   both palms on it (right 1.1-1.5 cm). In his file the motion ran through the hip; now it all but stops there, as the game does (the
   hip shot is a resting stop, the aim one more step). Read back: `ASSETS/ANIMATIONS/sequences/male/draw_shotgun_sawed_off.json` +
   nine stop poses (11, 13, 16 passing, 12 rests, 23 rests, 25-29 passing, 31 rests); 11, 12, 13, 16, 23 and 31 equal his save's
   read-back to 2.4·10⁻⁷; the gun's samples are unchanged (it does not move in the hand from 23 to 31); the game set rebuilt
   byte-identical. The SHORT STOCK, *"a outra shotgun segue o mesmo esquema"*: `family_lab.py seq <his shotgun timeline> 04
   SEQ_draw_shotgun_short_stock_MALE.blend hip=<the temp hip line> aim=FAMILY_H3_SHOTGUNS_aim_MALE.blend`, the shotgun's 18 and 20
   dropped at once (two rulings now): 0.380 long, the hand slides 121 mm from 16 to 23 and none after; both palms on it at the hip
   (0.6 / 1.3 cm) and the aim (0.6 / 2.1); away from the hands the gun cuts the belt, buckle, trousers, shirt and tie at 13-15 (the
   draw from under the coat, held at its tip: up to 192 triangle pairs a frame). Opened for him; the file goes into git with its
   read-back, once he has posed it. Next:
   his short stock -> its raise checked (`raise` if it needs it) -> read back; then the females of both (`in_step`).
   **The female's sawed-off: in step, smoothed, posed by him (2026-11-24, late night).** *"Depois da uma conferida na feminina"*:
   `family_lab.py in_step <his shotgun timeline> <his sawed-off> <her shotgun timeline> SEQ_draw_shotgun_sawed_off_FEMALE.blend`
   (kept as `temp/h3_family/SEQ_draw_shotgun_sawed_off_FEMALE_instep.blend`). Her own hold stays at 23 and 31 (her right hand's
   departure from his: 2.2 cm and 20° at the hip, 3.3 cm and 20° at the aim). **A gap in `in_step`:** at a breakdown the family
   timeline has no key on (25, 27, 29: his raise's, not the shotgun's) there is no departure of hers to carry, so her right hand
   there sits as his does on the gun, and between her 23 and 31 it swung ~20° aside and back (4-13° a frame). Running
   `family_lab.py raise <the in-step file> <out> 23 31 25,27,29 0.03` after it fixes that: the right hand at most 3.5° a frame, the
   barrel level within 1.4°, the palms on the gun (left 1.0 cm, right 1.8-2.5), nothing cutting her body in the raise (built copy
   `temp/h3_family/SEQ_draw_shotgun_sawed_off_FEMALE_built.blend`). He opened it (*"Abre no Blender"*) and saved it (*"Ajustei e
   salvei"*, 22:40, kept as `temp/h3_family/SEQ_draw_shotgun_sawed_off_FEMALE_his_2240.blend`): new keys at 8 (right forearm) and 9
   (left arm and forearm), the left forearm at 11 and 12; 13 on and the raise untouched. Measured: both hands speed up and slow into
   the lapel (12) without a jolt (the left palm at most 60 mm a frame, 5.6 mm into 12); out of 12 the left palm moves 42 mm in the
   frame to 13 (30 on the male and on the build), as the gun appears; the game's smoothstep over 12-23 spreads that start. At 13 her
   coat crosses the middle of the gun (34-79 % of its length; 41 triangle pairs more than 12 cm from the hands); the build had them
   too, the male has none (sheet `temp/h3_family/sawed/f13_closeup_sheet.png`). Read back as he saved it:
   `ASSETS/ANIMATIONS/sequences/female/draw_shotgun_sawed_off.json` + eleven stop poses (8, 9, 11 passing, 12 rests, 13 and 16
   passing, 23 rests, 25-29 passing, 31 rests); the game set rebuilt byte-identical. **Her 13 fixed** (*"Corrige o 13"*, then
   *"Pode instalar"*): the coat's right front panel crossed the gun's right side at the waist. Moving the gun with the hand clears it
   only toward her left (1 cm clears it, 0.5 cm still crosses); forward it takes 6 cm, back cuts the belt, and blending the coat's
   keys (`LongDrawFix_f12` / `_f16`) otherwise at 13 makes it worse. Built in a new file (`temp/h3_family/sawed/f13fix/`): the left
   hand moved 1.5 cm by a world offset with its turn kept, the arm by `family_lab._reach`, the three left-arm bones keyed at 13. The
   gun sits centred between the coat (0.92 cm) and the buckle (0.96; the male's gap to the coat is 1.53), and nothing of the figure
   touches it from 11 to 31. Side effects: out of 12 the left palm now moves 48 mm into 13 (42 in his save), and 13-16 is gentler.
   The rig's curves smooth with continuous acceleration (`auto_smoothing = CONT_ACCEL`), so a key change spreads along the whole curve:
   the left hand, which has no key at 8 or 9, turns 2.3° and 2.0° otherwise there (the left arm 0.2° at 8). Read back again: only the
   stops 8 and 9 (that hand) and 13 (the arm) changed; the gun's samples and the coat's keys are identical; the game set
   byte-identical. The stop files before 13 also carry a stale gun placement: the gun is hidden there, Blender does not re-evaluate a
   hidden object, so the placement is whatever the file was saved with. The sequence's samples carry the right one, the stop files
   do not. Next: his short stock (saved 22:35, not yet called done) -> its raise -> read back; then her short stock (`in_step`, then
   `raise`).
   **The short stock checked; the long-gun draws' cuts fixed (2026-11-25).** *"Pode conferir"*: his save (22:35, kept as
   `temp/h3_family/SEQ_draw_shotgun_short_stock_MALE_his_2235.blend`) changed only the left index at 12 and the left hand at 31. Its
   raise had the sawed-off's fault (the barrel down 10° at 26 and aside 11° at 27, the right palm 3.5 cm off): rebuilt by
   `family_lab.py raise <his save> <out> 23 31 25,27,29 0.03` (the barrel within 1.5°, the gun at most 1.6° a frame, the right palm
   within 2.2 cm). **A new check, the gun through the figure** (scratch `clip_body.py`: the gun's triangles crossing the figure's,
   more than 12 cm from both wrists; the gun is hidden before 13, so a count there is the stale hidden gun, not a cut) found the
   short stock passing through the belt, buckle, trousers, shirt and tie at 13-15 (192 triangle pairs at 14) and through the coat at
   19, and his family shotgun, in the game, doing the same and more (915 pairs at 13-15). He could not see it from my angles
   (*"Grava os videos com a parte que atravessa a cintura e cruza o casaco"*, then *"faz os videos com a sua sugestão de correção
   também"*): videos with the gun painted orange and every figure triangle it cuts painted red, his beside the fix (scratch
   `clip_video.py`, `assemble_grid.py`; `temp/videos/short_stock_cintura_13_15.mp4`, `short_stock_casaco_19.mp4`,
   `escopeta_familia_cintura_13_15.mp4`). His reading: where the gun appears inside the shirt is hidden by design and by the camera
   angle; *"Mas ficou ok, pode instalar a correção em todas as instâncias que precisarem"*. **The fix:** the smallest world offset of
   the gun that clears the whole figure by 0.6 cm (scratch `offset_search.py`), made by moving the left hand with the gun riding it
   (the arm two-bone solved by `family_lab._reach`, the turn kept; scratch `fix_draw.py`), keyed at the cutting frames. The short
   stock: 13 (2.25 cm forward, 1 up, 1 to his left), 14 (2.25 forward), 15 (1 forward), 19 (1 forward, 0.5 to his right), on top of
   its rebuilt raise; the move from 12 to 13 grows from 15 to 31 mm; installed and read back
   (`ASSETS/ANIMATIONS/sequences/male/draw_shotgun_short_stock.json`, 12 stops, 13, 14, 15 and 19 passing). **Every long-gun draw
   surveyed** (13-22): the sawed-offs clean (the male's coat touched by 2 pairs at 15, left); the male bullpup through the waist at
   13-14 and the coat at 18-19, the female's through the waist at 13 and the coat at 20-21: fixed the same way (male 13: 1 cm
   forward; 14: 2.5 forward, 0.5 to his right, 1 down; 18: 1.75 forward, 1 to his right; 19: 0.25 forward, 1 to his right; female
   13: 1.25 forward, 0.5 to her left, 1 up; 20: 1 forward, 1 to her right; 21: 2.75 forward, 1 to her right, 1 up), installed and
   read back (male 9 stops, female 11). The male's little pause at 17 in Blender now flows on. **The two family shotguns** need more:
   no offset within 6 cm clears their 13 (or her 15), the stock runs down the thigh; swinging the stock forward about the left palm
   does (male 13: 30° with 1.5 cm forward and 1 to his left, 14: 20° with 0.5 forward, 15: 15°; female 13: 30°, 14: 20°, 15: 20°,
   16: 5°; scratch `fix_draw_tilt.py`, built in `temp/h3_family/cutfix/sg_{m,f}_fix.blend`). But seen from the game camera the
   swung stock then shows below the coat, where his version hides the cut inside it (`temp/videos/escopeta_{masculina,feminina}_correcao.mp4`):
   shown to him with that advice (leave them as they are), not installed. Left as they are, his poses: the contacts at the hip and the aim (the butt in the shoulder, the
   cheek on the bullpups' stock, the hat brim on the male bullpup at 31, the male bullpup's stock through the coat as it rises 23-31).
   Each fix adds passing stops, and the curves' continuous-acceleration smoothing moves the frames around them a little (measured:
   the gun's travel a frame within a few mm of his). Backups of every replaced file are in `temp/h3_family/`. Next: the shotguns on
   his word; then her short stock (`in_step` from the fixed male, then `raise`).
   **The snipers' scene: their grip in the aim, the eye to the scope (2026-11-25, later).** *"De resto é isso, se não tiver mais nada
   estranho podemos fechar e seguir para os snipers. Acredito que a empunhadura vai ser muito parecida com a dos rifles.
   Possivelmente vai precisar de um ajuste na cabeça/coluna/pescoço, pra conseguir olhar pela luneta. Tenta encaixar a pegada deles
   na pose da mira, e já abre a cena com todos, pra gente validar os tamanhos."* The family shotguns stay as they are (the item closed
   with that). The snipers' scene, `FAMILY_H3_SNIPERS_aim_MALE.blend` (01, 09-12, 16, 17), was built on 2026-11-23 on his current
   aim and never saved by him (kept as `temp/h3_family/snipers/FAMILY_H3_SNIPERS_aim_MALE_built_1123.blend`): its grip is already
   the rifles' (each trigger guard at the right index where the shotgun's is, the gun riding the left hand; the pack's four at x1.0
   of the reference's units, the two sci-fi at 1.1 of its length). Measured (scratch `scope_probe.py`): the pack's four carry GLASS
   lenses, so the scope's axis runs through the two lens centres and the rear one is the eyepiece. On the family's aim the right eye
   (the long aim's rule: the nose's tip plus `LONG_EYE_FROM_NOSE`, carried by the Head bone) sat 1.1-1.4 cm under the axis, 0.6-1.2
   to its left, 2.7-2.8 behind the eyepiece (11: 5.9, its scope sits forward). The two sci-fi snipers have no scope and their housing
   rises 2.5 and 3.5 cm above the eye, through the face and the hat (129 / 234 and 240 / 356 triangle pairs): a size or place for him.
   **The head** (scratch `sniper_head.py`): ONE turn of the Neck and the Head, the same on every sniper Agent (01 keeps the family's),
   fitted by Nelder-Mead to bring the eye onto the four scopes' mean axis at its distance behind the eyepiece, the head's look kept:
   the neck (9.1, -2.0, 1.4)°, the head (-17.4, -2.2, 3.3)° (local XYZ), so the head lifts and still looks along the barrel (1.3°
   off); the eye 0.4-0.7 cm under the axis, inside the eyepiece; the cheek on the stock (36-57 triangle pairs of the head against the
   gun). The eye exactly on the axis takes the head canted about 14° and the look 7° off: shown as the other choice
   (`temp/h3_family/snipers/head_f.blend`). No spine: the arms ride it, so a spine turn carries the gun with the head and changes
   nothing between the eye and the scope. The butts against the right shoulder joint: from 2.1 cm past it (17) to 7.3 (09, 12), the
   shotgun's 7.8. Close-ups: `temp/h3_family/snipers/head_side_sheet.png`. The scene installed with that head and opened for him.
   Next: his sizes; the head fitted again on them; the read-back; the snipers' body kept as a grip file (`family_lab.py grip`); the
   female's scene from the male's sizes.
3. **The poses per family, standing:** one timeline per family on its reference weapon (H3: the shotgun or the rifle; H2: the
   submachine gun): draw, hold, aim, and the way back. Then the family's other weapons by their points, checked by eye.
   **H3 opens with the SHOTGUNS (Director, 2026-11-17).** *"Vamos ter o tiro do hip, e o tiro mirando. Tiro do hip é rápido e erra
   mais, tiro mirando demora mais e acerta mais. Agachado só tem o tiro mirando."*
   - **Two shots:** from the HIP (standing only) and AIMED (standing and kneeling; the kneel has only this one). Their numbers
     (time or AP, the hit chance, the spread) are GAMEPLAY-01's (`docs/production/milestones.md`); MOVEMENT makes both postures and the
     choice between them.
   - **The four models** (§11.5): `Shotgun` and `Shotgun-ZmPTnh7njL` have a shoulder stock: AIMED = the butt in the shoulder.
     `Shotgun Sawed Off` and `Shotgun Short Stock` have only a pistol grip: AIMED = both arms forward, two hands, at the eyes (H2's
     way; Director, same day); their hip shot is the others'.
   - **The draw is a new one, not the pistol's (Director, 2026-11-17/18):** *"as armas grandes, tanto shotgun quanto rifles e sniper,
     vão ficar escondidas verticalmente atras da aba direita do casaco (a pistola sai da aba esquerda). O cano fica pra cima e o
     gatilho pra baixo."* Every LONG gun hides upright behind the coat's RIGHT flap, the barrel up, the trigger down. The draw, from the
     idle: the LEFT hand goes into the right lapel while the RIGHT hand lifts it, the pistol's draw mirrored; the left hand takes the
     barrel, from its middle to its tip, behind the flap, and pulls it out; the gun comes to the centre, in front of the tie, held by
     the tip, and the right hand lets the lapel go; last, the left hand turns it from vertical to horizontal, the barrel forward, while
     the right hand finds the trigger below. **The draw ends in the HIP shot's stance.** *"Um segundo momento seria o tiro mirando.
     Precisa de mais 1 AP, por isso é um custo extra, recompensado com mais precisão."* The aimed shot goes on from the hip to the
     shoulder and costs ONE AP more (GAMEPLAY-01: shots spend no AP yet).
   - **The starting timeline, BUILT 2026-11-18 for the Director to pose by hand:** `python3 tools/persistent/pose_lab.py
     draw_long_new [--gun shotgun] [--figure ...] [--render]` -> `ASSETS/MODELS/actors/agent/<fig>/work/SEQ_draw_shotgun_<FIG>.blend`, both figures
     (`tripo_pose_lab.draw_long_new`). Frames 1-31 at 24 fps, markers idle 1, lapel 12, centre 16, hip 23, aim 31 (the centre is a
     passing stop; the Director merged a separate pull into it the same day: *"o pull e o center são a mesma coisa"*). The lapel is the figure's pistol draw stop MIRRORED (its change from the idle; the legs stay the idle's);
     the pull, the centre, the hip and the aim place the gun and SOLVE both arms to it, the hands holding it as the bank `fire` frame
     holds a long gun (the left hand turned round the barrel for the draw), the trunk turned right at the hip (30 degrees) and the aim
     (35), the head looking down the barrel at the aim. `PROP_shotgun` (the pack's `Shotgun`) rides the LEFT hand and shows from frame
     13, held by the tip of the barrel through the centre; then (Director, same day) *"A mão esquerda, que está segurando a arma pela
     ponta do cano, vai girar toda a arma 90º para frente [...] Ao mesmo tempo em que faz o giro, a mão esquerda também desliza para
     trás pelo cano. Nesse meio tempo a mão direita encontra o apoio em baixo + o gatilho e puxa todo o conjunto pra cima, de forma
     que está pronta para atirar pela cintura"*: in the turn (centre -> hip) the muzzle goes from the zenith to the front while the left
     hand slides back to the fore-end, and the right hand takes the grip and the trigger below and lifts the gun to the waist; its place
     on the hand is keyed at every stop. The AIM, a turn later for one AP more: *"a shotgun tem que ficar apoiada no ombro, uma mão em
     baixo, e outra no gatilho, a pose clássica de mira"* (not the pistol's two hands at the eyes). At the build's ~1 m the left hand
     cannot stay at the tip for the hip or the aim (measured: the waist is out of reach, the aim would need 111 % of the arm): the
     slide is what makes both reachable. From 13 to the centre the hold does not change (Director: *"depois que o agente pega a arma,
     ela deveria continuar sendo segurada pelo cano, sem mudar"*): the left hand of 13 is carried to the centre turned the same, and
     the slide (centre -> hip) is keyed on every frame (`_bake_slide`: the point of the barrel in the palm runs back to the fore-end
     while the gun turns in the hand), since Blender's own interpolation of two different holds swung the gun out and through the body.
     At the hip and the aim the left hand is the SUPPORT hand (*"A mão esquerda precisa girar, pra palma apontar pra cima, e os dedos
     abraçarem o cano"*): the palm up under the fore-end, the fingers across it and closed round it, the thumb along its left side
     (`_support_hand`, `_close_fingers`); the read-back of a long gun's draw keeps the fingers (`LONG_GUN_SEQUENCES`), as the throw's does.
     **The aim at the EYE (Director, 2026-11-18):** *"a pose do aim ainda está muito baixa. Precisa ficar na altura dos olhos. E servir
     pra shotguns, rifles e snipers. Rifles também atiram na cintura. Snipers não."* The gun's sight line (the top of its receiver)
     runs just under the right eye, the head down on the stock and leaning right onto it, the butt high in the shoulder
     (`LONG_AIM_*`; the eye found from the nose's tip on the head mesh). ONE aim for the shotguns, the rifles and the snipers; the
     HIP shot is the shotguns' and the rifles', never the snipers' (a sniper draws straight to the aim); it opens at x0.085 of the pack's units, about 1 m long (at the pistol's 0.0600 its stock stops short of the shoulder): its
     size is the Director's. The coat has one EMPTY key per pose, `LongDrawFix_f12` ... `_f31`: opening the right flap is his.
   - **IN THE GAME on both figures, 2026-11-22** (read back as the files stood: his male save of 2026-11-18 02:49 is the session's last write
     byte for byte in its keys, so his fine adjustment was still to come; the female is the builder's plus that session's edits, no key of his).
     `pose_lab.py sequence draw_shotgun --figure both` -> `sequences/<fig>/draw_shotgun.json` (male: stops 12 rests, 13 and 16 passing, 23
     rests, 31 rests; female: 12, 16, 23, 31) and the pose files; `TripoFigure.build_library` carries them. His male `LongDrawFix_f12` (the right
     flap opened at the lapel, 304 vertices) is a morph of `AGENT_MALE_LIGHT.glb` (`glb_add_morph.py`); the empty keys stay out of the GLBs.
     **The engine:** `ActorMesh3D`'s aim sets are per hold FAMILY and posture (`FAMILY_DRAWS`: `pistol:standing`, `pistol:crouch`,
     `shotgun:standing`); a set changes only with the gun away, and the one gun node takes the timeline's bone (the long gun rides the LEFT
     hand), the row's model and, for a long draw, its own coat keys. The draw stops at the `hip` marker for the stance "hip" and runs to the
     end for "aimed" (`ActorPose.shot_stance`); the holster is the timeline backwards from wherever the gun is. A family is drawn only when the
     held row has a model: `weapons/shotgun.json` has one now (`ASSETS/props/shotgun/shotgun.glb`, the pack's `Shotgun.glb` byte for byte,
     LEFT hand at x0.085, muzzle at the bore's front face, no spent case: a pump throws it at the pump, not at the shot), so the smg and the
     sniper rifle (held as the shotgun, no model) are still not drawn. `ActorPose.weapon_id` "" (the agent's default) means the family's
     reference row. **The two shots in the menu:** a long gun standing offers "Atirar do quadril (Enter)" and "Atirar mirando" (the context
     menu's optional second action); kneeling or prone, or a sniper, the aimed one alone. The menu opening draws to the hip; the aimed shot
     goes on to the shoulder and fires once the figure is there (`AgentShotController._reach_stance`, after the precook join so the lag stays
     before the animation; `Agent.weapon_at_stance`). As with the pistol, the end of a shot puts the gun away. Takes `shotgun_draw` (the 4
     views) and `shotgun_shot` (hip, then aimed), scenario step `shoot_aimed <guard>`; filmed on both figures: the flash leaves the muzzle at
     the waist (123 px over the floor) and at the eye (163 px). Not done: his fine adjustment of the male and the female in step with his
     keys (a new read-back when he has saved), the shotgun's size certified (`size_certified`: until then a load warning says so), the
     kneeling long-gun draw (step 4), the other shotgun models (the H3 family lab), the pump / case (step 5), the AP of the aimed shot
     (GAMEPLAY-01).
   - **His fine adjustment IN THE GAME on both figures, and the long gun's recoil, 2026-11-22 (later).** The male is his save of 21:32
     (`SEQ_draw_shotgun_MALE.blend`): stops 11 (new, passing), 12 (rests), 13, 16, 18, 20 (passing), 23 and 31 (rests); his hands and
     fingers re-posed at 11-13, 23 and 31 (the right hand from 12 on first put at the rig's rest, his pick, *"a aberta do Alt+R"*, then posed
     by him). ⚠️ **A joint moved with G where no location curve exists is NOT keyed, holds on every frame, and the game never reads it:** 20
     such moves (the fingers of both hands and both shoulders, up to 1.6 cm) sat in his saves of 17:04-17:58 and made the hand look crooked
     even in the idle, where Alt+R cannot reach them; cleared with his OK (Alt+G on those bones, never the Hips). His last save holds 22 new
     ones (fingers, up to 1 cm): the game plays those fingers without them, and the difference was rendered for him. The coat's flap is the
     11-18 one byte for byte (the GLB unchanged). **The female in step** (her file was the builder's plus the 11-18 edits, none of his): at
     each of his stops but her idle, his rotations as they are (the crouch's way, `6eb531a1`; his changes applied as a delta on her own poses
     missed his gun angles through the draw), the gun at HIS placement against the left hand's bone (hers had been fitted to a hand turned up
     to 97° away), her right hand put back on the grip at 23 and 31 by a two-bone solve to his hand's place on the gun (palm to gun at the
     hip 3.6 -> 1.8 cm; his 1.5), his flap by nearest vertex (304 -> 337 of her vertices) as `LongDrawFix_f12` on `AGENT_FEMALE_LIGHT.glb`;
     her stops are his. **The recoil (Director: *"o tiro hip e o tiro aim (acrescentar o recoil)"*):** `ActorRecoil3D` kicks by a PROFILE
     chosen from the hold family and the stance (`profile_for`, called by `ActorMesh3D.fire_kick`): "pistol" as before (the arms, and the
     gun in the hand: `GUN_KICK_*` moved from `ActorMesh3D` into it); "shotgun:hip" and "shotgun:aimed": the TRUNK rocks back (Spine, Spine1,
     Spine2: the arms and the gun go with it, so the hands stay on the gun) and the arms add the muzzle's climb, the gun fixed in the hands;
     at the hip the arms take more (trunk 6° + arms 8° at the wrist), aimed the trunk (9° + 3.5°, the head going with the cheek on the
     stock); up in 0.045 s, settled in 0.40 / 0.45 s. **Ratified by the Director as they are** (*"Está bom assim"*, 2026-11-22).
   - **The shot in stages, 2026-11-23 (`WEAPON` D43 has the ruling and his answers; `DESIGN` §8.7 the gameplay).** The draw starts with the weapon's CHOICE (`AgentShotController.choose_weapon`, the number keys; the HUD's list later), no longer with the click on an enemy. A long gun standing stops at the hip and the flow pauses there (the menu over the agent: *Atirar do quadril* / *Mirar*); the aim goes on to the shoulder. At the target (stage 2) the WHOLE BODY turns in place to it at any angle, the throw's turn at its pace (`ActorPose.shot_aim_dir`, cleared by the next step of a move; `ActorMesh3D.facing_aim()`): the shot waits for the turn as it waits for the stance. After the shot nothing lowers the weapon: it stays where it fired (aimed: at the shoulder), the body facing the target, until a move (`Agent.move_along_path` lowers the grip, so the holster plays before the first step as before) or another item (`AgentShotController.put_away`: another weapon, the grenade). Scenario steps `draw <id>`, `stance hip|aimed`, `trigger`; take `shot_stages` (profile `ui`, the menus in sight). Filmed on both figures (`shotgun_draw`, `shotgun_shot`).
   - **His grip at the AIM, 2026-11-23 (night)** (Director: *"acho que o cabo da arma não está bem posicionado"*, then *"Ajustei e
     salvei"*). His save of 19:20 (`SEQ_draw_shotgun_MALE.blend`; his saves of 19:15 and 19:20 copied to `temp/h3/`) changed the KEYS at
     frame 31 only (72 channels): both hands turned 32-33° (the gun rides the left hand, so the whole gun re-angles with it; its placement
     in that hand is unchanged), the forearms 11-13°, the arms 7-12°, the shoulders 9-12°, the neck 8°, the head 3°, the right index
     7-46°, the thumb 16-36°, the middle and ring 11-17°. The hip (23) is unchanged; the passing stops 18 and 20 move up to 3.6° (the
     Bézier handles of the keys at 23 follow the key at 31). The right middle and ring fingers were also moved about 1 mm more with G:
     still not keyed, still not read (22 such fingers, as on 11-22). Read back with `pose_lab.py sequence draw_shotgun --figure both`; a
     fresh read of his 21:32 save gives the game's old files exactly, so every change is his. **The female in step by the 11-22 recipe,
     checked first:** re-run on his 21:32 save it gives her 11-22 file key for key once the right hand's solve takes the stops where his
     palm is within 4 cm of the gun (his aim was at 3.8 cm, now 2.6); on his new save her keys change at 18, 20 and 31 like his, her palm
     at the aim 2.95 cm from the gun. The gun's keys at 1 and 12, where it is hidden, hold a stale placement on both figures (Blender does
     not evaluate a hidden object; the read-back already gives a hidden sample the first shown one). Filmed: `shotgun_shot` on both figures.
   - **Her hip and aim by his hand, 2026-11-23 (night, later)** (Director: *"Primeiro eu vou ter que ajustar o hip e a mira feminina
     também"*, then *"Ajustei e salvei"*). He started from the recipe's file of 19:29 (`b112d762`); his save of 21:57 of
     `SEQ_draw_shotgun_FEMALE.blend` (both copied to `temp/h3/`) changed her body's KEYS at 23 and 31 only (56 and 64 channels). The
     gun's keys (its placement in the left hand), the coat's keys and shapes and the markers are unchanged. Read back, at the hip: the
     right hand 18°, the right arm 14°, the forearms 9-10°, the right fingers 9-24° (the index 9-17°, the middle, ring and little 24°),
     the trunk (Spine1) 7°, the left arm and hand 3-4°, the left shoulder 1°; at the aim: the neck 22°, the arms 15-23°, the right hand
     27°, the right thumb 4-34°, the right index 11-14°, the shoulders 10-12°, the forearms 12-13°, the left hand 10°, the trunk 2-6°.
     Her other stops did not move. Her right middle, ring and little fingers were also moved with G (up to 2.6 mm): not keyed, not read.
     Read back with `pose_lab.py sequence draw_shotgun --figure female` (the male's game files unchanged byte for byte); her pose files
     at 11 and 12 change only in the hidden gun's stale placement. **From now on her 23 and 31 are HIS** (his file is never
     overwritten): the in-step recipe never runs over those two stops again; a later male change there is carried by his hand, or by a
     delta that keeps his keys. Filmed: `shotgun_shot` on the female.
4. **The same, kneeling:** the kneel's legs under the family's arms (the pistol's `draw_crouch_new` way).
   **Director, 2026-11-26:** *"Também deixa planejado conferir o saque das armas quando agachado."* Every weapon's draw is checked
   crouched once its standing draw / hip / aim is done (H1's note in step 5: the family is expected to fire crouched unchanged): the
   gun out of the coat over the kneel's legs, the hands on it, nothing through the coat or the thigh (`cut_scan`'s rule).
5. **The shot per weapon,** as data over the procedural recoil (`ActorRecoil3D`): the kick, the burst (count and interval), the hold
   after it, the case from the `port` (none for the revolver, the taser, the darts). The flash and the tracer already leave
   `model.muzzle`. A pump or a bolt cycle is a small timeline of its own: wanted (2026-11-26), step 12. (2026-11-22: the kick is already
   per hold family and stance, `ActorRecoil3D.profiles`: "pistol", "shotgun:hip", "shotgun:aimed"; a row's own kick is still this step's.)
   **Built 2026-11-17 (the projectiles, D21's second amendment):** each row says how its shot LOOKS in an `fx` section
   (`WeaponDef.fx_*`: `flash` powder / energy / none, `case`, `projectile` tracer / bolt / dart / probes / hook / flare, `part`,
   `string`, `spin`, `color`). `ShotProjectiles3D` (one per board, like the cases) flies the bodies: the crossbow's own dart (the
   model's `crossbow_dart`, hidden on the gun and the string snapped straight until the weapon is put away) bites the wall; the
   taser's two probes on two wires; the grapple's hook (split off the model's `Hook` surface) on its line, bites, holds 0.45 s and
   winds back while the `Drum` turns; the flare to the wall, down to its foot, burning 6 s with its own glow (no board light). The
   sci-fi pistols and the ray gun fire a coloured bolt (TracerOverlay) with sparks of their colour, no case; the revolvers throw no
   case. Darts and probes are in the save (`stuck_projectiles`) and fall when their voxel is destroyed (`shot_projectiles_selftest`;
   not seen on the map: no blast in reach took the dart's own voxel). Drawn only from `CosmeticDensity` mid up, the record kept on
   every device. Takes `crossbow_shot`, `projectile_shots`, `dart_persist` (PLAYGROUND, the brick bench), both figures. Colours,
   sizes and the flare's glow are first passes: their finish is POLISH-01.
   **H1 closed 2026-11-17 (Director), skins aside.** The KICK per weapon is cosmetic (gameplay may at most read it into the hit
   chance, or, at the extreme, the Agent hurt by it): a stronger or weaker recoil per row is a visual variation, built with the next
   family's recoil data. The family firing CROUCHED is expected to work unchanged (the skeletons were left alone so every weapon fits
   standing and crouched) and is checked later. The suppressors are 12 % thicker (`model.mount.girth` 1.12 on every row:
   `AttachmentDef` widens the model across its bore, its length and muzzle unchanged).

6. **The cover bodies B3-B6,** then the pistol's lean-out on each, then the other families on them.
7. **The throws left:** from the kneel; the bowl (standing).
8. **The devices and the interactions:** I1's solved reach first (it serves the most objects), then H6, H5, I2-I6, H7.
9. **H8, the paired takedowns** (credits; §4.1's ranking).
10. **Moving with a weapon in the hands (B7), PLANNED (Director, 2026-11-17).** *"vamos precisar de uma animação específica pra correr
    com a arma em modo stealth. Claramente não vale a pena tentar só atachar a arma. Vamos deixar planejado em MOVEMENT pra fazer
    movimentação segurando armas."*
    - **What was tried (2026-11-17):** the pistol fixed in the right hand at the aim's placement while today's walk and run played as they
      are (a throwaway probe, never committed). It does not hold: the walk swings an open hand and the run pumps the arms, so the gun
      points wherever the hand goes, and the left hand is free. The Director judged it on the first takes.
    - **What it needs:** a gait of its own per hold family, at least a STEALTH RUN with the weapon (and its walk), with their starts
      and stops like today's gaits (§11.0), processed like every gait (root motion out, the tempo of the grid's step, D61). The bank already
      has candidates on both figures, both hands together at the chest: S3 `walking_briskly_and_stealthily_holding_a_pistol` (walk) and
      S2 `correr_furtivamente_segurando_uma_pistola_aponta` (a hunched run), §4.1's stealth rows; their sheets are in
      `ASSETS/ANIMATIONS/bank/sheets/clips/`. With them come the draw on the move and the aim from a gait, which do not exist today.
    - **The convention until then (Director, 2026-11-17):** *"o agente saca, atira e guarda automaticamente antes de
      andar/correr/fazer outra coisa"*. The weapon is out only to aim and to fire. **BUILT the same day:** a move ordered while the
      figure still shows a weapon (held after a shot, or on its way back into the coat) waits until it is put away, the hold after
      the shot cut short (`Agent._weapon_away`, `ActorPose.stow_weapon`, `ActorMesh3D.weapon_out`); a kneel or a rise ordered with the
      other posture's gun still up waits for it too, and the new posture draws again if the aim is still held. The throw already
      waited for the pistol (2026-11-12). The cost: a move ordered right after a shot leaves once the holster has played (the draw
      timeline backwards: up to 0.92 s, its 22 frames at 24 fps, the same on both figures standing and crouched). Takes `holster_walk`, `holster_run`, `holster_crouch` (PLAYGROUND), both figures.

11. **The enemies' carry, PLANNED (Director, 2026-11-18, opening `ENEMIES_MASTER_PLAN`).** *"Os inimigos em geral vão ter um tipo de
    arma principal (mais algumas secundárias) e ela vai estar sendo carregada na mão, a tiracolo ou seguradas casualmente de umas 3
    maneira diferentes."* One set of animations still serves everyone (§11.8 Q8); these are poses the Agent has not needed.
    - **What it needs:** per hold family (H1, H2, H3; H9's launcher), the main weapon carried in the hand, slung across the body, and
      held casually (Claude's reading: three casual holds besides the hand and the sling, chosen on renders); the passage from each carry
      to the aim and back; walking and running with them, with step 10's gaits.
    - **What exists:** the bank's pistol carries only (S2, S3), no long-gun carry. The field officers wear the Agent's body and coat
      (`ENEMIES_MASTER_PLAN` §6, ruled the same day), so the Agent's draws from the coat work on them as built.
    - **The models it asks for:** a sling on the long guns (`ITEMS` §2.1); where the secondaries ride is open (`ENEMIES` §5a).
    - **Detailed (Director, 2026-11-18, later):** *"Deixa planejado na milestone de movement, poses carregando armas longas para todos os
      atores."* Long-gun carry poses for EVERY actor (Agent included). **The casual poses are silly ways to carry a rifle:** resting it on
      the ground, leaning on it like a cane, and the like; an enemy takes them when CONFIDENT AND UNAWARE (so they read as a state: the
      passage out of them on alert is part of the work). **Secondaries** are hidden (out of sight) or hung at the waist (a pistol, a
      grenade, other items). **Stronger bosses** hold one weapon in the hand and carry another (a bazooka, a rifle) on the BACK, strapped
      across the chest, and switch between them in play as it suits: a back-to-hand swap per hold family.

12. **The actions worked by hand, then the reloads, PLANNED (Director, 2026-11-26).** *"coloca na milestone de movimento fazer as
    animações do pump, ferrolho, e posteriormente recarga de todas as armas. Mas por enquanto vamos primeiro finalizar o draw/hip/aim
    de todas."* After each shot the PUMP guns (the short stock; `shotgun_zmptnh7njl`, the pack's `Shotgun-ZmPTnh7njL`) rack the fore-end
    with the support hand and throw the shell out of the port; the four snipers (09-12) work the BOLT with the right hand; then the
    RELOAD of every weapon. Order: after steps 2-3 (draw, hip, aim) are done for every weapon. What it asks of the models: the moving
    piece as a node of its own (`WEAPON` "Third note", 2026-11-26); the certified shotgun (01) is a common shotgun, nothing per shot.

Steps 0 to 5 are the Director's order. Steps 6 to 9 are in Claude's proposed order: he listed them without one (§11.8 Q9). Steps 10,
11 and 12 are the Director's; 12 waits for steps 2-3 to be done for every weapon, the others have no place in the order yet.

### 11.7 Notes for other plans (recorded here, built there)

- **GAMEPLAY-01** (`docs/production/milestones.md`) and `DESIGN` §8.2: is PRONE viable; until then nothing prone is made.
- **`DESIGN` §10.2 and `WEAPON` §5.1 (Q3): two lists of firearms.** The engine's catalogue is pistol, revolver, submachine gun, assault
  rifle, shotgun, sniper rifle. The tree's weapons are the pistol, the suppressor, the taser, the suppressed rifle, the pulse carbine,
  the laser, the dart launcher, the plasma and the sonic weapon. The shotgun, the submachine gun, the assault rifle and the revolver
  are in no node of the tree, and the tree's late guns have no row in the catalogue. The families cover both, so MOVEMENT does not
  wait; who carries what is those plans' to say.
- **`WEAPON` §5.2 and `DESIGN` §10.4 (Q4):** the detonator is new today; whether a charge goes off by a remote or a timer is open there.
- **`PROP_PIPELINE_PLAN` (PP7):** the interaction anchor (§11.3).
- **`ACTOR` D70 / D100 (Q2):** "the gun comes out of the coat" (2026-11-08) presumes the coat is on; the stealth dress stows the coat in
  the pack.

### 11.8 Open questions for the Director

1. **"Holding":** is it a REST with the weapon out (low, ready), kept while he stands and moves (M1), until he puts it away? Today the
   pistol has no such stop: it comes out for the aim and goes back, and walking lowers it. *(Claude: yes for the long guns, and then
   the pistol gets one too, so every family has the same five stops. It costs one pose per family and its layer over the walk and the run.)*
   **RULED for now (Director, 2026-11-17):** no. The agent draws, fires and puts the weapon away before he walks, runs or does
   anything else; moving with a weapon out waits for gaits of its own (§11.6 step 10).
2. **Where a long gun comes from and goes back to:** out of the coat like the pistol (no stowed model; a sniper rifle out of a coat is
   a stylisation), slung on the back (always visible: a carried model that crosses the coat, the pack and the hand-made coat keys), or
   the pack. And with the coat stowed (the stealth dress)? *(Claude: out of the coat for all of them; a slung gun reopens the coat.)*
   **RULED (Director, 2026-11-17/18):** every long gun, the shotgun, the rifles and the sniper, hides upright behind the coat's
   RIGHT flap (the pistol is behind the left one) and comes out in the left hand (§11.6 step 3). The stealth dress is still open.
3. **Which firearms are the game's** (§11.7), and so which are certified first. *(Claude: the catalogue's six now, since their models
   are on disk; the tree's late guns when their models exist.)*
4. **The detonator:** a remote for C4 and the breaching charge, or a timer?
5. **The dart launcher:** a pistol (H1, it reuses the closed cycle) or a long gun (H3)? *(Claude: a pistol; `DESIGN` §10.2 gives it 6 tiles.)*
6. **The EMP:** thrown (H4) or placed (H5)? `WEAPON` §5.2 lists a bomb, the tree a "charge".
7. **The throws not on today's list:** the study's underhand toss and sidearm (§7): dropped, or later? *(Claude: the sidearm with the
   cover; the underhand only if the solver needs a short toss under a low ceiling.)*
8. ✅ **RULED 2026-11-16 (Director): "Todos podem carregar todas as armas, vamos usar as mesmas animações pros inimigos e agentes, mudando
   somente os modelos."** One set of animations for the Agent and every enemy; any of them may carry any weapon. Whether a guard DRAWS or
   starts with the weapon in hand is now a gameplay state, not a second animation set. Was: **Guards** (§4.1's question 7 stands): the same families on the same skeleton. Do they draw as the Agent does, or carry the weapon in
   the hands from the start?
9. **The order of steps 6 to 9** (§11.6).
10. ✅ **RULED 2026-11-16 — each model is a WEAPON of its own:** *"specs diferentes individuais por modelo (a definir na milestone de
    GAMEPLAY), mas são essencialmente a mesma arma em termos de animação e manuseio, mudando apenas a aparência, e o resultado dos tiros"*.
    One row per model (its own damage, accuracy…, set in GAMEPLAY-01); the family's poses and handling are shared. Was: **variants or weapons?** Is each model a weapon of its own (its own row, stats, range, noise), or a LOOK of
    one of the six weapons (one row per weapon, several models, same stats)? *(Claude: looks of the six, each model its own size / grip
    / muzzle points; stats stay six rows, so balance and the tree do not grow by fifteen weapons; a model can be promoted to a weapon
    later.)*
11. ✅ **RULED 2026-11-16 — one by one, family by family, in the AIM pose:** *"todos os modelos da mesma família lado a lado, próximos
    do agente, e vamos conferir o tamanho e a posição uma por uma, usando a mesma pose (aim). Mais tarde, terminando todas as famílias
    fazemos DRAW e HOLDING de cada uma e testamos com as armas individuais."* So step 2 is one lab file PER FAMILY: the figure in the
    family's aim, every model of the family laid out beside him, the Director sets each one's size and grip in that aim; DRAW and HOLDING
    per family come after ALL families are sized (steps 3-4), then each weapon is tested on its own. **Before the lab files: the ITEMS
    milestone (`ITEMS_MASTER_PLAN`) gathers every model first.** Was: **Sizing 21 models by hand:** each one by hand (21 lab sessions), or the family's reference by hand and its siblings at the pack's
    own proportion to it, checked by eye on one sheet? *(Claude: by family; the pack is consistent WITHIN a type, its pistol-to-rifle
    gap is what needs the hand.)*
