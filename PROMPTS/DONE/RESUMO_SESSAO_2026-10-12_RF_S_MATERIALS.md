# Session summary — 2026-10-12 (second half): RF-S per material, one-layer walls

Resume point for the next session. Everything is on `main`. Plan: `PROMPTS/PLANNING/ROOF_MASTER_PLAN.md` (v0.19, records in §5); the first half is `RESUMO_SESSAO_2026-10-12_RF_S.md`.

## 1. What a SHOT does to each material now
| Material | Fall of the broken voxels | Rest |
|---|---|---|
| concrete, brick | a 4x4x4 block per voxel crumbles back against the shot after a 0.33 s hold (three presets), piles | brick: the hole's inside is the FLAT material colour (no facade), only the front rubble layer keeps the texture; `FRESH_LIFT` 1.0 |
| stone | nothing falls (`RubblePresets.NO_FALL`) | the bullet-hole dust at 25% (`dust_chance` in the profile), amassed only with a pistol |
| wood | splinters (`RubblePresets.SPLINTERS`): per cube a hash gives FLY (thrown at the impact, a little farther, saved as rubble), STAY (the hole's ragged rim, saved) or GONE | VFX chips fan wider and fade, a floor stamp where they land; the hole's inside keeps the texture and is 1.3x lighter (`FRESH_KEEPS_FACADE`, `FRESH_LIFT_OF`) |
| plywood (madeirite) | wood's splinters with fewer full blocks (15%), more hollow, textured flying cubes; **tear** (`ShotPunchTable.TEAR_SIZE`) + **punch-out** | a shotgun's pellets open a CROUCH passage (`[SHOT-PASSAGE]`); the hole's inside has the normal shade |
| cardboard, fabric | no rubble behind, no splinters, no dust; tear + punch-out only | a little soot, darker smoke in the opening, floor stamps (the wood art, tinted: no art of their own), the opening's inside is SCORCHED (`FRESH_CLEAN_OF` 0, `FRESH_LIFT_OF` 0.6) |
| metal | nothing falls | keeps its sparks |

**Tear** (hole-only materials: plywood 4, cardboard 5, fabric 6 cells): each destroying hit takes an irregular patch (hashed random walk, down preferred), the SAME cells on both slices, so `PassageQuery`'s pair rule counts them. **Punch-out**: the middle of the break (an ellipse of `ZONE_RADIUS` around the centre of the shot's destroyed cells, plus floating islands) is cut out whole on every face of the edge; its voxels become shaded blocks thrown WITH the shot (`Room.spawn_shot_rubble(..., forward)`), 35% slump out on the shooter's side; they land as saved rubble. Blocks are built `BLOCKS_PER_FRAME` (5) per frame.

## 2. Geometry: one-layer materials (Director)
Glass, cardboard and fabric are ONE layer in every situation; the COMPILER enforces it (`EdgeExtractor.is_thin_material`). A solid block / divider of one of them keeps the OUTER shell (the layer in the neighbouring GU); `side: "inner"` on the item keeps it in its own GU. PLAYGROUND measured by `probe_store`: cardboard and fabric 2048 -> 1024 voxels, brick and plywood unchanged. The corner columns come from `JunctionResolver` (it already places a column when both legs occupy the OUTER cell of the elbow). Without a specified room, "inside" is the inside of the perimeter; a straight wall with no room: the algorithm picks a side, `side` overrides later.

## 3. Moto g04s (release APK, PLAYGROUND, portrait, `MAX_FPS=0`)
Logs `docs/measurements/device_2026-10-12_moto_rfs_*.log` and `..._moto_battery_*.log` (git-ignored). Shot tail after the fixes: plywood 81-95 ms (223 before the cap and the chunking), brick 63-95, wood 89, stone 22. See the end of this file for the final battery.

## 4. Tooling facts learned
- `INFILTRAITOR_SHOT_AGENT_CELL` / `SHOT_GUARD_CELL` are INTERNAL coordinates (GU + 5); the scenario's `centre` is GU. PLAYGROUND internal x: brick 27-30, cardboard 31-34, fabric 35-38, plywood 39-42, wood 22-25, stone 17-20, y 7-8. A zoom of 4.0 hangs the capture; 2.6 works.
- `verify.py smoke` is the default tier; a failed run (`smoke-boot` 12 s) after a capture Godot had just ended passed on the rerun: do not chain a commit behind it without checking the exit.
- macOS has no `timeout`; `sed -i` needs a suffix; zsh does not word-split.

## 5. NEXT (Director, 2026-10-12)
1. Explosions: carry splinters, dust and stamps into each material's blast behaviour (complementing what exists), then repeat everything for the ROOFS, including shots at the ceiling, adapting the falling-rubble animation (step 5 of RF-1, R-D10, then 6 and 7).
2. `side` on `panels` (windows and frames default to the INNER GU).
3. Automatic tests and the compiler's lock (a selftest for the one-layer rule, the shot ladder with TEAR, the punch-out).
4. Banners / posters / curtains with no thickness: the props milestone.
5. Owed: a darker-room check of the scorched / fresh insides; stamp art for cardboard and fabric (today the wood art, tinted); the Galaxy A16 round.

## 6. Final Moto battery (same APK as the last commit of the session, one boot per case, `MAX_FPS=0`, `FRAME_PROBE=1`, `--mem-poll 5`)
Logs `docs/measurements/device_2026-10-12_moto_battery_*.log` (git-ignored). Idle 17.5-18.8 ms/frame in every case (nothing moved at idle). Shot tail / worst 1 s `process` window (a held maximum): stone 23.7 / 111, wood 76.0 / 126, fabric 100.2 / 130, brick 91.8 / 132, cardboard 109.9 / 135, **plywood 135.7 / 166** (81-95 on the two earlier boots: boot to boot noise of ~40 ms). Standard grenade 0 (`throw 0 29,6`): worst frame **109.0 ms**, mean 22.2 over 299 frames (the known ~100-117 band). PSS read by `--mem-poll` 0.63-0.69 GB in every case, **not cross-checked against the 0.89-0.91 GiB PLAYGROUND rows of 2026-10-09** (the field parsed may differ). Verdict: no anomaly in idle or in the grenade; the plywood shot (72 voxels broken, 132 sub-voxels built over several frames) and the cardboard shot sit at or just above the 100 ms line of a shot tail: repeat them and, if it holds, spread the tear's voxel writes. The Galaxy A16 was not attached.
