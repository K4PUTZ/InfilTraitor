# RESUMO_SESSAO — 2026-08-13 (doc-vs-code audit → E-EMBER-01 / E-SMOKE-TINT-01)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-13_E_CONTRAST_FLOOR_SHADE.md`
**VERSION:** 0.9.100 → **0.9.101** ("Alpha Ember Tuning")
**Plans touched:** `EXPLOSION_REBUILD_MASTER_PLAN` (new §11b),
`VOXEL_LIGHT_MASTER_PLAN` (VL-D4), `DESTRUCTION_MASTER_PLAN` (header + D24),
`docs/production/current_state.md`, `docs/README.md`.

---

## The one-line version

A review of the project's docs against its code turned up exactly one real
divergence — the wood ember glow had been dead for eight days while three
documents called it shipped — and closing it, together with the wood smoke
tint the Director asked for in the same breath, put a `flammability` column on
the material table that the coming materials milestone will fill in.

---

## 1. The audit

Director: *"vamos dar uma revisada no estado do projeto, confrontando o código
com a documentação."*

Health gates, all green before any change was made:

    project_lint.py          ✅ PASSED — No real compile errors detected
    check_invariants.py      ✅ OK
    gen_codemap.py --check   ✅ exit 0
    run_selftests.py         ✅ 35 clean, 0 failed
    dead links in docs/README.md and CLAUDE.md: 0 (checked programmatically)

**One divergence found, and it is the feature the Director already had in
mind.** VL-D4's per-voxel ember→char glow:

- `VOXEL_LIGHT_MASTER_PLAN` §397 — *"Wood ✅ LANDED 2026-07-26 (VL-D4)"*
- `current_state.md:374` — listed under ✅ Resolved
- `DESTRUCTION_MASTER_PLAN:12` and D24 — present tense, and D24 still described
  `_is_freshly_scorched()` as the live seeding condition

In code, that helper and its loop were deleted on **2026-08-05** by the
`[RESET]` commit `d4124809`, which disconnected explosive destruction wholesale
for the rebuild. Task 5 (E-WAVE) reconnected the trigger on 08-07 and restored
the damage pipeline but not this. The only surviving `add_ember()` call was
`Room.spawn_blast_burst()` — the fireball core, a different thing entirely.
**No document recorded it as an open gap.**

**Everything else checked out.** Notably the sibling casualty of the same
rebuild — VFX-01's blast debris — is flagged honestly in three places
(`test_zone_controller.gd`'s own comment, `EXPLOSION_REBUILD_MASTER_PLAN` §5
with an explicit *"Ask before building it"*, and `current_state.md:639`). Docs
and code agree there.

## 2. What the Director asked for next

*"Pode manter como estava antes, a gente já tinha um visual bom. Por enquanto
só temos madeira que é combustível, mas quero acrescentar caixas de papelão e
tecidos… Um toldo por exemplo tampa a luz mas pode ser queimado… Outras crates
e paredes de madeira mais leve também vão ser bem inflamáveis, podendo abrir
passagens. Vamos trabalhar isso com mais detalhes na milestone de materiais.
Coloca essa propriedade na tabela."*

So: the original predicate, not a redesign; and combustibility becomes material
DATA now, with the mechanism deferred.

## 3. What shipped

**`flammability`, one row per material** (`materials/*.json`, read by both
`MaterialResistanceTable` and `MaterialRegistry.MaterialDef` — D21's
one-file-two-readers arrangement). A **multiplier centred on 1.0**, not a 0–1
probability, matching `shot_punch_table.gd`'s stated convention; only `0.0`
carries structural meaning (never catches). Wood is the 1.0 reference, which is
what makes the restored glow byte-for-byte the pre-`[RESET]` look. It is a gate
plus a duration scale and nothing else — burning through, blocking light,
opening passages are the materials milestone, deliberately not invented here.

**The ember, as a real plan wave.** `_build_ember_wave()` seeds from this
blast's own destroy entries (not the soot snapshot, which merges firearm holes
and every older crater on the map — a blast's embers belong to that blast), and
keeps the original predicate exactly: a voxel that SURVIVES with at least one of
its six neighbours gone. Played by the choreographer inside the expanding front
at bias −0.10, between the mark and the smoke, rather than in one burst after
the destruction has already passed through — the front did not exist in July.

**The smoke tint.** Per-voxel smoke entries now carry their material;
`Room.blast_smoke_tints()` resolves `{material: Color}` room-side, because the
builder is static and runs headless where `Registries` does not exist. The tint
supplies the HUE only — `SMOKE_COLOR`'s 0.2 alpha is kept, since per-voxel smoke
gets its density from overlap and VFX-01's own alpha was tuned for a completely
different path.

**Two deliberate departures from "como estava antes", both stated rather than
slipped in:**

1. The ember covers **floors and ceilings**, not only walls. The 2026-07-26 loop
   collected wood from `Slice`es only. D19 — *"a material behaves identically on
   floor, wall and ceiling — durability, baked assets, soot, effects, ember"* —
   had already outlawed that, so reproducing it would have been reproducing a
   bug.
2. The gate is data, not `if material == "wood"`, which is what the Director's
   own instruction asked for.

## 4. Evidence

Real live PLAYGROUND detonation at the wood test-zone grenade:

    [E-PLAN] census gu=(18, 5) cost=188.4ms
      FLOOR/concrete   destroyed   85 · dented   54 · cracked   59
      FLOOR/stone      destroyed    0 · dented    0 · cracked    5
      FLOOR/wood       destroyed  137 · dented   43 · cracked    0
      WALL/wood        destroyed   38 · dented   32 · cracked    0
    [E-EMBER] 290 ember(s) queued
    [E-WAVE] frames 1-5, apply 5.2 / 7.6 / 11.0 / 1.3 / 0.2 ms

Hand-named (rotation-proof) captures:
`e_ember01_wood_blast_peak_2026-08-13.png` — the detonation at full burn;
`e_ember01_wood_embers_settled_2026-08-13.png` — ~2.2 s later, scattered coals
on the wall face reading over the soot, the floor's own already cooled. That
asymmetry is not luck: `EmberOverlay.height_bias_low = 0.65` shortens the
lowest embers on screen, which is "heat rises" behaving as written.

`detonation_plan_selftest.gd` tests 7 and 8, both against the real map: 112
embers at a second wood GU, each one verified to be a survivor, 6-adjacent to a
hole this same blast opens, on a material with `flammability > 0` read from the
**live registries**, never duplicated, carrying wood's own value as
`duration_scale` — plus the negative case (holes touching no combustible voxel
queue zero embers), and every per-voxel smoke entry carrying a real material.

**Test 7 failed on its first run** — 10 embers reported on "non-combustible"
material. Diagnosed rather than relaxed: the test's own cell→material ground
truth walked `Slice`es and `Slab`s and omitted `JunctionColumn`, the third
container class, and 4 of PLAYGROUND's 20 columns are wood (measured, along
with 0 cell overlaps between the three classes). The code was right; the test
was incomplete, and the fix was completing the ground truth.

## 5. Verification

    project_lint.py          ✅ PASSED
    check_invariants.py      ✅ OK
    gen_codemap.py --check   ✅ clean
    run_selftests.py         ✅ 35 clean, 0 failed (plan selftest 16/16 PASS)

## 5b. E-EMBER-02 / E-EMBER-03 — the same session, after the Director saw it live

**E-EMBER-02.** Director: *"o foguinho... queremos que suba rapidamente pra cima
verticalmente e ao longo da parede, e apague em seguida, deixando para trás
voxels bem vermelhos e brilhantes… os voxels também se propagam para cima, de
maneira mais comedida e errática… ao apagar, cada voxel gera mais fumaça
escura."* Plus a correction: the colour order runs yellow-hot → red, not the
red → yellow first written.

**The Director's own diagnosis was the key**: *"talvez já esteja funcionando, mas como o
foguinho está por cima eu não estou vendo."* Right. The fireball and the scorch
embers share one overlay and one z_index, and at 46 px/s a burst ember climbed
~46 px in its whole ~1 s life — under two voxel steps. The fire sat on the
crater covering the thing it existed to reveal. Fixed by MOVING it (rise → 150
px/s + per-ember jitter), never by shortening it: P-STROBE tuned that lifetime
on purpose.

Shipped inside the existing structure: the per-ember cooling ramp; the upward
creep (one level at a time, stopping at the first that does not catch, FNV-1a
per cell because `build_plan()` is pure and the filmstrip replays it); a
trailing `delay` on `add_ember()`; a darker, ember-sized extinguish puff.

**The filmstrip rejected the first attempt, which is why it was run.** Every
seed igniting on the same frame at the same hot tone made ~137 ADD circles sum
into one molten sheet the shape of the crater — the old random per-ember hue had
been supplying the t=0 variety and the ramp removed it. Fixed on perceived
DENSITY, not count: radius 14→9, halo reach and alpha down, value 0.85-1.0 →
0.60-0.85, and a deterministic 0.45 s stagger across the seeds' ignitions.

**E-EMBER-03.** Director: *"a gente conseguiria passar de amarelo pra vermelho
vivo mais rápido, antes de apagarem? De resto ok."* Both ramps were linear in
`t`, so the ember drifted through orange and the vivid red never got its own
stretch. Hue and value are now eased in opposite directions — hue exponent 0.40
(62% of the way to red by 30% of the life), value exponent 1.80 (93% of full
brightness at that same point). Easing the hue alone would have delivered a red
that was already dim on arrival.

Evidence: `e_ember02_filmstrip_wood_2026-08-13.png` (ignition, ~0.6 s — a
36-frame strip structurally cannot reach the cooling), `e_ember03_vivid_red_70f`
(~1.2 s, vivid), `e_ember02_wood_cooling_120f` (~2 s, deep red) and `_240f`
(~4 s, out — charred wall, soot around the crater). Plan selftest 25/25.

## 6. What's open

1. **Blast DUST / SPARK / CHIP debris** (wood splinters included) still never
   fires for explosions, only firearms. No longer blocked by anything —
   E-SMOKE-TINT-01 demonstrated the threading — just unrequested.
2. `flammability`'s magnitude only scales ember duration today. Every other
   consumer (burning through, blocking light until burnt, opening passages) is
   the **materials milestone**.
3. Carried over unchanged: `weapon_fire`'s repaint has no deterministic pixel
   gate (Director's own call: not worth closing); SFX for the throw; junction
   column damage-texture orientation; junction columns + rotation-persistence,
   moot while rotation is off.
