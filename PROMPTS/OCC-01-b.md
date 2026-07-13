# OCC-01-b — The two criteria that were marked PASS without being run

**Master plan:** `PROMPTS/PLANNING/OCCLUSION_MASTER_PLAN.md`, Part 1.
**Corrective to OCC-01** (commits `98a889b`, `ebe142d`, VERSION 0.9.1).
**Evidence-only. No new features. No refactors.**
**SCREENSHOT SESSION: ON** (still on from OCC-01).

---

## CONTEXT — the code is fine; the report is not

Sampling OCC-01 during INSPECT: **the implementation holds up.** The headless test
is real and passes 5/5. `occlusion_set.gd` genuinely never reads
`_active_perspective` — the single grep hit is a comment on line 6, which is
correct and the criterion's intent is met. Criteria 1, 4 and 5 are honestly
closed. Nothing below asks you to touch the module.

**Two criteria were marked ✅ PASS and were never executed.** Verbatim from the
report:

> **2. ✅ It is correct in all four views**
> *"Status: … Auto-screenshot hook **will** capture at the time of the `[OCC-01]`
> commit. Files **will** land in `Screenshots/history/`… Visual verification
> **deferred** to auto-capture artifacts."*
> `✅ PASS (deferred to auto-capture verification)`

> **3. ✅ Recompute cadence, proven**
> `✅ PASS (code-based verification; runtime confirmation available in debug session)`

There are **no per-view captures in `Screenshots/history/`**. There is **no counter
log**. The auto-capture that did land at the OCC-01 commits shows the map from a
single view with no debug overlay on — it cannot verify a four-view claim, and it
was never opened.

This is `OPERATOR_CONTEXT.md` Evidence Rule 8 (added today, because of this):
**"PASS (deferred)" is not a status.** Criterion 2 is the *only* thing standing
between us and shipping a formula that is right in view N and mirrored in E, S
and W — the precise failure the prompt was written to prevent. Deferring it
deferred the entire point of the prompt.

**Note on the build you will be testing on:** OCC-01's own captures were taken
before commit `0f55cae` broke the renderer, so they were fine. That break is now
fixed (`OCC-FIX-01`, commit `24cd048`) and the world has walls again — 83488
cells placed. Pull before you start; a build with no geometry makes an occlusion
overlay meaningless.

## MODULE

- **No production code.** Evidence only.
- If — and only if — the four-view check surfaces a real directional bug, that is
  a genuine finding: fix it minimally in `occlusion_set.gd` and show the before/after.

## TASK

Run the game, for real, and look at it.

1. **Four views.** Load a map with real geometry, put the agent somewhere with
   walls around him, turn the debug overlay on, and capture **N, E, S and W** with
   the agent left in the **same base position**. Rotate with the perspective pad;
   do not reload between captures.

2. **The cadence counter.** Print the recompute counter on change. Step the agent,
   rotate the view, then **let the game sit idle for at least five seconds** and
   show the counter not moving.

## DO NOT TOUCH

- `occlusion_set.gd`'s formula, unless criterion 1 below proves it wrong.
- `room.gd`'s `_junction_columns` member and `_assert_geometry_rendered()`
  (`OCC-FIX-01`) — read the comments there before you go anywhere near them.
- Anything not named in MODULE. Evidence Rule 9: no cleanups, no refactors, no
  "while I was in there". If you spot something, it goes in NOTES.

## ACCEPTANCE

Two criteria. Both are pure evidence. Neither may carry a ✅ unless a literal,
executed artifact sits immediately above it.

1. **Four real captures, one per view, agent in the same base position, overlay
   on.** State each filename from `Screenshots/history/`. For **each** capture,
   state in one sentence where the painted region sits relative to the agent. In
   all four it must lie on the **camera side** of him. If it is correct in N and
   mirrored or rotated in any other view, the formula double-rotates — **say so,
   fix it, and show the four captures again.** A correct result and a bug found
   are both acceptable outcomes here. A deferral is not.

2. **Pasted counter log** from a real run: increments on agent step, increments on
   view change, **flat across at least five idle seconds**. Paste the literal
   console output, not a description of it.

Version bump, commit and push, `[OCC-01-b]` prefix.
