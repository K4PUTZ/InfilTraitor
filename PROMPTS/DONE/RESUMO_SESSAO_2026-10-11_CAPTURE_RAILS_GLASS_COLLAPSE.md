# Session summary — 2026-10-10/11: CAPTURE_RAILS built, the glass collapse reformed (G-D55), Moto optimisation started

Resume point for the next session. Everything below is on `main`; the Director APPROVED the glass design ("O design está aprovado").
Tag `alpha/glass-3d-explosion` marks the approved look (before the under-the-flash swap experiment, `effde8e9`).

## 1. CAPTURE_RAILS (`PROMPTS/PLANNING/CAPTURE_RAILS_MASTER_PLAN.md`) — CR-1..CR-6 built, CR-7 parked
- Map anchors in GU: `layout` section (POIs with optional `extent`, regions, objectives, envelope), `MapLayout` / `MapCompass` /
  `MapEnvelope`, one envelope file `maps/_spec/segment_envelope.json`; validated at load.
- Capture: `capture/profiles.json` (engine 1280x720 everyday, `showcase` 1920x1080, `ui` portrait + landscape, `perf` handset),
  computed framing (`CaptureFramer`), rails + named takes (`capture` section; defaults overview / region:<id> / poi:<id>),
  `@id` cell arguments in any scenario, HUD switch through the facade, off-screen Movie Maker video (`capture.py --take`, `--still`,
  `--sheet`, `--realtime` timing run), `device_record.py --take`, `build_filmstrip.py --take`, layout overlay (`view_mode layout`).
- 8 orphan capture demos deleted (room.gd -1 588 lines); tool-backed and UI-state actions kept.
- GLASS takes: `glass_blast`, `glass_hole`, `glass_edge`.

## 2. Glass (`GLASS_MASTER_PLAN` 1c / 1d and the 1b block)
- Shards: gravity (per-shard drag + pop), bright start + spin glint, 1..4 per voxel. Rim walls of holes carry the crack ink (base 0.08).
- **G-D55 (supersedes G-D52's three waves):** unsupported glass falls VOXEL BY VOXEL (`GlassVoxelFall3D`, MultiMeshes): rests ~1/3 s
  (slight far/low lead), own g / push / tumble, carries its crack piece (`crack_per_voxel`), lands on its own column's top, then shards
  (one rain on the fall's clock) + a dust puff per impact.
- Cracked panes: the decal on the THICKNESS (strips folded over the corner, toned per edge) and on the BACK face (twin quad, each side
  drawn only from outside, `crack_side`).
- The swap is seamless: fall shown in the remesh-commit step, crack cut held until then (`VoxelBoard.glass_occ_hold`), materials warmed.
- The support is walked IN THE COOK on the predicted world; the swap happens under the flash.

## 3. Moto g04s numbers (GLASS, release APK, uncapped)
- Spike attack: release spread over frames + crack occupancy as bytes: 233-266 → ~180 ms (tagged state).
- Under-the-flash swap (`8a886371`): the cook is ~0.7-0.9 s longer; the blast's heavy frames 702 / 427 / 341 / 279 ms (were 619 / 488 / 278).

## 4. NEXT SESSION — optimise the glass explosion on the devices (Director: "quantas rodadas forem necessárias")
Options to try, measured on the Moto and the Galaxy, one at a time:
1. Run the collapse's swap a few frames AFTER the blast's flush (still hidden by motion), instead of on its heavy frames.
2. Extend the flash by one or two frames to hide more work. ⚠️ **Photosensitive epilepsy:** the flash is an inverted full screen;
   longer / repeated flashes are a strobe — keep any change under the WCAG 2.3.1 limit (no more than three flashes in any one second)
   and consider an accessibility option to soften it.
3. Cut the glass COMMIT frame itself (the standing ~600-700 ms debt on GLASS): attribute it first (FrameSplit / timers).
4. The collapse's own dirty pass (108 ms when it shares the blast's frames, 31 alone) and the board commit (10 ms).
Also parked (roadmap): free 360° orbit on ALT (camera-only today; the logical view needs to follow a continuous yaw).
