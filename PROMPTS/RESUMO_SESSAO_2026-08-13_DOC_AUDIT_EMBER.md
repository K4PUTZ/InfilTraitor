# RESUMO_SESSAO — 2026-08-13 (doc audit → the whole destruction/VFX close-out)

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

## 5c. The rest of the session — VFX foundation, plan closure, runtime hardening

**E-AUDIT.** A sweep of the explosion mechanism for loose ends found four, the
worst being `blast_burst_ember_spread_px` — a tuning field whose declaration
documents "the one relationship worth preserving when retuning" and which **no
code reads**. The `slab_full_color` shape exactly, and the E-EMBER-02 rise
retune had walked straight past it. Now an `assert` (stripped in release).

**E-DEBRIS-01.** Dust, sparks and wood chips finally reach explosions — the gap
§5 flagged on 2026-08-07 with an explicit "ask first". The load-bearing decision
was a UNIT CONVERSION, not taste: `vfx_*_chance` is per destroyed voxel and was
calibrated against a firearm (a handful of voxels); a grenade destroys 243-500.
Blast rates are one documented fraction of the firearm ones
(`blast_debris_rate_scale`). A prediction made and disproven, kept in the code:
sparks looked unreachable for metal (destroy_factor 0.03) — but
`apply_crater_damage()` ignores destroy_factor, so a metal FLOOR loses 143.

**E-SPARK-CAP → E-SPARK-01.** Director: *"o metal deveria gerar bastante faísca
num tiro da shotgun."* It generated none. Two problems, and the second was real:
the capture harness waited a fixed 30 frames while a spark lives 0.2-0.4 s (so
firearm VFX had been effectively uncapturable for as long as the action
existed); and `_dispatch_destruction_vfx()` runs off `voxel_destroyed`, which a
shotgun on metal (punch 0.29-0.39) or stone (0.42-0.53) **structurally never
reaches**. Those two produced nothing while wood got everything — the exact
inverse of the intent, and the VFX half of the gap D33-SOOT-01 closed for soot.

**E-SPARK-02/03/04, E-DUST-01, E-MUZZLE-01/02.** Sparks: longer-lived, faster, a
tapered fading trail whose length follows the particle's own speed, no gravity,
per-material ladder (metal a lot → wood none). **Dust was invisible BY
CONSTRUCTION** — 0.9-1.1 s before falling, alpha ramping 0→1 *while* falling, 1.6
px specks. Muzzle flash + powder smoke built from the project's own overlays per
E-NATIVE-01 rather than from the reference sprite sheets the Director shared.
Three measured mistakes on the way, all fixed: the flash inherited the cooling
ramp (red fireball), inherited `glow_radius` tuned down for crater coals, and —
misdiagnosed twice — the black hole in its middle was `EmberOverlay`'s dark
BURN-OUT puff, not the muzzle's pale smoke.

**Both master plans CLOSED**, Director-ratified. The sweep found six items listed
as open that were already closed or moot in code, and one doc instruction telling
implementers to snapshot `_base_soot` — a field D24 deleted in that same
document. The GPU-flush safeguard closed WON'T DO: folding the flush into
`apply_damage_voxel_swap()` would flush once per VOXEL and undo PERF-02 A1.

**E-DEBUG-RAY removed**, with `AnimatedRayOverlay` (E-RAY) alongside it — it was
that overlay's only consumer. Checked whole-repo first, per the 2026-07-12
lesson; one trap cleared on the way (`DebugRayOverlay.clear()` clears the SHARED
ray overlay, but both call sites already clear it directly on the line above).

**REG-STRONG-01.** `Registries` held every registry through a `WeakRef`, and
nothing else holds one — so each was collected between accesses and REBUILT FROM
DISK. Measured on one throw: bomb registry **4×**, material registry **2×**. The
fix was already in the same file six lines down (`_frame_cache`, FRAME-MEM-01).
Verified: one load each, and the process still exits 0 with no SIGABRT.

**RUNTIME-GUARD-01 / W-GUARD-01.** `DetonationChoreographer` is RefCounted and
lives across its awaits, but `VoxelRenderer` is a child of the room and
`load_map()` builds a new one. The class header claimed this was safe — true for
QUIT, false for RELOAD. Both await sites now revalidate and abandon loudly;
`TestZoneController.clear()` drops the active choreographer. Same treatment on
the firearm path, plus its busy-latch rejection made loud (a silent guard on a
self-clearing latch is indistinguishable from a broken one).

## 6. What's open

1. **NEXT SESSION — firearm pre-production (W-PRECOOK).** Measured: a shot's
   whole cost is `_repaint_voxel_light_buckets()`, **~310 ms of synchronous CPU
   for nine voxels**, while a 453-voxel blast commits in 0.5 ms because its light
   field is resolved during the throw. The repaint is load-bearing (D24 derives
   bullet soot from it), so it is not a deletion. Two routes and the numbers are
   written up as `WEAPON_MASTER_PLAN` §0.
2. **Also next session:** verify the Baking System cache and the decals against
   the second texture set the Director is preparing.
3. `flammability`'s magnitude only scales ember duration today. Every other
   consumer (burning through, blocking light until burnt, opening passages) is
   the **materials milestone**.
3. Carried over unchanged: `weapon_fire`'s repaint has no deterministic pixel
   gate (Director's own call: not worth closing); SFX for the throw; junction
   column damage-texture orientation; junction columns + rotation-persistence,
   moot while rotation is off.
