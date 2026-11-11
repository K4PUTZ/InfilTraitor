# Session 2026-09-09 — the workspace split becomes real

Previous session:
[`RESUMO_SESSAO_2026-09-07_SHOCKWAVE_AND_THE_STALE_WORLD.md`](RESUMO_SESSAO_2026-09-07_SHOCKWAVE_AND_THE_STALE_WORLD.md).
**No engine work happened.** The session opened as a resume and turned into the
whole of the two-workspace split — asked for, in the Director's words, so that
*"o que for feito lá não vai interferir aqui com nosso processo da engine"* and
so he could *"trabalhar em cada um separadamente, mas rodar o mesmo projeto do
Godot e conferir as mudanças sem interferir uma na outra."*

Seventeen commits across THREE repositories (`InfilTraitor` main and
`feat/design-interface-hud`, and the separate `JAMES` repo). The engine's two
standing debts — the G-D48 ramp calibration and opaque-wall passages — are
untouched and still open.

---

## 1. ⛔ RESUME POINT

**The engine is where it was on 2026-09-07.** Nothing in this session touched
gameplay, rendering or physics. The two open items are unchanged:

- **The G-D48 ramp values are placeholders** awaiting on-screen calibration.
  `INFILTRAITOR_GLASS_RING_DIAG=1` prints per-pane ring / probability / outcome.
- **Opaque-wall passages are not wired for MOVEMENT.**
  `build_movement_edge_set()` still asks `PassageQuery` about GLASS edges only.

New, from this session, and the Director's to decide:

- **A Resume button is the one thing genuinely outstanding in the interface**
  (§4.2). Everything else in `INTERFACE_MASTER_PLAN` § Part 4 already ships.
- JAMES's `ask: ["Edit"]` still confirms every file edit. Not raised; noted.

---

## 2. What was built — the split, in five gates

| | |
|---|---|
| **Gate 0** `check_design_scope.py` | Pre-commit. **The single authority** for the design branch's path list — docs call `--list` rather than restating it. Blocks engine files on a design branch; only WARNS about UI files on `main`, because the Director works there. Merges are exempt: a sync is not authorship. |
| **Gate 0.5** `hud_map.py --check` | Pre-commit, only when `hud.tscn` is staged. Keeps `QWEN.md`'s generated HUD map from rotting into a confident lie. |
| **L3** `hud-widget-behind-the-facade` | `check_invariants.py`. Only `hud_controller.gd` may name a HUD widget. |
| **pre-push** | A design branch may push only itself, read off the REFS being transferred. |
| **`hud_seam_selftest`** | 16 checks against the REAL `hud.tscn`. |

**Re-verified end to end at session close, six for six:** Gate 0 blocks
`room.gd` and passes `panel_base.gd`; L3 catches `_room.btn_view_h`; pre-push
refuses `HEAD:main` and accepts the branch; Gate 0.5 catches a one-word scene
edit; the seam selftest is green; both trees clean.

### The code that made it possible

**UI-SPLIT-01 — the HUD is its own scene.** `godot/scenes/ui/hud.tscn` holds the
CanvasLayer and its 24 nodes; `room.tscn` instances it in one line and fell from
254 to 77. No script changed, deliberately: node paths resolve through an
instance, so the blast radius was two scene files.

**UI-SPLIT-02 — the engine stops naming widgets.** `hud_controller.gd` became
the seam and DESIGN owns it. `room.gd` lost 21 `@onready $HUD/...` lookups and
all 25 uses; `camera_controller` stopped fetching seven buttons; `vision_` and
`debug_tools_controller` now ask instead of poking. **JAMES can restructure
`hud.tscn` freely and only update `setup()`.**

---

## 3. ⚠️ THE FINDINGS worth carrying

### 3.1 A gate must be exercised on its FIRST REAL WORKFLOW, not just its violation case

Both defects in `check_design_scope.py` were found by using it, and each would
have made it actively harmful:

- It **refused the design branch's own sync merge from `main`** — a merge stages
  every engine file that changed, indistinguishable from the violation it exists
  to block. Exempt via `MERGE_HEAD` now.
- `--against main` read a **LOCAL `main` seven commits stale** (nobody ever
  checks it out) and called 36 already-merged files violations. A confident
  wrong answer is worse than no answer.

And L3's first version **caught only one of the two shapes it claimed**: there
is no word boundary between the `_` of `btn_` and the `v` of `btn_view_h`. It
passed the clean tree, which proved nothing.

### 3.2 Two documents at one path is a merge conflict with a delay

Tracking `.README_WORKSPACE.md` on both branches put two DIFFERENT documents at
one path — an add/add conflict guaranteed on first contact, which `merge-tree`
confirmed before it fired. **Fixed by making it ONE document describing both
sides, identical on both branches.** The same reasoning is why JAMES's charter
is `QWEN.md`, a distinct path, rather than a design-flavoured `CLAUDE.md`.

### 3.3 A stale status line is not cosmetic when an agent will act on it

`INTERFACE_MASTER_PLAN` said Wave 3 was "not started". It shipped **2026-07-15**
in `28cb79ad` as `main_menu_panel.gd` — whose own first line says so. Escape
already opens it and pauses; closing it by any path unpauses, because `room.gd`
hangs that off the panel's `closed` signal rather than the keypress.
`JAMES_WORKFLOW.md` went further and handed him an implementation sketch for
`pause_menu_panel.gd`. Following either, his first act would have been to
rebuild a shipping menu and leave two competing for Escape. Corrected in the
plan (v1.1), the workflow doc, and `QWEN.md`.

### 3.4 Write for the context the reader actually has

JAMES runs a 9B model in **32 768 tokens, auto-compacting at 0.65**. Measured:
~3 400 load before his first prompt; `INTERFACE_MASTER_PLAN.md` costs **~5 000 —
a sixth of his window**; `hud.tscn` ~1 340. So `QWEN.md` carries a **generated**
~250-token map of the HUD's node tree and geometry, and the common layout edit
costs him nothing to look up. Generated, because a hand-kept map of a scene
someone is actively editing is a lie with a delay — hence Gate 0.5.

### 3.5 The cross-file trap, avoided by obeying the rule already written down

`toolbar_row` and `perspective_pad` appear ONCE each in `room.gd` — the
declaration — and look dead. They are written from `debug_tools_controller` and
`vision_controller`. Deleting them would have repeated 2026-07-12 exactly.

### 3.6 A test can be wrong about innocent code

`hud_seam_selftest` failed its first run on the two new signals and the
controller was innocent: **a GDScript lambda captures a local BY VALUE**, so the
listener wrote to a copy. Red-before-green was then proven properly, by
disabling the real wiring and watching the suite fail.

---

## 4. Also this session

### 4.1 Screenshots — 3.6 GB to zero

Director ruling: *"o material realmente importante está em REFERENCES. Os
screenshots são só isso mesmo, screenshots."* Audited before deleting: all 164
captures still cited by live docs were **receipts** — proof a measurement
happened, beside a ruling whose decision is in the prose. Only 8 of ~517
mentions were real markdown links; demoted to backticks, zero dead links.
`DIAGRAMS/` (28 files, 116 MB) entered git in the same pass — the global
`*.psd`/`*.png` rules had been swallowing it silently.

### 4.2 What JAMES has now

His charter is `QWEN.md` (auto-loaded; `--system-prompt` does not suppress it),
his system prompt was rewritten, and he **can push his own branch** —
`approvalMode: "default"` plus an explicit allow, since `ask` outranks `allow`
and `Bash(*)` had made every allow entry dead. `JAMES/docs/DESIGN_ROLE.md` is
the Director's operating manual; nothing in that repo reaches JAMES's context,
because it is a sibling of the workspace, not an ancestor.

**Wave 3 is inside his scope end to end** — `ui_pause` exists,
`input_controller.gd` already emits `pause_requested`, `modal_stack`,
`panel_base` and `window_base` are his, and a menu can be instanced into
`hud.tscn`. He needs the engine for none of it.

---

## 5. Inventory

| | |
|---|---|
| `tools/persistent/check_design_scope.py` | Gate 0; `--list`, `--against <ref>`, `--is-design-branch` |
| `tools/persistent/hud_map.py` | Gate 0.5; `--check` against `QWEN.md`'s snapshot |
| `godot/scripts/tools/hud_seam_selftest.gd` + `.tscn` | 16 checks, real scene |
| `CLAUDE.md` | Rule **11** (the seam), Engine-Only, the screenshot ruling |
| `.README_WORKSPACE.md` | One charter, both sides, identical on both branches |
| `QWEN.md` | JAMES's charter + the generated HUD map |
| `INTERFACE_MASTER_PLAN.md` | **v1.1** — Wave 3 corrected |
| `JAMES/docs/DESIGN_ROLE.md` | The Director's manual for operating JAMES |

**Every commit:** 52 selftests clean, `project_lint.py` clean,
`check_invariants.py` clean, CODEMAP fresh.
