# COSMETICS_MASTER_PLAN
## Cosmetic items, ownership, the backpack, contributions, the weekly faction war and the world map — v0.6

> 🟡 **v0.6 · 2026-10-23 · PLANNING ONLY, nothing built.** v0.6: **the Agent's faction dress (§9, `ACTOR` D78):** a faction is PACKAGING on
> the same dress (colours, symbols, pins, accessories), the banner behind the ranking portrait completes it; accent zones, the Director's
> palette families measured for colour-blind players, the signature accessory per faction, the styles; a character's faction now comes from the BACKGROUND stated in the
> deposition (§2, `DESIGN` §15); every faction's field officers wear an overcoat (§8.3).
> v0.5: §8 crossed with the plot's closed main arc (`DESIGN_MASTER_PLAN` §2): the
> sub-leaders rise to the leaders' priority, crowd sets, three cast cuts ruled (no child base, the rescue only as scenery, a 2D TV anchor), and the
> first slice is the opening every route shares (§8.5). The props side of the same analysis is `PROP_PIPELINE_PLAN` §9.
> v0.4 (2026-10-22): v0.4 (Director's review of the plot): a player has up to FOUR characters, one per faction,
> whose faction never changes (§2); the permanent tattoo of the campaign's ending (§3); many simultaneous leagues of 4 x 30 characters, bots shown as
> bots, prizes to humans only (§4); the reporter (§8.4).
> v0.3: four factions (§2), the 16+ audience (C11, §4), the model slot inventory (§8).
> v0.2 (2026-10-21): v0.2: the factions are decided in `DESIGN_MASTER_PLAN` §2.1/§2.6 (§2 here); the world map, city only, no photo (§6).
> v0.1: Opened by the Director after the hero v5 (`ACTOR` D70-D77): *"o que mais nosso
> sistema de objetos precisa ter? Uma hash única por player, a questão da exibição na mochila [...] Vamos chupar o mecanismo do Team Fortress 2, ou
> possivelmente usar alguma plataforma tipo steamworks ou unreal pros usuários contribuírem"*; then *"vamos criar o plano de cosméticos, e incluir mais
> alguns detalhes no player pra vender, como tarja de capitão no braço com algum símbolo, de repente um banner atrás do player [...] pelo menos 3
> [facções] [...] cada player associado com um objetivo maior de cada facção, que muda semanalmente, e a gente distribui prêmios pros vencedores."*
> Every row below is a **PROPOSAL (Claude)** until the Director ratifies it; the status column says which.

**Reads first:** `docs/DESIGN_MASTER_PLAN.md` §16 (monetisation: user-friendly before money-friendly, no purchased loot boxes, no FOMO, the core game must
not need an online service, no PvP planned) · `ACTOR_MASTER_PLAN` D36 (cosmetics express state, never grant it), D63 (a faction is a palette), D66/D69
(slots, data-only `.iprop`, fallback to the generic), D70-D77 (the hero and his costume), D74 (stock base in the APK, extras at first load) ·
`PROP_PIPELINE_PLAN` (the validator, the slot contract).

---

## 0. The shape of the system (one picture)

```
CONTENT (us + contributors)           CATALOG (server, versioned)            OWNERSHIP (server, per account)          CLIENT (draws only)
pieces/<slot>/<id>/                    item definitions: id, slot, models,    item instances: uid, def, owner,          downloads by manifest,
  <id>.blend  (editable source)  --->  styles, quality, allowed attributes --> origin, attributes (paint, counter,  -->  checks hashes, assembles
  <id>.glb / <id>_g5.glb               + signed asset manifest (hashes)       name), equipped loadouts                  on ONE skeleton, falls back
  <id>.json   (slot, covers, styles)                                          signed by the server                      to the stock piece
```

The rule underneath everything: **the server says what a player owns; the client only draws it; a cosmetic never changes the game** (D36, D66).

---

## 1. Decisions (proposed)

| # | Decision | Why | Status |
|---|---|---|---|
| **C1** | **Definition vs instance (the TF2 item schema).** A *definition* is the catalog entry, the same for everyone (`def_id`, slot, models, styles, quality, allowed attributes). An *instance* is what a player owns: a 64-bit `uid` minted by the server, `def_id`, `owner`, `origin` (bought / earned / gift / event / contribution), `created_at`, and its own attributes (paint, counter, custom name). **The "unique hash per player" is this `uid`, minted and signed by the server**; a hash computed on the device proves nothing (anyone can forge it). | Everything else (trading later, counters, gifts, refunds) hangs off instances; a definition-only inventory cannot express "this one, with this paint, that counted 300 knockouts". | proposed |
| **C2** | **The server is the authority; the client draws.** The inventory arrives signed; equipping is a request; what OTHER players see (ranking, profile, lobby) is read from the server, never from the sender's client. A modded client only changes what its own player sees, which is harmless because of C3. | Mobile clients are fully hackable; only an authority off the device can hold ownership. | proposed |
| **C3** | **Cosmetic only, forever** (D36, D66: gameplay comes from the SLOT, never the model). No item changes a cone, a noise, a hitbox or an AP. **Corollary for readability (D36's second half):** any state the game must show (stealth, mask on, eye glow) has a non-purchasable cue (the eyes, an outline, the HUD), so a cosmetic can never hide it. | Keeps the shop honest and makes cheating on cosmetics pointless. | proposed (extends ratified D36) |
| **C4** | **Slots and pieces** (as proposed 2026-10-21 for the hero): one base (body + skeleton + animations), every piece a separate file skinned to the same 65 bone names, one piece per slot: `hat`, `mask`, `hair`, `beard`, `shirt`, `collar_trim`, `tie`, `jacket`, `coat`, `trousers`, `shoes`, `gloves`, `pack`, **`armband`**, **`pack_pennant`** (§3). Each piece carries a small JSON: slot, styles it appears in (normal / black / mask), the body REGIONS it hides (`torso`, `arms`, `legs`, `feet`, `head`), its materials, its LOD. A **loadout** is `{slot: uid}`. | Swapping, buying, dropping and contributing all reduce to "a file that fits a slot". The base must be split into regions so a piece can hide what it covers (no skin through cloth). | proposed |
| **C5** | **Asset integrity.** Every downloadable file is listed with its SHA-256 in a manifest the server signs (fits D74's first-load download). A file whose hash does not match is not loaded: the slot falls back to the stock piece (D69's ladder). Contributed models enter as data only (`.iprop`, D66: never a `.tres`/`.res`, which can carry a script). | A tampered or truncated download must never crash the game or carry code. | proposed |
| **C6** | **Two sizes of every piece: the master for the backpack and the shop, the ~5k LOD for play** (D73). The backpack / shop / preview is its own SCENE (turntable, zoom, style switch, "try it on" = the assembler putting the piece on the player's own hero). Icons and thumbnails are pre-rendered at build time and served from the CDN; masters download on demand when a piece is inspected. | A list of 200 items cannot load 200 masters; the game figure is ~190 px and does not need them. | proposed |
| **C7** | **Attributes that fit a stealth game.** **Paint** = a shader parameter (free in memory; D63 already makes a faction a palette). **Counter** ("Strange" in TF2): an item counts something the player is proud of (guards knocked out unseen, missions without an alarm, captain's objectives won), shown in its name and on the profile. **Styles** = variants of one instance (beard on / off, coat colour). | Cheap to build, high perceived value, no gameplay effect. | proposed |
| **C8** | **Selling: direct purchase + items earned by playing. No paid random boxes** (§16: no purchased loot boxes, a company rule at any age rating). The status of play-earned random drops stays §16's open question. Mobile stores require their in-app purchase for digital goods (~15-30% fee) and restrict real-money trading; **trading and a market are deferred** (they attract fraud and regulation) but C1 does not prevent them later. | Store rules, the age rating, and §16's company identity. | proposed |
| **C9** | **Platform: our own backend or a hosted service with inventory + economy (PlayFab, Nakama or similar), behind OUR item schema.** Steamworks Inventory / Workshop only exist on Steam, so they cannot own a mobile player's inventory (a PC version could bridge later). Unreal's Fab is a marketplace for developers, not a player-contribution pipeline, and the project is Godot. | Mobile-first; keep the data model portable so the service can change. | proposed |
| **C10** | **Player contributions (TF2's Workshop, adapted).** A web portal with the kit (skeleton, slots, budgets, material rules); automatic validation by our exporter and `PropValidator`; **human curation before anything reaches the shop** (TF2 ships only what Valve picks); a contributor agreement (licence, revenue share, what happens if the author leaves); moderation and reports (trademarks, offensive content). Accepted items are re-exported by our pipeline, never shipped as the author's raw file. | Quality, safety and legal clarity; the raw file is the attack surface. | proposed |
| **C11** | **Privacy and accounts.** The minimum personal data (LGPD / GDPR); the game is rated 16 (§16): an age gate, privacy-protective defaults for 16-17-year-olds (minors) and §16's social defaults come before any social surface. Purchases survive a reinstall through the account, not the device. | Legal, and a lost purchase is the worst support ticket. | proposed |

---

## 2. Factions — DECIDED in the narrative (2026-10-21)

**The FOUR factions are `DESIGN_MASTER_PLAN` §2.1's (revised 2026-10-22):** the **Federal Police** (the fictional **FID**, Federal Inquiry Directorate), the
**Militia** (**Calm Waters Security**, a private military security company), the **Traffickers** (the **Bunsen Burners MC**) and the **Corporation**
(GRUB DRILL's executives and minority shareholders). The names were ratified on 2026-10-22 (`DESIGN` §2.7: names, mottos, leaders and successors;
§11.2: rank names per faction). Each is guilty of a share in the dam's fall (§2.6), so no faction is
the "good" one, and the Agent betrays all four. Balance: §2.1 (one axis each, the same threat budget, measured per faction and per route).

**Four characters, one per background (Director, 2026-10-22; revised 2026-10-23; `DESIGN` §15):** the BACKGROUND stated in the deposition
(`DESIGN` §2.2: a lifelong policeman, a former biker, an army veteran, a former private security guard) creates the character and ties him to one
faction for good (FID, Bunsen Burners MC, Calm Waters Security, the Corporation), the one shown in the rankings and his league; a player has at
most four, each levelling on its own. Allegiance is therefore per CHARACTER, never per account, and there is no faction switching (supersedes
v0.2's "first allegiance + cooldown"). **Consequence for items (Claude):** items belong to the account (C1) and are equipped per character; the
faction's colours and symbol are filled in by the game on any piece (§9), so no piece is "for one faction only".

## 3. The new items the Director asked for

| Item | Design (proposed) | Cost |
|---|---|---|
| **Armband** (`armband` slot) | A band on the upper arm (the costume already had one in D70's first description: "blue shirt and armband"). Its SYMBOL is a texture layer chosen separately: the player's faction emblem, a rank, an event mark. **The "captain's armband"** is the armband earned by the weekly war's top contributors (§4), shown only for that week's winners and kept as a commemorative variant afterwards. In the black style it goes dark with the suit (D70), and it is never the only cue of anything (C3). | ~100 tris; the symbol is one shared atlas (no extra draw call per symbol). |
| **Banner** | **Not on the figure in play:** D70 rules out capes, and a flag behind a 190 px figure hurts readability and the stealth silhouette. Two places instead: (1) the **profile / lobby / ranking BACKDROP**: a large banner behind the hero in the showcase scene (faction colours, the season's art, the player's emblem); **ratified as the ranking portrait's complement (Director, 2026-10-23: "nos retratos do ranking vai ficar mais evidente porque vamos usar o banner no fundo")**; (2) in play, a small **pennant on the pack** (`pack_pennant`), stowed in the black style. | The backdrop costs nothing in play; the pennant ~60 tris. |
| **Emblem** | The symbol itself (shown on the armband, the banner, the profile card). Earned, bought or contributed; a definition like any other (C1). | A texture in the atlas. |
| **Tattoo** (Director, 2026-10-22) | The mark of the campaign's ending (`DESIGN` §2.2): killing the reporter or letting him live leaves a different tattoo, **permanent on that character instance** (not on the player), and everyone can see who is "good" or "bad". **Rules (Claude, proposed):** earned only, never sold, never removed or swapped for money (otherwise a moral status is for sale, §16); a skin LAYER on a body region (`tattoo`, §8.2), not a mesh; shown on the profile, the ranking and the showcase, and in play wherever that region's skin shows. **Open:** where on the body (the Agent wears gloves and a mask: the neck, the forearm?). | A texture layer in the skin atlas. |

---

## 4. The weekly faction war (the league: Director, 2026-10-22; the rest proposed)

**The league (Director, 2026-10-22).** Many simultaneous leagues, not one for everyone: a league holds up to **30 characters per faction, 120 in all**
(league 00001, while another 120 play in league 00002, and so on), and nobody can predict which faction wins each one. Each of a player's characters
(§2) plays in a league, so he can win with all four or lose with all four. A character's Freelance missions count toward its faction's points in its
league; at the end of the week the faction with the most points in each league wins and reaps the prizes, **the bigger contributors taking the larger
share; prizes go to humans only** (*"Os prêmios são dados somente aos melhores humanos"*). Proposed on top (Claude): a weekly objective per faction
(e.g. "the Police: complete 1 500 missions without an alarm", "the Corporation: disable 2 000 cameras"), re-targeted from the measured balance
(`DESIGN` §2.1), and the **captain's armband** for each faction's top contributors the next week.

**Filling a league (Director):** the idea is to invite friends; **bots complete empty seats and are shown as bots**; they raise the points average but
do not change the result significantly, and never receive a prize.

**Absence is the player's right (Director):** a player may hurt his teams by not playing, but idle players exist on every team, so with 30 per side it
evens out; whoever comes in every Sunday wants to play. **The real challenge is a class left empty:** a league where everyone plays style X or Y and
class Z has nobody. (Claude: matchmaking fills each faction's 30 seats with characters of that faction and bots cover a short class; a class short in
every league is a balance signal for its kit, measured as §2.1 asks.)

**What the ranking is for (Director):** mostly to show each player's avatar (the master model, C6).

**What §16 forces on it (ratified canon), and how the proposal complies:**

| Canon (§16) | Consequence for the war |
|---|---|
| No FOMO, no punishing a missed streak, no fabricated urgency | Missing a week loses nothing; prizes are **cosmetic and commemorative**; every weekly cosmetic returns later by another route (no item removed only to force a purchase). |
| The core game must not need an online service | The war is an online LAYER on top of offline play: missions played offline count when the device syncs (with validation, see below); nothing in the single-player game depends on it. |
| Paid acceleration (the permanent **2× currency** multiplier) is accepted because there is no PvP | **The war IS a competitive surface** (§16 asks for an explicit revisit). Proposal: faction score counts **missions and objective actions, normalised**, never currency nor character level (a payer levels faster), so the 2× boost buys no war advantage; a per-player weekly cap stops one player from carrying a faction. |
| No PvP planned | Factions compete through a shared score, never by fighting each other. |
| A 16+ audience, minors included (§16) | No gambling mechanics in the prizes; no real-money value; the boards show nicknames and avatars, never a player's city. |

**Anti-cheat:** an offline client can claim anything, so the server validates what it counts: plausible mission durations and outcomes, the per-player
cap, signed mission seeds where possible, and outlier review before prizes are paid. **Size:** a league seats 30 per faction by construction, so the
biggest faction can no longer win by numbers alone (v0.2's per-player average is no longer needed).

**Switching faction:** none: a character's faction never changes (§2; supersedes v0.2's cooldown).

---

## 5. Open questions for the Director

1. ~~Which factions~~ — **decided** (§2): four since 2026-10-22: the Federal Police, the Militia, the Traffickers, the Corporation; a league is
   4 x 30 = 120 characters (§4).
2. **Prizes:** cosmetic only (armband, emblem, banner, paint), or also currency? (Currency in a competitive prize interacts with the 2× boost.)
3. ~~The banner~~ — **the backdrop behind the ranking portrait is ratified** (Director, 2026-10-23, §3, §9.7); the pack pennant stays proposed.
4. **Backend:** a hosted service (faster) or our own (control, cost at scale)? Decides nothing in the data model (C9).
5. **Contributions:** revenue share or a flat fee, and from which milestone (contributions need the shop to exist first)?
6. **Trading between players:** never, or "later, designed" (C8)?

## 6. The world map (Director, 2026-10-21)

*(Director: "um mapa mundi, onde cada jogador se conecta [...] o mundo começa cinza e conforme os players vão se conectando ele vai sendo preenchido";
then, on the safety risk: "Vamos sem foto então, mas um nome de cidade".)*

- **What a player gives:** optionally, a CITY (chosen from a list, never an address, never a point, no photo). It is the city of his "operational
  base". Opting out is the default.
- **What everyone sees:** no individual pins in public; each region glows by how many players are based there and takes the colour of the faction that
  contributed most to it this week: the map is the weekly war's board (§4). The world starts grey and lights up.
- **What the region changes in play (proposed):** local FLAVOUR only (architecture, weather, time of day of the missions generated for that region);
  never content locked to a place (unfair, trivially spoofed with a fake GPS, and the FOMO §16 rules out). Everything here is an online layer over a game
  that works offline (§16).
- **How it is built (feasible and cheap):** not a copy of Google Earth (street-level imagery is terabytes and only exists through paid, licensed
  providers). A stylised globe / map in Godot: country and coast outlines from **Natural Earth** (public domain, a few MB), an optional low-resolution
  **NASA Blue Marble** texture (public domain), and the cities from **GeoNames** (CC-BY: credit required; ~25 000 cities over 15 000 people, names and
  coordinates, a few MB). Zoom goes from the globe to a city's outline, never to a street (which also protects privacy).
- **Privacy:** a city is coarse by design; it is stored on the server with the account (C11), shown only as an aggregate, and can be removed.

**Ruled (Director, 2026-10-21, closing the world):** the world is a **3D GLOBE with the countries' political borders only**; the CITIES where people play
light up, with an indication of how many play where; **landmarks common to every player** sit on it; **the globe is the game's world map (its mission
hub)**; **the player's starting point (his city) opens missions near it on his globe.** Claude's guard (§16: no content permanently unavailable): the home
city is a STARTING point, never an exclusive: every location is reachable by every player through the campaign and Freelance travel. The campaign itself
travels the world (`DESIGN_MASTER_PLAN` §2.6).

**Personalised by the home city (Director, 2026-10-21):** the missions are the SAME for everyone, set in different cities per player. The game asks the
player's city and names its places after the cities AROUND it (GeoNames already lists them with coordinates); it infers the country's CAPITAL and
mentions it; FLAGS in the scenery reflect the base's country; billboards and other in-world text change LANGUAGE. Claude's remarks:
- **In-world text** goes through the localization system (`tr()`, `LOCALIZATION_REFERENCE`): signage becomes keyed strings and decal textures per
  language, so a billboard is data, not baked art. The player's language and the base's country can differ (a Brazilian living in Lisbon): ask which.
- **Flags and real names attached to crimes (ratified):** a corrupt agency HQ under a real national flag, or a massacre set beside a real neighbouring town, can offend
  or be read as an accusation. Proposal: real names and flags only on neutral places (streets, stations, cafés, billboards); the factions' buildings and
  the crimes keep fictional names and emblems.
- **The dam — ruled (Director, 2026-10-21):** it happens in the player's chosen city (`DESIGN` §2.6): a fiction about a tragedy that can happen
  anywhere. **Flags only in neutral zones — ratified.**
- **Fallback:** a player who gives no city gets a default set (fictional city names, the game's own country), so nothing depends on the answer.
- **The deposition's form (Director, 2026-10-24; `DESIGN` §2.2):** the STORY's city is now the HOME TOWN on the police form that opens the game,
  filtered by the NATIONALITY: the country's cities in alphabetical order with a search field, "Custom" at the top for a free name (an empty one
  reads Lowmere). The towns AROUND it come from GeoNames' coordinates; a Custom name has none, so they come from the country's largest cities.
  **Claude's guard:** that home town is per character and stays on the device; this section's world-map base is still the account's OPT-IN (it
  may offer the form's city pre-filled, never send it without the opt-in), which keeps §16's minors rule and the privacy line above. The list is
  the GeoNames set already chosen here (~25 000 cities over 15 000 people); a smaller home town is what "Custom" is for.

## 7. Stages (once ratified; none started)

| Stage | Content | Depends on |
|---|---|---|
| **CS-1** | Split the hero into base + one file per piece, the piece JSON (C4), the editable `.blend` per piece, an exporter that never overwrites a hand-edited piece; the body cut into regions | hero v5.1 (`ACTOR` D77) |
| **CS-2** | The Godot assembler: one skeleton, pieces by loadout, hiding by regions and by style; also the adapter to `ActorMesh3D` (bone / action names) | CS-1 |
| **CS-3** | The local item schema (definitions + instances, C1) and the stock catalog shipped in the APK; the backpack / shop scene with masters on demand and pre-rendered icons (C6) | CS-2 |
| **CS-4** | Server: accounts, signed inventory, the signed asset manifest and the first-load download (C2, C5, D74) | C9 decided |
| **CS-5** | Store purchases (in-app), paints and counters (C7, C8) | CS-4 |
| **CS-6** | Factions in play (allegiance, armband, emblem, banner backdrop), the weekly war (§4) and the world map (§6) | §5 Q2, CS-4 |
| **CS-7** | The contribution portal and curation (C10) | CS-5 |

## 8. The model slot inventory (Director, 2026-10-22: "planejar todos os slots de modelos que vamos precisar construir")

Every character in the game is ONE base skeleton (the hero's 65 bones, `ACTOR` D70-D77) plus pieces in slots (C4). A faction is a uniform set over the
same slots, a rank is a few pieces on top, a cosmetic is one piece. **Nothing below is built; the hero's v5.1 pieces are the only ones that exist.**

**8.1 Bases (one skeleton, the animations shared):** male (built: the agile-B body), female (REQUIRED since 2026-10-22: the Agent may be a woman, `DESIGN` §2.7; ACTOR D70's female option; every piece of the Agent's costume must fit both bases, which doubles the fitting work of each hero piece), a heavier build for
the militia's and the traffickers' bruisers (a remodel of the same body, like agile-B). **No child base (Director, 2026-10-23):** the son appears
only in photographs (a frame at home, the grave), as a texture. There is no baby (`DESIGN` §2.6, 2026-10-22).

**8.2 Slots (each piece declares the body regions it hides, C4):**

| Group | Slots |
|---|---|
| Head | `hair`, `beard`, `hat`, `mask` (the hero's crown-mask, guards' balaclavas, helmets), `eyewear` (glasses, night-vision goggles, visors), `earpiece` |
| Torso | `shirt`, `collar_trim`, `tie`, `jacket` (suit jacket, police shirt, tactical top, biker vest over a shirt), `vest` (armour, the club's patched vest), `coat` |
| Arms / hands | `gloves`, `armband` (the captain's armband, rank and faction emblems), `watch` |
| Legs / feet | `trousers`, `shoes` (dress shoes, boots, trainers) |
| Gear | `pack` (the hero's), `belt` (holster, radio, cuffs, pouches), `pack_pennant`, `badge` (the police badge: the commissioner takes it during lap 1, `DESIGN` §2.2) |
| Skin (layers, not meshes) | `tattoo` (the campaign ending's mark, §3: permanent per character; its region open) |
| Held (attachments, not slots: `WEAPON_MASTER_PLAN`) | pistol, rifle, shotgun, grenade, the drone's controller, a phone |

**8.3 Uniform sets per faction (one set each, ranks add pieces, `DESIGN` §11.2):**

| Faction | Base set | Rank pieces (Recruit → Captain) | Must read at ~190 px as |
|---|---|---|---|
| Federal Police (the FID) | uniform shirt, trousers, boots, cap, duty belt | radio (Lieutenant up), tactical vest, a commander's jacket | the law: uniform colour and cap |
| Militia (private security) | tactical top, armour vest, helmet or cap, boots, gloves | goggles / visor, drone controller, a heavier armour | high tech: hard silhouettes, visors |
| Traffickers (motorcycle club) | patched vest over a shirt or tee, jeans, boots | bandana or balaclava, chains, a president's colours | bikers: vest and patch, loose shapes |
| Corporation (executives and their agents) | suit of their own cut and palette, earpiece | sunglasses, a briefcase, the leaders' tailoring | suits, **never** the hero's fedora (§2.1) |

**Field officers (Director, 2026-10-23; `DESIGN` §2.1, §11.2):** from Lieutenant up, and the sub-leaders with distinctions, every faction's
officers wear an **overcoat** in the faction's colours with its symbol on the back (one coat silhouette, four faction rows, §9's zones): the FID
investigators' mustard trench with blue and white, and Claude's sketches for the others in the Director's colours (§9.4; to render first): a
grey tactical coat with red and wine bands for Calm Waters, a BROWN leather duster with orange trim for the Bunsen Burners (never an orange coat:
for colour-blind players it would merge with the police's mustard, §9.4), a black coat with purple and navy for the Corporation. This coat is the
UNIFORM the Agent can steal, find or earn, and what the LED coat imitates (`DESIGN` §2.2, §10.5): it passes from afar and grants no access,
and up close his fedora, tie and shoes give him away (`ACTOR` D78; Director, 2026-10-23). Below the officers, the henchmen of each faction may take
any look, as long as the factions stay complementary and equivalent in power (`DESIGN` §11.2, §11.6).

**8.4 Named characters (a base + pieces + a face; names in `DESIGN` §2.7):** the Agent (built; Victor Rook by default), his wife Claire, his son
Leo (photographs only, 8.1), the four leaders (Commissioner Martin Graves, who is also the commissioner who takes the badge; Commander Dale Kessler; "Deacon"; the CEO
Gordon Pryce, the Senate candidate), **the four successors who take their posts** (Deputy Commissioner Irene Barrow; Duke Hardcastle; "Choirboy";
Evelyn Marsh), Marsh's counsel Prudence Vane, the official investigator who takes over the case, the front's man at Pith & Peel Holdings, **the reporter, Thomas
Marlow** of *The Sieve* (the finale; civilian clothes, no faction set), **the club's hired assassin** whose hat-mask the Agent takes ("the
Confessor", proposed; `DESIGN` §2.2), **the four faction members abroad** of the trips (`DESIGN` §2.6, proposed), and civilians (a few base outfits recoloured by the material/palette system). **The Agent himself is four instances** (one per background, §2): his
look per class is **settled by `ACTOR` D78 and §9**: the same dress, the faction as packaging.

**From the arc (2026-10-23; Claude's reading of `DESIGN` §2, the cuts ruled by the Director):**
- **The sub-leaders rise to the leaders' priority:** each is the handler on one route, stands beside the leader in lap 1, takes the post in lap 2,
  and the four stand at the memorial (`DESIGN` §2.7).
- **The leaders are bosses** (lap 2's mortal confrontations): Kessler and "Deacon" on the heavier base, Graves and Pryce on the standard one
  (proposed).
- **The spouse in both genders:** Claire, or Clement for a female Agent (`DESIGN` §2.7): clothes and a face on the existing bases.
- **Crowd sets:** the press (camera, microphone), mourners (dark civilian clothes), medical staff (scrubs), looters (civilians with a bandana;
  hostile).
- **Cut (Director, 2026-10-23):** no child base (8.1); **the rescue only as scenery** (vehicles, cordons, hoardings: no firefighter or paramedic
  set, as `DESIGN` §2.2 has it heard of more than seen); **the TV anchor is 2D** (the epilogue's bulletin is an image on the TV).
- **Out of the arc:** §11.2's Rival Agent boss has no place in the campaign as written.

**8.5 Order of work (proposed; the first slice ruled 2026-10-23):** the CS-1 split of the hero (C4) proves the slot pipeline. **The first kit is the
opening every route shares** (Director, 2026-10-23; `PROP_PIPELINE_PLAN` §9): the house, the police station, the devastated town, the power
station of the official work. Its actors: the Agent on both bases; the Federal Police set at the game LOD (the station's officers); Commissioner
Graves; Thomas Marlow at the door; **the four sub-leaders**, since the faction that approaches him outside the station follows the background the
player states (revised 2026-10-23), so all four must exist there (Claude: a consequence of `DESIGN` §2.2); a few civilians. Then the other three
faction sets, one per territory. Each set has a ~5 k game budget (D73) and is measured on the Moto before the next.

## 9. The Agent's faction dress (Director, 2026-10-23; `ACTOR` D78)

**9.1 The principle (ratified).** *"A gente não vai mudar o estilo de se vestir propriamente dito, mas a embalagem final. Nos retratos do ranking
vai ficar mais evidente porque vamos usar o banner no fundo como complemento."* The Agent's dress (D70/D77) is the same for every character; the
faction shows through colours, symbols, pins and accessories. Every character starts as an FID inspector in the investigators' mustard coat
(`DESIGN` §2.1, §10.0); his background's faction shows in the accents, the marks of his PAST. Everything below §9.1 is **Claude's proposal**
until ratified, and gets decision renders first (the four at portrait size and at the game's 132×200).

**9.2 Where the faction shows.** Every piece declares accent zones (`faction_primary`, `faction_secondary`, `faction_metal`,
`faction_emblem`); the faction fills them (D78). Sizes in play are estimates from the model (~103 px per metre for a ~190 px figure), not
measurements.

| Point | What changes | Reads in play? | Cost |
|---|---|---|---|
| Hatband | primary | barely (~2 px tall) | free (palette) |
| Tie | regimental stripes, primary / secondary (the tie already has diagonal stripes) | no | free (a stripe mask + two colours) |
| Coat lining | primary; **while he wears another faction's uniform (its coat or the LED coat), the lining keeps his own** (the traitor's true colours are inside) | when the coat opens or swings | free once the lining is its own surface |
| Pocket square | secondary (a bandana for the biker) | no | free |
| Armband (§3) | primary + emblem; the FID's carries the letters, like a real plainclothes police armband. **Part of the UNIFORM: it follows the coat he wears** (Director, 2026-10-23, `DESIGN` §2.2), so in another faction's coat it is that faction's; the renders show the background's because they show his own mustard coat | yes, side and back (~8 px) | ~100 tris |
| Pack patch (velcro) | the emblem, subdued | yes, in the black style (the coat is away) | ~12 tris |
| Lapel pin, tie bar | emblem, metal | portrait only | menu master only |

**9.3 The mark of his past (one signature accessory per background).**

| Background → faction | Signature | Notes |
|---|---|---|
| Lifelong policeman → FID | a service-star lapel pin; the lettered armband | the badge is NOT the faction's mark: every character is an FID inspector and every route loses it in lap 1 (`DESIGN` §2.2) |
| Former biker → Bunsen Burners | a wallet chain below the coat, a skull-and-flame ring, a bandana for a pocket square | a support patch grows with his standing, by the club's own ranks (Hang-around → Prospect → Patch, `DESIGN` §11.2) |
| Army veteran → Calm Waters | dog tags at the collar, a subdued velcro patch on the pack | once he holds its pass, the company's access card on a reel (the Militia's leak is access, `DESIGN` §2.1) |
| Former private security → Corporation | a coiled earpiece, the GRUB DRILL lapel pin, gold cufflinks | the earpiece is the Corporation's code (`DESIGN` §2.1) |

**9.4 The palette: the Director's families (ratified 2026-10-23), Claude's values and roles (proposed, measured).**

*(Director: "azul/branco/amarelo - polícia; laranja/marrom/verde/aqua - traficantes; vermelho/vinho/cinza/branco - milícia; preto/roxo/azul
marinho - corporação".)* It supersedes the same day's proposal (navy, wine, aqua, vermilion). The measurements are CIEDE2000 in normal vision and
under a Machado 2009 simulation of deuteranopia / protanopia / tritanopia (scikit-image). Under ~10, two colours read as one at a small size.

| Faction | Primary (carries identity) | Secondary | Accents (only on the primary, never a band of their own) | Metal |
|---|---|---|---|---|
| FID | blue #2E6FD8 (L* 48) | white #F2F2F2 | yellow: the investigators' mustard #CCA33D, the coat itself | silver |
| Bunsen Burners | orange #F08A24 (L* 67) | brown #7A4A22 | green #5C8F2A, aqua #46C2C2 (the emblem's flask and flame) | aged iron |
| Calm Waters | red #B3121E (L* 38) | wine #5A1222 | grey #8A8D91, white | gunmetal |
| Corporation | black #141416 (L* 6) | purple #6B2FA0 | navy #1B2550 | platinum |

- **The primaries are excellent once their VALUES are pulled apart** (orange lighter, red deeper). Worst pair: **35.9 normal / 26.3 deutan /
  23.3 protan / 25.0 tritan**, above 20 everywhere and better than the superseded proposal in normal vision (31.5). Taken naively, the same
  families give 22.8 / 14.3 / 20.1 / 14.2, with orange against red as the weak pair.
- **The risk is in the SECONDARIES**, hence the accent rule (naive → tuned):
  - the traffickers' green beside the militia's red: **3.2 → 10.6** under deuteranopia, the classic red/green confusion;
  - the Corporation's purple beside the police blue: 9.9 → 11.3 deutan;
  - the traffickers' brown beside the militia's wine: 10.6 → 13.6 tritan.
  None of these may carry a faction alone.
- **Against the investigators' mustard coat, the bikers' orange collapses** (2.8 deutan, 4.3 protan). So the bikers' field officers wear a BROWN
  coat with orange trim (§8.3), and a biker-background Agent's armband is brown with orange stripes (ruled 2026-10-23, §9.9).
- **The opposites:** the police blue and the bikers' orange are near-complements (the law and the crime, the poster's diagonal); the dark pole
  is the Corporation (black), the warm armed pole the Militia (red).
- **For colour-blind players the emblem's SHAPE carries the identity,** so the symbol on the coat's back must read as a silhouette. The black
  Corporation will vanish on the dark board in play, so its purple and navy accents and its emblem carry it (an inference, to measure).
- **The hero's burgundy tie now collides with Calm Waters' wine** and changes when this is built. Regenerate the poster
  (`DIAGRAMS/CIRCULO_ENREDO.png`) with these families.

**9.5 Per style (D70, D72).** Normal: full colour. Black: the subdued variant (dark on dark, like low-visibility military insignia), the pack's
patch the main sign. Masked: the amber eyes stay the same for every faction (a state cue, never a faction one, D71/C3), the emblem stencilled
dark on the mask's side plate (portrait only). Cloak: nothing (the illusion). LED symbol: the coat's outside shows the bluffed faction, the
lining keeps his own.

**9.6 Earned and sold (C3, D36).** The faction's identity (palette + emblem) comes with the background and is never sold or swapped; the GRADE
(the metal and enamel of the pin, the armband's stripes) is earned by standing only; the captain's armband is the war's prize (§3, §4); the
tattoo is the ending's (§3). Sold or earned: variants of FORM (another tie pattern, ring design, pin style), always filled by the faction's
zones, so no purchase ever breaks recognition.

**9.7 The ranking portrait.** The master (C6) in three-quarters, the banner behind (primary colour, the emblem large, the league and the
position), the captain's armband on that week's winners. In play nothing depends on reading the faction at 190 px (the player knows his own;
what must read is Agent vs guard), so the detail budget goes to the portrait.

**9.8 Cost.** In the game LOD the palette is free; new geometry is the armband, the patch and one visible signature (< 250 tris over ~5.2 k);
pins, rings, cufflinks and the earpiece live in the menu master only (D73). Small accessories are rigid pieces on bone sockets (lapel, chest,
wrist, belt), so they fit both bases (§8.1) with one offset per socket and no cloth refitting.

**9.9 The decision renders (2026-10-23).** The Director's palette on the hero v5 master, rendered in Blender (EEVEE, Standard view transform,
so a hex renders as itself). This is a MOCK of the look, not the engine's shaders or cost. The sheets are in `Screenshots/history/`:
- `d78_faction_dress_agent_portraits.png`: the ranking portrait over the banner, plus a chest detail.
- `d78_faction_dress_agent_game.png`: 132×200 at the game camera on a dark board, ×3, and the ×3 under deuteranopia.
- `d78_faction_dress_officer_coats.png`: the field officers' coats from behind, the LED coat's bluff view, with the same rows.

To regenerate (the palette is data, `tools/asset_generation/hero/faction_palette.json`):
`faction_dress_art.py textures <dir>`, then `HERO_REPO=<repo>/ FD_OUT=<dir> blender -b -P hero_faction_dress.py`, then `faction_dress_art.py sheets <dir>`.

What the renders show (Claude's reading, for the Director to judge):
- **At play size the armband is the faction's main cue on the Agent.** The hatband and the lining's edge back it up; the tie, the pins and the
  mark of his past only show in the portrait.
- **The measurement came true on screen:** under deuteranopia the bikers' orange armband VANISHES into the mustard coat, while the Militia's
  red turns into a dark band that still reads by value. **Ruled (Director, 2026-10-23): on the Agent, the bikers' armband is BROWN with
  orange stripes** (the inverse of the banner, which stays orange; `faction_palette.json` "armband"). Against the mustard coat the brown band
  measures CIEDE2000 **35.2 normal / 32.1 deutan / 34.5 protan**, against the orange's 16.0 / 2.8 / 4.3, and the re-render shows it as a dark
  band under deuteranopia where the orange one vanished.
- **The officers' coats separate by the COAT's value even under deuteranopia** (mustard, dark brown, grey, black), so the brown coat for the
  bikers holds. The FID officer and the Corporation officer both show blue accents to a deuteranope, and are told apart by light vs dark coat.
- **The officers' back roundel reads at play size** (the bluff's distance view); for colour-blind players the emblem's shape carries it.
- **Mock limits:** emblems are the poster's placeholders; the officers wear the Agent's coat silhouette and go bald (the hair is shaped for the
  fedora); the Corporation's earpiece sits on the side the cameras do not see.
