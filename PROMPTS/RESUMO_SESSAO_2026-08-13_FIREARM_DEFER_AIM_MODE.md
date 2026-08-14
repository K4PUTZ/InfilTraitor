# RESUMO_SESSAO — 2026-08-13 (firearm pre-production deferred, aim mode specified, the character track opens)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-13_DOC_AUDIT_EMBER.md`
**VERSION:** 0.9.101 — **unchanged**, no code was touched this session
**Commits:** `e099db6e`, `e68dc7c9` (both `[DOCS]`, both pushed to `main`)
**Plans touched:** `WEAPON_MASTER_PLAN` (v1.0 → v1.1, new §0 banner, §5c, §7c,
D30–D38), `ACTOR_MASTER_PLAN` (v1.6 → v1.7), `docs/DESIGN_MASTER_PLAN` (§8.7 new,
§10.2 superseded), `docs/production/milestones.md`, `current_state.md`,
`technical_debt.md`.
**Closed:** 2026-08-14, on the Director's word.

---

## The one-line version

A documentation-only session that reversed the previous one's schedule: firearm
pre-production is deferred to the end of the combat milestone because there is
no character to hold a weapon, aim mode is specified in its place, and the ACTOR
living-beings track — deferred since 2026-07-26 — is open.

**No code was written. No feature was built. Nothing here has been verified by
execution, because there is nothing executable to verify** — the session's whole
product is written decisions. That is the honest scope, stated plainly so the
next reader does not go looking for a build.

---

## 1. What the Director asked

Four things, in one message:

1. Postpone firearm pre-production until the character exists and holds a
   weapon — *"pra não ficar testando com mecanismos visuais teóricos"* — and
   park it in the optimization milestone.
2. Give the agent shooting: rifle (1), pistol (2), shotgun (3), `S` for aim
   mode; targets picked from a short cyclable list with hit percentages
   (Fallout 3 / XCOM); auto-target the nearest enemy on entry, resolve the wall
   behind it, pre-compute the miss damage; recompute on target change; Enter or
   a second tap rolls the dice.
3. Remember the shotgun's pellets are independent and each applies its own
   damage.
4. *"Agora chegou a hora de produzir realmente o personagem."*

Then, after a first pass: four rulings that corrected the placement and closed
two open questions (§4).

---

## 2. W-PRECOOK — deferred, then moved twice

**The measurement is unchanged and worth restating**, because the deferral is
easy to misread as the problem going away:

    resolve 1.00 ms cpu · render 4.9 ms wall over 0 frame(s) · repaint 309.89 ms cpu ·  9 voxel(s)
    resolve 1.09 ms cpu · render 7.9 ms wall over 0 frame(s) · repaint 322.64 ms cpu · 18 voxel(s)

Firing a gun costs ~310 ms of synchronous CPU for nine voxels, all of it in
`_repaint_voxel_light_buckets()`. A grenade destroying 453 voxels commits in
0.5 ms, because it pre-computes during the throw.

**Why deferring is a verification decision, not a priority one.** W-PRECOOK's
entire job is to hide that cost inside the aiming window. There is no aim mode,
no shooter, and no agent that holds a weapon — so the window's duration, trigger
and interruption points would all have to be mocked. This project's own evidence
rules already ban standing a synthetic fixture in for the real path.

**It moved twice in one session, and the second move was the Director correcting
the first.** Assigned to M7.0 (the optimization milestone, as instructed), then
pulled forward: *"pode colocar o W-PRECOOK mais cedo, vamos fazer ele no final da
milestone de combate."*

**M7.0 was the wrong home for exactly the reason it was chosen.** "Optimization"
named the *kind* of work; the work's real dependency is aim mode, which lands in
GAME-01. M7.0 also sits after M6.05, so parking it there would have buried a
gameplay-blocking stall behind visual polish. End of GAME-01 satisfies both
halves: aim mode exists to hide the cost inside, and no finished combat feature
ships carrying the stall. The M7.0 entry is kept as a moved-out marker rather
than deleted.

Also logged as `technical_debt.md` item 16 with the real numbers.

---

## 3. Aim mode — specified, unbuilt (D31–D36, flow in §5c)

```
ENTER AIM MODE (S)  ->  weapon already selected (1/2/3, open set)
                        nearest enemy auto-targeted
                        |
PRE-RESOLVE current target:  the line past the target
                             which wall is behind it (VOID is valid)
                             what a miss would do to it
                             LINE -> one plan · CONE -> N pellet plans
                        |
CYCLE  ->  discard, pre-resolve the new target
                        |
CONFIRM (Enter / second tap)  ->  hit roll per projectile
                        |
   ON HIT  -> damage roll against the actor
   ON MISS -> commit the pre-computed backdrop damage
```

**D32 supersedes D25's mechanism, not its principle.** A shot still always
targets an actor and never a free direction; what changed is that the contextual
menu becomes a modal aim mode with cycling and a visible percentage. The
percentage is the first time D12's hit roll becomes player-facing information.

**Input verified against the real `[input]` map, not assumed:** the project binds
`Z X V L H P K R`, arrows, `Esc` and `G` (`ui_grenade_mode`). `1`, `2`, `3` and
`S` are free. These land as InputMap actions beside `ui_grenade_mode`, never raw
keycodes (INTERFACE_MASTER_PLAN Part 1). The game is mobile-first portrait — the
keys mirror on-screen controls, they are not the primary interface.

**Cancellation is an assumption, flagged as one.** `Esc` mirrors grenade aim
mode; the Director did not state it.

---

## 4. The four rulings — and one that corrected me

**W-PRECOOK placement** and **the bake-cache check** — §2 above and §5 below.

**D36 ratified.** *"Sim, shotgun calcula tudo e depois resolve, tudo certo."*
This started as my proposal (marked 🟠) and became the model: a shotgun computes
the whole all-miss plan — the upper bound of the work, so it costs no more than
the worst case — and the rolls then decide which of the N separable sub-deltas
actually commit. `PREDICTION_MASTER_PLAN`'s `build_plan()`/`commit()` split has
the right shape, but firearms use `apply_point_impact()` and share **neither**
blast mutator, so this is new construction on a proven pattern.

**D37 closes Q1 — and supersedes design canon.** *"Não, vamos ter mais armas
disponíveis, desde granadas até dardos tranquilizantes. Podemos ter mais decisões
relacionadas ao modelo de gameplay restringindo o acesso a tudo de uma vez, mas
por enquanto deixa liberado."* `DESIGN_MASTER_PLAN` §10.2's one-weapon-per-mission
loadout rule is no longer a live constraint; its tier table survives as the
catalog. Restricting access stays an **undecided** design lever, so nothing may
be built assuming either state is permanent. Concrete consequence: D31's number
keys are a selection surface over an **open, growing** set, not three slots.

**D38 closes Q2 — and corrects the question rather than answering it.** *"Não é
teto, é um cenário mais comum. Se houverem 6 inimigos, o sistema tem que circular
cada um."* I had posed this as bounded-vs-unbounded pre-production. **That
framing was wrong.** D33 pre-resolves only the *current* target, so peak cost is
**one plan** whether there are two candidates or six. What the candidate count
actually governs is how often a cycling player discards a plan mid-flight — a
**cancellation** problem, not a budget one.

§5c's "why W-PRECOOK gets smaller" paragraph was corrected accordingly, and the
honest version is now on record: **the plan gets smaller and bounded; the state
machine around it does not obviously get simpler**, because cancel-and-resume is
exactly the half of the grenade's machinery that survives. D38 also forbids any
fixed-width target UI — cycling has to be a real list traversal.

---

## 5. Off the agent's list

The Baking System cache check the previous session queued is now the Director's
own: *"por enquanto eu mesmo vou testar o cache do Baking System, substituindo os
arquivos de texturas nas pastas. Pode tirar isso da sua lista."*

A **separate** deliverable was added to M7.0's last optimization stage, per
*"coloca um lembrete para a gente tratar o cache do baking system + decals na
última etapa da otimização."* Recorded as two different things on purpose: the
smoke test answers *does it obviously work*; the M7.0 pass answers *does it hold
against the shipping art* — cache invalidation, `BAKE_CODE_VERSION` /
`DAMAGE_BAKE_LOCAL_VERSION`, decals recompositing over new art.

---

## 6. The character track is open — and deliberately undesigned

`ACTOR_MASTER_PLAN` D18's living-beings deferral is lifted (Parts 1, 3, 4).
**No design was written**, because the Director asked to discuss the model's
construction first. The revision does one thing: it dates the gate opening and
records that **Part 4 (weapon layering) is what the firearm work is waiting on**
— which makes Part 4 load-bearing, not cosmetic.

`current_state.md`'s Animation/Sprites section moved from *"0% — Not Started,
awaits post-demo"* to **ACTIVE**, with what exists to build on and what does not.

### What the analysis found, for whoever picks this up

**The agent today is a placeholder with no facing at all** — a 44×61 px vector
box outline, `agent.gd:263`. There is nothing to inherit.

**Perspective is free.** On-screen yaw is `facing − perspective`, which is
cyclic: 4 facings × 4 room perspectives = **4 distinct yaws, not 16**. Lighting
per perspective is also free — the relight shader resolves it at runtime.

**The turn is NOT free, and this is the finding worth carrying forward.**
`guard_enemy.gd:201` interpolates `body_angle` continuously toward
`facing_angle_deg` at `TURN_SPEED := 4.0`, with `vision_angle` turning
independently at 1.35× — head leading body. That works because the guard is
vector geometry: rotation costs nothing. **A sprite cannot rotate** — every
intermediate angle of a turn is a frame that must exist. Either the turn becomes
discrete, or the yaw count rises sharply. The vision cone itself is safe:
`DESIGN_MASTER_PLAN` §4.6 already ratified that it is vector, never a sprite.

**Layering defuses the combinatorial explosion.** Weapon baked into the body:
`3 × P poses × Y yaws`. Weapon as its own albedo+normal pair from the same
camera at the same yaw, composited over a per-(pose, yaw) hand anchor:
`body(P×Y) + weapon(3×Y)` — additive. The bake rig already emits that pair, the
relight shader already consumes it, and `PropDef.layers` (D7) exists and has
never had a consumer. Part 4 is literally this.

**The decision everything hangs off: is the source rigged?** D12's two paths are
not equivalent for a character. A voxel twin has **no skeleton** — every pose is
re-authored voxel by voxel, at a measured ×8 cost of 16 576 nodes and ~480–500 ms
per pose. An imported mesh is rigged and proven end to end (shotgun, grenade).
A third path neither D12 nor Part 1 names: **a rigged low-poly mesh authored to
read as voxel** — skeletal animation, same world look; the bake rig cannot tell
the difference, it is the same SubViewport + orthographic camera either way.

### Five questions left open, for the next session

1. **Source** — rigged mesh, voxel twin, or the hybrid? *(this one gates the
   other four)*
2. **The turn** — does the character snap between facings, or turn through them?
3. **How many facings** — 4 (like movement) or 8 (the shot is 360°, D15)?
4. **Minimum viable pose set** — idle + three weapon stances unblocks the
   firearm work; walk / crouch / prone / peek / death can follow.
5. **Face and identity, or silhouette?**

Director: *"Vamos debater isso com mais calma depois. Precisamos discutir como
vai ser a construção da persona e outros detalhes."* — so the persona itself,
not just the model, is part of that conversation.

---

## 7. State at close

**Gates:**

    check_invariants.py      ✅ OK (both commits)
    gen_codemap.py --check   ✅ exit 0 (both commits)
    project_lint.py          ✅ PASSED — 202 files, no real compile errors
                                (pre-commit hook, both commits)

`run_selftests.py` was **not** re-run this session, and should not be cited as
evidence: no code changed, so the last real result stands — 35 clean / 0 failed,
recorded in the previous session's close.

**No VERSION bump** — nothing shipped. **No `verified/` tag** — none was asked
for.

**Next session:** the character. Question 1 above first; the other four follow
from it.
