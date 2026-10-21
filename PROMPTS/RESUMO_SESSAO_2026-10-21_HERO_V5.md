# RESUMO DA SESSÃO — 2026-10-21 (2) — HERO v5: draped cloth, the hat becomes the mask, a face, a shirt and a tie

**Branch:** `claude/r3d-actors-y5r8hs` (commits land on `origin/main`). **Decision:** `ACTOR_MASTER_PLAN` **D77** (D76's tipped hat superseded).
**Previous record:** `PROMPTS/RESUMO_SESSAO_2026-10-21_CHARACTER_HERO.md` (v1-v4, the Moto numbers, the reproduction recipe).
**Everything below was built and rendered in Blender (EEVEE) this session. Nothing was imported into Godot or run on a handset: the Director said
"não se preocupe em testar por enquanto".**

## 1. What the Director asked for

The overcoat "still looks odd, somewhat inflated"; **the mask is the top of the hat, which comes down in front and lights the eyes, so in stealth mode he no
longer has the hat**; a face more like a protagonist, "discreet but reasonably handsome", maybe a beard; "a touch" on the tie and the shirt so the suit
reads; take the recommended decisions, best quality without hurting performance.

## 2. What changed (all in `tools/asset_generation/hero/hero_tailor.py`, v5)

| Area | v4 | v5 |
|---|---|---|
| Cloth | the body offset along its normals: every muscle inflated into the coat and the jacket | `drape()`: offset once, then smoothed and pushed back out of the body to a gap, 30-40 times: rests on crests, spans hollows |
| Coat over the pack | a fixed "hump"; the pack's corners and side pouches came through as soon as the rig posed | drapes OVER the pack (`over_pack()`), the hump leans on `spine_03`, pockets moved to the pack's back face, a lining (cull_back) |
| Coat front | lapels + two single-quad "flaps" (read as loose cards) | wider lapels and the standing collar; flaps removed |
| Fedora | round crown: the FOREHEAD poked through its front (the pale patch on the band since v3) | oval like the head, tapered, teardrop crease + front pinches, rounded top, snap brim; hair pressed inside |
| Mask | face plate + jaw + a tipped copy of the hat on top | `Mask_Shell` = the hat's felt as a crown over the head (crease, pinches, smooth visor), `Mask_Band` = the band slid down across the eyes with the lenses, smooth `Mask_Jaw`; no hat, no hair, no hood |
| Face | bald, white brows, the mouth open and pouty | leaner jaw (mouth untouched), firmer chin, cheekbones; CC0 `Hair_SimpleParted` dark brown; dark brows; optional short boxed beard grown from the face |
| Shirt / tie | spread collar points as two flat triangles; a flat strip tie | white contrast collar (band + leaf, points framing the knot), cuffs that follow the forearm, a pocket square; a knotted 4 mm tie, diagonal stripes, tie bar from the same texture |
| Shoes / trousers | crumpled convex hull; ragged hem cut through the instep | a parametric last (welt, toe spring); the hem cut above the instep with a break over the shoe |

## 3. Bugs found (each now a numbered trap in the script's header)

1. **Blender 5.2's `shape_key_add()` creates the key at value 1.0: v4 EXPORTED all seven expressions on at once** (smile + frown + blink + jaw_open...). Found
   by an A/B of the sculpted face (closed mouth) against the built model (open, pouty): the imported GLB listed every key at 1.0. Fixed: each key set to 0.
2. **`drape()` took the cut rings' heights after its first offset**: the neck ring tilted, `collar()` skipped the edges no longer level, and the coat's collar
   had two slits at the nape. Found by LISTING the open edges near the nape. Fixed: pins taken first.
3. **A cloth that starts inside the pack is pushed toward the body by the pack's inner face** (the first v5 coat went UNDER the pack). Fixed: `over_pack()`.
4. **A beard outline from a mask with a 6 mm step snapped to mid-edges**: a staircase. Fixed: linear ramps, so the 0.5 contour lies on the intended line.
5. **A straight lens quad on a curved band sank into it** (four dots instead of two slits). Fixed: 8 segments, each ray-cast.

## 4. Numbers (Blender, one build each)

- Master `hero_tailor5.glb`: 37 943 tris, 25 meshes, every state in one file.
- Game LOD `hero_tailor5_g5.glb` (`DECIMATE=0.2`, per-piece `LOD_WEIGHT`): **visible 5 446 tris normal (5 236 shaved), 4 904 black, 5 186 masked** (D73's ~5 k).
- Normal style: 19 visible meshes (v4: 18). The handset cost is NOT measured.

## 5. NOT done (so nobody assumes it)

- Not imported or looked at in Godot; not measured on the Moto or the Galaxy. The bench (`actor_viability_bench.gd`) was updated for the v5 piece names
  (`Mask_Shell`/`Mask_Band`, the hat / hair / beard hidden in `_mask`, a new `_shaved` suffix) but not run.
- The engine does not darken shirt / tie / trim in the black style (the previews swap the texture); open since v3.
- The mask's mechanisms (the hinge that brings the crown down, the brim rolling into the band, the cheek plates, the tie hook, the nape tether) are not rigged.
- The adapter to `ActorMesh3D` (bone and action names) is still the first job to make the hero playable (previous record §6).

## 6. Open for the Director

Beard yes or no (the file has it, `_shaved` hides it; recommended: on); hair style (`Hair_Buzzed` is the other CC0 option); the mask band grey (the hat's
ribbon, kept for identity) or black; the assumption that the brim rolls into the band.

## 7. Reproduce

As in the previous record §7, plus `HERO_HAIR_DIR=".../Universal Base Characters[Standard]/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/"`;
the default `OUT_SUFFIX` is now `_tailor5`, and the game LOD is `DECIMATE=0.2 OUT_SUFFIX=_tailor5_g5`. Previews are EEVEE (`PREVIEW=full|quick|none`),
including a 132x200 render at the game's size per style (`t5_<style>_game.png`).
