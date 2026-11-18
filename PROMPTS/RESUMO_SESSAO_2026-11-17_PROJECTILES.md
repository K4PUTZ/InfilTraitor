# Session summary 2026-11-17 (later) — the shots' own projectiles; POLISH-01

Picks up the owed list of `RESUMO_SESSAO_2026-11-17_H1_FAMILY_SUPPRESSORS.md`.

## Rulings of the day (Director)

- **POLISH-01**, a milestone before M7.0's optimization: weapon skins, secondary variants of the same objects, cosmetic effects,
  sound (`docs/production/milestones.md`). Whether M6.0 / M6.05 fold into it is open.
- **The grapple's kinds** (ITEMS §2.5): pull the guard to the Agent, pull the Agent to the guard, pull an object, move the Agent
  across the map, pull a wall down. Claude's further candidates (disarm, distant trigger, drop something on a guard, fetch, rappel /
  zip line) are NOT ratified. Until GAMEPLAY: the hook bites, holds and is wound back.
- **Darts and probes stay** on the map and in the destruction save; weak devices may stop drawing them (WEAPON D21's second
  amendment). The flare: its own glow only. The sci-fi pistols and the ray gun: energy bolts.

## Built

`WeaponDef.fx_*` (an `fx` section per row), `ShotProjectiles3D` (dart, probes, hook, flare; the record and its save; the fall),
`ActorMesh3D` pieces (split, hidden, string fired, drum turning, reload on putting the weapon away), coloured bolts in
`TracerOverlay`, `Room.spawn_energy_flash`, `SaveState` `stuck_projectiles`, `shot_projectiles_selftest`, `capture.py` keeps the
whole run's log in `temp/capture_last.log`. Takes `crossbow_shot`, `projectile_shots`, `dart_persist`. MOVEMENT §11.6 step 5 has
the record.

## Open

- The fall of a dart whose voxel goes is pinned by the selftest only (no blast in reach on PLAYGROUND took the dart's own voxel).
- A dart still leaves a CRACKED mark (the bullet pipeline marks one voxel at punch 0; it was so before today) and that mark is not
  brought back by a save/restore (damage replay, not the dart).
- The bolt colours, the flare's size, the probes' look: first passes, POLISH-01.
- The wrist grapple (W) has no model or hold yet.
