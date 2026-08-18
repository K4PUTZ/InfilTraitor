# BAKE ORDER — character layers (head turn, hat swap)

**Raised 2026-08-17.** Director: *"vamos deixar já preparado o pedido de bake com
todas as poses necessárias."* This is an executable request, to be run while the
runtime layer system is built in parallel.

**Read [`docs/pipelines/character_bake_pipeline.md`](../docs/pipelines/character_bake_pipeline.md)
first.** It carries the stage-by-stage mechanism, every env var, and the eight
traps this order assumes you will avoid. This file is only *what* to bake.

---

## Why the split exists

`_do_idle_behavior()` already turns a guard's head before his body
(`attention.focus(...)`, "visual scan"). The behaviour has shipped for months and
was only ever visible through the detection overlay, because the baked figure has
no head-turn art. This order produces that art.

Ratified 2026-08-17: **all parts separated**, so a faction is a swap and not a
re-bake. The hat changes on the agent (D53's costume flip) and the enemy goes
bare-headed.

---

## The finding this order is built on — do not re-derive it

**A head frame depends only on the head's ABSOLUTE yaw, never on the body's
facing.** Measured with `tools/asset_generation/p3_head_turn_spike.py`: the head
layer rendered at the same absolute yaw under a body at 0° and at 90° differs by
**0 of 126 000 pixels** on the bare head, and 11 px at delta 1 (rasteriser
rounding) with the fedora on.

So head art is **additive in one dimension**. It is indexed by absolute yaw and
shared across all four body facings.

### How many head frames, exactly

Body facings are `{0, 90, 180, 270}`. The head sweep is **±60° in 15° steps**
(9 offsets — settled 2026-08-17: the head leads the body by at most one or two of
`_do_idle_behavior()`'s 45° steps). The union of the four ranges is:

```
{0,90,180,270} + {-60,-45,-30,-15,0,15,30,45,60}  →  24 distinct yaws
```

which is simply the full circle at 15°. **24 head frames per posture-variant, not
9 per facing** — 9 was the per-facing count and is the wrong number to bake.

---

## What to bake

### A. BODY — headless

The body bake **must not contain a head**, or the composited head layer will have
a baked head peeking out from under it at every non-zero yaw. The neck
(`seg_neck`, bound to the `neck` bone) stays on the body; only `seg_head` and the
four fedora parts lift off.

> ⚠ **This needs a model flag that does not exist yet.** `p1_agent_model.py` has
> `P1_NO_HAT` and `P1_NO_BACKPACK` but no `P1_NO_HEAD`. Add it the same way
> (palette-independent env override, `log()` on the skip path) before running
> this section.

| Variant | `P1_PALETTE` | Postures | Facings | Frames |
|---|---|---|---|---|
| agent | *(none)* | standing, crouch, prone | N,E,S,W | 12 |
| enemy | `enemy` | standing, crouch, prone | N,E,S,W | 12 |

Plus the walk cycle, same headless body, via `p3_walk_export.py`
(`P3_WALK_PHASES=32`): 32 phases × 4 facings = **128 frames per variant**.

Each frame is two PNGs (`_color`, `_normal`).

### B. HEAD — bare, 24 yaws

Bare `seg_head` only. No hat: the hat is its own layer (§C) precisely so the
enemy can go without one.

| Posture group | Yaws | Frames |
|---|---|---|
| upright (standing + crouch) | 24 | 24 |
| prone | 24 | 24 |

**Standing and crouch share one head image set** — the head geometry and its
orientation are identical; only the anchor differs, and the anchor lives in
`anchor.json` per directory. Prone genuinely differs (the head is pitched ~-92°).

> **Verify rather than assume this**: bake standing and crouch separately once
> and compare the PNGs byte-for-byte. If they are identical, collapse to one set
> and keep two anchors. If they are not, something in the crouch pose moves the
> head and the assumption above is wrong — say so, do not quietly ship 48.

### C. HAT — the fedora, 24 yaws

Same 24 yaws, same posture grouping as §B. **Agent only** for now; the enemy is
bare-headed by Director's call, taken knowing the turn reads more weakly without
the brim and band (revisit when the face lands).

Authoring note: the four fedora parts are already bound to the `head` bone, so
they ride the same yaw with no extra work.

### D. BACKPACK — not ordered

Already handled at model level: `build_backpack()` is palette-conditional, so the
agent has it and the enemy does not. Bake it as a layer **only** if runtime
toggling is wanted (stowing it, or a loadout that drops it). Not part of the head
work; do not build it speculatively.

---

## Frame budget

| Layer | Per variant | Notes |
|---|---|---|
| Body, postures | 12 | headless |
| Body, walk | 128 | 32 phases × 4 |
| Head | 48 | 24 upright + 24 prone, shared across facings |
| Hat | 48 | agent only |

The alternative — baking head yaw into full-figure frames — multiplies the body
count by 9 (the per-facing sweep), which is the whole reason the layer split
exists. D42 names RAM as this character's binding constraint.

---

## Naming

Follow the existing convention exactly so `AgentSprite`'s loader needs no special
case:

```
actor_bakes/agent_frames<family>/<posture>/frame_{N,E,S,W}_{color,normal}.png
actor_bakes/agent_frames<family>/<posture>/anchor.json
```

For the yaw-indexed layers there is **no established convention yet** — propose
one with the runtime work rather than inventing it here. The obvious shape is
`agent_head<family>/<posture_group>/yaw_<000..345>_{color,normal}.png`, but the
loader that reads it does not exist, and a naming decided without its consumer is
how two formats start.

---

## Do not bake yet — sequencing

`AgentSprite` today draws **one composite frame per facing**. Nothing composites
a head over a body. Baking §B and §C before that exists produces PNGs no code can
draw — dead assets waiting for a consumer, and a naming scheme guessed without
one.

**Order of work:** the runtime layer system first (a CHARACTER_MASTER_PLAN
decision, not yet taken), then §A's headless re-bake, then §B/§C against the
naming that system defines.

§A's `P1_NO_HEAD` flag is the one piece that can be built immediately and safely,
since it only adds an option nothing is forced to use.

---

## Verification for whoever runs this

Per pipeline doc §7, and specifically here:

1. Every gate green — heights, X-span, floor-on-origin, `MAX_WHITE_FRACTION`.
2. Contact sheet per layer; look at it.
3. The byte-comparison in §B, reported either way.
4. Re-run `p3_head_turn_spike.py` against any new model and confirm the
   independence figure is still ~0 px. If a model change ever breaks that, the
   24-frame economy is void and the whole order needs re-costing.
