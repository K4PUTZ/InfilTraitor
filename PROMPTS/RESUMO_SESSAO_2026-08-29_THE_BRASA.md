# RESUMO_SESSAO — 2026-08-29 · THE BRASA, AND D-4 CLOSES

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-28_PRESENTER_AND_THE_SMOKE.md`
**Gates at close:** lint ✅ · selftests **40 clean / 0 failed** ✅ · invariants ✅ ·
CODEMAP regenerated ✅ · zero warnings in the 3 `.gd` files touched · cell probe
`1169 erased · 0 RESTORED · 512 appeared · 0 VANISHED` (identical to D-2/D-3).
**VERSION:** unchanged at 0.9.107 (no tag requested).

---

## Read this first if you are resuming

**`DETONATION_PRESENTATION_MASTER_PLAN` D-4 is DONE.** Next is **D-5** (the light
lands — §7), then D-6 (remove the choreographer). Nothing is half-built; the tree
is clean.

---

## 1. THE DIRECTOR DOWNSCOPED THE SYMBOLIC FIRE ON SIGHT

Presented with the §5.1 plan (per-voxel vibrating flame → incandescent voxel →
black → smoke, transmission that turns a voxel to ash), the Director closed it:

> *"Olha a gente já chegou num visual bem bom, só falta um pouquinho de brasa nos
> materiais moles, e pronto. Faz como você achar melhor, o que a gente conseguir
> colocar de vermelho brilhando que vira preto é lucro. De resto pode deixar
> assim mesmo. Só vamos precisar trabalhar o vidro, porque ele tem que quebrar
> muito mais com a granada, mas vamos fazer isso no final da milestone de
> materiais."*

So §5.1's spec is **not built as written** and does not need to be — see §2. The
glass break (*"tem que quebrar muito mais"*) is parked to the end of the
materials milestone (`MATERIALS_MASTER_PLAN` M4, the non-local pane break).

## 2. ✅ D-4 — THE BRASA (§8.8)

**The glow was already on screen.** `_build_ember_wave()` queues exactly one
ember on every voxel the fire consumes — the proof is structural, not measured:
`_maybe_burn()` is only ever called from `_build_ember_wave()` / `_climb_from()`,
always immediately after that cell gets its ember, so `burnt ⊆ ember-wave cells`.
Measured on the real PLAYGROUND fabric wall at gu (31,3): **235 of 235 consumed
voxels carry an ember** (`[E-BURNEMBER] 235 of 235`). And `EmberOverlay` already
ramps yellow-hot → deep red → charcoal and hands a puff to the smoke overlay on
death. "Vermelho que vira preto" was tuning, not construction.

**What shipped — a flag and three knobs, no new overlay, no new wave kind:**

- **`DetonationPlanBuilder._mark_burnt_embers()`** — PHASE_BURN, right after
  `_commit_burn_to_delta()`. Walks `waves["ember"]`, sets `burnt: true` and `at`
  (the retired schedule's pace) on every entry whose cell is in `burnt`.
- **`EmberOverlay.burnt_ember_radius_gain` (1.18) · `_life_gain` (1.15) ·
  `_cool_rate` (0.85)** — the boost a flagged ember gets. `DetonationEntryWriter`
  reads them and passes them to `add_ember()` as `radius_scale`, a
  `duration_scale` multiplier and `cool_rate`. An unflagged edge ember passes
  `1.0 / 1.0 / 1.0` and is **byte-for-byte unchanged** — so **wood's ratified
  VL-D4 look is untouched** (wood burns nothing, flags nothing).

⚠️ **THE FIRST CUT WAS A FIREBALL.** `burnt_ember_gain = 1.6` on both radius and
life turned 235 consumed voxels into one blown-out yellow sheet under ADD — the
exact "molten sheet" E-EMBER-02 lowered `val_*` to avoid. Toned to 1.18 / 1.15 on
the second capture and it reads as coals: bright orange at f60–75, cooling
through red, nearly out by f165. Every value is a `var` and the Director tunes it
on the filmstrip.

**Works on both paths.** The writer is shared (D-3) and `ember` is already in the
choreographer's `PLAYED_KINDS`. The choreographer ignores `at` and paces the
flagged embers with its radial front; the presenter releases them by `at`, in the
order the fire spread. The choreographer is D-6's to delete either way.

⚠️ **A flagged ember sits ON the hole the fire opened** — the exact opposite of
`_build_ember_wave()`'s survivor predicate. `detonation_plan_selftest` `test_7`
pins that predicate for the UNFLAGGED embers; the new **`test_11`** pins the
inverse for the flagged ones (every flagged ember on a destroyed cell, carries
`at`; a concrete blast flags none). The two rules live side by side on purpose.

## 3. Evidence

- **Cell probe** (P-FILM, `INFILTRAITOR_PRESENTER=1`, fabric gu (31,3)):
  `1169 erased · 0 RESTORED · 512 appeared · 0 VANISHED` — identical to D-2/D-3.
  The brasa writes no cells, so this was expected, and it confirms no regression.
- **Filmstrip** `Screenshots/filmstrip/` (gitignored) + `brasa_montage.png` —
  f48 ignition, f62–95 orange coals, f120–150 cooling to deep red under the
  rising smoke.
- `test_11`: 235/235 flagged, every flagged ember on a hole and carrying `at`,
  concrete flags 0.

## 4. OPEN — in order (unchanged from the 08-28 record except D-4 done)

1. **D-5 — the light lands** (§7). Soot into the commit; the ramp to its D-0
   duration. Gate: the final frame pixel-identical to a pacing-only control.
2. **§7.4 — the light derive, ~202 ms in one frame.** With D-3 in, it is the
   whole remaining stall, and ruling 2 of the 08-28 record (the 240-frame event
   is ratified) says there is now a second of smoke to hide it under.
3. **D-2b** — the pre-fabricated pattern; now also what makes an authored breach
   point work.
4. **D-6** the removal, **D-7**, SS-6 with D-7.
5. **Glass** — *"tem que quebrar muito mais com a granada"*, deferred to the end
   of the materials milestone (`MATERIALS_MASTER_PLAN` M4).
6. Untouched: `SOOT_STORAGE_REFORM` SS-4/SS-5, the glowing edge,
   `INFILTRAITOR_HIDE_VOXELS`, `update_docs.py`'s silent wipe, audio.
