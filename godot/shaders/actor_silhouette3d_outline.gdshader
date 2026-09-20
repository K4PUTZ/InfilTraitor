// RENDER3D R3D-7 — the OUTLINE pass of a revealed actor's silhouette. See actor_silhouette3d.gdshaderinc.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never;

#define OUTLINE_PASS
#include "res://godot/shaders/actor_silhouette3d.gdshaderinc"
