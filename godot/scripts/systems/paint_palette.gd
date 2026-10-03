## PaintPalette — the named paints a painted surface can wear (`painted_metal@olive_drab`).
##
## A paint is ONE COLOUR. A surface that takes paint keeps its material (its detail, its family, its soot and light behaviour)
## and only its `albedo` changes, so repainting is a single shader parameter write: no texture, no material copy, no disk row.
## The grayscale facade of a material that has one stays the detail the paint is multiplied by (B2), and is the natural mask for
## wear later (chips that show the metal under the paint).
##
## It lives in code, not in `ASSETS/materials/` (git-ignored there) nor in a JSON the export filter would have to list: the
## palette is a short table that ships with the scripts.
class_name PaintPalette

## Colours are display (sRGB) values, handed to a `source_color` uniform like every other board colour.
const PAINTS := {
	"olive_drab": Color(0.30, 0.34, 0.17),
	"sand": Color(0.62, 0.55, 0.38),
	"navy": Color(0.14, 0.18, 0.30),
	"signal_red": Color(0.62, 0.12, 0.10),
	"bone_white": Color(0.78, 0.76, 0.70),
}
const SEPARATOR := "@"


## `"painted_metal@olive_drab"` -> `{"material": "painted_metal", "paint": "olive_drab"}`; no separator -> an empty paint.
static func split_spec(spec: String) -> Dictionary:
	var at: int = spec.find(SEPARATOR)
	if at < 0:
		return {"material": spec, "paint": ""}
	return {"material": spec.substr(0, at), "paint": spec.substr(at + 1)}


## The colour of paint `id`. An unknown id is `push_error`'d and answers mid-grey, so a typo is visible, never silent.
static func color_of(id: String) -> Color:
	if not PAINTS.has(id):
		push_error("[PaintPalette] unknown paint '%s' (known: %s)" % [id, ", ".join(PAINTS.keys())])
		return Color(0.5, 0.5, 0.5)
	return PAINTS[id]
