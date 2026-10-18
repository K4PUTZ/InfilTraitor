# Session record — M6 liquids, 2026-10-17 / 10-18

Resume point for the next session: **M6 is built through F1-F8 and the fire of F5 (oil); open: the handset cost of the fire, the rest of F5, F7, F9-F12.** The master record is `MATERIALS_MASTER_PLAN` §6 (task list F0-F12 and the blocks under it); this file is the index of what this session decided, built and measured.

## Director rulings (all recorded in the plan)
- Footprints: up to 8 prints, the first well marked and each lighter, then they fade over N turns. Guards noticing and following them: AI + MOVEMENT milestones (the print data is in `FootprintMarks3D._marks`; expose a read then).
- Protection gadgets (boots, suits): props milestone, as multipliers on `gameplay.exposure` / `wade_ap`. A lethal dose returns to the CHECKPOINT (the room reset stands in; the mission flow is the GAMEPLAY milestone).
- Manipulable world objects (valve, switches, alarms, computers, panels, levers, handles; shooting glass / lamps / supports): left click = menu, right click = default action, double tap for precision on mobile: PROPS milestone. Dev stand-in until then: `FLUID_VALVE`.
- **No overflow.** Containers rise and fall to the container's own level. Flooding a whole segment (F12) is SHELVED as a future expansion (the measured model is in the plan).
- Fire (F5): anything explosive, incendiary arrows and shots light a flammable liquid; the front runs some GU a turn, then burns in a real-time loop; it burns, kills, lights the place while lit; water / extinguishers put it out. The water pistol, wall extinguishers, candles, fireplaces, bonfires, torches: props / gameplay milestones. The oil must stay dark and the flames themselves are the fire.

## Built
- `FluidPlane`: lean loop (bit-identical to the first form, digest pinned), `rounds_per_tick()` by cell size and `rounds_scale` by fluidity, incremental tick (`begin_tick` / `step_rounds`) with `committed` truth for the rules, a worker thread (`threaded`, dev flag `FLUID_THREAD`), `consume()`. PIPE_LAB's channel runs at 0.5 GU cells.
- `LiquidFire` (+ `Room.ignite_liquids`, blast and shot hooks, `LIQUID_IGNITE`), `LiquidFlameTongues` (tongues of flame, shader `liquid_flame3d`), `LiquidFlames` (ember sparks), the sheet's `fire_surface` dial. Footprints: 8, fading. Dev scripts: `FLUID_VALVE`, `LIQUID_IGNITE`.
- Benches: scenario step `flood <off|level|plane05|plane025|ch1|ch4|ch8|ch8q>`, `tools/persistent/flood_scenario.py` (`--f8`, `--stress`, `--extra`), `tools/persistent/fire_scenario.py`. Takes on PIPE_LAB: `valve_rise_fall`, `oil_fire` (final) and `oil_fire_a`..`d` (the experiments).
- Selftests: `fluid_plane_selftest` (digest, incremental, worker, thick rounds), `liquid_fire_selftest` (sweep, fade, tongues), `liquid_rules_selftest`, `liquid_registry_selftest`. `verify.py` (smoke tier) green at every commit.

## Measured (Moto g04s unless said; details and tables in the plan)
- One channel was 102 ms a tick on the main thread; now 8 channels cost +0.9 ms/frame (187 -> 27 ms), worker thread 26.3 ms; at the old 0.25 GU cells 91 -> 32 ms. Galaxy A16: free at 0.5 GU.
- Whole-segment flood: the plane is 855 ms (0.5 GU) / 3.2 s (0.25 GU) a tick; a flat water sheet +11 ms of GPU (26 -> 37 ms); over the stress blasts +4 ms.
- **NOT measured: the flames on a handset** (neither was attached at the end). Galaxy with the first, orange-sheet version showed no cost; the tongues (about 200 additive quads) and the embers have not run on either handset.

## Open
- Run `fire_scenario.py` on the Moto and the Galaxy (idle vs fire, `FLAME_STYLE` both / embers / tongues) and record it under the F5 blocks.
- Fire as a real light (the board's light planes cost a repaint: measure first); a checkpoint keeping `LiquidFire.state()`; the valve / extinguisher input (props); the rest of F5 (acid / toxic corrosion, cryogenic freezing, lava crust plates, quicksand); F7 rain (needs weather); F9-F11 (movement / props / gases); F12 (shelved).
- A blast's reach is the constant `BLAST_IGNITES_LIQUID_GU` (3 GU): move it to bomb data when a second explosive needs another.

## Added late on 2026-10-18 (read with the plan's F5 rounds and the "Channel margin" block)
- Fire final: yellow tongues only (blue rejected), 4 a cell, sway / wind / per-tongue flicker, flames follow the oil depth, oxygen under roofs, sparks + fagulhas, smoke when a cell goes out. `FluidPlane.surface_cap` and PIPE_LAB curbs 4 voxels / brim 3 (the margin rule: curb = brim + at least one voxel).
- **First thing next session: dig the channel** (plan block "NEXT SESSION"); then run `fire_scenario.py` on the Moto and the Galaxy (still unmeasured).
