# CAPTURE_RAILS_MASTER_PLAN
## The map's spatial anchors in GU, and a capture system that frames them by itself — v0.1 (planning, nothing built)

> **Status: 🟡 v0.1, 2026-10-10 — opened by the Director; NOTHING is built.** Three decisions were ruled when the plan was asked
> for (§1); the open ones are in §11. Stages CR-1 to CR-7 (§9) wait for the Director's read of this file.
>
> **Why this exists (Director, 2026-10-10):** *"você sistematicamente executa testes com a tela muito apertada, em modo retrato,
> que muitas vezes estão centralizados na parte de fora da cena que importa."* The same day's video proved it twice: the first
> take (`detonate 0` on GLASS) flew the camera to dev grenade 0 in another corner of the map and recorded 17 s of a wall; the
> second was framed by a GU typed by hand (`centre 12,10`, `zoom 0.5`) on a 390×844 portrait screen. **The cause is not
> carelessness: no file says where the scene that matters IS.** Every capture today re-derives it from memory and guesses.
>
> **Related:** `docs/technical/MAPFILE_REFERENCE.md` (the section contract this extends), `docs/systems/MAP_MASTER_PLAN.md`
> (`MapSpec`, `LevelGraph`, access points, Rule 7), `docs/DESIGN_MASTER_PLAN.md` §14 (segment structure, mission structure),
> `PERFORMANCE_BUDGET_MASTER_PLAN` (the segment's measured envelope, §5 / PB-7), `DEVICE_DIAGNOSTICS_MASTER_PLAN` (the handset
> chain), `docs/DIRECTION_GLOSSARY.md` (the compass), `docs/pipelines/device_video_recording.md`.

---

## 1. What the Director ruled (2026-10-10)

| # | Ruling | Consequence here |
|---|---|---|
| R1 | **The anchors live in the `.map.json`**, managed by the map systematically, so they save, load and round-trip — and a future scenario editor (to be planned) reads and writes them. | New registered sections (§4), loud-fail, versioned, unknown keys round-trip verbatim (the MAPFILE contract). Formal constants (§3) are written once and read by every consumer. |
| R2 | **Video is frame by frame** (deterministic); **a real-time check is needed eventually.** | Godot's Movie Maker under a fixed FPS is the default path (§7); a real-time path is its own later stage (CR-6). |
| R3 | **Rails from the first build**, standing on a formalised space: cardinal points, geometric bounds with some slack for future expansion (guides, never engine limits), the agent's start, the segment's objective / exit, points of interest. | The layout model (§3-§4) is CR-1, before the camera; the rails (§6) ship in CR-3, not "later". |
| R4 | **Outside performance work, captures are DESKTOP**, zoomed well out for global events or centred for detail, as the need dictates. | Capture profiles (§5); portrait on a handset is the `perf` profile only. |
| R5 | **The HUD is hidden in captures of engine work and shown in captures of interface work.** | A profile property, applied through the HUD facade (rule 11 / L3), never by reaching into a node. |

---

## 2. The performance check the Director asked for (R1: "confirm nothing is absurd")

The question: before formalising the segment's bounds as constants, is anything in the measured budget unreasonable, given what is
still coming (guard AI, the gameplay mechanics, items, clothes / accessories)? The numbers are `PERFORMANCE_BUDGET` §0f-§0h
(Moto g04s = the floor device; HEAVY = the densest ratified segment).

| Budget (§0d) | HEAVY on the Moto | Headroom | What is still coming that spends it | Verdict |
|---|---|---|---|---|
| PSS ≤ 1.0 GiB at the peak | 757 MiB (Galaxy 741) | **~260 MiB** | guards ~0.8 MiB each (24 guards +9); clothes / accessories are palettes and shader uniforms (D34: only archetype × silhouette multiplies a mesh); items are props (~0.3 MiB each after the first block); a second guard rig (Q4) would be the largest single item | **Comfortable.** The one thing that could eat it in one step is a material that reads the screen or the depth buffer (~250-295 MiB of driver memory on the Galaxy, §0c 8-10) — already a written rule |
| Play frame ≤ 33.3 ms, GPU included | idle GPU 24.4 ms | **~9 ms** | the GPU floor is the board's geometry, not content (§0e); guards +0.1 ms each; **the coming 3D overlays are the risk**: vision cones, the planned VISUAL SOUND interface, objective markers — fragment-heavy, transparent, full-screen-ish layers on a Mali-G57 MP1 | **Tightest margin, but not absurd.** Every new world-space overlay is measured on the Moto uncapped (`MAX_FPS=0`) before it is kept; a `discard` or a subpass-merged transparent pass costs ~8-10 ms there (memory note) |
| Frag grenade hit-stop ≤ 200 ms, 100 ms elsewhere | worst stage 152 ms (Galaxy 73) | ~48 ms | more props near a blast (the 30-prop cliff was cut, §0f) | **OK.** ⚠️ **One known exception: the glass COMMIT frame, ~610-620 ms on the Moto on the GLASS map** — 3× the hit-stop budget. It is tolerated only because a segment carries ≤ 12 GU of small panes (PB-1); the G-S1 collapse added a ~900 ms worker walk (off-frame, fine). **"Glass is practically done" holds for the look and the mechanics, not for this frame**: a map with big panes would breach §0d. Recorded, not opened here |
| Load | 7.6 s cold / 4.65 s reload | — | more content scales the store build and the light apply roughly linearly | Q5 accepted ~12 s; fine |
| CPU, guard AI | **not measured** | — | A\*, vision rays per TIC, the alert meter (rule 5) | **Unknown, not alarming:** the game is turn-based, so AI runs on the enemy turn and can be spread across frames. A per-frame budget for it should be set when the AI is built (a proposal: ≤ 4 ms per frame on the Moto, spread) |

**Conclusion:** nothing in the measured envelope is absurd. Two items need a rule, not a redesign: (1) every new world-space
overlay is measured on the Moto before it is kept; (2) the glass COMMIT frame is a standing debt that any big-pane map reopens.
The segment bounds below can be formalised on the HEAVY measurement.

---

## 3. The formal space (the constants, written once)

### 3.1 Coordinates

- **Map space = the internal GU grid** (`MapSpec`'s playable space; the buffer ring is applied only in `MapCompiler`, rule 7).
- **A point is `[x, y, z]`**: `x`, `y` in GU, fractional allowed **on the voxel lattice (multiples of 1/8 GU)**, the same rule as
  `ground_decals.at`; `z` in **storeys above the playable ground**, fractional allowed (1 storey = 8 levels). `z` is RELATIVE on
  purpose: an absolute level in a file is the trap rule 9 exists for. The runtime converts with `board.ground_plane_level()` /
  `GeometryCoords.storey_level_base()`, never a literal.
- **A box is `{min: [x, y, z], max: [x, y, z]}`** in the same units, `min < max` on every axis.
- **World conversion has ONE function** (`MapLayout.to_world(point) -> Vector3`, base coordinates, view-independent): GU `x` → world
  `x`, GU `y` → world `z`, storeys → world `y` through the board's own storey height and `VERTICAL_SCALE`. Every consumer (framer,
  overlay, editor) calls it; nobody re-derives the scale.

### 3.2 The compass of a map (derived, never authored)

From `DIRECTION_GLOSSARY` §2-§4, at view N (yaw 0): the map rectangle's corners are the compass vertices and its sides are the wall
faces' names.

| Name | What | In GU (inner `W × H`) |
|---|---|---|
| corner **N** | top vertex | `(0, 0)` |
| corner **E** | right vertex | `(W, 0)` |
| corner **S** | bottom vertex | `(W, H)` |
| corner **W** | left vertex | `(0, H)` |
| side **NE** | `y == 0` | the N-E edge |
| side **SE** | `x == W` | the S-E edge |
| side **SW** | `y == H` | the S-W edge |
| side **NW** | `x == 0` | the N-W edge |

These are BASE names: they do not change when the camera yaws (R3D-ROT: rotation is camera-only). An access point, an exit, the
safe zone and a rail's camera direction are expressed with them. `MapCompass` (a small static helper) answers them; nothing types
`"y == 0"` again.

### 3.3 The bounds and the envelope

| Constant | Value | Source | Kind |
|---|---|---|---|
| Segment footprint | **18 × 36 GU** | Q2 (Director 2026-10-08), measured as HEAVY | guide, checked by PB-7 for segment maps |
| Buffer ring | 5 GU | `board.buffer` | derived from the map |
| Playable storeys | 1 | memory: upper storeys only compose height | design |
| Compose height (guide) | ≤ 3 storeys above the playable one | GLASS's tallest pane | guide (Q-CR3) |
| **Expansion reserve** | **proposal: 24 × 48 GU** (the footprint + one third per axis) | — | **warning only, never an error**: past it the map is outside what PB-3 measured; a map there must re-run `pb3_study.py --only HEAVY` |
| Content counts | HEAVY row of `segment_spec` | `PERFORMANCE_BUDGET` §5 | gate (PB-7) |

**One authority for these numbers (a finding, not a new rule):** today the segment spec's numbers live in Python
(`gen_segment_map.SPECS`, read by `segment_budget.py`) and the prose table in §5 of the budget plan. A GDScript consumer (the
layout validator, the future editor) would be a third copy. CR-1 moves them to ONE data file, `maps/_spec/segment_envelope.json`,
read by the generator, the PB-7 gate and the runtime (`MapEnvelope`); the plan's §5 table points at it. Values unchanged.

---

## 4. The map sections (R1)

Two new section owners in `map_sections_v1.gd`, each `{"v": 1}`, loud-fail, both round-trip through `map_lint`'s golden check.
They are SEPARATE because they have different readers: `layout` will be read by gameplay (objectives, exits, the safe zone), the
editor and the camera; `capture` is dev tooling only and must never be read by gameplay.

### 4.1 `layout` — the map's anchors

```json
"layout": {
  "v": 1,
  "envelope": {"reserve": [24, 48], "compose_storeys": 3},
  "poi": [
    {"id": "big_pane",    "at": [12.5, 9.0, 1.5], "tags": ["glass", "detail"]},
    {"id": "throw_front", "at": [12.0, 10.5, 0.0], "tags": ["event"]}
  ],
  "regions": [
    {"id": "glass_wing", "box": {"min": [9, 7, 0], "max": [22, 12, 3]}, "tags": ["glass"]}
  ],
  "objectives": [
    {"id": "obj_terminal", "kind": "reach_terminal", "at": [15.5, 4.5, 0.0]}
  ],
  "exits": [
    {"id": "exit_main", "side": "SE", "cells": [[17, 30], [17, 31]], "role": "main"}
  ]
}
```

| Field | Content | Owner rule |
|---|---|---|
| `envelope` | the per-map reserve and compose height, overriding §3.3's defaults (optional) | guide only |
| `poi` | points of interest: `id`, `at`, `tags` (free strings; `detail` / `wide` / `event` are understood by the capture system) | new |
| `regions` | named 3D boxes: `id`, `box`, `tags` | new |
| `objectives` | `id`, `kind` (one of `DESIGN` §14.2's list: `reach_terminal`, `neutralise`, `undetected`, `recover_item`, `escort`, `sabotage`, `survive`), `at` or `region` | new; **data only** — no gameplay reads it until the mission system exists; no text (rule 6: logic ≠ narrative; any label is a `tr()` key elsewhere) |
| `exits` | the segment's ways out: `side` (§3.2), `cells`, `role` (`main` / `secondary` / `secret`, `DESIGN` §14.1) | ⚠️ **see "two authorities" below** |

**Derived, NOT stored in `layout` (one authority each):**
- **the agent's start** stays in `actors.agent_start`; `MapLayout.agent_start()` reads it there;
- **the bounds and the compass** come from `board.inner_size` / `buffer`;
- **the 2-GU safe zone** (`DESIGN` §14.1) is derived from the entry side;
- **the access points** today live in `legacy_compiler.access_points` (and the runtime's `exit_cells`, and `LevelGraph`'s
  connections for `access_from_graph` maps).

⚠️ **Two authorities — remove one.** `exits` in `layout` would describe the same thing as `legacy_compiler.access_points`. CR-1
does NOT add `exits`; it ships `poi`, `regions`, `objectives` and the read API, and `MapLayout.exits()` reads the legacy field.
Moving access points to their native home (the legacy field migrated by a section migration, then removed — not mirrored) is
CR-7, a `MAP_MASTER_PLAN` change that needs the Director's sign-off because `MapCompiler` and `LevelGraph` read it.

### 4.2 `capture` — rails and takes (dev only)

```json
"capture": {
  "v": 1,
  "rails": [
    {"id": "glass_overview_then_pane", "keys": [
      {"frame": "wide",   "target": "glass_wing", "yaw": "N", "hold": 30},
      {"frame": "detail", "target": "big_pane",   "yaw": "N", "move": 45, "hold": 120, "ease": "in_out"},
      {"frame": "wide",   "target": "glass_wing", "yaw": "N", "move": 45, "hold": 60}
    ]}
  ],
  "takes": [
    {"id": "glass_blast", "profile": "engine", "rail": "glass_overview_then_pane",
     "event": "throw 0 @throw_front", "start_key": 0, "event_at_key": 1, "frames": 900}
  ]
}
```

- **A rail key** = how to frame (`wide` / `detail` / `fit` / `explicit`), a `target` (a `poi` or `region` id, or a raw point / box),
  a `yaw` (`N`/`E`/`S`/`W`, base names), `move` (frames to travel from the previous key), `hold` (frames to stay), `ease`. Durations
  are in **frames**, not seconds: a take runs under a fixed FPS, and an effect fired alongside a stall must age in drawn frames
  (memory: animate in frames).
- **A take** = a profile + a rail + the event that happens (a scenario step whose GU arguments may name an anchor with `@id`) + when
  it fires relative to the rail + the total length. A take is what a person or Claude asks for by name: "grava o `glass_blast`".
- **The `@id` substitution** is the fix for both of today's mistakes: the event and the camera read the SAME anchor, so they cannot
  point at different places.

---

## 5. Capture profiles (R4, R5)

| Profile | Machine | Canvas | HUD | Dev panels | FPS | Use |
|---|---|---|---|---|---|---|
| **`engine`** (default) | desktop | `framing desktop` 1280 × 720 (Q-CR1: 1920 × 1080 for video?) | **hidden** | off | fixed 60 | board, VFX, destruction, light, glass, props — anything that is not the interface |
| **`ui`** | desktop | **`framing portrait` 390 × 844** (see note) | **shown** | off | fixed 60 | interface work |
| **`perf`** | handset (Moto / Galaxy) | portrait, as shipped | as the player sees it | off | real time | measurements and the device video (`device_record.py`) only |

**Note on `ui` (licensed skepticism):** R4 says desktop outside performance work, and `ui` does run on the desktop — but the game
is PORTRAIT by default (Director, 2026-10-09) and the HUD is laid out for it; a 1280 × 720 frame would show a HUD arrangement no
player sees. Recommendation: the `ui` profile uses the desktop machine with the portrait canvas. Overrule it and it becomes
`framing desktop` in one line (Q-CR2).

**Hiding the HUD goes through the facade** (rule 11 / L3): `HudController.set_capture_hidden(bool)` hides the HUD's canvas layer(s)
and remembers it; the scenario op `hud on|off` and the profile call it; `hud_seam_selftest` gains one check that the method exists
and hides what it says. Nothing outside `hud_controller.gd` names a HUD node.

---

## 6. Framing that is computed, not typed

### 6.1 What the camera is today (read from the code)

- `CameraController` drives a `Camera2D` (zoom clamp `ZOOM_MIN` 0.20 .. `ZOOM_MAX` 1.20, a leash of 4 tiles outside the map);
  `Board3DLive._process()` maps its screen centre to a GU ground point and puts the orthographic `Camera3D` there:
  `size = viewport_height / zoom / px_per_unit`, pitch −30°, yaw 45° + the view's yaw. One GU = one world unit; `px_per_unit` ≈ 181.
- The scenario's `centre` takes a **whole** GU (`Vector2i`) and `zoom` goes through the gameplay clamp.

### 6.2 Two facts that make "frame it" impossible today

1. **A whole segment does not fit at the gameplay zoom floor.** An 18 × 36 GU ground rectangle at yaw 45° projects to ~38.2 world
   units wide and ~19.1 tall (before any wall height). At the desktop canvas (1280 × 720) and zoom 0.20 the camera shows ~19.9 tall
   and ~35.4 wide: **the width does not fit**, and a wall height on top makes it worse. A `wide` take of a segment needs ~0.15-0.17.
   The gameplay clamp is right for the player and wrong for a capture.
2. **A whole-GU centre cannot centre a region** whose middle is a half GU (and a 3D box's visual centre is never on the ground grid).

### 6.3 The fix

- **`CaptureFramer`** (pure, a static class, no nodes): given the camera basis for a yaw, the viewport size and a set of world
  points (the 8 corners of a box, or a point + radius), it returns the ground point the camera must look at and the zoom that fits
  them with a margin. Orthographic maths: project the corners onto the camera's right / up axes; the extents give the size
  (`max(h, w / aspect) × (1 + margin)`), the mid-point gives the centre, slid along the view direction to the ground plane.
  - `wide` = the region (or the whole map + ring for `target: "map"`) with a 10 % margin;
  - `detail` = the target tight, 5 % margin, never below a minimum box of 3 × 3 × 1 GU (so a point POI still frames a scene);
  - `fit` = a list of targets together; `explicit` = a raw centre + zoom (escape hatch, logged).
- **A capture camera API on `Room`**: `set_capture_view(centre_gu: Vector2, zoom: float, yaw: String)` — a fractional centre, a
  **capture zoom range** (proposal 0.08 .. 2.0) that does not touch `ZOOM_MIN` / `ZOOM_MAX`, the leash released (as DEV_VISION
  already releases it). Only the capture path calls it.
- **`frame_check <name>`**: prints `[FRAME-CHECK] <name> target=<id> inside=yes margin=<px> yaw=<N>` by projecting the target's corners
  through the REAL `Camera3D` after the frame is drawn — the framer checked against the camera, not against itself.

---

## 7. Video, frame by frame (R2)

- **Godot's Movie Maker** (`--write-movie <file> --fixed-fps 60`): the engine renders every frame with a fixed delta and writes it,
  whatever the real frame time. The particles, the smoke and the soot fade age exactly as in play; the run is reproducible with
  `INFILTRAITOR_RNG_SEED`. No project tool uses it today (`build_filmstrip.py` grabs the viewport per frame itself).
- Output: a PNG sequence or MJPEG `.avi` (to be measured in CR-3: disk and time per second of video) → `ffmpeg` → `videos/<take>.mp4`
  (git-ignored), optionally a contact sheet (one frame per N) from the SAME frames — the filmstrip becomes a by-product of a take.
- **One command:**
  ```
  python3 tools/persistent/capture.py --map GLASS --take glass_blast            # the video
  python3 tools/persistent/capture.py --map GLASS --take glass_blast --sheet 1s # + a contact sheet, one frame per second
  python3 tools/persistent/capture.py --map GLASS --still big_pane --yaw E      # one framed still
  ```
  It boots the desktop Godot with the take compiled into a `SCENARIO` string, waits, transcodes, prints the path; the result is
  rendered in the conversation (CLAUDE.md: every capture is shown).
- **Real time (R2, later — CR-6):** a frame-by-frame video cannot show a stall (the fixed delta hides it). Two instruments: the
  handset (`device_record.py`, already built, profile `perf`), and on the desktop the same take at real speed recorded from the
  window (`ffmpeg -f avfoundation`; needs macOS Screen Recording permission for the terminal — the Director's action, once), with a
  small frame-number + frame-ms stamp in a corner so a hitch is visible and attributable.

---

## 8. A layout overlay (for the eye, and the editor's first piece)

`view_mode layout` (the existing dev-overlay toggle path, English labels): draws in world space, depth-tested like every new VFX
(RENDER3D rule), the map bounds, the buffer ring, the envelope reserve (dashed), the compass letters on the corners, the side names,
the agent's start, the exits, every POI (a pin + its id) and region (a wire box + its id), and a selected rail's path with its
keys. It costs nothing when off. It is how the Director checks that `big_pane` is where its name says, and it is the first visible
piece of the scenario editor (§10).

---

## 9. The stages

Each stage closes with `verify.py` at its tier, a commit on `main`, and its evidence pasted (CLAUDE.md).

| Stage | What | Closes when |
|---|---|---|
| **CR-0** | This plan; the Director's answers to §11 | ruled |
| **CR-1 — layout data** | `maps/_spec/segment_envelope.json` (one authority, §3.3; generator + PB-7 read it); `layout` section owner v1 (`envelope`, `poi`, `regions`, `objectives`); `MapLayout` read API (`to_world`, `poi`, `region`, `agent_start` from `actors`, `exits` from the legacy field, compass, bounds, safe zone) and `MapCompass`; `layout_lint` in `verify.py quick` (unique ids, inside bounds + ring, `min < max`, lattice, objective kinds, envelope warnings); data for **GLASS** and **PLAYGROUND**; `gen_segment_map.py` writes a `layout` for the SEG maps | `map_lint` golden round-trip green with the new section; `layout_lint` self-test red-then-green on a bad file; `MapLayout` selftest |
| **CR-2 — framing** | `CaptureFramer` + selftest (four yaws, box / point / map, margin honoured); `Room.set_capture_view()`; HUD facade `set_capture_hidden()`; scenario ops `profile`, `hud`, `frame <target> [wide|detail|fit] [yaw]`, `frame_check` | a `frame_check` on GLASS reads `inside=yes` for every region in all four yaws (real boot); a still of `glass_wing` wide and `big_pane` detail, HUD off, shown to the Director |
| **CR-3 — rails, takes, video** | `capture` section owner v1; `CaptureRail` (per-frame interpolation of centre / zoom; a yaw change is a cut, not a tween, unless Q-CR4 says otherwise); scenario op `rail <id>`; `@id` substitution in events; `capture.py` (Movie Maker → mp4, `--sheet`, `--still`); the `glass_blast` take | the `glass_blast` video, shown; two runs of the same take differ by 0 frames' content under the seed (determinism earned before it is trusted — CLAUDE.md) |
| **CR-4 — layout overlay** | §8 | a still of GLASS with the overlay, shown |
| **CR-5 — tools onto takes** | `build_filmstrip.py` becomes a take + `--sheet` per frame; `device_record.py --take` (the `perf` profile, the same anchors, portrait framing computed by the framer); CLAUDE.md's capture section rewritten around profiles. **Then** the 22 `INFILTRAITOR_CAPTURE_*` env vars and `room.gd`'s capture actions are listed with every reader and every side effect (memory: deleted function side effects) and retired **only with the Director's OK** | the old tools produce the same evidence through takes |
| **CR-6 — real time** | desktop real-time recording of a take + the frame stamp (§7) | a take recorded both ways, the stall visible only in the real-time one |
| **CR-7 — access points native** (needs sign-off; `MAP_MASTER_PLAN`) | `layout.exits` becomes the owner; `legacy_compiler.access_points` migrated by a section migration and removed; `MapCompiler` / `LevelGraph` read `MapLayout` | one authority; `map_lint` + selftests green |

**Size estimate:** CR-1 and CR-2 are the bulk of the value (they fix both of today's mistakes); CR-3 is the rails and the video.
CR-4 to CR-7 can wait without blocking anything.

---

## 10. The future scenario editor (to be planned — what this plan already gives it)

Not designed here. What CR-1..CR-4 deliberately leave ready for it: every anchor has a stable `id`; every section has an owner with
`serialize` / `deserialize`; the editor writes through those owners, never by patching JSON; `MapLayout.to_world()` and the
inverse (a picked ground point back to GU on the voxel lattice) are the only conversions; the layout overlay (§8) is the editor's
viewport layer. The editor's own plan decides placement UI, undo, and how it writes `actors` / `walls` / `props`.

---

## 11. Open questions (the Director's)

1. **Q-CR1 — resolution of the `engine` profile:** 1280 × 720 (today's `framing desktop`, light files) or 1920 × 1080 for video?
2. **Q-CR2 — the `ui` profile's canvas:** portrait 390 × 844 on the desktop (recommended, §5) or the desktop canvas?
3. **Q-CR3 — the envelope numbers:** reserve 24 × 48 GU and ≤ 3 compose storeys as WARNING thresholds (§3.3) — or other values?
4. **Q-CR4 — yaw inside a rail:** a change of view is a cut (cheap, exact: the game's own rotation is a quarter-turn snap) or a
   smooth orbit (prettier, shows a camera the player never has)?
5. **Q-CR5 — CR-7:** move the access points into `layout` now that the editor is on the horizon, or leave the legacy field until the
   mission system needs it?
