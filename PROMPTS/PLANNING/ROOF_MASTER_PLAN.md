# ROOF MASTER PLAN — destroyed roofs

> **Status: 🟡 v0.1, 2026-10-11 — opened by the Director; nothing built.** *"Faltam os telhados destruídos na engine. Vamos colocar
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
A glass roof becomes a horizontal pane: transparent when intact (Q2), it cracks and crazes, breaks into shards and rain, holds by the support rule, collapses crossfaded, and changes the room's light when broken (G-D53: "skylights … broken to change the room's light"). Reuses the pane machinery (crack field, opening masks, rim, rain, piles) on a horizontal face, then retires the G1 "glass roof stays opaque" exception.

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

1. **Q1 — what light enters a hole.** The light canon has a *Directional* class (sun, moon, global ambient) that nothing implements yet. Does a hole let in the map's outdoor light (one per map: day / night / overcast), or only lift the "under structure" darkening back to the open-floor value?
2. **Q2 — an intact glass roof: transparent (a skylight: light already enters, you see the room through it from above) or opaque frosted glass?** Today it renders opaque.
3. **Q3 — do shots reach roofs?** G-D53 says shots count, but the agent shoots horizontally on the playable plane; a round would only reach a roof slab if it can be aimed upward or the target is a low roof. Keep shots for a later weapon, or define how they hit?
4. **Q4 — a grenade thrown ONTO a roof (D15-D17)** is designed but unbuilt (a roof hit from above behaves as a floor, one grenade pierces one slab). In scope here, or does the grenade stay on the playable plane?
5. **Q5 — metal roofs:** break like the others, or bend / hang (a sag like fabric's)?
6. **Q6 — the gameplay side of the light:** detection does not consume light yet (`LIGHT_MASTER_PLAN` status). This plan changes the VISUAL light; the tactical effect waits on that link. Confirm it stays visual here.

## 5. Records
- 2026-10-11 v0.1 — opened (Director), inventory §1, stages RF-0/RF-1/RF-2+, questions Q1-Q6.
