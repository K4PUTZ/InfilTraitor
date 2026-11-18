# Session summary 2026-11-17 (later) — the shots' own projectiles; POLISH-01

Picks up the owed list of `RESUMO_SESSAO_2026-11-17_H1_FAMILY_SUPPRESSORS.md`.

## Rulings of the day (Director)

- **POLISH-01**, a milestone before M7.0's optimization: weapon skins, secondary variants of the same objects, cosmetic effects,
  FOLEY (`docs/production/milestones.md`). Audio is split three ways: POLISH-01's foley (the sounds), M6.0 (sound as a gameplay
  mechanic), SOUNDTRACK (the music, in progress on the PC). M6.05 (visual polish) is merged into POLISH-01: visual and sound polish are one milestone, before the optimization.
- **The grapple's kinds** (ITEMS §2.5): pull the guard to the Agent, pull the Agent to the guard, pull an object, move the Agent
  across the map, pull a wall down; Claude's extras ratified too (disarm, distant trigger, drop something on a guard, fetch, rappel /
  zip line). The grapple PISTOL is early game and takes the pistol slot (no firearm, no dart); late game the hook moves to the left
  wrist device, freeing the right hand and the pistol slot. Until GAMEPLAY: the hook bites, holds and is wound back.
- **Darts and probes stay** on the map and in the destruction save; weak devices may stop drawing them (WEAPON D21's second
  amendment). The flare: its own glow only. The sci-fi pistols and the ray gun: energy bolts.

## Built

`WeaponDef.fx_*` (an `fx` section per row), `ShotProjectiles3D` (dart, probes, hook, flare; the record and its save; the fall),
`ActorMesh3D` pieces (split, hidden, string fired, drum turning, reload on putting the weapon away), coloured bolts in
`TracerOverlay`, `Room.spawn_energy_flash`, `SaveState` `stuck_projectiles`, `shot_projectiles_selftest`, `capture.py` keeps the
whole run's log in `temp/capture_last.log`. Takes `crossbow_shot`, `projectile_shots`, `dart_persist`. MOVEMENT §11.6 step 5 has
the record.

## Open

- The fall of a dart whose voxel goes is pinned by the selftest only; the Director: not important (2026-11-17).
- A dart still leaves a CRACKED mark (the bullet pipeline marks one voxel at punch 0; it was so before today) and that mark is not
  brought back by a save/restore (damage replay, not the dart).
- The bolt colours, the flare's size, the probes' look: first passes, POLISH-01.
- The wrist grapple (W) has no model or hold yet.

## Later the same day: moving with a weapon; the holster convention

- **Tried:** the pistol fixed in the right hand (the aim's placement) while today's walk and run played unchanged, a throwaway
  probe, never committed. **Director:** *"vamos precisar de uma animação específica pra correr com a arma em modo stealth.
  Claramente não vale a pena tentar só atachar a arma"*. Moving with a weapon (B7) is PLANNED as MOVEMENT §11.6 step 10 (its own
  gaits; the bank's S2 / S3 stealth clips with the pistol are the candidates).
- **Ruled:** *"o agente saca, atira e guarda automaticamente antes de andar/correr/fazer outra coisa"* (MOVEMENT §11.8 Q1).
  Built: a move waits for the weapon to be away, the hold after a shot cut short (`Agent._weapon_away`, `ActorPose.stow_weapon`,
  `ActorMesh3D.weapon_out`); a kneel or a rise waits for the other posture's gun. Before the change, a walk ordered right after a
  shot turned and stepped with the arm still up and the gun in it; a kneel ran together with the holster. A move ordered right
  after a shot now leaves up to 0.92 s later (the holster: the draw timeline backwards). Takes `holster_walk`, `holster_run`,
  `holster_crouch`, both figures.
