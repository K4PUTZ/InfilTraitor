## GlassMaterials — GLASS_MASTER_PLAN G-D16, the glass FAMILY seam.
##
## WHY THIS EXISTS, and it is measured rather than stylistic. Before G-VARIANT,
## "is this glass?" was written as a bare `material == "glass"` in TWENTY-FIVE
## places across rendering, geometry, occlusion, the guard phase, the shot path
## and the cook. Every one of them is a BEHAVIOUR: a glass slice does not
## occlude, does not enter the vision edge set, groups into a pane, lets a round
## through, renders on its own transparent layers, drops no smoke, and anchors
## no shards.
##
## G-D16 adds `glass_armored` and `glass_screen_{green,red,amber}` as members of
## that same family — *"a family of tinted behaviour classes, not new geometry"*.
## Adding them against 25 literal comparisons would make each new material a
## silently OPAQUE wall that happens to be named glass: it would occlude, block
## sight, stop rounds, puff smoke, and never form a pane. Nothing would error.
##
## So the family is asked, never compared. `is_glass()` is the only question the
## engine is allowed to ask about glass-ness, and `check_invariants.py` rule
## **L2** fails any new bare comparison outside this file.
##
## ── WHAT THIS FILE IS NOT ──
##
## It is not a second material registry. Resistance, destroy/dent/crack factors
## and `base_color` stay where they already live — `ASSETS/materials/<id>/<id>.json`
## via `MaterialResistanceTable`/`MaterialRegistry`, and `ShotPunchTable`'s
## balance rows. This file answers exactly one thing: which material ids are in
## the glass family, and (from V-C) which behaviour class each one carries.
class_name GlassMaterials

## The roster. **V-A ships with one member on purpose** — the sweep that replaced
## the 25 literals has to be provably behaviour-preserving, and a one-member
## family makes `is_glass(m)` and `m == "glass"` the same function by
## construction. The variants land in V-B, after the seam is green.
const FAMILY: Array[String] = ["glass"]

## The BASE member — the id whose balance rows, frost texture and tint every
## other member starts from. Kept as a named constant rather than `FAMILY[0]`
## so a future reordering of the roster cannot silently repoint it.
const BASE: String = "glass"


## The only question the engine asks about glass-ness.
##
## Takes the material id a caller already has — a `Slice.material`, an
## `Edge.material`, a `Slab.material`, or `Slice.material_at(rel)` for a G-D9
## banded wall. It never reads a registry, so it is safe in the hot render loop
## and in a pure planner alike.
static func is_glass(material_id: String) -> bool:
	return FAMILY.has(material_id)
