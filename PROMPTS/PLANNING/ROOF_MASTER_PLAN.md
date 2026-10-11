# ROOF MASTER PLAN — destroyed roofs

> **Status: 🟡 v0.2, 2026-10-11 — opened by the Director; R-D1 to R-D3 ruled; nothing built.** *"Faltam os telhados destruídos na engine. Vamos colocar
> eles na frente do modelo, porque acho que é uma das últimas coisas que falta destruir. […] Vamos iniciar os trabalhos pelo telhado
> de vidro, os demais seguem ele como modelo, adaptando para cada tipo de material com suas características específicas."*
>
> **Place in the order:** roadmap step **A1d**, BEFORE A1b (the agent's final model). It completes destruction in the engine; the
> glass track that opened the rule (G-S1 / G-D53) is closed (`GLASS_MASTER_PLAN` top block, 2026-10-11).
>
> **Related:** `GLASS_MASTER_PLAN` G-D50 to G-D55 (the support rule, the collapse, the crossfade: this plan's model), G-D16c/d
> (skylights, `lift`); `PROMPTS/DONE/EXPLOSION_REBUILD_MASTER_PLAN.md` D14-D18 (roof falloff, a roof hit from above, slab piercing,
> roof destruction = a LIGHTING event); `PROMPTS/DONE/DESTRUCTION_MASTER_PLAN.md` §2b; `VOXEL_LIGHT_MASTER_PLAN` VL-D3;
> `docs/systems/LIGHT_MASTER_PLAN.md` (the Directional class); `PROPS_TIER4_PLAN` (the pile, falling voxels of opaque materials);
> `RENDER3D_MASTER_PLAN` (the roof entity, R3D-ROT occlusion); `PERFORMANCE_BUDGET_MASTER_PLAN` (the segment's budget).

---

## 0. Canon this plan does not reopen

| Rule | Source | Consequence here |
|---|---|---|
| **Roof destruction is a LIGHTING event, never an access route.** The upper storeys compose the scene's height; the player never goes up. | EXPLOSION_REBUILD D18; Director 2026-08-06 | A hole matters for what it lets IN (light) and for what falls DOWN. No pathing, no "entry from above". |
| **The support rule (G-D50) and the collapse (G-D51/52/55).** A voxel stands while it is connected to something that holds it; what loses support falls after the blast, crossfaded. | `GLASS_MASTER_PLAN` 1a, 1f | The roof's collapse is the SAME machinery, generalised from panes to roof slabs. |
| **G-D53 — all roofs, by material; shots count.** Each material its own chance to hold: stone barely affected, plywood collapses more easily than wood; fabric may SAG (a partial fall by distance, the cloth hanging down) — to be designed. Glass first. | `GLASS_MASTER_PLAN` 1a | The per-material table of §3 and the fabric stage. |
| A roof is an entity (`roofs`: gu, size, storeys, material, kind); 2 levels thick; built as `Slab` Role.CEILING; only `kind: flat` exists. | RENDER3D roof entity; `room_builder.gd:258, 269-340` | Pointed / diagonal roofs stay out of scope. |
| The frag grenade is the stress case; 200 ms hit-stop ceiling; budgets judged on the Moto g04s. | roadmap 2026-10-07 | Every stage is measured on the Moto with the GLASS-style take. |
| No all-glass rooms in INFILTRAITOR 1. | Director 2026-10-07 | A glass roof is a skylight or a roof panel over a room with ordinary walls. |

## 0b. Director's rulings (2026-10-11)

- **R-D1 — THE LIGHT ABOVE A ROOF (answers Q1).** *"Vamos ter luz externa em alguns cenários mais abertos (sol, lua, nublado, ambiente). Mas em geral os cenários serão internos e as luzes vão afetar zonas internas menores. Seria basicamente o conceito de um galpão com cubículos/aposentos, que vão ter sua luz própria, mas que também podem ser influenciados pela luz maior quando o telhado quebra."* So the light a hole lets in is **whatever light is ABOVE that roof**: the map's outdoor light (one of sun / moon / overcast / ambient, open scenes only) or, in the common case, the enclosing hall's own light over a cubicle's roof. A room keeps its own lamps; breaking its roof ADDS the larger light through the hole.
- **R-D2 — SHOTS REACH ROOFS (answers Q3).** *"Os tiros por natureza são horizontais atualmente […] Nós vamos querer porém ter o gameplay onde o agente deliberadamente atira no telhado para causar alguma mudança no cenário. […] na prática vai ser o mesmo comportamento do vidro vertical, mas com as consequências, chuva, pó, caindo pra baixo."* A shot aimed at a roof behaves as a shot on a vertical pane (the hole, the craze, the support rule, G-D49's re-damage), with the consequences falling DOWN (rain, dust). The aiming gesture (how the player targets a roof) is designed with the interface, not here; the engine takes a shot whose target is a roof cell.
- **R-D3 — AN INTACT GLASS ROOF IS TRANSLUCENT (answers Q2).** *"O telhado de vidro intacto tem opacidade, de maneira que a luz passa, porém restrita. Quando o vidro é destruído ela fica acentuada (full)."* An intact glass roof lets a RESTRICTED share of the light above through (a per-material transmission factor); a broken cell lets it through in full.

## 1. What exists today (inventory, 2026-10-11)

- **A blast damages roof voxels:** `BlastCalculator` buckets every CEILING slab on a flooded GU (`hit_roofs`), `DetonationPlanBuilder._phase_roofs` runs the wall ring model on them (D14 falloff, `carved_side` always BOTTOM). The voxels vanish; WALK / SOOT / BURN see them.
- **Nothing else.** No debris, no falling pieces, no pile, no decal on a roof hole's rim; **a shot never damages a roof** (`AgentShotController` resolves a slice or a prop block only); **no support check** (`GlassSupport` only reads `store.pane`; a roof slab is never a pane), so a roof piece over walls that fell stays in the air (`GLASS_MASTER_PLAN` G-S1, the defect that opened the rule).
- **Glass roofs render OPAQUE** (G1: a CEILING slab is never a pane; `voxel_board.gd:882-884`) and break like any material: no shards, no rain, no craze. PLAYGROUND (`[38,2]`, 3×1) and STRESS (13×11) have glass roofs; no map has a skylight; `lift` is unused.
- **Light ignores a hole.** There is no sky / directional term in `VoxelLightField`; the "under structure" darkening (VL-D3, ×0.68) is taken from the INTACT build, so the floor under a hole stays as dark as under the roof. Only the voxels at the hole's edge brighten (`exposed_top`).
- **The reveal** (roof cutaway by slab adjacency, `OcclusionSet`) is keyed on slab objects, not voxel visibility: no tested interaction with a destroyed roof.
- **Fixtures:** OCCLUSION_ROOM (3×3 concrete roof), OCCLUSION_HALL (15×15), SEG_* (concrete), SURFACES_GALLERY; no take or POI on a roof. Roof selftests cover building and occlusion, none destruction.

## 2. The stages

Each stage closes with `verify.py` green, a desktop take judged by the Director, and a Moto run of the take (worst frame, PSS).

### RF-0 — the shared foundation (built WITH RF-1, so glass proves it)
1. **Roof support and collapse.** `GlassSupport`'s walk generalised to a slab: sources are roof voxels resting on a standing wall / column / block below (or touching a non-roof claim), reach by material (§3), the same off-thread walk after the event, the landing index, the crossfade, `GlassVoxelFall3D`'s motion. One support computation for panes and roofs.
2. **What falls lands.** Opaque material: the voxels fall and join a persistent pile (the Tier 4 pile's record); glass: they shatter into the rain and the floor shards, as panes do.
3. **The light comes in.** The floor (and walls) under a hole brighten: the cover term (VL-D3) read from the LIVE roof, plus whatever light the open sky gives (Q1). Applied by the consequence light, measured.
4. **The rim.** A roof hole's edge looks broken per material (glass: the jagged rim of G-D54; others: §3), and the reveal keeps working over a holed roof.
5. **A take and a fixture:** a map (or a POI on GLASS) with each roof type over an ordinary room, a grenade beside / under it.

### RF-1 — the GLASS roof (the model)
A glass roof becomes a horizontal pane: translucent when intact (R-D3), it cracks and crazes, breaks into shards and rain falling DOWN, holds by the support rule, collapses crossfaded, and lets the light above in when broken (R-D1; G-D53: "skylights … broken to change the room's light"). Reuses the pane machinery (crack field, opening masks, rim, rain, piles) on a horizontal face, then retires the G1 "glass roof stays opaque" exception. Steps, each closed with `verify.py` and a capture before the next:
1. **The fixture and the take.** A roof POI on GLASS (or a small map): a room with its own lamp under a glass roof, inside a larger lit hall, and an outdoor-lit open area; takes for a blast beside it and a shot into it.
2. **The roof as a pane in the store.** A glass CEILING slab gets pane claims with a horizontal face (`VoxelStore.pane`), so cracks, openings, the rim and `GlassSupport` see it; the 3D board draws it with the pane material (translucent, the top and bottom faces broad, the edges the rim). Every reader of `pane` that assumes a vertical face is listed first (Rule: list what a function else does).
3. **The light above (R-D1, R-D3), as a STATE the light field reads.** A per-roof "light above" (outdoor class or the enclosing hall's light) and a per-material transmission (glass < 1, opaque 0, a hole 1); the cover term (VL-D3) read from the live roof; the consequence light re-derives the cells under a changed roof. Measured on the Moto.
4. **Breaking it.** The blast path (`_phase_roofs`) runs the glass shatter on a roof pane (shockwave zone, crazes, openings, remnants), the rain and dust falling to the floor below, the floor shards.
5. **The shot (R-D2).** `AgentShotController` accepts a roof cell as the target: the point impact, the opening, G-D49's re-damage collapse, the rain down. The aiming gesture is out of scope (a dev scenario step fires it).
6. **The collapse.** `GlassSupport` with a horizontal pane's sources (resting on a wall / block / non-glass claim below or beside it) and the crossfaded fall.
7. **Devices.** The take on the Moto and the Galaxy, worst frame and PSS inside the segment budget.

### RF-2 onward — each material follows RF-1, with its own behaviour (§3)
Order proposed: **concrete / stone** (the common case: SEG_* maps), **wood / plywood**, **metal**, **fabric** (the sag, designed then), **cardboard / paper**.

## 3. Material behaviour (to calibrate on screen; values are starting points)

| Family | Holds (support reach) | When it goes | Rim / debris |
|---|---|---|---|
| glass | short (G-D50's values) | shatters: shards, rain, floor shards | jagged rim, craze around it |
| stone / concrete / brick | long ("barely affected") | chunks fall to a pile, dust | broken edge, dented underside |
| wood | medium | planks / chunks fall, splinters | splintered edge |
| plywood | short ("collapses more easily than wood") | sheets fall | torn edge |
| metal | long, bends rather than breaks? (Q5) | sheet pieces | bent / torn edge |
| fabric | — | SAGS: hangs down by distance from support (to be designed) | frayed edge |
| cardboard / paper | short | flaps fall, light | torn edge |

## 4. Questions for the Director (ask at the point each one blocks)

1. ~~Q1~~ — ruled, R-D1. 2. ~~Q2~~ — ruled, R-D3. 3. ~~Q3~~ — ruled, R-D2.
4. **Q4 — a grenade thrown ONTO a roof (D15-D17)** is designed but unbuilt (a roof hit from above behaves as a floor, one grenade pierces one slab). In scope here, or does the grenade stay on the playable plane?
5. **Q5 — metal roofs:** break like the others, or bend / hang (a sag like fabric's)?
6. **Q6 — the gameplay side of the light:** detection does not consume light yet (`LIGHT_MASTER_PLAN` status). This plan changes the VISUAL light; the tactical effect waits on that link. Confirm it stays visual here.

## 5. Records
- 2026-10-11 v0.2 — R-D1 (the light above a roof), R-D2 (shots reach roofs), R-D3 (a glass roof is translucent); RF-1 split into seven steps.
- 2026-10-11 v0.1 — opened (Director), inventory §1, stages RF-0/RF-1/RF-2+, questions Q1-Q6.
