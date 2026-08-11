# RESUMO_SESSAO — 2026-08-10/11 (Alpha Bubble Foundation)

**Continues:** `PROMPTS/DONE/RESUMO_SESSAO_2026-08-10_GRENADE_TARGETING_FOUNDATION.md`
**VERSION:** 0.9.95 → **0.9.96**
**Commits:** 9, `6af2767`–`ea5fe56`, plus this checkpoint.
**Plan:** `PROMPTS/PLANNING/TARGETING_MASTER_PLAN.md` — now 🟢 BUILT, §6 carries
what is left.

---

## The one-line version

The grenade aiming UI is a real, working chain — G → aim → tap or Enter → arc →
bounce → cook → detonation — and it **did not run at all** when the session
started. Everything below either fixed something that was silently inert or was
built on the Director's direct notes across six rounds of review.

---

## What the session opened on

The previous session reported "Phase B targeting UI fully functional", `34/34
selftests clean`, and closed. The audit that started this session found:

| Reported | Actual |
|---|---|
| Throw works | `SceneTree.get_physics_frame()` does not exist in Godot 4.6 — the coroutine aborted on its first iteration, so **no throw ever detonated** |
| ESC cancels targeting | `ui_pause` is also ESC and returns first — ESC opened the Main Menu mid-aim |
| Enter throws | Claimed unconditionally in `_input()`, which runs before GUI input — this **killed the context menu's focused button**, and with it the `test_zone_detonate` capture |
| Bubble sized from the bomb | Sized from the THROW RANGE, and drawn as a circle over a 2:1 ellipse |
| Clamp keeps the target in range | Preview clamped; `execute_grenade_throw()` re-read the RAW hovered cell |
| 34/34 selftests clean | 33 + `detonation_choreographer_selftest` failing deterministically since `[E-FUME]` |

Every one was reproduced before being fixed, and the two that a screenshot could
show got red/green captures from the same binary.

---

## Built

**`IsoProjection`** (`godot/scripts/world/utilities/iso_projection.gd`) — one
analytic home for "a shape in GAME UNITS, drawn on the isometric plane". Its
basis is MEASURED against `tileset_blocks.tres`, not reasoned from Godot's
layout enum, and `iso_projection_selftest.gd` (24 assertions) checks it there —
a self-comparison would pass whatever the constants said.

The results everything else leans on:

    off-diagonal of M·Mᵀ = 0        → every ellipse is screen-axis-aligned
    floor circle  → (181.02, 90.51) px/GU   exactly 2:1
    sphere        → (181.02, 183.83) px/GU  very nearly a circle
    normalised radius == (grid distance / R)²  in every direction

| Piece | What it is |
|---|---|
| **Dome** (`AimBubbleOverlay`) | A 2 GU hemisphere: the sphere ellipse closed underneath by the floor section, which share a horizontal semi-axis so the seam is exact. Orange. At exactly 2.0 the rim passes through the cells two out — the spill is the message |
| **Shrapnel rays** (`ShrapnelPreviewOverlay`) | LightRayOverlay's mechanism pointed at a grenade. Directions from the SAME wall-aware BFS the blast floods with; endpoints on an ellipse so lengths are even; lifted origin, ground braking, deterministic jitter |
| **Perimeter** (`ThrowPerimeterOverlay`) | The projection of a 7 GU grid circle. Whole number on purpose — cell centres only sit at integer offsets |
| **Affected GUs** (`BlastWireframeOverlay`) | Graded red fill per blast ring, MovementOverlay's own mechanism. Zero-damage rings excluded by data, not by a hardcoded −1 |
| **Virtual grenade** (`TargetCursorOverlay`) | `GrenadeProp`'s real baked frames + `virtual_grenade.gdshader` (50% overlay, 2 px stroke, 2 px diagonal hatch) |
| **Throw** (`ThrowArcOverlay` + controller) | A real ballistic arc with launch height, a flight tumble, a landing hop, and a 1 s cook — one continuous angular motion from release to rest |

**Dev vs. player:** both reds are dev-vision-only. The player's HUD shows the
dome, the rays, the virtual grenade and the arc.

---

## Verification

    project_lint.py          ✅ 204 files, 0 errors
    iso_projection_selftest  ✅ 24 PASS / 0 FAIL
    check_invariants.py      ✅ OK
    gen_codemap.py --check   ✅ OK
    run_selftests.py         34 clean, 1 failed (pre-existing, see below)

Hand-named captures, so the 50-file rotation cannot eat them:
`grenade_aim_dome.png`, `grenade_aim_gameplay_hud.png`, `grenade_aim_wide.png`,
`grenade_virtual_cursor.png`, `grenade_flight_tumble.png`,
`grenade_throw_cooked.png`, `grenade_menu_detonate.png`, and the red/green pair
`grenade_throw_before.png` / `grenade_throw_after.png`.

New dev capture actions: `grenade_aim`, `grenade_throw`, `grenade_cancel`,
`grenade_tap`, `grenade_second`; modifiers `INFILTRAITOR_CAPTURE_AIM_CELL="x,y"`
and `INFILTRAITOR_CAPTURE_NO_DEV=1`. The last one matters more than it looks:
`dev_vision` defaults TRUE in this build, so before it the harness had never
once captured the player's own HUD.

---

## Where it stops

Two items were being worked when the session closed, both specified and both
written up in full in `TARGETING_MASTER_PLAN` §6.1:

- **The grenade's ground shadow** — `object_ground_shadow.gdshader` is written
  and documented; **nothing references it yet**. Four wiring steps listed.
- **The settle roll is still quantised** at 1/16 and 1/32. The friction model
  that frees it is derived in the plan; the ease-out profile does not change,
  only where its two numbers come from.

Neither leaves the tree broken — the shader is inert and the roll works, it is
just not yet free.

---

## Found, not fixed — both belong to the blast work, not to this plan

- **`detonation_choreographer_selftest` fails deterministically.** 91% of the
  front on one frame. Cause proven red/green: `[E-FUME] 20334c3` pulled soot out
  of `WAVE_TABLE`, taking 546 of 949 steps out of the paced queue. Putting those
  four rows back gives 10 PASS / 0 FAIL and a 53.7% heaviest frame.
- **E-FRAG's post-blast debris has never fired.** `shrapnel_overlay.gd:49` calls
  `VoxelRenderer.cell_level_to_world()`, which does not exist;
  `debug_ray_overlay.gd:45` makes the same call. Dates to `0c728c6`, confirmed
  pre-existing by stashing this session's work and reproducing at `71c60af`.

---

## The lesson worth keeping

Every defect this session opened with was invisible to `project_lint.py`, to the
selftests, and to a screenshot of the aiming UI — because they were all in code
paths nothing ran end to end. The fix that made the rest possible was building
capture actions that drive the REAL input path (`G` → `_input` → hover → Enter
→ detonation) and then reading the console, not the picture. `grenade_second`
exists because a capture of ONE throw can never show a bug in the second one.
