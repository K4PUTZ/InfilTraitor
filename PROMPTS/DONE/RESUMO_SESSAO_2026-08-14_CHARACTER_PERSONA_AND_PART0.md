# RESUMO_SESSAO — 2026-08-14 (the character: persona, plan, and Part 0's two tests)

**Version:** 0.9.101 (unchanged — nothing shipped to the game itself).
**Commits:** `2f67fd1d` → `1716eb6c`, eight, all pushed.
**No `verified/` tag** — none was asked for.

---

## The one-line version

The character track went from *"nothing is designed"* to **fourteen ratified
decisions (D32–D45), an execution plan, two new milestones, and both of Part 0's
tests run** — S1 answered (ASTC yes, ETC2 no) and S2 rendered and awaiting the
Director's eye.

---

## 1. What the Director asked, in order

1. Review the existing docs before touching the persona.
2. Debate personality/attitude/behaviour **before** design.
3. Register the decisions.
4. Write a master plan covering the tests, the stages, and the 3D model.
5. Start the tests, with mockups.
6. **Maximum priority:** communicate with visual examples generated in Blender.

---

## 2. The persona — what was decided

`ACTOR_MASTER_PLAN` §2 holds the full text. Compressed:

- **Identity lives outside the body** (D32) — lore, stealth abilities, movement
  style, technology, contacts. Two fixed archetypes (Shepard's model) sharing
  **one skeleton, pose library and animation timing**; they differ in mesh,
  proportion and head. The body carries *recognizability*, not personality.
- **Persona:** a cunning operator — socially fluent, reads between the lines,
  persuades and deceives. A double agent, renegade to both corrupt police and
  drug lords after the campaign, motivated by something **renewable, never
  resolvable**.
- **The tonal anchor is a trickster with humour** — *"olha o passarinho"* as a
  way to neutralise a guard. That single line did more to fix the character's
  register than any of the structural discussion around it, and it rules out the
  brooding-operative posture language entirely.
- **Art direction** (D35): action figure — visible joints, swappable parts, low
  poly — crossed with gangster / Michael Jackson. **The same reference D16 named
  on 2026-07-26** (Moonwalker's pose language), arrived at independently three
  weeks later without anyone noticing.

---

## 3. The decisions, D32–D45

Full text in `ACTOR_MASTER_PLAN` §2. The load-bearing ones:

| D | Why it matters |
|---|---|
| **D35** | The source is a **rigged low-poly mesh**. This gated the other four questions, and D34's arithmetic had already made it self-answering — a voxel twin has no skeleton, so 192–448 body sets at ~500 ms/pose is arithmetically dead. |
| **D34** | The cost contract: only archetype × silhouette class multiplies. Layers are additive; colour is a free shader uniform. |
| **D44** | **Four facings, permanently.** A diagonal step resolves as two orthogonal GU steps, so the yaw axis **can no longer grow** — this removed the last way the art budget could expand, and it is why the plan went to v2.0. |
| **D40** | Clothing is baked into the silhouette class, so there is no separate outfit to animate. The weapon layer indexes on **grip** (~3), not pose (≥8). |
| **D42** | The binding constraint is **RAM, not CPU** — and the dominant mitigation is that D34's axes are mutually exclusive at runtime. |
| **D39** | Poses are keyframes; **animation between them is the deliverable.** |

---

## 4. Part 0 — both tests run

### S1 — normal maps under mobile compression → **ASTC yes, ETC2 no**

60 measurements, real GPU. **Both gates passed before any number was read:**
same-config re-render diff **0**; every light direction produced a 200–227 luma
spread, so no D22-style flat-image false pass.

    ASTC (as colour)   worst maxD  96   avg meanD  4.08 / 255  (1.6%)
    ETC2 (as colour)   worst maxD 164   avg meanD 14.07 / 255  (5.5%)

**D17 is safe to scale, and §8's RAM arithmetic improves** — ASTC 4×4 is 8
bits/texel against RGBA8's 32.

**Two findings worth carrying forward.** `COMPRESS_SOURCE_NORMAL` is a
**contract with the shader**, not a quality dial: used against the shipped
`.rgb`-reading shader it measured 6× *worse*, and the first run was discarded and
redone rather than reported. And at the shotgun's **real 66×33 px size all six
variants are indistinguishable** — the 8× strip was the right view to *find* the
artifact and the wrong one to decide it mattered (the Director's call).

### S2 — the mockup and the turn → **rendered, awaiting judgement**

Blender 5.2.0 arrived mid-session, so the mockup was **generated to spec** rather
than sourced generic: 20 bones, 19 segments, all seven sockets.

**A character was scriptable at all only because the art direction made it so** —
an action figure is rigid segments on visible joints, so every segment binds 100%
to one bone. No weight painting, no falloff. The style and the tooling agree, the
same way D35 records the style and the layering architecture agreeing.

The turn renders at 0/1/3/7/11/15/23 in-betweens, eased, with **head and chest
leading the hips** because `guard_enemy.gd` turns `vision_angle` at 1.35× and D41
ratifies preserving that read. Director: *"faz muita diferença cada um"*, with 7+
clearly best.

---

## 5. Scale — settled, measured, and once misread

The Director's cover spec made §4.7 derivable: **1 voxel = 0.20 m.**

| | voxels | m | px |
|---|---:|---:|---:|
| slice | 8 | 1.60 | 160 |
| **room = 2 slices** | 16 | 3.20 | 320 |
| standing | 9.8 | 1.96 | 196 |
| crouched | 5.5 | 1.10 | 110 |
| prone | 2.2 | 0.44 | 44 |

Verified by measuring the evaluated mesh with a loud fail outside the band — the
first run came back 9.8 / 7.3 / 4.0 and the poses were deepened until they
measured in.

**A slice is HALF a room.** Calling 1.60 m "short for architecture, a deliberate
realism trade" was reading a slice as an architectural storey; the Director
corrected it the same day and the note was **withdrawn, not softened**. And the
character is deliberately large on purpose: *"ao fazer os personagens maiores,
estamos granularizando os voxels de graça."* The vertical space already exists
and is already paid for.

---

## 6. Three corrections to premises that were about to carry decisions

Recorded because each was heading into a real choice:

1. **"We have RAM to spare per the earlier check"** — S1 measured *compression
   fidelity*, not headroom. Now measured: the one resident loadout costs
   2.2–144 MB across the option grid, so the smoothness decision is **not**
   RAM-bound. The conclusion was right and the premise was wrong. **Device
   headroom is still unmeasured.**
2. **"We're at 30 fps"** — no. Nothing caps the rate anywhere; **60 is the stated
   target**. And the animation is **time-driven** (`floating_collectible.gd:331`),
   so at 30 fps it keeps correct duration and drops frames — graceful, and
   exactly the bug D26/v1.5 already paid for once.
3. **"Vertical parallax is ownerless"** — my claim, and wrong. It is documented in
   **four** places: `ARCHITECTURE.md` §"Vertical Rendering and Parallax" (up),
   `DESTRUCTION_MASTER_PLAN` D18 (down, through craters), `OCCLUSION_MASTER_PLAN`
   O9, and `systems/lighting.md`.

**The display ceiling**, which nobody had stated: a sprite frame cannot show for
less than one rendered frame, so a *D*-second turn at *F* fps displays at most
*D×F* frames. At 60 fps a 200 ms turn caps at 12; 23 in-betweens need ≥417 ms
just to appear.

---

## 7. What was created

| Artifact | What |
|---|---|
| `PROMPTS/PLANNING/CHARACTER_MASTER_PLAN.md` | **New.** The execution plan — 9 Parts, the model spec, the tests, the budget contract |
| `ACTOR_MASTER_PLAN.md` v2.0 | D32–D45; Parts 1/3/4 now point at the new plan |
| `milestones.md` → **GAMEPLAY-01** | **New.** The distraction verbs, manipulable NPCs, lamp destruction |
| `milestones.md` → **MONET-01** | **New.** Shop/economy/forum. A repo-wide review found **no monetisation material existed anywhere** — §16's nine rows were the entire body of design |
| `milestones.md` → M7.0 | Gains the pose/clothing bake cache |
| 4 tools | S1 spike, resident-memory probe, and three Blender generators |

---

## 8. State at close

    check_invariants.py      ✅ OK (every commit)
    gen_codemap.py --check   ✅ exit 0
    project_lint.py          ✅ PASSED — 204 files (pre-commit, every commit)

`run_selftests.py` was **not** run and must not be cited: no gameplay code
changed this session. The last real result stands — 35 clean / 0 failed.

---

## 9. Next session — in order

1. **The turn's frame count and rate.** 15 in-betweens at a clean 30 Hz gives a
   **570 ms** turn; at 60 Hz, **283 ms**. Render both side by side and let the
   Director choose by eye — this is the only thing still blocking a frame budget.
2. **Part 2 — the minimum viable agent.** Idle + 3 grips × 4 yaws, baked through
   the Godot rig, composited, and **the vector placeholder in `agent.gd::_draw()`
   gone.** This is what the Director asked to see next (*"queria ver com o
   personagem em cena mesmo, com iluminação"*) and it is the only Part with
   external dependents: **firearm aim mode and W-PRECOOK both wait on it.**
3. **Open and not urgent:** the cape's own animation cost (D43), the free
   fallback for a purchasable state indicator (D36 / §9 #4), how many silhouette
   classes (§9 #2), and on-device headroom.

**Standing instruction from this session, at maximum priority:** debates and
close choices get **rendered**, not described. Recipe and tooling are in the
`render-dont-describe` memory.
