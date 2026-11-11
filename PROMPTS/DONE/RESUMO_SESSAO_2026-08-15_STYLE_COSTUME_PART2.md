# RESUMO_SESSAO — 2026-08-15 (the style, the costume, and Part 2 taking the lead)

**Version:** 0.9.102, unchanged. No tag — none was asked for.
**Code touched:** none. **Captures produced:** none, and none are claimed.
This was a research-and-decision session; every artifact below is documentation.

---

## The one-line version

The character's **art direction and costume are settled** (D52, D53), Alpha is
scoped to **mechanics only** with finish deferred to Beta (D54), the licence
filter for imported geometry is **hard CC0** with two named exclusions (D57),
and **D48 was reversed the same day it landed** — Part 2 now leads, Part 8 is
deferred and may ship as 2D (D55), which means **firearm aim mode and W-PRECOOK
stop waiting**.

---

## 1. Seven decisions, D52–D58

Registered in `ACTOR_MASTER_PLAN` §2 with the Director's own words, per
convention. Cited by number everywhere else.

| D | What it settles |
|---|---|
| **D52** | Stylised figure — Sonic's volumetric cartoon against Moonwalker's human silhouette, with Dick Tracy / Bond / TF2 Spy as the tailoring language. **Splits D35**: *swappable parts* kept (it is what carries D34), *visible joints* declined as finish |
| **D53** | The costume — reversible white/black overcoat, blue shirt + armband, white tie, all-black suit and hat, flipping to a hooded balaclava silhouette for an AP cost |
| **D54** | Alpha closes **mechanics**; detail and finish are Beta |
| **D55** | **Reverses D48.** Gameplay figure leads; showcase model deferred, possibly 2D |
| **D56** | The hand's bar is "Diablo" — pose-capable, never anatomically correct |
| **D57** | Geometry is **assembled from CC0 parts**; CC0 is a filter, not a preference |
| **D58** | Two parallel fronts — concept art (PC) and technical (Mac) — with B built so it does not presuppose A |

---

## 2. The finding that made D53 cheap

The Director designed a full costume with a disguise transformation. The
expectation going in was that it would cost new architecture. It cost **one
socket**.

| Costume piece | Where it already lived |
|---|---|
| hood, back → head | **D37**, socket `back_upper`; "hood up / down" already in §4.4's pose set |
| overcoat | **D37** names it too; deforming layer, synced by **D43** |
| blue armband | socket **`arm_L`**, already in the §4.3 table |
| white ⇄ black | **D34** — colour is a free shader uniform. Same geometry |
| hat stowed "in a backpack" | a layer switched off. No stowed geometry to author |
| AP cost to flip | fits the ratified 2-AP economy; canon already prices "improving cover costs 1 AP" |
| **hat, removable** | ⚠️ **nothing.** §4.3 had no head socket — Part 1 modelled the fedora into the body mesh. **Added as `head` (rigid).** |

And the convergence worth recording: **D37 already stated that the hood was
"the first real consumer of §10.1's tier-1 *Civilian clothes — perfect
disguise*, which has existed in the design with nothing reading it"**, justified
with the Director's *"entrar numa festa de gala pela frente, e de repente ir
para outra área da casa."* White coat + fedora is the gala. Black coat + hood is
the other area. The mechanic was designed and mute; this session gave it a face.

**A budget trap avoided by being explicit:** the two disguise states are
**layers, not silhouette classes**. The dressed body is the same black suit in
both. Had they been modelled as two dressed bodies, §8's only multiplicative
term — `archetype × silhouette × pose × yaw` — would have **doubled** for a
change the player reads as one garment turning inside out. Recorded in §4.5.

---

## 3. D48 reversed, and why that is principled rather than churn

D48 landed earlier the same day and promoted Part 8 above Part 2, because *"the
gameplay figure takes its design from it — building Part 2 first would mean
authoring it twice."*

**The dependency was never on the showcase *model*; it was on the *design*
being settled.** D52 and D53 settle it. So the dependency is **discharged by
another route, not skipped**, and the double-authoring risk D48 guarded against
does not come back.

- **Gained:** Part 2 unblocks, and with it firearm aim mode
  (`WEAPON_MASTER_PLAN` §5c / D31–D36) and W-PRECOOK.
- **Left open, deliberately:** D33 splits the two representations as *gameplay
  shows TIER, the big model shows IDENTITY*. A 2D showcase changes what the
  identity half is. Filed as `CHARACTER_MASTER_PLAN` §9 #15. Does not block
  Part 2.

---

## 4. A correction made mid-session, recorded because it had a cost

D35's *"action figure"* was read as **finish** — bonequinho, visible ball
joints — and an argument was built on it: visible joints would delete the hard
part of a procedural hand (the interdigital blend, the thenar mass, the rotated
thumb frame), making the hand "the algorithmic easy case."

The Director declined that reading — *"o modelo não vai ser bonequinho
necessariamente, queremos um pouco mais de detalhes"* — and **the argument was
withdrawn along with it.** D52 records the split and the withdrawal, so the
same shortcut is not taken again from the same row.

The hand ended up out of scope anyway, but on **separate grounds** (D56: rigid
socket, grip-indexed, ≈19 px at ship size). Two different reasons, and only the
second one holds.

---

## 5. The licence research, which is the part with a real trap in it

**Passes the D57 filter** — vetted shortlist now in `CHARACTER_MASTER_PLAN`
§5.1: Quaternius *Modular Character Outfits* (62 parts; the repo already carries
two Quaternius packs with `ATTRIBUTION.txt`), Blender Studio *Human Base Meshes*
(17 meshes, hands/heads/feet separate), Sketchfab *Clothing And Character Kit
1.0* and *Military Character Kit 1.1*.

**Fails, and both were one click from being adopted by mistake:**
- **Meshy's free tier publishes under CC BY 4.0**, not CC0 — commercial use is
  allowed, but a permanent attribution obligation rides along with the shipped
  game. Its paid tier grants a private licence.
- **SMPL-X / MANO** — the standard parametric body and hand models, which
  dominate any search on this topic — are licensed **for non-commercial
  scientific research only**.

**The legal point that inverts the intuition:** CC0 imposes **no obligation to
alter anything**. *"Mudar um pouquinho pra não ficar comum"* is therefore an
**art** requirement bounded by taste, not a licence requirement. D51's risk runs
the other way — non-CC0 material entering unnoticed — and **D57 raises that risk
rather than lowering it**, because "assembled from" means more foreign geometry
survives into the result than D51's "inspired by" assumed. Noted on §9 #14.

**One tool evaluated and declined:** UniRig (Tsinghua/Tripo, SIGGRAPH 2025, open
source) auto-rigs arbitrary meshes — but the gameplay figure uses the verified
20-bone skeleton that already exists, and per D55 the showcase model barely
animates. It solves a problem this project does not have.

---

## 6. Hardware, recorded because it decides where work runs

| | Front A — conceptual | Front B — technical |
|---|---|---|
| Machine | Ryzen 7 5800X3D / **RTX 3060 Ti 8 GB** / 16 GB | Mac mini M1 16 GB, Blender 5.2 LTS |
| Verdict | at the floor, but viable: SDXL fits at fp16/1024², Flux fits quantised (GGUF Q4/Q5), TRELLIS 2 needs low-VRAM mode at 512³ | no CUDA — Hunyuan3D's texturing alone wants ~38 GB and its rasteriser **fails silently** there |

Generative 3D therefore lives on the PC as an experiment, **never as a pipeline
dependency**. A silently-failing rasteriser is exactly the failure mode B6
(loud-fail) exists to forbid.

---

## 7. Files changed

- `PROMPTS/PLANNING/ACTOR_MASTER_PLAN.md` — D52–D58 added to §2.
- `PROMPTS/PLANNING/CHARACTER_MASTER_PLAN.md` — status block re-ordered; `head`
  socket added to §4.3 with the reason; D52/D53 pointers in §3; the
  layers-not-classes note in §4.5; new §5.1 (CC0 shortlist) and §5.2 (the two
  fronts); §7 Parts re-ordered for D55; §9 #6 narrowed, #14 re-weighted, #15
  opened.
- `CLAUDE.md`, `docs/README.md` — decision range D1–D45/D51 → **D1–D58**, and
  the reference-map rows brought in line with D54–D57.

**Gates:** `check_invariants.py` ✓ · `gen_codemap.py --check` ✓ ·
`project_lint.py` **✅ PASSED — no real compile errors**. No selftests run: no
code changed.

---

## 8. Where the next session starts

**Part 2, the three-grip spike** — agreed and not started, because the Director
scoped this session to registration. It needs nothing that does not already
exist in the repo:

- Part 1's 20-bone rig (D48 preserved it; D55 does not disturb it)
- `quaternius_ultimate_guns_pack`, already imported with `ATTRIBUTION.txt`
- `hand_R` / `hand_L` as **rigid** sockets; D40's ≈3 grips, indexed on grip and
  not on pose
- render `CAM_GAME` at 133×196, four yaws

**The question it answers:** does the small figure read as *holding* a shotgun
and a pistol at 19 px of hand? Under D56 that is the whole bar.

**Numbers still unset, both tuning rather than architecture:** the AP price of a
coat flip (§9 #6), and whether the coat's inner lining needs two-sided material
at showcase fidelity (a Beta question under D54).
