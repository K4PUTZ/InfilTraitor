# Session 2026-09-06 — the glass track CLOSES: two silent defects, a doc truth pass, four rulings

Previous session:
[`RESUMO_SESSAO_2026-09-06_G4_4_SCATTER.md`](RESUMO_SESSAO_2026-09-06_G4_4_SCATTER.md).
This one opened with *"Estamos tentando resolver um bug que aparece nas rachaduras
dos vidros, durante a explosão de granadas. Leia a documentação"* and ended with
**`GLASS_MASTER_PLAN` v1.43 → v1.46, the track CLOSED**, plus `MATERIALS_MASTER_PLAN`
M4 closed with it. Five commits.

| | commit |
|---|---|
| the olive cast — a glass atom on the OPAQUE layer | `a2a4370a` |
| CRACK-04 — the replay claims before it flushes, + the §10 truth pass | `77a579a4` |
| the shockwave-gain bench dial, and the number it exposed | `1cdeab04` |
| gain → 15, cook's glass punch → 5.0 | `7f5d6afc` |
| G-D46 (+1 GU), G-D42 radial, G-D47 (partial break crazes) | `305e73ea` |

---

## 1. ⛔ RESUME POINT — WHAT IS NOT DONE

**The Director asked for CASE TESTING and it has not been done.** *"ainda precisamos
fazer alguns testes de caso, mas vamos encerrar por hoje."* Everything below was
verified on the GLASS map's own panes and by selftest; what has NOT happened is the
Director playing through real scenarios and judging the four rulings on screen
together — especially the radial rain at gain 15 over a pane that only partially
breaks, which is the combination none of the captures show in one frame.

Nothing is known to be wrong. This is a review gate, not a bug list.

## 2. Two defects, and BOTH prior diagnoses were wrong

### 2.1 The olive cast (`a2a4370a`)

Root: **`_set_voxel_cell(apply = false)` returned a glass sublayer atom with nothing
in the dict saying which layer it belonged to.** The detonation cook's
`_resolve_damaged_tile()` handed that id to `DetonationEntryWriter`, which writes the
dented/cracked waves to the OPAQUE layer — so every CRACKED glass voxel had its own
pane atom stamped under the still-intact pane. A glass atom's RGB is
`(dim, dim, tint/255)`, data for `glass_pane.gdshader`, so `voxel_face_shading` drew
it as flat YELLOW and the real pane MULTIPLIED its blue tint over that: **olive**.

720 stray cells across levels 80..103 — which is why the previous session's node
sweep never killed it by hiding one `voxel_layer_N` at a time. Fixed with
`"glass_sublayer": true` on the resolve-only return and `{}` from
`_resolve_damaged_tile()`. 92 779 → 1 754 olive px (the residue is the dev HUD's own
green text). Pinned as `glass_transparency_selftest` **[12]**.

⚠️ The audit's unexplained `(101,101,2)` was **FACE-READ-03's residue snap** forcing
the SW face onto its own class mod 3 — blue 0 becomes 2. Never a tint index.

### 2.2 CRACK-04's rotation drift (`77a579a4`)

§16.13 blamed region grouping. **The grouping was never the asymmetry** — step 1
already makes one region per claim. It was an ORDER: `_reapply_base_damage()` erases
the recorded holes and ENDS in `process_dirty()`, whose tail flushes the rims — with
zero claims — so the fallback invented `GLASS_OPENING_DEFAULT` on a centroid for
every hole. **After one camera turn every hole in the game wore the default shape.**
Fixed by `_claim_base_openings()` before the replay.

⚠️ **A COUNT COULD NOT CATCH THIS**: the gap-3 board is 2 shards before AND after;
only the shape moved. The gate is pixels — **185 → 0** on a N→E→N round trip. Pinned
as `glass_crack_selftest` **[22]**, both halves as identities plus a source-order
check.

## 3. ⚠️ THE INSTRUMENT WAS LYING, AND THAT IS WHY 2.2 SAT OPEN

`glass_crack_demo` never persisted the destruction that made its hole — not the bore,
not G-D24's crossed pieces (52 voxels in the gap-3 case). Any live-vs-rebuilt count
compared a pane that had lost 53 voxels with one that had not, so **the recorded
"340 → 389" was measuring the demo at least as much as the build**. The loud signal
was there the whole time: *"covers N cell(s) whole that still hold glass"* fired
after **every** flip and nobody read it.

The demo now punches a real SECOND bore + claim (it used to lay a second crack over a
pane with no second hole — the fiction its own header bans), takes
`INFILTRAITOR_CRACK_DEMO_SECOND_GAP`, and its flip proof reads the shard BOARD before
and after a flush. New memory: `instrument-fidelity-before-symptom`.

## 4. The §10 truth pass

Four rows said something that had stopped being true, so a reader got four wrong
answers: **CRACK-02** read "PLANNED, UNBUILT" three days and four stages after
S-1/S-2/S-3/S-5 shipped; **G-VARIANT** was 🟡 while its own text ended "IS COMPLETE";
**G6** still listed G-D25's big shards after G-D44 retired them; **G3-D** said
"(open) passage work" when `PassageQuery → blocked_edges` had been built and pinned
since 2026-08-31. Also corrected: S-4's *"blast_\* has no caller yet"* (§16.12 shipped
six procedural blast patterns) and S-6's blocker (CRACK-04 answered it — **S-6 is
unblocked work now, awaiting the Director**).

New **§10.1** is the audited list of what is left and who owns it. **None of it is
glass render or physics.**

## 5. Four Director rulings

| | |
|---|---|
| **G-D42 gain 15** | shipped at 3.0 = a push of 0.11..0.375 of a **floor tile** — real, and invisible. Nobody had converted it to tiles (8 cells per GU). Ruled from a four-video sweep. Now travel mean 1.223 tile |
| **G3-C punch 3.4 → 5.0** | *"a granada está rachando vidraças muito próximas […] 1 ou 2 GUs da bolha"*. A ring IS a GU. Ring 1 78.6% → 96.5%, ring 2 **5.9% → 25.9%**. `SHATTER_BLAST_GAIN` is the ONLY dial that moves glass alone — `ring_multipliers` is shared by dents, craters, soot AND the shard impulse |
| **G-D46 +1 GU for glass** | the AREA grows, the falloff does not move (the `ring - 1` reading would have overwritten the ruling above). Costs no second flood — ring 3 was already in `affected` with a 0.0. **Bounded at 1** by the flood's own reach; [10] pins that |
| **G-D42 radial** | the impulse carries a POINT (`from`) now, not a pre-normalised `dir` — a caller cannot pre-normalise a per-shard direction, so **the old shape could not express the ask**. [8] passed perfectly for the parallel field; new [11] asserts alignment along each shard's OWN radius |
| **G-D47 partial break crazes** | same `_craze_pane()` the lost roll uses; self-limiting for a whole break |

## 6. ⚠️ THE FINDINGS worth carrying

- **A resolve/apply split hides a routing decision.** The resolve half returned an id
  and no target; every caller guessed "opaque". New memory:
  `resolve-only-seam-must-name-its-layer`. **Also:** when a defect's pixel has an
  exact signature (`R == G`, `B ≈ 0`), grep for the line that WRITES it —
  `_build_glass_pane_atom()` had `Color(rgb, rgb, tint_b, a)` in plain sight while a
  whole session hunted a colour bug.
- **`WorldDelta._fold()` folds onto the projection, so a later CRACKED on a voxel
  already projected DESTROYED RESURRECTS it.** G-D47 hit this immediately; the fix is
  to ask `delta.state_of()`, never the live Voxel, inside `build_plan()`.
- **A one-sided bound cannot tell "correctly unlikely" from "collapsed".**
  `glass_shatter_selftest` [10] asserted `p2 <= 0.2` and passed happily on the 5.9%
  the Director reported as a defect. Ring 2 has a band now.
- **A test that pins a superseded design must be REWRITTEN to the new one, not
  weakened.** The cook block asserted "ring 3 is the reliable loser" and "a won roll
  must not also craze" — both now the opposite. It searches for a winning and a
  losing salt instead of hardcoding one, and proves both outcomes are REACHABLE.
  ⚠️ Its first run failed because the probe GUESSED a `pane_id` and therefore searched
  a different salt sequence; the id is read off the fixture now.

## 7. Standing notes for next session

- ⚠️ **The fall is 14–26 FRAMES whatever the distance**, so `SCATTER_IMPULSE_GAIN`
  sets horizontal SPEED, not flight time. If a shard ever reads as a streak,
  `GlassRainOverlay.fall_frames_*` is what moves with it.
- ⚠️ **Ring 4+ is 0% for glass at any gain** — `frag_grenade`'s table ends in 0.0 and
  the flood stops at ring 3. Reaching further is a change to the BOMB.
- ⚠️ **The shatter roll is deterministic per `(source_gu, pane_id)`.** A pane that
  loses from one grenade spot loses EVERY time from that spot — "it always just
  cracks" can be one fixed outcome sampled repeatedly. Test from several positions.
- Bench: `build_filmstrip.py --glass-rain default --rain-impulse 1.0 --rain-gain N`
  (repeat `--rain-gain` to sweep, one MP4 each; prints the travel actually achieved).

## 8. Evidence

`glass_olive_fix_{before,after}.png` · `crack04_rim_roundtrip_{before,after}.png` ·
`Screenshots/filmstrip_rain/rain_{shipped,radial}_gain15.mp4` and the 0/3/12/30 sweep
(gitignored — regenerate with the command in §7). All 51 selftests clean, lint +
invariants + codemap OK at every commit.
