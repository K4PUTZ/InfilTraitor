# INFILTRAITOR — Game Plan

> **Project:** INFILTRAITOR  
> **Genre:** Top-down stealth / tactical RPG  
> **Platform:** Mobile (iOS & Android)  
> **Created:** 2026-02-20  
> **Last updated:** 2026-03-09  
> **Status:** Pre-production / Design phase  
> **Engine:** Godot 4 (2D)  
> **Orientation:** Portrait

**Repository (source of truth):**
- GitHub: https://github.com/K4PUTZ/InfilTraitor.git
- Default branch: `main`
- Clone: `git clone https://github.com/K4PUTZ/InfilTraitor.git`
- Suggested workflow: `git checkout -b feature/<short-name>` → commit → push → PR

---

## 1. High-Level Concept

**INFILTRAITOR** is a mobile **turn-based** stealth tactics game with RPG progression, inspired by the tactical readability of *XCOM* and the clean top-down room navigation of classic **Zelda-style** dungeon design. The player controls a secret agent viewed from a **top-down perspective** on a **square tile grid** in **portrait orientation**. The camera is zoomed in to show a portion of the dungeon; the map **scrolls to follow the agent** as they move from room to room.

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
| **Tall grass / shadow** | Reduces enemy vision — agent is harder to detect while on this tile. |
| **Stairs / ladder** | Transition between elevation layers (future multi-floor levels). |
| **Conveyor belt** | Moves anything on it 1 tile per turn in a fixed direction. |
| **Trap tile** | Player-placed or pre-existing; triggers an effect when stepped on. |

Terrain modifiers are displayed via **subtle tile overlays** (e.g., arrows for currents/wind, wavy lines for water) so the player can plan around them.

### 3.4 Vision & Fog of War
- The player has limited forward vision.
- Tiles outside vision range are dimmed / fogged.
- Certain gadgets (periscope, drone) can reveal tiles ahead.

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

1. **Grid size:** Start small (8 × 12 tiles) and expand to (12 × 20) in later chapters.
2. **Visible area:** Portrait orientation shows roughly 8 × 10 tiles at a time; the rest is revealed by scrolling.
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
| **Rendering** | 2D sprite-based with `TileMap` node; placeholder coloured rectangles → pre-rendered 3D sprites (see §8) |
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
- James lives under `DEVELOPMENT/JAMES/` and should evolve as a production-support system, not as game runtime code.

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
- **Camera:** Fixed orthographic top-down; smooth scroll following the agent.
- **Room language:** Compact Zelda-like rooms and corridors with strong silhouette readability.
- **UI:** Minimal HUD — alert meter (top), action points indicator (top), context menu (tap-activated), mini-map (corner, optional).
- **Movement overlays:** Distinct colours for 1 AP movement, 2 AP movement, and path preview; danger tiles may be overlaid separately.

---

## 9. Narrative & Story

### 9.1 Philosophy
Narrative is **light and non-intrusive** — the focus is on gameplay. Story is delivered in small, digestible pieces that never block the player for long.

### 9.2 Delivery Methods
| Method | When | Details |
|---|---|---|
| **Artistic intro screens** | Game start / new chapter | 2–3 illustrated panels introducing the character, mission context, or new villain. Skippable. |
| **Tutorial level** | First play session | A short, guided level that teaches movement, AP, context menu, and basic detection — woven into a narrative setup ("your first field assignment"). |
| **In-game text dialogs** | During gameplay | Short speech bubbles or comm-link messages (1–2 lines) triggered by reaching specific tiles or events. Do not pause the turn flow. |
| **Victory screen** | Level complete | Brief narrative outcome ("Intel secured — HQ sends new orders") + stats + rewards. |
| **Defeat screen** | Mission failed | Narrative consequence ("Agent compromised — extraction team en route") + retry / ad-continue options. |
| **Dossier / intel log** | Between levels (menu) | Collected intel pieces build a deeper backstory for players who want it — entirely optional. |

### 9.3 Tone
- Espionage thriller — tense but not grim. Occasional dry humour in comm-link dialog.
- The agent is a professional; the stakes feel real but the vibe is closer to *Mission: Impossible* than *le Carré*.

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
| **M1** | Prototype — grid + room flow | Godot project, TileMap, entrance room, exit room, room transitions, agent movement (2 AP/turn), turn manager | TBD |
| **M1.5** | Prototype — tactical UI | Tap-to-select tile, contextual action menu, path preview, 1 AP / 2 AP movement overlays | TBD |
| **M2** | Prototype — threats & combat | Guard patrols, vision cones, detection meter, enemy AI phase, basic brute-force attack option | TBD |
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
- [ ] Portrait aspect ratio targets — phone vs tablet scaling strategy.

---

## 13. Change Log

| Date | Author | Changes |
|---|---|---|
| 2026-02-20 | — | Initial game plan created. |
| 2026-02-20 | — | Decided: turn-based (XCOM-style, 2 AP/turn). Decided: Godot 4 (2D) as engine. Added tap-to-select context menu interaction model. Defined placeholder art pipeline with future pre-rendered 3D asset phase. Added M1.5 milestone for context menu. Updated open questions. |
| 2026-02-20 | — | Decided: portrait orientation with scrolling camera. Defined level layout patterns (multi-path, single-path gauntlet, side-scroll wings, reverse levels). No multiplayer at launch; future cooperative elements. Light narrative via intro screens, tutorial level, in-game dialogs, victory/defeat screens. Overwatch + traps + detection reaction window defined. Tile terrain modifiers system added (water current, wind, ice, shadow, conveyor, etc.). Added §9 Narrative & Story. Expanded Level Design Guidelines. Resolved 5 open questions, added 5 new ones. |
| 2026-02-20 | — | First concept art generated via Stable Diffusion (`concept_art/infiltraitor_concept_1.png`). Consolidated SD tooling: rewrote `generate_concept.py` with CLI args, created `generate_art.sh` wrapper to handle VS Code terminal limitations. Added §7.1 Asset Generation Tooling with setup summary, usage instructions, known issues, and AI-agent guidance. Cleaned up temp files. |
| 2026-03-09 | — | Aligned the project plan with the intended prototype direction: Zelda-like room-to-room dungeon flow, entrance/exit structure, room objectives, room rewards, procedural floor generation, brute-force combat as a supported playstyle, and explicit 1 AP / 2 AP tactical movement overlays for mobile readability. Updated the roadmap and open questions accordingly. |
| 2026-03-09 | — | Added James as the internal development operator for production tooling. Documented the push-to-talk control model, the split between James and the external GPT-5.4 planning brain, and the requirement to log actions and return to VS Code with results after tasks performed in Godot or other desktop applications. |

---

*This document is the single source of truth for the INFILTRAITOR project. Update it whenever a decision is made or a milestone is reached, so that any contributor (human or AI) can pick up where work left off.*
