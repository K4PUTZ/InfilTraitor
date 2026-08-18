# RESUMO_SESSÃO — 2026-08-18: o encanamento da cabeça, e quatro suposições que morreram

**Version:** 0.9.104 throughout — no bump asked for, no tag.
**Commits:** 1, pushed. `ef3976b5`

---

## The one-line version

Built the runtime layer system the previous session named as the blocker, and in
building it found that four load-bearing claims in the written bake order were
wrong — each replaced by a measurement rather than by a second opinion. The agent
and the enemy are baked, verified in-engine and rendering through the layer path
in the real game. The remaining bake work is written up as an executable order.

---

## 1. What was asked, and what shape it took

Director: *"montando o encanamento dos movimentos da cabeça"*, then *"pode seguir
com o que achar mais apropriado... só lembrando que queremos deixar a última
parte do trabalho braçal de bake solicitada por escrito"*.

The mechanism, ratified before any code:

- `AgentSprite` gains child `Sprite2D` layers (`head`, `hat`), each with its own
  `ShaderMaterial` sharing the light uniforms. Children draw after their parent in
  Godot, so head-over-body needs no `z_index` — which matters, because OCC-03's
  always-on-top policy belongs to the agent and a `z_index` here would fight it.
- Head art is indexed by **absolute yaw**, not by body facing.
  `p3_head_turn_spike.py` had already measured the premise at 0 of 126 000 pixels.
- Driven by `guard_enemy.vision_angle` — the angle `_get_cone_tiles()` already
  tests detection against. One call in `_process`, no new attention system.
- **Registration by construction, not by a tuned offset**: body, head and hat come
  out of ONE posed export, and the layers inherit the BODY's Y recentring rather
  than their own.

## 2. Four corrections, each paid for by a measurement

| Written yesterday | What the measurement said |
|---|---|
| Add a `P1_NO_HEAD` model flag | Unnecessary. Parts split at EXPORT time (`p2.export_posed(parts=...)`), gated as a partition — agent 58+1+4=63, enemy 54+1=55 |
| Standing and crouch share one head set | They cannot. `POSTURES["crouch"]` pitches `neck` **14°** and the head inherits it — a different picture, and no offset rotates one into the other |
| Bake 24 prone yaws | Prone opts out entirely. Its head is pitched ~-92°, so a world-vertical yaw is a cone swing, not a turn. Guards have no posture, so nothing reaches it |
| One head socket per posture | **Per direction.** Standing spreads 0.000 px across the four facings; the crouch spreads 9.6 (agent) / 8.9 (enemy) because it leans |

The fourth is the one that nearly shipped as a bug in the opposite direction: an
early version of the bake **gated on** the four sockets agreeing, "proving" the
head sits on the yaw axis. Standing passes it at 0.000 px and looks like
vindication. The crouch would have been rejected — a layer that in fact registers
perfectly — and the single-point delta the gate was defending would have placed
the crouched head up to 17 px from its own neck.

## 3. The gate that makes the rest mean anything

`_verify_layers` composites `headless body + head + hat` with the **runtime's own
arithmetic** and compares it against a bake of the whole figure. It runs
automatically at the end of the same Godot boot, so it cannot be skipped or
forgotten on another machine.

| | agent | enemy |
|---|---|---|
| standing, worst | **1.20 %** | **1.20 %** |
| crouch, worst | 0.88 % | 0.51 % |

**The ceiling is 1.5 %, earned rather than invented.** `AGENT_BAKE_VERIFY_DUMP`
writes composite/reference/diff, and the diff settles what those pixels are: an
even red/blue speckle around the ENTIRE outline — feet and shotgun included, which
no layer touches — with balanced counts (55 vs 57, 38 vs 38) sharing one x-range.
A shift paints red down one edge and blue down the other, in disjoint ranges.

Cropping to the alpha box, measured: **0.17 MB against 12.00 MB** for a 24-yaw
head set, 50–70× across the four sets. That is what makes a finer sweep a flag
rather than a budget argument (D42).

## 4. `headless` is per frame set, so the swap need not be atomic

Each bake writes `headless` into its own `anchor.json`, and `AgentSprite` reads it
**per frame set** to decide whether to draw layers. Consequences:

- postures ship headless while the walk still carries its baked heads, and **both
  render correctly** — no flag day, no window where the agent has two heads;
- a headless set with no layer bake is FATAL and loud (B6), because a headless
  character is a bug to see, not a mode to degrade into.

## 5. Verified, not asserted

- `project_lint.py` — clean. `check_invariants.py` — clean. CODEMAP regenerated.
- `run_selftests.py` — **35 clean, 0 failed**.
- The registration gate, green on both families, figures above.
- **In the real game** (`Screenshots/history/auto_2026-08-18_15-49-01.png`): the
  guard renders with a head, bare-headed, no dev joints — his `_enemy` body on
  disk is headless, so the head visible there IS the layer, drawn in-engine.

## 6. Left for the Director

**The yaw count.** `Screenshots/p3_head_sweep/head_sweep_blind.gif` — three blind
columns, order shuffled, key in `head_sweep_key.txt`, driven by the guard's own
exponential lerp rather than an even sweep (an even sweep flatters the coarse
bracket exactly where the real motion is fastest). 24 yaws is 15° a step, ~10 Hz
through a 90° turn, against D46's 30 Hz. The 36 and 72 variants are already baked
to `x36_*` / `x72_*` under `actor_bakes/` (gitignored scratch) so the comparison
can be re-looked at without re-baking. Changing the answer is `P3_LAYER_YAWS` —
`AgentSprite` counts what is on disk.

---

## Where the next session starts

1. **The yaw-count verdict**, then re-bake head/hat for both families if it moves.
2. **The walk, headless** — `p3_walk_export.py` already exports the split; the
   walk reuses the STANDING head set across 32 phases via the neck socket. Known
   bounded approximation recorded in the order: the walk's head stabilisation
   pitches ≤3.7°, which a flat layer does not reproduce (~1.3 px).
3. **dev and test_white families**, when the movement milestone reopens.

The order is [`PROMPTS/BAKE_ORDER_CHARACTER_LAYERS.md`](BAKE_ORDER_CHARACTER_LAYERS.md),
rewritten as an executable request — status table, exact commands per family, what
each printed line means, and a table of what to do when a gate fires. **The bakes
are gitignored** (`.gitignore:69`), so a fresh clone has the code and the gates and
no frames: that file is the deliverable, not a record.

Still open from before: `WEAPON_MASTER_PLAN` §6c (the wall-shot wave), glass's
missing roof facade, and the four-view capture's framing.
