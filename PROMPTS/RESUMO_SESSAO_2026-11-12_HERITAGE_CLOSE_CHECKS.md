# Session summary — 2026-11-11/12: HERITAGE carried out, the checks cut to the work left

## Done (all on `main`, pushed)
- **HERITAGE plan v0.2 ratified and carried out** (`PROMPTS/PLANNING/HERITAGE_AND_LOOSE_ENDS_PLAN.md` §5 rulings, §6 progress):
  - T1, T3, T4, T6 done;
  - T2: W1–W4 (the weapon is one object at its hand size, the shot leaves from each weapon's muzzle, the pickup floats with the
    actors' contact shadow);
  - T5: the stealth selftest, the alert meter reset by the HUD's Reset (a real bug, red 100/100 → green 0/100).
- **The `DevFlag` registry** (F1), **one version source** (V1), **JAMES retired**, **one storey value** (T4, 19.596 px a level).
- **Save ruled**: the game is ephemeral; the checkpoint is the map's whole "RAM" (damage and every consequence), built LAST, just
  before M7.0 (`docs/production/roadmap.md`); the player's progression is saved as it happens.
- **`capture.py` start timeout** (`bb277505`).
- **Baseline intermittence diagnosed and accepted** (blast stages sliced by a wall-clock budget at a fixed FPS; plan §6, 2026-11-12).
- **The checks follow the work left** (`84b3a1ba`): 66 selftests of the closed engine work parked (`--all`), smoke on PLAYGROUND +
  SEG_TYPICAL, `full` = light gate + occlusion / rotation / pick (~3 min), `FREEZE_IDLE` for a deterministic light baseline.
  `CLAUDE.md`'s verification table and `verify.py`'s header carry the new tiers.

## Open (recorded where they live)
- GAMEPLAY milestone: W5 (the 3D grenade), the ballistic line from the muzzle, the stealth thresholds (game 0.25/0.50/0.75 vs the AI
  plan's 0.30/0.60/1.00).
- A muzzle point and a hand size for each new weapon at its certification (the pistol is the only one).
- The checkpoint, last before M7.0.
- The brick mismatch between the committed manifest and `generate_voxel.py` (never run it at the root).

## Next
Back to animation and characters (MOVEMENT), with the lighter checks: `verify.py` (smoke) by default, `look` / `full` for a light change.
