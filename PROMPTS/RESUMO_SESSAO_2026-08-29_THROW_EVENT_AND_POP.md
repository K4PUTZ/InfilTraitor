# RESUMO_SESSAO — 2026-08-29 · throw_event POLISH + E-POP

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-29_D7_LIGHT_COOK.md`
**Commits (pushed):** `08a9f66e` throw_event polish · `a6d4d42f` E-POP.
**Gates at close:** lint ✅ · selftests **38 clean / 0 failed** ✅ · invariants ✅ ·
CODEMAP ✅.
**VERSION:** unchanged at 0.9.107.

---

## §8.13 — `throw_event` polished

The three rough edges the master plan flagged, plus two found on the way:

- **Aim HUD cleared before the capture loop** — dome, shrapnel rays, range
  perimeter, wireframe footprint. Opens on the agent cocked to throw, not a
  screen of aiming diagram. Virtual grenade + arc stay (gameplay).
  `INFILTRAITOR_EVENT_KEEP_HUD=1` restores it.
- **Default target = PLAYGROUND fabric floor zone gu (30, 4)** — a soft material.
  `agent.cell + (3, 0)` landed on bare concrete from `agent_start` (27, 9):
  dents, no fire. Fabric gives a crater, ~39% passage, **310 embers**.
- **Camera frames the landing GU**, not the agent↔landing midpoint (which sat
  over empty floor with the blast off-frame).
- **Dropped `_seed_dev_grenades_if_empty()` from this capture** — it seeds a row
  of grenades against the far walls and `enter_grenade_mode()` threw one of
  those (blast landed right, visible prop arced from across the map). Empty, it
  spawns one at the agent's cell.
- **`FRAMES_TOTAL` default 460 → 620** — 460 ended during the smoke-clear wait,
  before `play_consequence_light()`. 620 reaches `light landed` (and shows D-7's
  `derive 13 ms · cook field` on the real throw path).

⚠️ Still minor, not chased: the grenade in flight is small against the floor.

## E-POP — the grenade hops to the blast centre

> Director, 2026-08-29: the explosion point sitting a bit above the ground is
> right, but the grenade detonating from the floor left the fireball floating
> over it — *"a granada teria que dar um 'pulinho' de última hora quando acontece
> a explosão."*

`_start_detonation_sequence` beat 2, before the sprite is hidden: the grenade
lurches up `blast_pop_height_px` (20) over `blast_pop_frames` (3) with an
ease-out, and `spawn_blast_burst` / `spawn_shrapnel` fire from `boom_anchor` =
the ground anchor raised by the same amount. The fuse (beat 1) still burns at
ground level. Both `var` (Rule 1); frames not seconds (plays on the same frames
the synchronous cook finishes on). Director ratified on the slow-motion video.

## State of the detonation track

**Fully closed.** `DETONATION_PRESENTATION_MASTER_PLAN` has no engineering
pending: design closed 2026-08-29, D-0…D-8, D-6 deletion, D-7 light cook,
throw_event, E-POP all shipped.

## What is actually left (other plans)

1. **Glass** — `MATERIALS_MASTER_PLAN` M4, the non-local pane break, *"tem que
   quebrar muito mais com a granada"*. Parked to the end of the materials
   milestone. The one explicit follow-up the Director named.
2. **Materials M5 (props) / M6 (fluids)** — unbuilt.
3. **Optional:** a base-occupancy cache in `VoxelRenderer` — removes D-7's 45 ms
   cook step and speeds every room repaint. Its own change, its own gate.
4. Untouched: `SOOT_STORAGE_REFORM` SS-4/SS-5, the glowing edge,
   `INFILTRAITOR_HIDE_VOXELS`, audio (incl. the swiffh SFX D-6 deferred),
   `update_docs.py`'s silent wipe.
