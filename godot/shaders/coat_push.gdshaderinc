// ACTOR D94 — THE LEGS PUSH THE COAT, the vertex half. The reference is `tools/asset_generation/tripo/coat_push.py` (numpy, same maths, same names: read its header for the why);
// `CoatPush3D` sets the uniforms every frame from the skeleton, `tripo_coat_push.py` bakes the vertex data into the model.
//
// Per vertex (baked, in the glTF axes): COLOR.r = 1 - mask (a piece with no colour attribute reads (1,1,1,1) and is never pushed), COLOR.g * 0.1 = the push the REST pose already
// gives it (taken off, so an idle figure is untouched), COLOR.a = its outward direction at rest as one angle (atan2(Z, x) / 2 pi + 0.5: x lateral, Z the front; D95 moved it off UV2, which the emblem's
// zone now uses; COLOR.b is the emblem's mask and plays no part here). A vertex moves along that direction, turned
// with the pelvis, to the far side of every leg capsule its ray crosses; outside the capsule's silhouette the push falls off in a tent; a second pass takes a vertex that landed in another capsule out of it. No state: one pose, one coat.
uniform float push_on = 0.0;                    // 1 when `CoatPush3D` drives this material
uniform vec4 push_cap_a[6];                     // capsule starts (xyz, the skeleton's space) and radius + the cloth's offset (w): thigh, shin, foot of the left leg, then the right
uniform vec4 push_cap_b[6];                     // capsule ends (xyz)
uniform vec4 push_tent = vec4(0.03, 0.12, 0.5, 0.0);   // the tent's least and greatest width and its width per unit of height
uniform mat3 push_pelvis = mat3(1.0);           // the pelvis's turn since the rest pose

// where the ray p + t d, d a unit vector, LEAVES the capsule a-b of radius r (-1e9 when the line misses it)
float coat_push_far(vec3 p, vec3 d, vec3 a, vec3 b, float r) {
	vec3 ba = b - a;
	vec3 oa = p - a;
	float baba = dot(ba, ba);
	float bard = dot(ba, d);
	float baoa = dot(ba, oa);
	float rdoa = dot(d, oa);
	float far = -1e9;
	float qa = baba - bard * bard;              // the cylinder between the caps
	float qb = baba * rdoa - baoa * bard;
	float qc = baba * dot(oa, oa) - baoa * baoa - r * r * baba;
	float h = qb * qb - qa * qc;
	if (h >= 0.0 && abs(qa) > 1e-9) {
		float s = sqrt(h);
		float t0 = (-qb - s) / qa;
		float t1 = (-qb + s) / qa;
		if (baoa + t0 * bard >= 0.0 && baoa + t0 * bard <= baba) {
			far = max(far, t0);
		}
		if (baoa + t1 * bard >= 0.0 && baoa + t1 * bard <= baba) {
			far = max(far, t1);
		}
	}
	float da = rdoa * rdoa - (dot(oa, oa) - r * r);   // the sphere at a, beyond a's cap
	if (da >= 0.0) {
		float s = sqrt(da);
		if (baoa + (-rdoa - s) * bard <= 0.0) {
			far = max(far, -rdoa - s);
		}
		if (baoa + (-rdoa + s) * bard <= 0.0) {
			far = max(far, -rdoa + s);
		}
	}
	vec3 ob = p - b;
	float rdob = dot(d, ob);
	float db = rdob * rdob - (dot(ob, ob) - r * r);   // the sphere at b, beyond b's cap
	if (db >= 0.0) {
		float s = sqrt(db);
		if (baoa + (-rdob - s) * bard >= baba) {
			far = max(far, -rdob - s);
		}
		if (baoa + (-rdob + s) * bard >= baba) {
			far = max(far, -rdob + s);
		}
	}
	return far;
}

// the skinned vertex p of a coat piece, pushed out of the legs
vec3 coat_push(vec3 p, vec4 col) {
	float mask = 1.0 - col.r;
	if (push_on < 0.5 || mask <= 0.0) {
		return p;
	}
	float ang = (col.a - 0.5) * 6.28318530718;
	vec3 d = normalize(push_pelvis * vec3(cos(ang), 0.0, sin(ang)));
	float push = 0.0;
	for (int i = 0; i < 6; i++) {
		vec3 a = push_cap_a[i].xyz;
		vec3 b = push_cap_b[i].xyz;
		float r = push_cap_a[i].w;
		float t_out = coat_push_far(p, d, a, b, r);
		float dc = 0.0;
		if (t_out > 0.0) {
			dc = t_out;                         // inside the silhouette: the far exit
		} else {
			// outside it, seen along d: the tent. rho = the distance to the segment in the plane across d, tau = where along d its nearest point lies
			vec3 qa = a - p;
			qa -= d * dot(qa, d);
			vec3 qb = b - p;
			qb -= d * dot(qb, d);
			vec3 ab = qb - qa;
			float u = clamp(-dot(qa, ab) / max(dot(ab, ab), 1e-12), 0.0, 1.0);
			float rho = length(qa + u * ab);
			float tau = dot(mix(a, b, u) - p, d);
			float w = clamp(push_tent.z * max(tau, 0.0) + push_tent.x, push_tent.x, push_tent.y);
			float l = rho - r;
			if (t_out <= -1e8 && l > 0.0 && l < w && tau > 0.0) {
				dc = tau * (1.0 - smoothstep(0.0, 1.0, l / w));
			}
		}
		push = max(push, dc);
	}
	push = max(push - col.g * 0.1, 0.0) * mask;
	if (push > 0.000001) {
		// a vertex that was moved out of one capsule into another leaves that one too (no tent here: a vertex that stayed keeps the rest overlaps it was baked with)
		vec3 q = p + d * push;
		float more = 0.0;
		for (int i = 0; i < 6; i++) {
			more = max(more, coat_push_far(q, d, push_cap_a[i].xyz, push_cap_b[i].xyz, push_cap_a[i].w));
		}
		push += more * mask;
	}
	return p + d * push;
}
