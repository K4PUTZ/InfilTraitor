# Session record — 2026-11-01: the animation bank on the Agents, the coat's skirt, and the legs that push it

Picks up `RESUMO_SESSAO_2026-10-31_PRIMARY_ITEMS_COAT_EMBLEM.md` (open then: T4, the Godot adapter, and the clips). The session started with the order of work
(animate or texture first), played the real clips on the Tripo Agents in the engine, and spent the rest on the long coat, which is what showed the defects.

## Directed (Director)
- Animate first or texture first? Claude: animate (a texture hides nothing the clips would break). *"Pode seguir como achar melhor. O moto esta disponivel para testes."*
- On the first bench run: the clips stood frozen in place and sank into the floor (`dive`). Claude: the bank stores the Hips normalised by hip height; the bench now plays them in place with the
  Hips rescaled to the figure. *"Certo, a pose do dive deixa isso bem claro. Vamos deixar ela certinha e os outros provavelmente vão funcionar também."*
- The coat, as a game rule (NOT in the plans yet; the memory note `coat-civil-mode-backpack-idea-2026-11-01` holds it): worn only in "civil" mode (no dive, no flip in it); stealth mode keeps it in a
  BACKPACK (the model is missing); a cut-scene of stowing it as a map begins (he may arrive by motorbike); no swapping coats at a checkpoint; a swap costs a turn (2 AP, not startable in the same
  turn) with a short dress / undress animation. Before any of it is built it goes into `DESIGN` with his sign-off.
- Iterate the male coat with the recommended decisions until reasonable; walk and run first. His findings, in order: the sleeves and the upper areas still tear; the shirt, belt and tie leak through
  the armhole; the cuff (wrist) comes out cut; a strip near the pocket where the leg crosses the skirt; the knee should *slide forward pushing the skirt to the sides*, not push it forward.
- *"o casaco tem esqueleto?"* then: should the coat have a skeleton of its own, with properties and materials and real collision? It is already D88 (his own ratification of 2026-10-30), built, and had
  been silently dead in every Agent since D91. *"pode descartar esqueletos que não estão em uso do modelo"*: done in the build (a bone no vertex uses is dropped).
- The last order of the session, on the springs' video: *"ainda estamos com a questão da perna atravessando o casaco, tanto na parte da frente quanto na parte de trás, mesmo apenas caminhando.
  Temos que fazer o esqueleto do ator empurrar o tecido na parte de tras e formar um calombo na perna. Enquanto na parte da frente, a fenda do casaco simplesmente se abre mais, com as pontas das saias
  pendendo pros dois lados, enquanto os joelhos e as pernas se movimentam livremente pra frente e pra tras."* -> `ACTOR` D94.
- To check later: how the male's belt hangs (a game-camera still, front view, arrow at the belt's lower edge). The female's own clips: he fetches them from Tripo; the names to confirm.

## Built
- The bench plays bank clips (`actor_bench agent_<light|full>_<fig>[_tint]_f<k>_clip_<id> N`), in place; `_nosprings`, `_nopush` switch the coat's two layers off for an A / B.
- `tripo_skirt_fix.py` (the coat's final weights, last in `build_agents.sh`): forearm / hand off the skirt, the sleeves and torso smoothed, the cuffs keep Tripo's weights, the shirt's and belt's side
  faces removed (nothing shows through the armhole), the front halves hang from their own thigh, unused bones dropped. The male's walk went from 53 to 0 stretched edges per frame at the game camera.
- D88 restored: `tripo_common.fix_unrigged` had given the chains' vertices their neighbours' weights at `tripo_uv` (1 338 male vertices on the chains after the dress, 0 after it); `KEEP_BONES`.
- **D94, the legs push the coat:** `coat_push.py` (maths, the reference), `tripo_coat_push.py` (the bake, last in `build_agents.sh`), `coat_push_check.py` (Blender: numbers and renders),
  `godot/shaders/coat_push.gdshaderinc` + `actor_mesh3d.gdshader`, `geometry/coat_push3d.gd` (`CoatPush3D`), `coat_push_selftest.gd`.

## Found
- **The skirt is a tube 8-32 mm off the trousers; a stride sweeps the legs 25 cm through it.** Spring chains push only at their joints and the top of the skirt hangs from the body's weights; neither
  was going to open the front or raise the back. A stateless push (each vertex along its outward direction to the far side of the leg capsules) did, in Blender first (a numpy twin), then in the engine.
- **Measured (Blender, male LIGHT, skirt vertices deeper into a leg than at rest by > 2 mm, per frame): walk 58.7 -> 0.0, run 62.3 -> 0.0, dive 71.9 -> 0.6 (female walk 47.8 -> 0.0, run 59.9 -> 0.3);**
  one pass left 4.4 / 8.4 / 11.1, a second pass (only for the vertices the first one moved) took them out of the other capsule they had landed in. Seen in the bench in four facings, male and
  female. With the push, springs on or off look alike: the push is the collision, the springs are only flutter, and a state.
- **Moto g04s, 9 LIGHT male Agents walking, uncapped, springs on:** 24.6 and 24.8 ms/frame with the push (two boots), 23.6 without, idle 20.5-20.7: +1.0 to +1.2 ms, PSS unchanged (the first pass alone: 24.4 in three boots, +0.8; the 8 chains on or off:
  23.5 vs 23.5 earlier the same day).
- Traps: (1) the Blender glTF importer gives a mesh with COLOR_0 a material using it, and with one the exporter writes the colour twice (COLOR_0 and COLOR_1): the bake clears the coat's materials.
  (2) `Object.get_meta(key, null)` raises an engine error when the key is absent in 4.7: ask `has_meta` first. (3) A `Skeleton3D` recomputes its global poses (and runs its modifiers) only inside the tree
  and a couple of frames after a pose is set: a selftest has to await frames, not call the modifier. (4) Two `capture.run_godot` runs at once collide on `override.cfg` (two of four failed; the loser
  leaves nothing behind, check `override.cfg` is gone). (5) A shader's uniform arrays (`vec4[6]`) take a `PackedVector4Array` in 4.7.2.

## Open
- The Director's look at the push in the game's camera (the video `videos/coat_push_ab.mp4`: walk and run, before | after) and his call on the springs: keep the simulator and its 24 bones, or build the
  Agents with `SKB_N=0` and let the skirt hang rigid from the Hips.
- T4: `ActorMesh3D` wears the 65-joint rig and must call `CoatPush3D.attach` with a coat material per actor; the clips (the female's own, MV-3 processing).
- The coat's normals are not recomputed (invisible on a black coat; check once it is lit and textured). The dive keeps 0.6 vertices per frame inside a leg (13 mm at worst).
- The male's belt drape; the backpack model and the civil / stealth rule in `DESIGN`; texturing.
- The four rebuilt Agent GLBs are tracked and were NOT committed in the earlier rounds of this session (binary, ~7 MB the set); they are committed with D94.
