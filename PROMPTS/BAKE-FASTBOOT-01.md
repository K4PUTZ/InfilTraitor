# BAKE-FASTBOOT-01 — Env-var bypass to skip baking entirely

**Status:** DONE — implemented and verified
**Plan:** ad hoc (testing-velocity fix, not part of `TOP_TEXTURE_MASTER_PLAN`)
**Plane:** systems only. No rendering, mapping, or bake-pipeline changes.
**Baseline:** tag `verified/v0.6.0`.

---

## CONTEXT

Most headless test boots exercise logic unrelated to facade appearance
(destruction, AI, map correctness) but still pay the full bake cost (cold:
~0.4–1.2 s; warm from disk cache: currently ~0.7 s, see `BAKE-CACHE-01`
follow-ups) because `BakeConfig.enabled` defaults `true` for the facade
calibration phase. Across thousands of test runs this adds up. This prompt
adds a **fast-boot bypass**: an environment variable that forces baking off
regardless of `bake_config.cfg`, independent of and complementary to the
disk-cache speedups (`BAKE-CACHE-PAGESIZE-01`, `BAKE-CACHE-FORMAT-01`) —
implement this one first; it needs neither of the others.

**Design:** `BakeConfig.load_config()` is the single, already-proven
entry point every boot path calls (`room.gd`, every `bake_*_test.gd` tool).
Add an environment-variable check at the top of it: if
`OS.get_environment("INFILTRAITOR_FAST_BOOT") == "1"`, force
`enabled = false` **after** the `.cfg` file is read (so the env var wins over
any local override, including the Director's own `bake_config.cfg`) and
print a loud, unmistakable one-line notice so nobody mistakes a fast-boot
run for a real bake-off test. Nothing else changes: with the flag unset,
behavior is byte-identical to today.

## MODULE

- `godot/scripts/systems/bake_config.gd`

## DO NOT TOUCH

- The `.cfg` file format, other flags, `load_config()`'s file-reading logic.
- Any bake/compositor/lookup/renderer code — this only gates `enabled`.

## TASK

In `BakeConfig.load_config()`, after the existing `.cfg`-file block, add:

```gdscript
if OS.get_environment("INFILTRAITOR_FAST_BOOT") == "1":
    enabled = false
    print("[BakeConfig] ⚡ FAST BOOT — INFILTRAITOR_FAST_BOOT=1, baking forced OFF")
```

## ACCEPTANCE (4)

1. Headless boot with `INFILTRAITOR_FAST_BOOT=1 godot --headless --path . --quit-after 20`
   shows the fast-boot log line and `enabled=false` in the `[BakeConfig]`
   summary print, even though the local `bake_config.cfg` has `enabled=true`
   — paste both boot logs (with and without the env var) side by side.
2. With the flag set, TEXTURES boots with 0 baked hits, all cells via the
   generic material atlas (paste the `render()` summary line) — confirms the
   bypass reaches placement, not just the config flag.
3. Without the flag, behavior is unchanged from `verified/v0.6.0` (paste one
   boot log showing `enabled=true`, baked hits as before).
4. `python3 tools/persistent/project_lint.py` pasted, zero real compile
   errors; version bump; commit + push; completion report appended here.

**Director ratification (post-Operator):** running any test with
`INFILTRAITOR_FAST_BOOT=1` set boots visibly faster and shows flat material
colors, no facade texture — confirms the bypass without needing to time it.

## COMPLETION REPORT

- Implemented the env-var override in [godot/scripts/systems/bake_config.gd](godot/scripts/systems/bake_config.gd) so `INFILTRAITOR_FAST_BOOT=1` forces `enabled = false` after config-file loading, overriding even a local `bake_config.cfg` that sets `enabled=true`.
- Verified the boot logs with and without the flag using headless Godot runs. Without the flag, the loader reported `Enabled: true`; with the flag, it printed the fast-boot notice and `Enabled: false`.
- Verified the placement path with the flag set: the boot log reported `render() summary: 640 slices, 128928 cells placed (0 baked hits, 128928 generic fallbacks, 0 cells with null edge)`.
- Ran `python3 tools/persistent/project_lint.py` successfully; the lint script reported `PASSED — No real compile errors detected`.
- Bumped the project version from `0.6.0` to `0.6.1` in [VERSION](VERSION).
