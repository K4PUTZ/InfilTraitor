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

## The roster (V-B, 2026-09-01). ⚠️ ONE LINE, and `check_invariants.py`'s L2
## parses it off this line — a multi-line literal turns the rule off, which is
## why the parser reports "cannot check" as a violation rather than passing.
##
## Order is the TINT INDEX and is therefore load-bearing: the pane atom carries
## it in its BLUE channel and glass_pane.gdshader indexes `glass_tint_alt` with
## it. Append, never reorder.
const FAMILY: Array[String] = ["glass", "glass_armored", "glass_screen_green", "glass_screen_red", "glass_screen_amber"]

## The BASE member — the id whose balance rows, frost texture, atom silhouette
## and calibrated tint every other member starts from. Kept as a named constant
## rather than `FAMILY[0]` so a future reordering of the roster cannot silently
## repoint it.
const BASE: String = "glass"

## How many tints glass_pane.gdshader can hold: `glass_tint` (index 0) plus
## `glass_tint_alt[4]`. The renderer LOUD-FAILS when the roster outgrows this
## rather than clamping — a sixth member silently wearing the fifth's colour is
## exactly the kind of quiet wrongness a clamp buys.
const TINT_SLOTS: int = 5


## ── THE FRACTURE SHEETS (G-D14 / G-D21 / G-D23) ──────────────────────────────
##
## EXACTLY TWO, and the count is ratified rather than incidental: G-D14 gives
## glass two hole sizes (pistol / shotgun pellet take `tight`, rifle-class takes
## `wide`), and inside the rifle class the ENGINE destroys 2-4 voxels rather than
## the art growing a variant per weapon (Director, 2026-09-02). A third width
## would also cost 2048 composed atoms at every map load, cracked or not.
##
## Named here rather than at the consumer because there IS no consumer yet —
## G-D21's re-anchoring is unbuilt — and until one exists `check_decal.py` has
## nothing to read to tell a wired sheet from an orphan one. Order is the
## authoring order and carries no index.
const FRACTURE_WIDTHS: Array[String] = ["tight", "wide"]


## The sheet a member of the family cracks with. Every variant reuses BASE's
## pair (G-D16: the variants differ by tint and behaviour class, never by
## geometry), so this goes through `art_id()` for the same reason every other
## art seam does — a variant id must never reach a texture lookup under its own
## name. Returns the `texture_id` half of `TextureResolver.resolve()`, whose
## folder argument is `art_id()` as well.
static func fracture_texture_id(material_id: String, width: String) -> String:
	return "fracture_%s_%s" % [art_id(material_id), width]


## The only question the engine asks about glass-ness.
##
## Takes the material id a caller already has — a `Slice.material`, an
## `Edge.material`, a `Slab.material`, or `Slice.material_at(rel)` for a G-D9
## banded wall. It never reads a registry, so it is safe in the hot render loop
## and in a pure planner alike.
static func is_glass(material_id: String) -> bool:
	return FAMILY.has(material_id)


## The member's slot in the shader's tint table, or -1 for a non-member.
static func tint_index(material_id: String) -> int:
	return FAMILY.find(material_id)


## ── THE PANE TINTS (G-D16) ───────────────────────────────────────────────────
##
## ⚠️ THIS IS NOT `base_color`, AND CONFLATING THE TWO WOULD BE WRONG RATHER THAN
## MERELY UNTIDY. A pane does not alpha-blend: `glass_apply()` MULTIPLIES this
## colour over a BackBufferCopy of the scene behind it and adds a sheen on top
## (G-D1). It is a filter, not a paint. `base_color` is the opaque MULTIPLY a
## material's atom takes on the ordinary wall path — a different operation on a
## different surface — and the two have carried different values for base glass
## since G1 shipped (`glass.json` says 0.62/0.74/0.78; the pane reads
## 0.47/0.63/0.90, the Director's calibrated "painel 005"). Reading the JSON here
## would silently repaint every pane in the game.
##
## Index 0 MUST equal glass_shading.gdshaderinc's `glass_tint` default and
## VoxelRenderer._glass_shader_params — three copies of one number, which is one
## too many; the selftest pins them equal rather than trusting the comment.
##
## `static var` (not const) for the same reason every balance row in
## ShotPunchTable and GlassShatter is: these are the Director's dials, and 1..4
## are FIRST-PASS placeholders awaiting a calibration pass on the GLASS map.
## Index 0 is calibrated and must not be touched by that pass.
static var PANE_TINT: Array[Color] = [
	Color(0.47, 0.63, 0.90),   ## glass — CALIBRATED ("painel 005"), do not retune
	Color(0.63, 0.47, 0.90),   ## glass_armored — the blue rotated toward magenta at
	                           ##   the same luminance, so G1's calibration still reads
	Color(0.24, 0.62, 0.34),   ## glass_screen_green — a terminal, not a window: darker
	                           ##   so the MULTIPLY reads as a lit panel over a dark body
	Color(0.72, 0.26, 0.28),   ## glass_screen_red
	Color(0.82, 0.60, 0.20),   ## glass_screen_amber
]


## The tint a member's pane is filtered through. BASE's tint for anything else,
## so a caller that has not checked `is_glass()` gets the shipped look rather
## than a black pane.
static func pane_tint(material_id: String) -> Color:
	var i: int = tint_index(material_id)
	if i < 0 or i >= PANE_TINT.size():
		return PANE_TINT[0]
	return PANE_TINT[i]


## ── THE BEHAVIOUR CLASSES (G-D16, V-C) ───────────────────────────────────────
##
## The half of G-D16 the tint exists to announce. A class is not a difficulty
## dial — it changes WHICH RULES APPLY, which is why it is an enum and not a
## number:
##
##   BREAKABLE      the shipped model. §5.1's roll, §5.4's flood, G-D5's
##                  pass-through: a round goes through and the pane may take it.
##   ARMORED        resists common shots (its RESISTANCE row does that), and when
##                  a roll DOES win it goes ALL AT ONCE regardless of pane size —
##                  G-D12's partial break is exactly what armoured glass does not
##                  do. G-D15's rifle pierce-and-prime is V-D.
##   INDESTRUCTIBLE a control interface. It never reaches DESTROYED, it never
##                  rolls, and — Director, 2026-08-31, *"trinca mas o tiro
##                  para"* — **it STOPS THE ROUND.** It is the one glass G-D5
##                  does not apply to, and that is what sells it as armoured
##                  rather than merely tough.
enum Class { BREAKABLE, ARMORED, INDESTRUCTIBLE }

## ⚠️ The screens default to INDESTRUCTIBLE, and that is an ASSUMPTION worth
## seeing rather than burying. G-D16 gives `glass_screen_*` both readings —
## INDESTRUCTIBLE for control interfaces, BREAKABLE for TVs, circuits and news
## panels — *per placement*. The per-placement tag is V-D; until it exists the
## material default has to be one of them, and INDESTRUCTIBLE is the one with
## behaviour to build and test. V-D's tag flips a placement back to BREAKABLE.
const CLASS_OF: Dictionary = {
	"glass": Class.BREAKABLE,
	"glass_armored": Class.ARMORED,
	"glass_screen_green": Class.INDESTRUCTIBLE,
	"glass_screen_red": Class.INDESTRUCTIBLE,
	"glass_screen_amber": Class.INDESTRUCTIBLE,
}


## V-D — "no per-placement override", the value `Slice.glass_class` carries for
## every ordinary pane. Not 0, which is a real class (BREAKABLE).
const CLASS_UNSET: int = -1


## The member's behaviour class. BREAKABLE for anything else — a non-member is
## not glass at all, and every caller here has already asked `is_glass()`; the
## default exists so a missed roster row degrades to the SHIPPED behaviour rather
## than to a pane that cannot be broken.
static func class_of(material_id: String) -> Class:
	return CLASS_OF.get(material_id, Class.BREAKABLE)


## V-D — the class that actually applies HERE. G-D16 makes the screens
## INDESTRUCTIBLE or BREAKABLE *per placement* (a control interface against a TV
## or a news panel), so the material carries a default and the map may override
## it per panel. `override` is `Slice.glass_class`, or CLASS_UNSET when the map
## said nothing.
static func effective_class(material_id: String, override: int = CLASS_UNSET) -> Class:
	if override != CLASS_UNSET:
		return override as Class
	return class_of(material_id)


## True when this glass never breaks and STOPS a round instead of passing it
## through (G-D5's one exception). Named for the question rather than the class
## so the call sites read as physics.
static func stops_a_round(material_id: String, override: int = CLASS_UNSET) -> bool:
	return is_glass(material_id) \
		and effective_class(material_id, override) == Class.INDESTRUCTIBLE


## True when a won shatter roll must take the WHOLE pane rather than a region
## scaled by punch (G-D15) — armoured glass does not break in patches.
static func shatters_whole_pane(material_id: String, override: int = CLASS_UNSET) -> bool:
	return is_glass(material_id) \
		and effective_class(material_id, override) == Class.ARMORED


## The authoring vocabulary for `panels[].glass_class` (§9.6). Kept beside the
## enum so the mapfile spelling and the code cannot drift, and parsed loudly:
## a typo in a map is a placement whose class silently reverts to the material
## default, which is the quietest possible way to lose armour.
const CLASS_NAMES: Dictionary = {
	"breakable": Class.BREAKABLE,
	"armored": Class.ARMORED,
	"indestructible": Class.INDESTRUCTIBLE,
}


static func class_from_name(name: String) -> int:
	if name == "":
		return CLASS_UNSET
	var key := name.to_lower()
	if not CLASS_NAMES.has(key):
		push_error("[GlassMaterials] unknown glass_class %r in a map — expected one of %s. The panel keeps its material default, which is how a screen silently stops being a control interface." % [
			name, ", ".join(CLASS_NAMES.keys())])
		return CLASS_UNSET
	return int(CLASS_NAMES[key])


## ── ART (G-D16: "a family of tinted behaviour classes, NOT new geometry") ─────
##
## Every member renders from BASE's art — the same voxel atom silhouette, the
## same `facade_glass.png` frost. So the family costs ZERO new PNGs, and this is
## the function that makes that true at every art seam: a variant id never
## reaches a texture lookup under its own name.
##
## It matters most on the OPAQUE fallback. `MATERIALS.find(id)` returns -1 for an
## unregistered material and the renderer then falls back to source 0 — CONCRETE.
## A glass roof or a glazed floor zone (the horizontal cases G1 deliberately
## leaves opaque) would render as a concrete slab, with no error anywhere.
static func art_id(material_id: String) -> String:
	return BASE if is_glass(material_id) else material_id
