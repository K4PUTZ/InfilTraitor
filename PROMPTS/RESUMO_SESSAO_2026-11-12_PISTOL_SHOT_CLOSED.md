# Session record — 2026-11-12: the pistol shot; the pistol cycle closed on both figures

- **Shot (`a2ef3ba5`):** `ActorRecoil3D` (procedural kick of both arms about the gun's lateral axis, back to the aim in ~0.3 s), the gun's own
  kick, the aim held 0.6 s after the shot; `ShellCasings3D` (spent case to the shooter's right, bounces on `stand_height`, stays for the map,
  one MultiMesh, cap 256; not in the checkpoint). Take `pistol_shot` on one frontal view (`agent_shot_rail`, `079bc444`).
- **Female:** the same code, checked on the take with `TRIPO_FIGURE=female`.
- **Male:** the Director's pistol placement at frame 15 (`60bb40bb`) and his coat fix in `DrawFix` (103 vertices, `992977ee`;
  `glb_add_morph.py`, then `godot --headless --import`). Note: `DrawFix` peaks at frame 12, so an edit there shows most at the draw.
- **Closed by the Director:** idle + draw + aim + shot + holster, both figures (MOVEMENT §6).
- Not measured: the Moto (below the 5 % rule). Next: the Director's call (other weapons, crouch / prone, throw on the Tripo figure).
