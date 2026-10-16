## RubblePresets — how a voxel a shot broke crumbles (ROOF_MASTER_PLAN R-D9, Director 2026-10-12).
##
## A broken voxel is replaced, on the frame the round lands, by a block of DIVISION³ sub-voxels sitting exactly where it was (the hole
## is never shown before they go). The whole block then crumbles out of the wall and piles on the floor. HOW it crumbles is one of three
## fall presets (the project's three-variant scheme), picked per voxel by a B4 FNV-1a hash of its cell, so the same wall breaks the same
## way on every run:
##   0 TOPPLE — the top layer leaves first, the block peels down from above;
##   1 SLUMP  — the bottom gives first and the block sags almost straight down at the wall's foot;
##   2 SPILL  — the face nearest the shooter leaves first and the block spills further out.
## A preset gives each sub-voxel a release delay (seconds after the hold) and a multiplier on its push. `SPEED` scales a material's
## push (concrete crumbles, wood and board spill further). `var`, rule 1.
class_name RubblePresets
extends RefCounted

const DIVISION: int = 4
const VARIANTS: int = 3
const TOPPLE: int = 0
const SLUMP: int = 1
const SPILL: int = 2

static var SPEED: Dictionary = {
	"concrete": 0.9, "stone": 0.9, "brick": 1.0, "metal": 0.7,
	"wood": 1.3, "plywood": 1.3, "cardboard": 1.5, "fabric": 1.1, "generic": 1.0,
}
## Materials whose broken voxels do NOT crumble (Director, 2026-10-12: stone gives a hole and the bullet-hole dust, nothing falls; cardboard,
## metal and fabric shed no particles at all from a shot — metal keeps its sparks, which are light, not debris).
static var NO_FALL: Array[String] = ["stone", "cardboard", "metal", "fabric"]
static var LAYER_STEP_S: float = 0.045   ## seconds between two layers of a block leaving
static var JITTER_S: float = 0.03        ## a hashed extra delay per sub-voxel, so a layer does not leave as one slab


## Which of the three presets a voxel wears (B4: hashed on its cell, never `randf()`).
static func variant_of(cell: Vector2i, level: int) -> int:
	return FacadeSampler._fnv1a_hash("RUBBLEVAR|%d,%d,%d" % [cell.x, cell.y, level]) % VARIANTS


## (release delay s, push multiplier) of one sub-voxel. `height` 0..DIVISION-1 is its layer from the bottom, `outward` 0..1 how far
## toward the shooter it sits in the block, `h01` a hashed number in [0, 1) of its own.
static func shape(material: String, variant: int, height: int, outward: float, h01: float) -> Vector2:
	var top: float = float(DIVISION - 1)
	var speed: float = float(SPEED.get(material, SPEED["generic"]))
	var delay: float
	var push: float
	match variant:
		SLUMP:
			delay = float(height) * LAYER_STEP_S
			push = 0.35
		SPILL:
			delay = (1.0 - outward) * top * LAYER_STEP_S
			push = 1.6
		_:
			delay = (top - float(height)) * LAYER_STEP_S
			push = 1.0
	return Vector2(delay + h01 * JITTER_S, push * speed)


## SPLINTERS (Director, 2026-10-12, wood): a broken voxel does not crumble afterwards. On the frame of the impact its block of sub-voxels
## splits three ways, by a hash of each cube: some FLY (thrown against the shot at once, a little farther than a crumble, and land),
## some STAY where they were (the ragged rim of the hole, saved with the pile) and the rest are GONE (the hollow of the crater). The
## cubes on the block's edge in the struck face's plane stay far more often, so the hole reads as splintered around its mouth.
static var SPLINTERS: Array[String] = ["wood", "plywood"]
const FLY: int = 0
const STAY: int = 1
const GONE: int = 2
static var STAY_EDGE: float = 0.55      ## chance a cube on the block's edge (in the face's plane) stays
static var STAY_INNER: float = 0.12     ## ... and one inside it
static var FLY_SHARE: float = 0.55      ## of the cubes that do not stay, the share that flies (the rest are gone)
## Per material: plywood (madeirite) is wood with more destruction and more splinters (Director, 2026-10-12).
static var FLY_SHARE_OF: Dictionary = {"plywood": 0.5}
## Plywood's splinters are darker and vary more from cube to cube (Director, 2026-10-12): a lower point on the ramp and a wider brightness jitter.
static var RAMP_OF: Dictionary = {"plywood": 0.15}
static var JITTER_OF: Dictionary = {"plywood": 0.14}
## Plywood: an open, airy break (Director, 2026-10-12): only a share of the broken voxels get a block of sub-voxels at all (the others are plain
## empty holes), the blocks that do are mostly hollow, the rim is thin and the thrown pieces keep the facade's texture (the floor noise of
## black stains and mixed wood tones). Wood keeps the defaults above.
static var BLOCK_SHARE_OF: Dictionary = {"plywood": 0.15}
static var STAY_EDGE_OF: Dictionary = {"plywood": 0.40}
static var STAY_INNER_OF: Dictionary = {"plywood": 0.05}
static var FLY_TEXTURED_OF: Dictionary = {"plywood": true, "cardboard": true, "fabric": true}
## BLAST FRAGMENTS (Director, 2026-10-13): a seasoning of the shot in a blast's inner ring, so both read as one visual language. Simulated
## shotgun pellets (`BLAST_WEAPON`, `BLAST_PELLETS` per cone, eight cones, `BLAST_PELLET_STEPS` GU) pick, with the shot's own plan, the voxels that
## become blocks (at most `BLAST_MAX_CELLS`: a block is 64 cubes, the Moto's budget) and the standing faces that get the shot's impact effects
## (at most `BLAST_MAX_IMPACTS`). The punch-out materials (`FORWARD_MATERIALS`) are not seasoned yet.
static var BLAST_WEAPON: String = "shotgun"
static var BLAST_PELLETS: int = 24
static var BLAST_PELLET_STEPS: int = 2
static var BLAST_MAX_CELLS: int = 40
static var BLAST_MAX_IMPACTS: int = 40
## The HOLE a blast opens in a roof (Director, 2026-10-13: "abrir buraco sobre a granada"): every roof voxel within this radius (board voxels, 8 per
## GU) of the epicentre's centre is destroyed through every layer, the edge ragged by `BLAST_ROOF_HOLE_RAGGED` (a hashed share of a voxel per
## column); outside it the ring's scattered DESTROYED rolls become dents (marks and dust, no pinholes). Lighter materials open wider.
static var BLAST_ROOF_HOLE_RADIUS: float = 6.0
## Stone 5 -> 4 -> 3.2 (Director, 2026-10-14: stone is barely affected, and should differ more from concrete).
static var BLAST_ROOF_HOLE_RADIUS_OF: Dictionary = {"stone": 3.2, "wood": 8.0, "plywood": 10.0, "cardboard": 11.0, "fabric": 11.0}
static var BLAST_ROOF_HOLE_RAGGED: float = 1.8
## The outline is not a circle (Director, 2026-10-14: "não tão circular, com mais irregularidades"): the radius swings with the angle around the
## epicentre, a sum of lobes [harmonic, share of the radius] with phases hashed per blast, so every hole has its own shape.
static var BLAST_ROOF_HOLE_LOBES: Array = [[2, 0.22], [3, 0.18], [5, 0.12], [7, 0.07]]
## What the hole's voxels become (Director, 2026-10-14: "usar mais os voxels e até blocos com chunks de voxels que despencam; alguns vão subir e
## cair em cima do telhado"; the skylight's burst is the model). A whole 2x2x2 cell of the hole (the roof's two layers) is a CHUNK at
## `ROOF_CHUNK_SHARE`; every other voxel is a whole VOXEL at `ROOF_VOXEL_SHARE`, a crumbling block of sub-voxels (the shot's) at `ROOF_SUB_SHARE`,
## else it simply vanishes when the roof gives way, no trace (Director, 2026-10-14). Caps per blast for the Moto. Thrown away from the
## epicentre and barely up: `ROOF_PUSH` [out, up] GU/s, times `ROOF_WEIGHT_*` (a chunk is heavier, it mostly drops); the pieces land on the
## floor, a pile or the roof around the hole.
static var ROOF_CHUNK_SHARE: float = 0.3
static var ROOF_VOXEL_SHARE: float = 0.4
static var ROOF_SUB_SHARE: float = 0.12
static var ROOF_MAX_CHUNKS: int = 4
static var ROOF_MAX_VOXELS: int = 60
static var ROOF_MAX_SUBS: int = 8
static var ROOF_PUSH: Vector2 = Vector2(0.6, 0.3)
static var ROOF_WEIGHT_VOXEL: float = 0.8
static var ROOF_WEIGHT_CHUNK: float = 0.45
## A share of the whole voxels is blown UP out of the hole and comes down on the roof around it (Director, 2026-10-14: "alguns explodindo pra
## cima e caindo no telhado, só alguns menores"): `ROOF_UP_SHARE` of them, at most `ROOF_MAX_UP`, with the `ROOF_UP_PUSH` [out, up] kick.
static var ROOF_UP_SHARE: float = 0.1
static var ROOF_MAX_UP: int = 8
static var ROOF_UP_PUSH: Vector2 = Vector2(0.9, 4.0)
## The falling mass is sooted, each piece its own shade in `ROOF_SOOT` [darkest, lightest] (a multiplier, hashed per piece), so it does not read
## clean. The charred ladder (`PropFragmentSim` `char`) read pitch black in the air.
static var ROOF_SOOT: Vector2 = Vector2(0.45, 0.85)
## While it comes down, dust trickles from almost every voxel of the hole's rim (Director, 2026-10-14: "bastante pozinho, de quase todos os
## voxels na borda, durante a queda do entulho, e irem parando em seguida"; the bullet hole's sand trickle, in the material's colour), each
## starting in `ROOF_RIM_DELAY` [first, last] seconds after the blast and running its own short envelope: at most `ROOF_RIM_TRICKLES`.
static var ROOF_RIM_TRICKLES: int = 48
static var ROOF_RIM_DELAY: Vector2 = Vector2(0.1, 1.1)
## PER MATERIAL (Director, 2026-10-14; concrete is the model above, brick keeps it). Each `_OF` row overrides its value for one material:
##   stone     — barely affected: a smaller hole, heavier rubble (more 2x2x2 chunks, fewer loose voxels), nothing blown up onto the roof, and a
##               lot of dust falling from under the rim for longer (Director, 2026-10-14);
##   concrete, brick and stone keep CRUMBS on the crater's rim (`ROOF_RIM_BITS_OF`);
##   wood      — the shot's SPLINTERS (`spawn_shot_rubble`'s splinter blocks: they fly and stamp the floor), no chunks, a few whole voxels, less
##               dust, and the rim stays splintered: sub-voxel cubes ATTACHED to the standing rim (`ROOF_RIM_BITS_OF`, darker), never loose in the hole;
##   plywood   — wood's, far more pieces (in proportion to its wider hole), darker and more varied, like its shot (`JITTER_OF`);
##   cardboard — light flaps that glide down (`ROOF_FALL_OF`: gravity, terminal speed, sway), more of them blown up onto the roof, no dust
##               (`NO_DUST`), no chunks or crumbling blocks; the fire spreads across the roof and chars it (`ROOF_FIRE_*`, fabric too).
## Cardboard, fabric and plywood roofs are ONE layer (`RoomBuilder`), so they never make a 2x2x2 chunk anyway.
##   fabric    — a cloth sheds NO fragment at all (Director, 2026-10-16: "pano não pode soltar fragmentos, ainda mais voxels quadrados"): the hole's
##               middle just disintegrates; its ragged rim is a set of flaps that rise and fall (`Room.spawn_cloth_flaps`), the fire goes on.
static var ROOF_CHUNK_SHARE_OF: Dictionary = {"stone": 0.8, "wood": 0.0, "plywood": 0.0, "cardboard": 0.0, "fabric": 0.0}
static var ROOF_MAX_CHUNKS_OF: Dictionary = {"stone": 5}
static var ROOF_VOXEL_SHARE_OF: Dictionary = {"stone": 0.25, "wood": 0.12, "plywood": 0.35, "cardboard": 0.45, "fabric": 0.0}
static var ROOF_MAX_VOXELS_OF: Dictionary = {"stone": 12, "wood": 30, "plywood": 120, "cardboard": 120}
static var ROOF_SUB_SHARE_OF: Dictionary = {"stone": 0.06, "wood": 0.3, "plywood": 0.15, "cardboard": 0.0, "fabric": 0.0}
static var ROOF_MAX_SUBS_OF: Dictionary = {"stone": 2, "wood": 20, "plywood": 16}
static var ROOF_UP_SHARE_OF: Dictionary = {"stone": 0.0, "cardboard": 0.35, "fabric": 0.0}
static var ROOF_MAX_UP_OF: Dictionary = {"cardboard": 30}
## A light piece's kick upward is smaller, or it would rise metres under its low gravity.
static var ROOF_UP_PUSH_OF: Dictionary = {"cardboard": Vector2(0.7, 2.2)}
static var ROOF_SOOT_OF: Dictionary = {"plywood": Vector2(0.3, 0.75)}
## Stone sheds a lot of dust from under its rim (Director, 2026-10-14: "deixar cair bastante pozinho por baixo"): every rim voxel of its small
## hole trickles, the starts spread over a longer window (`ROOF_RIM_DELAY_OF`) so the dust keeps falling after the rubble has landed.
static var ROOF_RIM_TRICKLES_OF: Dictionary = {"stone": 120, "wood": 16, "plywood": 16}
static var ROOF_RIM_DELAY_OF: Dictionary = {"stone": Vector2(0.1, 2.6)}
## ... and not only from the rim (Director, 2026-10-14: "um chuveirinho de pó junto com os cubos que caem"): the lower layer's voxels up to this
## many voxels from the hole shed dust too, so a shower falls around the opening while the cubes come down. 1 = the rim only.
static var ROOF_DUST_REACH_OF: Dictionary = {"stone": 4}
## How a piece falls, per material: {gravity (x GRAVITY), fall_max (GU/s), sway (GU/s), max_time (s)} (`PropFragmentSim`).
static var ROOF_FALL_OF: Dictionary = {"cardboard": {"gravity": 0.35, "fall_max": 0.9, "sway": 1.5, "max_time": 4.0}}
## The ragged RIM (`Room._roof_rim_bits`; Director, 2026-10-14): of each destroyed voxel beside a standing one, the sub-voxel cubes on the face
## toward it stay attached, at `[first layer, second layer]` chance: wood and plywood's SPLINTERS, and the CRUMBS (farelos) of concrete, brick and
## stone. At most `ROOF_RIM_BITS_MAX` cubes per blast. They are sooted in `ROOF_RIM_BITS_SOOT_OF` (else the falling pieces' `ROOF_SOOT_OF`): wood's
## read as light dots on its charred rim (Director: darker). `ROOF_RIM_BITS_TEXTURED` wear the facade; wood keeps the shot's flat splinter look.
static var ROOF_RIM_BITS_OF: Dictionary = {
	"wood": Vector2(0.45, 0.15), "plywood": Vector2(0.45, 0.15),
	"concrete": Vector2(0.35, 0.1), "brick": Vector2(0.35, 0.1), "stone": Vector2(0.35, 0.1),
}
static var ROOF_RIM_BITS_SOOT_OF: Dictionary = {"wood": Vector2(0.22, 0.45)}
static var ROOF_RIM_BITS_TEXTURED: Array[String] = ["plywood", "concrete", "brick", "stone"]
static var ROOF_RIM_BITS_MAX: int = 320
## A piece of roof the hole left with no support (`DetonationPlanBuilder._roof_islands`) falls WHOLE, voxel by voxel, barely pushed: at most
## `ROOF_MAX_ISLAND` voxels (thinned evenly past it), `ROOF_ISLAND_PUSH` [out, up] GU/s at `ROOF_WEIGHT_ISLAND`.
static var ROOF_MAX_ISLAND: int = 800
static var ROOF_ISLAND_PUSH: Vector2 = Vector2(0.2, 0.0)
static var ROOF_WEIGHT_ISLAND: float = 0.3
## The roof's FIRE (Director, 2026-10-14: cardboard "queimasse mais tempo e mais longe, e pode deixar com bastante fuligem, porque nesse caso o
## fogo efetivamente chegou na face superior"; fabric the same). On a roof of these materials the fire does not stop at the hole's burning edge:
## it creeps OUTWARD across the roof up to `ROOF_FIRE_SPREAD_OF` voxels, one ring every `ROOF_FIRE_STEP_S`; ring k catches at `ROOF_FIRE_CHANCE`^k
## (a miss ends that branch, so the front is ragged); every voxel it reaches ends CHARRED and `ROOF_FIRE_EMBER_SHARE` of them glow, `ROOF_FIRE_LIFE`
## times longer than an edge ember. It consumes nothing (the hole stays the blast's and its burnt edge's). The top layer takes the ring's full
## soot (`ROOF_TOP_SOOT_LIFT_OF` 0: the fire reached the face that looks at the sky).
## (fabric is NOT here since 2026-10-16: a cloth's fire is the cloth's own, burning the flaps and the edge of the opening while it falls and spreading a little where it
## parks: `Room.release_roof_sheet`, `soft_sheet3d.gdshader`)
static var ROOF_FIRE_SPREAD_OF: Dictionary = {"cardboard": 6}
static var ROOF_FIRE_STEP_S: float = 0.35
static var ROOF_FIRE_CHANCE: float = 0.88
static var ROOF_FIRE_EMBER_SHARE: float = 0.55
static var ROOF_FIRE_LIFE: float = 1.5
static var ROOF_TOP_SOOT_LIFT_OF: Dictionary = {"cardboard": 0, "fabric": 0}
## How many tones lighter a roof's TOP layer is sooted than the blast's ring would make it (it faces away from a blast below).
static var ROOF_TOP_SOOT_LIFT: int = 2
static var BLAST_IMPACTS_PER_FRAME: int = 4
## The bullet hole's sand trickle on wall voxels a blast marked (dented / cracked): the share of them picked, the cap, the materials and how
## long after the commit the last one may start (Director, 2026-10-13).
static var BLAST_TRICKLE_MATERIALS: Array[String] = ["concrete", "brick", "stone"]
static var BLAST_TRICKLE_SHARE: float = 0.08
static var BLAST_TRICKLE_SHARE_OF: Dictionary = {"stone": 0.04}   ## stone a little less than the others (Director, 2026-10-13)
static var BLAST_MAX_TRICKLES: int = 10
static var BLAST_TRICKLE_SPREAD_S: float = 1.2
## A blast near a hole-only wall opens a DOOR in it (`DetonationPlanBuilder._plan_blast_breaches`), on edges in these rings: half its width in
## voxels (of the face's 8), its height in levels from the floor (STANDING wants two storeys, 16 levels, half gone) and how many top rows arch.
static var BLAST_BREACH_MATERIALS: Array[String] = ["plywood", "cardboard", "fabric"]
static var BLAST_BREACH_HALF_WIDTH: float = 3.1
static var BLAST_BREACH_ROWS: int = 13
static var BLAST_BREACH_ARCH_ROWS: float = 1.0
static var BLAST_BREACH_RING: int = 1
## Per material, on a blast's pellet impacts only (Director, 2026-10-13): concrete trickles sand from every struck face, wood throws more chips
## (each chip's landing stamps the floor).
static var BLAST_DUST_CHANCE_OF: Dictionary = {"concrete": 1.0, "brick": 1.0, "stone": 0.5}
static var BLAST_CHIPS_MULT_OF: Dictionary = {"wood": 3.0}
## The most broken voxels of one shot that turn into blocks on one frame (the rest follow on the next ones).
const BLOCKS_PER_FRAME: int = 5
## PUNCH-OUT (Director, 2026-10-12): the middle of a hole-only wall's break is cut out whole and thrown FORWARD, with the shot, to land as rubble
## beyond the wall. `FORWARD_KEEP` is the share of a cut voxel's 64 cubes that is drawn at all (the rest are gone: the zone is empty
## either way, this is only what the eye sees fly), `FORWARD_SPEED` the push, a little more than a splinter's.
static var FORWARD_KEEP: float = 0.22
static var FORWARD_SPEED: Vector2 = Vector2(2.0, 3.6)
static var FORWARD_DELAY_S: float = 0.05
## Part of the cut zone falls on the SHOOTER's side instead (Director, 2026-10-12: the rubble was all behind the wall): this share of its voxels, hashed,
## slumps out slowly against the shot (`FRONT_SPEED`) and piles in front.
static var FRONT_SHARE: float = 0.35
static var FRONT_SPEED: Vector2 = Vector2(0.5, 1.3)
static var FORWARD_MATERIALS: Array[String] = ["plywood", "cardboard", "fabric"]
## Shed no dust puff where the pile lands (Director, 2026-10-12: cardboard and fabric leave no splinters and no dust, only a little soot).
static var NO_DUST: Array[String] = ["cardboard", "fabric"]
## The cut zone around the centre of a shot's destroyed cells on a wall face, as an ellipse in (col, row) cells; a survivor with this many of its
## four neighbours gone is a floating island and goes too.
static var ZONE_RADIUS: Vector2 = Vector2(1.5, 2.0)
## Per material (Director, 2026-10-13): plywood's hole is a little wider, enough for the agent to squeeze through it head first (a crawl, not a
## door: it need not reach the floor); more rounds widen it.
static var ZONE_RADIUS_OF: Dictionary = {"plywood": Vector2(3.2, 3.2)}
const ISLAND_NEIGHBOURS: int = 3
static var FLY_SPEED: Vector2 = Vector2(1.8, 3.2)   ## a flying splinter's push multiplier, min..max (a crumble is 0.35-1.6 x the material's speed)
static var FLY_DELAY_S: float = 0.04    ## the most a splinter waits after the impact, so they do not leave as one slab


## Whether this broken voxel gets a block of sub-voxels at all (hashed on its cell, B4).
static func block_kept(material: String, cell: Vector2i, level: int) -> bool:
	var share: float = float(BLOCK_SHARE_OF.get(material, 1.0))
	if share >= 1.0:
		return true
	return float(FacadeSampler._fnv1a_hash("SPLBLOCK|%d,%d,%d" % [cell.x, cell.y, level]) % 1000) / 1000.0 < share


static func splinter_role(material: String, cell: Vector2i, level: int, a: int, b: int, cc: int, x_normal: bool) -> int:
	var top: int = DIVISION - 1
	var lateral: int = cc if x_normal else a
	var edge: bool = lateral == 0 or lateral == top or b == 0 or b == top
	var h: int = FacadeSampler._fnv1a_hash("SPLINTER|%d,%d,%d|%d,%d,%d" % [cell.x, cell.y, level, a, b, cc])
	var u: float = float(h % 1000) / 1000.0
	if u < float((STAY_EDGE_OF.get(material, STAY_EDGE) if edge else STAY_INNER_OF.get(material, STAY_INNER))):
		return STAY
	return FLY if float(FacadeSampler._fnv1a_hash("SPLFLY|%d" % h) % 1000) / 1000.0 < float(FLY_SHARE_OF.get(material, FLY_SHARE)) else GONE


## (release delay s, push multiplier) of a flying splinter, from a hashed number in [0, 1).
static func splinter_shape(h01: float) -> Vector2:
	return Vector2(h01 * FLY_DELAY_S, lerpf(FLY_SPEED.x, FLY_SPEED.y, h01))


static func forward_role(cell: Vector2i, level: int, a: int, b: int, cc: int) -> int:
	var h: int = FacadeSampler._fnv1a_hash("FWD|%d,%d,%d|%d,%d,%d" % [cell.x, cell.y, level, a, b, cc])
	return FLY if float(h % 1000) / 1000.0 < FORWARD_KEEP else GONE


static func is_front_drop(cell: Vector2i, level: int) -> bool:
	return float(FacadeSampler._fnv1a_hash("FRONT|%d,%d,%d" % [cell.x, cell.y, level]) % 1000) / 1000.0 < FRONT_SHARE


static func front_shape(h01: float) -> Vector2:
	return Vector2(h01 * FORWARD_DELAY_S, lerpf(FRONT_SPEED.x, FRONT_SPEED.y, h01))


static func forward_shape(h01: float) -> Vector2:
	return Vector2(h01 * FORWARD_DELAY_S, lerpf(FORWARD_SPEED.x, FORWARD_SPEED.y, h01))
