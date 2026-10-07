## Roadmap A1 (2026-10-07) — CosmeticDensity: the default is the identity (so every gate stays bit-identical), the tiers thin a count
## without erasing it, a bad value is refused loudly (falls back), and the factor is clamped to its floor.
extends SceneTree

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _init() -> void:
	print("\n== COSMETIC DENSITY SELFTEST ==\n")
	CosmeticDensity.factor = CosmeticDensity.TIER_HIGH
	_check(CosmeticDensity.scaled(22) == 22 and CosmeticDensity.scaled(3000) == 3000, "factor 1.0 is the identity")
	_check(CosmeticDensity.parse("") == 1.0, "unset = high (1.0)")
	_check(CosmeticDensity.parse("low") == CosmeticDensity.TIER_LOW and CosmeticDensity.parse("MID") == CosmeticDensity.TIER_MID, "tier names (case-insensitive)")
	_check(is_equal_approx(CosmeticDensity.parse("0.5"), 0.5), "a number is taken as is")
	_check(is_equal_approx(CosmeticDensity.parse("0.0"), CosmeticDensity.FLOOR_FACTOR) and CosmeticDensity.parse("7") == 1.0, "clamped to [floor, 1]")
	_check(CosmeticDensity.parse("banana") == 1.0, "garbage falls back to high")
	CosmeticDensity.factor = CosmeticDensity.TIER_LOW
	_check(CosmeticDensity.scaled(22) == 9 and CosmeticDensity.scaled(3000) == 1200, "low thins 22 -> 9, 3000 -> 1200")
	_check(CosmeticDensity.scaled(2) == 1 and CosmeticDensity.scaled(1) == 1, "never below the minimum (a thin effect does not vanish)")
	_check(CosmeticDensity.scaled(0) == 0, "zero stays zero")
	CosmeticDensity.factor = CosmeticDensity.TIER_HIGH
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
