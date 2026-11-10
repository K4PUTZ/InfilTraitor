# Session record 2026-11-10 — the code and heritage audit, and the draft plan

**Asked by the Director:** a complete analysis of the code and of the project's evolution (loose pieces, bare wires, pending items, what the 2D-to-3D transition left, engineering practice), then: save it, draft a project to attack the pending items, and an opinion on whether the 2D mechanism costs performance. Read-only session: no code changed, nothing booted, no gate beyond `verify.py docs`.

## What was produced
- **The audit:** [`PROMPTS/AUDITS/CODE_AND_HERITAGE_2026-11-10.md`](AUDITS/CODE_AND_HERITAGE_2026-11-10.md) (commit audited `2162a561`). It holds every number and its source.
- **The draft plan, v0.1, nothing ratified:** [`PROMPTS/PLANNING/HERITAGE_AND_LOOSE_ENDS_PLAN.md`](PLANNING/HERITAGE_AND_LOOSE_ENDS_PLAN.md): six tracks (T1 safe cleanup, T2 the weapon as one object, T3 one path for captures and flags, T4 world coordinates in stages, T5 at the door of A2, T6 documents / version / release identity).
- Landed on `main` as `63bd810c`.

## The findings in short
- The drawing is 3D; the coordinate space is still the 2D isometric plane (kept on purpose on 2026-10-04, with no owner for its retirement). The camera, the actors' positions, the old effects and the free objects go through it.
- A weapon has no single identity (six places), and the pistol has three sizes: 0.180 GU in the hand (computed from the files), 0.277 on the table, 0.25 as a pickup. The muzzle flash and the tracer start at a 2D estimate, not at the gun.
- About 2 500 lines of `room.gd` exist for the old world or for dev tooling (the base-damage replay, the old capture harness); 88 flags are read only from the environment and never reach an APK.
- The 2026-11-04 audit's dead-code list, dead links and git items are all still open.
- `room.gd` is 13 197 lines; the two central classes are called by string; the stealth core has no selftest.

## The opinion given on performance (reasoning, NOT a measurement)
The 2D coordinate space costs a few multiplications per object per frame, well under the 5 % rule for measuring. The costs the Moto rounds named (GPU fill, the world commit, the remesh, GDScript particles) do not depend on it, and the HEAVY segment fits the floor device with the mechanism in place. So it is commercially viable; its cost is engineering (duplication, constants that disagree, estimated anchors). T4 is therefore a maintenance decision, not a performance one.

## Open, for the Director (he will take these up later; nothing starts before)
1. Which track starts, and the go for each (T1 needs his word on the dead-code list, the renames and the git deletions).
2. T2: does a weapon lying on the floor keep a readability factor, or the hand's exact size?
3. T2: "bouncing in the air" was read as the hovering pickup rising and falling in 3D; a dropped weapon bouncing on the floor is a different object.
4. T4: whether to reopen the 2026-10-04 decision that kept the 2D coordinate space.
5. T5: the save's format; T6: the documents' curation and JAMES's status.
