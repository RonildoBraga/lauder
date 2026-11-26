# Lauder — story bible, draft 0.8

**Date:** 26 November 2026\
**Status:** Ensemble direction and exploration-led play with an armed, coordinated trio are approved, and the maintainer chose a frozen world on 20 November 2026. The combat identities below are agreed as the basis for designing the movement, formation and combat systems. Their tuning values remain starting points for playtests, and the encounter details remain a proposal. Biographies, exact relationships and enhancement histories remain open. The [README](../../README.md) and [prototype plan](../prototype-plan.md) own implementation status and next-step gates; this design document does not assign gameplay implementation. The game opens with Miki, Tom and Laura together on the Brooklyn Bridge ([ADR 0004](../decisions/0004-brooklyn-bridge-opening.md)).

**First-encounter revision, 23 November 2026:** The maintainer accepted C's dark armed form and motion, then assigned its integration in place of the first human shooter. The opening below uses the [first-tower guard](../encounters/bridge-spider-bot.md). The cause of the machine's continued patrol remains unexplained. Current implementation verification and tuning belong in the [prototype plan](../prototype-plan.md), not in this narrative outline.

**Opening revision, 26 November 2026:** The maintainer simplified the opening: **“I want to simplify the starting of the game so all the 3 companions will start together so no need to meet Tom and Laura later in the game”**. Asked what then happens to the scenes that introduced Tom and Laura, the maintainer chose **“Guard fight only”**. The three start together, the guard is the bridge's only fight, and the supply case's search, the knife attacker, Tom's intervention and Laura's rescue are gone. Why they travel together, and whether they were strangers, is now open.

**Strategic guard assignment, 26 November 2026:** The maintainer authorised a guard that requires all three characters and alternates its attacks, with manual changes of leader. The [prototype encounter](../strategic-guard.md) implements that direction using Miki's long rifle, Laura's sword and Tom's minigun. That manual-control prototype was delivered in [TestFlight build 33](../prototype-plan.md#build-33-testflight-preview); it does not establish a main-branch merge. It gives the opening a concrete act of cooperation without explaining the trio's histories; the west-arch bypass remains an alternative.

**Companion-autonomy revision, 26 November 2026:** After the generic phone feedback **“It worked nice”**, the maintainer asked for independent companions and explicitly chose **“Companions can complete the weakpoint steps too”**. The [bounded assignment](../companion-autonomy.md) is implemented on its feature branch; the [prototype plan](../prototype-plan.md#companion-autonomy--in-development) owns validation and delivery status. The player keeps the leader, while the other characters may contribute their native actions once combat is engaged. Changing leader remains available but is not mandatory for each step. This does not settle anyone's biography, promise automatic success or authorise a merge.

## Agreed direction

- Belonging, trust and people becoming responsible for one another provide the emotional centre. Blood relationships are not required to explain the group.
- Characters' lives intersect through encounters and the consequences of earlier actions. Their connections, histories and shared purpose emerge through play.
- Three playable characters travel together, from the start of the game ([ADR 0004](../decisions/0004-brooklyn-bridge-opening.md)). The player moves the active character; the others remain companions in the same world. A button switches control and leadership to another member. The [requested movement direction](../prototype-plan.md#combat-design-review-gate) is a coordinated squad that finds useful positions, rather than companions copying every footstep.
- Each character has distinct capabilities that make different approaches useful, including agility and strength.
- Chapter One begins with Miki, Tom and Laura crossing the Brooklyn Bridge together towards Manhattan. The transmitter repair at Relay House is kept as a later scene, not yet placed in the story.
- The world is futuristic and devastated, resembling the aftermath of a world war. The opening is set in a post-apocalyptic New York. The cause and wider extent of the collapse remain uncertain.
- The whole world is frozen. Rivers and the sea lie under ice, and most of the land is buried under snow: flat, white and largely empty, broken by a few structures and landmarks. Why it froze, and how the freeze relates to the collapse, remains uncertain.
- Exploration, purposeful salvage and survival lead the experience. The opening has one optional guard encounter on the bridge; afterwards combat stays occasional. All three characters carry weapons and can defend themselves and support one another. Ordinary cooperation, humour and care remain possible.
- Human enhancement exists through discreet internal synthetic replacements and biological or genetic changes. Characters retain a human exterior; exposed machinery is not the visual direction.

The control description is understood as **one human player directing a party of up to three**, with the others as computer-controlled companions. Three simultaneous human players or online co-op are not assumed by this document.

### What remains open

Miki, Laura and Tom are the playable trio. Their paired weapons and the assigned first-guard roles are agreed; further skills, signature-ability rules, enhancement histories, ages and biographies remain working choices. The coordinated-squad intent does not settle those details. Nina is proposed as a supporting character outside that trio.

No family relationship among Miki, Laura, Tom and Nina is settled, and none should be assumed in a script. The opening no longer shows how the three came to travel together, or whether they were strangers; their backgrounds, motivations and relationships unfold gradually through play. Decide the underlying relationships as writers before scripting intimate memories or kinship-specific dialogue. Keeping a relationship unknown to the player is different from leaving it undecided during writing.

With the East River frozen, the opening needs a reason to cross by the bridge rather than over the ice. A proposal: the line of the buried road is the one way across known to be solid, marked by someone with flagged poles, and off it the snow hides thin ice and channels of open water near Manhattan. The places beyond the bridge that assume open water, such as Old Lock's crossing, the canal route and the coastal water crew, need revisiting for the frozen world.

The [Chapter One outline](#chapter-one--across-the-bridge) below records the remaining dialogue work. The [gameplay walkthrough](../gameplay-script.md) condenses it into what the player sees and does.

## Premise

Miki, Tom and Laura set out together across the Brooklyn Bridge, towards Manhattan, through a post-apocalyptic New York. Why they are crossing, like their pasts, is revealed gradually rather than at the start.

On the bridge a machine guards the first tower. The three can fight it or use the other arch to get clear, then walk on to Manhattan. The opening shows what each of them does in a fight, not who they were before.

Trust grows from what they do for one another. Their biographies, motives and relationships unfold through the journey; the opening does not explain them.

A relay shelter's transmitter, which the three restore, is kept for later as the [Relay House scene](#later-scene--relay-house).

The longer story follows the commitment the three come to make. Homecoming can mean finding people and a place with which to build a future. The group gradually chooses what they owe one another and the communities sustaining their journey.

## The playable party

All three remain people in the scene when control changes. Switching leadership represents whose abilities the player directs; it does not transfer memories, change personalities or turn followers into silent possessions of the leader.

The active character leads movement and supplies their particular interaction capabilities. The other two remain involved in movement, defence and the story. Skills should be understandable at first use, even when their medical origins or personal histories remain unknown. Coordinated behaviour does not establish that they served together, received military training or share a hidden origin.

| Working character | Contribution | Example use | Personal tension |
|---|---|---|---|
| Miki | Systems knowledge, inspection and careful salvage | Identify a compatible regulator without cutting a live supply | Finds mechanical certainty easier than relying on another person's judgement |
| Laura | Agility, balance and reading a route | Reach a service latch and open access for the whole party | Is used to carrying a route's risks herself and must share decisions |
| Tom | Strength, controlled load handling and delivery knowledge | Shift a manageable obstruction or support a heavy assembly | Wants to remain dependable when his old information is no longer enough |

These distinctions are not complete identities. All three can observe, talk, help and carry ordinary supplies. Expertise and enhanced capacity are different things: stronger arms do not explain knowing how to repair a transmitter.

### Leadership should create decisions

- Favour readable alternatives. A stable route may take longer; an agile approach may open a convenient passage. Strength can make a load safer to handle without solving every obstacle.
- Avoid repeating three obstacles each labelled for a different character. Switching should follow the player's reading of a place.
- A specialist opening should ultimately admit the party. Laura might reach a latch to release access for the others; following her does not make them equally agile.
- Companions should not repeatedly become stuck or need rescue to justify their presence. A narrow passage needs a credible group route before the scene is written around it.
- Keep commands few and readable. The current leadership-switch and formation controls, and the squad orders built with [ADR 0003](../decisions/0003-squad-movement.md)'s phase S3, are recorded in the [input contract](../prototype-plan.md#input-and-interaction-contract); a regroup control remains a design proposal rather than an implemented mapping. Skill trees and separate equipment systems are not prerequisites.

### Combat identities

**Weapons revision, 26 November 2026:** The maintainer gave each character two weapons to switch between ([ADR 0021](../decisions/0021-paired-weapons.md)). Miki has a long rifle and an assault rifle, Laura a shotgun and an energy sword, and Tom a minigun and a shield dome that protects him and those inside it. These replace the carbine, burst weapon and scatter weapon proposed below. The signatures below remain proposals, not built.

Each character should be useful as leader and capable of ordinary weapon defence. Their distinctions concern range, exposure, positioning and the situation they can improve, rather than an obligatory sequence of three specialist actions. Keep ordinary travel comfortable under every leader; Tom should not make routine exploration slower simply because he has a stronger build.

The assigned first-tower guard deliberately teaches three contributions in sequence: Miki disables a sensor with the long rifle, Laura breaches a side coupling with the sword, and Tom damages an exposed reactor with the minigun over repeated recovery windows. Those first two results persist for the attempt. This is a specific machine's dismantling rule, not a requirement that every future fight use a fixed combination or a new implementation of the proposed signatures below. Build 33 kept companions following/holding without attacks. The new autonomy assignment lets them complete their own native contributions while respecting engagement, movement orders, a nearby leader leash and regrouping; switching away from Tom still drops his player-controlled shield. Automatic shields and signature abilities are not assigned.

In the separate Quiet Yard proposal, companions would provide basic weapon support while the player triggers only the active character's signature ability. This remains unimplemented and is not the assigned guard's control model. They would not spend signatures automatically or require the player to manage three ability bars. Using another member's signature would mean switching to them first, and the controls and threats must allow for that:

- Every member is at most two presses away: Next, on L1 / LB on a controller or as a button on touch, goes round the party.
- A threat's wind-up lasts long enough to switch and act; about 1.5 seconds is a starting value for playtests.
- The HUD names who can answer a telegraph, such as “Miki can Disrupt”.
- When a signature is pressed, assisted targeting prefers the threat it affects, such as the unit winding up for Disrupt.

Defending the group does not mean starting fights with neutral people, breaking a chosen non-combat approach or pursuing threats after a withdrawal order. Exact targeting, damage, timing and recovery rules require design review and playtesting. Until health is designed, The Quiet Yard uses a [placeholder hit rule](../encounters/the-quiet-yard.md#placeholder-hit-rule) so that exposure and retreat can be tested.

Personality can influence a companion's preferred nearby position and brief reactions: Miki looks for a clear view, Laura reads another safe angle, and Tom considers the exposed approach. It must not create concealed disobedience, suicidal advances or repeated rescue chores. A command to regroup and leave takes priority over those preferences.

Natural movement should seek reachable nearby destinations and respond to obstacles, with enough space for all three. **Close** for compact mutual support, **Spread** for more separation on open ground and **Column** for single file in tight places are the formations built for the opening. Narrow passages temporarily compress the group, which expands again where space permits. Formation shape must yield to safe, credible group access; Laura's agility cannot justify taking a route her companions cannot use. Orders that place the companions, with the directional pad or a press-and-hold menu on touch, are built for the opening as well; a regroup order in a fight remains a proposal. [ADR 0003](../decisions/0003-squad-movement.md), not this document, settles their bindings, targeting and navigation rules.

## Miki — understanding what still works

**Proposed background:** Municipal water and power maintenance.\
**Proposed role:** Technical inspection and purposeful salvage.\
**Enhancement status:** Undecided; her competence does not require an enhancement.

Miki reads places through a dry pipe, a warm cable or a pump vibrating behind a wall. She checks markings and diagrams rather than assuming a familiar housing contains a safe part. Her practical local knowledge does not give her universal access to future technology.

She wants to reach the coast and discover whether she can belong somewhere beyond the district that has needed her for years. Laura has offered an introduction and a possible place to stay; Miki chooses to pursue it. The opening has a destination without depending on an endangered relative.

She tends to add one more task to a completed job. Under pressure she becomes brief and exact. Dry humour and small acts of care appear when she stops trying to control every uncertainty.

Her first important act is restraint: she leaves useful infrastructure intact because other people depend on it. Over the chapter, she accepts that Laura's experience and Tom's conversations supply facts her instruments cannot.

**Proposed combat identity — precision and disruption.** Miki carries a long rifle for measured, heavy shots from a clear position, and an assault rifle for rapid fire at middle range. **Disrupt** uses a precise shot to interrupt one clearly telegraphed ranged attack at useful range, opening a brief window for a teammate to cross, fire or withdraw. It is a specific combat action, not universal hacking, control of every machine or knowledge acquired through an unexplained enhancement. The Quiet Yard proposal first demonstrates it against a visible security-unit wind-up; applicability to other threats remains to be defined.

Her strength is reading a threat and making a deliberate opening. Being crowded or attacked from several directions exposes her limits; basic weapon fire still lets her defend herself. As a companion, she favours a reachable position with a clear view and supports the current fight without independently changing the group's plan. That preference reflects her careful inspection and desire for certainty. Learning to trust another person's timing can develop her character without making her mechanically unreliable.

## Laura — finding a way through

**Proposed background:** Scout and route worker for a coastal water crew.\
**Proposed role:** Agility, balance and access.\
**Possible enhancement:** Biological changes supporting coordination and recovery; the changes, timing and reason remain undecided.

Laura is physically present with Miki and Tom from the opening playable journey. The radio does not introduce her as an absent companion waiting at the coast.

She needs current conditions to get herself and the water crew safely through the crossing. Her responsibilities continue while she travels; joining the group is her decision, with obligations and limits of its own.

Miki already has reason to trust her. Show that through a kept appointment, an accurate warning or an honest limit before explaining their history. Laura can be dependable and have a past the player has not heard.

She reads footing and structure before committing her weight. Her agility appears in controlled movement, not necessarily acrobatics. She tires, makes mistakes and can be injured.

The proposed depot discovery reveals that she once helped maintain water for people who stayed in an officially emptied block. She answers naturally when asked. Her knowledge reflects a particular experience, not proof of a secret role in the global collapse.

**Proposed combat identity — mobility and useful angles.** Laura carries a shotgun for close blasts, and an energy sword that strikes close by and turns shots from in front of her, which supports movement between nearby safe positions. **Reposition** is a quick dash, at about twice running speed, to a point she can see on reachable ground a few metres away. A prepared shot is aimed where its target stood; the dash is quick enough to leave that line, which walking usually is not. That lets her cross a short exposed gap, reach another angle before a unit turns, or break away. It cannot cross a blocked passage, perform an unsupported leap or protect her once she stops in the open, and it needs a moment to recover before she can dash again. Its value comes from the ground and the threat's readable attention, rather than a hidden damage bonus for switching characters.

She is strongest when she can move deliberately and use an opening; her light weapon has less stopping power against a close advance than Tom's. Isolation or sustained exposure puts her at risk. As a companion, she prefers a nearby useful angle while staying within the group's support and obeying placement or withdrawal orders. Her tendency to carry route risks herself can appear in dialogue and choices, but it must not force the player to chase or rescue her. Biological coordination changes remain a possible explanation of capacity, not a settled biography or a substitute for route knowledge.

## Tom — carrying his share

**Proposed background:** Transport and water-delivery work.\
**Proposed role:** Strength, handling loads and route knowledge.\
**Possible enhancement:** Internal synthetic muscle and supporting skeletal replacements fitted for medical or civilian work reasons; the actual history remains undecided.

Tom travels with the group throughout the chapter. He carries his share, has inland communities depending on deliveries and knows the district's former connections. He intends to reach the coastal supply team to arrange their next allocation; Old Lock is his meeting point with its crew and part of that onward journey. His relationship to Miki is open; the new script should introduce what they actually know about each other.

A stronger build gives him a clear silhouette. His useful strength is controlled and specific: he can shift an obstructing frame the others cannot safely move. He cannot lift an entire ruined structure or make an unsafe floor bear its weight.

He asks who walked a road and when. His maps are useful, but he will correct them. The depot's occupied water line challenges what his transport records said about the block.

He sometimes masks worry with instructions. His arc involves accepting help and sharing responsibility, not proving his worth through a heroic sacrifice. He has a voice beyond being the strongest member or an older source of wisdom.

**Proposed combat identity — close protection and space control.** Tom carries a heavy minigun, and projects a shield dome that stops shots for him and those inside it while he holds it. **Brace** steadies a controlled blast that briefly checks a nearby advancing threat, creating room at an approach or protecting a withdrawal. Unlike Miki's interruption of a telegraphed ranged attack, it addresses close pressure on a small area. It does not make his body bulletproof or require teammates to stand behind him in every encounter; the dome is equipment he projects, not his replacement tissue.

He is strongest where a close approach needs holding and weakest against distant pressure or threats reaching him from several sides. He remains a practical leader at ordinary travelling pace. As a companion, he favours a useful position near an exposed approach or teammate, without blocking the group's movement or ignoring a retreat. His care for deliveries and people makes protection personal; his arc also allows others to cover him. The origin and exact capacity of his possible internal replacements remain undecided.

### How the trio complements itself

Miki can create a brief opening, Laura can use another angle, and Tom can make space to leave or hold a close approach. Beyond the first guard's explicit teaching sequence, those are alternatives and opportunities for teamwork rather than a mandatory combination for every encounter. Ordinary fire and positioning should remain useful with any leader, and no character is a passive escort or a compulsory healer. Their exploration contributions remain central: understanding equipment, reading access and handling a load continue to matter outside a fight.

The weapons make survival capability visible before the player learns where it came from. Their ownership does not settle military history, allegiance, kinship or enhancement origins. Reveal those histories through relevant encounters and choices; explain the usable combat rules when they first matter.

## Nina — a life beyond the journey

**Proposed age:** Eight.\
**Role:** Supporting character at the coastal settlement, outside the playable trio.\
**Relationship to the party:** To be settled before detailed dialogue is rewritten.

Nina has routines, friendships, responsibilities and things she wants for herself. She is not waiting alone to be rescued. Her connection with the travellers can carry warmth without declaring a blood relationship at the beginning.

A dry place kept for someone's bag, a borrowed cup or an ordinary promise can show attachment. Such details should follow a relationship actually chosen by the writers, rather than replace that decision.

She is not a mysterious biological key or an enhancement specimen. Her age does not prevent her noticing what adults overlook, but it does not supply knowledge the story has not earned.

## Enhancement in this world

This is original fictional technology. The reference to discreet, human-looking enhancement describes appearance and tone, not borrowed characters, terminology or another setting's biology.

### Synthetic replacement

Some people have internal replacements for tissue: muscle, bone, joints or organs. These integrate beneath an ordinary human exterior. Clothing, skin and expression are what the player first sees. Exposed metal limbs, glowing seams and decorative ports are not the default language.

Replacement and enhancement overlap without meaning the same thing. One synthetic joint restores ordinary movement; another replacement may support greater force. A medical history does not automatically imply exceptional powers.

### Biological and genetic changes

Some humans have engineered biological traits affecting capacity, such as muscle development, coordination or recovery. Treatment methods, inheritance and exact capabilities remain world-building decisions.

These changes need not alter visible anatomy. They do not automatically make a person invulnerable, ageless or capable of immediate healing.

### Everyday consequences

Before the collapse, replacements and enhancements could serve healthcare, transport, hazardous maintenance and other civilian work as well as military uses. Access varied. Not every enhanced person needs to have been a soldier or manufactured weapon.

Leverage, footing, fatigue, recovery and injury still matter. Medical care may be harder to obtain after the collapse, but compulsory drug dependence, constant implant failure and new resource meters are not assumed mechanics.

Enhanced and unenhanced people have skills, agency and moral differences. Enhancement does not establish worth, allegiance or humanity. Not every party member needs one, and abilities need not explain why their lives intersected.

### How the player learns

Show a useful capability clearly, then develop its context. Tom moves a load with unusual control; a later encounter can explain who fitted his replacement and what it meant to him. Laura's movement can become familiar before her training or treatment history is discussed.

Avoid an opening diagnostic dossier, an obligatory body reveal or a surprise ability that invalidates earlier obstacles. Keep abilities reliable enough to learn. Let mystery concern the person, their choices and the history surrounding that ability.

## The world after the collapse

Networks supplying water, power, food and communications have broken apart. Civilian buildings bear blast damage. Military wreckage lies among public vehicles; stripped checkpoints have become shelters and storage. No dependable national authority reaches the Basin.

The future is visible in surviving materials, automated services and distributed utilities. A transit display refreshes above a burnt vehicle. Delivery-machine panels patch a blast shutter. An announcement repeats directions to a shelter whose roof has fallen.

Years of weather, salvage and habitation matter as much as the original destruction. Places are not empty simply because official systems stopped counting them. Settlements function because people maintain them.

People disagree about the sequence of fighting and infrastructure failure. Local records, broadcasts and survivor accounts contain evidence, errors and gaps. None of the party has a complete global explanation. Enhancement history may intersect particular events, but it is not automatically the cause of the collapse.

Water, food, warmth, shelter, load and reliable information shape choices. In the frozen world, water comes from snow and ice and takes fuel to melt, and cold presses as hard as hunger. A long detour can be impossible with the fuel and water they carry. These pressures give salvage purpose without requiring a meter for every bodily need.

People can cooperate, disagree or compete over resources without belonging to a hidden faction. Light combat and observation-based avoidance belong to the wider direction; the first repair need not require a fight.

## Place and communications

| Place | Working purpose |
|---|---|
| The Brooklyn Bridge | The opening crossing, travelled by Miki, Tom and Laura together |
| Manhattan | Where the crossing leads; what the party finds there is not yet written |
| The Basin | Damaged inland district Miki has helped maintain |
| East Span | Recently closed crossing interrupting the travellers' routes |
| Relay House | Occupied shelter with a working receiver and failed transmitter |
| The depot | Stripped transit maintenance site with a regulator and evidence of continuing use |
| Old Lock | Staffed crossing where the party can meet the coastal water crew |
| The coastal settlement | Inhabited destination with a water crew, local routines and Nina's present home |

The places after the first two belong to the Relay House scene and the journey beyond it; where they sit relative to New York is not settled. Names, distances and the full map remain working choices. The canal route needs a water stop and current reports from both approaches before the party relies on it.

Handsets retain offline functions and limited short-range radio. Maintained relay sets permit longer contacts at scheduled times. Relay House hears the coastal operator but cannot answer until its power regulator is replaced.

The repaired set serves others as well as the party. It establishes contact and a meeting plan; it does not restore the old network or make the roads safe.

## Chapter One — Across the bridge

The first tower retains the C robot; the supply-case interaction and recruitment beats are removed. The [encounter document](../encounters/bridge-spider-bot.md) records the preceding prototype, and the [strategic guard](../strategic-guard.md) records the assigned revision. Implementation status and verification belong in the [prototype plan](../prototype-plan.md); narrative intent does not establish a successful runtime check.

**Immediate goal:** Cross the Brooklyn Bridge into Manhattan.\
**Emotional movement:** Three travellers begin to rely on one another.\
**Party:** Miki, Tom and Laura, together from the start.\
**Achievement:** The three reach Manhattan together.

The merged baseline contains the whole opening, as its [decision record](../decisions/0004-brooklyn-bridge-opening.md) sets out. Its strategic first-guard revision was delivered for phone testing in build 33. The new companion-autonomy revision remains in development; the maintainer's general phone feedback does not establish detailed controls, performance or merge approval. Final dialogue remains to be written; the game's lines are provisional.

Keep the opening's lines short. They should reveal nothing about anyone's past beyond what the moment needs; backgrounds, motivations and relationships unfold through the journey. Settle the underlying relationships and enhancement histories before writing kinship-specific dialogue. Character details and new lines retain their proposal status.

### 1. Together on the bridge

The three start at the Brooklyn end. Snow has buried the bridge's road, everything left on it and the frozen East River alike, and only the towers stand above the white plain. The player learns to move, look around, switch leader and try the formations.

### 2. The guard at the first tower

A dark, four-legged machine still patrols the first tower. Miki notices its continued vigilance, but the scene gives no account of its maker or orders. In the assigned strategic revision, she reads and disables its sensor, Laura reaches a side coupling and breaches it, and Tom uses the reactor's recovery openings. Build 33 lets the player direct each contribution by changing leader. The assigned autonomy revision also allows companions to contribute while the player guides the leader, using the tower's stone and the machine's readable attack cycle to survive; orders and withdrawal retain priority. Their cooperation is shown before its personal history is explained. The other arch still offers a route beyond the guard area instead.

### 3. Onwards

The three continue towards Manhattan together. Squad movement and formations are there from the start. Each one's personality, abilities and role in the group emerge over the journey rather than in the opening.

## Later scene — Relay House

A transmitter repair at Relay House is kept as a later scene. Where it falls in the journey, and how it fits New York, is not decided. By then the three know one another. Its outline:

**Immediate goal:** Restore the transmitter and agree a viable onward route.\
**Emotional movement:** Practical cooperation becomes a deliberate commitment to travel together.\
**Achievement:** A working community transmitter, an Old Lock appointment and a concrete discovery about the district.

### 1. The road on the map

East Span is closed after recent structural movement. Miki cannot reach the place Laura described; Laura cannot confirm the water crew's approach; Tom cannot rely on his delivery route. The northern detour takes more water than they carry.

They compare what each actually knows and head to Relay House. Dialogue establishes present needs and a little familiarity, without a family introduction or an account of the war.

### 2. A reason to help

The keeper explains the transmitter fault. Miki identifies compatible equipment. Tom remembers protected bays at the depot. Laura assesses the route from its last known access points, acknowledging that conditions may have changed.

They agree to make the short salvage trip together. The keeper remains at the shelter. None of the playable trio is parked there as a stationary quest-giver.

### 3. What still serves someone

Front access is blocked. The group reads the depot and chooses an approach. The scene can demonstrate a useful leadership switch without requiring an obstacle for each skill.

This scene proposes two approaches to the same service barrier: Laura reaches its release latch, or Tom shifts its loose panel from a stable grip. Either opens the passage for everyone; neither requires the other first. These are contextual actions represented simply in the greybox, not free climbing or a physics lifting system. Miki checks the regulator and isolates the disconnected equipment containing it.

A maintained bypass supplies a neighbouring block marked empty in an old transport register. Inspection shows current use. Miki leaves that supply connected; the regulator comes from separate equipment. This decision belongs to ordinary salvage, not a new branching morality system.

### 4. Different knowledge of the same place

Laura recognises the bypass. Tom has different information in his records. They discuss it where they find it:

> **Laura:** We kept that tap open for the people who stayed.
>
> **Tom:** That block was marked empty.
>
> **Laura:** Some people never left.

These are proposed lines. A direct follow-up should get a natural answer about who was there and what Laura knew. The discovery raises a local human question; it does not prove a global conspiracy or Tom's culpability.

### 5. Make the return matter

All three return with the regulator. Miki installs and tests it while the others contribute to preparation and route reports. The community supply powers the repaired transmitter. The part stays for the next person who needs to answer a call.

They contact the coastal operator and water crew. Reports from both approaches make the canal route credible. The party and crew agree to meet at Old Lock, with a next radio appointment and a staffed shelter to use if travel fails.

Nina can speak during the scheduled contact once her relationship has been settled in the dialogue pass. A brief ordinary exchange supplies warmth. Laura participates beside Miki and Tom, not as a remote voice.

### 6. Tomorrow's bags

Another traveller uses the set. The party shares food, checks its water and packs for the route it now knows. Each has contributed; each has a reason to continue. A reciprocal act, such as making room for another person's tools, expresses growing care.

The scene ends with lasting progress. They choose to make the next journey together. They also know that the district's written history has left people out. The transmitter repair remains a journey without a required fight; the armed-squad proposal does not insert a combat gate into it.

## Later encounter proposal — The Quiet Yard

After the Relay House scene, on the way towards Old Lock, the party can consider a canal maintenance yard holding spare filter seals useful to the coastal water crew. [The Quiet Yard](../encounters/the-quiet-yard.md) is a separate design exercise for occasional combat, avoidance and withdrawal, rather than part of the current prototype.

A safe detour continues the journey without the seals. The yard can also offer a readable patrol gap and a covered route for the whole party, or an optional confrontation with two old security units of one type. Existing walls and clear approaches give the proposed roles something understandable to do. No compulsory sequence of signatures, invisible combat lock or reinforcement wave is needed. Regrouping and leaving remains a supported choice during an encounter; the encounter proposal must define fair targeting, pursuit limits and a credible exit before implementation.

Evidence of recent human maintenance raises a local question about who still uses the place. It does not reveal the cause of the collapse or the trio's connections. A quiet exchange afterwards can recognise both the usefulness of the seals and the people who took the risk, without declaring avoidance or fighting the only correct choice. Detailed dialogue and encounter rules remain for review.

## Mystery and revelation

Exploration creates a question, interaction supplies a perspective, and a later event tests or deepens it. An answer should change the player's understanding of a person or place. Not every discovery needs to open a larger mystery.

| Player encounters | First understanding | Later development |
|---|---|---|
| Maintained water in a block marked empty | People continued living beyond the official account | Meet someone who depended on it and learn what maintaining it required |
| Laura recognises the bypass | She helped people there | Learn the circumstances through an encounter and her choices about a new obligation |
| Tom corrects a record | He can admit his information has limits | Discover how the delivery network affected particular people |
| Miki leaves useful infrastructure intact | Her care extends beyond the party | A recipient recognises the consequences of that decision |
| A companion demonstrates unusual capacity | The player learns a reliable capability | Medical or work history gives it personal meaning when relevant |

### Author knowledge and fair disclosure

Before scripting the chapter, settle the local truth. A proposed explanation: the transport register recorded the end of organised evacuation as an empty block, although residents stayed. Laura and residents maintained the bypass. Tom knew the transport record, not an exhaustive census. Miki discovers current use through inspection. This remains an author proposal, not a revelation already delivered by the game.

For important reveals, record what happened, what each character knows, what the player has observed and what the reveal changes. Decide underlying relationships before writing lines intended to conceal them. Public repository notes may contain labelled spoilers; mystery is for the player's experience, not a lack of answers among writers.

Characters should not feign ignorance, avoid ordinary names or refuse useful information solely to prolong suspense. Avoid amnesia as an opening shortcut. Some connections can be unrecognised because their effects passed through other people, rather than because everyone has a secret identity.

Balance questions with answers, jokes, reliable actions and progress. Major connections need an accessible story beat; optional records add texture rather than carrying all the emotional explanation. The collapse and individual relationships can develop at different speeds.

## Story promises and next writing pass

- The group becomes worth caring about through what members do for one another, including disagreement and repair of trust.
- Their histories are not all branches of one hidden experiment. Shared purpose can grow from present commitments.
- Enhancements support readable abilities and human stories; they do not replace character, training or judgement.
- Each chapter delivers a concrete achievement. New information does not repeatedly erase routes, move destinations or undo trust merely to extend the journey.
- People beyond the party have meaningful lives of their own.

With the combat identities agreed, the next design step is the movement, formation and combat systems; the accepted [ADR 0003](../decisions/0003-squad-movement.md) covers the movement and formation part. Settle the trio's identities, underlying relationships and enhancement specifics before the full dialogue pass; the bridge opening's lines come first, and stay brief. Decide where Relay House and Old Lock sit relative to New York, so water and timing remain credible.

The [prototype plan](../prototype-plan.md) owns the scope, review gates, control defaults and phone cadence. The combat, formation and positioning designs above are implemented only as far as the opening's milestones and ADR 0003's squad orders.
