# Session summary 2026-11-17 — the H1 (pistol-hold) family and the suppressors

MOVEMENT §11.6 step 2 CLOSED for H1 on both figures. Commits `8845b6b1` .. `64fc92a6` (+ this docs commit).

## What is built

- **The lab files** `ASSETS/MODELS/fit/FAMILY_H1_aim_<MALE|FEMALE>.blend` (untracked, the Director's): every H1 model in the
  aim, sized by hand by the Director. `tools/asset_generation/weapons/family_lab.py`:
  `build` (the female's file from the male's read-back), `render` (red bead on each muzzle), `readback` (Umeyama fit of each
  model to its place, relative to the reference pistol), `swap` (replace a model in a file with the Director's version).
  Backups in `temp/family_lab/backup/`.
- **14 weapon rows** written by `family_rows.py <male rb> --female <female rb>`: `pistol_compact`, `pistol_service`,
  `pistol_tactical`, `revolver` (now `held_as: pistol`), `revolver_snub`, `revolver_long`, `taser`, `hand_crossbow`,
  `flare_gun`, `scifi_pistol_a/b/c`, `ray_gun`, `grapple_gun`. Each is its own weapon (same mechanism, own stats later).
  The grip is EXPLICIT per figure (`model.held_like.figures.{male,female}`: scale/pos/quat relative to the reference pistol;
  Director: both checked by hand, none inherited; a missing figure loads with a warning and identity). `model.muzzle` per row.
  Non-bullet rows (taser, crossbow, flare, grapple) do zero wall damage and name their projectile.
- **Engine:** `WeaponDef.held_rel_for(fig)`, `WeaponRegistry.family()`, `ActorMesh3D` swaps the hand model while the gun is
  hidden and fires from the row's muzzle; key **2** again cycles the family.
- **Suppressors** = muzzle attachments (`attachments/*.json`, `AttachmentDef`, `AttachmentRegistry.fitting`), only on the four
  bullet pistols. Two from the lab (`suppressor_a/b`), six by script (`tools/asset_generation/items/suppressor_variants.py`:
  round_short, round_long, square, square_long, triangle, hex). Mount relative to the reference pistol's muzzle, re-scaled
  per pistol; the shot leaves from the attachment's front. Key **5** cycles them (`ui_weapon_attachment`, recorded in
  `docs/technical/INPUT_REFERENCE.md`; the in-game Controls panel lists it from the InputMap).
- **Takes** (PLAYGROUND): `h1_family`, `h1_family_shot`, `grapple_shot`, `suppressed_shot`, `suppressor_variants`; rail
  `h1_family_rail`. All filmed on both figures (`INFILTRAITOR_TRIPO_FIGURE=female`).

## Rulings of the day

- Grapple: BOTH mechanisms — the held pistol (H1) and a left-wrist launcher in the blade's place (ITEMS §2.5, Q3).
- The Director's own crossbow and grapple replace the earlier ones (`hand_crossbow.py` is SUPERSEDED, writes `_v1_script`).
- Each suppressor gets its own attributes (silencing, damage, accuracy); every weapon's attribute sheet is **GAMEPLAY**.

## Owed

- Taser skin detail; crossbow string + dart in flight; grapple hook + rope + reel; each weapon's own firing effect (all use
  the pistol's powder flash today).
- Suppressors look thin in game (they inherit suppressor A's scale): the radius is one line in the script if wanted.
- The other hold families need their aim poses first.
- Attribute sheets: GAMEPLAY milestone.
