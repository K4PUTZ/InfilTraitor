# CAPTURE_RAILS_MASTER_PLAN
## The map's spatial anchors in GU, and a capture system that frames them by itself — v0.3 (planning, nothing built)

> **✅ CR-1 to CR-6 BUILT 2026-10-10 (the retirement of the old capture actions waits for the Director, CR-5; CR-7 parked).** §10's rows
> have what changed against the plan. **Proof take:** `python3 tools/persistent/capture.py --map GLASS --take glass_blast --sheet 30`
> → `videos/GLASS_glass_blast.mp4` (904 frames, 1672×936): wide on the glass wing, move onto the big pane, the grenade on
> `@throw_front` (cell 18,16), the blast, G-S1's waves (25 / 109 / 42 voxels), an orbit to E. **Two runs: 904 of 904 frames
> byte-identical** (seed 1). **Found while building:** (1) the screen is 1920×1080, so a 1920×1080 window cannot exist: the largest
> same-aspect window that fits was used at first — **then (Director: the machine may be in use, a stray click) the window
> goes OFF SCREEN (`--position 4000,4000`): it still draws and Movie Maker writes the exact 1920×1080; stills are the last frame of a
> short Movie Maker run (the off-screen window itself is clamped by the OS)**; (2) Movie Maker records at the project's base size (390×844) whatever `--resolution` says:
> `capture.py` writes a marked `override.cfg` for the run and deletes it; (3) a point POI cannot frame a 6-GU pane: POIs take an
> optional `extent` [x, y, z].
>
> **Status: 🟡 v0.3, 2026-10-10 — R11 recorded: the HUD is a 3×3 grid of screen regions in both shapes plus an interface layer on
> the board in GU (§1, §9b; the design itself belongs to `INTERFACE_MASTER_PLAN` Part 7). NOTHING is built.** Next: CR-1 (§10) on
> the Director's go.
>
> v0.2, 2026-10-10: the five questions of v0.1 RULED (R6-R10); the mechanism of every element detailed (§3-§8).
>
> v0.1, 2026-10-10: opened by the Director.
>
> **Why this exists (Director, 2026-10-10):** *"você sistematicamente executa testes com a tela muito apertada, em modo retrato,
> que muitas vezes estão centralizados na parte de fora da cena que importa."* The same day's video proved it twice: the first
> take (`detonate 0` on GLASS) flew the camera to dev grenade 0 in another corner of the map and recorded 17 s of a wall; the
> second was framed by a GU typed by hand (`centre 12,10`, `zoom 0.5`) on a 390×844 portrait screen. **The cause is not
> carelessness: no file says where the scene that matters IS.** Every capture re-derives it from memory and guesses.
>
> **Related:** `docs/technical/MAPFILE_REFERENCE.md` (the section contract this extends), `docs/systems/MAP_MASTER_PLAN.md`
> (`MapSpec`, `LevelGraph`, access points, rule 7), `docs/DESIGN_MASTER_PLAN.md` §14 (segment and mission structure),
> `PERFORMANCE_BUDGET_MASTER_PLAN` (the segment's measured envelope, §5 / PB-7), `INTERFACE_MASTER_PLAN` Part 7 (orientation),
> `docs/DIRECTION_GLOSSARY.md` (the compass), `docs/pipelines/device_video_recording.md` (the handset video).

---

## 1. Rulings (Director, 2026-10-10)

| # | Ruling | Where it lands |
|---|---|---|
| R1 | **The anchors live in the `.map.json`**, managed by the map systematically: saved, loaded, round-tripped, and read / written by a future scenario editor (to be planned). Formal constants are written once. | §3, §4 |
| R2 | **Video frame by frame** (deterministic); **a real-time check eventually.** | §8; CR-6 |
| R3 | **Rails from the first build**, standing on a formalised space: cardinal points, geometric bounds with slack for expansion (guides, never engine limits), the agent's start, the segment's objective / exit, points of interest. | §3-§7 |
| R4 | **Outside performance work, captures are DESKTOP**, wide for global events, centred for detail. | §5 |
| R5 | **HUD hidden for engine work, shown for interface work.** | §5.3 |
| R6 (Q-CR1) | **The `engine` profile renders 1920 × 1080.** | §5.1 |
| R7 (Q-CR2) | **`ui` captures the portrait canvas — and the HUD must be BIVALENT.** *"Modo desktop também significa jogar na tela horizontal (ainda não temos interface, apenas mockups)."* Then, the same day: *"Na prática vamos evitar layouts que só funcionem na orientação A ou B. Queremos um mecanismo neutro, próximo do quadrado, aproveitando os 4 cantos disponíveis."* | §5.1; recorded in `INTERFACE_MASTER_PLAN` Part 7 |
| R11 | **The screen is 9 regions (3 × 3) in BOTH shapes, plus an interface layer ON THE BOARD, placed in GU.** *"Vamos ter painéis com skills, gadgets, e outros indicadores visuais em cada região. A gente faz um design líquido ocupando essas zonas, priorizando os painéis de controle na posição mais confortável para os dedos, e indicadores nas demais. Enfim, só pra ir adiantando."* A direction, not yet a design. | §5.1, §9b; `INTERFACE_MASTER_PLAN` Part 7 |
| R8 (Q-CR3) | **Envelope: reserve 24 × 48 GU, ≤ 3 compose storeys, as warnings.** | §3.3 |
| R9 (Q-CR4) | **A change of view inside a rail is a CUT by default; during development the rails ORBIT smoothly.** | §7.4 |
| R10 (Q-CR5) | **Access points: only the plumbing now, plus a warning in the maps plan.** | §4.5; `MAP_MASTER_PLAN` top note |

**R7 + R11 in full:** "desktop" is a way to PLAY — on a computer, in a landscape window — not only a dev view. The HUD is **ONE
orientation-neutral mechanism, not two layouts**: the screen is a **3 × 3 grid of regions** in both shapes; panels (skills,
gadgets) and indicators fill the regions in a liquid design, the CONTROL panels in the regions most comfortable for the thumbs and
the indicators in the others; nothing may depend on the screen being tall or wide (no full-width bar, no side column that only fits
one shape). A second layer of interface lives ON THE BOARD, placed in GU (§9b). The same mechanism serves the phone (portrait,
default, locked on handhelds) and the desktop (landscape). Handsets stay portrait-locked: a
runtime orientation change on the Galaxy A16 reopens the 256 MiB allocator block (`PERFORMANCE_BUDGET` §4). This amends the canon
line "mobile-first, portrait" for the desktop only; `INTERFACE_MASTER_PLAN` Part 7 said such a ruling was needed and records it.

---

## 2. The performance check (R1: "confirm nothing is absurd")

The numbers are `PERFORMANCE_BUDGET` §0f-§0h: the Moto g04s (the floor device), the HEAVY segment.

| Budget (§0d) | HEAVY on the Moto | Headroom | What is still coming that spends it | Verdict |
|---|---|---|---|---|
| PSS ≤ 1.0 GiB at the peak | 757 MiB (Galaxy 741) | **~260 MiB** | guards ~0.8 MiB each; clothes and accessories are palettes and shader uniforms (D34: only archetype × silhouette multiplies a mesh); items are props (~0.3 MiB each after the first block); a second guard rig (Q4) is the largest single item | **Comfortable.** One step can eat it: a material that reads the screen or the depth (~250-295 MiB of driver memory on the Galaxy) — already a written rule |
| Play frame ≤ 33.3 ms, GPU included | idle GPU 24.4 ms | **~9 ms** | the GPU floor is the board's geometry, not content (§0e); guards +0.1 ms each; **the coming world-space overlays** (vision cones, the VISUAL SOUND interface, objective markers) are fragment-heavy and transparent on a Mali-G57 MP1 | **Tightest, not absurd.** Every new world-space overlay is measured on the Moto uncapped (`MAX_FPS=0`) before it is kept |
| Frag grenade hit-stop ≤ 200 ms, 100 ms elsewhere | worst stage 152 ms | ~48 ms | props near a blast (the 30-prop cliff was cut, §0f) | **OK, one exception: the glass COMMIT frame, ~610-620 ms on the Moto on GLASS** — 3× the budget. Tolerated because a segment carries ≤ 12 GU of small panes (PB-1). **Glass is done in look and mechanics, not in this frame**: a big-pane map breaches §0d. Recorded, not opened here |
| Load | 7.6 s cold / 4.65 s reload | — | grows roughly with content | inside Q5's ~12 s |
| CPU, guard AI | **not measured** | — | A\*, vision rays per TIC, the alert meter | **Unknown, not alarming**: turn-based, so the AI can spread over frames. Set its per-frame budget when it is built (proposal: ≤ 4 ms per frame on the Moto) |

**Conclusion:** nothing is absurd. Two rules, no redesign: a new world-space overlay is measured on the Moto before it is kept; the
glass COMMIT frame is a standing debt that a big-pane map reopens. The capture system itself costs nothing in a release build:
`layout` is a few hundred bytes of data, and everything under `capture` runs only in dev scenarios.

---

## 3. The formal space

### 3.1 Units and the one conversion

| Quantity | Unit | Lattice | Notes |
|---|---|---|---|
| `x`, `y` (plan) | GU, **inner** coordinates (`MapSpec`'s playable space) | 1/8 GU (one voxel), as `ground_decals.at` | GU cell `i` spans `[i, i+1)`: `12.5` is the middle of cell 12 |
| `z` (height) | **storeys above the playable ground** | 1/8 storey (one level) | relative on purpose: an absolute level in a file is the trap rule 9 exists for |
| a point | `[x, y, z]`, or `[x, y]` = on the ground (`z = 0`) | | |
| a box | `{"min": [x, y, z], "max": [x, y, z]}` | | `min < max` on every axis |
| a duration | **frames** at the take's fixed FPS | integer | never seconds (memory: animate in frames) |

**Rule 7 holds:** the file and `MapLayout`'s public API speak inner coordinates; the buffer offset is added in ONE place,
`MapCompiler`, which emits the compiled layout in raw coordinates (`compiled["layout"]`). The inverse (a picked raw cell back to
inner, for the editor) is `MapCompiler.raw_to_inner()`, also the only one.

**World space** (the 3D board): one GU = one world unit, raw GU `x` → world `x`, raw GU `y` → world `z`; one storey = one world
`y` unit × `Board3DLive.VERTICAL_SCALE` (8 levels per storey, a level = 1/8). `MapLayout.to_world(point) -> Vector3` and
`to_world_box(box) -> AABB` are the only conversions; the framer, the overlay and the editor call them and nobody re-derives the
scale. Anchors are BASE coordinates: a rotation (camera-only since R3D-ROT) never touches them.

### 3.2 The compass (derived, never authored)

From `DIRECTION_GLOSSARY` §2-§4 (view N): the map rectangle's corners are the compass vertices, its sides carry the wall faces' names.

| Name | What | Inner GU (`W × H`) | Outward step (glossary `edge_delta`) |
|---|---|---|---|
| corner `N` / `E` / `S` / `W` | the four vertices | `(0,0)` / `(W,0)` / `(W,H)` / `(0,H)` | — |
| side `NW` | `x == 0` | column 0 | `(-1, 0)` |
| side `NE` | `y == 0` | row 0 | `(0, -1)` |
| side `SE` | `x == W-1` | last column | `(+1, 0)` |
| side `SW` | `y == H-1` | last row | `(0, +1)` |

`MapCompass` (static, no state) answers: `corner(name, size)`, `side_of(cell, size) -> String` (`""` inside), `side_cells(side,
size)`, `outward(side)`, and `views_facing(side) -> Array[String]` — the views whose camera sees that side's outer face, read from
`Board3DLive.VIEW_FACE_SLOTS` (the board's own table, never a second copy). Every anchor that names a direction uses these names;
nobody writes `y == 0` again.

### 3.3 Bounds and the envelope (R8)

| Constant | Value | Kind |
|---|---|---|
| Segment footprint | **18 × 36 GU** (Q2, 2026-10-08; measured as HEAVY) | guide; PB-7 gates segment maps |
| Buffer ring | 5 GU (`board.buffer`) | derived from the map |
| Playable storeys | 1 | design (upper storeys compose height only) |
| Compose storeys | **≤ 3 above the playable one** | **warning** |
| Expansion reserve | **24 × 48 GU** (the footprint + one third per axis) | **warning**: past it the map is outside what PB-3 measured; re-run `pb3_study.py --only HEAVY` |
| Content counts | the HEAVY row | gate (PB-7) |

**One authority (CR-1):** these numbers and the three `segment_spec` rows move into ONE data file,
**`maps/_spec/segment_envelope.json`** (`{"v": 1, "footprint", "buffer", "reserve", "playable_storeys", "compose_storeys",
"specs": {"LOW", "TYPICAL", "HEAVY"}}`), read by `gen_segment_map.py` (today's `SPECS`), `segment_budget.py`, and the runtime's
`MapEnvelope` through `JsonFile` (a bad row is loud, AUDIT 2026-10-07). `PERFORMANCE_BUDGET` §5 keeps its table as the ratified
record with a pointer to the file. Values unchanged. A map may override `reserve` / `compose_storeys` in its own
`layout.envelope` (a special map, GLASS's three storeys).

---

## 4. The anchors: section `layout` (R1, R3)

### 4.1 Common shape

Every element: `id` (`[a-z0-9_]+`, unique across the whole `layout` AND `capture`, stable: the editor's handle and the
`@id` of a take), `tags` (array of short strings, optional), `note` (dev-only English free text, optional, never shown to a
player). Geometry is a `point` (`at`) or a `box` (`box`); any reference ends as an AABB in world space.

**Reserved names** (an `id` may not take them; `layout_lint` fails it): `map` (the inner rectangle, ground to the tallest
storey), `map_ring` (the same with the buffer ring), `agent_start`, `agent` (LIVE: the agent where it is now), `guard_<i>`
(LIVE), `corner_n|e|s|w`, `side_nw|ne|se|sw`.

```json
"layout": {
  "v": 1,
  "envelope":   {"reserve": [24, 48], "compose_storeys": 3},
  "poi":        [{"id": "big_pane", "at": [12.5, 9.0, 1.5], "tags": ["glass", "detail"]},
                 {"id": "throw_front", "at": [12.0, 10.5], "tags": ["event"]}],
  "regions":    [{"id": "glass_wing", "box": {"min": [9, 7, 0], "max": [22, 12, 3]}, "tags": ["glass", "wide"]}],
  "objectives": [{"id": "obj_terminal", "kind": "reach_terminal", "at": [15.5, 4.5], "tags": []}]
}
```

### 4.2 The elements

| Element | Fields | Meaning | Who reads it |
|---|---|---|---|
| **envelope** | `reserve [w, h]`, `compose_storeys` | this map's override of §3.3 | `layout_lint`, the overlay |
| **poi** | `id`, `at`, `tags` | a point that matters. Tags the capture system understands: `detail` (frame it tight), `wide`, `event` (where an event is staged: a throw target, a shooter's cell) | the framer, takes, the overlay, later the editor and gameplay hints |
| **regions** | `id`, `box`, `tags` | a named 3D volume (a wing, a room, the glass hall). The height matters: a 3-storey pane is framed whole | the framer, takes, the overlay; later rooms, triggers |
| **objectives** | `id`, `kind`, `at` or `region` (an id), `tags` | where the segment's objective is. `kind` is one of `DESIGN` §14.2: `reach_terminal`, `neutralise`, `undetected`, `recover_item`, `escort`, `sabotage`, `survive` | **data only** until the mission system exists. No text (rule 6: logic ≠ narrative; a label is a `tr()` key that lives in the mission's text, never here) |
| *exits* | — | **reserved key** (§4.5) | — |

### 4.3 What is DERIVED, not stored (one authority each)

| Anchor | Read from | `MapLayout` call |
|---|---|---|
| the agent's start | `actors.agent_start` | `agent_start()` |
| bounds, ring, compass | `board.inner_size`, `board.buffer` | `bounds()`, `bounds_ring()`, via `MapCompass` |
| access points | the compiled access cells (`legacy_compiler.access_points`, or `LevelGraph` for `access_from_graph`) | `exits()` → `{cell, side, role: "unknown"}` |
| the 2-GU safe zone (`DESIGN` §14.1) | the entry side, when the level says which one it is | `safe_zone(entry_side)` → a box 2 GU deep along that side |
| LIVE: the agent, a guard | the Room, at the frame it is asked | `resolve("@agent")`, `resolve("@guard_2")` |

### 4.4 Lifecycle

1. **Load:** `MapFileService` deserialises the section through its owner (loud-fail, `{ok, spec, errors}`); `FileMapSource` puts it
   in the runtime spec as `layout` (inner); `MapCompiler` shifts every point and box by the buffer into `compiled["layout"]`.
2. **Build:** `Room.load_map()` builds `room.map_layout: MapLayout` from the compiled layout, the spec's `board` / `actors` and
   the compiled access cells — **replaced on every load, F2 reload included** (memory: `load_map` once left the renderer's decal
   records behind; a selftest pins that a reload swaps the instance).
3. **Rotation:** nothing happens. Anchors are base coordinates.
4. **Checkpoint save / restore:** nothing is saved: the layout is static map data. The progress of an objective, when the mission
   system exists, is state keyed by the objective's `id` — that is why ids are stable.
5. **Edit (the future editor):** `MapLayout` has a small mutation API (`add_poi`, `move`, `remove`, `rename` — rename rewrites every
   `@id` in `capture`) and `to_section() -> Dictionary` (inner). The editor writes through the section owner, never by patching
   JSON. A selftest pins `from_section(to_section(x)) == x` and `map_lint`'s golden round-trip covers the file.
6. **Code-generated maps** (`PLAYGROUND`'s generator fallback, `PROCEDURAL`): no `layout` = the default value (empty lists); the
   derived anchors (bounds, compass, agent start, exits) still exist, so `@map` and `@agent_start` frame ANY map.

### 4.5 Access points: the plumbing only (R10)

- `MapLayout.exits()` reads the compiled access cells and derives each one's `side` with `MapCompass`; `role` is `"unknown"` (the
  legacy field has no main / secondary / secret).
- The `layout` owner **reserves** the key `exits`: a file that writes it fails loudly (`"layout.exits is reserved until the access
  points move here (CAPTURE_RAILS CR-7, MAP_MASTER_PLAN)"`). Nobody can start a second authority by accident.
- `MAP_MASTER_PLAN` carries the warning (top note, 2026-10-10): when the maps milestone touches access points, they move to
  `layout.exits` (`{id, side, cells, role}`, `DESIGN` §14.1), `legacy_compiler.access_points` is migrated by a section migration
  and REMOVED, and `MapCompiler` / `LevelGraph` read `MapLayout`.

### 4.6 Validation: `layout_lint` (in `verify.py quick`, with its own self-test)

| Check | Severity |
|---|---|
| `id` syntax, uniqueness across `layout` + `capture`, not a reserved name | error |
| a coordinate off the 1/8 lattice; a box with `min >= max` on any axis | error |
| a point or box outside `map_ring` (x, y), or below the ground (`z < 0`) | error |
| an objective `kind` outside §4.2; an objective `region` that names no region | error |
| the key `exits` present | error (reserved, §4.5) |
| anything above `1 + compose_storeys` storeys; a map larger than `reserve` | warning |
| a non-segment map larger than the footprint | info line |

---

## 5. Capture profiles (R4-R7)

### 5.1 The table

One data file, **`capture/profiles.json`**, read by the game (the scenario op `profile`) and by `capture.py` (the window size and
the FPS must be on the command line before the boot).

| Profile | Machine | Window | Canvas (`content_scale_size`) | HUD | Dev panels | FPS | Turn default |
|---|---|---|---|---|---|---|---|
| **`engine`** (default) | desktop | **1920 × 1080** | 1280 × 720 (`framing desktop`) | **hidden** | off | fixed 60 (Movie Maker) | orbit (R9, dev) |
| **`ui`** | desktop | **two runs**: 390 × 844 ×2 = 780 × 1688 portrait, and 1920 × 1080 landscape | portrait 390 × 844 / landscape 1280 × 720 | **shown** | off | fixed 60 | cut |
| **`perf`** | handset | the screen | portrait 390 × 844, as shipped | as the player sees it | off | real time | cut |

- **`ui` renders BOTH shapes by default (R7):** every interface capture produces a portrait and a landscape version of the same
  take — the check that the ONE neutral 3 × 3 mechanism holds in both shapes. `--shape portrait|landscape` restricts it.
  A later, cheap gate (interface work, not this plan): every HUD panel's rect lies inside its region in both canvases and no two
  panels overlap. `still … --hud-grid` (CR-2) draws the 3 × 3 region lines over a `ui` capture, so a capture shows which region a
  panel sits in.
- **`perf` is the handset path** that exists today (`device_record.py`); CR-5 gives it `--take` (§9).

### 5.2 Window, canvas and the real frame size

The canvas decides the layout of the HUD and the 2D overlays; the window decides the pixels. Godot renders the 3D at the window
resolution, so the `engine` profile gets 1920 × 1080 pixels of board with the dev canvas's 1280 × 720 layout. **To measure in
CR-2:** a 1920 × 1080 window on a Mac whose screen is smaller is clamped by macOS; Movie Maker writes the viewport it gets. `capture.py`
checks the first frame's size and fails loudly if it is not the profile's (never silently a smaller video).

### 5.3 The HUD through the facade (rule 11 / L3)

`HudController.set_capture_hidden(hidden: bool)`: hides the HUD's `CanvasLayer` and restores it, remembering the state it found.
The scenario op `hud on|off` and the profiles call it. `hud_seam_selftest` gains a check against the real scene. Nothing outside
`hud_controller.gd` names a HUD node. Dev panels already stay off unless `DEV_PANELS=1`.

### 5.4 The camera in capture mode

While a capture drives the camera, **gameplay may not move it**: `CameraController`'s input, its leash and its zoom clamp
(`ZOOM_MIN` 0.20 .. `ZOOM_MAX` 1.20) are bypassed, and calls that move the camera for play (`focus_on`, the enemy-phase camera of
M2.10, `detonate`'s "camera on the grenade") are suppressed and logged once (`[CAPTURE] camera move from <caller> suppressed`).
**The screen shake stays** (it is part of the effect being judged; `shake off` removes it for a measurement of geometry).

---

## 6. Framing (computed, never typed)

### 6.1 The camera as it is (read from the code)

`Board3DLive._process()` takes the `Camera2D`'s screen centre, maps it through the ground map to a GU `g`, and puts the
orthographic `Camera3D` at the ground point `(g.x + 0.5, 0, g.y + 0.5)` (the 2D centre of a cell is its middle) moved back along
its basis; `size = canvas_height / zoom / px_per_unit` (`KEEP_HEIGHT`; `px_per_unit` ≈ 181); rotation `(-30°, 45° + view yaw, 0)`.

### 6.2 Why "frame it" is impossible today

1. **A whole segment does not fit at the gameplay zoom floor.** An 18 × 36 GU ground rectangle at yaw 45° projects to ~38.2 world
   units wide and ~19.1 tall before any wall; the 1280 × 720 canvas at zoom 0.20 shows ~19.9 × 35.4. The width does not fit, and
   a wall on top makes it worse: a `wide` segment needs ~0.15-0.17. The clamp is right for the player and wrong for a capture.
2. **The scenario's `centre` takes a whole GU**, and a box's visual centre is never on the ground grid.

### 6.3 `CaptureFramer` (pure, static, no nodes)

Input: the yaw, the canvas size, the targets (AABBs), the mode, a margin. Output: `{ground_centre: Vector2 (raw GU), zoom: float,
fits: bool, margin_px: float}`.

1. The camera's right `r` and up `u` vectors for pitch −30° and yaw `45° + view` (the same numbers `_make_camera()` uses — read from
   `Board3DLive`, never retyped).
2. Project the 8 corners of every target: `a = P·r`, `b = P·u` (orthographic: the depth is irrelevant).
3. Extents `w = Δa`, `h = Δb`; required camera size `S = max(h, w / aspect) × (1 + 2 × margin)`.
4. The screen centre `(ā, b̄)` is the middle of the extents. The ground point `T = (tx, 0, tz)` with `T·r = ā` and `T·u = b̄` is a
   2 × 2 linear solve, always solvable because the pitch is not zero.
5. `zoom = canvas_height / (S × px_per_unit)`, clamped to the **capture range 0.08 .. 2.0** (`fits = false` if the clamp bit);
   the Camera2D's GU centre is `(tx − 0.5, tz − 0.5)`.

| Mode | Targets | Margin | Floor |
|---|---|---|---|
| `wide` | the target; `@map` = the map + ring to the tallest storey | 10 % | — |
| `detail` | the target | 5 % | a point POI grows to a 3 × 3 × 1 GU box around it, so it still frames a scene |
| `fit` | several targets together (`fit @a @b`) | 8 % | — |
| `explicit` | a raw centre + zoom | — | logged as explicit (the escape hatch) |

**`frame_check <name>`** projects the target's corners through the REAL `Camera3D` (`unproject_position`) after the frame is drawn
and prints `[FRAME-CHECK] <name> target=<id> yaw=<v> inside=yes|no margin=<px>` — the framer checked against the camera, not against
itself. The `CaptureFramer` selftest covers four yaws × (a box, a point, `@map` of an 18 × 36 and of a 44 × 22) and asserts every
corner lands inside the canvas with the requested margin.

---

## 7. Rails and takes: section `capture` (R3, R9)

### 7.1 Shape

```json
"capture": {
  "v": 1,
  "rails": [
    {"id": "glass_overview_then_pane", "keys": [
      {"frame": "wide",   "target": "@glass_wing", "view": "N", "hold": 30},
      {"frame": "detail", "target": "@big_pane",   "view": "N", "move": 45, "hold": 150, "ease": "in_out"},
      {"frame": "wide",   "target": "@glass_wing", "view": "E", "move": 60, "hold": 90,  "turn": "orbit"}
    ]}
  ],
  "takes": [
    {"id": "glass_blast", "profile": "engine", "rail": "glass_overview_then_pane",
     "steps": ["throw 0 @throw_front"], "at_key": 1, "after_hold": 0, "length": 900, "seed": 1}
  ]
}
```

### 7.2 A rail key

| Field | Meaning | Default |
|---|---|---|
| `frame` | `wide` / `detail` / `fit` / `explicit` | `wide` |
| `target` | `@id`, a reserved name, or several for `fit`; `explicit` takes `centre` + `zoom` | `@map` |
| `view` | `N` / `E` / `S` / `W` (base names) | the current view |
| `move` | frames from the previous key's pose to this one | 0 (a cut) |
| `hold` | frames the pose is held | 0 |
| `ease` | `linear` / `in_out` / `out` | `in_out` |
| `turn` | `cut` / `orbit`, when `view` differs from the previous key | the profile's turn default (R9) |
| `follow` | re-resolve the target every frame (a LIVE target: `@agent`, `@guard_2`) | false: resolved once, at the key's start |

### 7.3 How a rail plays (`CaptureRail`)

1. At the start of each key, resolve the target(s) and run the framer for the key's view: a POSE `{centre, zoom, view}`.
2. During `move`, interpolate **per drawn frame**: the centre linearly in GU, the zoom **in log space** (a zoom from 0.15 to 1.2
   feels even only in log), both through the ease curve. With `follow`, the end pose is recomputed every frame.
3. During `hold`, the pose stays (or tracks, with `follow`).
4. Each key prints `[RAIL] <rail> key <i> frame <n> pose centre=<..> zoom=<..> view=<..>`, so a video's frame number always maps to
   a key.

### 7.4 Turning: cut and orbit (R9)

- **`cut`** (the canonical default): at the key's first frame the view snaps through `Room._set_perspective()`, exactly as the
  game's own rotation (camera-only, ~10 ms on the Moto). Exact: every frame shows a view the player can have.
- **`orbit`** (the development default for now): the camera yaw turns continuously over `move` frames through a capture-only
  override, `Board3DLive.set_capture_yaw(deg)` (camera rotation only; the glass's per-view pixel axes follow the yaw, they are a
  formula). **The board's LOGICAL view** — the face shading slots (`face_x_slot` / `face_z_slot`), the occlusion cutaway, the
  actors' light basis (`Room.view_yaw_deg()`) — **switches once, when the yaw crosses the half-way of each quarter turn** (45°;
  a half turn crosses twice). The geometry has every face meshed for every view (R3D-ROT), so nothing is missing mid-turn.
  **The orbit's honest look:** one visible snap per quarter turn in the face tones, the cutaway and the actors' light, at the
  half-way frame; the log prints `[RAIL] orbit view switch at frame <n>`. That is the price of showing a camera the player never
  has, and the reason `cut` stays the canonical default. Flipping the default back is one value in `capture/profiles.json`.

### 7.5 Takes

A take is what is asked for by name ("grava o `glass_blast`"): a profile, a rail, the event steps, when they fire and how long the
take runs.

- **`steps`** are ordinary scenario steps; any GU argument may be an anchor: `throw 0 @throw_front`, `place_guard 0 @poi_x`,
  `aim @big_pane`. The substitution resolves `@id` to the anchor's ground cell (a point's GU; a box's centre). **The event and the
  camera read the SAME anchor, so they cannot point at different places** — the fix for both of the 2026-10-10 mistakes.
- **`at_key` / `after_hold`**: the steps fire when key `at_key` starts holding, plus `after_hold` frames.
- **`length`** in frames; **`seed`** goes to `INFILTRAITOR_RNG_SEED` (the effects use `randf_range()`).
- **Default takes, for ANY map, with no authored data:** `overview` (`wide @map`, one key per view N/E/S/W with the profile's turn),
  `region:<id>` (`wide` on a region, then `detail` on every `detail`-tagged POI inside it) and `poi:<id>` (`detail`). A map
  without a `capture` section still has framed captures.

### 7.6 Validation (`layout_lint` covers `capture` too)

Every `@id` resolves; `view` is N/E/S/W; durations are non-negative integers; `at_key` exists; the rail exists; the profile exists;
each step parses with `ScenarioRunner`'s own parser (one parser, never a copy in Python — `capture.py` asks Godot headless to
`--check-take`).

---

## 8. Producing the capture

### 8.1 Scenario ops (new)

| Op | What |
|---|---|
| `profile <name> [portrait|landscape]` | applies a profile (canvas, HUD, dev panels, turn default), enters capture mode (§5.4) |
| `hud on|off` | through the facade |
| `frame <mode> <targets…> [view]` | one framed pose, no motion |
| `frame_check <name>` | §6.3 |
| `still <name> <mode> <targets…> [view|all]` | frame + capture; `all` = the four views, four files |
| `rail <id>` | plays a rail; returns when it ends |
| `take <id>` | the whole take: profile, seed, rail, steps at their frame, `length`, quit |
| `shake on|off` | §5.4 |

### 8.2 Frame by frame (R2): Movie Maker

`capture.py` boots the desktop Godot with **`--write-movie <tmp> --fixed-fps 60 --resolution <profile window>`** and
`INFILTRAITOR_MAP`, `INFILTRAITOR_RNG_SEED` and `INFILTRAITOR_SCENARIO="take <id>"` (memory: a capture without the map opens the
LAST map used). Movie Maker renders every frame with a fixed delta and writes it whatever the real frame time, so the particles,
smoke and soot fades age exactly as in play. Output: MJPEG `.avi` or a PNG sequence (measured in CR-3: disk and time per second of
video) → `ffmpeg` → **`videos/<map>_<take>.mp4`** (git-ignored); `--sheet <every N frames | 1s>` builds a contact sheet from the
SAME frames into `Screenshots/takes/` (git-ignored). The filmstrip becomes a by-product of a take. The result is rendered in the
conversation (CLAUDE.md).

```
python3 tools/persistent/capture.py --map GLASS --take glass_blast
python3 tools/persistent/capture.py --map GLASS --take glass_blast --sheet 1s
python3 tools/persistent/capture.py --map GLASS --take overview
python3 tools/persistent/capture.py --map GLASS --still big_pane --view all
python3 tools/persistent/capture.py --map GLASS --take hud_check --profile ui           # portrait AND landscape
```

**Determinism is earned before it is trusted** (CLAUDE.md, pixel gates): CR-3 runs the same take twice and compares the frames;
a difference is a finding about the harness (an unseeded RNG, a wall-clock read), never noise to ignore.

### 8.3 Real time (R2, later: CR-6)

A fixed-delta video cannot show a stall. Two instruments:
- **the handset** (`device_record.py`, built; profile `perf`, gaining `--take` in CR-5);
- **the desktop at real speed**: the same take without Movie Maker, the window recorded with `ffmpeg -f avfoundation` (needs macOS
  Screen Recording permission for the terminal: the Director's action, once), plus a **frame stamp** in a corner (frame index,
  frame ms, the slowest `FrameSplit` stage) and a per-frame CSV beside the video, so a hitch is visible AND attributable. The stamp
  is a dev overlay, off unless the take asks for it.

---

## 9. The layout overlay (for the eye, and the editor's first piece)

`view_mode layout` (the existing dev-overlay toggle path; English labels): world-space, depth-tested like every new VFX (RENDER3D
rule), off = zero cost. It draws the map bounds, the buffer ring, the envelope reserve (dashed), the compass letters on the
corners and the side names, the agent's start, the exits with their derived side, every POI (a pin + its id) and region (a wire box
+ its id), and a chosen rail's path (each key's ground centre and its framed rectangle). It is how the Director checks that
`big_pane` is where its name says, and it is the editor's viewport layer.

## 9b. The interface layer on the board (R11) — what this plan provides, not its design

The board's own interface (markers over guards, objective and exit markers, a skill's target area, contextual menus on a cell) is
placed in GU and drawn in world space. Its design belongs to `INTERFACE_MASTER_PLAN`; this plan only guarantees the ground it stands
on:
- **one conversion** (`MapLayout.to_world`, §3.1) and the anchors themselves: an objective marker reads `layout.objectives`, an exit
  marker `MapLayout.exits()` — no second list of where things are;
- **base coordinates**: a board marker never moves with a rotation (camera-only);
- **the cost rule of §2**: every board-interface element is a world-space overlay and is measured on the Moto uncapped before it is
  kept (the GPU headroom is ~9 ms);
- in captures, the board layer belongs to the HUD switch: hidden by the `engine` profile with the screen HUD, shown by `ui`
  (`set_capture_hidden()` covers both, through the facade).

---

## 10. The stages

Each stage closes with `verify.py` at its tier, a commit on `main`, and pasted evidence (CLAUDE.md).

| Stage | What | Closes when |
|---|---|---|
| **CR-0** ✅ | this plan, the rulings (§1) | ruled 2026-10-10 |
| **CR-1 — the anchors** ✅ BUILT 2026-10-10 (as-built: `maps/_spec/segment_envelope.json` read by `gen_segment_map.py` → `segment_budget.py` (same verdicts) and `MapEnvelope`; `MapCompass`, `MapEnvelope`, `MapLayout` in `godot/scripts/world/maps/`; the `layout` owner round-trips the dict as authored and **`MapFileService._validate()` runs `MapLayout.validate_section()`** (an error fails the load, the envelope prints warnings); `MapCompiler._compile_layout()` applies the buffer, `MapCompiler.raw_to_inner()` / `tallest_storeys_of()` live there; **consumers PRELOAD the new scripts and build with `MapLayoutClass.new().load_compiled(compiled)`** — a new `class_name` is invisible to headless runs until the editor rebuilds its cache; `MapLayout.vertical_scale` is fed by `Room` from `Board3DLive.VERTICAL_SCALE` (headless tools cannot parse the board's script); `room.map_layout` + `Room.guard_cell()` for `@guard_<i>`; **`layout_lint` is `map_layout_selftest`** (in `verify.py quick` through the selftests: 13 RED shapes, every shipped map loads, GLASS compiled and resolved, the editor API, `to_section()` == the file); GLASS 7 POIs / 3 regions, PLAYGROUND 5 / 3, generated segments one region + one POI per room. `MapCompass.views_facing()` moves to CR-2, where the yaw is. Real boot: `[MAP-LAYOUT] GLASS: 7 poi, 3 region(s) … 3.00 storeys`, a different instance after `reload`.) | `maps/_spec/segment_envelope.json` + its three readers (§3.3); `MapCompass`, `MapEnvelope`; the `layout` owner v1 (envelope, poi, regions, objectives; `exits` reserved); `MapCompiler` shift; `MapLayout` (read API, `resolve()` incl. reserved and LIVE names, `to_world*`, mutation API, `to_section`); `room.map_layout` replaced per load; `layout_lint` in `verify.py quick`; data for **GLASS** and **PLAYGROUND**; `gen_segment_map.py` writes a `layout`; the `MAP_MASTER_PLAN` warning (R10) | `map_lint` golden round-trip green with the section; `layout_lint` self-test red-then-green; `MapLayout` selftest (round-trip, reload swaps the instance, `resolve` of every reserved name); `segment_budget.py` reads the JSON with the same verdicts |
| **CR-2 — framing and profiles** ✅ BUILT (`capture/profiles.json`, `CaptureProfiles`, `CaptureFramer` + `capture_framer_selftest` (20 cases, four views; a segment needs zoom 0.154), `CaptureController` (`Room.capture()`), `Room.set_capture_view()`, `CameraController.capture_locked` refusing focus_on / the enemy-phase tween / re-centres / input (logged once each), `HudController.set_capture_hidden()` + `hud_seam_selftest`; ops `profile`, `hud`, `shake`, `frame`, `frame_check`, `still`; GLASS real boot: `frame_check` inside=yes for @map + 3 regions × 4 views; `--hud-grid` in `capture.py`; `MapCompass.views_facing()` NOT built — the framer needed only the yaw) | `capture/profiles.json`; `CaptureFramer` + selftest; capture mode on the camera (§5.4); `HudController.set_capture_hidden()`; ops `profile`, `hud`, `frame`, `frame_check`, `still`, `shake`; `capture.py --still` (and `--hud-grid`, the 3 × 3 region lines over a `ui` capture, R11); the 1920 × 1080 window check (§5.2) | `frame_check` reads `inside=yes` for every GLASS and PLAYGROUND region in all four views (real boot); stills of `@map` wide and `@big_pane` detail with the HUD hidden, shown to the Director |
| **CR-3 — rails, takes, video** ✅ BUILT (`capture` owner + `MapLayout.validate_capture()` (9 RED shapes); `CaptureController.play_rail()` (log-space zoom, ease, cut / orbit with the logical view switching at each half quarter-turn, `follow`); `Board3DLive.capture_yaw`; ops `rail`, `take`; `ScenarioRunner.substitute_anchors()` for `@id` cell arguments — also in any `SCENARIO`; default rails/takes overview / region:<id> / poi:<id>; `capture.py`; GLASS `glass_blast`; determinism 904/904) | the `capture` owner v1; `CaptureRail` (cut and orbit, `follow`); `@id` substitution in steps; ops `rail`, `take`; default takes (§7.5); `capture.py --take` with Movie Maker, `--sheet`; the `glass_blast` take | the `glass_blast` video shown; two runs of the same take compared frame by frame (equal, or the difference explained) |
| **CR-4 — the layout overlay** ✅ BUILT (`LayoutOverlay3D`, `view_mode layout`, `LAYOUT_RAIL=<id>`; capture `Screenshots/takes/GLASS_layout_overlay.png`, local) | §9 | a GLASS still with the overlay, shown |
| **CR-5 — the tools onto takes** ✅ BUILT, retirement PENDING the Director (`device_record.py --take` + `CAPTURE_PROFILE=perf`; `build_filmstrip.py --take <id> [--every N]` delegates to `capture.py` (a sheet of every frame); CLAUDE.md's capture rules. **Inventory for the retirement (nothing deleted):** `room.gd` reads 22 `INFILTRAITOR_CAPTURE_*` vars (65 references) and dispatches **26 `CAPTURE_ACTION`s** (`agent_shot`, `busted`, `detonation_filmstrip`, `end_turn`, `escape_open_menu`, `glass_blast_demo`, `glass_crack_demo`, `glass_rain_demo`, `glass_rain_timings`, `glass_reap_demo`, `grenade_cancel`, `grenade_second`, `grenade_tap`, `grenade_then_shot`, `grenade_throw`, `light_burn_probe`, `open_showcase`, `shot_filmstrip`, `test_collectible`, `test_zone_detonate`, `test_zone_escape`, `test_zone_menu`, `test_zone_view`, `throw_event`, `throw_filmstrip`, `walk_filmstrip`), plus `benchmark`; readers: `build_filmstrip.py` (4), `build_material_matrix.py` (3), `tools/asset_generation/p3_step_bracket.py` (3), `camera_controller.gd` (`CAPTURE_ZOOM`), `blast_calculator_selftest.gd` (1). Many actions are DEMOS that stage gameplay (menus, a cancelled grenade, the showcase), not framing: a take can replace their camera, not their staging. Proposal: retire action by action as each gets a take + a scenario equivalent, never as one sweep. **Evaluated and done 2026-10-10 (Director: "avalie se vale a pena apagar"):** DELETED the 8 demos with no caller, whose job a take / scenario now does — `glass_crack_demo`, `glass_blast_demo`, `glass_rain_demo`, `glass_reap_demo`, `light_burn_probe`, `grenade_then_shot`, `throw_filmstrip`, `throw_event` — with the 9 helpers and 3 constants only they used: **room.gd −1 588 lines** (last tree with them: `9d577d29`). KEPT: the 7 tool-backed actions (`detonation_filmstrip`, `shot_filmstrip`, `glass_rain_timings`, `test_zone_*`, `agent_shot`, `walk_filmstrip`, `benchmark`), the four-view hook path, and the small UI-state actions (`busted`, `end_turn`, `escape_open_menu`, `grenade_*`, `open_showcase`, `test_collectible`): they stage interface states no scenario op reaches yet — retire them when the interface work gives them scenario ops) | `build_filmstrip.py` → a take + `--sheet` of every frame; `device_record.py --take` (profile `perf`, portrait framing by the same framer); CLAUDE.md's capture section rewritten around profiles and takes. **Then** the 22 `INFILTRAITOR_CAPTURE_*` env vars and `room.gd`'s capture actions are listed with every reader and every side effect (memory: deleted function side effects) and retired **only with the Director's OK** | the old tools' evidence reproduced through takes |
| **CR-6 — real time** ✅ BUILT, differently from the plan: `capture.py --take <id> --realtime`. The macOS screen recording cannot see an off-screen window, so the take is run a SECOND time at real speed, uncapped (`MAX_FPS=0`), with `CAPTURE_TIMING=1`: every take frame's duration goes to `captures/<take>_timing.csv` (`ScenarioRunner._time_take`); a take is counted in frames, so frame N of that run is frame N of the Movie Maker run, and `<map>_<take>_realtime.mp4` shows each Movie Maker frame for its measured time with the ms stamped (red over 33.3 ms): a stall is a freeze you can see and a number you can read. No screen-recording permission needed. Desktop timing, not the handset's (that stays `device_record.py --take`) | §8.3 | one take recorded both ways; a stall visible only in the real-time one |
| **CR-7 — access points native** (parked, R10) | §4.5's move, inside the maps milestone | one authority; `map_lint` + selftests green |

**Order:** CR-1 → CR-2 → CR-3 are one line (each needs the one before). CR-4 can follow CR-1 at any time. CR-5 and CR-6 after CR-3.
CR-1 + CR-2 already fix both of the 2026-10-10 mistakes; CR-3 is the rails and the video.

---

## 11. What this leaves ready for the scenario editor (to be planned)

Not designed here. Ready for it after CR-1..CR-4: every anchor has a stable `id`; every section has an owner with `serialize` /
`deserialize`; `MapLayout` has the mutation API and `to_section()`; the rename rewrites the `@id`s; `to_world` and
`MapCompiler.raw_to_inner()` are the only conversions; `pick_ground()` already turns a screen point into a ground point; the layout
overlay is the editor's viewport layer. The editor's own plan decides placement UI, undo, and how it writes `actors` / `walls` /
`props`.

---

## 12. Open questions

None blocking CR-1. The HUD's 3 × 3 design (which panel in which region, per shape, handedness) is `INTERFACE_MASTER_PLAN`'s, to be
designed with the Director when the interface work starts.
