# LAUNCH_MASTER_PLAN
## The launch milestone: what the game needs around it to ship — v0.2

> 🟡 **v0.2 · 2026-10-22 · NOTES ONLY, nothing designed in detail, nothing built.** v0.2: the town is the player's city and the open question of a
> city that lived a real disaster (§1); L4 updated to the leagues of 4 x 30; L7, the community-moderated forum. v0.1 (2026-10-21): opened by the Director ("milestone de Lançamento (a criar)") to
> collect launch items as they come up. Each row records the Director's note, then Claude's remarks (risks, canon it touches, the owner plan). A row
> becomes work only after the Director ratifies it; detail goes to the owner plan named in the row (`cross-milestone items go to their owner plan`).

## 1. Partnership with those affected by the dam disasters (proposal)

*(Director, 2026-10-21: "propor alguns itens como camisetas in-game, e outros mecanismos de distribuição de recursos para as vítimas. Vamos deixar como
proposta de parceria na milestone de Lançamento".)*

- **Charity items:** in-game items (e.g. T-shirts) whose revenue goes to the people affected; possibly a donation link. Partner candidate: an association
  of the families and people affected (e.g. AVABRUM, Brumadinho), approached BEFORE launch, with transparent accounting of what is passed on.
- **How the tragedy is presented (Claude's advice, accepted as direction 2026-10-21):** no real images, names or dates in the game or its marketing; the
  fiction names no real case, and the town is the city the player chooses (`DESIGN_MASTER_PLAN` §2.6, ruled 2026-10-21; this line said "a fictional
  town" before that ruling); a short, sober dedication in the END credits about tailings-dam safety and the victims
  of Mariana (2015) and Brumadinho (2019); the trailer sells the spy thriller, never the mud. **Why:** the real collapses were not sabotage, the families
  still fight for accountability, and real photos in a monetised game read as opportunism.
- **Open — a player whose city lived a real dam disaster (Director, 2026-10-22):** *"Fica a dúvida se não seria ainda mais desagradável pro jogador
  de Brumadinho não poder usar a cidade dele no jogo por causa do ocorrido."* Claude's recommendation: keep the dam in every city, as ruled; take the
  question to the association before launch (it is theirs to answer, and the partnership already means approaching them first); keep the backup setting
  (`DESIGN` §2.6: refinery or hydro plant) as a tool, swapped silently if they ask for it, never a "your city is not allowed".
- Owner when it becomes work: `COSMETICS_MASTER_PLAN` (the items, C1/C8) + a legal / store review (charity claims have store rules).

## 2. Notes for the launch (Director, 2026-10-21)

| # | Director's note | Claude's remarks | Owner plan |
|---|---|---|---|
| L1 | Extend non-playable outside tiles around the map as scenery (blurred?) | A ring of cheap backdrop (low-detail meshes or impostors, fog / depth fade instead of a screen blur: a blur reads the screen, ~250-295 MiB on the Galaxy, `PERFORMANCE_BUDGET`). Must fit PB-7's segment budget | `SURFACES` / `PERFORMANCE_BUDGET` |
| L2 | A tutorial in map stretches, each teaching one position, skill, shadows, weapons, new feature | Matches the canon: the campaign IS the tutorial, one mechanic per chapter (`DESIGN` §2.2); the stretches can be segments (§14) | `DESIGN` §2.2 / `MAP_MASTER_PLAN` |
| L3 | Encourage players to upload their own art (photos of wood, stone…) to customise their game; unlocked by tier / level | Fits §17's local, cosmetic drop-in content. A photo must become OUR facade format (1024x512 grayscale, B2), so the game needs an in-app converter; it stays LOCAL (seen only by its player) unless curated (`COSMETICS` C10); the merit gate is SURFACES' late "customisation" item | `SURFACES_MASTER_PLAN` / `PROP_PIPELINE_PLAN` |
| L4 | The player sees his avatar and tier; his model appears on the week's ranking board; groups of 10-30 players per faction competing for the lead; the top 3 win items, each team gets a prize by performance. **Revised 2026-10-22:** many simultaneous leagues of up to 30 characters per faction (4 x 30 = 120), one character per faction per player; invite friends; bots fill empty seats, shown as bots; prizes to humans only; the ranking is mostly there to show the avatar | Must keep `COSMETICS` §4's rules: score by normalised missions, not currency nor character level (the paid 2x), a per-player cap, prizes cosmetic, nothing lost by missing a week (§16). The board shows the master model (C6) | `COSMETICS_MASTER_PLAN` §4 |
| L5 | Evaluate swapping stats for cosmetics: give an item the look of another item already owned for the same slot (Far Cry 6) | That is a TRANSMOG: the item keeps its effect and wears another's look. Compatible with D36 only if the readability cues survive (C3). Cheap: an instance attribute `appearance_uid` (C1) | `COSMETICS_MASTER_PLAN` C1/C7 |
| L6 | A realistic world map, using Google Maps or the players' input, to generate locations | ⚠️ Google Maps' terms do not allow storing or deriving our own map from its tiles or data, and it is paid per use. The open path is `COSMETICS` §6 (Natural Earth, NASA Blue Marble, GeoNames); OpenStreetMap (ODbL: attribution and share-alike on derived DATA) if a city's streets are ever needed for generating locations | `COSMETICS_MASTER_PLAN` §6 |

| L7 | (2026-10-22) A forum, even a rudimentary one, moderated by the community itself through privileges earned by participation, like Stack Overflow | Free text, so `DESIGN` §16's free-text rule governs it (a 16+ audience, minors included): earned privileges ARE the reports-and-review layer that rule asks for, but it still needs automatic filters and an escalation path to staff before it opens to 16-17-year-olds. In-game or on the web: open | `DESIGN` §16 |

## 3. Open

Every row above is a note: scope, order and whether each ships at launch are the Director's call.
