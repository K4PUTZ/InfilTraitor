## ModelPaths — where every model lives under ASSETS/MODELS, the game's one place that knows (the Director, 2026-11-19).
##
## The game asks here instead of typing `res://ASSETS/MODELS/...`, so a reorganisation is an edit of this file. Its twin for the
## tools is `tools/asset_generation/model_paths.py`; the two must agree (that file's header has the layout): one folder per
## character, the stages inside it (source, base, work, game, textures). The game only ever reads `game/` and `textures/`.
class_name ModelPaths
extends RefCounted

const MODELS := "res://ASSETS/MODELS"
const FIGURES: PackedStringArray = ["female", "male"]


## an Agent figure's file in its game/ folder (`figure` in any case)
static func agent_game(figure: String, file_name: String) -> String:
	return "%s/actors/agent/%s/game/%s" % [MODELS, figure.to_lower(), file_name]


## the built Agent: AGENT_<FIG>.glb, or the LIGHT one
static func agent_rig(figure: String, light: bool) -> String:
	return agent_game(figure, "AGENT_%s%s.glb" % [figure.to_upper(), "_LIGHT" if light else ""])


## an enemy's file: faction = FID | CALM_WATERS | BUNSEN | CORP, character = e.g. guard_male, stage = game | textures
static func enemy(faction: String, character: String, stage: String, file_name: String) -> String:
	return "%s/actors/enemies/%s/%s/%s/%s" % [MODELS, faction, character, stage, file_name]
