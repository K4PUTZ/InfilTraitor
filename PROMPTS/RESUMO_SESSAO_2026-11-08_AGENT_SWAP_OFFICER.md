# Session record 2026-11-08 (later): the Tripo figure is the Agent, the old agent model is the enemy officer

## Done
- **Grenade aim cancel**: the fuse sparks ramp to 0 over the cancel's 0.12 s (`fuse_fx_fade`); scenario op `aim_cancel` + PLAYGROUND take `aim_cancel` film it.
- **The Agent wears the Tripo LIGHT figure by default** (the male; `TRIPO_FIGURE=female` swaps, `none` brings the old rig back for comparisons). Only the agent (family "") is affected; a guard never wears it. Not yet on that figure (unchanged from MV-4): the weapons in hand, the aimed grip, crouch / prone, the throw animation (the grenade's sparks fall back to the head anchor).
- **The old agent model is the enemy OFFICER**: `ActorMesh3D.RIG_BY_FAMILY["_officer"] = agent_live.glb`, `GuardEnemy.officer`, the map's `actors.officers` (optional list of indices into `guards`; `MAPFILE_REFERENCE`), `MapCompiler` -> enemy def `officer` -> `Room._spawn_guards`. PLAYGROUND: guard 6 (index 5, patrol (27..29,10)) is the officer; POI `officer_close`. Look only: no rank rules yet.
- Trap met: JSON integers arrive as floats (`[5.0]`) and `Array.has(5)` is false on them; the compiler compares as ints.
- **Ruling (Director): AP costs (posture included) wait for the GAMEPLAY milestone**, not open yet; until the engine is practically finished no action is restricted. Recorded in `DESIGN_MASTER_PLAN` §3.1; the "posture AP cost never read" item leaves the open list.

## Next (open list, level 2 left): guard noise indicator unwired; the male's belt drape; shirt / trouser defects; then device rounds, MV-4 transitions, the rest as in `RESUMO_SESSAO_2026-11-08_CLOSEUP_LEVEL1.md`.
