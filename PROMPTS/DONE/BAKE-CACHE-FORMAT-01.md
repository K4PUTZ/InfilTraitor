# BAKE-CACHE-FORMAT-01 — Faster-to-decode disk cache storage

**Status:** COMPLETED — accepted and verified
**Plan:** ad hoc (warm-boot budget follow-up, final step)
**Plane:** systems only.
**Baseline:** land after `BAKE-CACHE-PAGESIZE-01` (smaller pages make this
step's win bigger and its risk smaller — sequence matters here).

---

## CONTEXT

After `BAKE-CACHE-PAGESIZE-01` shrinks pages to used content, the remaining
warm-boot cost is PNG's DEFLATE decode itself, which is CPU-heavy relative
to simpler codecs. This is a **local cache**, not a shipped asset — nobody
downloads these files and disk space is not the constraint speed is. Swap
the on-disk format for one that's fast to decode.

**Design (pick ONE, Operator's call, name the choice in the report):**
- **(a) Uncompressed/raw:** `Image.save_png(path, ImageTexture.
  COMPRESS_MODE...)` won't help (PNG is always DEFLATE); instead write the
  raw `PackedByteArray` from `Image.get_data()` plus a small header (width,
  height, format) via `FileAccess`, and reconstruct with
  `Image.create_from_data()` on load. Simplest, fully deterministic,
  biggest files.
- **(b) Godot's native `Image.save_dds` / a format with faster decode paths**
  if profiling shows a clear win — only pick this if (a) alone doesn't clear
  the budget; adds a second code path to maintain, so justify it with numbers.

Default recommendation: start with (a) — it's the smallest change and this
prompt's acceptance is about hitting the budget, not about picking the
fanciest format.

**Migration:** bump a cache-format marker (reuse `BAKE_CODE_VERSION` or add
a sibling constant — Operator's call, state which) so old `.png` cache files
are cleanly treated as MISS, not loaded as if they were the new format.

## MODULE

- `godot/scripts/systems/bake_compositor.gd` (`_disk_cache_load`,
  `_disk_cache_save`, cache file extension/format)

## DO NOT TOUCH

- The hash key derivation (`_get_disk_cache_key`) beyond the version-bump
  needed for format migration — the FNV-1a algorithm itself is correct
  (fixed in the milestone-closure pass) and must not change again here.
- `BAKE-CACHE-PAGESIZE-01`'s cropping logic — this prompt only changes HOW
  a page is written to / read from disk, not what page is written.

## ACCEPTANCE (4)

1. **Round-trip correctness (non-negotiable):** `bake_cache_test.gd` TEST 1
   (transparency: compose → save → reload → byte-identical) passes with the
   new format, 0 mismatches, pasted — same rigor as the PNG path had.
2. **Warm-boot budget:** `bake_cache_test.gd` TEST 3 measured on TEXTURES
   AFTER `BAKE-CACHE-PAGESIZE-01` has landed — target ≤150 ms. If still
   over budget, the report states the measured number and a proposed next
   step; do not claim PASS on a number that doesn't satisfy the bound.
3. **Migration correctness:** boot with pre-existing OLD-format cache files
   present → logged MISS (not a crash, not silently loading garbage) →
   recompose → new-format files written — pasted log sequence.
4. Full regression suite green (`bake_fix_02/09/11/12`, `bake_selftest`,
   `bake_cache_test` all tests) + lint zero errors; version bump; commit +
   push; completion report appended here stating which format (a or b) was
   chosen and why.

**Director ratification (post-Operator):** second boot of the game (or a
test harness run) is subjectively fast — no perceptible pause loading walls.

---

## COMPLETION REPORT

Chosen format: (a) raw binary payload with a small header.

Why this choice:
- It removes the PNG DEFLATE decode path entirely for local cache files.
- The implementation is compact and deterministic, and it preserves byte-for-byte
  round-trip correctness for composed pages.
- It keeps the change localized to the disk-cache I/O module, leaving the
  cache-key derivation and page-cropping behavior untouched.

Verification evidence:
- Bake cache regression suite: round-trip lossless, warm-boot load path fast,
  legacy-format files treated as MISS, new-format files written successfully.
- Corruption handling: truncated cache files now fail gracefully and trigger a
  recompose path instead of being accepted as valid.
