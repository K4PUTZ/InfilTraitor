## ACTOR_MASTER_PLAN objects track — generic ground contact shadow (Director,
## 2026-07-28): "não precisa estar conectada com o sistema de iluminação...
## é só pra ficar mais claro onde está posicionada a arma em relação ao
## chão." A deliberately dumb, static soft blob under a floating/elevated
## prop — NOT wired to LightRegistry/VoxelLightField, NOT direction-aware,
## just a fixed dark ellipse that reads as "this is the object's ground
## contact point," reusable by any FloatingCollectible-style object.
##
## The blob texture is a small radial-alpha gradient generated once per
## process and cached at the class level (every ContactShadow instance
## shares the same Texture2D) — cheap enough that per-object tuning is just
## `configure()`'s scale/alpha, no new bake step needed per collectible.
class_name ContactShadow
extends Sprite2D

const TEXTURE_SIZE := 64

static var _cached_texture: Texture2D = null


func _init() -> void:
	texture = _get_or_build_texture()
	centered = true


## radius_px: on-screen radius (before squashing) the shadow should read as.
## squash_y: vertical flatten factor — < 1.0 turns the circle into a
## ground-hugging ellipse (isometric "puddle" convention). alpha: peak
## opacity at the blob's center.
func configure(radius_px: float, squash_y: float = 0.35, alpha: float = 0.4) -> void:
	var tex_radius := float(TEXTURE_SIZE) * 0.5
	var s := radius_px / tex_radius
	scale = Vector2(s, s * squash_y)
	modulate = Color(0.0, 0.0, 0.0, alpha)


static func _get_or_build_texture() -> Texture2D:
	if _cached_texture != null:
		return _cached_texture
	var img := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(TEXTURE_SIZE, TEXTURE_SIZE) * 0.5
	var radius := float(TEXTURE_SIZE) * 0.5
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center) / radius
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a  ## soften the falloff — linear reads as a hard-edged disc
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_cached_texture = ImageTexture.create_from_image(img)
	return _cached_texture
