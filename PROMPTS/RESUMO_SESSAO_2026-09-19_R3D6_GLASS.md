# Session summary — 2026-09-19 — R3D-6 item 2 (glass look parity)

**Resume point:** R3D-6 item 2 is BUILT and awaiting the Director's ratification of the look
(plan: `PROMPTS/PLANNING/RENDER3D_MASTER_PLAN.md`, R3D-6 item 2). Items 3–7 not started.

## Commits (all on `main`, pushed at session end)
| Commit | What |
|---|---|
| `bd8e8a79` `[R3D-6a]` | Glass on the 3D board: one back-reading pass replaces the flat blue (tint MULTIPLY with body floor, frost, sheen, per-member tint) |
| `9cf81430` `[R3D-6a]` | The maths now runs in sRGB like the 2D shader |
| `092774a3` `[R3D-6a]` | Multiply force 0.60 → 0.68 on the 3D board only (Director: slightly more blue) |
| `0f16e449` `[R3D-6b]` | `GlassCrackMirror3D` — every 2D `GlassCrackSprite` mirrored onto the pane plane |
| `ac126c17` `[R3D-6c]` | Pane caps dimmed per plane (top 0.60, thickness 0.78) via vertex `COLOR.r` |
| `20a98b9c` `[R3D-6d]` | Full remesh when the blast's consequence beat lands |
| `5daa978f` `[R3D-6d]` | `CONSEQUENCE_REMESH` flag for the A/B; plan updated |

## Findings worth remembering
1. **The 3D screen texture is linear and ALBEDO is encoded on the way out.** A formula ported raw
   from the 2D shader applied tint^(1/2.2): effective multiply (0.81, 0.87, 0.96) against the
   asked (0.61, 0.72, 0.91). Measured by rendering `behind`, `behind*mul` alone and the full result.
   The "dim actor behind the pane" was the same defect, not the ratified billboard behaviour.
2. **Insensitivity to a parameter is a signal.** Changing `glass_mul_strength` 0.60 → 0.85 moved
   nothing in some regions; that is what led to the colour-space cause. Two earlier hypotheses
   (back-face double tint; additive term ∝ tint) were tested and rejected by measurement.
3. **`delta.touched_voxels` is INCOMPLETE** (3 692 named vs 3 867 changed in the store on GLASS
   grenade #0). The shattered pane and the floor crater stayed drawn in 3D. Found only on the Moto
   because the desktop `glass_crack_demo` punches its hole through another path. Worked around by
   rebuilding every chunk at the beat's end; **the delta itself is still open.**
4. `device_run.py` runs need `INFILTRAITOR_AUTO_SCREENSHOT=1` for desktop capture actions
   (`INFILTRAITOR_CAPTURE_ACTION` alone did nothing); `timeout` does not exist on macOS;
   `sed -i` needs `''`; new `class_name` files need `preload` until the editor rescans; device
   `*.log` files are git-ignored; capture actions read `OS.get_environment`, not `DevFlags`,
   so they cannot run on the handset — use `INFILTRAITOR_SCENARIO="detonate 0"` there.

## Evidence
Desktop, GLASS, `--fixed-fps 60`, in `Screenshots/history/`:
`glass_crack_demo_r3d6_{2d,3d_flat,3d_sat}_before.png`, `glass_crack_demo_r3d6c_{2d,3d}_after.png`
(crack: 5 494 px changed in 3D, 0 before, 6 002 in 2D), `glass_crack_demo_r3d6d_3d_before.png`
(caps), `r3d6e_blast_{2d,3d}_after.png` (3D before the fix), `r3d6g_blast_3d_after.png`
(0 px from a forced full remesh). Handset: `moto_r3d6_glass_{2d,3d,3d_fix}.png`.

Moto g04s, GLASS + grenade #0, `RENDER3D=1`, same APK, `CONSEQUENCE_REMESH` 1 vs 0:
mean 41.5 / 40.5 ms vs 41.4 / 41.2 ms; worst 2 556 / 2 513 ms vs 2 504 / 2 530 ms (the cook,
frames 62–63, pre-existing). The remesh is 566 ms in the background, 6.4 ms of main-thread upload.
2D, same scenario: mean 120.6 ms, worst 3 998 ms, 23.3 s wall vs 11.9 s.

## Open / next
- **Ratify** the glass look (paired captures above).
- **Rim wedge** (CRACK-03/04 torn silhouette around a hole) NOT built — 3D holes are rectangular;
  needs a per-hole alpha discard on the pane; Moto cost unknown.
- **Floor shards** the 2D draws as tiles are absent in 3D.
- **Craze / crack on faces other than SW** not captured.
- **Fix `delta.touched_voxels`** so the commit remesh is complete, then the full rebuild can go.
- No selftests run this session; `check_invariants` / codemap passed as commit hooks.
- R3D-6 items 3 (decals), 4 (dents), 5 (whole facades), 6 (floor dim / embers / soot), 7 (anything
  the reference set shows) not started. The 3D floor is brighter than the 2D one (74 vs 59 in
  the sampled region) — an item 6 candidate.
- The handset has no `dev_flags.cfg` left on it (removed).
