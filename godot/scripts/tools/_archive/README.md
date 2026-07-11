# _archive

Retired scripts, kept for historical reference per `docs/technical/archive_policy.md`.
Not part of the lint/test suite; not referenced by any live code.

## baked_tile_lookup_test.gd / block_01b_baking_e2e_test.gd

**Retired:** 2026-07-11 (Baking System milestone closure, Overlord cleanup pass).
**Era:** BAKE-05 / BLOCK-01b, pre-dating the continuous-plane facade model
(OVERLORD-FIX-01, 2026-07-10).

Both scripts test API shapes that no longer exist:
`baked_tile_lookup_test.gd` calls `_make_bake_key()` (superseded by the
`_compute_facade_key()` per-direction sheet addressing) and constructs a
`MockMaterialAtlas` missing the `has()` method the current lookup expects;
`block_01b_baking_e2e_test.gd` reads `BakedAtlas.pages` — a field the current
`BakedAtlas` (which has `atom_pages`, `page_modulates`, `lookup`) never had.
Both crash with `SCRIPT ERROR` on run. Neither was wired into
`project_lint.py`, `check_invariants.py`, or any CI gate — they were dead
weight in `godot/scripts/tools/`, not a safety net silently failing.

Current coverage of the same subsystems: `bake_fix_02_test.gd`,
`bake_fix_09_e2e_test.gd`, `bake_fix_11_pixel_diff_tool.gd`,
`bake_fix_12_facade_2d_test.gd`, `bake_selftest.gd`, `bake_cache_test.gd` —
all green as of the Baking System milestone close
(`docs/technical/BAKE_SYSTEM_REFERENCE.md`).

Rewrite against the current `BakedTileLookup`/`BakeCompositor` API if this
coverage is ever needed again; do not un-archive as-is.
