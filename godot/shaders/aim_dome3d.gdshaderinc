// AIM-DOME-3D (2026-10-09) — what every pass of the grenade aim dome shares (`AimBubbleOverlay`).
//
// SPACE: `v_p` is the fragment's position relative to the dome's floor centre in GU, x = grid x, z = grid y, y = up in
// storeys (1 storey == 1 GU, `GeometryCoords.LEVELS_PER_STOREY == VOXELS_PER_UNIT_AXIS`). The walls arrive in the same
// space as `seg_a` / `seg_z`, the packed records `AimBubbleOverlay._nearby_wall_segments()` builds.
//
// LINES are measured in SCREEN pixels, as the 2D polylines were: a line is the zero set of a field `f`, and
// |f| / |∇f| (screen-space derivatives) is the fragment's distance to it in pixels. The 2D widths were canvas pixels at
// 2D zoom 1, i.e. `width / px_per_unit` world units; `px_per_world()` turns that into render-target pixels.
const int MAX_SEGMENTS = 32;
uniform vec3 dome_color = vec3(1.0, 0.66, 0.30);  // display value, decoded to linear once
uniform float radius = 2.0;
uniform int seg_count = 0;
uniform vec4 seg_a[MAX_SEGMENTS];  // (1 = the wall separates cells along x, plane offset, span min, span max)
uniform vec2 seg_z[MAX_SEGMENTS];  // (bottom, top) of the wall, storeys above the floor
uniform float px_per_unit_2d = 112.0;
// Model space to GU: the shell and the floor disc are unit meshes scaled by the radius here; the wall patches are built in GU.
uniform float vertex_scale = 1.0;

// Every pass's vertex() sets it: `v_p = VERTEX * vertex_scale;`.
varying vec3 v_p;

vec3 dome_linear() {
	return mix(pow((dome_color + 0.055) / 1.055, vec3(2.4)), dome_color / 12.92, lessThan(dome_color, vec3(0.04045)));
}

// Distance along the unit direction `dir` to the nearest wall that ray really hits (its span AND its height range:
// a parapet cuts only the low part); a huge number when none. `AimBubbleOverlay._wall_hit_distance()`, per fragment.
float wall_hit(vec3 dir) {
	float best = 1e9;
	for (int i = 0; i < MAX_SEGMENTS; i++) {
		if (i >= seg_count) {
			break;
		}
		vec4 a = seg_a[i];
		bool axis_x = a.x > 0.5;
		float d_axis = axis_x ? dir.x : dir.z;
		if (abs(d_axis) < 0.0001) {
			continue;
		}
		float t = a.y / d_axis;
		if (t <= 0.0 || t >= best) {
			continue;
		}
		float along = (axis_x ? dir.z : dir.x) * t;
		float up = dir.y * t;
		if (along >= a.z && along <= a.w && up >= seg_z[i].x && up <= seg_z[i].y) {
			best = t;
		}
	}
	return best;
}

// Is `p` on the dome's real volume, or does a nearer wall stop the ray from the centre first?
bool dome_reaches(vec3 p) {
	float d = length(p);
	if (d <= 0.0001) {
		return true;
	}
	return wall_hit(p / d) >= d - 0.001;
}

// Render-target pixels per world unit, orthographic camera (`KEEP_HEIGHT`: |PROJECTION_MATRIX[1][1]| = 2 / size; the sign
// is the API's y flip).
float px_per_world(mat4 proj, vec2 viewport) {
	return viewport.y * abs(proj[1][1]) * 0.5;
}

// Coverage of a line `width_2d` canvas pixels wide centred on the zero set of `f`.
float line_cov(float f, float width_px) {
	float g = length(vec2(dFdx(f), dFdy(f)));
	float d = abs(f) / max(g, 1e-6);
	return 1.0 - smoothstep(width_px * 0.5 - 0.6, width_px * 0.5 + 0.6, d);
}

// Coverage of a band `width_px` wide INSIDE a boundary where `f` falls to 0 (an outline drawn on the shape's own side).
float edge_cov(float f, float width_px) {
	float g = length(vec2(dFdx(f), dFdy(f)));
	float d = f / max(g, 1e-6);
	return 1.0 - smoothstep(width_px - 0.6, width_px + 0.6, d);
}

// Paints `over` (alpha) over `under`: everything here is one hue, so only the alpha composites.
float over_alpha(float under, float over) {
	return under + over * (1.0 - under);
}
