# RESUMO_SESSAO — 2026-07-18 (ROOF OCCLUSION + WIREFRAME/SCREENSHOT FIXES)

**Active master plan:** `PROMPTS/PLANNING/DESTRUCTION_MASTER_PLAN.md` —
still **PAUSED at Alpha Horizontal Bake Foundation** (this session was the
Director's roof-occlusion feature request plus two reported bugs).
**VERSION at session start:** 0.9.59
**VERSION at session end:** 0.9.62
**Mode:** Solo mode.
**Screenshot session:** never toggled ON; all captures via direct off-screen
runs with `INFILTRAITOR_CAPTURE_*` env vars.

---

## Executive Summary

Three deliverables, all landed with real-capture evidence: (1) the
Screenshots folder "cap overflow" was diagnosed as Godot `.import` sidecars —
fixed with a `.gdignore` (the editor now ignores the whole tree; files stay
on disk); (2) the Director's "wireframe 3–4 px up" was measured with
erase-diff forensics to be a **roofline seam**, not a wireframe offset — the
wall-column erase ran to the top of every layer and ate the roof's border
row; capped at the edge's own `max_level` (OCC-26); (3) **roof occlusion**
(ROOF-OCC-01): roofs now ghost in screen-horizontal GU stripes with ring
falloff, small roofs vanish entirely into a full-shape wireframe.

## Wave table

| ID | What | Status |
|---|---|---|
| SCREENSHOT-HOOK-03 | `.gdignore` in `Screenshots/` — editor skips the tree, no more `.import` sidecars; cap of 50 was already working; stable N/E/S/W names already exist (`occ_view_*.png`) | ✅ `cc0951c` (0.9.60) |
| OCC-26 | Wall occlusion erase stops at the edge's own top: `max_level` travels with each occluded cell; junction columns too; spared roof border row kills the ~4-px roofline seam | ✅ `c01f1a6` (0.9.61) |
| ROOF-OCC-01 | Roof occlusion: stripes of constant `gu.x+gu.y` (screen-horizontal), ring = depth distance from agent/hover, MAX_RING window; components ≤ 5 stripes ghost whole; trigger = containment OR wall-coupling; wireframe = one box per roof GU reusing the wall segment dict (overlay untouched) | ✅ (0.9.62) |

## Decisions (Director-ratified)

1. **Stripe orientation:** screen-horizontal (constant `gu.x + gu.y`,
   anti-diagonal in grid space) — chosen over axis-aligned GU rows when
   asked explicitly (AskUserQuestion, this session).
2. Solo-mode decisions surfaced in the commit body (trigger design,
   small-roof threshold = 5 stripes, per-GU box wireframe): implemented as
   the faithful reading; Director to ratify in play.

## Key forensic findings (worth keeping)

- **The wireframe was never offset.** Erase-diff capture pairs (same agent
  cell, occlusion on/off) measured the wireframe pixel-aligned with the
  erased wall silhouette: median delta 0 px at the base, in views N AND W.
  The perceived 3–4 px was the roofline seam (see OCC-26). Method: the
  erased-silhouette boundary is the ground truth the wireframe must hug.
- **Camera renders at 0.5 zoom** in these captures: 1 screen px = 2 local
  px. Any "N px" visual report should be doubled before hunting constants.
- **Voxel-layer screen formula** (verified by probe): `map_to_local(c) =
  ((cx−cy)·16 + 16, (cx+cy)·8 + 8)` local; layer y offset `−20·level`.

## New capture instruments (all env-gated, zero cost otherwise)

- `INFILTRAITOR_OCC_DISABLE=1` — force empty occlusion set (opaque pair).
- `INFILTRAITOR_WF_HIDE=1` — hide only the wireframe overlay.
- `INFILTRAITOR_CAPTURE_REVEAL_RADIUS=N` — widen FOW reveal for teleported
  captures on big maps.

## Testing evidence

| Check | Result |
|---|---|
| `project_lint.py` | 0 real compile errors, every commit |
| OCC-02 ghost round-trip (roof cells in set) | IDENTICAL, all 4 views |
| `roof_slab_selftest` | 15/15 |
| `slab_render_selftest` | 8/8 |
| `roof_integration_selftest` | 5/5 |
| `occlusion_set_test` | **3/5 — PRE-EXISTING stale** (same result at session-start commit `1369827`); its synthetic scenario predates the OCC-08 trigger redesign; not touched (scope) |

Visual (real captures in `Screenshots/history/`):
`auto_2026-07-18_21-39-35` (concrete tower as full glass box, view N),
`occ_view_W` (rotated: erased roof grid + intact east walls showing their
inner faces through the volume), `auto_2026-07-18_20-39-05` (OCC-26
roofline seam closed), `auto_2026-07-18_21-42-22` (PLAYGROUND large-roof
partial reveal — numeric: 778 cells / 14 segments = 10 of 20 roof GUs;
scene is lighting-dark and the field sits off-frame, flagged below).

## Open items carried forward

- **Director to ratify in play:** stripe reveal feel on a real large roof
  (no map in the catalog currently has a > 5-stripe roof near the fixed
  camera's frame; PLAYGROUND's 4×5 field is off-frame and unlit — consider
  a TEXTURES-style test map with one large roofed structure).
- `occlusion_set_test.gd` is stale (3/5, pre-existing) — needs a rewrite
  against the OCC-08 edge-trigger model when a test wave comes up.
- Wall-coupling triggers the roof of ANY structure whose walls ghost; if a
  tall unroofed-interior building should keep its roof until the agent is
  close to the roofline itself, that's a tuning conversation.
- Junction mirror on fine textures + ART-01 gating: unchanged from
  2026-07-18 SLAB BAKE session.
