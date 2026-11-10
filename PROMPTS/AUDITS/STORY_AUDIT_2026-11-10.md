# Audit 2026-11-10 — the story: the factions' points of view, the Agent's choices, credibility, early reveals, the road to Freelance

**Asked by the Director:** (1) a brief analysis from each faction's point of view and the consequences of the Agent's main choices (in practice the order in which he kills the leaders, the reporter at the end, and some secondary ones); (2) inconsistencies that could discredit the plot or hand over information too early; (3) the road to Freelance paved (the sub-leaders stay alive).

**In one line:** the structure holds. What can hurt it is not the shape but eight unwritten mechanisms, four characters who know too much for a free kill order, and a Freelance start state nobody has written down.

> **RATIFIED the same day (Director, 2026-11-10: "Aplica todas as propostas").** Every proposal below is now canon in `DESIGN_MASTER_PLAN`
> §2.8, and the C list was applied. The items where this audit offered no single answer are `DESIGN` §18's "From the story audit" entry.
> The text below is the audit as written, before the ruling.

## Method and limits
- Read: `docs/DESIGN_MASTER_PLAN.md` §1, §2 (all), §10.0, §10.5, §10.6, §11, §14, §15, §16, §18, §19; `COSMETICS_MASTER_PLAN` §2-§4, §6, §8; the session records of 2026-10-22, 10-23 and 10-24; text searches over `docs/vision/`, `docs/production/`, `MODEL_INVENTORY`, `PROP_PIPELINE_PLAN`.
- **Nothing here is ratified and no canon text was changed.** The plot was closed on 2026-10-23; every fix below is a PROPOSAL (Claude) waiting for the Director. Section references are to `DESIGN_MASTER_PLAN` unless a plan is named.
- Severity: **A** = can discredit the plot or spoil the reveal; **B** = a visible seam; **C** = stale text or a detail to write.

---

## 1. Each faction's point of view

| | FID (Police) | Calm Waters (Militia) | Bunsen Burners (Traffickers) | Corporation |
|---|---|---|---|---|
| **What the leader thinks the Agent is** | A subordinate too close to the case: motivated, deniable, outside the chain he cannot trust (Graves) | A grieving inspector whose signature on "the club did it" is worth a war and a lever on Pryce (Kessler) | A cop outside Graves's deal, useful for the job his dead assassin was doing ("Deacon") | The one investigator who could find the books: to be used against the State and watched (Pryce, through Hedge) |
| **What it needs from him** | The leak found before federal scrutiny finds the pit | Proof against the traffickers | Who sells the club to the Militia | Proof of the State's negligence, which saves the candidacy |
| **What the leader holds that can sink him** | The roadblock log | The wreck, the rider's frame, "our informant" | The chop-shop sale, the rider, the Confessor's mask | The puts, and everything Hedge saw |
| **Why he does not use it** | The trail ends in his own house (the leak is a policeman, the pit is his) | Naming an intruder brings the inspectors who find the sirens | He believes the Corporation framed the club | Exposing the bettor opens the trading around the disaster, then the books |
| **The successor's gain** | Barrow: the chair, and a dead man to blame for the pit | Hardcastle: command, on camera | "Choirboy": the club, cleansed of Deacon | Marsh: the chair and the sale to Carrion Capital |
| **Where it stands at the memorial** | The reformer of a compromised agency, same cover-ups | Unpaid, still holding the complex, the sirens unseen | The public culprit, surviving by disowning its dead president | Sold at half price, the hole laid on a dead man, the report unseen |

**The pattern worth keeping in view:** every leader holds one true piece and has a selfish reason to sit on it, and every successor needs the official version more than the truth. That is why the plot survives a free order. It is also the cynical thesis of the game, stated four times.

**Two leaders are not like the other two.** Graves and Kessler hold a fragment. "Deacon" and Pryce hold a CHAIN that reaches the Agent without the reporter (§3, A3 and A4). In fiction, the villain's best order is Deacon first, then Pryce. The player does not know that, and on a second playthrough it is one more thing to see.

---

## 2. The Agent's choices and what each one changes

| Choice | What the canon already makes it change | Gap found |
|---|---|---|
| **The background** (the deposition) | Lap 1's rotation, the handler, the chapter where the badge goes (4th on the Police route, 1st on the Corporation's), one own-faction L1 node, the league's faction | On three routes of four, Graves hands over his favour AFTER taking the badge at the pit (B4) |
| **The order of the official work** | The power station: lights, recharge points, powered distractions | Which site holds the Confessor (already in §18) |
| **The run's violence** | The spouse's fate, the cemetery's two versions, "Choirboy"'s sub-mission | The causal link between KILLS and BLOOD (B6) |
| **Being caught** | Wanted in that scenario, the alert rises | None |
| **Sub-missions and neutral missions** | Access, gear, rotations, money; the violence average diluted | Barrow's needs Graves alive and does not say so (C3) |
| **The lap-2 order** | The reporter's hints (16 lines), an alert step per death, the sub-missions' windows (Hardcastle: before Kessler dies; Marsh: after two deaths) | Four things the canon leaves unsaid, below |
| **The reporter** | The tattoo; a fugitive either way; the truth buried either way | What he is discovered AS in the kill branch, and Marlow's files (B2) |

### 2.1 What the lap-2 order should decide, and does not yet say

1. **Access.** §2.2 says access "comes from that faction's leader's trust". Nothing says what happens to it when the Agent kills that leader. **Proposal:** it dies with him, because the trust was personal; the exception is the character's own faction, where the favour was voiced by the handler (§2.7's rule), who is now the head. Then the order is the order in which he closes doors on himself, and the L2 stores (gated by access, §11.6) give it weight: buy before you kill, or infiltrate the store afterwards (already canon). No new system, and it makes the Director's "main choice" a real one. The alternative (access survives) leaves the order cosmetic.
2. **Who is blamed for each death.** "The sub-leaders blame each other" cannot describe the first death, when only one successor is in post and three leaders are alive. **Proposal, written once for the 24 orders:** each successor blames the faction the circle already points him at (Barrow the Militia, Hardcastle the Traffickers, "Choirboy" the Corporation, Marsh the Police). Four lines, and lap 1 has already taught the player why.
3. **What each leader's position changes in his scene.** The confession and the clue are fixed. **Proposal:** his ATTITUDE is keyed by how many have died (surprised, defensive, bargaining, expecting him): 4 x 4 lines, the reporter's own budget, never 24 permutations.
4. **The time states.** Alert steps as hand-made maps multiply by order (a turf visited after k deaths). **Proposal:** key them by the COUNT of deaths, and carry the step as data (highly watched zones with a tier threshold in the map's `layout`), not as one authored map per case.

### 2.2 Consequences per faction of dying early or late (derived from the canon; the last column is the proposal above)

| Leader | Dies early | Dies late | Under proposal 1 |
|---|---|---|---|
| Graves | Barrow's sub-mission closes unseen; the off-the-books channel ends; the "substation fire" version loses its owner | He watches three colleagues fall with the roadblock log in his drawer | Nothing to lose: the police access went with the badge |
| Kessler | Hardcastle's sub-mission closes; the frame and the wreck pass to a man who wants cameras | The unpaid commander outlives his debtor if Pryce went first: the Militia turns on the Corporation | The armoury closes |
| "Deacon" | The only man who knows the Confessor is dead is gone: the mask is safe | He has the whole lap to tie the masked sightings to the Agent (A3) | The lab and the chop shop close |
| Pryce | The campaign that held Militia and board together ends: unpaid insiders sell more access (canon: the late pay is their reason); what Hedge saw dies | He holds Hedge's reports through three assassinations (A4) | The R&D floor closes |

---

## 3. Findings

### A — can discredit the plot or spoil the reveal

- **A1. Why does a police informant hold the Militia's codes?** Kessler's clue ("codes only we and our informant knew") is the one the reporter uses to close the case, and the official version repeats it ("a policeman who passed it the Militia's codes"). An informant SELLS to the Militia; nothing explains what the Militia gave him. **Proposal:** the codes are filed with the FID. A private company flying drones over a strategic complex registers its friendly codes with the federal agency, so outside Calm Waters they sit in one restricted police registry, which the leak reads. It also answers why the drone took off INSIDE the perimeter (the counter-drone screen faces outwards), and it ties the Militia's clue to the Police's: a policeman.
- **A2. Whose credential passed the roadblock, and what does the log say?** Graves runs the case and reads that log on the first day. If the number is the Agent's, the story ends there; and a roadblock officer saw a MOTORCYCLE, the vehicle the Agent parks at the station. A man who left his phone at home for an alibi does not then show his own badge. **Proposal:** the card was the colleague's, the same man who lent his name to Pith & Peel: a front lends what he is asked for and asks nothing. The Agent meant to manage him inside the investigation he expected to lead; the flood removed the witness. "His death is chance" stays true, and three of the four clues land on one dead man by construction, not by luck.
- **A3. "Deacon" can solve the case alone.** He knows a rider who was not his framed the club, sent the Confessor after that rider, and knows the Confessor is dead and his mask worn by someone. The hunted killed the hunter, so the mask is the rider. The day he ties the mask to the Agent he has everything, with no reporter. In a free order he may live through three deaths. **Proposal:** cap what he believes (the impostor is the Corporation's man, the financiers he already suspects); he sees the hat on the Agent only at his own death; his line may say "you killed my man" (the player knows that) and never "my man was hunting the rider". §2.4 already licenses him to call the Agent "Confessor".
- **A4. Hedge has been watching since the official work, and reports to Pryce.** By the canon's own proposal he may have seen the mask taken, the four-way game, the meetings with the reporter and, on the Corporation's trip, the Agent derailing the trail to Pith & Peel. That last one makes Pryce's clue an accusation. **Proposal:** write Pryce's silence as his choice (each rival's death helps him, and exposing the bettor exposes his books), make HIM the ambush's sender (§18 leaves it open) because of what Hedge saw abroad, and keep his scene inside §2.4's suppression. Then the knowledge is a motor, not a hole.
- **A5. When does the reporter know?** He knows from before the disaster that his source also sells to the Militia. For him alone, Kessler's clue is not ambiguous. If the Agent hands him each confession whole and Kessler dies first, the reporter spends three kills feeding leads to a man he has identified, which also costs him his innocence. **Proposal:** in lap 2 the Agent trades the leaders' SHARES (the four failures), never the trigger clues: he controls the intelligence (§2.3). The reporter gathers the four clues from leaks during the time jump (each new regime leaks its predecessor's file; The Sieve lives on leaks), and what turns him is the memorial itself: he hears the truce name a dead policeman as the informant, and his informant is standing at the grave. Order-independent, written once, and he stays an honest partner until the last scene.
- **A6. The voice-over now sits on the pictures it contradicts.** Since 2026-10-25 the Agent narrates the night while the clue objects are on screen. "I was at home" spoken over his arrival on the bike moves that clue from minutes apart to the same shot. **Proposal:** the arrival plays silent; the first spoken line starts once he is inside, so every sentence is true of the image it sits on.
- **A7. Too many physical matches can meet in one chapter.** The helmet, the bike, the rope and hook and the balaclava are all his from the first mission; the Militia's frame shows a rider going over a wall on a rope. On the Militia route that chapter-opening favour is the first of lap 1. **Proposal, an exposure budget:** before the finale each match is SAID or CARRIED, never displayed. The frame is words in lap 1 ("a rider"), an object in the Confessor's file, and a picture only in the reporter's hand. The frame resolves the helmet, never the bike or its plate.

### B — visible seams

- **B1. The club's president stands at the victims' memorial.** The official version makes the club the author of the attack, and its new president seals a truce before the press and the mourners. **Proposal:** the image is four successors each denouncing a dead man; "Choirboy" hands over Deacon's cell and stays at the edge (the gate, engines off), never on the stage.
- **B2. The kill branch.** "He is discovered" must mean the reporter's killing, never the dam; a grieving father who shoots the journalist investigating the dam is the loudest clue in the story. To write: what the public version is (the reporter drew first, which is true), and where Marlow's files go. If The Sieve prints a dead man's notes, the "conspiracy theory" reading still holds, now with a martyr.
- **B3. The official version changes and nobody says when.** It starts as "a substation fire" and ends as "the club's attack". The Graves-"Deacon" deal can only leak once both are dead, or one of them denies it. **Proposal:** one moment for every order, in the time jump before the cemetery.
- **B4. Graves's favour after the badge.** On the Militia, Traffickers and Corporation routes the pit chapter comes before the chapter Graves asks for. The canon's answer (a deniable asset) needs one authored beat: Graves must believe the Agent found less than he did.
- **B5. The chop-shop sale is not route-proof.** On the former biker's route the shop knows his face, and the rider's bike is his old club bike. **Proposal:** the buyer never took his helmet off. It reuses the helmet, explains why the club hunts "a rider", and holds on every route.
- **B6. Kills do not drain a blood bank; the wounded do.** **Proposal, from canon already there:** each death he causes is blamed on a rival and answered, and the reprisals' wounded are what the radio counts.
- **B7. Four faction heads killed in weeks, one a federal commissioner and one a Senate candidate, and no outside inquiry.** The FID's motto ("We'll get back to you.") carries it as satire if a line says so; left unsaid it reads as an oversight. It is also a Freelance seed (§4).
- **B8. The slip at the grave.** If the spouse stands beside him she hears it too. Either she is out of earshot, or her silence is a beat the Director wants; "only the reporter and the player know" should be a decision, not an accident.
- **B9. Minor mechanics to write:** the hours between the strike and the collapse (they are what makes the silent sirens a crime, and they cover his ride home); why the son is buried only at the restored cemetery (the town buries its dead together); the pit still holding acid in a restored town.

### C — stale text and orphans (no change made)

- **C1.** §2.2, the reporter: "the real approach at the hospital **after the wife's death**" predates the ruling that she survives by default and that her fate is sealed at the end. The midpoint (her condition turns critical) is the beat that exists.
- **C2.** §18, decided list: "the player picks the recruiting faction at the police station" predates the background.
- **C3.** §2.7: Barrow's sub-mission (bug Graves's office) lists only the badge as its condition.
- **C4.** §2.4: `EXTRACTION` relabelled `ACTIVATION SITE` belongs to the superseded canon in which the campaign built the attack; nothing is activated now.
- **C5.** §15: "a Network contact" (the Agency / Network pair is history). `docs/production/milestones.md:1043` ("destroy Agency or go public") and `roadmap.md:268` are the same residue.
- **C6.** `COSMETICS` §8.4 and `MODEL_INVENTORY` list "the official investigator who takes over the case" and "the front's man at Pith & Peel". Neither has a role in §2. The front's man is the dead colleague (a photograph at most). The investigator is a loose honest witness unless he is someone we know. **Proposal:** Barrow takes the case the Agent expected to lead, which also sharpens their rivalry.
- **C7.** §11.2's Rival Agent row and `COSMETICS` §8.4's "no place in the campaign": the Confessor and Hedge now fill that tier.

---

## 4. The road to Freelance

**What the canon already gives:** each faction outlives its leader; the four sub-leaders are the clients, paying a faceless seller; the Agent is dead to the world; the trips' places and the neutral missions' templates carry over; L3 comes from captains' prototypes through Zest.

**What is not written, and Freelance stands on it:**

1. **The sub-leaders must be unkillable by staging, not by rule.** The engine lets the player shoot anyone, and the project's own list bans actors with special rules. They are never a reachable actor on a playable board (a scene, behind glass, a comm-link). The same holds for the reporter before the finale and for the spouse.
2. **The truce is on the STORY, not on the turf.** The memorial freezes the past; Freelance is the fight for what is left. The fuel is already in the canon: the Militia's unpaid bill against a company sold to Carrion Capital; the club as public enemy, raided for show by an agency that used to protect it; Barrow's pit; Marsh's sale and the report nobody saw; the Corporation's missing LED prototype, which the Agent wears.
3. **Freelance contracts are leaves too.** No contract may carry a piece of the disaster. An endless game cannot reopen what the campaign buried.
4. **A dead man has no face.** Bare-faced he is a dead inspector to anyone who knew him; masked he is the club's assassin, whom every faction believes alive. So Freelance starts with NO access anywhere, every uniform in the LED coat, and the bounded forged credential (§15's balance pass) as its only access. To rule: is the masked figure the official hand of the attack? If so the mask is wanted on every turf, and the lie that protects him describes him exactly.
5. **What the faked death costs the player.** The gun and the badge go into the acid. To state: identity objects only; gear, tree and uniforms stay.
6. **Why a dead man with money keeps working.** The faked death opens the offshore account. Either it reaches the spouse (and he keeps nothing), or reaching it is Freelance's far horizon, paid in tranches. Unanswered, the mode's premise ("charging for information") has no need behind it.
7. **The league needs a reason in the fiction.** He sells to all four, yet scores for one. The hinge is canon: the handler "knows a little more and keeps quiet". To rule: whether that one client suspects whose ghost he pays. The canon today says none of them knows.
8. **Who has seen the dead man.** Zest meets him between the laps; the four store keepers served him. Either they only ever met the mask, or one of them is leverage.
9. **The reporter's branch.** Alive, Marlow is the one person who would recognise the seller's hand; dead, his files are. Any difference in Freelance must stay flavour of equal weight: the tattoo is a mark, never a power.
10. **Spoilers from the live layer.** Rankings show two tattoos and "dead" Agents to a player still in his first campaign; and the league opens only after the campaign, weeks in. To rule: tattoo art that names nothing, and whether the neutral missions between the laps already count for the league.

---

## 5. What I would take to the Director first

1. A1, A2 and A5: three sentences that close the three holes a careful reader finds.
2. §2.1 item 1: whether access dies with the leader. It decides how much the order matters.
3. A3 and A4: the cap on what "Deacon" and Pryce may know and say.
4. §4 items 4 and 6: the dead man's face and the dead man's money.
5. The C list: seven text fixes, safe to apply on his word.
