# Session summary — 2026-10-10 (afternoon): G-S1 tuning, the capture system planned, the HUD direction

Resume point for the next session. Everything below is on `main`. The previous session's record is
`PROMPTS/RESUMO_SESSAO_2026-10-10_LOAD_GLASS_COLLAPSE.md`.

## 1. Glass (built, `a59da27f`)
- **Crack decal spill 0.7 -> 0.4 voxel** past the hole edge (`crack_edge_spill`, `glass_crack3d.gdshader`).
- **G-S1 waves overlap**: `Room.schedule_glass_collapse()` no longer awaits each wave; they start `GLASS_COLLAPSE_WAVE_GAP_S` = 0.12 s
  apart (was 0.35 s after each finished). The board work stays serialised by `_destruction_render_busy`; only the shards' fall overlaps.
- `verify.py smoke` PASSED (98 s). Moto video `videos/glass_collapse_overlap.mp4` (local, git-ignored): GLASS, a grenade thrown in
  front of the big pane. **Not verified frame by frame that the three waves overlap on screen**: the Director judges the video.
  If the waves still read as separate, the gap is the one number to move.

## 2. The capture system — `PROMPTS/PLANNING/CAPTURE_RAILS_MASTER_PLAN.md` v0.3 (planning, NOTHING built)
Why: captures were cramped portrait frames centred off the scene (the first take of the day flew the camera to dev grenade 0 in
another corner of GLASS; the second was framed by a GU typed by hand). Rulings R1-R11 (§1):
- anchors live in the `.map.json` (`layout`: envelope, POIs, regions, objectives; derived: agent start, bounds, compass, exits, safe
  zone), save / load / a future scenario editor; `capture`: rails and named takes (dev only);
- desktop captures outside perf work, **1920 × 1080**, wide or detail; HUD hidden for engine work, shown for interface work (both
  shapes); the handset only for perf;
- video frame by frame (Movie Maker, fixed FPS), real time later (CR-6);
- rails from the first build; a change of view is a CUT by default, an ORBIT during development (one honest snap of the face tones /
  cutaway / actor light at each half quarter-turn);
- envelope: footprint 18 × 36, reserve 24 × 48 and ≤ 3 compose storeys as warnings; the segment spec numbers move to ONE file
  (`maps/_spec/segment_envelope.json`);
- access points: plumbing only (`MapLayout.exits()` reads the legacy field, `layout.exits` reserved), warning at the top of
  `MAP_MASTER_PLAN` (CR-7).
- Performance check (§2): nothing absurd; GPU headroom ~9 ms on the Moto is the tightest (world-space overlays are measured before
  they are kept); the glass COMMIT frame (~610 ms on GLASS) is a standing debt (`technical_debt.md`, 2026-10-10).

## 3. Interface direction (Director; `INTERFACE_MASTER_PLAN` Part 7, `DESIGN_MASTER_PLAN` platform line)
The desktop is a way to PLAY, in landscape; handsets stay portrait-locked. The HUD is ONE orientation-neutral mechanism: **a 3 × 3 grid
of screen regions in both shapes**, a liquid design, control panels (skills, gadgets) where the thumbs are, indicators in the other
regions, **plus an interface layer on the board placed in GU**. A direction ("só pra ir adiantando"), not yet a design.

## 4. Docs touched
`CAPTURE_RAILS_MASTER_PLAN` (new), `CLAUDE.md` (reference map row), `docs/README.md`, `INTERFACE_MASTER_PLAN` Part 7,
`DESIGN_MASTER_PLAN` (platform, UI line), `MAP_MASTER_PLAN` (access-point warning), `MAPFILE_REFERENCE` (planned sections),
`GLASS_MASTER_PLAN` 1b, `roadmap.md`, `current_state.md` (also carries the auto-generated header / inventory lines that were
pending), `technical_debt.md`, `device_video_recording.md`.

## 5. Next
1. **CAPTURE_RAILS CR-1** on the Director's go: `segment_envelope.json` + its three readers, `MapCompass`, `MapEnvelope`, the `layout`
   owner, `MapCompiler`'s shift, `MapLayout`, `layout_lint` in `verify.py quick`, data for GLASS and PLAYGROUND.
2. Then CR-2 (framing, profiles, HUD switch, stills) and CR-3 (rails, takes, Movie Maker video).
3. Glass: the Director's verdict on the overlapping waves; G-D53 roofs.
