# RESUMO_SESSÃO — 2026-08-17: o ciclo que nunca liberava, o cone torto, e as camadas do personagem

**Version:** 0.9.104 throughout — no bump asked for, no tag.
**Commits:** 8, all pushed.
`613ef3a5` · `0722ac91` · `745221e3` · `1fd644cc` · `68c11204` · `f6004546` ·
`9a55f7d9` · `37dba803` · `7bd63017`

---

## The one-line version

Started on the dormant bug from the previous session and fixed it structurally
(301 MB leaked per map build, gone), then hardened the arbiter so that class of
bug cannot hide again, then moved to the character: a 90° cone bug that turned
out to be the overlay lying rather than the body, the white suit's real lever,
and the head/hat/backpack separation — proven by measurement, documented, and
deliberately **not** baked yet.

---

## 1. The Slab↔Voxel reference cycle (LEAK-CYCLE-01)

`Voxel` held its container strongly while the container held the Voxel forward.
`RefCounted` has no cycle collector, so every container plus its voxels became a
self-sustaining island outliving the room, the registry and every owner.

Fixed structurally: `_parent_container_id`, a plain `int`, resolved through
`instance_from_id()`. An id rather than a `WeakRef` because a WeakRef per Voxel is
143 392 extra objects on PLAYGROUND alone (D42: RAM is the constraint).

| Measurement | Before | After |
|---|---|---|
| PLAYGROUND build+free ×3, retained | 301 → 602 → **907 MB** | **4.18 MB**, flat |
| `roof_bake_selftest`, leaked instances | **410 408** | **0** |
| 64 000-voxel probe, reclaimed | 0.02 MB | 94.04 MB |
| Dirty transition cost | 0.319 µs | 0.358 µs |

Weakening the reference exposed **six fixtures that never owned their container**
— it survived only because the cycle made it immortal. All failed loudly, which
is B6 working.

**Two claims in the original audit were wrong** and are corrected in place: the
disk-cache explanation (the leak fired on a warm cache too), and the "Narrow" fix
option (`DamageVariantBaker` builds no `Slab`/`Voxel` at all — it references two
of Voxel's enums).

## 2. The arbiter now enforces what it was ignoring (LEAK-GATE-01)

`run_selftests.py` failed only on exit code and `SCRIPT ERROR`. `ObjectDB
instances leaked at exit` printed on every run for months, unread — that is the
whole reason the cycle survived. Now a leak **fails** the run, and so does a
teardown crash.

The `bake_selftest` "teardown crash after PASS", tolerated since 2026-08-01 as
engine cleanup, **was ours**: the only selftest calling `Engine.set_meta()`
without `remove_meta()`, so engine metadata still held a `MockRegistry` at
`unregister_core_types()`. Two lines ended it.

Gate proven in both directions — an injected `Object.new()` produced
`exit 0 + LEAKED objects at exit`, exactly the case the old runner called clean.

## 3. P-FILM and the four-view capture run again

Retiring PLAYGROUND's floor grenades (`66253137`) silently killed both dev
capture tools. Both now seed their own from `TEST_ZONE_GRENADE_GUS`; verified the
four material walls never moved when the board grew 24×16 → 44×22.

**Still open:** the four-view capture runs and detonates but no longer *frames*
the blast — camera on the agent (13,14), grenade at (13,5), off-screen. Where
that camera should point is a design call, left to the Director.

## 4. The vision cone was 90° off the detection it draws (CONE-ANGLE-01)

The Director reported the enemy's orientation looking 90° off the floor overlay.
**The body was right and the overlay was lying.** Three consumers read the
facing; `_get_cone_tiles()` (real detection) and `_draw()`'s nose line use grid
convention with no offset, while both cone draw functions added `+ 90.0`.

Root cause: `vision_angle` carried a grid angle by default and a SCREEN angle
under attention (`to_focus.angle()`). One constant offset suits at most one, and
in an isometric projection screen↔grid is not a rotation at all. Fixed by never
leaving grid space — the attention target is a cell, so the grid delta is direct.

**Director's clarification: the head diverging from the body is an intended
feature.** The fix is a prerequisite for it, not an obstacle.

Also fixed (`FACING-SYNC-01`): the guard's sprite never updated facing after
`attach_sprite()`. Proven from code, **not reproduced at runtime** — the guard
never turned in any drivable capture.

**Instrument warning:** the `end_turn` harness is non-deterministic — 849 349
pixels differ between two runs of identical code. Never pixel-diff it.

## 5. The white suit, and the lever that actually moves it

`lit = albedo * (ambient + ndotl * light_intensity)`. On an unlit facet this
collapses to `albedo * ambient` — so the palette (already at the
`MAX_WHITE_FRACTION` ceiling) and `LIGHT_RESPONSE_OVERRIDE`'s scale/max are all on
the far side of a multiply by zero. **Only `ambient` moves it**, and it is now
per-family.

Director picked **0.75**, the third step, not the brightest: headroom against an
over-bright display. Floor around the guard spans luma 85–146; 0.75 puts the suit
at 174, and 0.90 reached 212 but flattened the folds.

Pinstripes went from 12 torso-only prisms to **44** — torso, sleeves, trousers,
each bound to its own limb bone.

## 6. Character parts separated, and the head-turn spike

The backpack and the hat were built unconditionally, so every palette inherited
them. Both are palette-conditional now; the enemy ships bare-headed and without
the pack, and was **re-baked** (12 frames, in the game).

**The load-bearing measurement** (`p3_head_turn_spike.py`): a head frame depends
only on the head's ABSOLUTE yaw, never the body's facing — **0 of 126 000 pixels**
differ between a body at 0° and 90°. Head art is additive.

It took a wrong answer first: rotating about the bone's local Z gave 4713 px, and
that number is what exposed the wrong axis (a bone's local Y runs *along* it, so
the head was tilting, not turning).

**The hatless enemy ships at 1.920 m, not 2.00 m.** A fedora is 7.6 cm. The scale
factor stays fixed so every body matches; the gate is told the expected height
instead. `EXPECTED_STANDING_HEIGHT_M` now exists for that.

## 7. Documentation

- [`docs/pipelines/character_bake_pipeline.md`](../docs/pipelines/character_bake_pipeline.md)
  — the whole mechanism, executable by someone who did not build it.
- [`PROMPTS/BAKE_ORDER_CHARACTER_LAYERS.md`](BAKE_ORDER_CHARACTER_LAYERS.md)
  — what to bake. **Head frames are 24, not 9** (9 is per-facing; absolute yaw
  makes the union the full circle at 15°).

---

## Where the next session starts

1. **The runtime layer system** — `AgentSprite` draws one composite frame per
   facing; nothing composites a head over a body. This is the plumbing, and it is
   a CHARACTER_MASTER_PLAN decision not yet taken. Everything else waits on it.
2. **`P1_NO_HEAD`** — the one piece safe to build immediately, since the body must
   bake headless.
3. **Then** the bake order's §A/§B/§C, against the naming the layer system
   defines.

Still open from before: `WEAPON_MASTER_PLAN` §6c (the wall-shot wave), glass's
missing roof facade, and the four-view capture's framing.
