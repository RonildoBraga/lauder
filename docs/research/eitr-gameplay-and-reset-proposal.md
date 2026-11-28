# Eitr research and a gameplay-first reset proposal

**Date:** 28 November 2026. **Agent:** Codex, researcher and repository auditor. **Status:** research retained; first duel assigned in [issue #236](https://github.com/RonildoBraga/lauder/issues/236), broader proposals tracked in [issue #234](https://github.com/RonildoBraga/lauder/issues/234).

## Recommendation and scope

Keep this repository, preserve the bridge at the [named checkpoints](../milestones/bridge-prototype.md), and build toward a single controlled hero with deliberate close combat. Keep Swift/RealityKit and the Apple development pipeline initially. Test one enjoyable duel before committing to a campaign, character art, elaborate environments or progression systems.

The initial assignment authorised research, a reuse audit and a roadmap before implementation, explicitly retaining this repository. The maintainer subsequently assigned the first duel experiment in issue #236. The [current plan](../prototype-plan.md) owns that implementation; later phases below remain gated recommendations. The research itself changed no game source or assets, and the anonymous prototype hero does not rewrite the preserved story foundations. The two-leader pilot is preserved separately rather than merged just to archive it.

Eitr should be a close mechanical reference, not a promise of an identical finished game: no released build or complete specification is available to us. Its [official Steam listing](https://store.steampowered.com/app/350050/EITR/) remains unavailable, unlisted at the publisher's request, and marked Coming soon. Neither cancellation nor current active development was established. A developer [2019 reply](https://steamcommunity.com/app/350050/discussions/0/1644290549110684004/) says Eitr was shown too early and had undergone several major revisions. Dates matter.

## Evidence and research limits

The study uses developer posts and interviews, the official trailer, and first-hand accounts of playable demonstrations. The labels below distinguish developer-confirmed statements, observed footage, reported demo behaviour and our own adaptations. No wiki's synthesis is treated as a final design specification.

Sampled frames from the official 61.6-second Steam gameplay trailer were visually inspected. They show compact encounters, a sword/shield hero, clearly different enemy silhouettes, bursts of elemental effects and an elevated view across floors and scenery. They support discussion of composition and attack readability, not frame-perfect parry timing, damage formulas, actual input or a complete level layout. Contact samples cannot establish continuous movement or responsiveness.

The longer [IGN Gamescom 2015 dungeon demonstration](https://www.youtube.com/watch?v=NwRXSC4hCCM), [IGN developer interview](https://www.youtube.com/watch?v=cR7iTzSrFi8), [VaatiVidya PSX preview](https://www.youtube.com/watch?v=a-YatMGBqq0) and [developer-published 2020 work-in-progress video](https://youtu.be/K-DBqrq4xgg) were identified and their provenance checked, but usable playback/transcripts were not available in this research environment. They were not watched here. The developer discusses the later video in a [27 February 2020 Steam reply](https://steamcommunity.com/app/350050/discussions/0/1745645554525434866/), explicitly separating recording frame rate from game performance. Do not infer a new release or a performance fault from video/CDN metadata.

Before attempting closer replication, inspect the longer demonstrations interactively with the maintainer and agree which dated version is the reference. Hidden timing, feel and balance remain experiments even then.

## What Eitr actually documented

### Combat, movement and control

David Wright describes the original aim as sword/shield combat influenced by Souls and Zelda, seen from a Diablo/Path of Exile perspective, with direct player skill rather than only build optimisation. This is the design intent, not proof that every Souls mechanic exists in Eitr. [Developer interview, April 2015](https://80.lv/articles/5-tools-to-make-eitr).

| System | Evidence | Consequence for this proposal |
| --- | --- | --- |
| Movement and melee direction | Developer Aedous describes eight-direction travel but horizontal-only attacks in [August 2014](https://discussions.unity.com/t/eitr-gameplay-video-action-rpg-isometric-pixel-art-new-trailer/546220?page=2). An [earlier post](https://discussions.unity.com/t/eitr-gameplay-video-action-rpg-isometric-pixel-art-new-trailer/546220) says melee enemies line up left/right before attacking. | Do not silently assume unrestricted directional combat was Eitr's rule. In 3D, compare a simple facing-based arc against this historical lane model before claiming fidelity. |
| Target selection | [November 2014 developer post](https://discussions.unity.com/t/eitr-gameplay-video-action-rpg-isometric-pixel-art-new-trailer/546220?page=5): Tab cycles targets; selection forces facing except during running/dashing and supports backstabs. Directional right-stick selection was planned. | Retain Lauder's input/target-selection boundaries. The final controller bindings and later facing rules remain unknown. |
| Dated controller bindings | [Famitsu's E3 2015 hands-on](https://www.famitsu.com/news/201506/18081207.html) reports R2 attack/charge, R1 guard-breaking kick, L2 guard, L1 parry and Circle quickstep. | This is a concrete reported demo mapping, not a verified final layout. Combining guard/parry on one button below is our proposed mobile simplification. |
| Attack variation | [November 2014 official post](https://eitrthegame.tumblr.com/post/101790928278/holding-down-the-attack-button-unleashes-a) shows a secondary attack by holding attack. [October 2015 devlog](https://discussions.unity.com/t/eitr-gameplay-video-action-rpg-isometric-pixel-art-new-trailer/546220?page=8) trades slower two-handed attacks for reach/damage. | Reach, commitment and recovery can differentiate weapons before inventing a large loot catalogue. Exact charge thresholds and ratios are unknown. |
| Evasion | A [May 2015 official post](https://eitrthegame.tumblr.com/post/118543165513/the-new-sidestep-is-a-result-of-your-feedback) adds a sidestep following feedback. The October 2015 devlog confirms briefly invulnerable dodging. | Prototype a short ground-level dodge with an explicit vulnerable recovery; do not inherit Lauder's complete-roll immunity as an Eitr specification. |
| Defensive timing and cancellation | A [first-hand E3 2015 report](https://www.destructoid.com/hands-on-with-2d-souls-like-eitr/) describes an uncancellable parry, a manually chosen follow-up, and several other moves that can cancel. | A successful defence should earn an opportunity, not automatically attack. Do not claim all Eitr attacks were irrevocable or invent its full cancel matrix. |
| Stamina and guard pressure | A [first-hand 2016 PS4 demonstration report](https://archive.rpgamer.com/news/Q2-2016/062016a.html) describes running/dodging consuming stamina, heavy swings exposing the attacker, chains, guard-breaking kicks and repeated blocks causing stun. | A shared resource and punishable recovery are promising. Costs, regeneration, guard-break thresholds and attack costs require our tuning, not assumed numerical copying. |
| Weapons and active skills | Official posts show [dual wielding/fire arrows](https://eitrthegame.tumblr.com/post/120286954463/sticks-and-stones-break-bones-but-blades-decimate), [freezing defence](https://eitrthegame.tumblr.com/post/132681753243/gain-armour-when-using-snowflake-guard-to-freeze) and later [defensive spear play](https://eitrthegame.tumblr.com/post/152427500503/defensive-tactics-are-well-performed-with-spears). | Variety can change positioning and defence, rather than just damage numbers. None is necessary to validate the first sword/shield duel. |

### Progression and the exploration loop

In the [August 2015 developer account](https://discussions.unity.com/t/eitr-gameplay-video-action-rpg-isometric-pixel-art-new-trailer/546220?page=8), Favor comes from enemies, bosses and chests, with NPC acquisition also considered. Keeping it provides stronger, death-vulnerable deity-linked benefits; spending it at Yggdrasil buys smaller permanent stats. Equipment Gems supply skills, whose charges replenish through matching offensive or defensive activity. Potion charges then refill through kills. The same thread later discusses randomized skill-tree prototypes and plans for randomized maps. Those plans do not demonstrate a completed procedural campaign.

The later [June 2020 developer explanation](https://www.reddit.com/r/Eitr/comments/h0zzoo/comment/fvtscio/) describes equipment talents that change behaviour, a customizable character skill tree and volatile perks lost on death. It does not fully reconcile every older Favor/Gem rule. Treat these as changing designs, not a list of features that must all coexist in our game. In particular, do not substitute a conventional corpse-recovery system for Favor without evidence or a deliberate design decision.

The [2015 first-hand WorthPlaying demonstration](https://worthplaying.com/event/E3_2015/PostE3_2015/96941-ps4pc-preview-eitr/) reports flint-activated bonfires, resting without respawns and respawns after death. [Famitsu's E3 2015 hands-on](https://www.famitsu.com/news/201506/18081207.html) describes doors that create shortcuts. These are observations of those demos, not verified final checkpoint rules. The useful structure for us is a risky outward journey, an optional find, and a satisfying return; randomized penalties, durability, crafting and skill trees can wait.

### Camera, levels and overall experience

The official listing calls the view isometric. The sampled trailer shows a consistent elevated oblique composition, visible ground between opponents, constrained passages and contrasting small/large threats. The exact projection, pitch, lens, follow damping and zoom rules were not documented in the inspected sources. A low-resolution sprite presentation also does not tell us what 3D heights or collision volumes should be.

PlayStation's [first-hand PSX 2016 report](https://blog.playstation.com/archive/2016/12/09/the-playstation-experience-2016-report-one-day-to-play-17-of-the-best-games-of-the-show/) describes measured combat, traps, dark hallways and deaths from excessive attacking. The [2016 developer interview](https://mcvuk.com/business-news/interview-eitrs-got-soul/) emphasises demanding attention and avoiding autopilot. These support intentional encounters rather than continuous spawning as the starting point.

Our interpretation of the appeal is **recognise a threat → choose position or defence → earn an opening → decide how much to commit → recover or continue exploring**. Failure can teach because the enemy's preparation and the player's overcommitment are legible. Exploring can change the next fight or create a safer return. This is a design hypothesis to test with players, not evidence that matching the features guarantees enjoyment.

## What Lauder can reuse

Audit baseline: clean merged main at 0f4eb819ae2b794f713ca67b2211bc53766a28ee. The separate two-leader pilot at 99131065a388cf3cf655b816ec60697d15691b61 is not part of that tree. Recommendations here concern future active use; no source has been removed.

| Retain | Adapt or replace | Preserve historically, then retire from active gameplay if agreed |
| --- | --- | --- |
| Swift 6, RealityKit, Swift Testing, formatting and Apple project layout | One session/world coordinator for a single hero and one encounter | Three-person leadership, formations, squad orders, follow/hold and companion tactics |
| Shared input arbitration, touch capture generations, pause/disconnect neutral gates, app lifecycle and idle-timer ownership | Reduce commands to move, attack, guard, dodge and optional interaction/target selection | Character/weapon switching, grenade orders and party role prerequisites |
| Camera-relative movement, swept collision, traversal queries, projection and camera-follow boundaries | New attack phases, stamina, directional guard, timed dodge and enemy states | Instant sword resolution, passive drawn-sword defence and shield-dome rules |
| One fixed-step update, plain Swift rules and presentation consuming resolved values/events | Small hero/enemy combat owner instead of the complete bridge encounter graph | Guard eye/leg combinations, pack enemies, gun targeting/ammunition and encounter-specific retaliation |
| Blender coordinate conversion/export fingerprints, model provenance and layout validation | Register a small graybox and only its active resources | Bridge-only export declarations and required spawned-model manifests |
| Simulator keyboard/touch workflow, scripted scenarios, source-bound check/release tooling and privacy boundaries | New duel/reset scenarios and a compact current-status page | Obsolete bridge scenario requirements and resource packaging in the new active app |

Concrete boundaries already worth keeping:

- [InputRules](https://github.com/RonildoBraga/lauder/blob/milestone/bridge-main-2026-11-28/apple/sources/interface/InputRules.swift) owns command priority and readiness; [GameControls](https://github.com/RonildoBraga/lauder/blob/milestone/bridge-main-2026-11-28/apple/sources/interface/GameControls.swift) owns source changes. Route new actions through them rather than adding a second combat input policy.
- [Movement](https://github.com/RonildoBraga/lauder/blob/milestone/bridge-main-2026-11-28/apple/sources/world/Movement.swift), [PartyMotion](https://github.com/RonildoBraga/lauder/blob/milestone/bridge-main-2026-11-28/apple/sources/world/PartyMotion.swift) and [CameraRig](https://github.com/RonildoBraga/lauder/blob/milestone/bridge-main-2026-11-28/apple/sources/world/CameraRig.swift) provide useful geometry/projection. PartyMotion's collision math is reusable even if its party-oriented name later changes. It currently supplies flat movement and boxes, not a complete 3D terrain/navigation system.
- [EncounterStage](https://github.com/RonildoBraga/lauder/blob/milestone/bridge-main-2026-11-28/apple/sources/world/EncounterStage.swift) separates scene entities from value-only simulation. Preserve that principle, not every current presenter.
- [The check command](../../scripts/check), [Simulator runner](https://github.com/RonildoBraga/lauder/blob/milestone/bridge-main-2026-11-28/apple/scripts/playtest) and [release tooling](https://github.com/RonildoBraga/lauder/blob/milestone/bridge-main-2026-11-28/apple/scripts/testflight_release.py) already bind validation and delivery to actual sources. Retain the source/signing/Apple-processing/tester-access checks when a future release is authorised.

The current sword hits immediately when ready inside its range/arc in [EncounterSimulation](https://github.com/RonildoBraga/lauder/blob/milestone/bridge-main-2026-11-28/apple/sources/gameplay/EncounterSimulation.swift); the drawn sword can passively deflect frontal shots. [Weapon](https://github.com/RonildoBraga/lauder/blob/milestone/bridge-main-2026-11-28/apple/sources/combat/Weapon.swift) also models a rechargeable area shield. [PawnMotion](https://github.com/RonildoBraga/lauder/blob/milestone/bridge-main-2026-11-28/apple/sources/world/PawnMotion.swift) supplies a roll, while [GameWorld](https://github.com/RonildoBraga/lauder/blob/milestone/bridge-main-2026-11-28/apple/sources/world/GameWorld.swift) excludes the rolling leader from hostile shot targeting. There is no stamina economy or general player startup/contact/recovery state. A sword-and-shield prototype needs new authoritative combat rules, not simply new models or tuned gun damage.

### Architecture and workflow improvements

The audit counted 65 Swift source files/16,084 lines and 90 test/support files/16,805 lines. DEBUG Playtest (2,159), EncounterSimulation (2,062) and GameWorld (1,778) account for about 37% of source lines. Those concentrations join many bridge features; line count alone establishes neither a bug nor a performance problem.

Keep one app/module initially. Use the existing ownership direction:

1. Input produces intents; session owns pause/reset and mode.
2. The world advances a fixed step and resolves movement/collision.
3. Value-only combat state accepts actions, spends/replenishes stamina, owns facing and action phases, and resolves once-per-action hits.
4. Presentation consumes that same state and resolved events for poses, impacts, sound and HUD. It cannot independently award damage or advance a second combat clock.

This is a small new rule set within retained infrastructure, not a generic combat framework, custom ECS, event bus or new package hierarchy. Prototype collision should use simple swept shapes/arcs and target volumes, avoiding exact mesh contact and ragdoll simulation. If a slower rendered frame crosses an active interval, the rules must still detect the crossed interval; each accepted action must not damage the same target once per frame.

Reuse procedural primitives for clear anticipation, contact and recovery first. Current hero pawns have no runtime skeleton, so historical character animation experiments do not establish ready melee animation. Authored rig work should follow a demonstrated need; animation may improve readability, but must not change the source of hit authority.

Workflow priorities, in order:

1. Provide a direct duel/retry entry, avoiding repeated traversal of the long bridge for every tuning experiment. Keep one small current plan with acceptance gates; move release history to linked records after agreement rather than continuing to grow the front page.
2. Keep input/lifecycle/collision/reset regressions. When old production features leave, retire their active tests and scenario requirements together; retain the checkpoint history. Do not keep dormant squad code just to satisfy old tests.
3. Adapt the asset declarations, exporters, preflight and drift checks together. Folder-synchronised resources under [apple/sources](https://github.com/RonildoBraga/lauder/blob/milestone/bridge-main-2026-11-28/apple/sources) are bundled: unused USDZ/WAV files there still ship. Authored art can remain outside runtime resources; do not disable safeguards to hide obsolete content.
4. Measure validation phases before optimising CI. [PR #228 CI 213](https://github.com/RonildoBraga/lauder/actions/runs/46095812456) succeeded, but validation took 17m24s and logged an Apple Simulator service timeout. Portable checks took about six seconds and formatting eleven; most time was Xcode/hosted Simulator work. This does not isolate build/test costs. Consider a fast value-rule check and cached local iteration only if measurement justifies them; retain the complete release check.
5. Profile the smaller loop before introducing pooling, caching or concurrency. [Issue #227](https://github.com/RonildoBraga/lauder/issues/227) records a deferred phone HUD measurement, not a demonstrated performance regression or a new measurement assignment. Simulator timings do not establish iPhone performance.

Do not replace the engine during research. A tiny RealityKit prototype can test action timing, camera and input without another migration. Reconsider only against a concrete unmet requirement, such as measured animation tooling cost or unavailable rendering behaviour, rather than engine popularity.

## Proposed first playable and roadmap

The maintainer assigned Phase 1 in issue #236 after this research. Later phases retain the gates below; they are not promises of a full Eitr feature set or calendar estimates. This document preserves the original proposal and evidence; the current prototype plan owns implementation status.

### Phase 0 — agree the reference and preserve the bridge

Retain the two source checkpoints and delivered-build reference. Decide whether to pursue Eitr's early horizontal melee or an intentional 3D adaptation. Recommendation: analog camera-relative travel and attacks in the hero's facing direction, with bounded facing commitment during the swing. This differs from the documented 2014 horizontal-only attacks; name the difference rather than hiding it. Use an anonymous placeholder hero until character/world identity is agreed. Do not rewrite Miki's established weapon or story to fit a research prototype.

**Gate:** agree one hero, close combat, simple arena, evidence limitations and what is out of scope. Review PR #228 as a preserved historical experiment; do not merge or close it automatically as part of the reset.

### Phase 1 — make one duel worth replaying

One flat graybox arena, one sword/shield hero, one enemy with a deliberate sweep and a longer wind-up thrust. Both attacks must be distinguishable by pose/shape and timing, not colour alone. No auto-spawning waves or boss phases.

- Hero: move, attack, held directional guard and dodge. Attacks have anticipation, contact and recovery; facing cannot snap freely throughout an active swing. Guard protects the facing side and costs stamina when hit. Dodge has a bounded evasion interval and punishable recovery. Damage is straightforward; no mandatory weak-point chain, random criticals or floating-number dependency.
- Shared stamina is our proposed economy for attacks, evasions and blocked impacts. It regenerates under a simple visible policy. Exhaustion must leave ordinary repositioning possible. Exact values and cancellation rules are tunable and explicitly ours.
- Enemy: approach to useful range, prepare, commit, resolve, recover. Stop perfect tracking before the dangerous contact. Avoid endless pursuit and unavoidable attacks from outside the camera. A missed attack creates a genuine punish window.
- Input: reject illegal actions consistently, spend once on acceptance, and allow at most a short bounded buffered action so accidental queued combos do not play themselves. Pause/disconnect/reset cancels pending action authority and requires neutral input using the retained rules.
- Feedback: readable silhouettes, guard impact, clear hit response and modest sound. Health/stamina are enough HUD. No character sculpting, texture pipeline or cinematic production is needed.

**Gate:** source tests cover phases, collision, once-only hits, resources, recovery and reset. Rendered tests verify pose/contact agreement and readable attack distance. Human playtest asks whether the player understands each hit, can deliberately bait/punish, and wants another attempt. If mashing attack, permanent blocking or repeated dodging dominates, tune this duel before adding content.

### Phase 2 — defensive depth and phone controls

Only after the duel works, compare a timed parry on the initial guard press with ordinary held blocking. A parry earns a manually chosen counter window; its risk/reward must differ from safe blocking. Add a charged attack or guard-break response only if ordinary attack/guard/dodge fails to create enough decisions. Add one second enemy pattern to test reach and spacing, not a roster of superficial variants.

Proposed controller layout: left stick move, right shoulder attack, left shoulder guard, face button dodge, optional stick-click target toggle and separate out-of-combat interaction. Exact bindings remain open; these are not claimed Eitr controls. Touch starts with one movement stick and Attack/Guard/Dodge; holding Guard requires no new permanent button. Keyboard uses the shared input path. No squad controls, weapon wheel or twin-stick shooting aim is needed. If facing proves unreliable, compare light target assistance with optional lock-on before adding more inputs.

Compare fixed-orientation orthographic and restrained long-lens perspective cameras using the same arena and actors. Select framing by visible weapon reach, feet/ground contact, foreground occlusion and enemy preparation on the phone. Use simple wall fading where needed. Do not infer Eitr camera degrees or inherit the very wide bridge camera unchanged. Keep terrain flat even though rendering is fully 3D; stairs, slopes and stacked floors add navigation and hit-height problems without proving the core loop.

**Gate:** short touch/controller sessions on the baseline iPhone, at a meaningful milestone, establish control comfort, threat readability and sustained frame pacing. Simulator keyboard/pointer play remains the everyday path; it does not establish live controller forwarding or physical multi-touch quality. Do not schedule repeated phone checks before useful changes accumulate.

### Phase 3 — give exploration a purpose

A proposed 6–10-minute graybox route: safe start → first fight → optional side cache or safer route → a harder encounter → shortcut back. The optional find should immediately change a choice, such as restoring a limited heal or enabling one weapon modifier, instead of being an unspendable collectible. Route knowledge and a shorter return are rewards too.

Add one bounded held-reward-versus-banked-progress experiment, inspired by the dated Favor design, only now. Define the death rule explicitly; no random equipment damage or layered death roulette initially. Compare whether carrying a useful temporary benefit creates an interesting continue/return choice, rather than merely fear of losing time.

**Gate:** players choose to explore for a reason, recognise a route/shortcut, and can explain why they returned or pushed onward. A retry is quick enough to test learning. Do not add procedural generation, skill trees, crafting, shops or inventory grids to repair a boring duel.

### Phase 4 — decide what deserves production

After several short human sessions, retain only mechanics that create repeated meaningful choices. Then choose protagonist, setting, animation needs and an art target compatible with the camera/performance budget. A second weapon should change reach, speed or defence, not only stats. More enemies should introduce distinct questions, such as a guard to flank or a ranged threat to approach, while staying readable together.

At that point, execute an approved active-code/resource cleanup, update the accepted architecture/walkthrough and assign small PRs. Preserve credentials privacy, CI/review gates and exact-source releases. TestFlight delivery remains a separate authorised operation and must verify Apple processing and tester availability, not just upload-command success.

## Main risks and simpler alternatives

- **Unreleased reference:** several historical systems conflict or remain unspecified. Select a documented slice rather than trying to merge every Eitr proposal into one game.
- **3D readability:** real depth can obscure contacts that worked as flat sprites. Start with flat navigation, simple target volumes, restrained occluders and one clear camera; add elevation only after evidence of a gameplay benefit.
- **Melee feel:** anticipation/recovery, aim commitment, input buffering and hit response matter more than a long features list. Use one authoritative timeline and playtest frequently; more artwork cannot validate these rules.
- **Mobile burden:** do not require precision target switching and four simultaneous gestures. First test three combat actions; parry/charged attacks are optional depth after comfortable basics.
- **Scope relapse:** the old bridge accumulated many interacting features before the central activity became satisfying. Make further scope contingent on the duel and short-route gates. If even sword/shield/dodge is hard to read, temporarily compare attack plus dodge alone before adding another system.

The maintainer selected the small single-hero sword/shield experiment as the next test in issue #236. Its source/check and human acceptance status belong to the current plan; that assignment does not establish that the later roadmap or lore is implemented.
