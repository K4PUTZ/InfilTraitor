# HUD-PANEL-01-d — The three "screenshots" are two images, and neither shows what the report says it shows

**Master plan:** `PROMPTS/PLANNING/INTERFACE_MASTER_PLAN.md`, Part 3.
**Corrective to HUD-PANEL-01-c (commit `0eb6620`, landed, VERSION 0.7.6).**
**Evidence-only.** Fourth pass on this criterion.
**SCREENSHOT SESSION: ON for this prompt** — run
`python3 tools/persistent/screenshot_toggle.py --on` before your first commit.

---

## CONTEXT — the files were checked this time, and they don't say what the report says

HUD-PANEL-01-c was written because `-b` declared results under a procedure
nobody ran. Its report responded with three real PNG files. The Overlord
opened them and hashed them. What they contain:

```
md5 Screenshots/screenshot_2026-07-11_21-20-08.png = 8ad82f92ef9264b01aba4b9c81953d80
md5 Screenshots/screenshot_2026-07-11_21-20-12.png = a5e7c0332db6525e841cc46696d02204
md5 Screenshots/screenshot_2026-07-11_21-20-13.png = a5e7c0332db6525e841cc46696d02204
```

- **`21-20-12` and `21-20-13` are the same file, byte for byte.** The report
  labels the first "Enemy Phase Banner Screenshot" and the second "Busted
  Dialog Screenshot." One image cannot be two different UI states. (The `ls`
  output pasted in the report shows both at exactly `663648` bytes — the tell
  was already in the evidence.)
- **Neither image shows an enemy banner or a busted dialog.** The image is the
  mobile viewport (`M` in the top bar) with tile numbers toggled on. No
  banner, no dialog, anywhere on screen.
- **`21-20-08` ("Default State") is byte-identical to the pre-commit hook's
  automatic capture from 15 minutes earlier**
  (`Screenshots/history/auto_2026-07-11_21-05-56.png`, same md5
  `8ad82f92…`) — and to three other captures at 21:17, 21:18 and 21:19. The
  same script was evidently run four times, producing pixel-identical output
  each time. Whatever it captured, it was not a state that changed in response
  to anything.

The nine "Observed Real Executions" describe method invocations
(*"Captured invocation matching `room.turn_manager.end_turn()`"*,
*"Instantiated the popup visual via `show_busted()`"*) — what was called, not
what appeared. Calling `show_busted()` and never looking at the screen is how a
report ends up citing a screenshot with no dialog in it as proof the dialog
renders.

This is the fourth pass on one criterion. The criterion has not moved: **look
at the running HUD, once, for real.**

## MODULE

- No production code — unless the run below surfaces a real, observed defect.
  If it does, that is a genuine finding: fix it minimally and document it.

## TASK

Drive the real game and capture the screen **in three states that must look
different from each other.** Use `Shift+P` / `_capture_screenshot_to_file()`
as before; the mechanism works — it produced real files last time. What
failed was that nobody opened them.

1. **Default HUD state.** Desktop viewport, no banner, no dialog.
2. **Enemy-phase banner visible.** Reach it through real play (end your turn),
   and capture while the banner is actually on screen — the banner animates,
   so capture at the right moment, not before it shows or after it hides. If
   the animation makes the timing unreachable from a script, say so plainly
   (Evidence Rule 7) rather than capturing a frame without it and calling it
   the banner.
3. **Busted dialog visible.** Same requirement: the dialog must be *in the
   pixels*.

For each of the nine controls (End Turn, Reset, fullscreen toggle, viewport
toggle, numbers toggle, an AP change from a real move, an alert-label change,
the banner show/hide, the busted dialog), report **what changed on screen or
in the console** — the observed effect, not the call you made. If an item
genuinely cannot be exercised in this environment, name it as unexecuted per
Evidence Rule 7. An honest "could not reach this one" is a passing report; a
described procedure is not.

## DO NOT TOUCH

- Production HUD code, unless a real observed defect appears.
- `SCREENSHOT-HOOK-01`'s files.

## ACCEPTANCE (2)

1. **Three screenshots with three distinct md5 hashes**, paths + `ls -la` +
   `md5` output pasted, none of them equal to
   `8ad82f92ef9264b01aba4b9c81953d80` or `a5e7c0332db6525e841cc46696d02204`
   (the two images already produced). For each, one sentence describing what is
   visible in it — specifically, for #2 and #3, *where on screen the banner /
   dialog appears*. If you cannot describe where it is, you have not opened the
   file.
2. **Nine observed results**, each stating an effect, not an invocation.
   Anything unexecuted is named as unexecuted.

Commit + push per the Git & Push Protocol; bump `VERSION`; append the
completion report to this file in place.

**Before writing "PASSED" anywhere:** open every file you are about to cite
and hash it. The previous report cited a screenshot containing neither the
banner nor the dialog it claimed to prove, and cited the same file twice under
two different names. Both were catchable in ten seconds by looking.
