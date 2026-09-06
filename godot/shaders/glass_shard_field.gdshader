// GLASS G6b-1 — the falling-shard field.
//
// One MultiMesh, one texture, one draw call: the member is chosen PER INSTANCE
// from custom data rather than by which of five nodes the shard lives in.
//
// ⚠️ `INSTANCE_CUSTOM.x` IS THE ATLAS CELL, and it is an index, not a UV. It is
// written by `ShardField.push()` as `GlassShardShapes.index_of(id)`, so the array
// order in `IDS` is what makes the two agree — reordering that array silently
// renames every shape here.
//
// ⚠️ FLAT. Interpolating the cell index across a quad would sample a blend of two
// members along the diagonal, which reads as a smear rather than as a shard.
shader_type canvas_item;
render_mode blend_mix;

uniform float atlas_cells = 5.0;

varying flat float inst_cell;
varying vec4 inst_color;

void vertex() {
	inst_cell = INSTANCE_CUSTOM.x;
	inst_color = COLOR;
}

void fragment() {
	// The mesh's own UV runs 0..1 over the quad; the cell is a slice of U.
	vec2 uv = vec2((UV.x + inst_cell) / max(atlas_cells, 1.0), UV.y);
	COLOR = texture(TEXTURE, uv) * inst_color;
}
