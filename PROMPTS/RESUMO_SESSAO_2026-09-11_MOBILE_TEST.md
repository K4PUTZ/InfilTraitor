# Session 2026-09-11 — the last render-order owed items, then the first phone test

Previous session:
[`RESUMO_SESSAO_2026-09-10_OPTION_A_SHIPPED.md`](RESUMO_SESSAO_2026-09-10_OPTION_A_SHIPPED.md)
(Option A ratified and default ON; Option B removed).

| | commit |
|---|---|
| The crack clip follows opaque destruction; its reach stops at its own atom | `73997c8b` |
| A hole on a GU seam gives the neighbour its side sliver back, locally | `7f7adbc3` |
| Web/Android builds shipped without the JSON maps or the translations, at 482 MB | `e732fc51` |
| Temporary dev-toolbar G button; the player's action bar registered for JAMES | `651f9f62` |
| (+ `[DOCS]` current_state AUTO blocks: `0f39e032`, `b56beee8`) | |

---

## 1. ⛔ RESUME POINT — the export cannot load a raw PNG

**Found at the very end, not fixed, Director's call pending** (*"Vamos encerrar a
sessão e seguir na próxima"*). Five runtime loaders open the SOURCE PNG by path with
`Image.load(path)`, and an export ships only the imported `.ctex` — the web `.pck`
holds **zero** raw PNGs (read from its index). In every exported build (web AND
Android):

| loader | effect in the build |
|---|---|
| `godot/scripts/systems/texture_resolver.gd` `_try_load_and_validate()` | `ResourceLoader.exists()` passes, the raw decode fails → `Tier.NONE` → **generic atlas: grey walls, no facades, silently** (the ART_SPECIFICATIONS failure mode) |
| `godot/scripts/overlays/grenade_prop.gd` `_load_texture_raw()` | **the grenade is invisible** (prop and arc); it still explodes — logged `[GrenadeProp] failed to load …grenade_frames/frame_N_color.png (error 7)` |
| `godot/scripts/overlays/agent_probe_prop.gd:316` | same class, not yet observed |
| `godot/scripts/agents/agent_sprite.gd:1450` | same class; the agent renders, so this may be a fallback path — check |
| `godot/scripts/systems/collectible_frame_cache.gd:59` | same class, not yet observed |

**Why it blocks the device perf run:** with no facades the board runs the unbaked
path, and this project measured bake OFF at **+243%** cost — a phone number taken on
this build would measure a different game.

**Proposed fix (not approved yet):** one shared loader — the imported resource when
`ResourceLoader.exists(path)` (`(load(path) as Texture2D).get_image()`), the raw
`Image.load()` otherwise. The raw path exists on purpose: `grenade_prop.gd` notes that
`--script` CLI runs have no import scan, and the selftests are CLI runs.
⚠️ **The risk to check first:** an imported texture may be VRAM-compressed (lossy).
Facades must stay exactly grayscale (B2) and silhouettes must match canon (B3); a
lossy import breaks both with no error. Read the facade / frame `.import` settings
and set them lossless where needed BEFORE switching the loaders.

Also missing from the pack, minor: `res://VERSION` (`version_info.gd` reads it with
`FileAccess`) — add it to `include_filter`.

## 2. Also owed

- **Device performance number** — after §1. Web = Compatibility renderer (WebGL2),
  so the native number needs the APK (`EXPORT_ANDROID.md`; SDK/Java/templates are
  set up, the preset exists). Instruments are env vars, which neither web nor
  Android can receive — a small args→env autoload was proposed and not decided.
- **ACTION-BAR-01's engine seam** (`INTERFACE_MASTER_PLAN` v1.2 Part 5) — built by
  CLAUDE on `main` when the Director schedules it, before JAMES wires widgets. Then
  delete `DebugToolsController.create_grenade_button()`.

---

## 3. What was done

- **Render order closed its owed list.** The clip now follows destruction
  (`note_opaque_erased()` at the three destroy seams, gated by each crack's
  `occ_bounds`); its reach was over-reaching the 36 px atom (exact `|Δy|` test); a
  hole on a GU seam re-masks the neighbour locally (`_expose_seam_neighbour()`) —
  NOT a full render after a grenade, which would repaint outside the pre-cooked plan.
  All red/green on the real path; plan `RENDER_ORDER_MASTER_PLAN` §10b.10.
- **The phone test works through the Director's web flow** (`tools/persistent/MobileTesting.md`,
  now with the CLI export command and the three export traps).
- **Grenades on touch:** a temporary dev-toolbar G button; the real answer, an
  XCOM-style action bar read against DESIGN §3.1 / §8.7 / §10.2 D37, is registered for
  JAMES.

## 4. ⚠️ Findings worth carrying

- **A build that boots is not a build that is complete.** The first web export booted
  into a playable game while missing the JSON maps (only the code PLAYGROUND existed),
  the translations, and every raw PNG. Read the `.pck` index (GDPC v3: header →
  `dir_offset` → entries) — that found all four; the preset and the picture found none.
- **Godot web logs are unreadable from the browser console** — hundreds of lines are
  dropped in seconds. Hooking `console.log/warn/error` into `window.__logs` via the
  browser pane's JavaScript tool BEFORE acting, then filtering, is what exposed both
  the grenade-frame errors and the blast actually resolving.
- **A dev Button must be `FOCUS_NONE`** when a keyboard action shares its effect: a
  focused button eats `ui_accept`, and Enter (throw) would have cancelled the aim.
- **The destruction test's harness was wrong three times** (dust mistaken for the
  pillar; the roof cap's one-voxel overhang; two slices per block edge) — each caught
  by reading the board, not the counter.

**Every commit:** 52 selftests clean, lint clean, invariants clean, CODEMAP fresh.
The local http.server and the ngrok tunnel were stopped at session end.
