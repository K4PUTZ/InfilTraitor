# Session 2026-09-11/12 — the export became a real build, and the blast got a real instrument

Previous session:
[`RESUMO_SESSAO_2026-09-11_MOBILE_TEST.md`](RESUMO_SESSAO_2026-09-11_MOBILE_TEST.md)
(§1 left the export unable to load a raw PNG, Director's call pending).

| | commit |
|---|---|
| Exported builds could not read a source PNG or probe a `res://` directory | `2759ceb4` |
| A phone booted into the desktop canvas, and the dev bar ran off screen | `9f49fe7b` |
| A blast craze clamped instead of tiling on every mobile build | `a78bdc04` |
| The showcase model and five dev glyphs were missing from every build | `969751f9` |
| `INFILTRAITOR_EVENT_NO_STRIP`: measure the blast, not the capture | `2ccd80f0` |

**Director verified on the phone:** glass decal ✅, portrait boot + two-row bar ✅,
icons ✅. The showcase could not be tested — **there is no button to open the menu
on mobile** (§2). His verdict on what matters next: *"o mais problemático é a
questão do tempo da explosão"*.

---

## 1. What was fixed

- **The raw-PNG class of bug, five call sites.** An export ships only the
  imported `.ctex`; `Image.load(path)` reads the SOURCE file, which is not in the
  pack. Result in every build: `Tier.NONE` → generic atlas (grey walls, no
  facades, silently) and an invisible grenade. `ImageSource` (new, in
  `systems/`) reads the raw file when it is on disk (editor, `--script` CLI) and
  the import otherwise. Every PNG imports `compress/mode=0`, so B2/B3 hold on
  both paths — checked BEFORE switching, since a lossy import would have broken
  both with no error.
- **`GLTFDocument.append_from_file()` has the same defect** (`showcase_panel.gd`):
  the pack holds the `.scn` and the `.import`, never the `.glb`. Same two-source
  choice.
- **`dir_exists_absolute(globalize_path("res://…"))` is FALSE inside a `.pck`** —
  it asks the real filesystem, which an export does not have. `agent_sprite.gd`
  probed its head/hat layers that way, so **the agent shipped headless**. Now
  `DirAccess.open()`, the same call the body frames already used.
- **A phone booted into the DESKTOP canvas.** `_ready()` ended with a bare
  `_on_hud_viewport_toggled()`, whose only effect was to flip the fresh state to
  desktop: measured, a boot that started at (390, 844) read `scale_size=(1280,
  720)` a few frames later, the board drew as a landscape band inside the
  portrait screen, and the button read "D". Now `_apply_boot_viewport()`, which
  picks by device and leaves a handheld's OS window alone.
- **The dev bar left the screen:** an `HBoxContainer` 396 px wide holding ten
  48 px buttons. Now a `FlowContainer`, centred, buttons at 40 px — two rows at
  390. The engine-added toolbar buttons ride the same wrap.
- **The blast craze clamped instead of tiling** — the Director's phone report (a
  crack low on the glass trailing straight lines upward, grenade only). Field
  mode drives `sheet_uv` outside [0,1] BY CONSTRUCTION; the wrap came only from
  the shader's `repeat_enable`, and **under Compatibility the GL sampler takes
  it from the CanvasItem's `texture_repeat`**, which defaults to DISABLED.
  ⚠️ Fixed and CONFIRMED BY THE DIRECTOR ON THE PHONE, never reproduced locally.
- **Five dev glyphs were tofu** (`↺ 🗺️ ✓ ✗ 💾 📡`): no theme, no font file and no
  font setting in the project, so the built-in font with no web fallback. ASCII
  now (`R`, `MAP`, `+`, `-`). A font would restore the icons if ever wanted.
- `VERSION` and `ASSETS/*.json` (178 bake manifests) joined `include_filter`.

## 2. ⛔ Owed

- **THE EXPLOSION'S DURATION — the Director's own priority, next session.** §3
  has the numbers; the direction question was put to him and dismissed, so the
  TARGET IS UNCHOSEN. The three candidates, with their costs, are in §3.
- **No way to open the main menu on mobile** — found by the Director trying to
  check the showcase. Same class as the grenade's G button: a keyboard-only
  route with no touch equivalent. Belongs with ACTION-BAR-01.
- **ACTION-BAR-01's engine seam** (`INTERFACE_MASTER_PLAN` Part 5), still owed
  from the previous session; then delete `create_grenade_button()`.
- **A device performance number** still needs an on-screen readout — env vars
  cannot reach a phone. Offered, deferred twice.
- The portrait dev override (`INFILTRAITOR_FORCE_HANDHELD`) was built for the
  glass diagnosis and REMOVED as unrequested scaffolding. Re-adding it was
  offered and dismissed.

## 3. The blast, measured — and what the numbers say

`INFILTRAITOR_EVENT_NO_STRIP=1` exists because **the filmstrip measures itself**:
the GPU readback plus a PNG per frame put a ~196 ms floor under EVERY frame. Two
boots agreed at mean 202.1 / 202.6 ms, worst 431.5 / 433.4 ms — all of it the
capture. Those two figures are RETRACTED.

Clean, PLAYGROUND fabric (31,3), the ratified baseline's own ground:

| | Forward+ | Compatibility (what the phone runs) |
|---|---|---|
| frames / wall clock | 369 / 6180 ms | 183 / 7796 ms |
| mean frame | **16.7 ms** | **42.6 ms** |
| worst frame | **82.0 ms** (f10, BEAT 2/3 + SOOT FADE) | **96.2 ms** |
| COMMIT | 97.9 ms | 99.8 ms |
| LIGHT | 34.7 ms | 58.8 ms |
| CONSEQUENCE | 4903 ms | 4918 ms |
| cook | 0 frames | 0 frames |

Run-to-run variance: 369 frames both times, 6180/6186 ms, worst 82.0/83.2.

Three readings that decide where to aim:
1. **The renderer alone costs 2.5×** (16.7 → 42.6 ms), before the phone's own
   hardware. Structural to Compatibility.
2. **The CPU spikes barely move** between renderers (COMMIT ~100 ms both), so
   they scale with the DEVICE's CPU, not the renderer.
3. **`CONSEQUENCE` is a WAIT, not work** — ~4.9 s at frame pace in both. It does
   not get worse on a phone, but it is what makes the event 6–8 s long.
4. **The cook is NOT the cost** when a fuse precedes it (0 frames), but costs
   **14 frames / 222.4 ms** when pre-production is short (direct detonation).
   The original "ms budget scales badly" hypothesis survives only in that form.
5. §7.4/D-7 already fixed the light derive (158 → 17.7 ms); **D-1's 201.9 ms
   worst frame is superseded** — do not reopen it.

## 4. Findings worth carrying

- **An instrument that writes to disk measures its own writing.** The shape gave
  it away: every frame cost ~196–198 ms regardless of which beat it was — a flat
  floor, not a workload curve.
- **`print_debug()` is stripped from an export-release build.** Two reads of
  "boot viewport" were residue from an earlier load in the pane's console buffer,
  which persists across navigations. A per-build tag (`[PROBE7]`) is what proved
  the difference; `print()` is what survives.
- **A hidden Browser pane draws no frames.** It explained, retroactively, a
  `_process` probe that never fired, byte-identical screenshots across different
  builds, and an apparently frozen game. The pane measures the pane.
- **Secure Context is required regardless of `thread_support`.** `thread_support=
  false` removes the COOP/COEP need, NOT the secure-context need, and a LAN
  `http://` IP is never one (only `localhost` is). The HTTPS tunnel is not
  optional for a phone test.
- **Read the pack index, not the preset** (GDPC v3: header → `dir_offset` at byte
  32 → entries). It answered "is the file in the build" four times in one
  session, where a grep of the `.pck` gave false positives.
- **A control experiment is cheaper than a hypothesis.** Forward+ vs
  Compatibility at 1280×720 AND at a true 390×844 portrait produced BYTE
  IDENTICAL captures (md5 `1b8440c3`), which killed both the renderer and the
  canvas-size explanations for the glass bug in one step and left the one that
  was right.
- **A Godot warning had been saying it all along**: *"Loaded resource as image
  file, this will not work on export"* — the engine naming §1's bug, in the log,
  before any of this.

**Every commit:** 52 selftests clean, lint clean, invariants clean, CODEMAP fresh.
`QWEN.md`'s `hud-map` was refreshed twice, as its hook requires.
The local `http.server` was stopped at session end; the ngrok tunnel was the
Director's own, in his terminal.
