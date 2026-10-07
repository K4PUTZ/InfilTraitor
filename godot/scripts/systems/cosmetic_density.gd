## CosmeticDensity — how many purely decorative particles a device is asked to draw.
##
## Roadmap step A1 (2026-10-07): the shard rain, the ember burst, the smoke blobs and the debris
## pieces scale per device; GAMEPLAY NEVER DOES. Only sites that draw and own no state may ask
## `scaled()` — a count that feeds the plan, the store, a damage roll or a persisted record must not.
##
## `DevFlags` sets `factor` at boot from `COSMETIC_DENSITY` (`low` / `mid` / `high`, or a float in
## (0, 1]). The default is 1.0, which returns every count unchanged, so the desktop and every gate
## are bit-identical to before this class existed.
class_name CosmeticDensity

const TIER_LOW: float = 0.4
const TIER_MID: float = 0.7
const TIER_HIGH: float = 1.0
const FLOOR_FACTOR: float = 0.1

static var factor: float = TIER_HIGH


## A tier name or a number to a factor; anything else is reported and answers `fallback`.
static func parse(raw: String, fallback: float = TIER_HIGH) -> float:
	var text: String = raw.strip_edges().to_lower()
	match text:
		"":
			return fallback
		"low":
			return TIER_LOW
		"mid":
			return TIER_MID
		"high":
			return TIER_HIGH
	if not text.is_valid_float():
		push_warning("[CosmeticDensity] COSMETIC_DENSITY=%s is not low/mid/high or a number; using %f" % [raw, fallback])
		return fallback
	return clampf(float(text), FLOOR_FACTOR, 1.0)


## `count` scaled by the device factor, never below `minimum` (a decorative effect thins, it does
## not vanish). The identity at factor 1.0.
static func scaled(count: int, minimum: int = 1) -> int:
	if factor >= 1.0:
		return count
	return maxi(minimum, int(round(float(count) * factor))) if count > 0 else count
