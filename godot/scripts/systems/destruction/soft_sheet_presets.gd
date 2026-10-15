## SoftSheetPresets — the numbers a soft roof falls with, per material (ROOF_MASTER_PLAN v0.28; the lab that fixed them is
## `tools/research/cloth_lab/`). Tuned by eye on the awning of ROOF_LAB, like every other `*Presets` table: `var`, so a calibration can move them.
class_name SoftSheetPresets
extends RefCounted

## Per material: `lb` the bend length in GU (the span at which a strip of it sags a lot: canvas ~ 0.12, corrugated cardboard ~ 0.7), `k_stretch`
## (about 1% strain under the roof's own weight; ABOVE ~1e4 the solver locks), `k_shear` (cloth gives, cardboard does not), `drag` (1/s), `thickness` (GU: the
## visible edge of the cloth, 0.04 = 6 cm: a cloth is a few millimetres, but it must show an edge at the play zoom, ROOF_MASTER_PLAN v0.31 C2).
static var OF: Dictionary = {
	"fabric": {"lb": 0.12, "k_stretch": 3000.0, "k_shear": 60.0, "drag": 1.0, "thickness": 0.04},
}

## The grid the sheet is simulated on: about one node per this many GU (a literal node per voxel, 1/8 GU, costs ~0.5 s a step in GDScript; this
## is N = 13 on a 4 GU roof, 11.6 ms a step on the desktop). The skin draws the voxel resolution.
static var NODE_SPACING: float = 1.0 / 3.0
## The fewest and most nodes along one side.
static var MIN_NODES: int = 4
static var MAX_NODES: int = 17


static func has(material: String) -> bool:
	return OF.has(material)


## Nodes along a side of `span` GU (counting both ends).
static func nodes_for(span: float) -> int:
	return clampi(int(round(span / NODE_SPACING)) + 1, MIN_NODES, MAX_NODES)
