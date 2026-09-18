// RENDER3D R3D-4d — swapped onto a 2D prop's sprites while a PropBillboard3D draws them in the 3D
// board. It exists so the prop's own `visible` stays the game's logical state (the throw code hides
// a detonated grenade with it) instead of being borrowed to mean "the 3D board draws me".
shader_type canvas_item;

void fragment() {
	discard;
}
