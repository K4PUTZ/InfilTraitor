## ImageSource — the one way runtime code reads a PNG as pixels.
##
## Two sources, chosen per path:
## - The raw file, when it is on disk: editor runs and `--script` CLI runs
##   (selftests, bakes). CLI-baked PNGs have never been through the editor's
##   import scan, so `load()` fails with "No loader found" for them.
## - The imported resource, when the raw file is NOT on disk: every exported
##   build (web, Android). An export ships only the imported `.ctex`, never the
##   source PNG, so a raw `Image.load()` fails there — grey walls with no
##   facade, an invisible grenade, silently.
##
## Every PNG in this project imports with `compress/mode=0` (lossless), so the
## imported pixels equal the source pixels — B2 (grayscale) and B3 (alpha from
## canon) hold on both paths.

class_name ImageSource


## Returns the image, or null with `err_out[0]` set to the failing error code.
static func load_image(path: String, err_out: Array = []) -> Image:
	if FileAccess.file_exists(path):
		var img := Image.new()
		var err := img.load(path)
		if err != OK:
			err_out.append(err)
			return null
		return img
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			var img := tex.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				return img
	err_out.append(ERR_FILE_NOT_FOUND)
	return null


## `load_image()` wrapped as an ImageTexture — the shape the sprite loaders need.
static func load_texture(path: String, err_out: Array = []) -> Texture2D:
	var img := load_image(path, err_out)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)
