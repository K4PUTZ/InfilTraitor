# RESUMO_SESSAO — 2026-08-17 (o bracket branco, o PLAYGROUND reformado, e o ciclo que nunca vazava)

**Version:** 0.9.104 throughout — no bump asked for, no tag.
**Commits:** 4, all pushed. `4da541d4` · `66253137` · `09470ab9` (a fourth,
untagged CODEMAP-only commit landed with this file — see below).

---

## The one-line version

Started from two Director requests — the §6c wall-shot wave and a drastic
white-clothing test for the enemy — and neither got finished. What landed
instead: a three-iteration white bracket (documented, not shipped), a
PLAYGROUND reform (bigger board, bench/grenades retired), and — the real
find of the day — a **structural Slab↔Voxel reference cycle** that Godot can
never free on its own, masked for months by a disk cache that never missed.
§6c is still first in the queue next session.

---

## 1. What shipped

| | |
|---|---|
| **White palette bracket** | `test_white` in `p1_agent_model.py::PALETTES` — bracket only, not a faction. Three real in-game iterations (v1 flat, v2 brighter + 12 pinstripes, v3 isolated light response). `AgentSprite` gained `LIGHT_RESPONSE_OVERRIDE`, keyed per `frame_family`, so a future bracket can tune light response without touching the agent's or shipped enemy's own values. |
| **PLAYGROUND reform** | Board 24×16 → 44×22. Weapon bench and floor grenades retired from `room.gd::_populate_test_zone_if_playground()` — testing moves to the agent himself (§6c). A light added over the guard's patrol cell. brick/cardboard/fabric/glass reserved as open floor, none built as real blocks. |
| **The glass demotion** | Glass looked ready (`BASE_MATERIALS`, resistance table, wall/floor render) but placing it as a real block failed `roof_bake_selftest.gd`: 520/2600 roof voxels with no baked lookup entry — no roof facade authored. Pulled back to reserved, same as the other three, rather than shipped half-working. |
| **The audit** | `PROMPTS/AUDITS/ROOF_BAKE_LEAK_2026-08-17.md` — full writeup of the Slab↔Voxel cycle, the false leads ruled out, and two unbuilt fix shapes (narrow vs. structural). |

---

## 2. Two guesses that were wrong, and I said so before building on them

1. **"It's the two-builds-in-one-process pattern."** `roof_bake_selftest.gd`
   builds PLAYGROUND twice (N then E view) with no frame-wait between them —
   looked like the obvious cause. Added `await process_frame` ×2 around both
   builds, matching `agent_frame_bake_spike.gd`'s own idiom. Measured before
   trusting it: leaked instances went from 38 to **415,730**. Reverted
   immediately. Wrong theory, and a worse one than doing nothing.
2. **"It's board size."** First bisection (26/30/36/44 wide, all with glass
   already in the map) seemed to show ANY size increase leaking. Turned out
   confounded — every one of those tests still had glass in it. Isolated
   properly afterward: 44×22 **without** glass passes clean; glass at the
   **original** 24×16 size still fails. Size was never the variable; glass's
   missing roof coverage was one bug, and a **cold damage-atom cache** was
   the other, unrelated one — proved by wiping `damage_atom_cache/` and
   watching the untouched original map leak too.

---

## 3. The actual root cause

`slab_generator.gd`: `Voxel.new(pos, level, slab)` — the Voxel keeps `slab`
as `_parent_container`, and `Slab.voxels` keeps the Voxel back. A plain
`RefCounted` cycle; Godot has no cycle collector. `DamageVariantBaker`'s disk
cache never missed against PLAYGROUND's one historical shape, so the live
Slab/Voxel build path — where the cycle actually forms — had never run in
this selftest before today. The same `Voxel.new(pos, level, slab)` pattern is
how every real gameplay room is built too; a map switch during play leaks the
same way. Director's call: document, don't fix today. Two shapes sketched in
the audit doc, neither built.

---

## 4. Where the next session starts

1. **`WEAPON_MASTER_PLAN` §6c, Parts A–E** — still the actual next item; today
   was entirely a detour from it. Four open questions already answered this
   session: **B1 → enemy's menu**, **B4 → aimed pose (one more bake)**; B2/B3
   were already pre-answered by the plan itself.
2. **The Slab↔Voxel cycle** — `PROMPTS/AUDITS/ROOF_BAKE_LEAK_2026-08-17.md` has
   the full case. Not urgent (invisible in normal single-session play so
   far), but real, and grows with every map switch. Worth a dedicated
   architecture session, not a squeeze-in.
3. **White palette** — parked as a documented bracket
   (`Screenshots/history/p3_white_bracket_v1_v2_v3.png` is the three-way
   comparison). Not promoted to a real faction. If revisited, the open
   thread is testing it somewhere the room's light actually reaches the
   suit's front face — the guard's current spot mostly doesn't.
4. **Glass** — has wall/floor/resistance support but no roof facade. Stays
   reserved in PLAYGROUND (gu x=37-39) alongside brick/cardboard/fabric until
   someone authors one.
