// bake_compositor.gdshader
//
// GPU composite of material × facade for atlas tile rendering.
// (v1: placeholder; GPU optimization deferred to v1.1)

shader_type canvas_item;

uniform sampler2D material_tile_sampler;
uniform sampler2D facade_sampler;
uniform vec2 facade_uv_origin;       // In facade plane coordinates (voxels)
uniform vec2 facade_plane_dims;      // (64, 32) in voxels
uniform int face_orientation : hint_range(0, 4) = 0;  // 0=NE, 1=SE, 2=SW, 3=NW
uniform int blend_mode : hint_range(0, 2) = 0;       // 0=MULTIPLY, 1=TEXTURE_ONLY, 2=MATERIAL_ONLY

void fragment() {
	// For each fragment (pixel):

	// 1. Silhouette check (is this pixel inside the voxel face?)
	// Skipped in v1; assume all fragments are inside

	// 2. Map fragment → flat texture space
	vec2 flat_uv = UV;  // [0, 1] in tile space; full transform TODO

	// 3. Map flat → facade plane
	vec2 facade_plane_uv = facade_uv_origin + flat_uv * facade_plane_dims;

	// 4. Sample material and facade
	vec4 mat_color = texture(material_tile_sampler, UV);
	vec4 facade_color = texture(facade_sampler, mod(facade_plane_uv, facade_plane_dims) / facade_plane_dims);

	// 5. Blend (multiply)
	vec4 result;
	if (blend_mode == 0) {  // MULTIPLY
		result = mat_color * facade_color.r;  // facade provides luminance
	} else if (blend_mode == 1) {  // TEXTURE_ONLY
		result = facade_color;
	} else {  // MATERIAL_ONLY
		result = mat_color;
	}

	COLOR = result;
}
