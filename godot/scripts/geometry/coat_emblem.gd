## CoatEmblem — the coat's emblem as DATA (ACTOR D95, 2026-11-02): the mesh carries only a zone (UV2 + COLOR.b, `tripo_coat_push.py`); the logo is `emblem_<id>.png`, resolved here through the facades'
## tier ladder — user `user://textures/emblems/` over default `res://ASSETS/emblems/` over none (one loud log line, a plain coat) — and handed to the coat's shader (`actor_coat3d.gdshader`).
## A user file is local: its owner sees it, nobody else (the server's item is what others see, `COSMETICS`). Never "decal" in a name: that is the DAMAGE decals' word (`check_decal.py`).
class_name CoatEmblem

const FOLDER: String = "emblems"
const DEFAULT_DIR: String = "res://ASSETS/"
## The zone's height / width (`tools/asset_generation/tripo/coat_decal_zone.json`, `aspect_h_over_w`; a selftest pins the two together). A logo of another aspect is FITTED inside, never stretched.
const ZONE_ASPECT: float = 1.5405


## ONE texture per emblem id for every coat that wears it (measured on the Moto g04s 2026-11-02: nine coats each making their own took ~250 MB of PSS, a new GPU allocator block). `clear_cache()` after the user's file changes.
static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


## The texture for `emblem_id` (e.g. "emblem_ref_skull") fitted to the zone, or null when no tier has a valid file. `resolver` is optional (tests pass one with their own folders).
static func texture_for(emblem_id: String, resolver: TextureResolver = null) -> ImageTexture:
	if resolver == null and _cache.has(emblem_id):
		return _cache[emblem_id] as ImageTexture
	var r: TextureResolver = resolver if resolver != null else TextureResolver.new("", DEFAULT_DIR)
	var resolved: TextureResolver.ResolvedTexture = r.resolve(emblem_id, FOLDER)
	if resolved.image == null:
		push_warning("[CoatEmblem] %s: no emblem in any tier (user://textures/%s/ or %s%s/); the coat stays plain" % [emblem_id, FOLDER, DEFAULT_DIR, FOLDER])
		return null
	print_debug("[CoatEmblem] %s from %s" % [emblem_id, "USER" if resolved.tier == TextureResolver.Tier.USER else "DEFAULT"])
	var img: Image = fitted(resolved.image)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	if resolver == null:
		_cache[emblem_id] = tex
	return tex


## `img` placed (contain, centred, transparent around) on a canvas of the zone's aspect.
static func fitted(img: Image) -> Image:
	var src: Image = img.duplicate()
	src.convert(Image.FORMAT_RGBA8)
	var w: int = src.get_width()
	var h: int = src.get_height()
	var cw: int = w
	var ch: int = h
	if float(h) / float(w) > ZONE_ASPECT:
		cw = int(ceil(float(h) / ZONE_ASPECT))
	else:
		ch = int(ceil(float(w) * ZONE_ASPECT))
	if cw == w and ch == h:
		return src
	var canvas := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.0, 0.0, 0.0, 0.0))
	canvas.blit_rect(src, Rect2i(0, 0, w, h), Vector2i((cw - w) / 2, (ch - h) / 2))
	return canvas


## Gives `coat_material` (a ShaderMaterial of `actor_coat3d.gdshader`) the emblem, or turns it off when there is none. -> true when an emblem is on.
static func apply(coat_material: ShaderMaterial, emblem_id: String, resolver: TextureResolver = null) -> bool:
	if coat_material == null:
		return false
	var tex: ImageTexture = texture_for(emblem_id, resolver) if emblem_id != "" else null
	coat_material.set_shader_parameter("emblem_tex", tex)
	coat_material.set_shader_parameter("has_emblem", 1.0 if tex != null else 0.0)
	return tex != null
