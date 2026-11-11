# RESUMO_SESSAO — 2026-08-15 (the turn, the corner, and the first real T-pose)

**Version:** 0.9.101 → **0.9.102 "Alpha Character Brainstorm"**.
No gameplay code was touched all session; the bump marks a design/asset
checkpoint, not a build change.
**Tag:** `verified/v0.9.102` — Director-cleared.
**Commits:** `c0705a1d` → close, all pushed.

---

## The one-line version

Part 0 **closed** and Part 1 **built**: the turn and the corner are both settled
by blind test (D46, D47), the agent has a real T-pose model, the Director
reordered the plan so the professional showcase model comes first (D48), and
Part 8 went from blocked to **ready to start** — its production settled (D49),
its versioning settled (D50), its sourcing settled (D51), and its start scene
built.

---

## 1. The finding that matters most is about METHOD, not about the character

Every sighted comparison this project had run returned **its last / most-frames
option**, and the Director named the pattern rather than accepting the answer:

> *"Em todos os exemplos até agora a última opção sempre foi a melhor."*

**That observation invalidates the instrument; it does not confirm the result.**
Two independent failure modes were uncontrolled and indistinguishable:

1. **Position and label bias.** Panels were always ordered by increasing frame
   count with the count printed on each, so *"the last one"* and *"the most one"*
   were the same panel every single time.
2. **An unbracketed range.** A monotonic preference across everything tested
   means the optimum lies *outside* the set. D45's whole premise is that smooth
   eventually reads sluggish — and no option rendered had ever been deliberately
   too slow.

**The fix, and it is reusable:** labels blinded to A–D, every number stripped
(including the progress bar — side by side, a bar filling at different rates is a
duration readout in disguise), order randomised under a fixed seed **constrained
so the extreme option is not in the position the bias favours**, and the range
extended past the expected breaking point (to 1633 ms for one 90° turn).

**The outcome was diagnostic, which was the point.** The Director picked the
**second** panel, rejected the **last** as too fast and the **most-frames** as
too slow. A single-peaked preference is what a real optimum looks like and what
neither failure mode can produce — so both explanations died and the earlier
sighted answer was confirmed *as a measurement*.

Carried into memory as [[blind-the-comparison-before-trusting-it]], the companion
to [[render-dont-describe]]: rendering the comparison is necessary and not
sufficient.

---

## 2. Six decisions registered — D46 … D51

Full text in `ACTOR_MASTER_PLAN` §2 (now v2.2).

| D | What |
|---|---|
| **D46** | The deliberate turn is **23 in-betweens at 30 Hz — 833 ms** — and it belongs to **target selection**, not to ordinary movement. Closes D45's one pending quantity |
| **D47** | Ordinary movement changes facing by **SNAP at the GU boundary**, no transition frames. Turn-then-move rejected outright (*"A ficou péssima, sem chance"*) |
| **D48** | The **professional showcase model is authored FIRST** and is the design authority for the gameplay figure. Part 8 moves to the front. *Art* derivation, not bake — D16 intact |
| **D49** | That model is made in a **dedicated, collaborative sculpt stage**: import open-source material, sculpt the agent *and the clothing* |
| **D50** | The sculpt **project** is versioned in the repo; its **exports** are not. The official sprite library is committed only once the models are final |
| **D51** | Material is **inspired by** CC0 rather than assembled from it; every source is logged at import time regardless |

**D47 is the row that keeps the art budget finite.** Intermediate yaws are a
*transition* asset. All eight poses need the four cardinal facings; only aim mode
pays for the other 92 — **744 body sets instead of 4608, a 6× saving on the
largest term in the plan.**

**D48 was registered against D16 deliberately, not around it.** D16 rejected
*mechanical* derivation of the gameplay representation from the twin — measured,
at ~500 ms and ~360 MB per pose combo — and made the two "synchronized by
convention." So *"derivar o boneco in game a partir dele"* is registered as **art
derivation, not bake derivation**: the showcase model becomes the visual source
of truth, and the gameplay figure is still separately authored to match it. **If
mechanical derivation was meant, D48 is wrong and D16 must be reopened against
those numbers.** The reading is stated in the row so it can be corrected.

---

## 3. Part 1 — the first real T-pose

`tools/asset_generation/p1_agent_model.py`. 20 bones · 36 rigid parts · 2432
faces · 1.898 m · 1.760 m span. Evidence:
`Screenshots/history/p1_agent_tpose_sheet.png`.

**T-pose is not a style choice.** D32 requires the second archetype to be a mesh
*retarget* onto this skeleton; retargeting needs limbs unambiguously aligned to
axes, and an arms-down rest bakes a shoulder rotation into the bind that every
retarget then has to undo. The sanity check **measures it off the armature and
fails loudly** — a rest pose that is only *almost* a T is worse than an honest
A-pose, because everything downstream will assume it is exact.

**Proportions were left untouched on purpose.** §4.7's scale was *measured*
against those exact numbers by `s2_posture_scale.py` and recorded as SETTLED;
re-proportioning would have silently invalidated a verified result. The art
problem the Director raised was about **form**, and that is where the work went.

**What survives D48:** the skeleton and its exact bone names, the seven sockets,
the verified T rest, and the measured scale. The art is what gets replaced.

---

## 4. Two bugs, both found by measuring rather than by looking

1. **`prism()` inherited an undefined roll.** Cross sections were oriented with
   `axis.to_track_quat("Z", "Y")`, whose rotation *about* the axis is undefined
   for a near-vertical segment. Pure-Z parts landed one way and the slightly
   Y-tilted shirt panel landed another, turning its 85 mm **width** into 85 mm of
   **depth** — a blade sticking out of the chest. **I diagnosed it wrong twice by
   eye** (first as a protruding shirt, then as an arm seen end-on) before
   measuring the bounding boxes, which answered it immediately. Same class as
   D30's copied `PERSPECTIVE_YAW_DEG` that came out 178° wrong.
2. **The first fedora had a 52 cm brim** — a sombrero. Caught only because the
   model was rendered rather than described.

---

## 5. Findings recorded, owned by Part 3

**`agent.gd`'s `STEP_DURATION` is 12.3 m/s.** One GU is 1.60 m
(`VOXELS_PER_UNIT_AXIS` 8 × 0.20 m) and the constant is 0.13 s — faster than the
100 m world record. Not a bug: a *"snappy tactical feel"* tuned for a 44×61 px
vector diamond with no legs to contradict it. It becomes a real problem the
moment a walk cycle is on screen. Same file: `_step_next()` builds a fresh
`EASE_IN_OUT` tween **per tile**, so a five-GU path is five accelerate-decelerate
cycles rather than one walk.

**A defect stated rather than buried:** the corner test's mockup stride was
wrong — `STRIDE_M` is distance per *full cycle*, so it took four footfalls per
1.60 m GU against a real figure's two. The Director caught it by counting, then
ruled the tests sufficient anyway. Footfall count is not what distinguishes the
four mechanisms, so D47's ranking stands.

---

## 6. Tooling added

| Script | What |
|---|---|
| `s2_turn_rate_compare.py` | 60 Hz vs 30 Hz on one asset; the blind `Track` mode every later sheet reuses |
| `s2_turn_bracket_blind.py` | the blind randomised bracket that produced D46 |
| `s2_corner_render.py` / `s2_corner_compare.py` | the four corner mechanisms, plus the step-duration sheet |
| `p1_agent_model.py` | **the T-pose base model and rig** |
| `p1_agent_preview.py` / `p1_agent_sheet.py` | four views, the game camera, and the true 196 px ship size |

**MP4 rather than GIF for every timing sheet, and it is a fidelity decision.** GIF
delays are centiseconds, so 16.67 ms rounds to 20 ms and a "60 Hz" GIF actually
plays at 50 Hz — a 17% error on the exact quantity under judgement. Holding each
source frame an *integer* number of output frames at a fixed 60 fps is exact by
construction.

**Neither the MP4s nor the `.glb`/`.blend` are committed, and both are policy,
not oversight.** `.gitignore:27` bans `*.mp4` repo-wide; `ASSETS/*` keeps heavy
binaries local (the S2 mockup's binaries were never committed either). The
generators are the versioned artifacts and reproduce everything exactly.

---

## 7. State at close

    project_lint.py          ✅ PASSED — 204 files (pre-commit, every commit)
    check_invariants.py      ✅ OK (every commit)
    gen_codemap.py --check   ✅ exit 0

`run_selftests.py` was **not** run and must not be cited: no gameplay code
changed this session. The last real result stands — 35 clean / 0 failed.

---

## 8. D48 confirmed, D49 added — and one word that needs the Director's ruling

**D48's reading was right** (*"Sim, derivar a arte, não o bake"*), with a
refinement: the bake-side artifact is *"outra versão só para bake de assets,
porém sincronizada com o modelo grande, considerando a exibição de tiers"*. That
is exactly **D16's `simplification`**, now gaining a *design parent* it never
had — D16 made the two separately authored and synchronized by convention; D48
adds that the showcase model is the art authority the other is authored to match.
A refinement of D16, not a contradiction.

**D49 closes §9 #11:** the professional model is made in a **dedicated,
collaborative stage** — open-source material imported, then the agent *and the
clothing* sculpted. Part 8 is unblocked.

### ⚠️ The naming collision, flagged rather than absorbed

The Director's phrasing calls the bake-side version *"o twin digital"*. **D16
assigns `digital twin` to the SHOWCASE model** and calls the gameplay-side
artifact the `simplification`. The two usages are exact opposites and cannot both
stand. The register keeps **D16's** assignment — `twin` = the big showcase model,
`simplification` = the bake-only gameplay version — because D16 is ratified and
cited across several documents, and a silent re-labelling is precisely how two
documents drift. **If the opposite mapping is preferred, it is a rename across
D1–D49 and must be done deliberately.**

## 9. What Part 8 now has, and what it cost to establish

**The start scene is built** — `p8_sculpt_start_scene.py` →
`agent_sculpt_start.blend`. `RIG` (the verified 20-bone T-pose + seven sockets,
*generated* by `p1_agent_model.py` rather than copied), `BLOCKING` (Part 1's body,
`hide_select`), `SCALE` (a 0.20 m voxel ruler to 3.20 m, the SLICE and ROOM lines,
the 1.60 m GU footprint, the posture marks), `CAMERAS` (the bake convention plus
three orthos), and a **133×196 render preset so F12 is a one-key check at true
in-game size.** Two placement bugs were found by rendering the scene rather than
trusting it: the ruler sat inside the 1.76 m T-pose arm span, and the labels
faced away from `CAM_FRONT` so they rendered mirrored *and* read right-to-left.

**The procedural ceiling was measured, not assumed** (`p1_procedural_sculpt_spike.py`,
answering *"a gente não consegue esculpir proceduralmente?"*). Lofted control
cages with per-section superellipse profiles, run through a subdivision surface,
genuinely improve the form. **The finding is the failure in the middle of it:**
uniform subdivision *destroyed the suit* — the jacket hem rounded into a bulb and
the shoe's sole dissolved, because a garment edge is a **cut**. The fix was mixed
construction, and **a script can execute that decision but cannot make it.** The
plateau is therefore not surface quality: neither version has a face, fingers or
fabric behaviour, and no amount of subdivision produces them.

**Two costs recorded rather than discovered later.** `.git` is already **915 MB**
and `git-lfs` is not installed, so D50's versioned `.blend` — an opaque binary
stored in full per revision — needs the discipline of **committing at milestones,
not at every save**; history cannot be pruned afterwards without rewriting
published commits. And D51's provenance log guards against *non*-CC0 material
entering unnoticed, which is unrecoverable once geometry has been reshaped and
merged.

## 10. Next session

1. **Part 8 — the professional showcase model**, the dedicated joint sculpt stage
   (D49). **Nothing blocks it.** Open `agent_sculpt_start.blend`; the first
   action should be **Save As** into
   `ASSETS/ISOMETRIC/source_assets/sculpt/agent_showcase.blend`, so the sculpted
   file is born in the versioned location instead of overwriting the generated
   scene.
2. **Part 2** follows, and still unblocks firearm aim mode and W-PRECOOK.
3. **Open and not urgent:** the cape's own animation cost (D43), the free
   fallback for a purchasable state indicator (D36 / §9 #4), how many silhouette
   classes (§9 #2), on-device RAM headroom, and §9 #12's step duration.
