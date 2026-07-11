# TOP-JUNCTION-03 — Junction tops from the X-leg's T

**Sequence: after TOP-CROP-02 is Director-ratified. Smallest prompt of the
series.**

---

## CONTEXT

Junction columns already continue each leg's SIDE planes
(`_compose_junction_pages`, OVERLORD-FIX-02). Their tops still use the flat
diamond. Per D-TT2 the junction top may continue either leg — canon choice:
the **X-axis (dir 0) leg**, using its T with the junction's projected column
(`col_x`) as u₀ and the level band as v₀ — the same crop formula as
TOP-CROP-02, same diamond mask, no new geometry.

## TASK

Add the T crop to `_compose_junction_pages` (replacing the flat diamond when
`facade_tops` is true; `false` stays bit-identical).

## ACCEPTANCE (3)

1. Junction-atom top pixels match the X-leg T crop byte-exactly for ≥ 4
   junctions × ≥ 8 pixels each (compare against `_get_plane_top` output
   directly — same-source identity, 0 mismatches, pasted).
2. Baseline suite green (one-line results) + `BAKE_CODE_VERSION` unchanged
   OR bumped consistently if junction pages are cached (they are not —
   state which and why in one line).
3. Report appended HERE; lint; commit + push.

**Director visual gate:** V corners on TEXTURES show tops flowing through
the junction without a flat diamond interrupting the slab.
