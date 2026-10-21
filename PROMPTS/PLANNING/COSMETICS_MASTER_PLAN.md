# COSMETICS_MASTER_PLAN
## Cosmetic items, ownership, the backpack, contributions, the weekly faction war and the world map — v0.2

> 🟡 **v0.2 · 2026-10-21 · PLANNING ONLY, nothing built.** v0.2: the factions are decided in `DESIGN_MASTER_PLAN` §2.1/§2.6 (§2 here); the world map, city only, no photo (§6).
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
| **C8** | **Selling: direct purchase + items earned by playing. No paid random boxes** (§16, ratified: no purchased loot boxes in the all-ages product). The status of play-earned random drops stays §16's open question. Mobile stores require their in-app purchase for digital goods (~15-30% fee) and restrict real-money trading; **trading and a market are deferred** (they attract fraud and regulation) but C1 does not prevent them later. | Store rules, the age rating, and §16's company identity. | proposed |
| **C9** | **Platform: our own backend or a hosted service with inventory + economy (PlayFab, Nakama or similar), behind OUR item schema.** Steamworks Inventory / Workshop only exist on Steam, so they cannot own a mobile player's inventory (a PC version could bridge later). Unreal's Fab is a marketplace for developers, not a player-contribution pipeline, and the project is Godot. | Mobile-first; keep the data model portable so the service can change. | proposed |
| **C10** | **Player contributions (TF2's Workshop, adapted).** A web portal with the kit (skeleton, slots, budgets, material rules); automatic validation by our exporter and `PropValidator`; **human curation before anything reaches the shop** (TF2 ships only what Valve picks); a contributor agreement (licence, revenue share, what happens if the author leaves); moderation and reports (trademarks, offensive content). Accepted items are re-exported by our pipeline, never shipped as the author's raw file. | Quality, safety and legal clarity; the raw file is the attack surface. | proposed |
| **C11** | **Privacy and accounts.** The minimum personal data (LGPD / GDPR); an all-ages product needs parental controls before any social surface (§16 leaves the lobby's communication model unresolved). Purchases survive a reinstall through the account, not the device. | Legal, and a lost purchase is the worst support ticket. | proposed |

---

## 2. Factions — DECIDED in the narrative (2026-10-21)

**The three factions are `DESIGN_MASTER_PLAN` §2.1's:** the **Agency** (the corrupt law), the **Militia** (the criminals) and the **Corporation** (a private military and security company, against both).The names
are working names (Director: *"Tanto faz o nome, o importante é serem equilibradas"*). Each is guilty of a share in the dam's fall (§2.6), so no faction is
the "good" one, and the Agent betrays all three. **The faction the player picks at the police station (§2.6) is his first allegiance here;** switching
follows §4's cooldown. Balance: §2.1 (one axis each, the same threat budget, measured per faction and per route).

## 3. The new items the Director asked for

| Item | Design (proposed) | Cost |
|---|---|---|
| **Armband** (`armband` slot) | A band on the upper arm (the costume already had one in D70's first description: "blue shirt and armband"). Its SYMBOL is a texture layer chosen separately: the player's faction emblem, a rank, an event mark. **The "captain's armband"** is the armband earned by the weekly war's top contributors (§4), shown only for that week's winners and kept as a commemorative variant afterwards. In the black style it goes dark with the suit (D70), and it is never the only cue of anything (C3). | ~100 tris; the symbol is one shared atlas (no extra draw call per symbol). |
| **Banner** | **Not on the figure in play:** D70 rules out capes, and a flag behind a 190 px figure hurts readability and the stealth silhouette. Two places instead: (1) the **profile / lobby / ranking BACKDROP**: a large banner behind the hero in the showcase scene (faction colours, the season's art, the player's emblem); (2) in play, a small **pennant on the pack** (`pack_pennant`), stowed in the black style. | The backdrop costs nothing in play; the pennant ~60 tris. |
| **Emblem** | The symbol itself (shown on the armband, the banner, the profile card). Earned, bought or contributed; a definition like any other (C1). | A texture in the atlas. |

---

## 4. The weekly faction war (proposed)

**The loop:** each week every faction gets an **objective** (e.g. "the Network: extract 5 000 files", "the Corporation: disable 2 000 cameras", "the
Agency: complete 1 500 missions without an alarm"). A player's missions in Freelance count toward HIS faction's objective. At the end of the week the
winning faction's players get a prize; the top contributors of each faction get the **captain's armband** for the next week.

**What §16 forces on it (ratified canon), and how the proposal complies:**

| Canon (§16) | Consequence for the war |
|---|---|
| No FOMO, no punishing a missed streak, no fabricated urgency | Missing a week loses nothing; prizes are **cosmetic and commemorative**; every weekly cosmetic returns later by another route (no item removed only to force a purchase). |
| The core game must not need an online service | The war is an online LAYER on top of offline play: missions played offline count when the device syncs (with validation, see below); nothing in the single-player game depends on it. |
| Paid acceleration (the permanent **2× currency** multiplier) is accepted because there is no PvP | **The war IS a competitive surface** (§16 asks for an explicit revisit). Proposal: faction score counts **missions and objective actions, normalised**, never currency, so the 2× boost buys no war advantage; a per-player weekly cap stops one player (or one bot) from carrying a faction. |
| No PvP planned | Factions compete through a shared score, never by fighting each other. |
| All-ages | No gambling mechanics in the prizes; no real-money value. |

**Anti-cheat:** an offline client can claim anything, so the server validates what it counts: plausible mission durations and outcomes, the per-player
cap, signed mission seeds where possible, and outlier review before prizes are paid. **Balance:** factions can be uneven in size, so the objective is
**per player** (average contribution) or scaled to each faction's active players; otherwise the biggest faction always wins and the rest leave.

**Switching faction:** allowed, with a cooldown (e.g. at most once per season) so a player cannot jump to the winning side on the last day.

---

## 5. Open questions for the Director

1. ~~Which three factions~~ — **decided 2026-10-21** (§2): the Agency, the Militia, the Corporation.
2. **Prizes:** cosmetic only (armband, emblem, banner, paint), or also currency? (Currency in a competitive prize interacts with the 2× boost.)
3. **The banner:** profile backdrop + a pack pennant, as proposed, or something on the figure itself (which D70 currently rules out)?
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
- **Flags and real names attached to crimes:** a corrupt agency HQ under a real national flag, or a massacre set beside a real neighbouring town, can offend
  or be read as an accusation. Proposal: real names and flags only on neutral places (streets, stations, cafés, billboards); the factions' buildings and
  the crimes keep fictional names and emblems.
- **⚠️ The dam (`DESIGN` §2.6) — open for the Director:** does the inciting event move to each player's country (a fictional town near his city), or stay
  in its one fictional Brazilian town, with the personalisation applying to where the investigation travels and to Freelance? Moving it means the
  tragedy sits next to every player's real neighbours (the sensitivity above, multiplied); keeping it fixed keeps one story and one dedication.
- **Fallback:** a player who gives no city gets a default set (fictional city names, the game's own country), so nothing depends on the answer.

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
