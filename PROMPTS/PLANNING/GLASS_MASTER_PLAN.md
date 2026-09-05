# GLASS MASTER PLAN — the physics of glass

**Status:** 🟢 v1.31 — **G-D35 B-3 IS BUILT (2026-09-05): the blast craze art is
on the pane** (§16.9). Two granularities per G-D37 — `blast_fine` (210 cells per
tile) and `blast_coarse` (58), three variants each — drawn as a Voronoi mesh on a
**toroidal metric**, so it tiles by construction: no border is mirrored, blended
or fixed up afterwards, because there is no border.

**The whole runtime path lit up with no code change**, which is exactly what B-2's
stage gate existed to make true. Evidence:
`glass_craze_granularity_2026-09-05.png`.

⚠️ **B-2's split point was wrong and only the real table said so.**
`CRAZE_FINE_MIN = 0.5` against `[1.0, 0.80, 0.55, 0.30]` put THREE of four rings
on the fine sheet — half of G-D37's art almost never drawn, with every geometry
assertion green. Now 0.67, and [18] pins REACHABILITY beside direction.

⚠️ **The gate learned the class and LOST a constant doing it.** The ORIGIN rule is
skipped for a tile (a uniform field satisfies it trivially at −0.8 %, +0.4 % — a
check passing for reasons unrelated to what it checks) and a SEAM check replaces
it, thresholded against both sides: the shipped sheet scores **1.14 / 0.99**, a
page with the wrap removed scores **3.15 / 3.72**. And the aspect rule was never
"2:1" — it was always "the aspect must match the SPAN", which the manifest now
answers per sheet. **B-4 (the perforation) is next.**

⚠️ **The 42 shipped sheets came back byte-identical from `--all`** — hash-compared,
not assumed.

Earlier, v1.30 — **G-D35 B-2 IS BUILT: the craze FIELD is the
pane's own rectangle, tiled** (§16.8), wired end to end from B-1's trigger through
`WorldDelta.commit()` to a rotation replay. It is a second sprite MODE, not a
parameter: the quad stops being a page and becomes the pane, UV stops being the
sheet and becomes a lattice, and the page feather goes to zero because a field
ends at the frame. ⚠️ **The unknown §16.3 predicted was not the real one** — there
is no fold, a panel pane is coplanar by construction; the real one was the phase
ANCHOR. ⚠️ **And the blast demo cannot host a pixel gate: two identical runs
differ by 160 276 pixels.** A gate belongs on the crack demo, which measured 0.

Earlier, v1.29 — **§16.6 IS FIXED (2026-09-05), AND ITS DIAGNOSIS WAS
WRONG.** A PANEL pane's damage did not survive a rotation — 1152 cracked before a
flip, 0 after — and v1.28 wrote that down as a persistence bug: *"the fix is a
base-space key that carries the FACE."* **The key was right the whole time.** It
pointed at where the pane should have been, and the pane had not moved:
`PerspectiveMapper.layout_with_perspective()` rotates every other geometry key and
never rotated `panel_instances`, which is where every half-thickness element lives
— G-D9's windows included. One branch, and both symptoms close: `1593 of 1593`
damage records re-applied in E, S **and** W (was 441), and CRACK-02 S-3's crack
rebuild goes `0 of 1` → `1 of 1` on a single flip. §16.6.

**The Director ruled §16.4's two open questions (G-D36, G-D37):** a crazed pane
**still lets sight through, with a large penalty**, and the coarse craze is **its
own mesh**, similar to the fine one rather than the fine one rescaled.

Earlier, v1.28 — **G-D35 B-1 IS BUILT (2026-09-04): a pane the blast does
not take now CRAZES**, whole, with an intensity from its ring (§16.5). The
trigger comes before the art on purpose — G-D35's sheet is a centreless tiled
field, and drawing today's bullet page over a blast-crazed pane would be the
wrong art wired to a real trigger. ⚠️ **Nothing changes on screen yet, and two
measurements came out of building it:** §6.2's predicted new BFS was never needed
(ring 3 is already in `affected` at zero cost), and **576 of 1152 crazed voxels
would never have been persisted** — PACKAGE only walks the slices the blast
reached, a craze takes the whole pane.

Earlier, v1.27 — **CRACK-05 IS CLOSED AND RULED ON (2026-09-04).** The
armoured class shipped, the Director sized it by looking (**10 × 5** voxels for
the bullet calibre, **16 × 8** for the rifle — G-D14's own split, *"3 versões
diferentes pra cada calibre"*) and softened its core to 64 % opaque so a little
of the pane shows through. ⚠️ **Its geometry is PAGE-RELATIVE, not voxel-relative,
and §15.5a is why** — it is the one sheet class with no opening to be anchored to.
**The last piece of glass is now named and staged: G-D35, the blast craze family
(§16)** — no centre, two axes (destruction × granularity), perforated per voxel,
and TILEABLE, which is what makes it cheap where the bullet classes were not.

Earlier, v1.26 — **CRACK-05 CLOSED §14.5's TWO OPEN ITEMS (2026-09-04).**
G-D28's **`armored`** class is on screen: a pane that stopped the round wears an
OPAQUE CRUSHED-WHITE CORE instead of a bullet page with a bore over glass nothing
pierced — the defect `ART_ORDER_GLASS_FRACTURE_CLASSES.md` §1 called that order's
priority. And the **cook names its hole**: the blast proposes an opening on the
`WorldDelta` and `commit()` claims it, so a grenade's hole is a picked member of
the family and survives a perspective flip. ⚠️ **That second one is correct and
LATENT under the shipped balance, measured rather than assumed** — a won roll at
ring 0 or 1 floods 42 / 22 voxels against a 48 × 24 pane, so the pane goes WHOLE
and there is no rim to shape; see §15.2, which also names where the cook's glass
work belongs next (§6.2's crack near a blast it survives).

Earlier, v1.25 — **CRACK-04 IS BUILT AND WIRED: the hole is an OPENING from a
12-member catalogue (G-D34), the decal is generated FROM it, and the two are the
same polygon.** The crack left the voxel (G-D27), is cut by the live glass tilemap
(G-D30), survives a flip (S-3), and its rim is shards (G-D31). CRACK-04 replaced
the per-cell wedge with a named shape, wired it to the shot path on a BASE-space
key, regenerated the art as 12 × 3 sheets and retired the round-hole pair.

**What CRACK-04 closed that nothing else could have:** the shard rim had **never
once reached the screen** since CRACK-03 — `refresh_glass_rims()` reported 12
cells cut and the tilemap held 0, because the CRACKED ring a hole always crazes
re-rendered those very cells. Every gate counted swaps ISSUED. See §14.

Earlier, v1.20 — **G-ART IS DELIVERED (2026-09-02). All five files are on
disk, gated green, and PROCEDURAL** — `tools/persistent/gen_fracture_sheet.py`
and `gen_shard_decal.py` author them, so the art is a parameter set rather than
an authoring night, and it is reproducible from a seed. `--material glass`
measures: `tight` centroid (−0.2, −0.1) vox / reach 11×12 / 2.61 % ink, `wide`
(−0.5, +0.2) vox / **reach 32×16** (G-D23's guarantee, exactly) / 6.84 %, and the
three shards at 25.7 / 21.5 / 25.8 % coverage.

**Procedural rather than §7.3's Stable Diffusion route, and the reason is
measurable:** the sheet must radiate from the EXACT page centre (G-D21) and
`wide` must carry ink to the edges (G-D23). Generated, those are a parameter and
a measurement; prompted, they are a lottery sampled until the gate agrees. Across
six seeds of each width every centroid landed inside ±1.6 voxels and every `wide`
hit 32/16 — 12 for 12. SD's realism is real and the shards were its natural
territory, but it aims at neither of those two numbers.

**§4 of the order is wired (steps 2, 4, 5, 6):** `TextureResolver` has a
`fracture_` category on the facade's own 64×32 contract, `GlassMaterials.FRACTURE_WIDTHS`
names the two sheets, and `check_decal.py` gained the sheet wiring check §3 said
was missing — proven red on both of its branches. ⚠️ **Wired is not used:** G-D21
is unbuilt, so nothing requests a sheet yet, and the gate prints that on its own
line rather than letting two green wiring lines imply a working feature.

✅ **BOTH §8 FINDINGS RESOLVED BY DIRECTOR RULING (2026-09-02) — see §8.1 / §8.2
for the full text. In short:**

1. **§8.1 → glass reaches CRACKED by the route it already has.**
   `ShotPunchTable.damage_state_for()` returns CRACKED for a sub-breach glass hit
   today; CRACK-01's event sets it directly on the surviving ring. `crack_factor`
   stays **0.0** — the blast crack-PROBABILITY path (which is what would drag in
   `decal_crack_glass_*` via [12]) is deliberately not the route. No selftest
   edit; `glass_crack_selftest` is the new guard.
2. **§8.2 → G-D21 is amended to WORLD-SPACE sampling.** The fracture is a plain
   texture sampled at `(v_glass_world − impact)`, ~2 MB, 0 atoms minted — not a
   reanchored atom page (36–144 MB). Per-pane multiplicity rides a tiny
   crack-groups data texture, not a `uniform vec3[]` (which prints a boot error
   here — V-B). The `_compute_facade_key()` offset and its 64/32 mirror-fold are
   not used at all.

Also 2026-09-02: **G-D25** (a big shard is a cut silhouette on whole voxels, not
a texture) and the Director's ratification that the shard decal's shimmering
white noise at 16×20 px **is the expected read**, not a shortfall.

Earlier, v1.19 — **G-VARIANT IS COMPLETE. V-D BUILT (2026-09-01):**
`panels[].glass_class` (a screen is a control interface or a TV *per placement*)
rides all the way to `Slice.glass_class`, and **G-D15's pierce-and-prime works
end to end**. Proved in ONE boot on the real map: shot 1 `PIERCED but held (punch
2.16) — primed` with the pane still standing and the round continuing to the
concrete behind it; shot 2 `was PRIMED — this hit auto-shatters it` →
`WHOLE PANE flooded=122` at punch **2.01**, lower than the first and far below
anything that could have taken the pane on its own. §5.4d.

⚠️ V-D also had to make **G-D3 structural**: glass never DENTS. That was true
only because `DESTROY_MIN["glass"]` and `PUNCH_DENT_MIN` were both 0.30, and
raising the armoured breach to 1.50 would have opened a band every common round
lands in. §6.1 asked for exactly this pin.

Earlier, v1.18 — **G-VARIANT V-C BUILT (2026-09-01): the behaviour behind
the colours.** ARMORED has no region — a won roll takes the pane WHOLE (G-D15) —
and INDESTRUCTIBLE caps at CRACKED and **STOPS THE ROUND**, the one glass G-D5
does not apply to. Real map, three shots, one weapon: armoured `glass_punch 3.03
WHOLE PANE flooded=119`, 128 of 128 destroyed; the red screen `cracked=1
destroyed=0` **with no concrete line at all** where plain glass puts `concrete:s1
destroyed=2` behind it; the plain control unchanged at `flooded=1071`. Captures
`glass_armored_whole_pane_` / `glass_screen_stops_round_2026-09-01.png`. §5.4c.

Earlier, v1.17 — **G-VARIANT V-B BUILT (2026-09-01): the roster is real and
the tints are on screen.** `glass_armored` (purple) and
`glass_screen_{green,red,amber}` are registered materials with their own
resistance rows, and **they cost ZERO new art** — the family shares every pixel
of `glass`'s (G-D16). The tint rides the pane atom's free BLUE channel into a
per-class shader uniform, so one container, one shader and one TileMapLayer per
level still serve all five: what multiplies is the ATOM table (80 atoms, composed
once at load), never draw submission. Capture:
`glass_variants_2026-09-01.png`. §5.4b has the detail.

Earlier, v1.16 — **G-VARIANT V-A BUILT (2026-09-01): the glass FAMILY SEAM.** `GlassMaterials.is_glass()` replaces 25 bare `== "glass"` comparisons
across rendering, geometry, occlusion, the guard phase, the shot path and the
cook — G-D16 makes glass a family, and against a literal comparison every new
member would be a silently OPAQUE wall that renders, occludes and stops rounds
with no error anywhere. Pinned by new invariant **L2 `glass-is-a-family`**, which
reads the roster out of the seam module rather than duplicating it.

✅ **AND V-A's verification found — then FIXED — G3 Stage B being INERT ON THE
REAL MAP (§5.1).** A won sniper roll on the GLASS map's big pane flooded **zero**
voxels: the shot's own local hole surrounded the origin and the BFS could only
step onto surviving glass, so `radius=23` over `lattice=1143` died at step one.
Pre-existing, not a V-A regression (before/after on the same binary were
identical). Now `flooded=1071`, and **`GlassFall` fires on the real shot path for
the first time** — it sits downstream of `if n > 0`. Red-before-green in
selftest [14], which punches the hole BEFORE rolling the way the real shot does.

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
Next: **G3**. G-ART, G5, G4, G6, G-D4, G-VARIANT, `plastic` unbuilt. *(G3,
G-VARIANT and G-ART have all since landed — see the status block at the top of
this file. G5, G4, G6, G-D4 and `plastic` are still unbuilt. §8.1 and §8.2 were
resolved by Director ruling on 2026-09-02 and **CRACK-01** is the build that
lands the crack — G5 folds into it.)*

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
| **G-D19** | **A CRACKED GLASS VOXEL IS HALF SEE-THROUGH — AND THAT IS NOT AN ALPHA.** *"Com a rachadura nos voxels eles naturalmente vão perder a visibilidade total. Vamos diminuir pra 50% naquele voxel de vidro que tiver algum decal. Mas o decal em si já vai ter a própria opacidade na hora do bake, então precisamos fazer essa sobreposição dos elementos de maneira consciente."* The two quantities are DIFFERENT CHANNELS and must never be multiplied into one: the atom's **alpha is COVERAGE** (is there glass here — the silhouette B3 clamps a decal to), while see-through-ness is how much of `behind` survives the modulate in `glass_apply()`. Fold the 50% into the decal's alpha and it lands in `cover`: the voxel gets HALF A SILHOUETTE and partly vanishes instead of frosting over. So the decal composites into the atom exactly as it does today (alpha = coverage, B3 unchanged), and the 50% rides a SEPARATE per-voxel damage term the shader applies to the background contribution — `lit = mix(lit, frosted_body, damage)` | ⛔ **RETRACTED 2026-09-02 BY THE DIRECTOR HIMSELF — see G-D26.** Two builds tried to keep it and both failed on the same frame; the reason turned out to be the premise, not the tuning |
| **G-D26** | **A CRACKED VOXEL'S TRANSPARENCY IS UNTOUCHED — THE CRACK IS LIGHT ADDED ON TOP. ⛔ This RETRACTS G-D19.** *(Director, 2026-09-02, correcting his own earlier ruling: "Eu estava errado, a gente não pode considerar o voxel todo como 50% menos transparente. Isso automaticamente cria uma 'moldura' porque os voxels ao lado estarão com 100% da opacidade planejada. Nós precisamos que a rachadura apareça como algo a mais por cima do voxel, sem alterar a transparência dele. Tem que ser igual aos demais. Provavelmente um mecanismo de adição, que soma as áreas brancas do decal/facade e não toca no resto.")* **The argument generalises past the two builds it kills.** Build 1 made the drop FLAT over the crack radius and it read as *"praticamente um bloco que parece outro material no meio do vidro"*; build 2 made it DENSITY-DRIVEN so the silhouette became the fracture's, which fixed the rectangle and still left the wrong thing in place. The Director's point is that **any** per-voxel change to transparency FRAMES that voxel, because transparency is read continuously across a pane and the untouched neighbour draws the cell boundary for you — a moldura. So the crack touches neither `cover` nor `glass_apply()`'s modulate; it is `lit + crack_colour · crack · dim`, the same pure ADD G1's own sheen already uses. It is the physically honest one too: a fracture SCATTERS light, it does not paint over what is behind it, and you still see through a cracked pane. Pinned by `glass_crack_selftest` — the shader may declare no crack uniform that modulates (`frost` / `see_through` / `opacity`), and the source must still read `lit + glass_crack_add_color`, so the retracted design cannot come back under a new name | ✅ Ratified 2026-09-02, retracts G-D19 |
| **G-D20** | ⛔ **SUPERSEDED SAME DAY BY G-D21** — the mosaic's job (event-anchored, not structure-anchored) is right, but assembling it from edge-matched tiles is doing by hand what `_compute_facade_key()`'s offset already does. Kept for the argument, which G-D21 inherits: **PANE FRACTURE IS EVENT-ANCHORED, NOT STRUCTURE-ANCHORED.** *"Uma outra possibilidade seria fazer mosaicos procedurais usando partes de rachaduras similares que se conectam. Isso facilita porque o furo tem que ser posicionado sobre o voxel que o tiro acertou, e não aonde a textura baked fica."* The Director's argument is decisive and it kills the earlier proposal: a facade sheet is **structure-anchored** (`texture_anchor` = the component's NW corner, deliberately static so the pattern does not swim), while a fracture is **event-anchored** — its centre is wherever the round landed, different every shot. A baked sheet would put the radial centre at a fixed spot on the pane no matter where you hit it. A tile set whose edges connect, assembled outward from the impact voxel, is event-anchored by construction, stays inside the existing per-voxel decal path (no new bake axis, no new anchor unit), and is still gated by `check_decal.py` | ✅ Ratified 2026-09-01 |
| **G-D22** | *(id deliberately skipped — "G-D22" sitting next to the older **D22** decision that G-D3 amends is a collision waiting to be misread. Same reasoning DIRECTION_GLOSSARY §10 applies to names.)* | — |
| **G-D21** | **THE CRACK IS A FACADE SHEET RE-ANCHORED ONTO THE IMPACT — supersedes G-D20's tile mosaic.** *"essa ideia de fazer a grade e montar o mosaico, me parece que é essencialmente o que o baking system já faz […] gerar uma facade bem maior que as convencionais, com o furo baked no centro. E na hora que o tiro acerta a janela, ela tem margem pra 'sangrar' e ser reposicionada dentro da janela, cobrindo o voxel que foi acertado."* Correct, and it reduces to a SUBTRACTION: `_compute_facade_key()` already keys a voxel by `(column_in_run, level)` relative to the run's own origin, so "reposition the sheet" is offsetting those two numbers by (impact − sheet centre). No new mechanism, no new anchor unit, and — unlike a per-event mosaic — **the atoms are all composed once at load**, because the crack ART is fixed and only the OFFSET moves. A shot changes which atom each voxel picks; it mints nothing | ✅ Ratified 2026-09-01 · ⚠️ **AMENDED 2026-09-02 (§8.2): the mechanism is WORLD-SPACE sampling, not the `_compute_facade_key()` atom offset.** The "reduces to a subtraction" insight survives verbatim — it is now a subtraction inside `texture(fracture, v_glass_world − impact)` in the glass shader, ~2 MB and 0 atoms, because glass never rides the baked wall path. "Mints nothing" survives; "composed once at load" becomes "not composed at all". CRACK-01 §B |
| **G-D23** | **NO MIRROR FOR THE CRACK FAMILY, AND A PANE HAS A MAXIMUM SIZE.** *"Vamos com a 3, tira o espelho dessa família. E aí convencionamos que toda vidraça vai ter um tamanho máximo. Que é o padrão real mesmo, nenhuma janela é infinita. Precisando, usa-se um frame divisório e começa outra vidraça."* The crack sheet clamps at its edge instead of mirroring, so beyond it there is simply NO crack — the physically right answer, and the one that cannot invent a second false fracture. The maximum pane is then DERIVED from the sheet rather than invented: **64 × 32 voxels = 8 GU × 4 storeys**, which makes *"a centred hit can crack the whole pane"* a guarantee. maps/GLASS.map.json's big pane (6 GU × 3 storeys) already fits. Anything larger is authored as two panes with a divider — a **NON-GLASS panel at the middle GU, or a gap**. ⚠️ A G-D9 `bands` entry does NOT split a pane (measured — see below); a banded window is still base-glass and the union-find joins it to its neighbours anyway | ✅ Ratified 2026-09-01 |
| **G-D24** | **WHERE TWO FRACTURES CROSS, THE GLASS FALLS OUT.** *"Realisticamente falando, um segundo tiro iria quebrar regiões com cruzamentos de rachaduras, então destruir os voxels que se encontram também é uma opção."* A voxel already carrying a crack, reached by a SECOND fracture, becomes DESTROYED. This replaces the "nearest impact wins" tiebreak proposed a turn earlier and is better on every axis: physically right (crossed cracks drop the piece), free (DESTROYED is what the engine does natively — no per-voxel crack-source int, no compositing of two sheets ever), and it gives a second shot a real mechanical identity instead of a cosmetic one — the first shot crazes, the second opens a hole along the intersection. The freed voxels then fall and pile through G-D16a like any other break | ✅ Ratified 2026-09-01 |
| **G-D25** | **A BIG SHARD IS A CUT SILHOUETTE ON WHOLE VOXELS, NOT A TEXTURE.** *(Director, 2026-09-02: "podem ter cacos maiores porém, com o tamanho de um voxel ou até mais: uma união de 2, 3, 4 voxels, em formatos diferentes, que nem precisam de textura específica, mas sim um shape recortado, nos moldes que usamos para fazer os voxels dented de teto, usando um alpha pra criar a máscara no voxel inteiro.")* The `shard` DECAL (G-D16b, delivered 2026-09-02) stays exactly what it is and the Director ratified its read the same day — **a shimmering white noise is the expected result at 16 × 20 px, not a shortfall**; it is the fine debris. What it cannot be is a big piece, because a decal is a mark ON a face and a large shard has a SILHOUETTE that is not the voxel's. So the big shards are a second, separate class: **an alpha mask cutting the whole voxel, the same mechanism as the DENTED CEILING voxel** (the Director's diagram — alpha bottom/top carves the cube's own outline rather than painting on it), spanning **1, 2, 3 or 4 voxels** in several shapes. **No per-shape texture:** the piece takes the material's ordinary glass surface and only its OUTLINE is authored, which is why the shape count is cheap. Build work belongs to G6 and is UNBUILT | ✅ Ratified 2026-09-02 · unbuilt |
| **G-D15** | **ARMORED GLASS (`glass_armored`, purple) — resists common shots; when breached, usually shatters entirely at once, leaving many individual shards.** ⚠️ **Special rifle case:** a rifle round may pierce a SINGLE voxel without shattering (treated as a weak hit) — this PRIMES the pane, and the next shot of ANY type auto-shatters the whole thing. `pane_primed` is a per-pane flag, checkpoint-scoped | ✅ Ratified 2026-08-31 · build after this doc is signed off |
| **G-D16** | **Glass is a family of tinted behaviour classes, not new geometry.** All variants share G1's rendering and differ only in a tint (`base_color`) and a `glass_class`: `glass` (blue, BREAKABLE) · `glass_armored` (purple, ARMORED, G-D15) · `glass_screen_{green,red,amber}` (dark terminal tone) which is **INDESTRUCTIBLE** (control interfaces — takes a crack decal, never breaks, and STOPS the round: *"trinca mas o tiro para"*) or **BREAKABLE** (TVs, circuits, news panels) per placement | ✅ Ratified 2026-08-31 |
| **G-D17** | **A screen is a glass voxel over a BLACK PLASTIC voxel.** *"O voxel de vidro fica na frente de voxels pretos de PLÁSTICO (a implementar — fura [não atravessa] ou derrete), de forma que nesses voxels pretos vamos pintar as imagens e textos posteriormente, e o vidro vai criar o efeito de brilho por cima."* New material **`plastic`** (black): a round DRILLS it (a hole, but the round does NOT pass through — unlike glass) or fire MELTS it. Images/text painted onto the plastic later; the glass in front adds the G1 sheen. Belongs in `MATERIALS_MASTER_PLAN` | ✅ Ratified 2026-08-31 · `plastic` + the paint layer are deferred |
| **G-D18** | **Glass does not occlude.** *(Director, 2026-08-31, on the G-D9 capture: "tem algum problema com a oclusão. Podemos considerar não fazer em materiais de vidro.")* A glass pane is see-through by construction (G-D1) — the agent behind it is already visible, so ghosting it reveals nothing, and because glass renders on its own `_glass_layers` (which `apply_occlusion()` never erases) the wireframe drew its lines and ghost-band fill over a still-solid pane. `OcclusionSet` now filters out any slice whose BASE material is glass (policy O7, `_group_slices_by_edge`): no trigger, no ring stop, no wireframe. A mostly-opaque wall with a small glass viewport (base ≠ glass) still occludes. Guard-through-glass vision is G-D7, a separate roll | ✅ **BUILT 2026-08-31** |
| **G-D27** | **THE CRACK IS A SPRITE OVER THE PANE, NOT SOMETHING THE VOXEL SHADER DRAWS. ⛔ This replaces G-D21's MECHANISM (the art and the event survive; only the renderer changes).** *(Director, 2026-09-02: "talvez fosse melhor colocar um sprite em alpha, só com a parte branca das rachaduras, sobre a vidraça deixando o buraco sem voxels no centro. Porque no fim do dia a gente quer que os voxels atrás da rachadura sejam idênticos aos outros. E de quebra a gente resolve o problema da rotação e da adição de mais buracos, porque os adesivos se somam sem depender do atlas de voxels.")* **Why the additive fix (G-D26) was still not enough:** a crack drawn BY the voxel shader inherits every per-voxel property whether it wants to or not — the atom's `dim` (1.0 / 0.78 / 0.60 by face plane), the coverage alpha `cover` the whole fragment is blended at, and the quad seams themselves. Additive or not, it is still the voxel's. Only leaving the voxel reaches *"idênticos aos outros"*. **What it buys, all four measurable:** the glass behind is untouched by construction; a crack becomes a node with a position, so a perspective rebuild recreates it from a base-coord registry instead of losing a renderer-side plane; N impacts are N sprites that alpha-composite, so the 16-group cap, the per-cell group plane and the RGBAF strip all delete; and it REMOVES a `texture()` + branch from every glass fragment on the map. **The one real cost, named before building:** a sprite is a rectangle and a pane is not, so a crack near a frame would bleed over whatever is beside it. The fix reuses the wall-face inverse CRACK-01-D built and `glass_crack_selftest` [10] pinned — the pane is a rect in `(run, level)`, so the sprite discards fragments outside its run/level bounds. That basis changes job rather than being thrown away | ✅ Ratified 2026-09-02 · **BUILT 2026-09-02, §13 stages S-1..S-3.** Every one of the four promised gains is real: the glass behind is untouched by construction, a crack is a node a flip can rebuild (S-3, 5853 of 5855 pixels), the 16-group cap and the plane are deleted, and the per-fragment read is gone. ⚠️ The fifth thing it was expected to buy — a measurable frame win — is NOT there: idle `GLASS` reads 6.40 ms on both binaries (§13.5) |
| **G-D28** | **FOUR DECAL CLASSES, AND `armored` HAS A CENTRE TOO.** *(Director, 2026-09-02, correcting the reading of his own reference set: "o tiro a prova de balas não é uniforme, ele tem um centro assim".)* The `REFERENCES/Vidro` set resolves into four distinct vocabularies, and the distinguishing feature is the CENTRE, not the spread: `bullet_tight` (small empty bore · sparse · a few long runners), `bullet_wide` (empty bore, irregular outline · radials + concentric arcs), **`armored`** (an OPAQUE crushed-white core — pulverised glass, never a void — dense radial needles and a wider secondary craze field, and no through-passage: *"estilhaça mas não rompe"*), and `blast` (no centre at all · spread crazing, the shockwave case). They map onto triggers that already exist — `WeaponDef.blowout` splits the two bullet classes (G-D14), `glass_armored` / INDESTRUCTIBLE screens take `armored` (G-D15/G-D16), and the cook path takes `blast`. ✅ **`armored` BUILT 2026-09-04 (CRACK-05)** — three procedural sheets whose centre is an OPAQUE CRUSHED CORE, selected by `GlassCrack.sheet_id_for()` off the pane’s MATERIAL/CLASS and never off the weapon, on a 24 × 12 voxel page. ⚠️ It is a sheet id and **deliberately NOT a member of `GlassOpening.FAMILY`**: a member is pickable by `pick()` and cuttable by `refresh_glass_rims()`, and armoured glass is the one pane that may never lose a voxel (G-D15). 🟡 `blast_*` stays unbuilt — §6.2, its only caller, is unbuilt | ✅ Ratified 2026-09-02 · `armored` BUILT 2026-09-04 |
| **G-D36** | **A CRAZED PANE STILL LETS SIGHT THROUGH — WITH A LARGE PENALTY.** *(Director, 2026-09-05, answering §16.4: "vidro rachado ainda permite a visão, mas com uma penalidade grande.")* This is the `LIGHT_MASTER_PLAN` split doing its job: the pane keeps TRANSMITTING (G1's blend is untouched, the agent and the guard still see each other's side), and what degrades is TACTICAL visibility — the detection term through a crazed pane, not the pixels. ⚠️ **It is a penalty, never a block**, which is the whole point: a binary "craze = opaque" would let one grenade delete a guard's sightline and turn the craze into a smoke wall, which is not what glass does. The magnitude is a balance number and belongs with G-D8's detection work, not with the art | ✅ Ratified 2026-09-05 |
| **G-D37** | **THE COARSE CRAZE IS ITS OWN MESH, SIMILAR TO THE FINE ONE — NOT THE FINE ONE RESCALED.** *(Director, 2026-09-05, answering §16.4: "o rachado mais grosso precisa de uma malha diferente, mas pode ser parecida.")* §16.4 offered "a different mesh or the same one at a bigger scale" and noted the second was nearly free; the Director took the first, and the reason is visible in the reference photos — a coarse craze is not a fine craze zoomed in, its polygons are fewer AND blockier, and the line weight does not grow with them. **What "parecida" buys is that it is one generator with a second parameter set**, not a second vocabulary: same Voronoi body, same wrapping seed rule, same stroke, different cell count. ⚠️ **The count of steps is TWO as a floor** (fine + coarse), which is the minimum reading of a ruling phrased about "o mais grosso"; a third middle step is the same generator a third time and stays the Director's, to be decided by looking at B-3's output rather than in advance | ✅ Ratified 2026-09-05 |
| **G-D35** | **THE BLAST FAMILY IS A TILEABLE CRAZE MESH ON TWO AXES, PERFORATED PER VOXEL.** *(Director, 2026-09-04, with two references of shattered tempered glass: "as explosões ou vão destruir a vidraça toda, ou vão deixar rachado com maior ou menor intensidade, dependendo da distância […] conseguimos criar padrões mais e menos destruídos (usando o mesmo mecanismo de cortar as bordas dos voxels nas beiradas), e mais e menos rachados (granularidade) […] queremos que alguns decals sejam perfurados aleatoriamente em alguns voxels […] como são mais regulares, esses tipos de rachadura podem ser espelhados/repetidos com o método de azulejos, só mudando os buracos de lugar."* Four things follow, and each one is a departure from the bullet classes rather than a variation on them. **(1) NO CENTRE and no impact** — this is G-D29's field, so it is not radial and has no origin to be anchored to; the sheet is a MESH of small polygons, the read of the reference photos. **(2) TWO AXES, not one intensity dial** — *destruction* (how much of the pane is gone, expressed through the opening/shard-rim mechanism already built) and *granularity* (how fine the craze mesh is), and distance drives them together. **(3) PERFORATION IS PER VOXEL AND RANDOM**, not part of the art: the sheet is uniform, and individual voxels are punched through it. **(4) IT TILES.** A centred sheet cannot repeat; a uniform mesh can, so one page mirrored/repeated covers a whole pane and the variation comes from moving the HOLES, not from more art. ⚠️ This is what makes the class cheap where the bullet classes were expensive — and it is also why `SPAN_RATIO`, the page centre and the origin gate in `check_decal.py` all fail to apply to it. 🔒 The reference photos are read for VOCABULARY only; delivery stays procedural (D57, and the same discipline §8's watermarked comps already imposed) | ✅ Ratified 2026-09-04 · UNBUILT |
| **G-D29** | **`blast` IS 3 PATTERNS × H/V FLIP, HASHED PER PANEL.** *(Director, 2026-09-02: "vamos usar um conjunto de padrões nos painéis, digamos 3, que podem ser escolhidos aleatoriamente e flipados vertical e horizontal. Assim teremos uma variação legal, sem consumir quase nada a mais de memória.")* Three textures, twelve apparent variants. The choice is NOT new machinery: it comes from the B4 FNV-1a the destruction stack already uses (`FacadeSampler._fnv1a_hash` over `pane_id` + panel index), which makes it deterministic and replay-safe by the same rule as every other per-cell choice in the project — and the same hash yields the two flip bits for free. This is also the answer to *"stretch one sprite / tile a field / scatter several"*: none of the three; a small pool placed per panel | ✅ Ratified 2026-09-02 |
| **G-D34** | **THE HOLE IS A KNOWN OPENING FROM A FAMILY, AND THE DECAL IS GENERATED FROM IT.** *(Director, 2026-09-04, in two steps. First "o decal é o dono da forma"; then, watching me start to flood-fill the sheets' voids to recover that shape: "vamos usar formatos simples internos conhecidos […] Criamos uma família de aberturas para serem escolhidas. Os decals se adaptam a esses formatos internos, podendo variar completamente do buraco para fora. Dessa forma já sabemos como construir o buraco sempre, independente de como vai ser o decal.")* An OPENING is a closed polygon in the pane's (run, level) space, voxels, centred on the struck cell: a cell inside is gone, a cell the boundary CROSSES keeps only the glass outside it (the intrusion into the neighbours' borders), a cell outside is untouched. **12 members** — four regular he had already ruled on, three large, four irregular *("algumas mais esquisitas, com um chunk grande faltando, angulos irregulares")* and one elongated. The decal's inner void is the SAME polygon, cut at runtime from a rasterised mask, so 12 openings × 2 sheets never becomes 24 hand-matched files. ⚠️ `MIN_VALLEY = 0.708`: an opening must swallow the cell it is centred on, or it asks to keep four corners of a voxel destruction removed whole. ⚠️ The pick is B4 FNV-1a on a BASE-space key (the room owns the conversion), and so is the sheet VARIANT, salted apart. ⛔ **This supersedes G-D32** — irregularity comes from the opening's own polygon, not from hashing each shard — and **resolves G-D33 as a consequence rather than a ruling**: the sheet's void is `hint_default_black`, so a crack with no hole binds nothing and keeps its centre | ✅ Ratified + **BUILT AND WIRED 2026-09-04** (§14) |
| **G-D33** | ✅ **ANSWERED BY G-D34's WIRING, not by a ruling** — the sheet's opening mask defaults to black, so a crack with no hole under it binds none and draws its whole centre. The rule it proposed holds; nobody had to maintain a case list for it. Original entry: 🟡 **PROPOSED, NOT RULED — the sheet stops drawing the bore, and the voxel becomes the master.** *(Claude's recommendation, 2026-09-02, asked for.)* The bore is GEOMETRY now: the rim IS the hole's edge, four shards with four hashed shapes. A sheet that still draws a crush rim means **two authorities describing one feature**, and after G-D32 they cannot be reconciled by authoring — the voxel side is drawn at random, so no fixed art can match it. What is left for the sheet is what the voxel lattice can never do: the fine radial runners and the craze field, at sub-voxel scale. **Three things follow.** §13.4's measured mismatch closes in the same pass (with no centre to draw, *"sparse with a few long runners"* becomes the whole brief and the dense even field goes by construction, not by calibration). The rule is one line rather than a case list: **the sheet draws a centre exactly when the geometry has no hole to show** — `tight`/`wide` no, `armored` and INDESTRUCTIBLE screens yes, because the round stopped and no voxel was removed, so the crushed-white core is the only thing that can say so. And G-D30's cut currently eats the sheet's bore, its brightest part; with no bore there is almost nothing left to cut and the two mechanisms stop competing for the same pixel. **Priority it implies:** `armored` before the `tight` redraw — the only piece that fixes something wrong on screen today, and the only class whose vocabulary does not depend on the density question. **What it says NOT to do:** more shape variants, per-shape art, or tuning `crack_strength` — every advance on this track came from REMOVING an authority, never from adding one | 🟡 Proposed 2026-09-02 · awaiting the Director |
| **G-D32** | ⛔ **SUPERSEDED BY G-D34, UNBUILT.** Under an opening the silhouette is stated outright, so per-shard hashing is not what makes it irregular — the polygon is. Original entry: **THE FOUR RIM SHAPES ARE ALL FOUR, HASHED PER SHARD — NOT ONE CHOSEN.** *(Director, 2026-09-02, on the rendered options: "gostei muito dessas 4 opções que você mostrou. Se a gente puder randomizar todas elas para cada pedaço do buraco, melhor ainda.")* The four candidates — **A** a deep spike into the hole, **B** the same spike recessed half a voxel, **C** a V notch that keeps the two corners, **D** a 45° chamfer — stop being a menu and become a POOL: each of a hole's cut cells draws its own. This also retires the "borda ligeiramente irregular" he had ruled *preciosismo*, because the draw IS the irregularity, at no extra authoring. ⚠️ **IT MUST BE THE B4 FNV-1a, NEVER `randf()`** — the shard set is rebuilt on a perspective flip (S-3) and on a load, so an RNG would reshuffle a hole's shape every time the camera turned, which is the exact failure S-3 exists to prevent. Same rule G-D29 already uses for the `blast` patterns, for the same reason. ⏳ **One sub-question open, and it is plumbing rather than design:** the hash key must be in BASE coordinates or the shapes still reshuffle on a flip — a view-space cell is renumbered by the rotation — and the renderer has no base-space knowledge today (the room owns the conversion). Cost: the mask table goes from 8 directions to 8 × 4 per (material, face, mask); composition is lazy, so a real map materialises on the order of 16–32 atoms, not the product | ✅ Ratified 2026-09-02 · **UNBUILT** |
| **G-D31** | **THE HOLE'S RIM IS SHARDS, NOT CUBES — AND THE SPRITE'S OPACITY IS 80%.** *(Director, 2026-09-02: "eu vou propor a criação de um conjunto de voxels especiais, derivados do vidro intacto, mas que tem um recorte em alfa, formando arestas pontiagudas em direção ao centro do buraco […] dessa forma a gente estaria na verdade criando o verdadeiro caco com voxel atrás + adesivo complementando"; and "vamos tentar botar ele com 90% de opacidade" → "pode até reduzir um pouco mais, de 90% pra 80%".)* Tirar 1, 3 ou 18 voxels does not help — the hole is a rectangle either way. So the cells bordering it take an alpha wedge that narrows to a point aimed at the hole, and the shard is the glass that survives. **Eight shapes, his own budget** — the four orthogonals plus the four diagonals — *"e isso já cobre praticamente todos os buracos"*; the rifle reuses the same eight. He explicitly ruled the irregular-edge refinement **preciosismo**: *"nosso mecanismo já é suficientemente bem aleatório"*. ⚠️ It is G-D25's primitive (an alpha mask carving a voxel's outline, the dented-ceiling mechanism) applied to the rim, so it needs no art. ⚠️ It does not re-create G-D26's moldura, and the distinction matters: a cut is a SILHOUETTE, so the surviving glass is identical to its neighbours and only its outline moved | ✅ Ratified + **BUILT 2026-09-02** (§13 S-5) |
| **G-D30** | **A DESTROYED VOXEL CUTS THE SPRITE, BY A PER-LEVEL OCCUPANCY PLANE — AND HOW MUCH IT CUTS IS THE DIRECTOR'S, DECIDED BY LOOKING.** *(Director, 2026-09-02: "possivelmente, tirar o voxel de trás e deixar o adesivo pode ser que não incomode, representa de fato os estilhaços. Mas precisamos ver acontecendo pra confirmar. Talvez seja necessário remover um pedaço do sprite em runtime […] dá pra fazer isso?")* **Yes, and cheaply.** The sprite's shader already recovers `(run, level)` per fragment for G-D27's pane clipping, so it can sample one per-level R8 "is there still glass at this cell" plane and multiply alpha by it. The data has three writers and no more — `erase_glass_cell()` (the cook) and the two dirty-render passes (`voxel_renderer.gd:3583` slices, `:3724` slabs) — and because the sprite reads LIVE state, **a second event re-cuts every existing crack for free**; there is no "update the old sprites" pass. It also cuts a G-D9 banded pane's brick sill out of the web as a side effect. ⚠️ **The remaining question is fiction, not engineering, and stays open:** cutting says *the crack lives on glass that exists*; not cutting says *the crack is the shard cloud, and it outlives the pane*. So `glass_crack_hole_cut` is a CONTINUOUS 0..1 dial, not a boolean, and it is settled by a same-boot capture of both ends plus the middle — the Director's own *"precisamos ver acontecendo"* | ✅ **BUILT AND RULED 2026-09-02** (§13 S-2). **The value is 1.0** — Director, on the capture set: *"as versões com o adesivo sem voxels atrás não funcionam, podemos descartar"*. The crack lives on glass that exists; 0.0 and 0.5 are out. The DIAL stays (it is how the ends were compared, and `INFILTRAITOR_GLASS_CRACK_CUT` is how they can be compared again), the DEFAULT was already 1.0, so nothing moved. Mechanism: Built as a READ of the glass tilemap rather than a second plane — `erase_cell()` is the live authority all three seams already go through, and a parallel plane would be a third copy free to drift. The triptych that settled it: `glass_crack_cut_triptych_2026-09-02.png`. ⚠️ **The ruling has a consequence worth keeping in view:** on the real SHOTGUN path cut 1.0 leaves no web at all, because G-D24 turns every overlapping pellet crack into a hole and the shot ends `cracked=0 destroyed=279` — there is no standing glass under any of the webs (`glass_crack_cut_shotgun_2026-09-02.png`). That is the rule behaving, not a bug, but it means a shotgun's signature on glass is holes and shards rather than a web |
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

✅ **FIXED 2026-09-01, same day, red before green.** The BFS now expands through
everything inside the radius EXCEPT `own_frame`, and only RECORDS a cell the
lattice holds — a hole does not stop a fracture, a frame does. Selftest **[14]
`test_local_hole_does_not_wall_off_the_flood`** punches the hole BEFORE rolling,
the way the real shot does, and measures both sides: intact origin **1128**
flooded, after a 9-voxel hole **1119** — it loses exactly the punched voxels and
nothing else. It was RED at **0 of 1128** before the one-branch change. [11]
(the banded pane's brick sill and head) stays green, which is what stops the fix
from becoming an over-fix.

**Real map, same setup, same weapon, differing only by the fix:**

| | sniper on the GLASS big pane |
|---|---|
| before | `glass destroyed=18`, **no `[GLASS-SHATTER]` line at all** |
| after | `[GLASS-SHATTER] radius=23 flooded=1071` · `glass destroyed=1089` · `[GLASS-FALL] 1071 of 1071 shard(s) landed, on 45 cell(s), deepest pile 24` |

`glass_flood_before_2026-09-01.png` / `glass_flood_after_2026-09-01.png` —
hand-named so the rotation cannot eat them; **109 486 px changed (11.9%)**. The
pane stands with one small hole in the first and is gone but for its remnant
strip in the second. ⚠️ **`GlassFall` had never once fired on the real shot path**
— it is downstream of `if n > 0`, so the strangled flood took it with it.

⛔ **THE DEFECT, kept because the shape of it is the lesson — found 2026-09-01
while verifying V-A, and NOT a regression from that work** (the before/after runs on the same
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

**The fix was one branch, and it had to distinguish two absences that were the
same absence.** A cell missing from `lattice` is either a HOLE (fracture travels
straight through it — an already-broken area does not stop a crack) or the pane's
own non-glass BAND (`own_frame`, which must keep stopping it, G-D13b). So the
walk expands through everything inside the radius except `own_frame`, and only
RECORDS a cell in `flood` when the lattice holds it:

    if dist.has(nb): continue
    if own_frame.has(nb): continue   ## a real frame stops the fracture
    dist[nb] = d + 1
    queue.append(nb)                 ## a hole does not
    if lattice.has(nb): flood[nb] = true

⚠️ **WHY THIRTEEN GREEN TESTS WALKED PAST IT, and this is the transferable part.**
[7], [8] and [9] all aim at an INTACT lattice cell, so their origin is in
`lattice` and the walk starts alive. The real path destroys the local hole FIRST
— `agent_shot_controller` applies `plan_entries` and only then calls
`_maybe_shatter_pane`. **The fixture was built with the data that works**, which
is CLAUDE.md's floor-dent lesson wearing a new costume: a synthetic test that
skips the caller's own preceding step cannot see a defect that lives in it.

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

⚠️ **G-D16b is no longer blocked on ART — it is blocked on its CONSUMER.** The
three `decal_shard_glass_{0,1,2}.png` landed 2026-09-02 and gate green. What does
not exist is the code that draws them: `glass_fall.gd:119` names the shape G6
needs and stops there. ⚠️ And the fix is NOT to add `glass` to
`IMPACT_DECAL_MATERIALS` — see §8.1; `shard` is a FLOOR mark whose sibling
(earth's dent) rides `IMPACT_FLOOR_MATERIAL` on a different path entirely.

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

### ✅ V-B BUILT (2026-09-01) — the roster, and the tint on screen

**Five materials, one shader, one layer set, ZERO new art.** G-D16's *"a family
of tinted behaviour classes, not new geometry"* taken literally: every member
renders from BASE's voxel atom and BASE's `facade_glass.png` frost, and
`GlassMaterials.art_id()` is the one function that makes that true at every art
seam — a variant id never reaches a texture lookup under its own name.

**Where the tint lives, and why not anywhere else.** `_build_glass_pane_atom()`
has always written `Color(dim, dim, dim, alpha)` while the shader reads only RED;
G-D19 has already spoken for GREEN. So BLUE was free, and it now carries the
member's index in `GlassMaterials.FAMILY`, decoded as `int(round(t.b * 255.0))`
— exact for 8-bit, and every texel of one atom carries the same value so
filtering inside it cannot smear the index.

The alternative was a TileMapLayer set per material with its own `glass_tint`
uniform. Rejected on the standing priority: that multiplies **draw submission**,
which is what an event actually pays for (VFX-COST-01), while the atom route
multiplies a table composed once at load. Measured: **80 atoms** (5 members × 4
faces × 4 masks), all source ids distinct.

| | |
|---|---|
| `glass` | blue `0.47/0.63/0.90` — **CALIBRATED** ("painel 005"), untouched |
| `glass_armored` | `0.63/0.47/0.90` — the same blue rotated toward magenta at the same luminance, so G1's calibration still reads |
| `glass_screen_{green,red,amber}` | `0.24/0.62/0.34` · `0.72/0.26/0.28` · `0.82/0.60/0.20` — darker, so the MULTIPLY reads as a lit panel rather than a window |

⚠️ **A pane tint is NOT `base_color`,** and conflating them would be wrong rather
than untidy: the tint MULTIPLIES a BackBufferCopy of the scene behind the pane
(G-D1) while `base_color` is the opaque multiply on the ordinary wall path. The
two have carried different values for base glass since G1 shipped. Indices 1–4
are first-pass placeholders for a Director calibration pass; index 0 is not.

**⚠️ TWO GLASS MATERIALS ARE TWO PANES — a defect the family created and V-B
closed.** `GlassPaneGrouper`'s union matched on face and adjacency and **never on
material**, which was invisible while glass was one id. A plain pane touching an
armoured one would have become ONE pane with two resistances and two classes, and
`plan_pane_shatter` would then flood a won roll out of the ordinary glass and
straight through the armour — defeating it with nothing on screen to explain why.
The union now requires the same BASE material; a G-D9 banded window is still base
glass and still joins its neighbours, which is exactly why §G-D23 says a `bands`
entry is not a divider. Real map: four adjacent variant panels, same face, **four
distinct `pane_id`s**.

**Two costs the variants introduced and V-B paid back before shipping them:**

1. **A shader-compiler error on every boot.** `uniform vec3 glass_tint_alt[4]`
   renders correctly and prints `Condition "!actions.custom_samplers.has(...)" is
   true. Continuing.` — measured 0 occurrences before, 1 per boot with the array,
   0 with four named scalars. *"Continuing"* makes it the worst kind of error: the
   sort a reader learns to scroll past.
2. **Four identical baked sheets nothing reads.** The bake went `3 combos` →
   `7 combos × 2 directions in 1374.0 ms`, composing 8 pages and 16 384 atoms for
   materials whose panes render from `_glass_atom_source` and whose roofs get
   their own page family. Collapsing the family onto BASE's combo: **`3 combos …
   in 1263.0 ms`.** ⚠️ The saving is **111 ms, not the ~785 ms** a per-combo
   average predicted — combos are wildly unequal (concrete's roof page alone is
   4096 atoms against a sheet's 2048), and dividing a total by a count is not a
   measurement of any one item.

**Pinned by** `glass_transparency_selftest` [10] (two materials never share a
pane; a banded one still joins) and [11] (80 distinct atoms; the BLUE round-trip
per member; and the base tint being ONE number rather than three copies — it is
written in `GlassMaterials.PANE_TINT[0]`, `_glass_shader_params` and the shader
default, and the test asserts all three equal).

⚠️ **Still V-C's, not built:** the behaviour behind the colours. An armoured pane
is only *harder* today (resistance 0.80 → pistol 0%, rifle ~1.5%, sniper ~15%
against 5%/44%/81%); it does not yet break whole-pane on a win, and a screen is
not yet INDESTRUCTIBLE and does not stop a round.

### ✅ V-C BUILT (2026-09-01) — the behaviour behind the colours

`GlassMaterials.Class` — BREAKABLE / ARMORED / INDESTRUCTIBLE. A class is not a
difficulty dial; it changes **which rules apply**, which is why it is an enum.

**ARMORED — no region at all.** G-D12's partial break exists so a big pane keeps
standing where the round did not reach, and that is precisely what armoured glass
does not do (G-D15: *"usually shatters entirely at once"*). A won roll takes the
lattice whole. ⚠️ Written as *take the lattice*, not *use a huge radius*, and that
is measured rather than stylistic: since the flood fix the walk expands through
HOLES, so its cost is the area of the disc — roughly `(2r+1)²` cells — and no
longer bounded by the pane. A sentinel radius would walk tens of thousands of
cells to reach 2048 voxels it can enumerate. Remnants also scale by
`SHATTER_REMNANT_ARMORED_SCALE` (0.35) — *"many individual shards"* on the floor
is the same statement as few hangers-on on the frame — with G-D13b's conditional
floor still intact.

**INDESTRUCTIBLE — two independent claims, and the second is the one that sells
it.** *"Trinca mas o tiro para"*:

1. **The tier ceiling.** `damage_state_for()` returns CRACKED and nothing else,
   ahead of every punch test — a capability outranks a threshold, exactly as
   `HOLE_ONLY_MATERIALS` already does at the opposite extreme. It never DENTS
   either (G-D3: glass fractures, it does not deform).
2. **The round stops.** A new `EdgeRegistry.glass_stop_edge_keys()`, tested in
   `_walk_pellet_ray` BEFORE the pass-through set.

⚠️ **AND IT HAD TO BE A SECOND SET, NOT A FILTER ON THE FIRST — the same
conflation Stage D already undid once.** `glass_edge_keys()` reads as *"these
edges are glass"* and answers two different questions: `build_movement_edge_set`
asks *does this stop a body*, the pellet flood asks *does a round go through*.
Narrowing it to the passable subset would have made every screen **walk-through**
— and it would not even have stopped the round, because a half-thickness panel is
not in `blocked_edges` either, so an edge in neither dictionary is open air, not a
wall. **Absence is not a stop.** Pinned by a third assertion in selftest [16] that
runs exactly that empty-dictionary case and requires a clean miss.

**Also closed here:** `blast_glass_punch()` carried the literal `"glass"` (V-A's
last one standing), so on the COOK path an armoured pane rolled a common pane's
odds against a grenade and its RESISTANCE row did nothing at all. It now takes
the pane's material, and `_is_glass_pane_slice()` excludes INDESTRUCTIBLE members
— at the predicate rather than at the roll, because that same predicate decides
which slices leave the ring-scatter model.

**Real map, three shots, one weapon (sniper), differing only in which pane the
ray crosses:**

| pane | result |
|---|---|
| `glass_armored` (1 GU × 2 storeys) | `glass_punch 3.03 WHOLE PANE flooded=119` · **128 of 128 destroyed** — the whole pane on a punch far below the 5.29 plain glass gets, because resistance 0.80 divides. Free-standing, so G-D13b correctly leaves nothing |
| `glass_screen_red` | `cracked=1 dented=0 destroyed=0` and **no concrete line at all** — the round stopped |
| `glass` (control) | `flooded=1071`, `destroyed=1089`, `concrete:s1 destroyed=2` + `s2 destroyed=1` behind it — unchanged |

**Pinned by** `glass_shatter_selftest` [15] (a weak win takes 225 of 1152 plain
voxels and 1148 of 1152 armoured ones, same punch; armoured leaves 4 remnants to
plain's 7 on a full win, same salt) and [16] (the CRACKED ceiling against a plain
DESTROYED control at the same punch; terminal vs crossing on one ray; and the
absence-is-not-a-stop case).

⚠️ **Deliberately NOT here:** the crack MARK a screen takes is art (G-ART) —
the state is CRACKED and correct, and glass has no marked-tier art yet, so a hit
screen looks untouched. And G-D15's rifle **pierce-and-prime** (`pane_primed`) is
V-D, with the per-placement `glass_class` tag that flips a screen to BREAKABLE.

### ✅ V-D BUILT (2026-09-01) — the placement tag, and the primed pane

**1. `panels[].glass_class` — the class is a property of the PLACEMENT.** G-D16
makes a `glass_screen_*` either a control interface or a TV *per placement*, and
that is a fact about where the pane was PUT. So the tag rides the same path
`bands` does — `panels[].glass_class` → `MapCompiler` → `Edge.glass_class` →
`Slice.glass_class` — parsed once in `EdgeExtractor` where a bad name can still
be reported against the panel that wrote it. `CLASS_UNSET` (−1, not 0, which is a
real class) means the material's own default.

Every class question is now placement-aware: the tier ladder (via
`plan_point_impact`, which has the slice), `glass_stop_edge_keys()`,
`_maybe_shatter_pane`, `plan_pane_shatter` and the cook's `_is_glass_pane_slice`.
**Real map, same material, same weapon, only the map tag differing:** the red
screen `cracked=1 destroyed=0` and the round stops; the amber screen — authored
`"glass_class": "breakable"` — `WHOLE PANE flooded=119`, `destroyed=128`, and the
round carries on through the glass beyond it.

**2. ⚠️ G-D3 MADE STRUCTURAL — glass never DENTS, and until now that was a
coincidence.** §6.1 called it out: `DESTROY_MIN["glass"]` and `PUNCH_DENT_MIN`
were both 0.30, so the DENTED band was *exactly* empty, and *"it must be pinned
by a selftest, not left as an equality two independent edits could break."* V-D
is the edit that would have broken it — raising the armoured breach to 1.50 opens
a 0.30–1.50 band every common round lands in, and an armoured pane would have
started DENTING into a tier glass has no art and no physics for. The family's
ladder is now written out in full: CRACKED below the breach, DESTROYED at or
above, never anything else. Pinned by [17], which sweeps all five materials × 61
punches **and keeps a concrete control that must still dent** — a glass-only
sweep would pass just as happily if DENTED had stopped existing for everything.

**3. `glass_armored`'s breach: 0.75 → 1.50, DERIVED from the shipped arsenal.**
`glass_punch = 3.0 · punch / 0.80` gives smg 0.82 · shotgun pellet 0.90 · pistol
1.05 · revolver 1.31 · assault rifle 1.88 · sniper 2.62. **1.50 is the only value
that splits that list where G-D15 splits it** — *"resists common shots"* and
*"a RIFLE round may pierce a single voxel"*. At V-B's 0.75 every shipped round
holed armoured glass as readily as a sniper. Pinned by [19], off the real weapon
JSONs.

**4. `pane_primed` — and it has no threshold of its own.** The gate is the
LADDER'S OWN OUTCOME: a round that DESTROYS a voxel of an armoured pane and still
loses its roll has breached the armour locally and been held, so it primes the
pane. One number (the breach above), one place, and no second "is this
rifle-class" test to drift away from the first. The flag is cleared BEFORE the
flood, so a second pellet of the same burst finds an ordinary pane rather than a
second free shatter. Stored per `pane_id` in `Room._pane_primed`, checkpoint-
scoped: captured in `SaveState`, validated, restored, and cleared by
`clear_run_state` — a fresh mission must not inherit a window that goes to the
first pistol shot. ⚠️ `FORMAT_VERSION` is deliberately NOT bumped: an old save
has no `pane_primed` key and reads as "nothing primed", which is both true and
the safe direction; a bump would refuse every existing save to gain nothing.

**The whole G-D15 sequence, ONE boot, real map, assault rifle:**

    shot 1  [GLASS-PRIME] PIERCED but held (punch 2.16) — primed
            glass_armored:s1 destroyed=6 · concrete:s1 destroyed=1  (the round went on through)
    shot 2  [GLASS-PRIME] was PRIMED — this hit auto-shatters it
            [GLASS-SHATTER] glass_punch=2.01 WHOLE PANE (armoured) flooded=122
            [GLASS-FALL] 122 of 122 shard(s) landed, on 8 cell(s), deepest pile 16

Shot 2's punch is LOWER than shot 1's (different luck) and nowhere near enough to
take the pane on its own — which is the mechanic proving itself rather than a
number happening to land.

⚠️ **A capture-tooling addition this needed:** `shot_filmstrip` is the only action
that fires TWICE in one boot, and it could not be aimed. It now takes the same
`INFILTRAITOR_SHOT_AGENT_CELL` / `_GUARD_CELL` overrides `agent_shot` has —
without them a two-shot mechanic is unprovable, because the shatter salt carries
`_world_revision` and the first shot bumps it, so two boots are two independent
rolls rather than a sequence.

### G-D19 mechanics — the free channel that carries the damage term

⛔ **SUPERSEDED 2026-09-02 BY G-D26 — kept for the shader facts, which are still
true, and for the argument, which is the one that lost.** The crack never
modulates a voxel's transparency now (it is pure additive light), so there IS no
per-voxel damage term and the GREEN channel this section reserved is free again.
What survives verbatim: the shader inventory below, the "alpha is COVERAGE, not
opacity" distinction, and the compositing-order rule. What does not: everything
that treats "half see-through" as the goal.

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

✅ **BUILT AS CRACK-01, 2026-09-02** — and the "everything is blocked on
`crack_factor`" reading above turned out to be wrong. `glass.crack_factor` STAYS
0.0 (§8.1's resolution): a glass voxel reaches CRACKED through the shot ladder
(`damage_state_for()` already returns it sub-breach), and CRACK-01's event sets
it directly on the ring around a hole. What was actually built:

- **G-D19 → ⛔ RETRACTED, replaced by G-D26** — the crack does NOT change a
  voxel's transparency at all. `lit + crack_colour · crack · dim`, pure additive
  light, because any per-voxel modulation frames that voxel against its untouched
  neighbours. Two builds (flat, then density-driven) died on that premise before
  the Director retracted it.
- **G-D21** — world-space, per §8.2's amendment. `fuv = 0.5 + offset / span`,
  where the offset comes from the fragment's CANVAS delta from the impact,
  inverted with the **wall face's** basis (`run = sx·d.x/16`, `level =
  (run·8 − d.y)/20`) — not the ground-plane inverse, which shears the sheet
  column by 1.25 voxels per level and scrambled the first build's web. Impact
  rides a `GLASS_CRACK_GROUP_CAP`-wide RGBAF strip, indexed by an R8 per-level
  plane. `glass_sheet_span_tight/_wide` set how many voxels the sheet spans —
  the compactness dial.
- **G-D23** — `fuv` outside `[0,1]` → no crack. The 64/32 mirror-fold never
  happens because the fold was a property of `_compute_facade_key`, which glass
  does not use.
- **G-D24** — `GlassCrack.apply()` checks the plane before stamping: a cell
  already in another group is `set_damage(DESTROYED)` and handed to `GlassFall`.
- **G-D14** — `tight` / `wide` off `WeaponDef.blowout` (`GlassCrack.wide_for_blowout`,
  ≥ 0.5 → wide). `CRACK_RADIUS_TIGHT` (6,5) / `_WIDE` (12,9), `static var`.

`glass_crack_selftest` (27 checks). On the real GLASS map
(`INFILTRAITOR_CAPTURE_ACTION=glass_crack_demo`): tight crazes 143 voxels, wide
475, and a second overlapping crack DESTROYS the crossing. Captures
`glass_crack_demo_{tight,wide,gd24}_{before,after}.png`. ⚠️ The look — sheet ink,
radius, `glass_crack_see_through`, and the voxel-step aliasing — is a Director
calibration pass (the fracture sheets regenerate from `gen_fracture_sheet.py`).

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

## 8. G-ART — ✅ DELIVERED 2026-09-02 (order + gate 2026-09-01)

**The order is [`PROMPTS/ART_ORDER_GLASS.md`](../ART_ORDER_GLASS.md)** and
`tools/persistent/check_decal.py` enforces it — earned BEFORE the art, the way
M2a was. **The delivery landed 2026-09-02** (§6 of the order carries the measured
numbers and the four symmetry defects that passed the gate and were visible only
at true size). Two sections below record what the delivery FOUND rather than what
it produced, and both outlive the art.

### 8.1 ✅ RESOLVED 2026-09-02 — glass reaches CRACKED by the route it already has

**Director ruling:** glass does NOT go through `crack_factor` at all. It stays
`0.0` in `glass.json`, glass stays out of `IMPACT_DECAL_MATERIALS` and
`IMPACT_CRACK_MATERIALS`, and `voxel_decal_selftest` [12] / [10] and the
blast-crack tests are untouched and green.

The tier is already reachable: `ShotPunchTable.damage_state_for()` returns
`CRACKED` for a sub-breach glass hit (and `DESTROYED` at/above breach; never
`DENTED` — G-D3). CRACK-01's event (§C) calls `set_damage(CRACKED)` directly on
the surviving ring around a hole, exactly as `_maybe_shatter_pane` calls
`set_damage(DESTROYED)` on the flooded voxels. A CRACKED glass voxel renders its
ordinary `_glass_atom_source` atom — `damage_variant_material("glass", CRACKED)`
resolves to the flat `"glass_cracked"`, which `apply_damage_voxel_swap` misses
(no baked glass crack variant) and the glass render path ignores anyway.

`glass_crack_selftest` (13 checks, `run_selftests.py --only glass_crack`) is the
GUARD: it fails if a future edit re-introduces the crack DECAL family on any axis
— `crack_factor > 0`, membership in either wiring list, a composed `decal_` name,
or `decal_crack_glass_*.png` on disk.

<details><summary>The original §8.1 write-up (the contradiction, before the ruling)</summary>

`_decal_material()` (`voxel_renderer.gd:286`) composes a decal name from the
DAMAGE STATE for every material in `IMPACT_DECAL_MATERIALS`, so putting `glass`
there asks the renderer for `glass_bullet_cracked_*` — the per-voxel mark G-D21
folded into the sheet. `shard` is not a name that function can compose at all;
its sibling, earth's dent, rides `IMPACT_FLOOR_MATERIAL` through
`_floor_sunk_decal_plan()`, a different constant on a different path.

And `crack_factor > 0` is not a free data edit either: `voxel_decal_selftest`
**[12]** ties it to `IMPACT_CRACK_MATERIALS` **and** to
`decal_crack_glass_{0,1,2}.png` existing on disk, and `damage_variant_baker.gd:161`
reads the same number for crack eligibility. So raising it demands art G-D21 says
must never exist.

**Glass is the first material for which "cracks" and "has a crack decal family"
are different claims.** Either [12] learns that a sheet-cracking material
satisfies the tier without a decal family, or glass reaches CRACKED by a route
that is not `crack_factor`. Until then **glass cannot reach CRACKED at all**,
which is what blocks G5 and makes G-D21 untestable on the map.

</details>

### 8.2 ✅ RESOLVED 2026-09-02 — G-D21 amended to WORLD-SPACE sampling

**Director ruling:** amend G-D21 (a change to a ratified decision, so it is
logged as an amendment on the row itself). The fracture is a plain texture
sampled in `glass_pane.gdshader` at `(v_glass_world − impact_world)`, ~2 MB and
**0 atoms minted** — not a reanchored atom page (the 36–144 MB below). The
`_compute_facade_key()` offset, and the 64/32 mirror-fold that was "the number
that bites", are not used: a world-space `fuv` with a plain `if fuv in [0,1]`
test IS G-D23's clamp, and an out-of-sheet fragment simply has no crack.

**Multiplicity (each pane its own impact)** is solved by a small crack-GROUPS
data texture (`sampler2D`, ~8 texels RGBAF: impact world-pos + width + active per
crack event), indexed by a per-cell crack PLANE (the soot-plane pattern —
`_soot_images` / `flush_cell_soot`). Not a `uniform vec3[]`, which prints a
shader-compiler error on every boot in this shader family (V-B measured it).

<details><summary>The original §8.2 write-up (the cost table that forced the amendment)</summary>

G-D21 reuses `_compute_facade_key()`'s `(column_in_run, level)` offset. That is
the BAKED WALL path, and it is correct for concrete. **Glass never touches it.**
Glass renders from `_glass_atom_source[material][face][mask]` — 16 atoms per
member — and the frosted pattern is not in the atom at all: `glass_shading.gdshaderinc`
samples it by WORLD POSITION (`texture(glass_frost_tex, v_glass_world * glass_frost_scale)`)
precisely so it flows across a pane instead of repeating per voxel.

Measured, 2026-09-02:

| | RAM | new atoms |
|---|---|---|
| every glass atom that exists today (5 members × 4 faces × 4 masks) | 360 KB | 80 |
| a fracture atom page, **per face** (2048 atoms) | 9.0 MB | 2048 |
| × the four faces | **36 MB** | 8192 |
| × faces AND masks | 144 MB | 32768 |
| the sheet as a plain texture, sampled by world position | **2.0 MB** | **0** |

The cheap route is the one the architecture is already asking for: a fracture
sampled by world position with an offset equal to the impact IS the
re-anchoring — a subtraction inside `texture()`, one fetch, nothing minted. Its
one real problem is multiplicity: a uniform is global and each pane has its own
impact, and the include's own comment records that a `uniform vec3 array[]` in
this shader prints an error on every boot. **Open for the Director** — amending
G-D21 to world-space sampling is a change to a ratified decision.

</details>

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
| ✅ | **G-ART** — **DELIVERED 2026-09-02.** All five files on disk and green, authored PROCEDURALLY (`gen_fracture_sheet.py`, `gen_shard_decal.py`), plus §4's wiring (steps 2/4/5/6). Found §8.1 and §8.2. *(Below: the order and gate, done 2026-09-01.)* **the order and the gate are DONE 2026-09-01** ([`ART_ORDER_GLASS.md`](../ART_ORDER_GLASS.md); `check_decal.py` now carries per-material families + the fracture-sheet class, proven red on 7 modes with all 54 shipped decals unchanged). Five files asked for: two 1024×512 grayscale fracture sheets (tight/wide, G-D14) and three 256×256 shard decals. **What is left is the delivery** | — |
| ✅ | **CRACK-01 / G5** — the crack, BUILT 2026-09-02, stages A–E (§8, §5). The CRACKED tier without `crack_factor`; the crack plane + groups strip; the event on the lost roll; the wall-face inverse; G-D26's additive light. Fires on the real map, state-correct. ⛔ Its RENDERER is superseded by CRACK-02 — the crack is drawn by the voxel shader and cannot stop looking like it | — |
| 🟡 | **CRACK-02** — the crack leaves the voxel (**§13**, G-D27..G-D30). S-1 the sprite + pane clipping, S-2 the occupancy cut, S-3 rotation survival, S-4 the art order (`bullet_tight`/`bullet_wide`/`armored`/`blast`×3). **PLANNED 2026-09-02, UNBUILT.** ⚠️ §13.3: the resolver + gate contract must move in S-1's own commit or the new art drops silently | CRACK-01 |
| 🟡 | **G3** — the break, per §5.1's REWRITTEN model. **Staged (Director "vamos seguir com G3", 2026-08-31):** **A** ✅ `GlassShatter` curve + arsenal selftest. **B** ✅ the roll in the shot path + region flood + G-D13 remnants + glass-VFX guard. **C** ✅ the grenade/cook path — `blast_glass_punch()`, panels out of the ring model, `_shatter_glass_panes()`, `VoxelRenderer.erase_glass_cell()` (see §5.1). **D** (open) G-D8's passage work: intact glass → the movement blocked-edge set (new split from vision's, per G-D7), broken glass → passage opens (`PassageQuery` → per-turn recompute) + detection +1 + light bump | G-MAP, G2, §5.1 |
| 🟡 | **G-VARIANT** — `glass_class` + tint (G-D16). **Staged 2026-09-01, mirroring G3's arc:** **V-A** ✅ the FAMILY SEAM — `GlassMaterials.is_glass()` replaces 25 bare `== "glass"` comparisons across render, geometry, occlusion, the guard phase, the shot path and the cook, pinned by new invariant **L2**. **V-B** ✅ the roster + the tint on screen — 4 material rows, per-member atoms carrying the tint index in the atom's free BLUE channel, a material-aware pane union, and the bake collapsed onto BASE's facade (§5.4b). **V-C** ✅ the class behaviour — `GlassMaterials.Class`, ARMORED's whole-pane break + sparser remnants, INDESTRUCTIBLE's CRACKED ceiling and the terminal `glass_stop_edge_keys()` set, and the cook made material-aware (§5.4c). **V-D** ✅ `pane_primed` (G-D15, checkpoint-scoped in `SaveState`) + the per-placement `glass_class` tag, and G-D3's no-DENTED rule made structural (§5.4d). **G-VARIANT IS COMPLETE** | — |
| 6 | **G4** — frame remnants: border ring, luck-driven survival, jagged half-voxel substrate. **G-D13 makes this a rule of G3, not a separate task** — it lands with G3 | G2, G-ART |
| 7 | **G6** — shards: BASE-coord store, floor decal, `SaveState` section (also holds `pane_primed`, G-D15). **Now also owns G-D25's big shards** — a cut silhouette on 1–4 whole voxels, no per-shape texture | ~~G-ART~~ (delivered) — unblocked |
| ✅ | **G-D4** — the bullet web on shot neighbours. ⚠️ **This row was stale until 2026-09-05: it was DELIVERED by CRACK-01/02.** `GlassCrack.plan_pane_crack()` crazes every glass cell within the crack radius around the bore and lays ONE sheet over the pane — the real shot path reports `crazed=80` on the GLASS map. §6.3's mechanism (a decal chosen by BEARING) is the part that died, superseded by G-D21; the requirement it carried was met by a different means, which is why nobody noticed the row | ~~G5~~, ~~G-ART~~ |
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

---

## 13. CRACK-02 — the crack leaves the voxel (G-D27..G-D30)

**Status:** 🟢 **S-1, S-2 AND S-3 BUILT 2026-09-02** (`a6cb797f`, `a407b93e`,
`34077458`); **S-4's order is written and its art is unbuilt.** Ratified in the
register as G-D27 (the sprite), G-D28 (the four classes), G-D29 (`blast` = 3 ×
flips) and G-D30 (the occupancy cut). This section is the build order; the
decisions and their reasoning live in §1 and are not repeated here.

CRACK-01 shipped a working crack (§8, stages A–E) and the Director rejected its
LOOK three times in a row, each rejection landing one level deeper:

| | rejected | root cause |
|---|---|---|
| 1 | a block of another material in the middle of the glass | the frost was FLAT over the crack radius, so its silhouette was a rectangle |
| 2 | *"as linhas não se encontram e estão todas embaralhadas"* | the sheet UV used the GROUND-PLANE inverse on a WALL face — 1.25 voxels of shear per level |
| 3 | *"ainda dá pra ver muita diferença entre voxels"* | **the crack was drawn BY the voxel shader**, so it inherited `dim`, `cover` and the quad seams no matter what it did |

Fixes 1 and 2 were real and are kept. Fix 3 is not a fix — it is the premise
going. **CRACK-02 is that.**

### 13.1 What survives, and what is deleted

**Survives unchanged:** the fracture ART (grayscale-on-black sheets — the sprite
shader does luma→alpha at sample time, so no re-authoring); `GlassCrack.plan_pane_crack()`
and `wide_for_blowout()` (they decide the CRACKED *state*, which is not a render
concern); the event hook `_craze_pane_around_hole` and every trigger it serves;
G-D23's clamp; G-D24's rule; the wall-face inverse and its selftest [10] — it
changes job from generating the UV to clipping the sprite.

**Deleted:** the per-level crack PLANE and its group ids, the RGBAF groups strip,
`GLASS_CRACK_GROUP_CAP` and the 16-crack ceiling, `write_glass_crack_cell` /
`glass_crack_group_at` / `flush_glass_crack` / `alloc_glass_crack_group` /
`set_glass_crack_group`, `glass_cell_canvas_pos`, and every crack uniform and the
cell recovery inside `glass_pane.gdshader` — that shader goes back to what it was
before CRACK-01-B.

⚠️ **STATE AND RENDER DECOUPLE, and G-D24 moves with them.** Today the crossing
test reads the crack plane. With no plane it becomes a geometric test on the
crack REGISTRY — does this new crack's region overlap a live crack instance on
the same pane. Simpler, and it is the one piece of CRACK-01 logic that has to be
rewritten rather than moved.

### 13.2 Stages

| | stage | what closed it |
|---|---|---|
| **S-1 ✅** | **The sprite.** `GlassCrackSprite` + `glass_crack.gdshader`, one node per crack, parented into the glass composite so G-D18b still holds. ⚠️ **The wall-face basis changed job rather than being inverted**: the FORWARD basis is baked into the node's `Transform2D`, so the quad IS the pane's parallelogram and the shader has no inverse in it — UV is already the sheet. Additive by BLEND MODE (`blend_add`) rather than by arithmetic inside someone else's shader. §13.1's delete list is gone; G-D24 is geometric | `glass_crack_demo_c02_*` — a continuous web, no per-voxel variation, no quad seams. And **`glass_crack_demo_c02_edge_clip_*`**, which is the one that matters: a CENTRED hit cannot prove the clip, because the sheet is smaller than a big pane and the bounds never engage. An EDGE hit puts the sheet 22 voxels past the frame and it is cut dead on the boundary; the demo prints both quads in screen pixels so it is a measurement |
| **S-2 ✅** | **The occupancy cut (G-D30).** ⚠️ **Not a plane — a READ of the glass tilemap.** `erase_cell()` on `_glass_layers` is what actually removes a glass voxel, and all three erase seams already go through it, so a parallel plane would be a third copy of the same fact, free to drift. The seams only FLAG; the rebuild is once per batch at the five seams `flush_damage_composite_pages()` already uses. §13.5's two side effects both confirmed: the brick band clips for free, and `armored` cannot be erased by the dial | `glass_crack_cut_triptych_2026-09-02.png` — one crack, one boot, 0.0 / 0.5 / 1.0 over a real hole punched through the real erase seam. **✅ RULED: 1.0.** `glass_crack_cut_shotgun_2026-09-02.png` is the consequence to keep in view |
| **S-3 ✅** | **Rotation survival.** `_base_cracks` mirrors `_base_damage` and stores only what cannot be re-derived: the impact in base coords and the sheet id. ⚠️ **Rebuilds through `sprite_spec()`, never `apply()`** — re-applying would set the damage a second time and run G-D24 against the cracks it is rebuilding, so every crack would cross the one before it | a **round trip** N→E→N, which returns to the identity so the sprite must land on the pre-flip pixels: **5853 of 5855 bright pixels identical**. "A crack appeared somewhere" is what the eye would have accepted. ⚠️ The E/S/W half is blocked by the `panel_instances` defect in the header |
| **S-6 🟡** | **The four shapes become a hashed POOL (G-D32).** Each cut cell draws its own from {spike-deep, spike-shallow, V-notch, 45° chamfer} — ratified from `glass_rim_shape_options_2026-09-02.png`, which renders the four hole silhouettes from the real atoms. ⚠️ B4 FNV-1a, never `randf()`; ⏳ the key must be BASE-space or a flip reshuffles the hole | UNBUILT — and the open sub-question is where the renderer gets a base-space key |
| **S-5 ✅** | **CRACK-03 — THE SHARD RIM (G-D31).** *"em vez de voxels cúbicos, a gente vai ter partes de voxel formando triângulos agudos apontando em direção ao centro do buraco […] estaríamos criando o verdadeiro caco com voxel atrás + adesivo complementando."* A hole is a rectangle of missing cells and reads as one however good the web over it is, so the cells that BORDER it stop being cubes: their alpha is cut to a wedge narrowing to a point aimed at the hole. **Eight directions, the Director's own budget** — four orthogonals plus four diagonals. ⚠️ Same primitive G-D25 ratified (an alpha mask carving a voxel's outline, the dented-ceiling mechanism), so no new art and no new render path. ⚠️ And it does NOT re-create G-D26's moldura: a cut is a SILHOUETTE, so the glass that survives is pixel-identical to its neighbours and only its outline moved — the same reason a DESTROYED voxel, a 100% cut, never framed anything | `glass_rim_ab_{pistol,rifle}_2026-09-02.png` — the A/B with `INFILTRAITOR_GLASS_RIM=0/1`, one camera, because a cut glass voxel reveals GLASS and the change has to be measured rather than squinted at. `glass_rim_atoms_2026-09-02.png` — the nine masks. Dials: `GLASS_RIM_TIP_HALF`, `GLASS_RIM_DEPTH` |
| **S-4 🟡** | **The art order** — `tight`, `wide`, `armored`, `blast` ×3 (G-D28/G-D29). **Written**: [`ART_ORDER_GLASS_FRACTURE_CLASSES.md`](../ART_ORDER_GLASS_FRACTURE_CLASSES.md), including the free-size/aspect contract S-1 made real and the six wiring steps. **Art unbuilt on purpose** — §6 of that order: the generator would have to produce the opposite distribution (§13.4), `blast_*` has no caller yet (§6.2 is unbuilt), and the look has been rejected three times on this track already | `check_decal.py` green on the new classes, and each class visible on the GLASS map — neither yet |

### 13.3 ✅ RESOLVED IN S-1's OWN COMMIT — the contract that had to move

`TextureResolver`'s `fracture_` category enforces the FACADE contract (64 × 32
voxels = 1024 × 512) and `check_decal.py`'s fracture class enforces 1024 × 512
grayscale with the ink centroid at the page centre. **Both encode the atlas
assumption S-1 removes.** A sprite is free-size and need not be centred, so left
as they are the gate rejects good art on size and — worse — the resolver drops it
with **no error at all** (Tier.NONE → generic atlas), which is the exact silent
failure this project has already paid for three times. They move with the
mechanism or the art lands and quietly does not load.

**✅ Both moved in `a6cb797f`.** `TextureResolver`'s `fracture_` branch now
returns true for any size — the branch still has to EXIST, because an
unrecognised prefix is `Tier.NONE` and the generic atlas with no error at all,
which is the failure this warning is about. `check_decal.py` swapped the 1024×512
rule for an ASPECT one (2:1 ± 2%, ≥128 px), reading the spans out of
`glass_crack.gd` rather than duplicating them, and re-expressed the ORIGIN slack
as a fraction of the page — the same tolerance, because "4 voxels" against a page
with no fixed voxel extent would have quietly become 3× more permissive on a
`tight` sheet. The origin rule itself is untouched and still fails: `Sprite2D`
is `centered`, so the page centre goes on the impact.

### 13.4 What the reference set actually said (`REFERENCES/Vidro`, read 2026-09-02)

Two findings that contradict the art CRACK-01 shipped, and one licence flag.

- **A real bullet hole is SPARSE with a few LONG runners.** In `bala-perdida-1`
  and `rachaduras-do-furo`, density collapses within a couple of voxels of the
  bore and what remains is 4–8 fine lines running far — one reaches the frame.
  The procedural sheets are dense and even out to the edge: the opposite.
- **Asymmetry is the norm.** None of the six is symmetric. The four "symmetry
  defects" the G-ART session fought (`ART_ORDER_GLASS` §6.2) were the generator
  pulling toward a regularity real glass does not have.
- 🔒 **`vidro buraco maior` (depositphotos) and `rachaduras-do-furo` (dreamstime)
  are WATERMARKED STOCK COMPS.** They are legitimate to read for vocabulary and
  illegitimate to derive pixels from. Delivery stays procedural or
  Director-authored — the same discipline D57 imposes and that the Freepik
  reference already cost this track once (§8's own note).

### 13.5 Risks worth stating before the build, not after

- **Perf is a claim, not a fact.** ✅ **MEASURED 2026-09-02, and the prediction
  did NOT hold.** Same map, same camera, idle `GLASS`, 40 probe samples each
  side, `--disable-vsync`:

  | binary | frame (median) | render cpu | draw calls |
  |---|---|---|---|
  | CRACK-01 `6d8bd94e` | **6.40 ms** | 3.10 ms | 7944 |
  | CRACK-02 `a407b93e` | **6.40 ms** | 3.10 ms | 7944 |

  Identical. Removing a `texture()` + branch from every glass fragment is real in
  instruction count and **invisible in the frame**, because this board is not
  glass-fragment bound (`render gpu` reads 0.0). The cost side is **+1 draw call
  and +1 quad per live crack**. Neither number is a reason to have done CRACK-02
  or to undo it — the reason was the look — but the plan predicted a win and
  there is not one, so it says so.
- **A banded pane clips for free, and that is luck, not design.** ✅ CONFIRMED and
  pinned: `glass_crack_selftest` **[12]** builds a real `VoxelRenderer` with two
  glass levels of real cells and asserts the brick-band row reads EMPTY while
  every glass row reads solid. It also pins the row convention (row 0 is the
  HIGHEST level) and G-D30's live re-cut after an erase.
- **`armored` never destroys voxels** (it holds, G-D15), so its opaque core has
  no hole to be cut by — S-2's dial does not apply to it. ✅ Free by construction:
  the occupancy is read off the glass tilemap, and an armored pane's cells are
  never erased, so its occupancy is solid whatever the dial says.

### 13.6 What S-1..S-3 cost that the plan did not predict

Three defects, each invisible to every gate that existed and each found by a
capture or by the test written for something else:

1. **A centred hit cannot prove the pane clip.** The sheet is smaller than a big
   pane, so the bounds never engage and the picture is correct for the wrong
   reason. The demo now prints the sheet quad and the pane quad in screen pixels,
   and `INFILTRAITOR_CRACK_DEMO_EDGE=1` puts the sheet past the frame on purpose.
2. **`_glass_composite_z` starts at −9999, below `CANVAS_ITEM_Z_MIN`.** Assigning
   it printed an engine error and left the node at z 0. The glass LAYERS never hit
   it because `_ensure_glass_sublayers()` sets the real z on its first line; the
   crack root can be asked for before any of that has run.
3. **`ImageTexture.get_image()` is a readback and can lag an `update()`.** A
   diagnostic that asked the texture read the occupancy one event stale and
   reported that the cut had not followed. The builder keeps the CPU-side Image
   as the authority.
4. ⚠️ **A CRACKED GLASS VOXEL WAS NOT RENDERING AS GLASS AT ALL, AND HAD NOT BEEN
   SINCE BEFORE CRACK-01.** `damage_variant_material("glass", CRACKED)` returns
   `"glass_cracked"`, and `is_glass("glass_cracked")` is FALSE, so
   `_set_voxel_cell()` skipped the glass branch and put the voxel on the OPAQUE
   layer. The crack radius is a rectangle, so the whole web sat inside a block of
   another material — *"volta a aparecer o quadrado em volta do decal"*, the
   Director's third rejection of a square and the same picture CRACK-01-D's flat
   frost produced by a different route. `DamageVariantBaker` reads the same
   function and had baked the full wall damage set for glass, so the swap path
   used it too.

   Fixed where the rule belongs: **a glass member keeps its own name at every
   damage state.** The STATE is untouched (G-D3/G-D4 ratified that glass cracks,
   VL-PERSIST still saves it); it simply no longer changes how the voxel LOOKS,
   which is G-D26's rule applied to the place it had been quietly broken.

   ⚠️ **The assertion that should have caught it passed for the whole life of the
   bug.** `glass_crack_selftest` [2] asked whether the name was a decal path — it
   was not — and never asked whether it was the material's own name. It now
   asserts identity across every member × damage state × blast, 24 combinations.
   *Assert what must be true, not what must be absent.*

   ⚠️ **It also corrected a misreading of this session's own measurement.** The
   1382-pixel block missing from S-3's round-trip frame was filed as "a pane's
   body", a second symptom of the `panel_instances` defect. It was THIS rectangle
   — the demo records no voxel damage to base, so the round trip restored no
   CRACKED states, which is exactly why that frame was the one the Director
   singled out as *"o único que funcionou"*. The `panel_instances` finding stands
   on its own evidence, the pane cell dump.
---

## 14. CRACK-04 — the opening family (G-D34)

**Status:** 🟢 **BUILT AND WIRED 2026-09-04.** The hole is a named shape, the decal
is generated from it, and the play path picks both on a BASE-space key.

### 14.1 What replaced what

| gone | replaced by |
|---|---|
| `GLASS_RIM_VECTORS` / `_DIRS` / `_glass_rim_index()` / `TIP_HALF` / `DEPTH` | `GlassOpening` — 12 polygons in pane (run, level) space |
| "four orthogonal neighbours, corners untouched" | whatever cells the polygon crosses (8 for `star_deep`, 31 for `shard_fan_wide`) |
| `fracture_glass_{tight,wide}.png` | 12 openings × 3 variants, generated FROM each polygon |
| `SHEET_SPAN_TIGHT/WIDE` as the sizing rule | per-opening span, read from `fracture_manifest.json` |

Under a per-cell wedge the hole's SILHOUETTE was a side effect nobody could name;
that is why G-D32 had to hash per shard to get irregularity, and why the neighbour
count was 8 in one commit and 4 in the next. An opening states it outright.

### 14.2 The defects it uncovered, and each one's shape

Every one of these was invisible to a gate that existed, and each failed in the
direction that looks correct.

1. ⚠️ **THE SHARD RIM HAD NEVER REACHED THE SCREEN, SINCE CRACK-03.**
   `refresh_glass_rims()` reported **12 cells cut**; `count_glass_shards()`, which
   reads the TILEMAP back, reported **0**. The overwriter is the feature's own
   neighbour: a hole always crazes the ring around it, and that CRACKED ring's
   render pass re-places the shard cells with the intact atom. CRACK-03's commit
   celebrated needing *"no registry, no dirty flags and no per-cell state"* —
   which is exactly why nothing could put them back. `_glass_shard_cells` +
   `restamp_glass_shards()`, and ⚠️ the re-stamp must run when NOTHING is dirty,
   because the pass that overwrites a shard flags no erase at all.
2. ⚠️ **THE CRACK'S ORIGIN WAS HALF A RUN STEP OFF, ON EVERY FACE.**
   `GLASS_CRACK_FACE_CENTRE` was one constant `(0, -6)` from a derivation whose
   rows were right and whose column was not: a face occupies HALF the quad's
   width. Per face and derived now: SW (−8,−6) SE (+8,−6) NW (−8,−14) NE (+8,−14).
   Selftest [10] reported 0.00000 px throughout, because it compares the sprite
   against the function that builds it.
3. ⚠️ **THE SHEETS WERE DRAWN VERTICALLY MIRRORED.** The generator draws in image
   space (y down); the radii are sampled in pane space (y up). Invisible on every
   regular star at phase 0, because the mirror is the identity on it — it showed
   only on the four asymmetric members, which is what the Director circled.
4. ⚠️ **AN ASYMMETRIC OPENING'S CENTROID IS NOT ITS IMPACT.** A claim was matched
   to a region by centroid, so every asymmetric hole missed its claim and applied
   the default DISPLACED; and `chunk_bite`'s two swallowed cells touch only
   diagonally, so 6-connectivity split them and the orphan stamped a second
   opening three cells outside the real one.
5. ⚠️ **THE GENERATOR WAS NOT DETERMINISTIC.** `hash(opening_id)` — Python
   randomises string hashing per PROCESS, so it produced different art every run.
   `zlib.crc32` now.

### 14.3 The instruments that were earned

- **`count_glass_shards()`** reads the tilemap rather than counting swaps issued.
  It is the only reason defect 1 was findable.
- **`INFILTRAITOR_FREEZE_GUARD_TURN=1`** (the Director's own diagnosis: guards ease
  from forward to their posted facing at boot, so two captures land at different
  points of the sweep). Two boots of the same capture: **34 px free, 0 px frozen.**
  This project's rule is that a pixel-diff gate must be EARNED by diffing two runs
  of the same code; no capture on this map could clear it before.
- **`INFILTRAITOR_GLASS_DIAG=1`** hides the guards and flattens the floor. Not
  cosmetic: on a two-tone backdrop a colour mask of "what shows through the hole"
  is biased by which half the hole sits on, and returned a confident +14.3 px that
  meant nothing. On a flat floor the hole reads NEUTRAL against BLUE glass.
- **`INFILTRAITOR_GLASS_OPENING=<id>`**, to photograph the family one shape at a
  time on the real map.

### 14.4 The fit, measured

Sprite centre (538.0, 354.9), from the demo's own printed quad. The eight
SYMMETRIC openings, delta in px:

    chamfer_45      (-0.3,-1.0)   star_deep_wide    (-0.3,-0.4)
    chamfer_45_wide (-0.5,-0.5)   star_shallow      (-0.4,-0.6)
    notch_v         (-0.0,-0.6)   shard_fan_wide    (+0.5,+0.3)
    star_deep       (-0.4,-0.6)   star_ragged_wide  (-0.4,-1.0)

All within 1.0 px, on a board where a voxel face is ~18 px across. ⚠️ The four
asymmetric members read 5–23 px off and are NOT misaligned — a lopsided shape's
centroid has no reason to sit on its own impact. **Only a symmetric member can
test alignment at all.**

### 14.5 ✅ BOTH CLOSED BY CRACK-05 (2026-09-04) — see §15

- ~~**The cook does not claim.**~~ It proposes on the `WorldDelta` and `commit()`
  claims. ⚠️ **And the measurement that came with it is the more useful half:
  under the shipped balance the claim is LATENT** — §15.2.
- ~~**G-D28's `armored` class.**~~ Built: three procedural sheets with an opaque
  crushed core, selected off the pane's material. §15.3.




---

## 15. CRACK-05 — the cook's own hole, and the pane that holds (2026-09-04)

**Status:** 🟢 **BUILT.** §14.5's two open items, closed. G-D28's `armored` class
is on screen; the cook names the shape of the hole it opens.

### 15.1 What was added

| | |
|---|---|
| `WorldDelta.glass_openings` | the blast's holes as a PROPOSAL; `commit(room)` is the only claimer |
| `DetonationPlanBuilder._shatter_glass_panes()` | proposes one entry per pane it takes, at the flood's ORIGIN |
| `GlassCrack.sheet_id_for()` | the single answer to "which sheet" — opening › armoured core › the smallest member's page |
| `GlassCrack.ARMORED_SHEET` + `plan["armored"]` | read off the pane's material/class in `plan_pane_crack()` |
| `gen_fracture_sheet.py --only armored` | 3 sheets, an opaque crushed core, a 24 × 12 voxel page |
| `INFILTRAITOR_CAPTURE_ACTION=glass_blast_demo` | one grenade in front of a chosen pane, on the real map |
| `INFILTRAITOR_CRACK_DEMO_MATERIAL` | the crack demo, aimed at one member of the family |

### 15.2 ⚠️ THE COOK'S CLAIM IS CORRECT AND CURRENTLY LATENT, AND THAT IS A
### BALANCE FACT

Measured on `maps/GLASS.map.json`, not reasoned:

    ring 0   glass_punch 8.50   region_radius 42 voxels   flooded 1152 of 1152
    ring 1   glass_punch 5.10   region_radius 22 voxels   flooded  966 of 1152
    ring 2   glass_punch 2.12   region_radius  4 voxels   P(shatter) 5.9 %
    ring 3   glass_punch 0.00   — the blast does not reach

The pane is 48 × 24 voxels. At ring 0 and ring 1 the flood radius is larger than
the pane, so **a won roll takes the whole thing** — and a hole with no glass
around it has no rim for an opening to shape. Only ring 2 leaves one. Its roll is
deterministic in `(source_gu, pane_id)`, and reproducing the FNV-1a offline over
every in-line grenade cell against all three of the map's panes returns **no
winner**: the visible case does not occur on this map at all.

So the claim's effect today is the RECORD — a blast hole now keeps its shape
through a perspective flip, which the shot path's holes have done since CRACK-04
and the cook's had not. Everything else waits on either a balance change or a
bigger pane. **This is worth stating rather than implying**, because a reader of
the code would reasonably assume the shapes were now varying on screen.

⚠️ It also names where the cook's glass work actually belongs next: **§6.2, the
crack near a blast it SURVIVES.** That is the fringe case with something to draw,
it is the caller G-D29's `blast_*` sheets exist for, and it is now reachable —
a pane that rolled and held says so in the log.

### 15.3 G-D28's `armored`, and the one rule that made it cheap

The class needed no new plumbing at all. A sheet is looked up by a KEY in
`fracture_manifest.json`, and CRACK-04 had already made that key an opening id —
so `armored` is simply a key that is not an opening. What it must never be is a
member of `GlassOpening.FAMILY`: a member is pickable by `pick()` and cuttable by
`refresh_glass_rims()`, and G-D15's whole point is that this pane loses no voxel.
`check_decal.py` now reads that distinction out of `glass_crack.gd` rather than
holding its own list, and REQUIRES the row.

**What the sheet draws** (`gen_fracture_sheet.py`, `PRESETS["armored"]`): an
opaque crushed-white core — a solid heart, ~500 facets fading outward, a ragged
lip straddling the boundary — then 26 dense radial needles at a fine stroke, and
a secondary craze field of ~900 short TANGENTIAL cracks between 2.2 and 8.5 core
radii.

⚠️ **The field is its own population, and the first version proved why.** Reusing
the wave generator at a bigger radius drew a handful of long zigzag polylines out
in the dark — the mandala trap's opposite number, reading as scattered lightning
rather than as a field. A craze field is MANY SHORT cracks, mostly tangential,
none of them bright.

### 15.4 The evidence

- `glass_armored_sheet_ab_2026-09-04.png` — **a same-binary A/B**, one map, one
  weapon, the armoured branch switched off for the left half. Before: a dark bore
  ringed by a crush rim, on glass nothing pierced. After: the crushed core.
- `shot_c05_armored_3_damage.png` — the REAL shot path (`agent_shot`, pistol,
  agent 6,13 → guard 6,7): `glass_armored:s1 cracked=72 dented=0 destroyed=0`,
  and the round carries on into the concrete behind (`dented=1`).
- `glass_crack_demo_armored_{before,after}.png` — the demo, which now derives
  "this pane gets no bore" from the pane instead of taking a flag.
- `glass_blast_demo_{before,after}.png` — the cook's ring-0 case: 1152 voxels
  flooded, 1152 shards landed.
- Selftests: `glass_shatter` **[20]** (the proposal and the commit, red on both
  halves) and `glass_crack` **[17]** (the selector's three cases, the span
  following the pick, the three sheets on disk, `armored` NOT in the family, and
  the class read off the pane rather than off the weapon).

⚠️ **`check_decal.py --material glass` still reports one WIRING FAIL, and it is
PRE-EXISTING** — verified by running HEAD's own copy of the gate against a
manifest with the `armored` row removed. It is the shard family's
`IMPACT_DECAL_MATERIALS` branch, whose own comment says glass must NOT be added
to that list; the gate has no third state for "correctly absent". Untouched here.

### 15.5 The Director's three rulings on the delivered sheet (2026-09-04)

Shown the class on the real pane, he kept the art and changed three things:

1. *"Tem que diminuir mesmo o decal"* → **10 × 5 voxels**, picked off
   `glass_armored_span_strip_2026-09-04.png` — one boot, the same crack redrawn
   at 24 / 18 / 14 / 10, only the quad moving.
2. *"Tira um pouco a opacidade do centro, queremos ver um restinho do fundo"* →
   the heart's luminance is **205**, not 255. ⚠️ **Tuned in the ART, not in the
   shader:** `crack_opacity` is 0.80 for every crack in the game and was ruled
   once for the whole track, so the sheet's own ink is the per-class knob. Luma
   IS the alpha, so the core lands at 205/255 × 0.80 = **64 % opaque**.
3. *"3 versões diferentes pra cada calibre"* → **two classes on G-D14's existing
   blowout split**, `armored_tight` (10 × 5) and `armored_wide` (16 × 8), three
   variants each. Nothing but the SPAN differs between them.

### ⚠️ 15.5a The trap inside ruling (1), which the fix for (3) had to solve first

The strip he chose from moved **only the quad** — the art was the span-24 page
rescaled. Regenerating at span 10 with the core still measured in VOXELS would
have kept the core at 0.6 voxels while the needles shrank with the page: **a core
2.4× larger relative to its own needles than the frame he approved** (2.5 % of
the page at span 24, 6.0 % at span 10).

So `ARMORED_CORE` is now a fraction of the page's **half-width**, not a count of
voxels. The distinction is not cosmetic and it is the class's own: every other
member is anchored in voxels because it is generated from a real OPENING — a hole
is a fixed size on the pane whatever page it is drawn on. `armored` has no hole,
nothing anchors it, and its composition is therefore page-relative. That is also
what lets one preset body serve both calibres with the span as the only
difference. Verified by looking:
`glass_armored_calibres_2026-09-04.png` puts the approved frame beside the
regenerated `tight`.

### 15.6 Left open

- **§6.2 / G-D29 `blast_*`** — see §15.2. The trigger is now one branch away.
- ~~**The armoured page's SIZE is a dial.**~~ Ruled: 10 × 5 and 16 × 8 (§15.5).
- **G-D35 — the blast craze family.** Ratified the same day; **B-1 built
  2026-09-04**, B-2..B-5 open. §16.


---

## 16. G-D35 — the blast craze family (ratified 2026-09-04 · B-1 BUILT · B-2 NEXT)

The last piece of glass, and the Director's brief for it is specific enough to
stage. It is **not** a variation on the bullet classes; every property below is a
departure from them, which is what makes it cheap.

> *"As explosões ou vão destruir a vidraça toda, ou vão deixar rachado com maior
> ou menor intensidade, dependendo da distância. […] conseguimos criar padrões
> mais e menos destruídos (usando o mesmo mecanismo de cortar as bordas dos
> voxels nas beiradas), e mais e menos rachados (granularidade). Nesse caso também
> queremos que alguns decals sejam perfurados aleatoriamente em alguns voxels.
> Como são mais regulares, esses tipos de rachadura podem ser espelhados/repetidos
> com o método de azulejos, só mudando os buracos de lugar."*

### 16.1 What is different from every sheet built so far

| the bullet / armoured classes | `blast` |
|---|---|
| ONE impact, and the page centre goes on it | **no centre at all**; the pane is crazed, not struck |
| the page is sized from the hole (`SPAN_RATIO`) or stated | the page is a **TILE**; the pane is covered by repeating it |
| variation = 12 openings × 3 variants of art | variation = **mirror/repeat + where the holes are** |
| the hole is one opening, claimed at the impact | **several voxels perforated at random** across the pane |
| `check_decal.py`'s ORIGIN rule applies | it must **not** — a field has no centroid to check |

### 16.2 The two axes, and why they are two

**Destruction** — how much of the pane is gone — is already built: it is the
opening/shard-rim mechanism, *"o mesmo mecanismo de cortar as bordas dos voxels
nas beiradas"*. Nothing new is needed for it beyond choosing how many voxels go
and where.

**Granularity** — how fine the craze mesh is — is the ART axis, and it is what
the reference photos are about: a near blast crazes into small polygons, a far
one into large ones. Two or three steps, not a continuum.

Distance drives both together, which is what §6.2 already reserves: *"a crack
radius one or two rings beyond the destruction radius"*.

### 16.3 The staging this implies

| | |
|---|---|
| **B-1 ✅** | **BUILT 2026-09-04 — the trigger.** §16.5. A pane the blast reaches and does not take goes CRACKED, whole, with an intensity from its ring. |
| **B-2 ✅** | **BUILT 2026-09-05 — the tiling seam.** §16.8. A second sprite mode: the quad is the pane's own rectangle and the sheet repeats across it, wired end to end from `delta.glass_crazes` through `commit()` to a rotation replay. ⚠️ **The unknown this row predicted was not the real one** — a panel pane is coplanar by construction, so there is no fold to seam at; the phase ANCHOR was. |
| **B-3 ✅** | **BUILT 2026-09-05 — the art.** §16.9. Two granularities (G-D37), a Voronoi mesh on a TOROIDAL metric, 3 variants each. The whole path lit up with **no code change**, which is what B-2's stage gate was for. |
| **B-4** | **NEXT.** **The perforation**: N voxels punched per pane, chosen by B4 FNV-1a on the BASE key so a flip does not reshuffle them — the same rule G-D34 already lives by — and cut with the openings that already exist. |
| **B-5 🟢** | **The gate — MOSTLY LANDED WITH B-3, because art whose defining property is unverified is not delivered.** `check_decal.py` learns the class (read off `CRAZE_SHEET_*`), skips the ORIGIN rule for it, and runs a SEAM check in its place. ⚠️ It also removed a constant: the aspect rule was never "2:1", it was "the aspect must match the SPAN", and the manifest now answers per sheet. What is left for B-5 proper is B-4's perforation coverage. |

### 16.4 ✅ BOTH RULED 2026-09-05 — what B-3 now builds

- ~~**How many granularity steps**, and whether the coarse end is a different mesh
  or the same one at a bigger scale.~~ **G-D37 — a different mesh**, and the
  Director's own word for it is *"parecida"*: one generator, a second parameter
  set (same Voronoi body, same wrapping seed rule, same stroke, fewer and blockier
  cells), not the fine sheet at a bigger scale and not a second vocabulary.
  **TWO steps as a floor**; a third middle one is that generator a third time and
  is decided by looking at B-3's output, not in advance.
- ~~**Whether a crazed pane still blocks sight.**~~ **G-D36 — it does not block
  it; it penalises it, heavily.** The pane keeps transmitting (G1's blend is
  untouched) and the TACTICAL term degrades — `LIGHT_MASTER_PLAN`'s split, exactly
  as §16.4 predicted the shape of the answer. ⚠️ **A penalty, never a block:** the
  binary version would let one grenade delete a sightline and turn a craze into a
  smoke wall. The magnitude is a balance number and lands with G-D8's detection
  work, not with the art — **so it does not gate B-2 or B-3.**
- 🔒 The two reference photos are read for **vocabulary only**. Delivery stays
  procedural — D57, and the same discipline §8's watermarked comps already
  imposed on this very track.


### 16.5 ✅ B-1 IS BUILT (2026-09-04) — the trigger, and two things it measured

`GlassShatter.plan_pane_craze()` + `DetonationPlanBuilder._craze_pane()`:
a pane the blast reaches and does not take goes CRACKED, **whole** (G-D2), with
`CRAZE_RING_INTENSITY[ring]` riding out on `WorldDelta.glass_crazes` for B-3 to
read. Real map, grenade at gu (14,13) on `maps/GLASS.map.json`:

    [GLASS-CRAZE] pane=PANE_SLICE_16_10_SW ring=2 intensity=0.55
                  — pane STANDS, 1152 voxel(s) CRACKED

**Nothing changes on screen, and that is the point of doing it first.** G-D35's
sheet is a tiled centreless field; drawing today's centred bullet page over a
blast-crazed pane would be the wrong art wired to a real trigger — worse than no
art, because it would look finished.

#### ⚠️ §6.2's predicted new BFS was not needed, and that is a measurement

§6.2 asked for *"a crack radius one or two rings beyond the destruction radius,
reusing the same BFS the soot derivation already walks"*. `flood_gu_rings()`
already floods to `ring_multipliers.size() - 1`, and frag_grenade's last entry is
**0.0** — so **ring 3 is already in `affected` and takes no damage at all**. The
ring beyond the damage radius was there the whole time; the two cases §6.2 and
G-D35 describe (the pane inside that held, the pane outside that was never at
risk) turned out to be one branch.

#### ⚠️ 576 of 1152 crazed voxels would never have been persisted

`PHASE_PACKAGE` is what fills `touched_voxels`, and it walks `ring_of` — which
`_phase_slices` fills only for the slices in `affected`. The blast reached **3 of
this pane's 6 slices**; a craze takes all 6 by design. So half of every crazed
pane would have been dropped by VL-PERSIST with nothing in any log to say so.
Topped up after PACKAGE (not at the craze: PACKAGE appends unconditionally, and
flagging `touched_this_blast` early would silently change what `_phase_soot_wave`
repaints). Now `[GLASS-CRAZE] 576 of 1152 ... added to the persistence set`.

### ✅ 16.6 THE PANEL ROTATION DEFECT — FIXED 2026-09-05, AND THE DIAGNOSIS
### BELOW IT WAS WRONG FOR TWO DAYS

**The symptom, measured 2026-09-04 and reproduced unchanged on 2026-09-05:**

    [VL-PERSIST] perspective E — 441 of 1593 re-applied, 1152 had no voxel
    cracked glass voxels: 1152 before the flip, 0 after (LOST 1152)

**441 = exactly the FLOOR records; 1152 = exactly the pane.** v1.28 read that as
a persistence bug and wrote the fix down as *"a base-space key that carries the
FACE."* ⚠️ **It is not a persistence bug and that fix would have built a second
key for nothing.** The key was correct: it pointed at where the pane should have
been after a quarter turn, and **the pane had not moved.**

`PerspectiveMapper.layout_with_perspective()` rotates `wall_tiles`, `wall_levels`,
`structure_tiles`, `blocked_cells`, `blocked_edges`, `enemy_defs`, `exit_cells`,
`light_sources`, `solid_block_instances`, `floor_zone_instances` and
`voxel_prop_instances` — and rode `panel_instances` through `duplicate(true)`
**unrotated**, which is where every half-thickness element lives, G-D9's windows
included. **That is ROOF-BAKE-02a for the third time**, on the one key nobody had
added to it. `room.gd`'s own comment had carried the correct cause since
2026-09-02 (*"seven of the GLASS map's eight panes have IDENTICAL cells in N and
in E"*) — it was read as a separate map defect and never connected to the rotation
symptom the blast demo reported two days later.

#### The fix, and why it is two halves

A panel is a **POINT plus a FACE**, so both rotate. The block branch above would
place it and leave it facing the wrong way — the silent version of the same
defect. The face table is not a new one: `SUFFIX_MAP` is proven equal to
`Face.delta()` under a quarter turn (E sends (dx,dy)→(−dy,dx), so NW→NE, NE→SE,
SE→SW, SW→NW, row for row), and `slice_voxel_positions()` puts those faces on
local col 0 / row 0 / col 7 / row 7, which the 8×-resolution cell rotation carries
onto exactly the plane the remapped face occupies. `remap_face()` and
`remap_tile_name()` now share one `_remap_suffix()` — a wall carries its face in a
tile-name suffix and a panel carries it in a field, and they are ONE rotation.

#### The evidence

| | before | after |
|---|---|---|
| `GLASS_BLAST_FLIP=E` | 441 of 1593, **LOST 1152** | **1593 of 1593**, KEPT 1152 |
| `GLASS_BLAST_FLIP=S` | — | **1593 of 1593**, KEPT 1152 |
| `GLASS_BLAST_FLIP=W` | — | **1593 of 1593**, KEPT 1152 |
| `CRACK_DEMO_FLIP=E` (the SHOT path) | `0 crack(s) rebuilt, 1 without a pane` | **`1 of 1` hole + `1 crack rebuilt, 0 without a pane`** |
| PLAYGROUND four views (**control — no panels**) | — | `460 of 460` × E/S/W, 0 missed |

⚠️ **The four-view A/B has a 0-pixel control and it is load-bearing.** Both sides
come from the same binary (the change stashed and re-run) on the same map:
**N differs by 0 pixels**, E/S/W by 245 757 / 268 935 / 311 376. A diff whose
control is not 0 says nothing; this one says the harness is deterministic AND that
the change is a no-op exactly where the identity requires it.
`glass_panel_rotation_ab_2026-09-05.png` — top row the panes standing still,
bottom row the panes turning with the map.

#### ✅ And CRACK-02 S-3 is only now actually proven

Its acceptance was a ROUND TRIP (`"E,N"`), where `cell_from_base` is the identity
— exact and tautological in the same way selftest [10] was before CRACK-04 found
it. On a SINGLE flip it rebuilt **0 of 1**. It rebuilds **1 of 1** now, and that
is the first time the claim has ever been tested.

#### The selftest that was missing, and the shape of the hole it left

`voxel_persist_selftest` had two properties, both green throughout: the base↔view
round trip is exact, and a voxel stays inside its rotated GU. **Neither can see
this defect** — the coordinates were right; the geometry they pointed at was not.
New test **[3]** asserts the identity instead: the rotated panel's voxel PLANE
equals the rotation of the original panel's voxel plane, over 16 placements × 4
directions, through `layout_with_perspective()` itself. ⚠️ It asserts an IDENTITY,
not a change — *"the panel entry is different"* would pass for a gu_cell rotated
with the face left alone. Proven RED with the fix stashed, green with it back.

#### ⚠️ Two more keys ride `duplicate(true)` unrotated — REPORTED, NOT FIXED

Found while reading `layout_with_perspective()` for this fix, and out of its
scope:

- **`junction_overrides`** — cell-shaped, and `room_builder.gd:786` reads it off
  the ROTATED layout. Same shape of defect as this one.
- **`playable_rect`** — a `Rect2i` whose w/h must swap under E/W. `room.gd:2206`
  reads it off `_base_layout` (the unrotated one), so it may well be deliberate;
  it needs a look before it is called either way.

Neither is glass, both are one branch each, and guessing which is intended is how
an unrequested cleanup breaks every wall in the game (2026-07-12).

### 16.7 What B-2 inherits

- The trigger, with its intensity, on `delta.glass_crazes`.
- `_count_cracked_glass()` + `INFILTRAITOR_GLASS_BLAST_FLIP`, the only instrument
  that can see any of this: **CRACKED glass renders exactly like intact glass**,
  so no screenshot can tell a crazed pane from a clean one until B-3 exists.
- ~~§16.6, which B-2 has to decide whether to wait for.~~ ✅ **Fixed first, on the
  Director's call (2026-09-05).** A tiled sheet had the same base-space problem as
  a voxel one level up, and it no longer has it — a panel now rotates, so a sheet
  anchored on the pane's own rectangle rotates with it. B-2 is not building on a
  seam known broken.
- **G-D36 and G-D37** (§16.4): two granularity meshes from one generator, and a
  crazed pane that still transmits. Neither gates B-2 — the first is B-3's, the
  second is a balance number in G-D8's detection work.


### ✅ 16.8 B-2 IS BUILT (2026-09-05) — the tiling seam, end to end

`GlassCrackSprite.setup_field()` + `GlassCrack.plan_pane_field()` +
`VoxelRenderer.spawn_glass_craze()` + `Room.claim_glass_craze()` /
`_respawn_base_crazes()`, and one branch in `WorldDelta.commit()`. The whole path
from B-1's trigger to a node in the scene.

#### It is a MODE, not a parameter — three things change together

| the page (every sheet so far) | the field |
|---|---|
| the quad is a page centred on an impact | the quad is the **pane's own rectangle** |
| UV **is** the sheet | UV is the pane; the sheet's UV is a **lattice** in (run, level) |
| the feather fades the ink at the page's edge | **no feather** — a field ends at the FRAME, and fading it draws a vignette no glass has |
| `crack_opening` cuts the sheet's void | never bound: a craze opened no hole |

The pane clip and G-D30's occupancy cut are shared **verbatim**. A field must not
bleed past the pane and must not draw on glass that is gone, for exactly the
reasons a page must not — and a G-D9 banded pane's brick sill falls out of the
field for free, the same way it falls out of a web (§13.5).

#### ⚠️ The unknown §16.3 named was not the real one

That row warned that *"the pane is a parallelogram in screen space and the tile
must not seam at the fold."* **There is no fold.** `GlassPaneGrouper` unions
panels that are coplanar and adjacent along the run axis, so a panel pane is one
flat face by construction — the parallelogram is the sprite's own transform,
which has baked the forward basis since CRACK-02 and needed nothing new.

The real unknown was the **phase anchor**, and it is not where the obvious answer
puts it. `Sprite2D.centered` makes the quad symmetric about its origin, and a
pane with an even side has its true middle on a half voxel — so the quad's centre
moves relative to the glass whenever that asymmetry changes. The lattice is
anchored at the pane's **low-run / low-level corner** instead (`crack_field_origin`),
which does not move. Selftest [18] pins it on an asymmetric pane specifically,
because on a symmetric one the two anchors coincide and every assertion passes
either way ([[symmetry-hides-bugs]], again).

#### One registry, and the one place that must tell the two apart

A field record lives in `_glass_cracks` beside the impact cracks — one lifecycle,
one occupancy refresh, one visibility switch, instead of a parallel array and five
duplicated helpers. `glass_crack_covering()` is the only reader that must exclude
it, and **the reason is gameplay, not tidiness**: G-D24 drops the piece where two
FRACTURES cross, and a craze is the whole pane at once. Left in, every
blast-crazed pane would answer "covered" for every cell, so the next round
anywhere on it would DESTROY what it touched instead of cracking it — a silent
balance change nothing would have failed on.

The record's `impact_run` / `impact_level` / `impact_cell` are the pane's **centre
cell**, not an impact. A craze has none; but `_build_crack_occupancy()` is written
against exactly those three keys plus the pane bounds, and giving the field its
own copy of that walk is how the two modes' cuts would drift the first time one
was fixed.

#### The stage gate — wired, and drawing nothing

`spawn_glass_craze()` returns 0 until `fracture_manifest.json` carries a `blast_*`
row, and says so once per boot. **That is the ordering, not a gap:** §16.5's rule
is that the wrong art on a real trigger is worse than none, because it looks
finished. Every other seam is live, so B-3 lights this up with no code change.

⚠️ **This is deliberately NOT a B6 loud-fail.** B6 is about a missing dependency;
this one is not missing, it is not built yet, and on purpose.

#### The evidence

- **The seam closes.** `INFILTRAITOR_GLASS_CRAZE_TESTTILE=1` draws a tile that
  wraps by construction — rings on the corners and edge midpoints, a centred
  square, a full-page diagonal. On the real pane every ring closes into a full
  circle across its tile boundary and the diagonal runs straight across six tiles.
  It is obviously a test pattern and could never be mistaken for the art, which is
  the point of using one. `glass_craze_field_seam_2026-09-05.png`.
- **It survives a rotation.** `[GLASS-CRAZE] perspective E — 1 field(s) rebuilt
  from base coords, 0 not rebuilt`, beside `1593 of 1593` and `1152 KEPT`. Only
  reachable at all since §16.6.
- **The shipped path is byte-identical: 0 pixels**, on the shot-path crack demo,
  against a determinism control of **0 pixels** measured first. This matters
  because the change touched the shader every existing crack draws
  (`repeat_enable`, and the mode branch).
- Selftest **[18]**, seven assertions, proven RED two ways: a quad sized from one
  side only fails on the asymmetric pane, and a field reading `slice.material`
  instead of `material_at()` runs over a G-D9 brick sill (`spans 80..95, expected
  82..93`). 50 selftests clean, 113 PASS in `glass_crack`.

#### ⚠️ The blast demo cannot host a pixel gate, and now that is measured

Two identical runs of `glass_blast_demo` differ by **160 276 pixels**. Its wait is
240 frames — 4 s at `--fixed-fps 60`, still inside the fire and smoke lifetimes,
and `spawn_blast_burst()` places embers with `randf_range()`. It is the same
finding as the 45-frame / 400-frame measurement of 2026-08-09, at a third point on
the same curve. **A B-2 or B-5 pixel gate has to live on the crack demo**, which
measured 0.

#### What B-3 inherits

- The tile's SIZE is `fracture_manifest.json`'s own `span` row — for this class
  the page IS the tile, so B-3 authors it and the engine holds no second number.
  `GlassCrack.page_span()` is the one reader.
- Two keys: `blast_fine` and `blast_coarse`, split at `CRAZE_FINE_MIN = 0.5`, so
  rings 0/1 craze fine and 2/3 coarse. ⚠️ [18] pins the DIRECTION — a near blast
  is the fine mesh — because inverting it fails no geometry test and every
  picture.
- Variants ride `pick_variant()` on a BASE key, which is G-D29's three-patterns
  pool arriving for free rather than as a second mechanism.
- 🟡 **Open, and named rather than left to be found:** the lattice is anchored at
  the pane's corner *in the current view*, so a pane whose width is not a whole
  number of tiles shows a different tile PHASE in E/S/W than in N. It is
  deterministic per view (no reshuffling on a camera turn, which is G-D29's actual
  requirement) but not identical across views. The fix is a phase carried in base
  space; it is not built because rotation is suspended for performance and nothing
  can currently see it.


### ✅ 16.9 B-3 IS BUILT (2026-09-05) — the craze art, and the gate that can see it

`gen_fracture_sheet.generate_blast()` + `blast_openings()`. Two manifest rows,
`blast_fine` and `blast_coarse`, three variants each, 512 × 512 grayscale on
black, span 8 × 8 voxels.

**The whole runtime path lit up with no code change**, which is exactly what B-2's
stage gate existed to make true: the first boot after the manifest gained its rows
went `craze fields: claimed=1 live=1` and the pane came back crazed.

#### Why a toroidal Voronoi, and what it replaced

The metric wraps every offset into `[-0.5, 0.5)` before taking the distance, so a
seed near the left edge is genuinely a neighbour of the pixels on the right.
**Nothing is mirrored, blended or fixed up at the border afterwards; there is no
border.** That is what §16.3 meant by *"tiles by construction"*, and it is why
the class is cheap where twelve openings × three variants were not.

⚠️ **No replica grid.** The obvious implementation surrounds the page with 9
copies of the seed set. Wrapping the offset is the same answer for a ninth of the
arithmetic — and, more to the point, it cannot be *slightly* wrong at one edge the
way a replica grid can.

The mesh is the cell BOUNDARY, recovered as `F2 − F1` (twice the distance to the
bisector), so a smooth falloff draws an antialiased line with **no supersampling
at all** — the radial sheets need `SS = 2`; a distance field does not.

Two touches keep it off the machine:

- **Lloyd relaxation, on the torus.** Tempered glass breaks into cells of fairly
  even size; raw Poisson seeds give a scatter of tiny and huge ones — cracked mud,
  not a shattered pane. ⚠️ The mean must be taken over WRAPPED offsets and added
  back to the seed; averaging raw coordinates drags every edge seed to the middle
  of the page, silently.
- **A per-EDGE depth**, hashed from the unordered pair of cell indices, so some
  cracks read deeper than others. Per EDGE, not per pixel: a pixel-noise version
  modulates *along* each crack and reads as a bad brush.

#### ⚠️ G-D37 is honoured by the CELL COUNT, not by the span

Both classes are 8 × 8 voxels and differ in cells per tile (210 against 58). That
is what makes them *a different mesh* rather than *one mesh at a bigger scale* —
the reading the Director explicitly rejected. Change the span instead and the
coarse sheet is literally the fine sheet zoomed.

#### ⚠️ AND THE SPLIT POINT WAS WRONG IN A WAY ONLY THE REAL TABLE SHOWS

B-2 shipped `CRAZE_FINE_MIN = 0.5` with a comment claiming it put rings 0/1 fine
and 2/3 coarse. `CRAZE_RING_INTENSITY` is `[1.0, 0.80, 0.55, 0.30]`, so 0.5 put
**three** of the four rings on the fine sheet and left the coarse mesh reachable
at ring 3 alone — half of G-D37's art almost never drawn, with every geometry
assertion still green. Now **0.67**, which sits between 0.80 and 0.55.
Selftest [18] pins REACHABILITY (≥ 2 rings each) beside the direction, proven RED
at 0.5. *The midpoint of a table's endpoints is not the midpoint of its rows.*

#### The gate learned the class, and lost a constant doing it

- `_classless_sheets()` reads `(?:ARMORED|CRAZE)_SHEET_*` — the runtime still owns
  which ids are not openings.
- **The ORIGIN rule is skipped for a tile class, and that is the point.** A
  uniform field satisfies "the ink centroid is the page centre" TRIVIALLY —
  measured at (−0.8 %, +0.4 %). A check that passes for reasons unrelated to what
  it checks is worse than no check: it reads as coverage and provides none.
- **A SEAM check replaces it, and it is a real measurement.** On a page that
  wraps, the first and last columns are neighbours, so their mean absolute
  difference should look like any other adjacent pair. ⚠️ **The threshold was
  measured against both sides before it was written:** the shipped `blast_fine`
  scores **1.14 / 0.99**, and a page drawn with the toroidal wrap REMOVED — the
  shape of not tiling — scores **3.15 / 3.72**. 2.0 sits between them with room
  each side.
- ⚠️ **The aspect rule was never "2:1".** Line 161 of the gate had said for months
  that *"a sheet whose aspect disagrees with its SPAN is stretched on the pane"*,
  and 2.0 was true of every span that existed — so the constant and the rule were
  indistinguishable until a class arrived whose span is square. It would have
  rejected correct art with the message *"square; the span is 2:1"*: a gate
  confidently wrong. The span is read from the manifest per sheet now.

#### The evidence

- `glass_craze_granularity_2026-09-05.png` — both meshes on the real pane, whole
  frame and zoomed. No visible tile seam in either.
- **The 42 shipped sheets came back byte-identical from `--all`, 0 different.**
  Hash-compared, not assumed — §15.3's near-miss cost 36 files to a rounding error
  in a default, and a generator that cannot reproduce its own output is the B4
  failure this project bans.
- `check_decal.py --material glass`: **48 sheets checked, 0 failed**; wiring
  reports all 12 openings plus 4 non-opening sheets. The one WIRING FAIL is
  pre-existing (the shard family's `IMPACT_DECAL_MATERIALS` branch, which has no
  third state for *correctly absent*).
- **The shipped shot path is 0 px** against B-2, on a harness whose determinism
  control measured 0.
- 50 selftests clean; [18] now nine assertions.

#### What B-4 inherits

- Perforation is chosen **per voxel** and is NOT in the art — G-D35 says so, and
  the tile carries no holes. B4 FNV-1a on the BASE key, cut with the openings that
  already exist.
- The rotation note from §16.8 stands and now has the Director's own direction
  behind it (2026-09-05: *"desejamos ter rotação futuramente"*): the tile lattice
  is anchored in the CURRENT view, so a pane that is not a whole number of tiles
  wide shows a different PHASE across views. ⚠️ **Everything else here is already
  rotation-safe, and the tile is the friendliest possible choice** — level is
  rotation-invariant, and mirroring an irregular craze mesh is invisible (G-D29
  even wants the flips as free variation). The phase is the one line, and it is
  `plan_pane_field()`'s, not the art's.
