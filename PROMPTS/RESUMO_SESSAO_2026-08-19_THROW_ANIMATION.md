# RESUMO_SESSAO — 2026-08-19 (the throw animates, and a projectile nobody could see)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-19_AGENT_SHOOTS.md`
**Gates:** lint ✅ 210 files · selftests ✅ 35 clean / 0 failed · invariants ✅ ·
CODEMAP ✅.

---

## The one-line version

The grenade throw is animated end to end — the arm comes up when the player picks
a GU and HOLDS there, comes back down along the same frames if they cancel, and
swings through a release and a follow-through when they commit. The shot's
decorative projectiles turned out to be invisible for a reason worth writing
down, and the enemies now stand one per material wall at four different ranges.

---

## 1. What the Director ordered, and what shipped

| Ask | State |
|---|---|
| Aim on GU select / right-click / first tap — weapon already pointed at "disparar" | ✅ both paths |
| Throw movement + bake, all intermediate states | ✅ standing; crouch/prone pipeline prepared |
| Cancel the grenade, quickly, "só pra não sumir de repente" | ✅ the raise, reversed, at 0.12 s |
| Reuse frames in reverse, refine with ease | ✅ cancel IS the raise reversed; smoothstep in-betweens |
| Symbolic decorative projectiles, fast, vanishing | ✅ — and the reason they were invisible is §4 |
| Enemies near the blocks, varied distances, per material | ✅ four guards, 2/4/6/9 GU |
| Remove the agent copies | ✅ probe bracket emptied, machinery kept |
| Posture distance penalties | ✅ crouch −2 GU, prone −4 GU, floored at 1 |

**Scope correction, obeyed literally** (Director, mid-session): *"precisamos
refinar as posturas agachado e deitado ainda, então pode deixar só o pipeline
dessas posições preparado. Por enquanto vamos fazer só o arremesso em pé."*
`p3_throw_export.py`'s `POSTURES` lists all three and exports one; the other two
print WHY they are held rather than being silently absent.

---

## 2. The throw, as built

Two sequences per posture, and **the cancel is not one of them**:

- `raise` — 6 phases, idle → cocked, 0.18 s, **held** on its last frame for the
  whole aim. Played BACKWARDS at 0.12 s to cancel.
- `release` — 10 phases, cocked → wind → throw → follow-through → idle, 0.40 s.

The in-betweens are sampled from five key poses with a smoothstep ease, which is
MOVEMENT_MASTER_PLAN §4's rule and the Director's own "refinar com ease". Raising
the frame count costs a re-run, not re-authoring.

**The left arm throws; the right keeps the shotgun.** `p2.export_posed()` gained
a `left_arm` override that forces the one-handed branch for a two-handed weapon —
without it the thrown grenade would be held by a hand also gripping the pump.

**The grenade leaves on the RELEASE frame, not on a timer.** `AgentSprite` emits
`throw_released` at the phase derived from the key list (`RELEASE` is the 3rd of
5 keys → half way, at any phase count), and the arc awaits it. Retiming the
animation cannot desynchronise the projectile.

**The cocked pose was rebuilt after looking at the first bake.** v1 had the
upperarm and forearm pointing in nearly parallel directions, so the elbow never
bent and the figure read as holding a lantern overhead. A cocked throw is an L —
the two bones must point in nearly OPPOSITE Y directions.

---

## 3. Three filename/cache collisions, again

Same class as the two found yesterday, found twice more today:

1. **`export_posed` had no phase in its output name.** Sixteen throw phases all
   wrote `agent_posed_shotgun_lowered.glb`; every manifest entry pointed at one
   file and the bake would have rendered sixteen copies of the last phase.
   Nothing failed — the heights even varied. Caught by reading the export log.
   Fixed with a `tag` that reaches the filename.
2. **The bake viewport was a `const` sized for the standing figure.** A raised arm
   reaches 0.160 m past the crown and hit the top edge, which the crop gate
   correctly refused. `AGENT_BAKE_VIEWPORT` now enlarges the CANVAS without
   touching the scale: `px_per_screen_m()` never reads it and `ortho_size()`
   divides by it, so a taller frame shows more world at the identical pixel size.

**The height gate got a caller-declared band** rather than an exemption. Lower
bound = the standing figure exactly, and that is a real gate: these poses move
only the left arm, so an arm can only ADD height. Upper bound measured from the
first run's own printout (2.000 → 2.160 m), pinned at 2.200.

---

## 4. ⚠️ The decorative projectile was invisible, and the cause is instructive

The tracers were being created correctly — 24 of them, with correct endpoints,
printed to prove it. They were never SEEN.

`_draw()`'s own call log settled it:

```
[TRACER-DRAW] 24 streak(s), first age 0.000
[TRACER-DRAW] 24 streak(s), first age 0.141      ← one frame, 141 ms long
```

The firearm path pays **~310 ms of synchronous CPU at the trigger** (§0's
W-PRECOOK measurement, `technical_debt` 16). The tracer's whole 0.14 s flight
elapsed inside ONE stalled frame, so the round was only ever drawn already
arrived.

**Two changes, and the first was not enough.** Splitting the controller's pass
into resolve → fly → break moved the stall to the next frame (ages went
0.000 → 0.139) and the streak parked again. What actually fixed it was changing
the UNIT:

> **A duration is the wrong unit for an animation that must survive a stall.**
> What has to elapse is not time, it is pictures of the round in different
> places, and a 141 ms frame produces exactly one of those however long it takes.

`TracerOverlay` now ages in DRAWN FRAMES (8 hold + 7 fade). Measured after:
frames 0, 1, 2, 3, 4, 5 — the round crosses. Evidence:
`Screenshots/history/shot_proj_2_tracer.png`.

The resolve/fly/break split was kept anyway: it is the more correct order, and
the Director asked for it in that order — flash, then the round crosses, then the
wall reacts.

---

## 5. The material board

One guard per material wall, each ON the line from the agent to ITS OWN wall, at
a different fraction along it — so shooting each tests a different angle AND a
different range on a different material. Measured, one shot each:

| material | distance | DESTROYED | DENTED | CRACKED |
|---|---|---|---|---|
| concrete | ~9 GU | 8 | 23 | 0 |
| **metal** | ~6 GU | **0** | 13 | 5 |
| stone | ~3 GU | 1 | 22 | 0 |
| **wood** | ~2 GU | **21** | 22 | 0 |

Metal resists, wood gives way — `ShotPunchTable.RESISTANCE` behaving as written
(metal 2.2, wood 0.8), on the real map rather than in a fixture.

**A first placement failed this test and was fixed:** the guards were originally
placed near their blocks but not on the agent's line to them, so the wood shot
flew past everything to the east boundary and tested nothing.

---

## 6. `throw_origin()` corrected — the stale placeholder, second half

Yesterday's session fixed `muzzle_origin()`'s stale `HEAD_OFFSET` and explicitly
LEFT `throw_origin()` alone, because moving a tuned ballistic arc deserved its
own pass. This is that pass, and the reason is the animation: building a throw
pose on top of a launch point that misses the hand by ~100 px would bake the
error into the pose work. Both now read the bake's own `anchor_px` /
`head_socket_px` through one `_head_anchor()`, so the throw, the arc's launch
height and the muzzle cannot disagree about where the hands are.

---

## 7. Open

- **Crouch and prone throws** are pipeline-ready and unauthored, by the
  Director's own call — their base postures are still being refined.
- **The tracer still flies through a stalled frame**, it is just immune to it
  now. W-PRECOOK remains the real fix for the 310 ms, and remains scheduled at
  the end of GAME-01.
- **The dev and normal variants both need every new bake.** Dev vision is ON at
  boot, so a bake that exists only in the normal family silently does nothing —
  hit again today, and the warning added yesterday is what caught it in seconds
  instead of in a capture.
