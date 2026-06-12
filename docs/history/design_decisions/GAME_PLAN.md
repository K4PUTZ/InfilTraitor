# INFILTRAITOR — Game Plan

> **Project:** INFILTRAITOR  
> **Genre:** Top-down stealth / tactical RPG  
> **Platform:** Mobile (iOS & Android, HTML5)  
> **Created:** 2026-02-20  
> **Last updated:** 2026-05-30 (Tile-wall autotile system locked; Phase 1 border + end-cap fixes; floor apron; Phase 2 environment/biome hierarchy designed)
> **Status:** M1.5 in progress — segment prototype (18×36) complete; tile-wall autotile system live; three-layer FOW live; core movement loop approved as Alpha Gameplay feel
> **Engine:** Godot 4.6 (GDScript), isometric 2.5D  
> **Orientation:** Portrait

**Repository (source of truth):**
- GitHub: https://github.com/K4PUTZ/InfilTraitor.git
- Default branch: `main`
- Clone: `git clone https://github.com/K4PUTZ/InfilTraitor.git`
- Suggested workflow: `git checkout -b feature/<short-name>` → commit → push → PR

---

## 1. High-Level Concept

**INFILTRAITOR** is a mobile **turn-based** stealth tactics game with RPG progression, inspired by the tactical readability of *XCOM* and the clean top-down room navigation of classic **Zelda-style** dungeon design. The player controls a secret agent viewed from a **top-down/isometric perspective** on a **square tile grid** in **portrait orientation**. Godot 4 renders all scenarios with isometric 2.5D tiles. The camera is zoomed in to show a portion of the dungeon; the map **scrolls to follow the agent** as they move from room to room.

The defining mechanic: **information is the primary resource**, not health or ammunition. The agent is a spy — success depends on *knowing* without being known. Fog of war, noise propagation, and enemy unpredictability make every run fresh and every action consequential.

Each run begins at an **entrance room** and progresses through a chain of connected rooms generated from handcrafted templates. Rooms contain **objectives / quests**, enemies, hazards, rewards, and finally a path to the **exit / next level**. The game blends **tactical puzzle-solving** (choosing a path through threats), **room-based dungeon progression** (clear, survive, extract, unlock), and **character growth** (new skills, gadgets, weapons, and equipment unlocked over time). Each turn the agent has **two action points (AP)** that can be spent on movement, gadget use, skills, combat actions, or interactions — forcing meaningful choices every turn.

---

## 2. Core Pillars

| Pillar | Description |
|---|---|
| **Stealth-first gameplay** | Detection = failure (or heavy penalty). Patience and planning are rewarded. |
| **Grid-based clarity** | Every element occupies discrete tiles, making threats readable on a small screen. |
| **Room-based dungeon flow** | Every floor has a readable entrance, room objectives, rewards, and a clear route to the next level. |
| **Procedural replayability** | Dungeon layouts are generated from authored building blocks so each run feels fresh but fair. |
| **Progressive mastery** | New abilities open up previously impossible routes and strategies. |
| **Session-friendly** | Levels are short enough (1–3 min) for mobile play sessions. |
| **Information asymmetry** | Fog of war, noise propagation, and limited vision make knowledge the scarcest resource. The player must gather intel before acting — and act before being known. |
| **Fair monetisation** | Ads + optional cosmetics; never pay-to-win. |

---

## 3. Gameplay

### 3.1 Turn System (XCOM-style)
- The game is **strictly turn-based**. Each turn the agent receives **2 Action Points (AP)**.
- An AP can be spent on:
  - **Move** — traverse up to N tiles (N determined by stats / skills). Moving costs 1 AP.
  - **Use gadget / skill** — activate an item or ability. Costs 1 AP (some powerful abilities cost 2 AP).
  - **Attack / brute force** — fire a weapon, perform a melee strike, or break an obstacle. Costs 1 AP unless otherwise specified.
  - **Interact** — open a door, pick up intel, hack a terminal. Costs 1 AP.
  - **Wait / Overwatch** — end turn early; agent enters a reactive stance (see §3.1.1).
  - **Set trap** — place a device on a tile that triggers during the enemy phase (1 AP).
- After the agent spends both AP (or manually ends the turn), **all enemies execute their turn simultaneously** (patrols advance, cameras rotate, lasers cycle).
- This loop creates a chess-like rhythm: *observe → plan → act → observe consequences*.

#### 3.1.1 Overwatch, Traps & Enemy-Phase Reactions
- **Overwatch:** If the agent ends the turn with unspent AP via the *Wait* action, they enter **Overwatch**. During the enemy phase, if a threat enters the agent's vision within a set radius, the agent may automatically perform a pre-selected reaction (e.g., duck behind cover, use a gadget).
- **Traps:** The agent can spend 1 AP to **place a trap** on an adjacent tile (smoke mine, noise maker, EMP mine). The trap activates when an enemy steps on or passes through the tile during their phase.
- **Detection reaction window:** When the agent is **detected** during the enemy phase, the game **briefly pauses** and presents a small emergency menu. The player can:
  - Spend a **gadget charge** (smoke bomb, EMP) to break line of sight immediately.
  - Use a **special skill** (e.g., Invisibility, if unlocked) to avoid full alert.
  - Do nothing and accept the alert-meter increase.
- Outside of detection events and overwatch, the player **cannot act** during the enemy phase — maintaining the clean turn structure.

### 3.2 Controls & Interaction
- **Tap a tile** to select it. A small **context menu** appears showing valid actions for that tile:
  - *Empty tile in range* → **Move here** (shows AP cost & path preview).
  - *Tile with object* → **Interact** (hack, pick lock, collect item, etc.).
  - *Tile with enemy* → **Use skill/gadget** (if applicable — e.g., Silent Takedown from adjacent tile).
  - *Agent's own tile* → **Gadget wheel** / **End turn** / **Wait**.
- The context menu keeps the UI clean: no permanent buttons cluttering the screen; actions are always contextual and discoverable.
- Movement is **four-directional** on the grid (up, down, left, right). Diagonal movement may be unlocked as a late-game skill.
- A **path preview** (highlighted tiles) is drawn from the agent to the tapped tile, showing the route and AP cost before confirmation.

#### 3.2.1 Movement Range & Tactical Readability
- The currently reachable area must be shown with **two movement bands** inspired by *XCOM* readability:
  - **1 AP zone** — tiles reachable with a single move action.
  - **2 AP zone** — tiles reachable only if the player spends the full turn on movement.
- These zones must use **different colours** and remain legible on a small mobile screen.
- After tapping a tile, the game shows:
  - the **pathfinder result**,
  - the **AP cost**,
  - any **known risks** on the path (enemy vision, trap tiles, alarms) when available.
- The UI goal is immediate tactical clarity: the player should understand **where they can go this turn**, **what it costs**, and **what they are risking** before confirming.

### 3.3 Tile Terrain & Movement Modifiers
Tiles are not all equal — terrain type affects movement cost, stealth, and can impose directional effects.

| Terrain | Effect |
|---|---|
| **Standard floor** | Normal movement (1 tile per move step). |
| **Rough terrain** (rubble, debris) | Costs extra movement points — fewer tiles covered per AP. |
| **Water current** | Pushes the agent 1 tile in the current direction at end of turn (free). Can be used strategically. |
| **Fan / wind vent** | Blows the agent (or lightweight objects) in a direction each turn. Blocks smoke. |
| **Ice / slippery floor** | Agent slides an extra tile in the movement direction (may overshoot). |
| **Tall grass / shadow** | Reduces enemy vision — agent is harder to detect while on this tile. Shadow tiles are generated by the lighting system (see §3.10) and rendered as permanent TileMap tiles. Detection multiplier: 0.30× (direct shadow), 0.55× (penumbra). |
| **Stairs / ladder** | Transition between elevation layers (future multi-floor levels). |
| **Conveyor belt** | Moves anything on it 1 tile per turn in a fixed direction. |
| **Trap tile** | Player-placed or pre-existing; triggers an effect when stepped on. |

Terrain modifiers are displayed via **subtle tile overlays** (e.g., arrows for currents/wind, wavy lines for water) so the player can plan around them.

### 3.4 Vision & Fog of War

Information asymmetry is the core strategic layer — the player never has complete knowledge, and that tension *is* the game.

**Visibility tiers:**

| Tier | Behaviour |
|---|---|
| **Unexplored** | Never visited. Fully dark overlay. Layout completely unknown. |
| **Explored** | Visited at least once. Layout visible; enemy positions not updated (last-known only). |
| **Currently visible** | Within sight radius of agent. Full live detail. |

**Implemented three-layer visibility system *(locked 2026-05-30):***

The in-game visibility is rendered by three independent, overlapping systems that together produce a smooth, atmospheric fog with no hard edges:

| Layer | Node | Technique |
|---|---|---|
| **1 — Distance fog gradient** | `VisionFogOverlay` (CanvasLayer, always on) | GLSL shader (`vision_fog.gdshader`) draws a radial gradient in screen UV space. Shape is an **isometric 2:1 ellipse** (wider horizontally, matching floor perspective). Fades from transparent at the agent's core to semi-opaque at the FOW boundary and beyond. |
| **2 — Fog of War polygons** | `FogOfWarOverlay` (Node2D, above floor) | Draws isometric diamond polygons over every unrevealed cell. Revealed state is **persistent per segment** (never re-fogged on re-entry). |
| **3 — Camera leash** | `room.gd` | Camera is constrained to stay within the vision radius of the agent using a soft zone (quadratic ease-out) + hard limit. Prevents the player from panning beyond their fog boundary. |

**FOW reveal shape:** Euclidean disc in tile space (radius = `VISION_TILE_RADIUS` tiles). Projects to a 2:1 ellipse on screen matching the isometric floor plane.

**FOW opacity — graduated rings with smoothstep ease-out *(updated 2026-05-30):***
- 12 rings of partial opacity between the reveal boundary and full darkness.
- Formula: `alpha(ring) = FOG_COLOR.a × t²(3 − 2t)` where `t = ring / 12`
- Gives a smooth **ease-in/ease-out S-curve from ≈2% (ring 1) to 100% (ring 12)**.
- **Per-vertex feathering**: each diamond vertex blends its ring alpha with the cardinal neighbour’s alpha. Revealed neighbours pull toward transparent; different-ring neighbours blend smoothly. No stair-step artefacts.

**Distance fog shader parameters (current tuning):**
- `VISION_TILE_RADIUS = 5` tiles — shader clear zone only (independent of FOW)
- `FOW_REVEAL_RADIUS = 9` tiles — Euclidean reveal radius and camera leash hard limit
- Shader inner clear zone: `VISION_TILE_RADIUS − 3` tiles from agent
- Shader outer (full darkness): `VISION_TILE_RADIUS + 9` tiles from agent
- The gradient extends 9 tiles beyond the shader boundary, overlapping the FOW rings.

**FOW wall-sprite alignment fix *(locked 2026-05-30):***
Isometric wall sprites extend ~158 px above their tile-floor footprint in screen space (measured from the tallest assets in the blocks-prototype pack: `wall_*` variants, windows). The standard diamond polygon only covers the floor area and left the wall tops exposed at the fog boundary.

**Solution:** The `FogOfWarOverlay` drawing loops (alpha pre-computation and polygon draw) extend **1 virtual tile** beyond the room boundary in all four directions (`range(-1, room_size+1)`). These outer tiles are never added to `_revealed`, so `_fog_alpha_for` naturally assigns them the smoothstep gradient based on proximity to the nearest revealed inner tile. The result: wall tops are covered by real FOW fog — the same S-curve fade — without any hard-coded border or alpha summation artefact.

**Scene background colour *(locked 2026-05-30):***
The Godot viewport clear colour is set to `Color(0.13, 0.13, 0.20, 1)` — a dark blue-black that matches the deep end of the FOW palette. This ensures the area beyond the virtual outer ring (pure scene background, no tile coverage) blends seamlessly with the fog instead of showing Godot's default mid-grey.

**Enemy visibility rule *(locked 2026-05-30):***

The FOW and the vision gradient serve different purposes for enemy rendering:

| Zone | Terrain visible? | Enemy visible? |
|---|---|---|
| **Clear zone** (within `VISION_TILE_RADIUS`) | Yes — full detail | **Yes — fully visible** |
| **Transition zone** (gradient area, beyond clear zone) | Yes — fading | **Fades out and disappears** |
| **Revealed / explored** (beyond gradient, FOW cleared) | Yes — muted | **No** — last-known position marker only |
| **Unexplored** (FOW fully dark) | No | No |

- Enemies are visible **only within the clear shader circle** (`VISION_TILE_RADIUS`). Their alpha tracks the inverse of the fog gradient — as the fog becomes denser, the enemy sprite becomes transparent and vanishes.
- This means the player always knows the *terrain layout* of revealed cells, but only has *live enemy intelligence* within their active sight radius.
- **Exceptions**: certain gadgets/abilities (periscope, mini-drone, terminal hack) can grant temporary enemy visibility beyond the normal sight radius.

**Enemy positions:**
- Visible only when within sight range.
- Last known position shown as a dimmed icon when an enemy exits sight.
- `?` marker displayed when an enemy was known to be in the area but has since moved.

**Animated decoration rule *(locked 2026-05-30):***

All decorative animated objects (fire, flickering lights, screens, neon signs, smoke, water, animals, fans, etc.) are **frozen outside the clear vision zone** and come alive as the player approaches.

| Zone | Animation state |
|---|---|
| **Clear zone** (within `VISION_TILE_RADIUS`) | **Active** — full animation running |
| **Transition / gradient zone** | **Activating** — begins playing as object enters zone |
| **Revealed but beyond gradient** | **Frozen** — static first frame; no process tick |
| **Unexplored** | **Dormant** — not instantiated or process disabled |

Implementation intent:
- Each animated decoration sets `process_mode = PROCESS_MODE_DISABLED` when outside the clear zone. On crossing the threshold (agent moves and distance ≤ `VISION_TILE_RADIUS`), `process_mode` is restored to `PROCESS_MODE_INHERIT`.
- **Memory management**: decorations beyond `FOW_REVEAL_RADIUS` + a small buffer can be freed from the scene tree and re-instantiated from a template when the player approaches. This keeps the active node count low on mobile.
- The activation sweep runs once per agent move (not every frame) — same event that triggers FOW reveal.
- Frozen decorations display their **rest pose** (frame 0 or a designated idle frame), so they are visually coherent without being animated.

**Noise propagation:**
- Each tile has a `noise_cost` (standard floor = 0, metal grating = 2, gravel = 3, broken glass = 4).
- Each agent move generates noise equal to the destination tile’s `noise_cost`.
- Guards with `hearing_radius > 0` raise alert if noise this turn exceeds their threshold within range.
- This creates a parallel stealth layer: route choice involves both vision cones *and* noise budget.

**Intel gathering:**
- Gadgets (mini-drone, periscope) and terminal hacks permanently reveal tile areas.
- The **Informant NPC** (§3.7.4) provides one guaranteed intel piece per map.
- Fog clears permanently on visit — giving a memory advantage on retry.

### 3.5 Threat Types

| Threat | Behaviour |
|---|---|
| **Guard (patrol)** | Walks a fixed route on the grid. Has a cone of vision. |
| **Guard (stationary)** | Faces one direction; rotates periodically. |
| **Security camera** | Sweeps an arc; triggers alarm if agent is in view. |
| **Laser grid** | Blocks a row/column of tiles; may toggle on/off in a pattern. |
| **Locked door** | Requires a keycard or hacking skill to open. |
| **Pressure plate** | Triggers an alarm or trap when stepped on. |
| **Dog / drone** | Follows scent/heat; harder to evade than human guards. |

### 3.6 Detection & Failure
- Detection raises an **alert meter**.
- Partial detection (peripheral vision) gives a warning; full detection fills the meter.
- When the meter is full → **mission failed** (option to watch an ad to continue — see §6).
- Stealthy play keeps the meter at zero and awards bonus rewards.
- Because the game is turn-based, the player always has a chance to **react** to a warning before full detection — rewarding careful planning over reflexes.
- During the enemy phase, detection triggers the **reaction window** (see §3.1.1) giving the player a brief opportunity to spend gadgets or skills to avoid full alert.

### 3.7 Dungeon Structure, Rooms & Level Flow
- A run starts in an **entrance room**.
- The player progresses room by room through a dungeon floor until they reach an **exit room**, elevator, stairwell, or extraction point.
- Each room should present at least one meaningful element:
  - an enemy encounter,
  - a stealth puzzle,
  - a quest / objective,
  - a reward cache,
  - a traversal constraint,
  - or a narrative event.
- Floors are grouped into **chapters / themes** (e.g., Embassy, Lab, Skyscraper, Bunker).
- Each chapter introduces a new threat type or mechanic.
- Chapters end with a **boss level** or high-security finale (e.g., a chief of security with unique AI).
- Optional **side objectives** per floor: steal intel, avoid all detection, rescue a hostage, recover an item, finish under a time limit.

#### 3.7.1 Room Objectives / Quests
Each room can roll one or more local objectives from a curated set:

| Objective Type | Description |
|---|---|
| **Reach terminal** | Move to a specific tile and hack/download data. |
| **Neutralize guard** | Eliminate or incapacitate one target in the room. |
| **Stay unseen** | Cross the room without filling the alert meter. |
| **Recover item** | Collect a keycard, prototype, weapon crate, or intel package. |
| **Escort / rescue** | Reach a hostage or ally and guide them to the exit. |
| **Sabotage system** | Disable cameras, power nodes, or laser relays. |
| **Survive ambush** | Hold out for a number of enemy turns. |

These room quests provide short-term goals inside the larger dungeon progression loop.

#### 3.7.2 Rewards & Progression Between Rooms
- Clearing or completing room objectives can award:
  - **XP**,
  - **coins / currency**,
  - **gadgets / charges**,
  - **weapons / ammo**,
  - **keys / access cards**,
  - **intel / story unlocks**.
- Rewards should support multiple playstyles: stealth, tech, and brute-force combat.
- The exit to the next floor may be:
  - immediately accessible,
  - locked behind a key objective,
  - or opened only after finishing a required room quest.

#### 3.7.3 Procedural Dungeon Generation
- The long-term target is a **procedural dungeon system** built from handcrafted room templates, connectors, and rule-driven placement.
- Generation must prioritize:
  - **fairness** — at least one viable route from entrance to exit,
  - **readability** — room purpose and navigation remain clear on mobile,
  - **variety** — mixes stealth rooms, combat rooms, utility rooms, and reward rooms,
  - **pacing** — tension ramps up across the floor instead of spiking randomly.
- Procedural generation should be **controlled**, not purely random. Authored constraints are required so the floor still feels designed.

#### Layout Patterns
| Pattern | Description |
|---|---|
| **Multi-path (default)** | 2–3 parallel vertical corridors with different obstacle sets. The player picks a route based on their skills/gadgets. Corridors may have cross-links. |
| **Room chain** | A Zelda-like chain of compact rooms linked by doors, hallways, lifts, or vents. |
| **Single-path gauntlet** | One main corridor with mandatory tasks / puzzles in the middle (hack a terminal, disable a laser grid). |
| **Side-scroll wing** | A horizontal branch off the main path leading to a **secret area**, bonus loot, or shortcut. The camera scrolls sideways. |
| **Reverse (top → bottom)** | Occasional levels where the agent starts at the top and must escape downward (e.g., after triggering an alarm in a story beat). |
| **Multi-floor** | Stairs/ladders connect vertical layers (future feature). |

The camera **scrolls to follow the agent** in any direction, but the natural pull is bottom-to-top in most levels.

#### 3.7.4 The Informant — guaranteed intel NPC

Every map may contain an **Informant**: a friendly Network contact embedded in the location. Reaching the Informant tile (1 AP interaction) before being detected grants one of three guaranteed intel pieces — player’s choice:

- Exact position of the primary objective
- Patrol route of one specific guard (displayed as a dotted path overlay for 5 turns)
- Location of the nearest secret room

The Informant is never on the critical path — reaching them requires a detour, making the choice a meaningful trade-off: time/AP vs. information.

#### 3.7.5 Zones & Thematic Chapters

Zones are high-level thematic chapters, each with a **unique tileset, enemy faction, and ambient aesthetic**. Each zone is a self-contained campaign chapter that connects into the main story arc.

| Zone | Theme | Tileset style | Faction |
|---|---|---|---|
| **1 — Corporate HQ** | Urban office tower | Concrete, glass, carpet | Agency security |
| **2 — Research Facility** | Underground sci-fi lab | White tile, neon accents | Research division |
| **3 — Jungle Outpost** | Remote military camp | Wood, dirt, vegetation | Paramilitary contractors |
| **4 — Arctic Base** | Ice/snow facility | Steel, ice tiles | Black-ops unit |
| **5 — Space Station** | Orbital platform | Hull panels, vacuum vents | Elite agency division |
| **6 — Underground Bunker** | Network HQ + final confrontation | Mixed salvage | Agency command |

Zone unlocks are linear (1 → 6) but each zone can be replayed in higher difficulty tiers (Standard / Shadow / Ghost) for max stars and exclusive cosmetics.

---

#### 3.7.6 Segment System — Map Structure *(locked 2026-05-30)*

All missions use a **segment-based macro structure** instead of an open floor grid.

**Segment dimensions (locked):**
- MAP_SIZE = **18 × 36 tiles** → **2304 × 1152 px** screen space (2:1 cell ratio maintained).
- Interior playable area: **16 × 34 tiles** (1-tile slab border on all sides).
- Odd centre column at col 9 (symmetry for default access points).
- Agent spawn: `Vector2i(9, 34)` — south interior, centred.
- 7 crates distributed in the interior at authored positions.

**Mission map grid:**
- Each mission is a **3 × 3 grid of segments** (27 × 81 tiles total).
- Progress direction varies per mission (south→north, west→east, diagonal, etc.).
- Full adjacency: lateral + vertical neighbours are all accessible.
- **Free backtracking** — the player can revisit any visited segment.
- No prior map visibility — only the agent's visited segments are shown; the rest is fog of war.

**Access points:**
- Any border tile can be an access point (open passage replacing the border slab).
- Per active border: **1 main** (always open) + **1 secondary** (gated / requires condition) + **1 secret** (hidden until discovered).
- Access point positions are defined in `ACCESS_POINTS` const in `room_layout_builder.gd`.

**Teleport mechanic:**
- Stepping on an access point tile teleports the agent to the adjacent segment.
- **Arrival uses mirrored offset**: exit at col 3 of north border → arrive at col 3 of south border of the next segment. X-position is preserved; Y flips to the opposite border.
- **No extra AP cost** — arriving on the border row organically costs 1 movement tile to reach the interior (natural consequence of where the agent lands, not a tax).
- **Safe zone**: the border row + 1 interior tile are guaranteed encounter-free, giving room to retreat or attempt stealth without being immediately threatened.
- **Full AP reset** on segment entry (arrival in a new segment restores AP to maximum).

**Camera & visibility:**
- Camera always stays within the **active segment** only.
- Unvisited segments render as **fog of war**.
- Strategic zoom ~30% — portrait device shows ~28% of segment width at a time.
- The segment is never fully visible on screen — exploration is always required.

**Anti-linear design rule:**
- Every mission must have **≥1 critical blocker** (door, guard, obstacle) whose unlock is in a **non-adjacent segment**, forcing lateral exploration.
- Multiple paths through the 3×3 grid, each favouring a different strategy.

**Events:**
- **On segment entry** — ambient setup, enemy patrol start, narrative beat.
- **On zone/tile** — triggered when agent enters a specific tile or zone.
- **On player interaction** — triggered by explicit agent action (examine, hack, talk).
- All three event types coexist within a single segment.

---

#### 3.7.7 Wall Autotile System *(locked 2026-05-30)*

All wall tiles in a segment are resolved at runtime by `room_layout_builder.gd`'s `_pick_wall_tile()` function. The function inspects the four cardinal neighbours of each wall cell and selects one of the following Kenney blocks-prototype tiles:

| Tile | Usage |
|---|---|
| `wall_NE / wall_NW / wall_SE / wall_SW` | Single open side (straight wall face) and mid-border cells |
| `wallCorner_NE / wallCorner_NW / wallCorner_SE / wallCorner_SW` | Two adjacent open sides (90° corner junction) |
| `block_*` | Zero or two opposing open sides; fully enclosed or tunnel positions |

**Three-rule resolution order (applied in sequence):**

**Rule 1 — Mid-border override.** Non-corner border cells are always assigned their straight face tile before any open-count analysis. This eliminates T-junction notches where interior walls join the segment border, and ensures access-point-adjacent cells display a clean straight face instead of a heavy corner block.

| Border position | Assigned tile |
|---|---|
| West border (x == 0) | `wall_SW` |
| East border (x == MAP_SIZE.x − 1) | `wall_NE` |
| North border (y == 0) | `wall_NW` |
| South border (y == MAP_SIZE.y − 1) | `wall_SE` |

**Rule 2 — Open-count autotile.** Count the number of open (non-wall) cardinal neighbours:

| Open count | Tile selection |
|---|---|
| 0 | `block_*` (fully enclosed) |
| 1 | `wall_<diagonal>` (face toward the open side) |
| 2 — adjacent directions | `wallCorner_<diagonal>` (L-junction) |
| 2 — opposing directions | `block_*` (tunnel — no exposed face) |
| 4 | `block_*` (fully isolated island, should not occur in practice) |

**Rule 3 — End-cap facing (3 open sides).** When only one cardinal side is closed, the tile represents the exposed mouth of a wall segment. A `block_*` here renders as a floating full cube; instead, the tile facing the exposed end is used (one of the diagonal `wall_*` variants).

Example: cell `(6, 17)` (east end-cap of the left interior wall) has W=wall, N/E/S=floor → closed W → the appropriate west-facing `wall_*` tile.

**Floor apron.** The floor placement loop in `room.gd`'s `_build_room()` extends 1 cell beyond the map boundary in all four directions (`range(-1, MAP_SIZE.x + 1)` × `range(-1, MAP_SIZE.y + 1)`). This creates a single-cell ring of floor tiles outside the border wall ring, grounding their outer faces so they never hover over the dark scene background. Apron cells are unreachable by game logic — the border wall ring blocks all movement paths.

---

#### 3.7.8 Environment Themes & Biome Hierarchy *(designed 2026-05-30 — not yet implemented)*

All visual differentiation between dungeon zones is driven by a **theme resource** applied at room load time. The existing Kenney tile set stays unchanged; variation is achieved purely through **ambient color tinting, fog color, and a subtle screen overlay**.

**Design hierarchy:**
```
Dimension → Universe → Galaxy → Planet → Environment
```
Each level narrows the context. The terminal node — Environment — selects a specific `EnvironmentTheme` resource that controls room atmosphere. Higher tiers signal harder difficulty through color temperature and saturation.

**Difficulty tiers (planned):**

| Tier | Zone / Environment | Ambient tone | Feel |
|---|---|---|---|
| 1 | Corporate HQ | White / neutral | Familiar, corporate, safe |
| 2 | Research Facility | Cool blue | Clinical, sterile, precise |
| 3 | Jungle Outpost | Warm green | Organic, humid, concealed |
| 4 | Arctic Base | Icy blue | Cold, stark, exposed |
| 5 | Space Station | Dark teal | Isolated, vacuum, hostile |
| 6 | Underground Bunker | Grey-red | Industrial, grim, final |
| 7+ | Hell | Bright red | Devilish, oppressive, intense |
| MAX | Veteran | Burning purple | Expert-only, symbolic mastery |

**Planned `EnvironmentTheme` resource:**
```gdscript
class_name EnvironmentTheme extends Resource
@export var theme_id:                  String
@export var floor_tile:                String          = "floor_NE"
@export var wall_tile_overrides:       Dictionary      = {}  ## e.g. {"wall_NE": "wall_SW"}
@export var ambient_color:             Color           = Color.WHITE   ## CanvasModulate tint
@export var fog_color:                 Color                           ## vision_fog.gdshader param
@export var screen_tint:               Color           = Color(0,0,0,0) ## top ColorRect overlay
@export var crate_variants:            Array[String]
@export var available_enemy_variants:  Array[String]
```

**Planned new files:**
- `godot/scripts/systems/environment_theme.gd` — Resource class above
- `godot/scripts/systems/game_context.gd` — Autoload storing `dimension`, `universe`, `galaxy`, `planet`, `environment_id`; exposes `func get_theme() → EnvironmentTheme` and signal `theme_changed`
- `godot/scripts/systems/theme_registry.gd` — loads all `.tres` from `res://godot/resources/themes/`; returns theme by `theme_id`
- `godot/resources/themes/theme_corporate.tres`, `theme_research.tres`, `theme_hell.tres`, `theme_veteran.tres`, etc.

**Planned modifications to existing files:**
- `room.gd` — in `_ready()`, call `GameContext.get_theme()` and apply: `ambient_color` to `CanvasModulate` node; `fog_color` into the `ShaderMaterial` parameter of `VisionFogOverlay`; `screen_tint` to a top-layer `ColorRect`
- `room_layout_builder.gd` — `func build_layout(theme: EnvironmentTheme = null) → Dictionary`; use `theme.floor_tile` if provided, `theme.wall_tile_overrides` to remap autotile names after resolution
- `room.tscn` — add `CanvasModulate` node (ambient tint) and `CanvasLayer + ColorRect` (screen tint overlay)

**Scope boundary (Phase 2):**
- No change to game mechanics
- No new tile sprite assets — color/lighting differentiation only for the foreseeable future
- No actual roguelite map generation; `GameContext` coordinates set manually during development
- Enemy and entity variants are declared in `EnvironmentTheme` but not spawned until M2

---

## 3.10 Lighting & Shadow System

Shadows are a **first-class environment element**, not a UI overlay. They are generated from the physical positions of light sources relative to obstacles, baked into a dedicated `ShadowLayer TileMapLayer` at room load time, and covered by Fog of War like any floor tile. The player reads shadows the same way they read walls — always present, geometrically predictable, discoverable through exploration.

**Full design specification:** see `DEVELOPMENT/LIGHTING_DESIGN.md`

### 3.10.1 Three Visual Depth Layers

The scene has three spatial planes at different parallax speeds (only the game layer is interactive):

| Layer | Contents | Parallax | z_index |
|-------|----------|----------|---------|
| **Upper (ceiling)** | Lamps, torches, ceiling geometry, high walls | ~1.08–1.12× (faster) | Above all gameplay |
| **Game (floor)** | Tiles, crates, walls, agent, guards, shadow tiles | 1.0× (reference) | Standard TileMap hierarchy |
| **Lower (sub-floor)** | Water, lava, smoke, grates, vents | ~0.88–0.92× (slower) | Below floor tiles |

Upper and lower layers are purely cosmetic. Lamps on the upper layer move slightly faster than the ground as the camera pans — visually "suspended" above the play surface.

### 3.10.2 Light Source Types

| Type | Height | Radius | Shadow character | Interactive |
|------|--------|--------|------------------|-------------|
| **Ceiling lamp** | 5.0 | 6–8 tiles | Long, sharp, radial | Hackable, breakable |
| **Wall torch** | 2.5 | 4–5 tiles | Medium, directional | Extinguishable |
| **Candle** | 0.5 | 2–3 tiles | Short, soft, omnidirectional | Extinguishable |
| **Sunlight** | ∞ | ∞ | Parallel, long, fixed direction | No |
| **Emergency lamp** | 3.5 | 3 tiles | Red, activates on alarm | Alarm-triggered |
| **Broken/flickering** | 4.0 | 5 tiles | Intermittent, baked at OFF state | Triggerable |

### 3.10.3 Interactive Light Mechanics (M4+)

- **Extinguish** (candle/torch): 1 AP adjacent. Creates shadow, triggers guard SUSPICIOUS if in LOS.
- **Hack** (ceiling lamp): 1–2 AP at terminal. Disable, flicker, or redirect.
- **Break**: 1 AP melee/throw. Permanent, loud noise, debris tile.
- **Alarm-activated**: emergency lamps illuminate stealth corridors during alert — tactical pressure.

---

## 3.8 Retention & Replayability Systems

### 3.8.1 Daily Challenge (Seed-based)

Every player worldwide faces the identical procedurally-generated map each day:

```gdscript
rng.seed = Time.get_date_dict_from_system().hash()
```

A global leaderboard ranks by turns used + alert level reached. Community discussion of “today’s map” is a free engagement loop. Zero server infrastructure required — the seed is the date.

### 3.8.2 Pre-mission Skill Selection

Before each mission, the player is shown **4 randomly drawn skills/gadgets** from their unlocked pool and picks 2 to bring. Same mission with a different loadout = a genuinely different run. Forces adaptation instead of relying on a memorized “best build”. Implementation: one pre-mission selection screen drawn from the agent’s unlocked skill set.

### 3.8.3 Ghost Run — Par Timer

Each map has a **par turn count**. Completing in:
- ≤ par → 3 stars + Ghost badge
- par +1 to par +5 → 2 stars
- above par +5 → 1 star (mission complete)

Stars never block progression but drive the obsession to optimize. The player knows a perfect run exists — and wants to find it.

### 3.8.4 Death Replay

On mission failure, the game replays the **last 3 turns** as a semi-transparent ghost overlay before showing the retry screen. The player sees exactly where the mistake was made — turning frustration into a learning moment.

```gdscript
# Append agent Vector2i position to history Array each turn.
# On failure: replay last 3 entries as tweened ghost at 50% alpha.
```

### 3.8.5 Mastery Statistics

After each run, display a brief stats card:
- Tiles moved in stealth vs. total tiles moved (% stealth rating)
- Total noise generated
- Turns used vs. par
- Peak alert level reached

These numbers give a tangible sense of improvement independent of mission outcome.

---

## 3.9 Adaptive Difficulty & Counter System

As the agent unlocks capabilities, the opposition evolves in response. The counter appears in the **next zone**, not the next mission — zone-gated, not ability-gated, to avoid punishing the player immediately for a new unlock.

| Agent capability | Counter introduced in next zone |
|---|---|
| Smoke bomb (blinds guards) | Guard with gas mask (immune to smoke) |
| Hack terminal (disables cameras) | Camera with physical backup switch (adjacent tile interaction required) |
| Sprint / dash movement | Pressure-plate corridors (noise-triggered alarm) |
| Overwatch stance | Shield-bearing guard (absorbs overwatch reaction, advances on agent) |
| Invisibility skill | Thermal-imaging guard (detects heat signature, ignores optical stealth) |
| Silent takedown | Guards patrolling in pairs (takedown triggers partner alert) |

**Mathematical balancing model:**
- Target metric: **Expected Actions to Complete (EAC)** — average actions an experienced player needs per map.
- Zone 1 EAC ≈ 12 actions. Zone 6 EAC ≈ 28 actions.
- Difficulty grows by adding *simultaneous variables* (patrol density, camera overlap, noise sensitivity) rather than inflating raw enemy stats.
- Guard HP and damage remain constant across zones. Complexity scales; numbers do not.

---

## 4. Progression & RPG Elements

### 4.1 Agent Profile
- **Codename** (player-chosen)
- **Level / XP** — earned by completing missions, side objectives, and streaks.
- **Skill tree** — branching paths (see below).

### 4.2 Skill Tree (initial design)

```
               [STEALTH]
              /          \
       [Shadow Walk]   [Silent Takedown]
            |                |
     [Invisibility      [Disguise
       (brief)]          Mastery]

               [TECH]
              /       \
       [Hacking]    [Gadget
         Lv 1-3]    Efficiency]
            |            |
     [Remote         [EMP
      Access]        Blast]

               [ATHLETICS]
              /            \
       [Sprint]         [Climb]
          |                |
     [Diagonal          [Vent
      Movement]         Crawl]
```

### 4.3 Gadgets & Equipment

| Gadget | Effect | Unlock |
|---|---|---|
| **Lockpick** | Open locked doors silently | Chapter 1 reward |
| **Smoke bomb** | Blocks camera/guard vision for 2 enemy turns (1 AP) | Chapter 2 reward |
| **EMP device** | Disables electronics in a radius for 3 enemy turns (1 AP) | Skill tree (Tech) |
| **Decoy** | Attracts guards to a target tile | Shop / XP unlock |
| **Grappling hook** | Move 2 tiles in one action (vertical only) | Skill tree (Athletics) |
| **Periscope / Mini-drone** | Reveals tiles beyond normal vision | Shop / XP unlock |
| **Disguise kit** | Lets agent pass one guard without detection | Skill tree (Stealth) |

Gadgets have **limited charges** per level; charges refill between levels or can be restocked via ads/rewards.

### 4.4 Combat, Rewards & Floor Progression
- Stealth is the preferred playstyle, but **brute force is a supported secondary path**, not an accidental edge case.
- Combat actions can include:
  - **silent melee takedown**,
  - **noisy melee strike**,
  - **pistol / ranged attack**,
  - **environmental attack** (explosive, trap, hacked device).
- Loud combat should increase risk by raising alert, attracting reinforcements, or changing room states.
- Between floors, the player may:
  - pick one of several rewards,
  - buy / equip gadgets,
  - unlock skills,
  - heal or restock,
  - and continue deeper into the dungeon.
- This creates a run loop of: **enter floor → solve rooms → earn rewards → exit → upgrade → next floor**.

---

## 5. Level Design Guidelines

1. **Segment size:** Each segment is **18 × 36 tiles** (MAP_SIZE = `Vector2i(18, 36)`). A mission map is a **3 × 3 grid of segments**. Interior playable area per segment: **16 × 34 tiles** (1-tile slab border on all sides).
2. **Visible area:** Portrait orientation at strategic zoom (~30%) shows roughly 28% of segment width at a time. Players pan freely within the active segment. Adjacent segments display fog of war until visited.
3. **Critical path:** Every level must have at least one solvable path with base skills.
4. **Entrance / exit clarity:** Every generated floor must clearly communicate where the player started, where progression is blocked, and where the next-floor exit is located.
5. **Room purpose clarity:** A player should be able to infer whether a room is combat-heavy, stealth-heavy, objective-heavy, or reward-heavy from its layout and props.
4. **Multi-path variety:** Prefer 2–3 distinct routes when the grid is wide enough; each route should favour a different play-style (stealth, tech, athletics).
5. **Side-scroll branches:** Use horizontal offshoots sparingly for secret rooms and bonus objectives — they should feel like discoveries.
6. **Reverse levels:** One per chapter at most (escape sequence or plot twist) to maintain surprise.
7. **Terrain storytelling:** Use terrain modifiers (water, wind, ice) to hint at the environment's identity — lab fans, flooded basement, frozen rooftop.
8. **Skill gates:** Optional routes/shortcuts require specific skills or gadgets, rewarding progression.
9. **Pacing:** Alternate tension (dense threat zones) with relief (safe rooms, story beats).
10. **Replayability:** Side objectives + star ratings encourage revisiting levels with new abilities.
11. **Procedural constraints:** Generated rooms must obey authored rules for spawn distance, reward placement, required keys, and objective sequencing.

---

## 6. Monetisation

### 6.1 Ads
| Placement | Type | Notes |
|---|---|---|
| **Pre-level** | Interstitial (skippable after 5 s) | Shown before every level start. |
| **Post-level** | Interstitial or rewarded | Shown after level completion; rewarded ad doubles XP/coins. |
| **Continue (revive)** | Rewarded video | On mission failure, offer "Watch ad to continue from last checkpoint". |
| **Gadget restock** | Rewarded video | Between levels, offer extra charges. |

### 6.2 Cosmetic Shop (future)
- **Agent skins** — different outfits, colour palettes.
- **Tile/grid themes** — visual skins for the level environment.
- **Takedown animations** — cosmetic variations.
- **Trail effects** — footstep particles, shadows.
- Currency: earned in-game coins or purchased premium currency.
- **No gameplay advantage** from cosmetic purchases.

### 6.3 Potential Premium Options (evaluate later)
- **Ad-free pass** (one-time purchase removes interstitials; rewarded ads remain optional).
- **Chapter packs** (unlock future chapters early).

---

## 7. Technical Direction

| Aspect | Decision / Notes |
|---|---|
| **Engine** | **Godot 4** (open-source, lightweight, excellent 2D support, GDScript) ✅ DECIDED |
| **Language** | **GDScript** for game logic; **Python** for external tooling, level editors, and asset pipelines |
| **Rendering** | **Isometric 2.5D** — dimetric projection (45° horizontal, 26.57° elevation), square tile grid; Godot `TileMap` in **isometric mode**; placeholder coloured shapes → Kenney isometric tiles → pre-rendered 3D sprites (see §8) |
| **Grid system** | Godot `TileMap` backed by a logical 2D array of `Tile` resources (type, occupant, AP cost, threat-cone refs) |
| **Turn manager** | Central `TurnManager` node: Player Phase → Enemy Phase → Environment Phase (cameras, lasers cycle) |
| **AI** | Finite-state machines for guards; A* path-following for patrols; runs during Enemy Phase |
| **Level format** | Godot scenes (`.tscn`) + companion JSON/resource files for room templates, patrol routes, triggers, and metadata |
| **Dungeon generation** | Rule-driven floor builder that stitches room templates from an entrance to an exit while guaranteeing solvable progression |
| **Objective system** | Room-level quest definitions (`reach`, `hack`, `survive`, `recover`, `neutralize`) evaluated by a central objective tracker |
| **UI overlays** | Separate overlay layer for 1 AP tiles, 2 AP tiles, path preview, danger zones, and interactable markers |
| **Ad SDK** | Google AdMob (Android) / Apple AdServices (iOS) — via Godot plugin |
| **Analytics** | Firebase Analytics — track level completions, fail rates, ad engagement |
| **Save system** | Local JSON (`user://`) + optional cloud sync |

### 7.2 Development Operator — James

- **James** is the internal macOS development operator for INFILTRAITOR production.
- James is responsible for local execution tasks in Godot, VS Code, browsers, Finder, Terminal, and other desktop tools.
- James is not the planning brain. GitHub Copilot using GPT-5.4 provides reasoning, task planning, and decision support.
- James provides:
  - **eyes** — screenshots, OCR, UI-state verification,
  - **ears** — push-to-talk audio capture,
  - **hands** — clicks, typing, shortcuts, and AppleScript-driven control,
  - **memory** — task logs, session summaries, and state snapshots.
- The target interaction model is **push-to-talk**, not a wake word:
  - press keypad `0` to start recording,
  - hold while speaking,
  - release to stop recording and submit the prompt.
- A critical James requirement is **return-to-editor discipline**: if James leaves VS Code to perform work in Godot or another app, he must return with a result, evidence, and a clear task outcome.
- James has been moved to a standalone repo at https://github.com/K4PUTZ/JAMES.git and lives as a peer directory (`../JAMES/`). It is project-agnostic and can be used for any development workflow.

### 7.1 Asset Generation Tooling (Stable Diffusion)

We have a local **AUTOMATIC1111 Stable Diffusion WebUI** installation that can be used to generate concept art, placeholder sprites, and reference images.

#### Setup summary
| Item | Value |
|---|---|
| **Location** | Auto-detected: `../../stable-diffusion-webui/` (sibling of repo, preferred) or `../stable-diffusion-webui/` (inside repo) |
| **Python** | `/opt/homebrew/bin/python3.10` — venv at `stable-diffusion-webui/venv/` |
| **Model** | `v1-5-pruned-emaonly.safetensors` (SD 1.5) |
| **Backend** | Apple Silicon MPS (Metal Performance Shaders) |
| **API port** | `http://127.0.0.1:7860` (when launched with `--api`) |
| **Launch flags** | `--skip-torch-cuda-test --upcast-sampling --no-half-vae --use-cpu interrogate --disable-nan-check --api` |

#### How to generate images

Two files in `DEVELOPMENT/` handle generation:

| File | Purpose |
|---|---|
| `generate_concept.py` | Python script that talks to the SD WebUI API. Accepts `--prompt`, `--width`, `--height`, `--steps`, `--seed`, `--name`, etc. Can auto-launch the WebUI if not running. |
| `generate_art.sh` | **Shell wrapper** that runs the Python script fully detached. Use this one. |

**Basic usage:**
```bash
# Generate with default INFILTRAITOR concept prompt:
bash DEVELOPMENT/generate_art.sh

# Custom prompt:
bash DEVELOPMENT/generate_art.sh --prompt "top-down tile grid, icy rooftop level, stealth game"

# Check progress:
bash DEVELOPMENT/generate_art.sh --status

# Cancel a running job:
bash DEVELOPMENT/generate_art.sh --stop

# Only start the SD server (no generation):
bash DEVELOPMENT/generate_art.sh --start-sd
```

Output is saved to `DEVELOPMENT/concept_art/` with auto-incrementing filenames.

#### ⚠️ Known issue — VS Code terminal

> **The VS Code integrated terminal kills long-running background processes** when
> another command is executed in the same terminal tab. This is a VS Code limitation,
> not a shell issue. SD image generation on Apple Silicon MPS takes **2–5 minutes**
> per image, which is long enough to be interrupted.
>
> **Workaround (implemented):** `generate_art.sh` launches the Python script via
> `nohup` inside a signal-trapped subshell `(trap '' INT HUP TERM; ...)` so it
> survives terminal reuse. Always use `generate_art.sh`, never call
> `generate_concept.py` directly from VS Code terminals.
>
> **For AI agents:** Do NOT run `generate_concept.py` directly with `run_in_terminal`.
> Instead:
> 1. Run `bash generate_art.sh [options]` — it returns immediately.
> 2. Wait ~3 minutes.
> 3. Run `bash generate_art.sh --status` to check completion.
> 4. If needed, poll the API directly:
>    `curl -s http://127.0.0.1:7860/sdapi/v1/progress | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['progress'])"`

#### Performance expectations (Apple Silicon)
| Resolution | Steps | Approx. time |
|---|---|---|
| 512 × 768 | 30 | 2–4 min |
| 512 × 512 | 20 | 1–2 min |
| 768 × 1024 | 30 | 5–8 min |

---

## 8. Art Direction

### 8.1 Placeholder Phase (current)
- All game entities are **simple coloured rectangles / shapes** on the tile grid:
  - Agent → green square.
  - Guard → red square.
  - Camera → orange triangle (pointing in view direction).
  - Laser → red line across tiles.
  - Walls → dark grey fill.
  - Floor → light grey fill.
  - Objective → gold square.
- This keeps visual noise minimal and lets us focus on **mechanics and feel** first.

### 8.2 Pre-rendered 3D Phase (future)
- Once gameplay is solid, we will **model assets in 3D** (Blender) and **render them as 2D sprite sheets** from the top-down camera angle.
- This gives a rich, pseudo-3D look while keeping the engine workload 2D.
- Each entity will have directional sprites (N/S/E/W) and animation frames (idle, walk, action).
- Tile sets will be rendered the same way — modular 3D pieces assembled in Blender, rendered to atlas PNGs.
- The swap is purely visual: the underlying `TileMap` and game logic remain unchanged.

### 8.3 General Direction
- **Palette:** Dark, muted backgrounds (concrete, steel) with high-contrast agent and threat colours.
- **Camera:** Isometric 2.5D, dimetric projection (45° horizontal / 26.57° elevation); smooth scroll following the agent in portrait orientation.
- **Room language:** Compact Zelda-like rooms and corridors with strong silhouette readability on the isometric grid.
- **UI:** Minimal HUD — alert meter (top), action points indicator (top), context menu (tap-activated), mini-map (corner, optional).
- **Movement overlays:** Distinct colours for 1 AP movement, 2 AP movement, and path preview; danger tiles may be overlaid separately.

### 8.4 Visual References

| Reference | File | Style lesson |
|---|---|---|
| *Emperor: Rise of the Middle Kingdom* | `REFERENCES/Emperor_Isometric.jpg` | Isometric pre-rendered 3D sprites on a clear tile grid; rich readable silhouettes; multi-layer elevation |
| *StarCraft / SC: Remastered* | `REFERENCES/starcraft.jpg` | Dimetric 2:1 grid; high-contrast units on dark terrain; clean unit readability at small sizes |
| *XCOM 2* | `REFERENCES/XCOM-2-03_0.webp` | Tactical turn-based UI overlay clarity; distinct movement zone colours |

---

## 9. Narrative & Story

### 9.1 Core Concept

The name is the story: **INFILTRAITOR** — the agent is *both* an infiltrator *and* a traitor.

The player controls a highly skilled field operative who discovers they have been serving the wrong side. The narrative arc is a **slow awakening** — inspired by *The Matrix* — from loyal instrument of the system to active agent of resistance from within. The twist: the game's title describes what the player *becomes*, not just what they *do*.

### 9.2 The Two Factions

| Faction | Public face | True nature |
|---|---|---|
| **The Agency** | Stability. Prevents wars, protects global order. | Achieves stability through surveillance, manipulation of governments, and the suppression of dissent. Genuinely prevents catastrophes — and genuinely silences innocents. |
| **The Network** | Transparency. Freedom of information. Resistance. | Leaks classified data; sabotages surveillance infrastructure. Genuinely fights for freedom — and genuinely endangers operatives and civilians with indiscriminate exposure. |

**Neither faction is purely heroic.** The player must choose their complicity — and live with the consequences.

### 9.3 The Story Arc

```
ACT 1 — The Asset (Zones 1–2)
  Tutorial missions. The agent is effective, trusted, professional.
  Unknown to them, their successful missions are being used to eliminate
  Network contacts. One mission ends with civilian casualties that HQ
  quietly erases from the record. The agent notices the discrepancy.

ACT 2 — The Fracture (Zones 3–4)
  First contact with a Network informant embedded in a target location.
  The agent begins passing double intelligence — completing Agency missions
  while feeding the Network parallel data. The Agency's internal
  surveillance closes in. The handler starts asking unusual questions.

ACT 3 — The Traitor (Zones 5–6)
  The Agency burns the agent's cover. Now both hunter and hunted,
  operating from inside the system they are dismantling, the agent must
  penetrate the Agency's most secure locations to expose the full operation.
  Final mission: destroy the Agency from within — or go public with
  everything and let the world decide.
```

### 9.4 Narrative Delivery

Narrative is **light and non-intrusive** — gameplay is primary. Story arrives in small, skippable pieces that never block turn flow.

| Method | When | Details |
|---|---|---|
| **Mission briefing** | Before each level | 2–3 lines from the handler or a Network contact. Skippable. |
| **Comm-link messages** | During gameplay | 1–2 line speech bubbles triggered by specific tiles or events. Non-blocking. |
| **Intel fragments** | Collectible in each map | Optional lore objects — documents, recordings, data packets. Build the deeper backstory for players who want it. |
| **Victory / defeat screen** | After each level | Brief narrative outcome + stats + rewards. |
| **Dossier log** | Between levels (menu) | Accumulated intel fragments form an optional expanded narrative. |

**LLM-generated briefings (future):** With a fixed template — location + target type + extraction window + faction context — an LLM produces unique, coherent mission briefings for every procedurally generated run. Each mission feels personally authored.

### 9.5 Tone

Espionage thriller — tense but not grim. Dry humour from Network contacts; cold professionalism from the Agency handler. Moral ambiguity is real and never resolved neatly — the player decides what justice looks like. Closer to *Tinker Tailor Soldier Spy* in stakes, *Mission: Impossible* in pacing.

---

## 10. Audio Direction (preliminary)

- **Music:** Ambient tension tracks per chapter; intensifies during near-detection.
- **SFX:** Footsteps (tile-type dependent), alert sting, camera whir, laser hum, gadget activation.
- **Haptics:** Short vibration on detection warning; longer pulse on mission failure.

---

## 11. Milestones & Roadmap

| # | Milestone | Scope | Target |
|---|---|---|---|
| **M0** | Game Plan & documentation | This document ✅ | 2026-02-20 |
| **M1** | Prototype — grid + room flow | Godot project ✅, TileMap ✅, 55×55 room ✅, AP/turn system ✅, movement overlay ✅, animated movement ✅ | ✅ Complete |
| **M1.5** | Prototype — segment system + visibility | Segment layout builder (18×36, autotile wall system, floor apron, crates, access points) ✅; three-layer fog of war (distance shader, FOW polygons with feathered rings, camera leash) ✅; tap-to-select tile, path preview, 1AP/2AP zones ✅; tile-wall autotile Phase 1 fixes ✅ | ⧖ In progress — enemy systems + contextual actions pending |
| **M2** | Prototype — stealth systems | Guard AI (patrol, FSM, perception, communication, search), detection pipeline, noise system, cover, posture, directional shadows, visual indicators | ⧖ In progress |
| **M2-01..05** | Detection pipeline | TicSystem, colored cone, organic patrol, noise grid, audio detection | ✅ Complete |
| **M2-06..11** | Guard intelligence + cover + polish | Decoupled vision/body, GuardAttention, STATE_SEARCH, comms, shadow tiles, cover states, FSM balance | ✅ Complete |
| **M2-12a** | Tactical mockup | New layout with shadow corridors, cover positions, asymmetric patrol routes | ⧖ Pending |
| **M2-12b** | Agent posture | STANDING/CROUCHING/PRONE, AP cost, detection multipliers, placeholder visuals | ⧖ Pending |
| **M2-13** | Directional shadow system | LightSource model, obstacle heights, directional ray casting, ShadowLayer TileMapLayer | ⧖ In progress (rewrite) |
| **M2-14** | Camera + noise indicators | Camera locked on agent (revealed guards only), guard noise emission, floating directional indicators | ✅ Complete |
| **M2-15** | Cover indicators UI | Shield icons on obstacle faces within movement perimeter | ⧖ Pending |
| **M2.5** | Prototype — room objectives | Room quest system, reward pickup flow, objective tracker, progression gate to next room/floor | TBD |
| **M3** | Prototype — procedural floor builder | Room templates, connectors, solvable entrance-to-exit generation, reward / quest placement rules | TBD |
| **M4** | Vertical slice | 1 full chapter theme, procedural floors, skill tree, basic UI, reward loop | TBD |
| **M5** | Monetisation integration | AdMob, rewarded ads, continue flow | TBD |
| **M6** | Content expansion | Additional chapters, gadgets, cosmetic shop | TBD |
| **M7** | Polish & launch prep | Performance, accessibility, store assets | TBD |

---

## 12. Open Questions

- [x] ~~Turn-based vs real-time with pause~~ → **Turn-based (XCOM-style, 2 AP per turn).** ✅
- [x] ~~Target engine decision~~ → **Godot 4 (2D).** ✅
- [x] ~~Portrait vs landscape orientation~~ → **Portrait. Camera zoomed in, scrolls to follow agent.** ✅
- [x] ~~Multiplayer~~ → **No multiplayer at launch.** Future: cooperative elements (send energy/equipment to friends). ✅
- [x] ~~Narrative depth~~ → **Light narrative.** Artistic intro screens, short in-game dialogs, victory/defeat story beats, optional intel log. ✅
- [x] ~~Overwatch / reaction system~~ → **Yes.** Overwatch stance + traps during player turn; detection reaction window during enemy phase; no free actions otherwise. ✅
- [x] ~~AP economy tuning~~ → **Yes.** Tiles have terrain modifiers (rough, water current, wind, ice, shadow, conveyor, etc.) affecting movement cost and behaviour. ✅
- [x] ~~Core control model~~ → **Tap a tile, inspect options, commit by AP cost.** ✅
- [x] ~~UI readability target~~ → **Distinct 1 AP and 2 AP movement overlays with path preview.** ✅
- [ ] Exact AP costs per terrain type — needs playtesting.
- [ ] Exact colour system for movement, danger, interactable, and quest overlays on mobile.
- [ ] How often should combat-first rooms appear versus stealth-first rooms in procedural generation?
- [ ] What is the minimum room template set needed for the first procedural prototype?
- [ ] Should weapons use ammo, cooldowns, noise values, or some combination?
- [ ] How many trap types at launch? Balance between trap-play and stealth-play.
- [ ] Cooperative friend system — platform integration (Game Center, Google Play Games, or custom)?
- [ ] Multi-floor / elevation system — scope and priority.
- [x] ~~Portrait aspect ratio targets~~ → **Segment is 4608×2304 px screen space; portrait device shows ~28% of segment width at ~30% zoom. Tablet vs phone: same segment geometry, different zoom bounds.** ✅
- [ ] Segment theme catalogue — what themes exist and how are they assigned per mission?
- [ ] Access point data model — how are access point positions stored and communicated between adjacent segments?
- [ ] Blocker design rules — minimum distance between a critical blocker and its unlock location across the 3×3 grid?
- [ ] Fog of war visual style — darkened tiles, greyed-out sprites, or full black mask?

---

## 13. Change Log

| Date | Author | Changes |
|---|---|---|
| 2026-06 | — | **M2 stealth systems complete (M2-01..M2-14).** Guard FSM with 5 states (PATROL/SUSPICIOUS/SEARCH/ALERT/CHASE), GuardAttention decoupled vision system, STATE_SEARCH physical tile traversal, guard communication (whistle/radio/alarm via room.gd signals), shadow tiles (detection multipliers), cover states (FULL/PARTIAL/NONE with flanking), agent posture (STANDING/CROUCHING/PRONE), camera locked on agent during enemy phase with floating noise direction indicators. **Lighting system designed** (see LIGHTING_DESIGN.md): three visual depth layers (ceiling/game/sub-floor), directional shadows from LightSource positions, obstacle height geometry, interactive light mechanics deferred to M4+. **M2-13 shadow rewrite in progress**: replacing dynamic Node2D overlay with static ShadowLayer TileMapLayer baked at room load. **Open:** M2-12a tactical mockup, M2-12b agent posture sprites, M2-13 shadow rewrite, M2-15 cover UI indicators. |
| 2026-02-20 | — | Initial game plan created. |
| 2026-02-20 | — | Decided: turn-based (XCOM-style, 2 AP/turn). Decided: Godot 4 (2D) as engine. Added tap-to-select context menu interaction model. Defined placeholder art pipeline with future pre-rendered 3D asset phase. Added M1.5 milestone for context menu. Updated open questions. |
| 2026-02-20 | — | Decided: portrait orientation with scrolling camera. Defined level layout patterns (multi-path, single-path gauntlet, side-scroll wings, reverse levels). No multiplayer at launch; future cooperative elements. Light narrative via intro screens, tutorial level, in-game dialogs, victory/defeat screens. Overwatch + traps + detection reaction window defined. Tile terrain modifiers system added (water current, wind, ice, shadow, conveyor, etc.). Added §9 Narrative & Story. Expanded Level Design Guidelines. Resolved 5 open questions, added 5 new ones. |
| 2026-02-20 | — | First concept art generated via Stable Diffusion (`concept_art/infiltraitor_concept_1.png`). Consolidated SD tooling: rewrote `generate_concept.py` with CLI args, created `generate_art.sh` wrapper to handle VS Code terminal limitations. Added §7.1 Asset Generation Tooling with setup summary, usage instructions, known issues, and AI-agent guidance. Cleaned up temp files. |
| 2026-03-09 | — | Aligned the project plan with the intended prototype direction: Zelda-like room-to-room dungeon flow, entrance/exit structure, room objectives, room rewards, procedural floor generation, brute-force combat as a supported playstyle, and explicit 1 AP / 2 AP tactical movement overlays for mobile readability. Updated the roadmap and open questions accordingly. |
| 2026-03-09 | — | Added James as the internal development operator for production tooling. Documented the push-to-talk control model, the split between James and the external GPT-5.4 planning brain, and the requirement to log actions and return to VS Code with results after tasks performed in Godot or other desktop applications. |
| 2026-05-18 | — | Confirmed engine as **Godot 4** (closing Phaser.js / Three.js experiments). Confirmed **isometric 2.5D** rendering style: dimetric projection, 45° horizontal / 26.57° elevation, square tile grid via Godot `TileMap` in isometric mode. Added §8.4 Visual References (Emperor, StarCraft, XCOM). Added planned Godot project folder structure to README. Rewrote README to reflect actual project state. Added new reference screenshots to `REFERENCES/`. |
| 2026-05-19 | — | Full asset reorganization completed. `TILESETS/` → `ASSETS/ISOMETRIC/` (8 Kenney packs with clean names). `OTHER ASSETS/` → `ARCHIVE/` (textures, fonts, FX, sprites-2d). Characters split into `ASSETS/CHARACTERS/humans/`. Orthographic angle renders → `ASSETS/REFERENCE/`. Deleted space-themed, flat-2D, and non-isometric packs. Created `DEVELOPMENT/ASSET_MAP.md` — full tile catalogue, chapter-theme mapping, and procedural generation guide. Updated README project layout. |
| 2026-05-19 | — | **Alpha 0** — first visual prototype running in-engine. Godot 4.6 project scaffolded (`project.godot`, `room.tscn`, `room.gd`, `agent.gd`, `tilemap_helper.gd`). TileSet builder (`build_tileset.gd`) implemented as headless `SceneTree` script; runs from terminal without Godot editor. Generates `tileset_blocks.tres` (240 tiles, blocks-prototype pack) with 4 custom data layers per tile (`tile_name`, `walkable`, `cover`, `interactive`) and `tile_registry.gd` (name→source_id lookup). 9×9 isometric test room rendering confirmed in-engine. VS Code dev workflow established: F5 launches game via `node-terminal` launch config, ⌘⇧B rebuilds TileSet via task. Tagged as `alpha-0` and pushed to GitHub. |
| 2026-05-26 | — | **Alpha 2.1** — stabilized the mismatch between the rendered board and the logical numbered grid. Added a shared runtime visual-offset compensation so camera centering, coordinate labels, selection overlay, and tile picking all reference the same board position. Tightened tile picking to require clicks inside the isometric diamond, eliminating selection in empty space above the board. Swapped the tall debug border blocks for low slabs to improve visual readability while the alignment compensation is in place. |
| 2026-05-29 | — | **Segment system design locked** (see §3.7.6). Map structure: 3×3 grid of 9×27-tile segments. Interior: 7×25 tiles. Natural 3×3 sub-grid of 3×9-tile zones. Access points: 1 main + 1 secondary (gated) + 1 secret per active border. Teleport: mirrored-offset arrival (exit col C north → arrive col C south of next segment). AP mechanic clarified: no extra cost — arriving on border row costs 1 natural movement tile to reach interior; 2-tile safe zone (border row + first interior tile) guaranteed encounter-free. Full AP reset on segment entry. Camera confined to active segment; fog of war on unvisited. Anti-linear rule: ≥1 critical blocker with unlock in non-adjacent segment. Events: on-entry, on-zone/tile, on-interaction. Code changes: wall generation deleted from `room_layout_builder.gd`; `StructureWallLayer` unified (single layer in `room.gd` + `room.tscn`); `EDGE_ALIGNED_EXCLUSIONS` added to `build_tileset.gd`. Segment prototype: `MAP_SIZE` → `Vector2i(9, 27)`, `AGENT_START_CELL` → `Vector2i(4, 25)`, `ACCESS_POINTS` const + `_add_access_points()` added. Camera now focuses on agent spawn cell. |
| 2026-05-26 | — | **Alpha 2.2** — advanced into the M1.5 tactical UI slice. Added a debug agent, AP/end-turn control, movement range overlays, selected-destination path preview, two-tap confirmation flow, and an auto-end checkbox inside the `END` button. Introduced blocked crate obstacles and a dedicated structure layer so walls/props render above tactical overlays while the path remains visible only over floor tiles. Set the coordinate overlay to start disabled by default. |
| 2026-05-30 | — | **Tile-wall autotile system** (see §3.7.7) — replaced the placeholder slab border in `room_layout_builder.gd` with a full autotile system. `_pick_wall_tile()` selects from `wall_*`, `wallCorner_*`, and `block_*` using three ordered rules: (1) mid-border straight-face override, (2) open-count autotile for corners, (3) end-cap facing for 3-open cells. **Phase 1 fixes** (commit `c0c6d19`): Rule 1 eliminates T-junction notches where interior walls at y=17 meet the segment border at x=0 and x=17; Rule 3 fixes end-cap cells at `(6,17)` and `(11,17)` that previously rendered as floating `block_*` cubes. **Floor apron**: `_build_room()` now floors `range(-1, MAP_SIZE.x+1)` × `range(-1, MAP_SIZE.y+1)` so border wall outer faces sit on ground instead of dark background. **Environment/biome hierarchy** designed for Phase 2 — Dimension → Universe → Galaxy → Planet → Environment with 8 difficulty-coded tiers (Corporate → Veteran); see §3.7.8. |

---

*This document is the single source of truth for the INFILTRAITOR project. Update it whenever a decision is made or a milestone is reached, so that any contributor (human or AI) can pick up where work left off.*
