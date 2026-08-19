# RESUMO_SESSAO — 2026-08-19 (the agent shoots, and four things the gates could not see)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-19_ALPHA_ENEMY_HAIR.md`
**Plan closed:** `WEAPON_MASTER_PLAN` §6c — Parts A–E, B1–B4.
**Gates:** lint ✅ 210 files · selftests ✅ 35 clean / 0 failed · invariants ✅ ·
CODEMAP ✅.

---

## The one-line version

The shooting mechanism the bench used to stand in for now leaves the AGENT: right-
click an enemy, "Atirar", the weapon comes up, the round misses by decree and
chews D30's ladder out of the wall behind him. Four defects that every automated
gate passed were found by looking at the captures, and one of them had already
destroyed the player's source model the night before.

---

## 1. The Director's two rulings

Asked at the point of ambiguity, before building, because §6c itself flagged
both as "confirm first":

- **B1 — where "Atirar" lives:** on the **ENEMY's** menu. Follows D25 and the
  Director's own 2026-08-16 phrasing (*"ao clicar nele + disparar"*), and scales
  to several enemies without a "which one" variable.
- **B4 — a firing pose:** **bake `aimed` now.** The grip spike had already found
  `aimed` the one of D40's three that reads unmistakably.

Declared rather than asked, as §6c instructs: **B2** he fires what he holds (the
shotgun), sidestepping the live D31 × §10.2 collision instead of resolving it;
**B3** the void case would be in the capture.

---

## 2. ⚠️ The player's model had been overwritten, and nothing had noticed

Found while preparing the `aimed` bake, not while looking for it.

`P1_PALETTE` and `P1_VARIANT` were independent env vars in `p1_agent_model.py`:
the palette decides WHAT is built (enemy_white is bare-headed and carries a face;
the agent is hatted and has neither), the variant decides WHERE it is written. A
run on **2026-08-18 22:52** set the first and not the second, so the enemy landed
on `agent_base.blend` — the PLAYER's own file.

Measured rather than inferred:

```
PROBE agent_base             suit=(0.92, 0.92, 0.94)  hat=ABSENT   [+face meshes]
PROBE agent_base_enemy_white suit=(0.92, 0.92, 0.94)  hat=ABSENT   [+face meshes]
```

Byte-for-byte the same character. Nothing failed at the time; the player's source
model was simply gone, and would have surfaced as **a hat popping off** the first
time anyone re-baked him.

**Recovered** by re-running `p1_agent_model.py` with no palette — the generator IS
the source of truth, so nothing was lost:

```
PROBE agent_base  suit=(0.02, 0.021, 0.026)  shirt=(0.86, 0.87, 0.9)  hat=(0.02, 0.02, 0.025)
FEDORA: ['seg_fedora_band', 'seg_fedora_brim', 'seg_fedora_crown', 'seg_fedora_curl']
HAIR/FACE: NONE
```

**Blinded** with a loud fail: `P1_PALETTE` with no `P1_VARIANT` now refuses,
naming the variant to pass. It cannot break a correct invocation, because a
correct one always passed both.

---

## 3. What was built

| Part | What |
|---|---|
| **A** | `Agent.muzzle_origin()`; `aim_offset_deg` on `select_cone_pellet_impacts()`/`select_line_impact()` so a shot can aim at an actor that is not on a grid axis |
| **B** | `AgentShotController` — hit-test on the guard's floor cell, "Atirar" on the enemy's menu |
| **C** | `ShotHitRoll` — D12's FIRST roll, real, with `FORCE_OUTCOME = MISS`. The HIT branch `push_error`s instead of falling through, so the hit path is one enum away and unreachable by accident |
| **D** | `TracerOverlay` — the decorative projectile. Amends D21: **visible, never simulated** |
| **E** | Three named capture frames + a control run |

The `aim_offset_deg` default is 0.0, so every pre-existing caller is
bit-identical — asserted, not assumed, by the new selftest.

---

## 4. The four defects the gates could not see

Every one passed lint, invariants, CODEMAP and 35 selftests. Every one was found
by looking at a capture.

1. **`p3_posture_export.py` keyed bake directories on the MODEL only.** Running
   `P3_GRIP=aimed` would have written straight over the shipped `lowered`
   frames — the ones idle, walk and turn draw from — and its manifest over
   theirs. Caught BEFORE the bake ran. `GRIP_SUFFIX` now reaches the directory;
   `lowered` keeps the bare name so nothing shipped moved.
2. **`AgentSprite._set_key()` omitted the grip.** Both grips shared one cache
   slot, `_ensure_set()` early-returned on it, and whichever loaded first was
   drawn forever — while `set_grip()` reported success.
3. **`_posture_root()` ignored the grip on the DEV branch.** Dev vision is ON at
   boot, so the raise resolved to `agent_frames_dev/` and did nothing, silently.
   The instrument that settled it is one `print_debug` naming the resolved root:

   ```
   [AgentSprite] grip -> _aimed (…/agent_frames_dev/)      ← before
   [AgentSprite] grip -> _aimed (…/agent_frames_dev_aimed/) ← after
   ```

   Measured torso change between the raised and lowered frames: **3 strong
   pixels before, 567 after.**
4. **`muzzle_origin()` read a stale constant.** `HEAD_OFFSET` was tuned
   2026-08-10 against the vector DIAMOND placeholder and never corrected when
   the baked figure landed — 64 px against a real drawn reach of ~169 px. The
   muzzle flash went off at the agent's **waist**. It now reads `anchor_px` and
   `head_socket_px` from the bake itself.
   **`throw_origin()` still carries the stale constant** — correcting the
   grenade's launch point changes a shipped, tuned arc, and that is a separate
   change with its own verification. Flagged, not silently fixed.

---

## 5. Evidence

`Screenshots/history/shot_stone_{1_aim,2_tracer,3_damage}.png`,
`shot_ctrl_3_damage.png`. **Named, not `auto_`-prefixed**, so the 50-file
rotation leaves them alone.

```
[AGENT-SHOT] from=(10, 8) at=(13, 4) outcome=MISS(forced) axis=(0, -1)
             offset=36.9 deg landed=24/24 impacts=[(14, 4), (13, 4)]
             voxels=15 tiers={ 3: 15 }
```

**The control run is the part worth keeping.** The first read of the
uncontrolled damage frame was WRONG — it looked like nothing had happened. Same
boot, same camera path, same binary, Escape instead of Enter: **2 161
strongly-changed pixels** in a bbox landing on the struck face. The marks are
real and low-contrast on a busy stone facade. "15 voxels changed state" and "a
mark you can see" are different claims, and only a control tells them apart.

---

## 6. B3 — the void case is UNREACHABLE, and that is a measurement

`MapCompiler` is the only place the buffer is applied (architecture rule 7) and
it blocks every tile outside the playable segment, so every map is fully
enclosed. PLAYGROUND is 44×22 inner with `buffer: 1`; `PELLET_FLOOD_MAX_STEPS` is
40. A ray fired from anywhere reaches a perimeter wall before exhausting its
walk. Measured by trying — a shot across the open east half from (30,16)
travelled ~14 GU into the boundary at x=44, `landed=24/24, tiers={3: 19, 2: 6}`.

D15's void path IS covered by selftest, but **no capture on any existing map can
show it.** It needs a map with an opening, or a `max_steps` below the board's
half-width. Reported as a gap rather than closed with a substitute.

---

## 7. Beyond the parts, named rather than smuggled

The agent **turns toward his target** before raising the weapon. Not in §6c's
list; the first capture made the omission read as a bug in the shot rather than
as a missing nicety.

---

## 8. Open

- `throw_origin()`'s stale `HEAD_OFFSET` (§4.4 above) — the grenade launches from
  the waist for the same reason the muzzle did.
- B3 needs a map with an opening before the void case can be captured.
- The DENTED marks read faintly on stone. Not this wave's (D22/D23 shipped them),
  but the control run is what made it visible as a question at all.
- `ShotHitRoll.BASE_CHANCE` is a placeholder with none of D12's real terms
  (skill, cover, shadow, weapon level) modelled. §7c's four open questions all
  land in `chance_for()`.
