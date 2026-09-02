# GLASS MASTER PLAN — the physics of glass

**Status:** 🟠 v1.16 — **G-VARIANT V-A BUILT (2026-09-01): the glass FAMILY
SEAM.** `GlassMaterials.is_glass()` replaces 25 bare `== "glass"` comparisons
across rendering, geometry, occlusion, the guard phase, the shot path and the
cook — G-D16 makes glass a family, and against a literal comparison every new
member would be a silently OPAQUE wall that renders, occludes and stops rounds
with no error anywhere. Pinned by new invariant **L2 `glass-is-a-family`**, which
reads the roster out of the seam module rather than duplicating it.

⛔ **AND V-A's verification found Stage B INERT ON THE REAL MAP (§5.1).** A won
sniper roll on the GLASS map's big pane floods **zero** voxels: the shot's own
local hole surrounds the origin, and the BFS can only step onto surviving glass,
so `radius=23` over `lattice=1143` dies at step one. Pre-existing — the
before/after runs on the same binary are identical. **The fix is one branch and
V-C is blocked on it.**

Earlier, v1.15 — **G-ART's ORDER AND GATE ARE DONE (2026-09-01, §8):**
[`ART_ORDER_GLASS.md`](../ART_ORDER_GLASS.md) asks for five files — two 1024×512
grayscale fracture sheets (tight/wide, G-D14/G-D21) and three 256×256 shard
decals — and `check_decal.py` enforces both classes, earned before the art (the
M2a precedent) and proven red on seven failure modes with all 54 shipped decals
unchanged. Every remaining glass task is now blocked on the DELIVERY alone.

Earlier, v1.14 — **G3 IS COMPLETE. All four stages built:** A
(`GlassShatter` curve), B (shot path — region flood, remnants), C (the
grenade/cook path), and **D (2026-09-01 — the movement/vision edge-set split, and
a broken pane opening the passage via `PassageQuery`).** Also built this day:
**G-D13b** (a remnant is ANCHORED or it is not one — a free-standing pane goes to
nothing), **G-D16a** (`GlassFall` — where a shard lands: base piles, counters,
sills and skylights from one rule), **G-D17** (a round loses power through every
glass layer it crosses), and **G-D23**'s pane-size ceiling enforced in
`GlassPaneGrouper`. G1 geometry, G2, G7, G-MAP, G-D9, G-D18, G-D18b BUILT.

**What is left, and what each is blocked on:**
| | blocked on |
|---|---|
| G-D8's last third — the light bump and +1 detection when a passage opens | needs the opening as an EVENT; Stage D landed a per-turn recomputed SET, which has no memory of the moment it changed |
| G-D19 / G-D21 / G-D23's clamp / G-D24 — the crack itself | **the two fracture sheets** (ordered 2026-09-01, §8). `glass.crack_factor` is still 0.0 and moves WITH the art, never before it: `voxel_decal_selftest` [12] requires data, wiring and art together |
| G-D16b — shards on screen | **the three `decal_shard_glass_*` files** (ordered 2026-09-01, §8) |
| G-D16c / G-D16d — skylights and sub-GU slab regions | CEILING glass still renders opaque (`voxel_renderer.gd:3676`); no horizontal `pane_id` |
| A solid glass CUBE shattering | `PANE_BLOCK_*` has no run axis for `plan_pane_shatter`'s lattice, and `_note_glass_crossing()` dedupes by `pane_id` so entering and leaving a block counts as one layer |

G1
appearance signed off; G1 geometry awaits a Director tuning verdict on the sliver
size/dim. **G-D9 (multi-material slices) BUILT 2026-08-31** — `panels.bands` →
`Slice.material_bands` + `material_at()`, the per-band bake page, a lookup
material override; the GLASS map's WINDOWS.png wall renders a brick sill + head
over a glass middle (`glass_bands_wall_{before,after}_2026-08-31.png`, same-boot).
**G-D18 (2026-08-31):** glass no longer participates in occlusion — a see-through
pane hides nothing and its wireframe drew over a still-solid pane
(`glass_occlusion_{before,after}_2026-08-31.png`). **G-D18b (2026-08-31):** the
agent renders BEHIND a pane he stands behind, faintly tinted, like a guard
already did (`glass_agent_behind_pane_2026-08-31.png`). ⚠️ **OPEN — the Director
flagged 2026-08-31 that intact glass blocks no movement** (agent and guards walk
through it); the fix folds into G3 (see G-D8). **The break design GREW on 2026-08-31** — per-projectile shatter roll
(G-D11), partial breaks on big panes (G-D12), a mandatory remnant floor (G-D13),
per-weapon hole size (G-D14), armored/purple glass with a primed state (G-D15),
terminal-colour glass classes (G-D16 — INDESTRUCTIBLE *stops the round*), a
black-plastic screen backing (G-D17). **G3 is PAUSED for this doc's sign-off**
before any code — the Director gave it at the end of the 2026-08-31 session.
Next: **G3**. G-ART, G5, G4, G6, G-D4, G-VARIANT, `plastic` unbuilt. *(G3 and
G-ART have since landed — see the status block at the top of this file.)*

**G1 GEOMETRY as reworked** (Director's two diagrams, 2026-08-31): the pane
thickness is a per-voxel **exposed-face cull**, not per-position atoms. A glass
voxel paints its MAIN face always; its TOP face only when nothing is above it
(the top row); its SIDE face only on the frontmost column (camera-nearest end,
always pos 7 — both screen axes carry a +south component). Top and side render
DIM and *that* is the thickness read. This kills the "serrilhado" — with
transparency every hidden face that gets drawn ghosts through. Generalises by
exposure to L-walls and glass cubes. 16 atoms (`_glass_atom_source[face][mask]`,
4 faces × 4 masks); `_build_glass_pane_atom(face, want_top, want_side)`;
`_glass_face_mask()` picks the mask. Tuning knobs: `GLASS_FACE_SLIVER_FRAC`
(0.55, the pane's half thickness), `GLASS_DIM_TOP` (0.60), `GLASS_DIM_SIDE`
(0.78), `INFILTRAITOR_GLASS_ATOM_NUDGE`. NW/NE slivers extrude toward the camera
(back walls) — untested; PLAYGROUND's panels are SW/SE.

**G1 FLOAT FIX** (`4d5da813`, Director 2026-08-31: *"o bloco todo de vidro está
deslocado pra cima ... flutuando na base"*): the pane atom's `texture_origin`
carried a leftover `+(0,20)` from the pre-rework `+shift` bookkeeping, lifting
every pane a level off the ground. `face_q` is now byte-for-byte the material
atom's own side face (`voxel_concrete.png` alpha rows 8..36), so the nudge
default is `Vector2i.ZERO` — glass renders exactly where an opaque wall does, and
matches the occlusion wireframe.

**G1 as built** (commits `41eee478`→`c9c4169c`): glass vertical faces leave the
opaque `_layers` for one glass `TileMapLayer` per level, composited through a
**`BackBufferCopy` rasterising container** (`glass_pane.gdshader` reads the
snapshot and applies the tint once — no double-tint; the Director's *"container
rasterizado"*). Per-face **parallelogram** atoms (the face-lattice fundamental
domain) for the interior; **perimeter** atoms add a DIM top cap + thickness strip
(1-voxel thickness). Frost sampled by world position. Calibration = "painel 005"
(sheen, `mul 0.60 / add 0.20`, blue tint `[0.47, 0.63, 0.90]`). Roofs / glazed
floor zones stay opaque (kept the roof-coverage geometry intact). Intact glass
still blocks light (`build_occupancy()` re-adds the cells).
`glass_transparency_selftest` (12 checks). Tooling:
`INFILTRAITOR_CAPTURE_ACTION=glass_calibration` + `glass_calibration.py`,
`INFILTRAITOR_GLASS_DIAG=1`, `INFILTRAITOR_GLASS_ATOM_NUDGE`.

⚠️ **GEOMETRY** — the pane half is reworked to the face-culling rule (2026-08-31,
above); a Director tuning verdict on the sliver size / dim is open. The glass
BLOCK half is untouched: roof-slab seam, opaque junction corner columns, z-index
vs walls in front. **The pane is the priority — full glass blocks are rare.**

Earlier: 🟡 v1.1 — DESIGN RATIFIED 2026-08-30, UNBUILT
**v1.1, same day:** G-D9 added and **§9 rewritten — it reverses its own first
recommendation** after the count it rested on was actually taken (16 call sites,
9 of which already hold the voxel; the bake seam already takes a level). The
reversal is kept visible rather than edited away.
**Owns:** `MATERIALS_MASTER_PLAN` M4a + M4b, which this document supersedes in
detail. That plan keeps the milestone row; this one keeps the design.
**Opened:** 2026-08-30, immediately after `DETONATION_PRESENTATION_MASTER_PLAN`
closed. Glass is the Director's one named explosion follow-up.

> Director, 2026-08-30: *"Ele tem que ter uma transparência em relação ao que tem
> atrás, que é independente da oclusão, mas uma característica própria. […]
> precisamos ainda pensar em como fazer o vidro rachar, se estiver perto de uma
> explosão, mas não dentro da área de dano. Quebrar efetivamente quando estiver,
> estilhaçando mais ou menos, e deixando mais ou menos sobras na borda da janela,
> da porta, etc. […] Pistola, normalmente o tiro fura o vidro, e cria aquele
> padrão de ondas rachadas ao redor. Fuzil normalmente faz um buraco grande ou
> quebra totalmente a vidraça também."*

---

## 0. Scope — and what this plan deliberately does NOT do

> Director, 2026-08-30: *"Não precisa fazer a janela ainda, vamos só trabalhar na
> física do vidro por enquanto e depois construímos as aplicações com ele no
> cenário."*

**IN:** transparency, pane identity, the non-local break, remnants on the frame,
cracking, floor shards, the per-weapon patterns, projectile pass-through, and the
art order that all of it needs.

**OUT, by explicit ruling, and each one recorded rather than forgotten:**

| Deferred | To | Why it is not here |
|---|---|---|
| **A real window** (brick cap · glass · brick cap over 3 stacked storeys) | the scenario applications | ✅ Its enabling capability — **multi-material slices, G-D9** — is BUILT (2026-08-31); the `panels.bands` authoring (§9.6) spells it and the GLASS map's WINDOWS.png wall renders it. What stays deferred is the full *reveal* geometry (the empty opposite face, the agent crossing it) |
| **Shard noise** | the sound milestone | *"Ainda não implementamos o som, ele vai ser uma parte crucial do jogo, inclusive com interface visual no cenário."* The shard STATE is built here; its gameplay consumer is not |
| **The agent walking through a broken pane** | the movement milestone | *"Com a janela de verdade vamos poder criar a passagem, e fazer o agente atravessar, na milestone de movimentação"* |
| **The see-through vision roll** (G-D7) | the scenario applications | It needs two rooms and a window between them to mean anything. Designed here, built there |

**The test bed is what already exists:** PLAYGROUND's two glass panels at
`(25,8) SE` and `(29,8) SW`, 2 storeys each, plus the glass block at gu x=38.
The Director's note on blocks stands: *"paredes de escritório envidraçadas, ou
mesmo divisórias, mas blocos acho que não. De qualquer forma é desejável que a
física permita a existência deles."* — blocks stay physically supported, they are
just not the target case.

---

## 1. Decision register

| # | Decision | Status |
|---|---|---|
| **G-D1** | **Transparency is a BLEND, never alpha.** *"queremos ver a textura dele por cima do fundo, mas com transparência, tentando não usar opacidade pura, pra não ficar lavado."* Glass modulates what is behind it; it is not a translucent layer over it. Independent of occlusion — a pane is see-through even when nothing is being occluded | ✅ Ratified 2026-08-30 |
| **G-D2** | **A pane is one continuous surface; a block is one block.** *"O vidro é uma coisa só, desde que seja a mesma superfície contínua. Um bloco é um bloco."* | ✅ Ratified 2026-08-30 |
| **G-D3** | **Glass CRACKS — ⚠️ this amends D22.** D22 ruled glass DESTROYED-only (*"não vai ter dented; é buraco feito, ou não feito"*), with `dent_factor` and `crack_factor` pinned to 0.0 so the rule read as intent. The Director now wants glass to crack near a blast it survives, and to craze around a bullet hole. **The amendment is narrow: CRACKED returns, DENTED stays impossible** — glass does not deform, it fractures. See §6.1 for the two accidents this converts into intent | ✅ Ratified 2026-08-30, amends D22 |
| **G-D4** | **Neighbours of a shot on glass may be CRACKED — ⚠️ this amends D30.1.** D30.1 says *"vizinhos destruídos mas sem marca própria"*, to prevent a spray of separate round holes. A crack web is the opposite of a spray: it is ONE fracture that spans cells. The exception is glass-only and is justified by that distinction, not by convenience | ✅ Ratified 2026-08-30, amends D30.1 for glass only |
| **G-D5** | **A projectile passes through glass and strikes what is behind it.** *"Sim, atravessa e bate no fundo."* ⚠️ Amends the reading of D28 (*a fully-penetrated path leaves no mark anywhere*): here the glass keeps its hole AND the round continues | ✅ Ratified 2026-08-30 |
| **G-D6** | **Shards are game state, not decoration.** *"Cacos fazem barulho sim, é estado de jogo, e enriquece o gameplay."* They persist, they are saved, and the sound milestone will read them | ✅ Ratified 2026-08-30 |
| **G-D7** | **Seeing through glass is a ROLL, driven by proximity, pane count and a light differential.** *"o guarda tem uma chance de enxergar através do vidro intacto, caso tanto o guarda quanto o agente estejam próximos do vidro. Mas se forem duas vidraças no caminho a chance cai bastante. […] a sala iluminada é fácil de ver de fora, quando está escuro. Ao passo que quando está claro lá fora é ao contrário: fica bem mais difícil de ver dentro, e vice-versa."* | ✅ Design ratified 2026-08-30 · **build deferred to the applications** |
| **G-D8** | **A broken pane opens a passage, barely moves the light, and raises detection one step.** *"Com certeza, mas não influencia tanto na luz, apenas aumenta um pouco de intensidade e sobe um grau de detecção no mecanismo stealth."* ⚠️ **2026-08-31 — the Director flagged that an INTACT glass pane blocks nothing today** (*"o agente consegue atravessar o vidro, precisamos implementar a questão da abertura de passagem"*). Half-thickness panels never enter `blocked_edges` (§2), so the agent AND the guards walk straight through intact glass. The fix is coupled to G3 and needs the **movement/vision blocked-edge split** G-D7 anticipates (`blocked_edges` feeds both today, and glass must block the body but not necessarily the eye) — **fold it into G3** rather than a standalone patch, so "blocks when intact" and "opens when broken" (PassageQuery → the movement edge set, per-turn recompute) land together. **Director's call 2026-08-31: "juntar tudo no G3."** | ✅ Ratified 2026-08-30 · build folds into G3 (Director 2026-08-31) |
| **G-D9** | **A slice can carry MORE THAN ONE MATERIAL, as a sparse per-level band map — and the Director's diagram wins over §9's first recommendation.** *(2026-08-30, from the Director's half-thickness window diagram.)* The window is **three game storeys stacked inside one code `Slice`**: brick cap · glass · glass · glass · brick cap. ⚠️ **This REVERSES the recommendation this plan shipped with**, on a measurement that contradicted it — see §9 | ✅ Ratified 2026-08-30 |
| **G-D10** | **Mullions are free or they do not exist — a continuous pane is fine.** *(Director, 2026-08-30, closing §9.1's open observation.)* If the muntin grid falls out of the geometry — horizontals at storey boundaries, verticals at GU boundaries — take it. If the glass reads as one continuous surface instead, that is equally correct. **Neither outcome is a defect, and G-ART owes NO fifth decal family.** The one thing ruled out is authoring muntins as art | ✅ Ratified 2026-08-30 |
| **G-D11** | **The whole-pane shatter is a PER-PROJECTILE ROLL scaled by power — ⚠️ this replaces §5.1's single `pane_shatter_punch` threshold.** *"Cada pellet ou projetil vai ter sua própria chance de quebrar ou não a janela toda, ou pelo menos uma área maior do que a zona do tiro, de acordo com a potência."* Every pellet/round that hits a pane rolls its OWN chance (B4 FNV-1a on `(salt, projectile index)`) to take the pane — or a region larger than its own hole. The chance rises with the round's glass punch. A shotgun's 24 pellets each roll and the pane's odds compound with the count — and **it is legitimately possible that none shatter it** | ✅ Ratified 2026-08-31, replaces §5.1 |
| **G-D12** | **A BIG pane breaks PARTIALLY; a SMALL pane is binary.** *"Uma vidraça grande permite que uma parte quebre totalmente, e outra continue resistindo. Em vidros menores é mais binário, quebrou tudo ou não."* A shatter roll takes a REGION — a flood from the hit, radius scaled by the round's power. On a large pane the rest keeps standing (same `pane_id`, still shatterable later); on a small pane the region covers the whole thing | ✅ Ratified 2026-08-31 |
| **G-D13** | **Remnants on the frame.** *"nunca queremos que todos os voxels quebrem, sempre deixamos umas sobrinhas nas molduras."* §5.2's luck-driven survivors are a rule of G3 itself, not an optional G4 flourish | ✅ Ratified 2026-08-31 · ⚠️ **its unconditional half superseded by G-D13b** |
| **G-D13b** | **A remnant is ANCHORED or it is not a remnant.** *"como essa vidraça não tem nada em volta, todos os cacos precisam cair. Então na verdade a regra é: alguns cacos devem sempre ficar sobrando, QUANDO estiverem conectados com qualquer outro material (half slices inclusive)."* A flooded glass voxel survives only if an ORTHOGONAL lattice neighbour holds non-glass material — the pane's own G-D9 bands, or a wall (half-thickness included) on the same edge line. Glass never anchors glass. G-D13's floor of `MIN_COUNT` survivors still holds, but only AMONG THE ANCHORED; a free-standing pane has none and goes completely. ⚠️ The floor the pane stands on is NOT an anchor (it is not in the pane's plane) — stated as an assumption, since counting it would keep a row of shards along the bottom of exactly the pane this rule exists to empty | ✅ Ratified 2026-09-01 |
| **G-D14** | **Hole size is per-weapon.** *"pistola ou shotgun fazerem um furo de um voxel, com a arte das ondas rachadas em volta, ao passo que armas mais potentes como o fuzil destroem de 2 a 4 voxels, e criam uma arte com ondas maior, e mais espaçada."* Non-shattering hit: pistol / shotgun pellet = 1 voxel + a tight `crack_web`; rifle-class = 2–4 voxels (scaled by power) + a larger, more spaced `crack_web`. Driven by the existing `WeaponDef.blowout` field | ✅ Ratified 2026-08-31 |
| **G-D17** | **A ROUND LOSES POWER THROUGH EVERY GLASS LAYER IT CROSSES.** *"Precisamos implementar quebra em dois vidros seguidos, ou formalizar que vidros só podem ter meia espessura. Seria mais interessante pra engine a primeira opção, porque isso implica nos cubos sólidos de vidro. Adicionamos um modificador de destruição, de forma que cada camada de vidro a mais diminui a potência do projétil."* A LAYER is one thickness of glass the round passes through — the next pane along the ray, or the far face of a solid cube. Depth 0 is unattenuated, so §5.1's ratified arsenal table is untouched by construction. GEOMETRIC (`punch · FALLOFF^depth`), never subtractive: it cannot go negative, and a thick stack stops a round by ARITHMETIC instead of by a special case naming a limit. Applied to the WHOLE projectile — the hole it makes, the pane roll, and the mark on the wall it finally reaches | ✅ Ratified + BUILT 2026-09-01 |
| **G-D19** | **A CRACKED GLASS VOXEL IS HALF SEE-THROUGH — AND THAT IS NOT AN ALPHA.** *"Com a rachadura nos voxels eles naturalmente vão perder a visibilidade total. Vamos diminuir pra 50% naquele voxel de vidro que tiver algum decal. Mas o decal em si já vai ter a própria opacidade na hora do bake, então precisamos fazer essa sobreposição dos elementos de maneira consciente."* The two quantities are DIFFERENT CHANNELS and must never be multiplied into one: the atom's **alpha is COVERAGE** (is there glass here — the silhouette B3 clamps a decal to), while see-through-ness is how much of `behind` survives the modulate in `glass_apply()`. Fold the 50% into the decal's alpha and it lands in `cover`: the voxel gets HALF A SILHOUETTE and partly vanishes instead of frosting over. So the decal composites into the atom exactly as it does today (alpha = coverage, B3 unchanged), and the 50% rides a SEPARATE per-voxel damage term the shader applies to the background contribution — `lit = mix(lit, frosted_body, damage)` | 🟡 Proposed 2026-09-01 |
| **G-D20** | ⛔ **SUPERSEDED SAME DAY BY G-D21** — the mosaic's job (event-anchored, not structure-anchored) is right, but assembling it from edge-matched tiles is doing by hand what `_compute_facade_key()`'s offset already does. Kept for the argument, which G-D21 inherits: **PANE FRACTURE IS EVENT-ANCHORED, NOT STRUCTURE-ANCHORED.** *"Uma outra possibilidade seria fazer mosaicos procedurais usando partes de rachaduras similares que se conectam. Isso facilita porque o furo tem que ser posicionado sobre o voxel que o tiro acertou, e não aonde a textura baked fica."* The Director's argument is decisive and it kills the earlier proposal: a facade sheet is **structure-anchored** (`texture_anchor` = the component's NW corner, deliberately static so the pattern does not swim), while a fracture is **event-anchored** — its centre is wherever the round landed, different every shot. A baked sheet would put the radial centre at a fixed spot on the pane no matter where you hit it. A tile set whose edges connect, assembled outward from the impact voxel, is event-anchored by construction, stays inside the existing per-voxel decal path (no new bake axis, no new anchor unit), and is still gated by `check_decal.py` | ✅ Ratified 2026-09-01 |
| **G-D22** | *(id deliberately skipped — "G-D22" sitting next to the older **D22** decision that G-D3 amends is a collision waiting to be misread. Same reasoning DIRECTION_GLOSSARY §10 applies to names.)* | — |
| **G-D21** | **THE CRACK IS A FACADE SHEET RE-ANCHORED ONTO THE IMPACT — supersedes G-D20's tile mosaic.** *"essa ideia de fazer a grade e montar o mosaico, me parece que é essencialmente o que o baking system já faz […] gerar uma facade bem maior que as convencionais, com o furo baked no centro. E na hora que o tiro acerta a janela, ela tem margem pra 'sangrar' e ser reposicionada dentro da janela, cobrindo o voxel que foi acertado."* Correct, and it reduces to a SUBTRACTION: `_compute_facade_key()` already keys a voxel by `(column_in_run, level)` relative to the run's own origin, so "reposition the sheet" is offsetting those two numbers by (impact − sheet centre). No new mechanism, no new anchor unit, and — unlike a per-event mosaic — **the atoms are all composed once at load**, because the crack ART is fixed and only the OFFSET moves. A shot changes which atom each voxel picks; it mints nothing | ✅ Ratified 2026-09-01 |
| **G-D23** | **NO MIRROR FOR THE CRACK FAMILY, AND A PANE HAS A MAXIMUM SIZE.** *"Vamos com a 3, tira o espelho dessa família. E aí convencionamos que toda vidraça vai ter um tamanho máximo. Que é o padrão real mesmo, nenhuma janela é infinita. Precisando, usa-se um frame divisório e começa outra vidraça."* The crack sheet clamps at its edge instead of mirroring, so beyond it there is simply NO crack — the physically right answer, and the one that cannot invent a second false fracture. The maximum pane is then DERIVED from the sheet rather than invented: **64 × 32 voxels = 8 GU × 4 storeys**, which makes *"a centred hit can crack the whole pane"* a guarantee. maps/GLASS.map.json's big pane (6 GU × 3 storeys) already fits. Anything larger is authored as two panes with a divider — a **NON-GLASS panel at the middle GU, or a gap**. ⚠️ A G-D9 `bands` entry does NOT split a pane (measured — see below); a banded window is still base-glass and the union-find joins it to its neighbours anyway | ✅ Ratified 2026-09-01 |
| **G-D24** | **WHERE TWO FRACTURES CROSS, THE GLASS FALLS OUT.** *"Realisticamente falando, um segundo tiro iria quebrar regiões com cruzamentos de rachaduras, então destruir os voxels que se encontram também é uma opção."* A voxel already carrying a crack, reached by a SECOND fracture, becomes DESTROYED. This replaces the "nearest impact wins" tiebreak proposed a turn earlier and is better on every axis: physically right (crossed cracks drop the piece), free (DESTROYED is what the engine does natively — no per-voxel crack-source int, no compositing of two sheets ever), and it gives a second shot a real mechanical identity instead of a cosmetic one — the first shot crazes, the second opens a hole along the intersection. The freed voxels then fall and pile through G-D16a like any other break | ✅ Ratified 2026-09-01 |
| **G-D15** | **ARMORED GLASS (`glass_armored`, purple) — resists common shots; when breached, usually shatters entirely at once, leaving many individual shards.** ⚠️ **Special rifle case:** a rifle round may pierce a SINGLE voxel without shattering (treated as a weak hit) — this PRIMES the pane, and the next shot of ANY type auto-shatters the whole thing. `pane_primed` is a per-pane flag, checkpoint-scoped | ✅ Ratified 2026-08-31 · build after this doc is signed off |
| **G-D16** | **Glass is a family of tinted behaviour classes, not new geometry.** All variants share G1's rendering and differ only in a tint (`base_color`) and a `glass_class`: `glass` (blue, BREAKABLE) · `glass_armored` (purple, ARMORED, G-D15) · `glass_screen_{green,red,amber}` (dark terminal tone) which is **INDESTRUCTIBLE** (control interfaces — takes a crack decal, never breaks, and STOPS the round: *"trinca mas o tiro para"*) or **BREAKABLE** (TVs, circuits, news panels) per placement | ✅ Ratified 2026-08-31 |
| **G-D17** | **A screen is a glass voxel over a BLACK PLASTIC voxel.** *"O voxel de vidro fica na frente de voxels pretos de PLÁSTICO (a implementar — fura [não atravessa] ou derrete), de forma que nesses voxels pretos vamos pintar as imagens e textos posteriormente, e o vidro vai criar o efeito de brilho por cima."* New material **`plastic`** (black): a round DRILLS it (a hole, but the round does NOT pass through — unlike glass) or fire MELTS it. Images/text painted onto the plastic later; the glass in front adds the G1 sheen. Belongs in `MATERIALS_MASTER_PLAN` | ✅ Ratified 2026-08-31 · `plastic` + the paint layer are deferred |
| **G-D18** | **Glass does not occlude.** *(Director, 2026-08-31, on the G-D9 capture: "tem algum problema com a oclusão. Podemos considerar não fazer em materiais de vidro.")* A glass pane is see-through by construction (G-D1) — the agent behind it is already visible, so ghosting it reveals nothing, and because glass renders on its own `_glass_layers` (which `apply_occlusion()` never erases) the wireframe drew its lines and ghost-band fill over a still-solid pane. `OcclusionSet` now filters out any slice whose BASE material is glass (policy O7, `_group_slices_by_edge`): no trigger, no ring stop, no wireframe. A mostly-opaque wall with a small glass viewport (base ≠ glass) still occludes. Guard-through-glass vision is G-D7, a separate roll | ✅ **BUILT 2026-08-31** |
| **G-D18b** | **The agent renders BEHIND a glass pane he stands behind.** *(Director, 2026-08-31: "no caso do vidro ser transparente, acho que podemos deixar o agente ser renderizado atrás e ficar parcialmente coberto pelo vidro.")* OCC-03 bumps the agent one z above the tallest OPAQUE layer so a wall never hides him. Glass hides nothing, so the whole glass composite (backbuffer + every pane layer) is now lifted one z above the agent (`VoxelRenderer.set_glass_over_z(agent.z_index + 1)`, called from room.gd) — a pane the agent stands behind tints him, exactly as it already did for a guard (`enemies_root.z_index = 10`, never bumped). An agent standing IN FRONT of a pane is unaffected: the isometric projection draws his sprite below the pane's screen footprint, so they do not overlap | ✅ **BUILT 2026-08-31** |

---

## 2. The seams that already exist — verified 2026-08-30, not remembered

Every row was read out of the file named. This section exists because three of
them changed the size of this plan.

| Seam | Where | What it means here |
|---|---|---|
| **A slice knows its edge and holds its voxels** | [`slice.gd:6-14`](../../godot/scripts/geometry/slice.gd) — `id`, `edge_id`, `material`, `voxels: Array[Voxel]` (64 per storey) | The pane grouping the old plan called *"a design question with a cost difference"* is a field that already exists. `voxel.container_id()` → `Slice` → `edge_id` → every voxel of that surface |
| **A panel is a half-thickness single face** | [`map_sections_v1.gd:162`](../../godot/scripts/world/maps/persistence/map_sections_v1.gd), [`edge_extractor.gd:203`](../../godot/scripts/geometry/edge_extractor.gd) | The pane, as an authored object. Two exist in PLAYGROUND |
| **A block dissolves into exposed faces** | `edge_extractor.gd` second pass — `solidblock_occupancy` keyed `"x,y,storey"`, buried faces culled | ⚠️ No block id survives extraction. G-D2's *"um bloco é um bloco"* has to be derived where the occupancy map is still alive (§4.2) |
| **`PassageQuery` is complete and unread** | [`passage_query.gd:186`](../../godot/scripts/geometry/passage_query.gd); the only two call sites are a `print` and a `print_debug` in `room.gd` | It already handles half-thickness explicitly (*"a fabric panel or a glass window will have ONE [face]"*). Destruction has never opened a passage for ANY material |
| **Vision reuses the movement edge set** | [`guard_enemy.gd:689`](../../godot/scripts/agents/guard_enemy.gd) `can_see_cell()` takes `blocked_edges` | Glass blocks sight today exactly like concrete. G-D7 is the ruling that splits "blocks the body" from "blocks the eye" |
| **A blocked edge has no material** | [`map_geometry.gd:151`](../../godot/scripts/world/maps/map_geometry.gd) — `{"from": Vector2i, "to": Vector2i}` | The gameplay grid and the `Edge`/`Slice` geometry are two disconnected representations. G-D7 and G-D8 are what force a bridge |
| **Nothing in the game makes noise** | `NoiseSystem` is complete and instantiated ([`room.gd:1401`](../../godot/scripts/world/room.gd)); `emit()` has **zero call sites** | G-D6's shards will be the first real noise source — in the sound milestone |
| **Noise→detection is gated backwards** | [`turn_controller.gd:200`](../../godot/scripts/world/controllers/turn_controller.gd) — `if noise_intensity > 0.0 and result.visible` | Noise only raises detection when the guard ALREADY sees the agent. Recorded here because the sound milestone must fix it or shards are inert by construction |
| **Tactical visibility is already per-cell** | [`exposure_system.gd`](../../godot/scripts/systems/lighting/exposure_system.gd) — visibility class 0–4 with detection multipliers | G-D7's light differential reads this, NOT the render brightness. `LIGHT_MASTER_PLAN`'s standing distinction survives |
| **The projectile stops at a blocked edge** | `select_line_impact()` / `select_cone_pellet_impacts()` take `_blocked_edges_dict()` | G-D5 is one rule in the pellet flood, not a new system |
| **Glass reaches the cascade ceiling** | `shot_punch_table.gd` — glass `RESISTANCE` 0.40, worst case punch 8.82 | Already measured and documented; the selftest exclusion was retired with a number, not a guess |

**Evidence for the opacity claim:** `Screenshots/history/mat_block_02_lit_five_materials.png`
— the glass block reads as a solid painted pale blue-green, fully opaque.

---

## 3. G1 — Transparency

### 3.1 Why the bake cannot answer it

Every voxel reaches the tilemap through `set_cell()` (architecture Rule 8) and
the material's colour arrives by MULTIPLY at bake time. The background is not
known at bake time, so "see through it" is unreachable there. And straight alpha
is the *"opacidade pura"* the Director rejects: it averages the texture toward
whatever is behind and washes it out.

### 3.2 The shape

Glass cells move to their **own `TileMapLayer` on the same level**, drawn
immediately after that level's opaque layer, with its own
`CanvasItemMaterial.blend_mode`. **Rule 8 is intact** — the voxels still arrive
via `set_cell()`; only the layer's compositing changes.

**Two sublayers, because one blend cannot be glass:**

- **MUL** — the tint. Darkens and colours what is behind while *preserving* the
  facade's grayscale pattern instead of averaging it away. This is the half that
  answers *"ver a textura dele por cima do fundo"*.
- **ADD** — the highlights. The bright streaks and reflections. This is the half
  that makes it read as glass rather than as tinted air.

Draw order works with the isometric painter's algorithm for free: the glass
sublayers sit between their own level's opaque layer and the next level up, so
glass composites over everything already drawn beneath it and everything drawn
later (higher levels, the agent) draws over the glass. Correct in both directions.

Layers are created **lazily, only for levels that actually contain glass**. The
TileSet rebuild is charged once per frame that mints, so this adds a one-time
layer, not a per-frame cost.

### 3.3 ⚠️ The risk, stated before it is discovered

`voxel_face_shading.gdshader` differentiates the three faces by **multiplying**.
On an ADD layer, multiplication means something else. The glass sublayers need
their own shader variant, or the face differentiation behaves differently there.
Not blocking, not free.

---

## 4. G2 — Pane identity

A `pane_id` is stamped on every glass slice at extraction time. One concept, two
producers, one consumer (the cascade).

### 4.1 Panels — contiguous coplanar surfaces

Adjacent glass panels sharing a plane are one pane. A union-find over the
extracted glass edges, run **once at map load**, never per shot.

### 4.2 Blocks — the connected component of the occupancy map

⚠️ The block's identity is destroyed by extraction: the second pass emits exposed
faces from `solidblock_occupancy` and no block id survives. So G-D2's *"um bloco
é um bloco"* must be derived **inside the extractor**, where the occupancy map is
still alive — a flood fill over contiguous `solidblock_glass` cells, stamped onto
every face those cells emit.

Doing it later is possible and wrong: the buried faces are already gone, so a
later derivation would be reconstructing a shape from its silhouette.

---

## 5. G3/G4 — The break

### 5.1 The break — a per-projectile roll (G-D11, G-D12, G-D14) ⚠️ REWRITTEN 2026-08-31

The single `pane_shatter_punch` threshold this section shipped with is retired.
The Director's model (2026-08-31): **each pellet or round that lands on a pane
does three things, in order.**

1. **The local hole (G-D14).** The impact voxel is DESTROYED. How many of its
   neighbours go with it is per-weapon, off `WeaponDef.blowout`:
   - pistol / shotgun pellet (`blowout` 0.0) → **1 voxel**, tight `crack_web`.
   - rifle-class (`blowout` ≥ ~0.5) → **2–4 voxels**, scaled by power; wider,
     more spaced `crack_web`.

2. **The shatter roll (G-D11).** The projectile rolls `P_shatter(glass_punch)`
   — a curve with a **near-flat bottom and a steep middle**, capped below 1.0.
   A single common round never *guarantees* a full shatter; only a
   `pane_primed` armored pane does (§5.3).

   **The Director-approved target distribution (2026-08-31), at neutral
   skill/luck:**

   | round | glass punch | P(shatter the pane) |
   |---|---|---|
   | smg | 1.65 | ~0% |
   | shotgun pellet (one) | 1.80 | ~2% |
   | pistol | 2.10 | ~2.5% |
   | revolver | 2.63 | ~16% |
   | assault rifle | 3.75 | ~44% |
   | sniper | 5.25 | ~81% |
   | **shotgun blast (24 pellets)** | — | **~38%** — `1 − (1 − 0.02)²⁴` |

   The exact `SHATTER_*` constants are `var` (rule 1) and **pinned by a selftest
   that reads the shipped weapon JSONs** and asserts this table within a
   tolerance — so a later balance edit to a weapon's `punch` fails the suite
   rather than silently turning a pistol into a pane-breaker (plan §11). The
   flat bottom is load-bearing: it is what keeps a shotgun's *volume* (24 rolls
   at ~2%) its advantage over a pistol's single ~2.5% roll, and it is what keeps
   "none of the 24 shattered it" a real outcome.

   ✅ **BUILT 2026-08-31 (Stage A) — `godot/scripts/systems/destruction/glass_shatter.gd`.**
   `p_shatter(glass_punch)` is a **shifted, renormalised logistic** — the
   `clamp(s(p) − C, 0)` is what makes the bottom actually reach zero (a plain
   logistic's tail never does). Constants: `SHATTER_K` 1.14, `SHATTER_X0` 3.79,
   `SHATTER_C` 0.075, `SHATTER_P_MAX` 0.98 (all `static var`). `rolls_shatter(glass_punch, salt)`
   is the deterministic B4 FNV-1a roll. `glass_shatter_selftest` (8 checks) reads
   `res://weapons/*.json`, computes each round's neutral `glass_punch` and pins
   the curve within ±6 pts (±8 for the 24-pellet compound); it also pins the flat
   bottom (0 below punch 1.5), the sub-1.0 ceiling, monotonicity, and that the
   roll's observed frequency tracks `p_shatter`. Curve vs targets as built: smg
   0.6% · pellet 2.0% · pistol 5.5% · revolver 14.3% · rifle 43.8% · sniper
   81.1% · shotgun blast 38.2%. Pistol lands a touch high — the target knee
   between punch 2.1 and 2.63 is sharper than a smooth sigmoid catches; Director
   2026-08-31: *"Boa — fixar como está."*

3. **The region (G-D12).** A won roll floods DESTROYED outward from the hit — a
   BFS over the pane's own voxels, radius scaled by `glass_punch` (a weak win
   takes a patch, a sniper takes the lot). On a small pane the radius covers
   everything → binary. On a large pane the rest survives with its `pane_id`
   intact and can be shattered by a later hit.

**G-D13b is a CONDITIONAL floor on all of it.** After the hole, the region, *and*
any later hits, a flooded glass voxel survives only where it is ANCHORED — an
orthogonal neighbour in the pane's lattice holding non-glass material. While a
pane has any anchor, at least `SHATTER_REMNANT_MIN_COUNT` of those survive; with
none, the pane goes completely.

✅ **AMENDED 2026-09-01 (G-D13b).** G-D13 spared survivors on the pane's own
BOUNDING BOX and forced at least 4 of them, on the reading that a pane always has
a frame. maps/GLASS.map.json's big pane does not — six GUs of glass with nothing
around it — and it kept shards hanging in mid-air, which is what the Director
reported. Measured on that exact pane, same shot, same salt, same radius 21, the
only difference being the model: **848 destroyed before, 882 after — 34 floating
shards now fall** (`glass_remnant_before_2026-09-01.png` /
`glass_remnant_after_2026-09-01.png`, 27 291 px changed). The glass still
standing on the left of both captures is OUTSIDE the flood radius — a legitimate
G-D12 partial break, not a remnant.

⚠️ **The same pass fixed a defect the anchor model exposed:** `plan_pane_shatter`
built its lattice from every voxel of every slice sharing the `pane_id`, and a
G-D9 banded window keeps its brick sill and head in those SAME slices. Nothing
consulted `material_at()`, so a won roll flooded straight through the brick and
returned it for DESTROY — **the pane took its own frame with it: 91 of 96 brick
voxels, worst trial**. Non-glass voxels are now frame: not flood candidates, the
BFS does not travel through them, and they anchor the shards beside them.

✅ **BUILT 2026-08-31/09-01 (Stage B) — `GlassShatter.plan_pane_shatter()` +
`agent_shot_controller._maybe_shatter_pane()`.** Runs in the SHOT PATH (where G7
already lives), once per pellet that landed on a pane, AFTER its local hole.
`plan_pane_shatter` builds the pane's own `(col, level)` lattice over every
`pane_id` slice (col = run axis: X for SW/NE, Y for SE/NW — panel panes only,
`PANE_BLOCK_*` deferred), Chebyshev-BFS-floods from the hit to `region_radius(glass_punch)`
= `BASE(3) + GAIN(6)·(glass_punch − PIVOT(2))`, then spares the frame ring:
each border voxel in the flood survives with `lerp(KEEP_MIN 0.10, KEEP_MAX 0.40, luck)`
and at least `MIN_COUNT` (4) always survive (the ones furthest toward a corner,
so they read as frame fragments). Every flooded voxel is `set_damage(DESTROYED)`
and folded into the shot's own bookkeeping — render pass, VL-PERSIST and
`bump_world_revision()` unchanged. `glass_shatter_selftest` grows to 12 checks
(region monotonic; small pane binary + remnants; big pane PARTIAL on a revolver
win / near-full on a sniper; G-D13 never leaves 0 border across 60 rolls).
Real-map, GLASS map's big pane (6 GU × 3 storeys, 1152 voxels): assault rifle
`glass_punch 4.13 radius 16` → **647 destroyed, the guard-side half stands**
(`glass_shatter_partial_rifle_2026-09-01.png`); sniper `glass_punch 5.78 radius 26`
→ **972 destroyed, 180 remnants** (`glass_shatter_full_sniper_2026-09-01.png`);
the round passes through and marks the concrete behind. ⚠️ `_dispatch_destruction_vfx`
now early-returns for `glass` — a 970-voxel shatter was 970 smoke puffs, a milky
haze over the map; glass debris is SHARDS (G6, a floor decal), not particles.

⛔ **STAGE B IS INERT ON THE REAL MAP — found 2026-09-01 while verifying V-A,
and it is NOT a regression from that work** (the before/after runs on the same
binary are identical: `glass destroyed=18` for sniper, rifle and shotgun alike).

**The local hole walls off its own shatter flood.** The BFS queues a neighbour
only `if lattice.has(nb)`, and `lattice` holds SURVIVING glass only — so it can
never step across a hole. The origin is this shot's own fresh hole, and a
rifle-class round's hole (G-D14: 2–4 voxels, plus the cascade) takes every cell
around it too. Measured on the GLASS map's big pane, sniper, roll WON:

    lattice=1143  own_frame=0  origin=(114, 84)  origin_in_lattice=false
    neighbours_in_lattice=0/8  flood=0  radius=23

1143 surviving voxels, a radius of 23, and the walk dies at step one. **The
failure scales the WRONG WAY:** the more powerful the round, the wider its local
hole, the more certainly the flood is strangled — and it bites hardest on the
sniper, which is the round most likely to win the roll in the first place. The
2026-09-01 captures above (972 / 647 destroyed) were taken before the GLASS map
grew its second pane row, and no longer reproduce.

**The fix is one branch, and it must distinguish two absences that are the same
absence today.** A cell missing from `lattice` is either a HOLE (fracture travels
straight through it — an already-broken area does not stop a crack) or the pane's
own non-glass BAND (`own_frame`, which must keep stopping it, G-D13b). So the
walk expands through everything inside the radius except `own_frame`, and only
RECORDS a cell in `flood` when the lattice holds it:

    if dist.has(nb): continue
    if own_frame.has(nb): continue   ## a real frame stops the fracture
    dist[nb] = d + 1
    queue.append(nb)                 ## a hole does not
    if lattice.has(nb): flood[nb] = true

⚠️ **The selftest could not have caught this and still cannot**: its fixtures
place the hit on an INTACT lattice cell, so the origin is in `lattice` and the
walk starts alive. The regression test has to destroy the origin's whole
neighbourhood first — which is what a real shot does before `_maybe_shatter_pane`
is even called.

**⚠️ Stage B runs in the SHOT PATH, not the cook.** The shot path does not use
`build_plan()`/`WorldDelta` — G7 and the local hole are all direct
`plan_point_impact` + `set_damage`, and Stage B matches that.

✅ **BUILT 2026-09-01 (Stage C) — the grenade/cook path.**
`GlassShatter.blast_glass_punch(ring_multipliers, ring)` = `SHATTER_BLAST_GAIN(3.4)
· ring_multipliers[ring] / RESISTANCE["glass"]` — the cook has no per-projectile
punch, so the pane's roll runs off the blast's own per-ring falloff (frag_grenade:
~98% at ring 0, ~79% at ring 1, ~6% at ring 2, 0 past). In
`detonation_plan_builder._phase_slices`, glass PANEL slices are pulled OUT of the
ring-scatter model entirely (glass fractures, it does not deform — whole break or
none); glass BLOCKS keep it. `_shatter_glass_panes()` groups the affected panels
by `pane_id`, keeps the nearest ring, rolls once per pane, floods the whole pane
(`plan_pane_shatter`, G-D13 remnants) into the Delta as blast-sourced DESTROYED,
deterministic on `(source_gu, pane_id)`. ⚠️ **`detonation_entry_writer`'s "destroy"
wave only knew `get_layer()` → the opaque stack** — a blast-shattered pane stayed
on screen because glass renders on `_glass_layers`. New
`VoxelRenderer.erase_glass_cell(level, cell)` (a no-op for non-glass) is now
called per destroy entry. This was a latent gap for glass BLOCKS too; Stage C
surfaced it. Real map: frag grenade at a corner of the GLASS big pane → ring 0,
1131/1152 flooded, the pane gone (`glass_shatter_grenade_2026-09-01.png`).

## 5.4 — WHERE A SHARD LANDS (proposed, needs sign-off)

Director, 2026-09-01, immediately after ratifying G-D13b: *"vamos empilhar mais
cacos na base do vidro quebrado… O modelo de âncora precisa ser bem planejado,
para os cacos caírem no peitoril, balcões, etc. Teremos claraboias e janelas no
teto, então precisamos arquitetar bem essa queda dos cacos. […] além de paredes
multi-materiais, precisamos de slabs multimateriais."*

⚠️ **Nothing below is built or ratified.** It is the mechanism, the state of the
tree it has to land in, and the questions that decide the shape.

### The simplification worth deciding first

G-D13b answers ONE question: *does this shard survive where it is?* Every item
the Director just named is a DIFFERENT question: *where does the glass that fell
end up?* Separating the two collapses three features into one rule:

> **A destroyed glass voxel falls straight down its own column until it meets the
> first horizontal surface, and accumulates there.**

That single rule gives, with no special case per feature:

| case | falls to |
|---|---|
| a normal pane | the floor at its base — the pile the Director wants |
| a pane over a counter (`balcão`) | the counter's top |
| a window with a sill (`peitoril`) | the sill |
| a skylight / roof window (`claraboia`) | the floor a whole storey below |

**And that may mean the anchor model needs no horizontal sources at all.** A sill
would get a PILE ON TOP of it rather than shards WELDED ABOVE it. G-D13b, exactly
as shipped, already handles the one sill that is genuinely in the pane's plane:
G-D9's brick band (maps/GLASS.map.json's WINDOWS wall), because a band is part of
the same Slice. **Q1 for the Director: for a real windowsill, do you want shards
clinging to the glass above it (an anchor), or piled on top of it (a landing), or
both?** The answer decides whether `collect_anchor_positions()` ever has to reach
outside the pane's plane — which is the difference between a tuning change and a
new cross-plane query.

### What the tree actually holds today (measured, not assumed)

| | state |
|---|---|
| `Slice` / `Edge` | `material_bands: Dictionary` keyed by **rel_level**, read through `material_at(rel_level)`. A 1-D run along the vertical axis |
| `Slab` | **single `material`. No bands, no `material_at()`** |
| `pane_id` | **`Slice` only.** `plan_pane_shatter()` is built on a `(col, level)` lattice with a run axis — it has no meaning for a horizontal pane |
| glass on the pane layer | **INTERIOR slabs only.** [`voxel_renderer.gd:3676`](../../godot/scripts/geometry/voxel_renderer.gd) is explicit: *"roofs and glazed floor zones stay opaque"* — a CEILING slab set to `glass` renders as an opaque glass-coloured slab today |
| G6 shards | designed (§7.1) as a **floor decal** on the floor-dent path, BASE coords, checkpoint-scoped, a third `SaveState` section. **Unbuilt** |
| `PropDef.material_zones` | the dictionary exists; only `"default"` is ever read ([`voxel_renderer.gd:4773`](../../godot/scripts/geometry/voxel_renderer.gd)). Props are single-material in practice |

So a skylight does not merely lack polish — **it has no pane identity, no
transparency, and no shatter path.** Three separate seams, not one.

### Multi-material slabs — NOT the slice model with a renamed axis

This is the trap to avoid, and it is worth stating before anyone writes
`Slab.material_bands`:

- A **slice** band is **1-D along `rel_level`**. A wall is 8 wide × N tall, and a
  sill/head is a horizontal run across the whole width — so one integer keys it.
- A **slab** is **one level, 8 × 8 in plan**. There is no level axis inside it. A
  slab's regions are **2-D sub-areas of the GU footprint**, so the same key shape
  cannot express them.

**And a per-GU skylight needs no bands at all.** Slabs are already per-GU and
single-material, so *"this GU's ceiling is glass"* is expressible the moment the
render routing allows it. Bands are needed only where the boundary is INSIDE one
GU — a skylight's own frame, a glass counter with a metal rim. That is the same
order walls took: a whole-GU glass panel worked first (G1), and G-D9 added the
sill/head inside one GU afterwards.

**Q2 for the Director: is the first skylight a whole GU, or does it need a frame
inside its own GU?** Whole-GU first is a much smaller piece and unblocks the fall
model immediately; sub-GU regions can follow the way G-D9 followed G1.

### ✅ G-D16a BUILT (2026-09-01) — `GlassFall`

`godot/scripts/systems/destruction/glass_fall.gd`, pure like
`collect_anchor_positions()`: it takes a surface INDEX, never the SlabRegistry, so
the selftest hands it a synthetic counter and proves the rule without a map.

- `build_surface_index(slabs, columns)` — a surface is any visible, undestroyed
  voxel of ANY Slab. That is why it names no feature: the ground is a FLOOR slab,
  a block roof and a counter top are CEILING slabs, a ledge is an INTERIOR one, so
  all three catch shards without a branch. **Glass is not a surface** — a shard
  through a skylight must not stop on the next pane under it, the same way a round
  does not (G-D5). `columns` restricts the walk to the columns a break touched, so
  the cost is proportional to the break, not the map.
- `landing_level()` = the highest surface STRICTLY below. A shard level-with a
  counter top is beside it, not on it, and goes to the floor.
- `plan_landings()` returns only shards that actually came to rest; one with
  nothing under it is DROPPED, never reported at a fake level 0 (`NO_LANDING`).
- `pile_by_cell()` gives G6 the shape it needs: `Vector3i(x, y, level) -> count`.
  Nothing is deduplicated — the multiplicity IS the pile depth.

`glass_fall_selftest`, 6 checks, one per case the Director named, all on the same
function with nothing changing but the geometry underneath: bare floor → base
pile; the SAME pane over a counter → 18 shards on the counter and the 6 at or
below it on the floor; a skylight at level 96 → a 17-level drop to the floor;
glass under glass → falls through; nothing underneath → no landing; a 3-storey
column → one cell at density 24.

**Wired into BOTH real paths on day one** — the shot path and the cook — and
REPORTED there rather than left until G6 can draw it. §7.1's own risk note is
that this project has already shipped two features that were built and never
triggered; a number in the shot's own log is the cheapest thing that cannot rot
unnoticed. Real map, GLASS's big pane, sniper:

    [GLASS-SHATTER] pane=PANE_SLICE_16_10_SW glass_punch=4.99 radius=21 flooded=882 voxel(s)
    [GLASS-FALL] 882 of 882 shard(s) landed, on 37 cell(s), deepest pile 24 (0 fell out of the world)

Deepest pile 24 is a full 3-storey column of glass emptying onto one floor cell —
the pile the Director asked for, already computed.

⚠️ **A latent seam found and closed while wiring it.** `plan_pane_shatter`'s
lattice key is `(col, level)` — for an SW/NE pane that is `(grid_pos.x, level)`,
and the THICKNESS row is dropped. That holds today because a glass panel is
half-thickness with exactly ONE slice per GU (verified on the real map: the
6 GU × 3 storey pane is 48 cols × 24 levels = 1152 voxels). The day a
full-thickness glass wall or a `PANE_BLOCK_*` exists, two voxels would collide on
one key and the second would silently overwrite the first — **half the pane would
never break, with no error anywhere.** It now `push_error`s and returns empty (B6)
instead.

⚠️ **G-D16b is blocked on art.** The landings are computed and reported; nothing
draws them. §7.1's decal path needs the `shard_floor` family, which G-ART has not
delivered. That is a real dependency, not a choice.

### ✅ G-D17 BUILT (2026-09-01) — the layer modifier

`GlassShatter.punch_after_layers(glass_punch, depth)` = `punch · SHATTER_LAYER_FALLOFF^depth`,
`SHATTER_LAYER_FALLOFF` a `static var` at **0.62** (architecture Rule 1, like every
balance row here). `_flatten_glass_passthrough()` stamps `glass_depth` on each
pick, because that is the one place that knows the flight order; the apply loop
and the W-PRECOOK loop apply the identical attenuation, since the precook has to
warm the alternatives the shot will actually land on.

The sniper, layer by layer — `punch 5.25 → 3.25 → 2.02 → 1.25 → 0.78`, and
`P(shatter) 81% → 29% → 4% → 0% → 0%`. **It stops being able to shatter at the
fourth pane by the curve alone**, with no rule saying "stop after N".

⚠️ **The GLASS map had no line that crossed two panes** — every panel was on
authored row y=9 — so the mechanic could not be verified on it at all. A second
row (gu x=11..14, y=6, face SW, 3 storeys) was added; the map's own description
says why. This is the map's stated job (*"Glass Physics Test Zone"*), and a
physics test zone that cannot express the case under test is the gap, not the fix.

**Real map, same shot, same salt, the model the only variable** (before side
captured with the change stashed):

    BEFORE  punch=[6.06, 4.72, 1.68]
    AFTER   punch=[6.06, 2.93, 0.65]

Three picks: the near pane, the pane behind it, and the wall behind both. Depth 0
is IDENTICAL in the two runs (6.06) — the ratified table really is untouched. The
second pane loses 38% and the wall behind loses 61%. On the neighbouring column
the near pane shattered at 5.93 while the far one, rolling at 3.34, did not —
which is the mechanic doing exactly what it was asked to do.

⚠️ **What this does NOT yet do: a solid glass CUBE.** `PANE_BLOCK_*` panes are
still excluded from the cascade (they have no single run axis, so
`plan_pane_shatter`'s `(col, level)` lattice has no meaning for them), and
`_note_glass_crossing()` dedupes by `pane_id`, so entering and leaving one block
counts as ONE layer rather than two. The attenuation is the half that generalises;
the block geometry is its own piece and is named here rather than implied.

### G-D19 mechanics — the free channel that carries the damage term

Verified in the shader, not assumed. There is exactly ONE glass shader
(`glass_pane.gdshader` + `glass_shading.gdshaderinc`) and it reads exactly two
things from the atom:

    float cover = smoothstep(glass_alpha_floor, 0.85, t.a);   // silhouette
    vec3  lit   = glass_apply(behind, local, t.r);            // per-plane dim

`_build_glass_pane_atom()` writes `Color(rgb, rgb, rgb, a)` — **R, G and B are
the same value and only R is ever read.** So the GREEN channel of a glass atom is
free, and a per-voxel damage factor can ride it exactly the way FACE-SOOT-01
rides the soot code in alpha on opaque voxels. No new texture, no new layer, no
new atlas source.

Why this matters more than it looks: glass does not alpha-blend at all. G-D1 is
explicit — *"straight alpha averages the texture toward whatever is behind and
washes it out. Glass MODULATES it"* — so the pane reads a BackBufferCopy of the
scene behind it and multiplies a tint over it. **There is no opacity knob to turn
down.** "50% see-through" means mixing the result toward an opaque frosted body,
which is what `glass_min_body` already does globally for a pane over a void:

    vec3 lit = glass_apply(behind, local, t.r);
    lit = mix(lit, glass_tint * frosted_body, t.g);   // t.g = per-voxel damage

**The compositing order, stated once so it cannot drift:** the decal composites
into the atom FIRST and only touches RGB + alpha-as-coverage — B3 still clamps it
to the silhouette, a decal still cannot enlarge a voxel. The damage term is
applied by the SHADER, after, to the background contribution. They are never
multiplied together, and the decal's own opacity never reaches `cover`.

### G-D21 mechanics — the numbers, and the one that bites

**It really is a subtraction.** The wall path keys every voxel through
`BakedTileLookup._compute_facade_key()`:

    sheet_col = _mirror_index_1d(column_in_run, 64)
    sheet_row = _mirror_index_1d(level, 32)
    key       = material|facade|col|row|dir

`column_in_run` and `level` are already the sheet-relative window. Re-anchoring
the crack onto the impact is offsetting those two by `(impact − sheet centre)`.
Nothing is invented and nothing is minted at shot time: the crack ART is fixed,
so its atoms compose once at load exactly like a facade's, and a shot only
changes which atom each voxel asks for. **That is the decisive advantage over
G-D20's mosaic** — a tile assembler still has to decide and place per event.

**The sheet is not "bigger than conventional" — it is exactly one facade page.**
64 columns × 32 rows = **2048 atoms**, and the boot log says the same number back:
`[BAKE] Composed sheet concrete|facade_concrete|0 (2048 atoms)`. The GLASS map's
big pane is 48 × 24, so it fits inside one window with 16 columns and 8 rows of
margin — the "margem pra sangrar" already exists at the current dimensions.

⚠️ **THE NUMBER THAT BITES: the vertical fold is smaller than a sniper's crack.**
The key uses MIRRORED repeat, which is right for a texture and wrong for a
fracture — a mirrored crack is a second, false crack. Measured against the real
`region_radius`:

| axis | period | reach from centre | of 55 offsets at radius 27 |
|---|---|---|---|
| column | 64 | ±32 | **0 fold** |
| row | 32 | ±16 | **23 fold** |

Horizontally it fits with 5 columns to spare. Vertically a sniper's radius 27
overruns ±16 and the crack mirrors back onto itself. Three ways out, and this is
the decision the build needs before it starts:

1. **Give the crack family its own period.** The 64/32 pair is a constant in one
   function; a crack sheet keyed at 64/64 costs 4096 atoms — twice a facade page,
   still one page's order of magnitude.
2. **Clamp the crack's vertical reach to ±16** (2 storeys). Cheapest, and the
   fracture stops looking like it wraps — but a 3-storey pane can then never
   crack top to bottom from one hit.
3. **Drop the mirror for this family** (plain clamp-to-edge instead), so beyond
   the sheet there is simply no crack. Closest to physically right.

**The Director's own margin argument survives all three**, and is why this works
at all: beyond the crack radius the sheet is EMPTY, and an empty region mirrored
is still empty. The fold only ever bites inside the radius — which is exactly the
region the table above measures.

### G-D23 / G-D24 mechanics — what the build has to do

**The clamp (G-D23).** `BakedTileLookup._compute_facade_key()` folds both axes
through `_mirror_index_1d()`. The crack family takes a clamp instead — index
below 0 or at/above the period resolves to NO CRACK, not to a reflected one.
Concretely that is a second key function (or a flag on the existing one), not a
change to the facade path, which must keep mirroring: a mirrored FACADE is
invisible and correct, a mirrored FRACTURE is a second false crack. **The two
families must not share the addressing.**

**The maximum pane (G-D23).** 64 × 32 voxels = 8 GU × 4 storeys, derived from the
sheet rather than invented, so *"a centred hit can crack the whole pane"* is a
guarantee rather than a hope. Two consequences worth writing down before someone
authors a wider window:

- maps/GLASS.map.json's big pane is 6 GU × 3 storeys — inside it already.
- ⚠️ **A `bands` divider does NOT split a pane, and this doc said it did.** I
  wrote that the fix "needs no new feature: `panels[].bands` already puts a
  non-glass band inside a pane". Wrong, and the real map said so: widening
  GLASS's big pane from 6 GU to 9 bridged the gap to the brick-capped window at
  gu 19..21 and the two merged into **one 12 GU pane** — which is what the new
  check reported. A banded window is still BASE glass, so `_is_glass_slice()`
  keeps it in `panels`, and the union-find joins by face and adjacency **without
  ever reading `material_bands`**. A real divider is a **non-glass panel** at the
  middle GU, or a **gap**; either breaks the adjacency the union walks.
- ✅ **The maximum is enforced from 2026-09-01** —
  `GlassPaneGrouper.oversize_panes()` measures every panel pane's run-GU and
  storey span and `_check_pane_size()` `push_error`s each violation, naming the
  pane, its size, the limit and the fix. The decision is split from the reporting
  on purpose: a selftest cannot intercept `push_error`, and a rule observable only
  in a log is a rule nothing gates. Pinned by `glass_transparency_selftest` [9],
  which asserts the boundary case passes (8 GU × 4 storeys accepted) as well as
  the two rejections — a rule that rejected everything would pass a
  rejection-only test.

**The crossing (G-D24).** A voxel already carrying a crack, reached by a second
fracture, is set DESTROYED. What that buys, beyond being right:

- **No per-voxel crack-source int.** The "nearest impact wins" bookkeeping
  proposed a turn earlier is deleted before it is written.
- **No compositing of two sheets, ever** — which was the one cost that could have
  made G-D21 mint at shot time. It now provably cannot.
- **A second shot means something.** The first crazes; the second opens a hole
  along the intersection of the two fractures. That is emergent from the rule,
  not scripted.
- The freed voxels fall and pile through G-D16a like any other break, so the
  floor already knows what to do with them.

⚠️ **Everything above is blocked on the same thing: `glass.crack_factor` is 0.0.**
No voxel can reach a CRACKED glass state today, so none of G-D19/G-D21/G-D23/
G-D24 can be exercised on a real map yet. The day that number goes non-zero,
`voxel_decal_selftest` **[12]** requires the family wired AND all three variants
on disk, in both directions — the data, the wiring and the art land together or
the suite goes red. That is deliberate: it is the same coupling that let
`bake_cache_test` rot for three weeks when only one side moved.

### The second shot — and it is the same problem the mosaic had

*"O desafio nesse caso seria fazer a conexão quando um segundo tiro na mesma
janela for efetuado […] adicionar uma rachadura extra por cima, nos voxels que
ainda resistirem."* Right, and worth saying plainly: **no scheme avoids this**,
the mosaic included, so it is not an argument against G-D21.

⛔ **The "nearest impact wins, per voxel" answer this paragraph used to propose is
SUPERSEDED by G-D24, same day.** It needed a per-voxel crack-source int and still
had no answer for two fractures crossing. The Director's is better and costs
nothing: **where they cross, the glass falls out.** No bookkeeping, no
compositing, and the crossing stops being the missing case — it becomes the
mechanic.

### G-D21 simplifies G-D19

If the crack is its own sheet drawn on its own sublayer over the glass — and
glass already has a sublayer pair (`_ensure_glass_sublayers`, the frosted/sheen
pass) — then the compositing-order question G-D19 was written to answer largely
dissolves: the crack's own opacity is its LAYER's alpha, and the 50% frosting is
a term the glass shader applies to the layer UNDERNEATH. Two layers, two
channels, nothing multiplied into `cover` by accident. G-D19's free green channel
is then only needed to tell the glass shader *which voxels are cracked*, which is
a single flag rather than an opacity.

### G-D20 mechanics — what a connecting tile set has to be

The tiles are ordinary per-voxel decals; what makes them a fracture is that their
EDGES agree. Wang-tile style: each of a tile's four edges is either "no crack
crosses here" or "a crack crosses at position *p*", and the assembler only places
a tile whose edges match its already-placed neighbours.

- **The impact voxel** gets the hole tile — the one family whose placement is
  fixed by the event, which is the whole reason the mosaic exists.
- **Outward from it**, tiles are chosen by matching the neighbour's exit points,
  so radials continue across seams instead of restarting per face.
- **Rotation is free** — four orientations per authored tile, so the authored set
  is roughly a quarter of the placed variety.

⚠️ **Authoring the tiles by hand is the part most likely to go wrong**, because a
human drawing sixteen edge-compatible 256 px tiles will miss alignments. The
cheap way round it: draw ONE large fracture and CUT the tiles out of it on a grid
— continuity is then true by construction rather than by care. That also happens
to be the answer to whether Stable Diffusion can author them (§7.3).

### The staging this implies

| | piece | depends on |
|---|---|---|
| **G-D16a** | **The fall.** A destroyed glass voxel's landing cell = straight down its column to the first horizontal surface. Pure geometry, testable with no art | ✅ **BUILT 2026-09-01** |
| **G-D16b** | **G6 accumulation.** The landing cells become shard density on the floor-decal path (§7.1). This is what makes the pile visible, and §7.1's own risk note says a state nobody can see is a state that rots | G-D16a, G-ART |
| **G-D16c** | **Horizontal panes.** CEILING glass routes to the pane layer; a horizontal `pane_id`; a shatter plan over an (x, y) lattice instead of (col, level) | G-D16a |
| **G-D16d** | **Sub-GU slab regions.** Only if Q2 says the frame lives inside the GU | G-D16c |

⚠️ **The ordering claim:** G-D16a is worth doing first even if the Director wants
skylights most, because the fall rule is the thing all four share, it needs no
art, and it is the only one of them that can be pinned by a selftest before a
single pixel exists.

✅ **Stage D — BUILT 2026-09-01 (the split and the opening; the detection/light
bump is the remaining third).**

**The problem was a conflation, not a missing flag.** `_current_blocked_edges`
fed MOVEMENT, VISION, DETECTION, NOISE and LIGHT from one set, and a
half-thickness glass panel entered none of it — so agent and guards walked
through intact glass, and "just add glass to blocked_edges" would have fixed the
feet by blinding every guard through every window, which is exactly what G-D7
forbids.

`EnemyPhaseController.build_movement_edge_set(edges, glass_edges, registry)` is a
SECOND set, used only where feet are involved:

| consumer | set |
|---|---|
| `MovementOverlay` (the agent), `GuardPathfinder` via `choose_next_cell()` / `move_to_cell_animated()` | **movement** |
| `can_see_cell()`, `TicSystem` | vision |
| `NoiseSystem` propagation | vision |
| `ShadowProjector` | vision |

And it answers the other half of G-D8 in the same pass by asking **`PassageQuery`
rather than a boolean**: a glass edge blocks the body only while its pane is
still `PassageClass.NONE`. A broken pane simply stops being added, so the passage
opens with no second record of what is broken and nothing to keep in sync.
Recomputed in `_refresh_tactical_state()` — which already runs after every agent
move — so a pane broken mid-turn opens for the guards in that same turn.

`run_single_guard_turn()` takes the movement set as an optional argument
defaulting to `blocked_edges`, so every caller not yet split behaves exactly as
before. `MovementOverlay.set_blocked_edge_keys()` is now its single writer;
`set_blocked_edges(array)` survives as the wrapper, because the `{from, to}`
array shape cannot express a glass panel at all.

**Real map, GLASS, one sniper shot at the big pane:**

    boot          glass edges=14 | vision blocks=88 | movement blocks=102 (+14 glass) | panes open=0
    after break   5 of 6 pane edge(s) OPEN [NONE, STANDING x5] | glass edges still blocking movement: 9

Intact glass added exactly its 14 edges to movement and none to vision; the
shatter (882 of 1152 voxels) opened five of the pane's six edges to STANDING, and
the movement set dropped 14 → 9. The one edge still NONE is the column outside
the flood radius — a partial break, which is G-D12 working.

`passage_query_selftest` [10] pins both halves on one edge with nothing changing
between them but the glass: intact blocks movement and NOT vision, broken drops
out, and the movement set's verdict is asserted to agree with `PassageQuery`'s own
so the two cannot drift apart.

⚠️ **Still open, the third part of G-D8:** *"não influencia tanto na luz, apenas
aumenta um pouco de intensidade e sobe um grau de detecção"* — the light bump and
the +1 detection step when a passage opens. Both need the opening to be an EVENT,
and what landed here is a per-turn recomputed SET, which deliberately has no
memory of the moment it changed. That is the right shape for passage and the
wrong one for a one-off bump, so it is its own piece rather than a line bolted on.

### 5.2 Remnants on the frame

*"deixando mais ou menos sobras na borda da janela, da porta"*

A slice is 8 positions × 8 levels per storey (`index = level * 8 + position`), so
the frame ring — position 0/7, level 0/7 — is derivable for free. Border voxels
survive with a probability drawn from the blast's own `luck` (the B4-pinned
FNV-1a), so *"mais ou menos sobras"* varies per event and still replays exactly.

Survivors render as **carved half-voxels with a jagged glass silhouette** —
D32.2's four-substrate machinery, which glass has simply never had its own art
for. This is the *"geometria apropriada"* half of the Director's brief; the
decals are the other half.

### 5.3 Armored glass (G-D15)

`glass_armored` (purple tint) is a `glass_class = ARMORED`. Against it the §5.1
ladder changes:

- **Resistance is high** — a much larger `RESISTANCE["glass_armored"]`, so a
  common round's `glass_punch` lands near `SHATTER_ROLL_FLOOR` and the local
  hole is often the whole story.
- **When it DOES shatter, it goes all at once** — the region radius for an
  armored win is the whole pane regardless of size, and the survivors read as
  *many individual shards* rather than a clean edge (G6's shard count is high,
  the frame remnants sparse).
- **The rifle pierce-and-prime case.** A rifle round that fails its shatter roll
  on an intact armored pane may still *pierce a single voxel* (a weak-hit hole,
  G-D5 pass-through still applies) and set **`pane_primed = true`** on that
  `pane_id`. A primed pane's next hit of any type has `P_shatter = 1.0` — it
  auto-shatters. `pane_primed` lives in `SaveState` alongside the shard store
  (G6), checkpoint-scoped.

An **INDESTRUCTIBLE** `glass_class` (the control-interface screens, G-D16)
short-circuits §5.1 entirely: the impact voxel takes a permanent `crack_web`
decal, nothing is ever DESTROYED — **and the round STOPS** (Director, 2026-08-31:
*"Trinca mas o tiro para"*). This is the one glass that does NOT pass a round
through (G-D5 does not apply), which is what sells it as genuinely armoured
rather than just tough.

---

## 6. G5 — Cracking

### 6.1 What G-D3 converts from accident into intent

Two known defects, both carried open in `MATERIALS_MASTER_PLAN` §4.2, are
**resolved by the Director's ruling rather than patched**:

1. *A far shotgun pellet already CRACKS glass, contradicting D22.* `damage_state_for()`
   returns CRACKED below `PUNCH_DENT_MIN` and a pellet at the end of the distance
   ladder computes `3.0 × 0.24 × 0.15 × 0.85 / 0.4 = 0.23`. Under G-D3 that is no
   longer a contradiction — it is the feature.
2. *Glass's empty DENTED band is a coincidence of two equal numbers.*
   `DESTROY_MIN["glass"]` and `PUNCH_DENT_MIN` are both `0.30`, which makes the
   band exactly empty. G-D3 makes that intentional — **glass fractures, it never
   deforms** — and it must be **pinned by a selftest**, not left as an equality
   two independent edits could break.

**Consequence worth stating:** the M4b note said glass would need
`HOLE_ONLY_MATERIALS` **and** a new `INTACT` return *"together, or neither"*.
G-D3 removes the need for both. Glass now marks (it cracks), so it does not
belong in `HOLE_ONLY_MATERIALS`; and *"não feito"* is gone, because a weak hit
now cracks instead of doing nothing. **The `INTACT` branch nobody wanted to build
is no longer required.** The ladder becomes: CRACKED → (no DENTED, ever) →
DESTROYED.

### 6.2 Cracking near a blast it survives

*"fazer o vidro rachar, se estiver perto de uma explosão, mas não dentro da área
de dano"*

A **crack radius** one or two rings beyond the destruction radius, glass-only,
reusing the same BFS the soot derivation already walks. Cheap because only glass
cells qualify and glass is sparse — the map-wide voxel walk that dominates the
cook (`PREDICTION_MASTER_PLAN` §8.8) is not widened.

### 6.3 The bullet web

*"o tiro fura o vidro, e cria aquele padrão de ondas rachadas ao redor"*

The hole is one voxel; the ring cells around it go CRACKED (G-D4). The ring index
picks the decal variant — dense near the hole, sparse further out.

⚠️ **The art constraint this creates, and it is the one that decides whether it
reads as glass:** the radial lines must point outward from the hole, so the web
reads as one continuous fracture rather than nine stickers in a 3×3.

⛔ **The mechanism this paragraph proposed — a decal chosen by BEARING from the
hole — is superseded by G-D21.** A single sheet re-anchored onto the impact is
radially continuous by construction, because every voxel reads its own place in
one fracture rather than picking a stamp that has to agree with its neighbours.
The requirement survives; the direction index does not, and §8 no longer orders
one.

---

## 7. G6/G7 — Shards, and the round that keeps going

### 7.1 Shards on the floor

*"conseguimos fazer eles caírem permanentes no chão, mais ou menos como o mapa de
fuligem?"*

**Not on the soot map itself.** It is `FORMAT_RG8` — R is the per-face soot code
(0..124), G is the light bucket ([`voxel_renderer.gd:3507`](../../godot/scripts/geometry/voxel_renderer.gd)).
Both channels are spoken for, and the cell plane (P3) still defaults OFF, so
anything living there is invisible on the shipped path.

**The path that works on the shipped renderer:** shards as a **floor decal**, the
same path the floor dents already take (`_floor_sunk_decal_plan`). Permanent by
construction, survives repaint, Rule 8 intact, and it commits inside the
detonation's single commit frame — the frame that already mints.

**Stored in BASE coords**, the lesson both `_base_damage` and the soot store
already encode: rotation is suspended for performance and is meant to return, and
a record in view space is a record rotation loses in silence. Lifetime is
checkpoint-scoped, like every other scenario mutation. `SaveState` gains a third
section alongside `base_damage` and `crater_floor_soot`.

⚠️ **The honest risk.** Per G-D6 shards are state, and their gameplay consumer
(noise) is deferred. This project has already shipped two features that were
built and never triggered — the noise indicator and the exposure labels. What
keeps shards from becoming the third is that the **decal makes them visible from
day one**: a state that is on screen cannot rot unnoticed. That is the mitigation,
and it is deliberate, not a hope.

### 7.3 Can Stable Diffusion author this? (Director asked 2026-09-01)

*"temos um Stable Diffusion instalado, seria possível gerar essas artes de
maneira realista e convincente, com opacidade?"*

**Realism: yes. Opacity: not directly — but glass has a shortcut that makes it a
non-problem.** SD outputs RGB and no alpha, and a general matting model is
overkill here. A glass crack is BRIGHT ON DARK, so:

> generate on a pure black field → take alpha = luminance → set RGB to the crack's
> own near-white → done.

No matting model, no manual cutout, and the result is exactly the shape §7's
gate wants (`check_decal.py` asks whether the IMAGE is transparent, and accepts a
palette PNG with a tRNS chunk, so an ordinary export passes).

**Where SD will NOT help, and it is worth knowing before spending a night on it:**

| | |
|---|---|
| Edge-matching for G-D20's tiles | SD has no notion of a tile boundary and will not produce cracks that line up across four edges. **Do not fight this** — generate ONE large fracture and cut the tiles out of it on a grid. Continuity becomes true by construction, and it is less work, not more. |
| The 16×20 px read | The real constraint, and the one neither SD nor any authoring tool solves. Detail that reads beautifully at 256 dissolves at 1/16th linear. Whatever comes out has to be checked at true size before it is delivered — which is what the fracture-plates page exists for. |
| The hole's position | Fixed by the event, not by the art (G-D20). SD authors the vocabulary of marks; the assembler decides where each one goes. |

**A workable order:** generate a handful of large fractures at 1024–2048 on black
→ luma-to-alpha → cut the tile grid → check every tile at 16×20 → deliver the set
that survives that check. The generation is the cheap step; the true-size check is
the one that decides what ships.

### 7.2 Pass-through

The pellet flood stops at blocked edges. G-D5 makes glass passable to the flood:
the pane takes its hole, the round continues, and what is behind it takes the
real impact. One rule at one seam.

---

## 8. G-ART — ✅ WRITTEN AND GATED 2026-09-01

**The order is [`PROMPTS/ART_ORDER_GLASS.md`](../ART_ORDER_GLASS.md)** and
`tools/persistent/check_decal.py` now enforces it — earned BEFORE the art, the
way M2a was. What remains of G-ART is the delivery itself.

**FIVE files, in two classes that fail in completely different ways:**

| Class | Files | Shape |
|---|---|---|
| **fracture sheet** | `fracture_glass_tight.png`, `fracture_glass_wide.png` | 1024×512 grayscale **on a black field, no alpha** — one 64×32-voxel page, G-D21/G-D23 |
| **floor shard decal** | `decal_shard_glass_{0,1,2}.png` | 256×256 RGBA with real transparency — an ordinary §7 decal, G-D16b |

⚠️ **THIS SECTION'S OWN FOUR-FAMILY TABLE IS SUPERSEDED and is kept below only
so the change is visible.** It was written on 2026-08-30, before G-D20/G-D21, and
three of its four rows are now wrong:

| Old row | What replaced it |
|---|---|
| `crack_web`, 3 variants, **direction-indexed** by bearing | **G-D21's sheet.** The fracture is anchored to the EVENT, so direction falls out of the `(impact − centre)` offset and no art is indexed by bearing. Two sheets, tight and wide (G-D14), not three variants |
| `bullet_web` — the impact cell itself | **Folded into the sheet**, whose hole is baked at its centre. A separate per-voxel bullet mark would be a second, competing fracture |
| `shard_floor` | Survives, as the decal family `shard` — the only one glass claims |
| `frame_remnant` | Survives as stated: **geometry, not a decal** (§5.2) |

**Three things the order records that were only discovered by reading the
consumers, and each would have wasted an authoring pass:**

1. **The facade path DESTROYS alpha.** `bake_compositor.gd:556-558` round-trips
   through RGB8 and flattens it to 255, so §7.3's *"generate on black, alpha =
   luminance"* recipe — correct for the DECALS — would deliver a sheet as a
   bright crack on **opaque black**. The sheet is a grayscale MASK; alpha is
   never consulted.
2. **`TextureResolver` knows three filename prefixes and rejects the rest with no
   error at all** (`texture_resolver.gd:176` — `facade_`/`slice_`/`slab_`, then
   `return false` → Tier.NONE → generic atlas). A `fracture_` category is one
   `elif`, listed in the order's §4 as work for when the art lands.
3. **A sheet is authored at 1:1 horizontally** (16 authored texels = 16 screen px;
   vertically ×20/16 NEAREST). §7.3's *"detail that dissolves at 1/16th linear"*
   warning applies to the **shard decals**, which are 256 → 16, and **not** to
   the sheets, which have no downsample to survive.

**The gate, proven red before it was trusted** (a green control first, since a
gate that rejects everything would pass a rejection-only test): off-centre origin,
alpha-only crack, non-grayscale, pre-squared, an unknown width, `decal_dent_glass_*`
(a tier glass cannot reach), and an unimported file — all rejected; all **54
shipped decals still PASS unchanged.** The origin check is the one that justifies
the new asset class: G-D21 offsets by `(impact − centre)`, so an off-centre
fracture displaces **every** crack in the game by a constant nobody can see.

⚠️ **The sheets have NO wiring check and the gate says so itself** — G-D21 is
unbuilt, so no constant names them. The shards' wiring check is already armed: the
day the three files exist, `--material glass` fails with `WIRING FAIL … 'glass' is
NOT in IMPACT_DECAL_MATERIALS`.

🔎 **Reference material the Director already collected:**
`REFERENCES/bullet-hole-transparent-glass-abstract-background-*.zip`,
`REFERENCES/Glass.png`, `REFERENCES/Glass.psd` (2026-08-02) — gathered a month
before this plan existed.

---

## 9. The window — MULTI-MATERIAL SLICES (G-D9)

⚠️ **This section was rewritten on 2026-08-30, the day it was written, and it
REVERSES its own first recommendation.** The first version recommended splitting a
face into several single-material slices keyed `(gu, face, level_start)`, and
rejected the multi-material slice on the grounds that it *"turns a field into a
query in dozens of call sites"*. **That claim was asserted without counting. It is
false, and the count is below.** Recorded rather than quietly edited, because a
plan that hides its own reversal teaches nobody anything.

### 9.1 What the Director's diagram specifies

**Source: `REFERENCES/WINDOWS.png`** (delivered 2026-08-30, alongside `SLICES.png`
and the rest of the architecture specs). ⚠️ **`REFERENCES/` is gitignored**
(`.gitignore:47`), so the diagram is **not versioned with this plan** — it can be
edited or replaced and this document's history will not show it. That is why it is
transcribed below rather than merely linked. The transcription is what the plan
stands on; the PNG stays the Director's own working copy.

A half-thickness glass window, built bottom-up:

```
   ┌──────────┐  brick cap          ← storey 2, upper level band
   │  glass   │                        storey 2, lower level band
   ├──────────┤
   │  glass   │  pure glass          ← storey 1, MONO-material
   ├──────────┤
   │  glass   │                        storey 0, upper level band
   └──────────┘  brick cap          ← storey 0, lower level band
```

> Director, 2026-08-30: *"São 3 storey do game empilhados (slices), que formam a
> parede completa."*

**Read off the diagram at full resolution — two of the three stacked storeys are
multi-material, one is not:** the top storey is a brick band over glass, the bottom
storey is glass over a brick band, and **the middle storey is pure glass** (the
diagram labels it `HALF ESPESSURA (1 SLICE) GLASS`, and the magenta
`MULTI MATERIAL SLICE` callout points only at the mixed one). So the capability is
needed for two of three bands, not all of them.

✅ **ANSWERED the same day — G-D10.** The reading was that the black mullion grid
falls on the geometry: horizontals at **storey boundaries**, verticals at **GU
boundaries**. The Director's ruling makes the question moot either way —
*"caixilhos de graça, ou nem precisam existir. Se for contínuo, está ótimo."* Take
the grid if the geometry produces it; a continuous pane is equally correct.
**G-ART owes no fifth decal family**, and muntins are never authored as art.

**The vocabulary, settled — and it settles a collision this project already
carried.** The `MATERIALS_MASTER_PLAN` records that *"the Director's 'slice' is one
storey of wall on one GU face; the code's `Slice` class is the whole face across
every storey."* The diagram resolves it in the code's favour:

| Diagram | Code | Note |
|---|---|---|
| one stacked piece ("slice") | a **level band of 8** inside a `Slice` | `LEVELS_PER_STOREY = 8` |
| the red box ("container / high wall") | the **`Slice`** itself | one face, every storey, `storey_count × 8` levels |
| — | `HighWallGroup` | ⚠️ **NOT the red box.** It is a bake-time grouping of edges **horizontally**. Reusing that name for the vertical stack would be a second collision |

**So no new container is needed.** The `Slice` already IS the red box. Only its
single `material` string has to become a band map.

### 9.2 The measurement that reversed the recommendation

Counted 2026-08-30 over non-test code, not estimated:

| Reader of a slice's material | Sites | Already holds the `Voxel`? |
|---|---|---|
| render — `damage_variant_material()` ×2 | 2 | **yes** |
| the `voxel_destroyed` signal | 1 | **yes** |
| the shot path — `agent_shot_controller` ×4, `weapon_bench_controller` ×2 | 6 | **yes** |
| the cook — `detonation_plan_builder` :1587 | 1 | **yes** |
| the cook — `detonation_plan_builder` :520 | 1 | no — whole-slice batch, needs per-voxel resolution inside |
| census / diagnostics — `room.gd` ×3 | 3 | no, and they genuinely want *"what is this wall made of"* |
| debug gallery | 2 | no |
| **TOTAL** | **16** | **9 already hold the voxel** |

**Nine of sixteen read the material off the slice only because `Voxel` has no
material of its own** — not because they want a property of the surface. For them
`material_at(level)` is a mechanical substitution.

**And the bake seam is already level-aware:**

```gdscript
func resolve(edge, face, voxel_xy, level: int = 0, column_in_run: int = -1)
_compute_facade_key(material_id, facade_id, column_in_run, level, dir)
```

`resolve()` already receives the level, and the facade key is already
`(material, facade, column, level, dir)` — **two materials on one face produce
distinct keys with no collision.** It simply asks `edge.material` instead of asking
per level: `baked_tile_lookup.gd:259` and `:415`.

### 9.3 The data shape

```
Slice.material                    stays — the BASE / dominant material
Slice.material_bands: Dictionary  SPARSE override, level → material
Slice.material_at(level)          the accessor
```

**Sparse on purpose:** the overwhelming majority of slices are single-material and
RAM is this project's constraint, not CPU (D42). A normal wall pays **zero bytes**.
`slice.material` keeps meaning *"what is this wall made of"*, which is exactly what
the three census sites want — they do not change.

### 9.4 ⚠️ Where the real cost is, and it is NOT the 16 reads

**The bake RUN.** `_group_edges_into_runs()` groups collinear edges sharing
material+facade **horizontally**, so a facade stays continuous across GUs — that is
what `column_in_run` is for, and it is why brick does not restart at every GU. A
multi-material slice cuts **vertically**. The two are orthogonal axes, so a run has
to become per **material band** rather than per edge;
`_edges_share_material_and_facade()` compares whole edges today.

This is the work. It is also the nastiest failure mode in the change: a wrong run
breaks nothing and throws no error — the texture simply restarts in the middle of
a wall. **It can only be caught by a capture**, which is why §11's rules apply here
too.

**Second gap, smaller, recorded now so it is not a discovery later:**
`JunctionResolver` builds a `JunctionColumn` from `edge_a.material` — one material
for the whole corner column. A multi-material edge would give that column the wrong
material over part of its height. Probably irrelevant for a window (windows rarely
reach a corner), but it is a known hole, not an unknown one.

### 9.5 What is still deferred

The **capability** is ratified here. The **authoring** — how a mapfile spells
"brick cap, glass, brick cap" — was deferred to the scenario applications; ⚠️
**that deferral is PARTIALLY LIFTED 2026-08-31** — the new `GLASS` test map
(§12) needs the authoring format now. §9.6 formalises it. ✅ **BUILT 2026-08-31.**

### 9.6 The authoring format (Director, 2026-08-31 — *"vamos usar o mecanismo do WINDOWS.png para criar as paredes"*)

A `panels` entry (M3-2b) gains an optional **`bands`** array — a sparse
level→material override on the same half-thickness face:

```json
{
  "gu": [x, y], "face": "SE", "storeys": 3, "start_storey": 0,
  "material": "glass",
  "bands": [
    { "levels": [0, 1],   "material": "brick" },
    { "levels": [22, 23], "material": "brick" }
  ]
}
```

- `material` is the BASE (the majority — glass, for a window). Any level not
  named by a band renders as the base.
- `bands` levels are **absolute within the panel's own extent** (0 …
  `storeys * LEVELS_PER_STOREY − 1`). `[0,1]` is the sill (brick cap at the
  bottom of the WINDOWS.png stack); `[22,23]` the head, for a 3-storey panel
  (24 levels). The three middle storeys are pure glass — exactly the diagram.
- A single 8×8×1 storey band can itself be split — that is the magenta
  `MULTI MATERIAL SLICE` callout: the sill storey is brick over glass, the head
  storey glass over brick.

**Pipeline — ✅ BUILT 2026-08-31 (commit pending). What actually landed:**

| Layer | Change as built |
|---|---|
| `map_compiler._compile_panel_bands()` | expands the sparse `bands` array into a dense `{rel_level: material}` dict on the panel instance, ONCE. `levels` accepted as `[lo,hi]` OR the `Vector2i` FileMapSource's JSON converter folds a 2-int array into |
| `edge_extractor._extract_panels` | `edge.material_bands = panel.material_bands.duplicate()` — panels are appended straight to `result["edges"]`, never rebuilt by the third pass, so nothing drops it |
| `Edge` / `Slice` | `material_bands: Dictionary` + `material_at(rel_level) -> String` + `has_material_bands()`. `rel_level` = `voxel.level − storey_level_base(start_storey)` — 0-based from the panel's own bottom, exactly the authoring space |
| `SliceGenerator._create_slice` | copies the band map onto the Slice (side-independent) |
| `voxel_renderer._render_slice` / `_process_dirty_slice_voxel` | per-voxel `vmat = slice.material_at(rel)` drives `damage_variant_material()`, the glass-layer routing gate (`vmat == "glass"`), and the diag. `_slice_top_glass_level()` anchors the G1 top sliver to the top GLASS row, below a brick head. `_slice_is_glassy()` (base OR any band) keeps the diag/geometry firing |
| `voxel_renderer._set_voxel_cell` | resolves the per-level material in RENDER space (`edge.material_at(level − storey_level_base(edge.start_storey))`) and passes it to the lookup as `material_override` — "" for every ordinary edge |
| `BakedTileLookup.resolve` / `_resolve_baked_sheet` / `_resolve_generic` | new trailing `material_override: String = ""`; when set it is the facade key's material component. The key was already `(material, facade, column, level, dir)` — two materials on one face, no collision |
| `room_builder._bake_textures` | one extra `wall_descriptor` per `(banded edge, band material)` so `_extract_unique_combos` / `_extract_combo_usage` see the combo and the compositor bakes the brick facade page. Verified: `[BAKE] Composed sheet brick|facade_brick` appears for the GLASS map (and does NOT on the pre-G-D9 checkout) |
| `GlassPaneGrouper._is_glass_slice()` | a slice is glass if base OR any band is glass — the GLASS map's 3 banded panels union into one `PANE_SLICE_22_10_SW` |
| ⚠️ `_group_edges_into_runs` — **NOT changed.** §9.4 anticipated a per-**material-band** run. It was not needed: the banded edges share their BASE material along the run, so they group naturally, and `column_in_run` continuity is exactly what the glass middle wants; the brick sill/head resolve against the (fully-swept) brick page folded through the same `column_in_run`, giving a continuous brick cap. §9.4's failure mode (a wrong run restarting a facade mid-wall) needs a run that spans two *different* base materials — those are already separate runs. If a future map places a banded window mid-run against a plain wall of a different base material and the brick cap misaligns, that is when the run split gets built, with its own capture. |

## 10. Task order

| Order | Task | Blocked by |
|---|---|---|
| 🟢 | **G1** — glass pane transparency via a `BackBufferCopy` container. **APPEARANCE signed off 2026-08-31** (calibration "painel 005"). **GEOMETRY reworked 2026-08-31** to the face-culling rule (main always / top on the top row / side on the frontmost column, both dim); awaiting a tuning verdict. Glass-block issues untouched. Vertical faces only — roofs / glazed floor zones stay opaque | — |
| 🟢 | **G2** — `pane_id`: `GlassPaneGrouper.assign()` at map load — union-find for panels (coplanar + adjacent along the face run axis), 4-connected flood fill for glass block cells (NOT per-authored-instance: PLAYGROUND's 3-wide block is three 1×1 declarations = one pane). Real-map verified (PLAYGROUND: 2 panel panes + 1 `PANE_BLOCK_0`). `Slice.pane_id`. **BUILT 2026-08-31** | — |
| 🟢 | **G7** — the round passes through a pane (G-D5): `EdgeRegistry.glass_edge_keys()`, `_walk_pellet_ray` records the crossing (deduped by pane) and continues, `agent_shot_controller` flattens crossings into picks. Real-map: `glass destroyed=1` AND `concrete dented=1` from one pistol shot. Blocks excluded (their cells are in `blocked_cells`, deferred). **BUILT 2026-08-31** | — |
| 🟢 | **G-MAP** — `maps/GLASS.map.json` **BUILT 2026-08-31**: big pane (authored gu x 10–15, y 9, SW, 3 storeys) in front of the agent, a WINDOWS.png `bands` wall (gu 19–21 — `bands` ignored until G-D9, renders as plain glass), a small 1-storey pane, a guard behind the big pane, a 3-wide glass block. Auto-registered via `FileMapSource`. `INFILTRAITOR_MAP=GLASS` boots it without touching the persisted cfg. Verified: pane_ids correct (one big pane, one small, one block, one bands wall), and a pistol shot goes `glass destroyed=1` + `concrete dented=1` through the big pane | — |
| 🟢 | **G-D9** — multi-material slices: `panels.bands` authoring (§9.6), `Slice.material_bands` + `material_at()`, the per-band bake page (extra `wall_descriptor`, NOT a run split — see §9.6), a lookup `material_override`. `GlassPaneGrouper` unions a banded panel by base-or-band glass. **BUILT 2026-08-31.** Acceptance: `glass_bands_wall_before/after_2026-08-31.png` (same-boot) — the WINDOWS.png wall gains a brick sill (rel 0-1) + head (rel 22-23) over a glass middle; `[BAKE] Composed sheet brick\|facade_brick` present on the GLASS map and absent pre-G-D9; `glass_transparency_selftest` test [7]; 39 selftests clean | — |
| 🟢 | **G-ART** — **the order and the gate are DONE 2026-09-01** ([`ART_ORDER_GLASS.md`](../ART_ORDER_GLASS.md); `check_decal.py` now carries per-material families + the fracture-sheet class, proven red on 7 modes with all 54 shipped decals unchanged). Five files asked for: two 1024×512 grayscale fracture sheets (tight/wide, G-D14) and three 256×256 shard decals. **What is left is the delivery** | — |
| 4 | **G5** — the CRACKED tier returns (G-D3): `crack_factor`, the pinned empty DENTED band, the blast crack radius | the art itself |
| 🟡 | **G3** — the break, per §5.1's REWRITTEN model. **Staged (Director "vamos seguir com G3", 2026-08-31):** **A** ✅ `GlassShatter` curve + arsenal selftest. **B** ✅ the roll in the shot path + region flood + G-D13 remnants + glass-VFX guard. **C** ✅ the grenade/cook path — `blast_glass_punch()`, panels out of the ring model, `_shatter_glass_panes()`, `VoxelRenderer.erase_glass_cell()` (see §5.1). **D** (open) G-D8's passage work: intact glass → the movement blocked-edge set (new split from vision's, per G-D7), broken glass → passage opens (`PassageQuery` → per-turn recompute) + detection +1 + light bump | G-MAP, G2, §5.1 |
| 🟡 | **G-VARIANT** — `glass_class` + tint (G-D16). **Staged 2026-09-01, mirroring G3's arc:** **V-A** ✅ the FAMILY SEAM — `GlassMaterials.is_glass()` replaces 25 bare `== "glass"` comparisons across render, geometry, occlusion, the guard phase, the shot path and the cook, pinned by new invariant **L2**. **V-B** the roster + the tint on screen (`glass_armored`, `glass_screen_{green,red,amber}`; the tint rides the glass atom's free BLUE channel — G-D19 reserves GREEN, and RGB are written identical today so B is spare). **V-C** the class behaviour (ARMORED's whole-pane break; INDESTRUCTIBLE stops the round — the one glass G-D5 does not apply to). **V-D** `pane_primed` (G-D15) + the per-placement `glass_class` tag in the mapfile | V-C needs Stage B's flood fixed (see §5.1) |
| 6 | **G4** — frame remnants: border ring, luck-driven survival, jagged half-voxel substrate. **G-D13 makes this a rule of G3, not a separate task** — it lands with G3 | G2, G-ART |
| 7 | **G6** — shards: BASE-coord store, floor decal, `SaveState` section (also holds `pane_primed`, G-D15) | G-ART |
| 8 | **G-D4** — the bullet web on shot neighbours | G5, G-ART |
| ⤴ | **`plastic`** (black backing material for screens, G-D17) + the paint-on-plastic layer + the screen-art pipeline — **`MATERIALS_MASTER_PLAN`, deferred.** A round DRILLS plastic (hole, no pass-through); fire MELTS it | MATERIALS |

**Deferred, with owners:** the window's full *reveal* geometry (§9, scenario
applications — the `bands` authoring itself is now G-D9, above) · shard noise
(sound milestone) · the see-through roll G-D7 (applications) · the agent crossing
a broken pane, and `PassageQuery` → `blocked_edges` (movement milestone) ·
`plastic` + screen art (`MATERIALS_MASTER_PLAN`).

---

## 11. Acceptance — what will and will not count

Per the project's standing evidence discipline, written before the work rather
than after:

- **A green selftest does not mean the feature fires on the real map.** Every one
  of G3, G4, G5 and G6 must be run on the **`GLASS` map's real panes** (§12) and
  the real counts read, not on a synthetic patch. The floor-dent path passed its
  selftest with 69 dents and produced zero on the real map; glass has exactly the
  same shape of exposure.
- **The transparency claim needs a capture**, hand-named so the rotation cannot
  eat it — `Screenshots/history/` with a non-`auto_` prefix, and a same-boot
  control, because a screenshot cannot tell *"did nothing"* from *"low contrast"*.
- **The cascade needs a cell probe**, not pixels: `INFILTRAITOR_CELL_PROBE=1`
  answers whether a voxel actually came back from the TileMapLayer.
- **`pane_shatter_punch` must be measured against the real arsenal**, the way
  `NEIGHBOUR_CASCADE_PUNCH` was pinned by a selftest that reads the shipped
  weapon JSONs — so a later balance edit fails the suite instead of silently
  turning a pistol into a pane-breaker.

⚠️ **The real-map bed is now the `GLASS` map (§12), not PLAYGROUND** — every G3 /
G4 / G5 / G6 run reads counts there.

---

## 12. The `GLASS` test map (Director, 2026-08-31)

> *"pra poder gerar esse mecanismo todo precisamos modificar o PLAYGROUND e
> colocar uma vidraça maior na frente do agente… Aliás o PLAYGROUND já está
> muito cheio, podemos criar um novo mapa GLASS pra testar vidro. Vamos usar o
> mecanismo descrito no diagrama WINDOWS.png para criar as paredes."*

A new mapfile `maps/glass.map.json`, registered in the map catalog, dedicated to
glass physics — PLAYGROUND stays as it is.

**What it needs (first pass — extend as the tasks land):**

1. **A big pane directly in front of the agent** — wider and taller than
   PLAYGROUND's 2-storey panels, so G-D12's *partial* break has room to read
   (part shatters, part holds). A single face, several GUs wide, 2–3 storeys.
2. **A WINDOWS.png wall** — a `panels` entry with `bands` (§9.6): brick sill,
   glass middle, brick head, over 3 storeys, half thickness. This is the piece
   that exercises the G-D9 multi-material-slice pipeline.
3. **A small pane** — 1 GU, 1 storey — for the binary (all-or-nothing) case.
4. **One guard behind the big pane** — the shot-through-glass path (G7) and the
   see-through roll (G-D7, later) both need an actor on the far side.
5. **A glass block** — carried over so block geometry keeps a home.
6. Later, as the variants land: a `glass_armored` pane, a `glass_screen_*`
   panel, and (when `plastic` exists) a plastic-backed screen.

**Acceptance for the map itself:** `INFILTRAITOR_GLASS_DIAG=1` prints the
expected `pane_id` set; a hand-named capture shows the big pane, the WINDOWS.png
wall and the small pane in one frame.
