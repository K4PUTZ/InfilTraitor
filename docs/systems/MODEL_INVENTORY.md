# MODEL INVENTORY — every model the campaign needs (consolidated 2026-10-24)

🟢 **RATIFIED 2026-10-24** (the five questions answered; Claude's list, at the Director's request: *"uma lista de todos os modelos, incluindo versões masculina e feminina, mais os props
associados com a história"*). Nothing below is built except the hero's v5.1 pieces. This list **derives** from its owners and never overrides
them: characters and slots `COSMETICS_MASTER_PLAN` §8-§9, places and props `PROP_PIPELINE_PLAN` §9, cast and tree `DESIGN_MASTER_PLAN` §2.7,
§10.0, §11.6-§11.7, §15. When an owner changes, this file follows.

**Director's rule (2026-10-24): architecture and LARGE objects are built in VOXELS** (generator scripts into `VoxelStore` containers, like
`gen_dorm_vox.py`: shots, blasts, fire and soot for free). So this inventory has two halves: **models to sculpt** (characters, pieces worn or
held, small or organic props: meshes) and **voxel generators** (rooms, furniture, machines, big story objects).

Legend: **M/F** = a piece fitted to both the male and the female base; **M** or **F** = one base only; ✅ = exists (hero v5.1).

## 1. Bases (one skeleton, the hero's 65 bones)

| Base | Who | Gender |
|---|---|---|
| Standard ✅ (agile-B) | the Agent, civilians, every rank-and-file guard, most named characters | M ✅ / F (required) |
| Heavy (a remodel of the same body) | the bruisers of Calm Waters and the Bunsen Burners; Kessler, "Deacon" | M / F (some women in every faction, not on every model: Director, 2026-10-24) |
| **Quadruped (a second skeleton; Director, 2026-10-24)** | Cairn's K9 dog (`DESIGN` §11.6; dogs follow trails, §4.7) | — |
| Child | **none** (the son only in photographs, `COSMETICS` §8.1) | — |

**The dog is the one model outside the one-skeleton rule (ratified):** its own rig and clips (walk, sniff, alert, bark, down).

## 2. The Agent (four instances, one per background; every piece M/F)

| Group | Pieces |
|---|---|
| Head | fedora (start) ✅, the **hat-mask** (the Confessor's) ✅, balaclava, hair and beard (the hero's CC0 pieces; the female base needs its own set) |
| Torso | shirt ✅, tie ✅, the FID **mustard coat** (black inside) ✅ — the same coat silhouette carries the four **officer coats** (FID mustard, Calm Waters grey, Bunsen Burners brown, Corporation black) and the **LED coat** (a shader on it, `DESIGN` §10.5) |
| Arms | gloves, **armband** ×4 factions (the bikers' brown with orange stripes, `ACTOR` D78), watch, wedding ring |
| Legs / feet | trousers ✅, dress shoes ✅, **silent boots** (Calm Waters armoury) |
| Gear | pack ✅, pack + **battery** (the upgrade), belt with holster, police **badge** (taken in lap 1), **vest** (Calm Waters, armour T3), **exoskeleton** (L3, a worn frame over both bases) |
| Skin layer | the ending's tattoo (a texture, not a mesh) |

Mask modules (thermal, motion, WiFi, X-ray, spectral, tactical analysis, predictive, trail reading) are **visor STATES of the hat-mask**: a shader
and the screen effect, no new mesh.

## 3. Held items and gadgets (meshes, small; all on one hand bone)

| Source | Items |
|---|---|
| Start kit = the attack's gear (`DESIGN` §10.0) | common pistol, stone (and the pile), **an old wind-up alarm clock** (later the **radio-clock**, Director 2026-10-24), **spray can**, **chloroform** bottle + rag, short **rope with hook** |
| FID tree | taser, suppressor (attachment), **sonic weapon**, radio (spoof), **radio scrambler**, lockpicks, zip ties, phone cloner |
| Calm Waters tree | **scout drone** + its controller (PP7, moves), **suppressed rifle**, **pulse carbine**, **laser** rifle, **EMP charge** |
| Bunsen Burners tree | **firework lure**, **dart launcher**, gas grenade, smoke grenade, **incendiary**, **tripwire flash**, **breaching charge** |
| Corporation tree | **camera-loop rig**, **shadow generator**, **plasma** weapon, cash envelope (bribe), forged credential card, **master keycard** |
| Distractions (`DESIGN` §5.4) | baseball, glass cup / bottle, can, universal remote |
| Story, carried | the report's folder, the wedding ring, the badge, a phone, the sample case (L3 prototypes to Zest) |

Vehicle the Agent rides: the **getaway bike** (Bunsen Burners chop shop) — see §6 Q1.

## 4. Factions: guards, officers and counter units

**Rank-and-file sets (standard base, with SOME women in every faction, not on every model: Director 2026-10-24; the heavy base where the faction uses bruisers), one per faction, ranks adding pieces** (`COSMETICS`
§8.3): FID uniform shirt, trousers, boots, cap, duty belt; Calm Waters tactical top, armour vest, helmet, gloves; Bunsen Burners patched vest,
jeans, boots, bandana; Corporation suits, earpiece, sunglasses. Rank pieces: radio, tactical vest, goggles / visor, chains, briefcase. **Officers
(Lieutenant up):** the faction's overcoat (§2's coat row) + armband.

**The twelve counter units (`DESIGN` §11.7): pieces on the rank-and-file set, three gear stages each, M/F.**

| Faction | EYE | HAND | WALL |
|---|---|---|---|
| FID | forensic tech: scent-decoy kit · tablet (patrol re-roll) · jammer case | riot officer: insulated vest · detector wand · ear defenders | radio sergeant: analogue handset · (behaviour) · runner's satchel |
| Calm Waters | counter-drone crew: anti-drone gun · insulation suit · (architecture: lead-lined rooms) | spotter + heavy: spotting scope · insulated armour · reflective plating | hardened tech: shielded case · pressure plates (floor prop) · (behaviour: pairs) |
| Bunsen Burners | sentry: (behaviour) · (behaviour) · (behaviour: informant hunts) | gas-mask cook: antidote injector · respirator · foam extinguisher | road crew: sweeping torch · spike strip + roadblock · (architecture: reinforced doors) |
| Corporation | feed monitor: tablet · (architecture: shielded rooms) · multi-spectrum camo suit | floodlight team: flare + portable floodlight · (zone) · heavy plating | compliance officer: (behaviour) · credential reader · keypad (wall prop) |

"(behaviour)", "(zone)" and "(architecture)" stages need no model: AI rules, map tags, or voxel materials.

## 5. Named characters (one base each; gender fixed by the canon)

| Character | Base | Note |
|---|---|---|
| Agent: Victor / **Victoria** Rook | standard M / F | §2 |
| Spouse: Claire (M Agent) / **Clement** (F Agent) | standard F / M | both exist |
| Leo Rook | — | photographs only (a texture) |
| Commissioner Martin Graves | standard M | boss, lap 2 |
| Deputy Commissioner Irene Barrow | standard F | sub-leader, handler |
| Commander Dale Kessler | heavy M | boss |
| Duke Hardcastle | heavy M | sub-leader |
| President "Deacon" (Wade Cutler) | heavy M | boss |
| Vice President "Choirboy" | standard M | sub-leader |
| CEO Gordon Pryce | standard M | boss |
| Evelyn Marsh | standard F | sub-leader |
| Prudence Vane | standard F | Marsh's counsel |
| Thomas Marlow (The Sieve) | standard M | the reporter; civilian |
| "The Confessor" | standard M | the hired assassin; wears the hat-mask |
| The official investigator who takes the case | standard (open) | |
| Pith & Peel's front man | standard M | |
| Four faction members abroad | standard (open) | one per trip |
| **Specialists (12):** Cairn (+ dog), Pyre, Vault · Ace Skyler, Rex Hawke, Chip Voltz · Vespers, Censer, Sexton · Ledger, Hedge, Escrow | standard / heavy; **two women per faction among its specialists + keeper** (ratified; who is open) | each carries his node's item (§3) |
| **Store keepers:** Urn, Tank Mercer, Tithe, Margin | open | `DESIGN` §11.7 |
| **Zest** | open | the researcher of the neutral missions |
| Four Freelance prototype captains | the faction's officer set + the L3 item | not named |

Crowd sets (M/F): civilians (recoloured), press (camera, microphone), mourners, medical staff (scrubs), looters (bandana). The TV anchor is 2D.

## 6. Story props

**Voxel (architecture and large objects, generator scripts):**
- **Kits / places** (`PROP_PIPELINE` §9.2): the devastated town, the Agent's house, the police station with the deposition room and the
  EVIDENCE ROOM, the power station and substation, GRUB DRILL's complex with the ARMOURY and the drone hangar, the clubhouse with the lab and
  the CHOP SHOP, the Corporation HQ with the R&D FLOOR and the campaign office, the hospital, the pit and the dam, the cemetery, four places
  abroad, **Zest's workshop** (new).
- **Furniture and machines** (§9.3 families): filing cabinets, tables, lecterns, **sofa and armchair** (were mesh; voxel under the new rule),
  terminals, server racks, monitors, TVs, control panels, boom gates, barriers, guard booths, hoardings, sandbags, floodlights, drums, tanks,
  sluice-gate wheel, transformer, generator, **siren tower**, pallets, catwalks, lab benches and fume hoods, pool table, bar counter, beds,
  blood-bank fridge, headstones (3-4) and the grave, the tent, kitchen counter, store shelving and weapon racks.
- **Big story objects:** the generator's **EMPTY PAD** (bolts and an "installed" tag), the **drone's wreck**, the **waste drums**, the pit's
  **railing**, the screen with the **puts**, the roadblock's **credential reader**, the drone parts on the chop-shop bench, perches (water
  tower, gantry).

**Mesh (small, thin or organic):** the deposition **camera** (its little light), photo frames (Leo's texture), a glass, a phone, a wreath,
umbrellas, chairs, cones, Pryce's **campaign posters** (in-world text via `tr()`), curfew signs, grapple anchors, the throwables of §3.

**Moving (PP7):** the Militia's drones, surveillance cameras, sensors, the sluice gate, the TV and radio states, car alarm, light switches.

## 7. Rulings (Director, 2026-10-24)

1. **Vehicles stay MESH** (`PROP_PIPELINE` §9.5 stands); the voxel rule covers architecture and large static objects.
2. **The K9 dog gets its own quadruped skeleton.**
3. **The alarm clock is an old wind-up clock** (a held mesh), later replaced by the radio-clock (`DESIGN` §10.0).
4. **Some women in every faction's rank-and-file, not on every model:** the female base carries a share of each faction's set, not all of it.
5. **Two women per faction among its four named people** (three specialists + the store keeper; the question said "five", a miscount);
   which ones is still to write.

## 8. Counts (proposal)

| Kind | Count |
|---|---|
| Skeletons | 2 (biped, quadruped) |
| Bases | 4 (standard M ✅ / F, heavy M / F) |
| Agent pieces (M/F) | ~22 pieces × 2 bases, ~9 exist on M |
| Faction sets | 4 sets × ~8 pieces × 2-4 bases |
| Counter-unit pieces | ~22 meshes (the rest are behaviour, zones or voxels) |
| Held items / gadgets | ~45 |
| Named characters (face + tailoring) | ~40 |
| Crowd sets | 5 |
| Voxel kits | 16 places; ~60 voxel object types |
| Story meshes | ~15; PP7 moving props ~8 |
