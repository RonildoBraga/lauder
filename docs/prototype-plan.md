# Lauder — bridge-only prototype

**Updated:** 28 November 2026

**Status:** The Brooklyn Bridge remains the only playable scene after the [bridge-only reset](decisions/0017-bridge-only-reset.md). The [two-leader pilot](#two-leader-party--in-development) is authorised and in development; source checks and independent diff review pass, with recorded Simulator evidence tracked on its PR. [Maintenance build 46](#build-46-maintenance-testflight-preview), frozen main/archive source `e025cc6`, remains the delivered comparison, with its verified release evidence preserved below. The pilot has not been merged or uploaded, and physical controls/touch, audio, combat feel and sustained phone performance remain unverified. Builds 33–46 retain their source-specific records.

The [leg-break stagger](#leg-break-stagger--in-development), under closed [issue #199](https://github.com/RonildoBraga/lauder/issues/199), is merged in [PR #202](https://github.com/RonildoBraga/lauder/pull/202) and delivered in [build 40](#build-40-testflight-preview). Its original full local check and three final rendered encounters passed on `4e114bb`; the release reran source-bound checks on frozen main `9b5ec53` and verified the packaged Simulator routes separately. The preceding locomotion, ordinary damage, cover/spacing and retaliation checks retain their actual sources below. Generic phone feedback for build 39 and earlier previews does not establish controls, audibility, combat feel or sustained performance for build 40.

The bridge concept and camera B remain selected. The maintainer accepted C's Blender form and walking/turning/shooting studies, then assigned its first-tower runtime integration and Simulator movement/shooting tests. The guard replaced the first human shooter; since 26 November the three meet it together, and it is the bridge's only fight. A stays a possible later different-weapon variant; B is unselected. This is a bounded prototype of the [first-tower encounter](encounters/bridge-spider-bot.md), not an assignment for additional scenes or enemy types.

On 25 November 2026 the maintainer replaced the party's figures with [pawns](visual-direction.md#characters-and-interface) and asked for a [dodge roll](decisions/0019-dodge-roll.md) to escape attacks, then said **“Start building”**. Their verification is recorded under [Pawns and dodge roll](#pawns-and-dodge-roll).

On 26 November 2026 the maintainer asked for three changes to the controls: one leader switch on L1 / LB that goes round the party, the status panel's toggle moved from Circle / B into the pause menu, and a [lock-on](decisions/0020-lock-on.md) on a press of the right stick. Their verification is recorded under [Controls pass](#controls-pass).

Later that day the maintainer started Miki, Tom and Laura together and kept the first-tower guard as the bridge's only fight. That change is recorded under [Three together](#three-together). In the same message the maintainer gave each character two weapons to switch between, recorded under [Paired weapons](#paired-weapons).

## Two-leader party — in development

The maintainer accepted the first increment with **“Ok proceed with your suggestion”** ([issue #225](https://github.com/RonildoBraga/lauder/issues/225); chat, 28 November 2026, no public permalink). It keeps all three travellers, toggles normal control **Miki → Tom → Miki** in travel and combat, and keeps Laura as safe ranged AI support under explicit Attack. She retains orders, cover/leash, withdrawal and lifecycle authority without remote sword-leg pursuit. Either selectable fighter can win with ordinary damage; no Laura-only progress gate is added.

The existing input path, weapon/enemy tuning, injury/Retry rules, Tom-only manual shield/grenade and optional west bypass remain the baseline. Healing/revive, transferring leg damage to Tom, a scouting/salvage objective, inventory and new art remain proposals. The authored sword, underlying leg rules and their native fixtures remain retained; they are not a new pilot attack or a reason to force Laura into the control cycle.

**Verified source:** [PR #228](https://github.com/RonildoBraga/lauder/pull/228), commit `4f569a59a3e4633f8ec7a94b2403c959ce3f6d2b`, passes the complete `./scripts/check` on Xcode 27.2 and an iOS 27 iPhone Simulator, completed at **2026-11-28 01:27:10 UTC**. This includes declaration and tooling contracts, 54 Blender tests, sixteen generated sounds, strict formatting, the app build and hosted Swift Testing, including all seventeen headless routes. Normal routes assert that Laura never becomes leader; controller, keyboard and touch Switch edges toggle the two fighters. Native planner-to-weapon tests establish real Laura shotgun damage under both leaders, wall/ally blockage, distant-shot refusal, explicit Attack/Defend and quiet engagement, no sword/leg contacts, and cached-goal invalidation. The retained sword, leg, cover, lethal-third-contact and reset fixtures use explicit initial actors rather than making Laura selectable through Switch. Independent review of the committed diff found no actionable findings.

**Recorded Simulator evidence:** On frozen source `4f569a5`, `weapons` passes **35/35**, `companions` **32/32** and `touch-fight` **53/53**, each with zero Retry/party-stop diagnostics. Tom's dome blocks two actual shots, and Laura contributes 360 damage through native ranged support in the companion run. The HUD visibly identifies Laura as support, and the shared Switch input selects only Miki/Tom. Follow-up app source `3117dd8eca746e7cb13868ecfb81087983e2935f` changes only the guard's stale sword/leg advice to eye/body guidance; gameplay, native tests and assets are unchanged. [PR #228](https://github.com/RonildoBraga/lauder/pull/228) records exact follow-up checks and the new full shipped `opening` and `touch-fight` recordings. The native suite, rather than the normal pilot routes, retains sword/leg/stagger contact proof.

**Remaining gates:** Affected controls/lifecycle and sustained performance on the baseline phone remain unverified. Simulator success does not establish physical controller forwarding, multi-touch, audio/haptics or enjoyment. Claude's review is requested on the PR; requesting it is not a completed review. Review, the phone milestone and a separate release go-ahead remain gates; no merge or TestFlight upload is claimed.

**Support-arrival follow-up:** Automated review on PR #228 identified an exact-position comparison that could leave Laura waiting for a covered target after her movement motor had already settled short of it. The correction recognises the motor's arrival tolerance while retaining close-range, legality, spacing and threat safety at her actual position. Its regression drives the real motor and collision resolution to a nonexact stop with a blocked guard shot, then checks that safe support can consider a pack target. Exact follow-up source, negative-control, check and recorded results belong to the PR; earlier results above retain their original sources.

## Build 46 maintenance TestFlight preview

**Verified availability:** The maintainer requested the latest merged build through TestFlight (chat, 28 November 2026; no public permalink). Fresh Lauder-specific discovery selected unused **0.1.0 (46)**. Version-only [PR #223](https://github.com/RonildoBraga/lauder/pull/223), reviewed head **`4a27571752dcff9a6e3b27d8a6e2338ce382cb40`**, passed [Check 204](https://github.com/RonildoBraga/lauder/actions/runs/46079683396) and merged as **`e025cc6c938ea72fbd8f1143c86a3ef46c6b5ece`** with the same complete tree. The gameplay baseline is **`2bb7337a281080d54d54e586399b31069fd26c17`**, after PRs #219–#222 merged. This is maintenance of the existing bridge encounter: retired content removed, combat rules shared, companion engagement explicit and native/DEBUG verification strengthened. It introduces no new mechanics, balance changes or artwork and does not resolve the remaining tuning and wreck-behaviour findings in issues #200/#209.

A fresh full source-bound `./scripts/check` passed on frozen main `e025cc6` at **2026-11-27 23:24:47 UTC**, including **all seventeen headless routes**, native regressions, formatting, build, tooling contracts and **sixteen sound fingerprints**. Earlier gameplay verification on reviewed source `de07a84` passed **89/89 targeted test groups**, rendered **`crawler-fight` 29/29** and **`drone-fight` 23/23** with zero Retry/party-stop diagnostics. Those results retain their actual source; they are not new rendered runs of the build 46 packaging. The version-only preparation preserves that gameplay code, tests and assets.

The normal-main Release archive passed identity/version/build, configured-team signature and matching-dSYM verification at **2026-11-27 23:25:13 UTC**. The independent pre-upload audit passed **86 assertions**, checking source/check-log binding, the archive fingerprint and internal export policy, all **25 runtime resources** (**sixteen WAVs, eight USDZs and the 995-byte acknowledgement**), and actual robot-USD credit metadata. The single API-authenticated upload succeeded with exit code 0 at **23:28:21 UTC**. Fresh Apple readback at **23:32:46 UTC** confirmed **COMPLETE**, **zero errors**, **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired identity-confirmed build, all intended existing internal groups containing build 46 and unchanged group/tester membership. Exact **en-AU** notes readback passed at **23:32:21 UTC**; the actual related-build endpoint joined those notes to build 46 at **23:32:23 UTC**. The independent post-upload audit passed **100 assertions**, reconfirming the unchanged archive fingerprint, source/check/signature/dSYM and resource/credit checks, actual Apple app/build/version and group/tester joins, and exact notes/related-build identity.

Choose **TestFlight → Lauder → Update**. The notes ask testers to check controller/touch movement, switching, Attack/Defend, rolls, Tom’s shield, damage, arrival and Retry, including Pause and controller reconnection. Physical input/multi-touch, audio, combat feel, readability and sustained phone performance remain unverified. Archive, symbols and private evidence are retained. No tester invitation, uninstall, store-availability change or public App Store submission occurred. Build 45 and the earlier delivery records remain unchanged.

## Build 45 combined TestFlight preview

**Verified availability:** Under the maintainer-authorised combined delivery, [PR #212](https://github.com/RonildoBraga/lauder/pull/212) merged as **`4db6dcc1cf5a7a040c392831cb3990f5e48dc758`**, whose complete tree equals final reviewed candidate **`d33e9179bee8f56f80bef63b199ecf4ce50024d8`**. [Check 181](https://github.com/RonildoBraga/lauder/actions/runs/45973201590) passed before merge. This includes the crawler pack, the reviewed #215 grenade-input/covered-route and #216 robot-credit fixes, and #217’s stable warning target. Issues #208/#217 are closed; #200/#209 retain their broader backlog. Fresh Lauder discovery selected unused **0.1.0 (45)**. Build 44 and its general phone acceptance remain unchanged.

A fresh full source-bound `./scripts/check` passed on that exact frozen main at **2026-11-27 09:49:06 UTC**: **15 declaration mutation tests, 31 offline release contracts, six recorder regressions, 54 Blender tests and seventeen sound fingerprints**, strict formatting, build and hosted Swift Testing including **all seventeen headless routes**, the native warning-target regression and grenade/cover assertions. Earlier combined verification passed on **`a4392c0bdc56f3199c3ee9c9f4b7e10826dce693`**; `d33e917` differs only in three reviewed Markdown corrections, with app code, tests, tooling and assets byte-identical. Installed build 45 passes rendered **`crawler-fight` 27/27**, **`drone-fight` 23/23** and **`touch-fight` 52/52**, with zero retries or party-stop diagnostics. The crawler route exercises the shipped guard/drone/crawler fight; the drone and touch routes retain their narrower fixtures, so the touch result is not combined touch/crawler verification.

The normal-main signed Release archive passed identity/version/build, configured-team signature and matching-dSYM verification. The independent pre-upload audit passed **111 assertions**, including all **26** source/LFS resources, the **995-byte** canonical/bundled credit and actual robot-USD metadata, source/check-log binding and internal export policy. The single API-authenticated upload and processing wait both succeeded with exit code 0. At **2026-11-27 09:56:40 UTC**, Apple readback confirmed **COMPLETE**, **zero errors**, **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired identity-confirmed build, all intended existing internal groups containing build 45 and unchanged group/tester membership. Exact **en-AU** notes readback passed at **09:56:46 UTC**, and the actual related-build endpoint joined those notes to build 45 at **09:56:47 UTC**. Fresh final Apple status at **09:57:43 UTC** reconfirmed availability. The independent post-upload audit passed **127 assertions**, confirming the unchanged archive fingerprint, source/signature/dSYM and all resource/credit checks, actual Apple app/version and group/tester joins, and exact notes/related-build identity.

Choose **TestFlight → Lauder → Update**. Archive, symbols and private verification evidence are retained. Build 44’s general phone feedback is not physical acceptance of build 45; its controls/multi-touch, audio, readability, balance and sustained phone performance remain unverified. No tester invitation, uninstall, store-availability change or public App Store submission occurred.

## Build 43 combined TestFlight preview

The maintainer requested **“Go ahead and use git issues to coordinate with Claude to fix #207 and add the missing companion tests, then check CI, merge PR #203 and deploy the combined build to my phone using TestFlight.”** (chat, 27 November 2026; [relayed assignment](https://github.com/RonildoBraga/lauder/issues/207#issuecomment-7211706369)). Claude [owns the fixed warning target and existing warning tests](https://github.com/RonildoBraga/lauder/issues/207#issuecomment-7211731957); Codex owns a new companion/drone native test file and rendered route. The starting baseline was PR #203 head `c7ce02b`; that PR subsequently merged as `a71a9f9`. This does not assign another enemy or any Blender changes.

Fresh Lauder-specific discovery selected unused **0.1.0 (43)**, [reserved for this combined release](https://github.com/RonildoBraga/lauder/issues/207#issuecomment-7211768367). Claude’s warning-target fix `3e5d362` is integrated: a warning stays with its named member/last-seen point, and elapsed warning time cannot transfer to someone else. The installed Simulator build reports **0.1.0 (43)**.

**Verified delivery:** Internal **0.1.0 (43)** is available to the existing Lauder TestFlight testers. PR #203 merged as **`a71a9f95fb554e3cd10b18823adb5caca78c371e`**, whose complete tree equals reviewed head **`c6e6cb8ecb6df06530c72aece8d62df64fe6aa3f`**. [Check 159](https://github.com/RonildoBraga/lauder/actions/runs/45955397426) passed at **2026-11-27 07:16:43 UTC**. A fresh full source-bound `./scripts/check` passed on that exact frozen main at **07:21:51 UTC**, including the contracts, formatting, build and all sixteen headless routes and native tests recorded below. App/test/tooling content remains identical to the earlier gameplay verification source `4800560`.

The signed Release archive passed identity/version/build, configured-team signature and matching-dSYM verification. Independent pre/post-upload audits confirmed source/check-log binding, unchanged archive fingerprint, internal export policy, all seventeen bundled WAVs and the source-identical scout-drone USDZ. The single API-authenticated upload succeeded with exit code 0 at **2026-11-27 07:26:25 UTC**. At **07:31:03 UTC**, fresh Apple readback confirmed **COMPLETE**, **zero errors**, **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired identity-confirmed build, every original internal group containing build 43 and unchanged group/tester membership. Exact **en-AU** notes readback passed at **07:30:59 UTC**, with the related-build endpoint joined to build 43 at **07:31:00 UTC**. Archive, symbols and full private evidence remain retained.

**Verified source: `48005603db05316d967e1dcf54dc0ba569abb05b`.** The full `./scripts/check` passes: **13 declaration contracts, 31 offline release contracts, 52 Blender tests, seventeen sound fingerprints**, strict formatting, app build and hosted Swift Testing, including **all sixteen headless routes**, twenty drone tests and the four new native companion/drone tests. The new coverage uses the production companion override, explicit orders, actual blockers, vulnerable drone-only injury/Retry and Pause/Resume and Restart state. Independent code/test review found no findings. [Claude’s actual review of final head](https://github.com/RonildoBraga/lauder/pull/203#issuecomment-7212364436) reported no blocking finding, with the coverage limits below. Cancellation of a drone warning queued before a same-frame death or Retry has not been verified.

All three final rendered Simulator routes pass with **zero retries and zero party-stop diagnostics**:

| Route | Completed steps | Duration | Peak injuries: Miki / Laura / Tom |
|---|---:|---:|---:|
| `companion-drones` | 30/30 | 66.950 s | 0 / 0 / 2 |
| `drone-fight` | 23/23 | 67.763 s | 0 / 0 / 1 |
| `touch-fight` | 52/52 | 57.483 s | 1 / 0 / 0 |

At the `companion drone down` mark (**53.333 s**), the guard still has **1,500 HP**; Tom has applied **60** damage to `drone.2` through **twenty** native hits, while Miki has dealt **zero**. Target/member accounting establishes the companion contribution before player damage or guard defeat; the route then exercises Defend/Pause and the combined finish. The touch route records **zero non-touch input frames**, but runs on the guard-only fixture: it is a touch regression, not combined touch/drone verification. Recordings and traces are retained privately; Simulator pacing is not phone-performance evidence.

**Remaining coverage limits:** Defend and Go test windows do not require an eligible drone dive; actual drone damage is not isolated from a guard-aimed round intercepting the drone; world-level `.avoiding` precedence is deferred to #208. A queued warning’s same-frame death/Retry sound cancellation remains unverified. These acknowledged limits and broader [quality follow-ups in #209](https://github.com/RonildoBraga/lauder/issues/209) do not describe additional fixes in build 43. The earlier touch route is guard-only, so combined touch/drone play, phone audio and sustained performance remain unverified.

Choose **TestFlight → Lauder → Update**. Issues #201/#207 are closed after the merge. PR #206 was closed as incorporated after its byte-identical build 42 record reached main; it was not separately merged. Build 33–42 records retain their original sources and checkpoints. No tester invitation, uninstall, store-availability change or public App Store submission occurred. The source remains frozen; later quality work does not change this delivered archive.

## Build 42 TestFlight preview

The maintainer requested **“Go ahead and check CI and Claude’s feedback on PR #205, address anything outstanding, then merge PR #204 followed by PR #205 and deploy the updated build to my phone using TestFlight.”** (chat, 27 November 2026; no public permalink). Fresh Lauder-specific discovery confirmed **0.1.0 (42)** was unreserved. [Build 41 was reserved separately for Claude’s PR #203 preview](https://github.com/RonildoBraga/lauder/pull/203#issuecomment-7211005454); this package excludes drones.

**Verified delivery:** Internal **0.1.0 (42)** is available to the existing Lauder TestFlight testers. PR #204 merged first as `162ae8`, then PR #205 as **`4789ed077c5267b8661acc52b86bcb47a7b5467d`**. This frozen main/archive source’s complete tree equals final reviewed package `33eb72d158eb7dfc0c905caf8af0335e763c9839`; **Check 151** passed at **2026-11-27 06:11:57 UTC**. Automated review reported no findings. [Claude’s actual post-merge review](https://github.com/RonildoBraga/lauder/pull/205#issuecomment-7211464238) confirmed orders, safety, Laura’s role and the integration boundary, with no further code change required.

A fresh full `./scripts/check` passed on frozen main at **2026-11-27 06:17:35 UTC**: **13 declaration contracts, 31 offline release contracts, 52 Blender tests, seventeen sound fingerprints**, strict formatting, app build and hosted Swift Testing including **all fourteen headless routes** and the native body-shot regressions. Packaged **0.1.0 (42)** passes rendered `companions` **32/32** in **83.03 s** and `touch-fight` **52/52** in **57.50 s**, with zero retries/party-stop diagnostics and zero non-touch frames for the touch route. Peak injuries are respectively **0 / 0 / 1** and **1 / 0 / 0** for Miki / Laura / Tom. These are encounter regression checks; the native fixture establishes blocked-eye/body-shot causality, as recorded below.

The signed archive passed identity/version/build, configured-team signature and matching-dSYM verification. Independent pre/post-upload audits confirmed source/check-log binding, the unchanged archive fingerprint, internal export policy and all seventeen bundled sound resources. The single API-authenticated upload succeeded with exit code 0 at **2026-11-27 06:21:21 UTC**. At **2026-11-27 06:24:11 UTC**, fresh Apple readback confirmed **COMPLETE**, **zero errors**, **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired identity-confirmed build, every original internal group containing build 42 and unchanged group/tester membership. Exact **en-AU** notes readback passed at **06:24:07 UTC**; the related-build API response joined the notes to build 42 at **06:24:08 UTC**. The [shared delivery report](https://github.com/RonildoBraga/lauder/pull/205#issuecomment-7211502381) records the release.

Choose **TestFlight → Lauder → Update**. The separate drone preview is available under previous build 41, not included here. Phone installation, controls/multi-touch, audio/haptics, combat feel and sustained performance remain unverified for build 42. No tester invitation, uninstall, store-availability change or public App Store submission occurred. Archive, symbols and private verification evidence are retained.

## Companion body-shot fallback — in development

The maintainer requested **“Go ahead with your recommendations, starting with the companion body-shot fallback. Coordinate with Claude to avoid overlapping work and test the changes in the simulator.”** (chat, 27 November 2026; [relayed assignment](https://github.com/RonildoBraga/lauder/issues/200#issuecomment-7210709561)). This first increment addresses issue #200 item 6 and its realistic-fallback regression coverage in item 4. It is based on documentation-only [PR #204](https://github.com/RonildoBraga/lauder/pull/204), source `7a9b8db`, whose runtime matches delivered main `9b5ec53`; that documentation PR subsequently merged as `162ae8`.

The [companion contract](companion-autonomy.md#body-shot-fallback-follow-up) preserves a direct safe eye shot first, then allows Miki/Tom a useful body shot from their current legal, spaced stance before keeping or seeking an eye orbit. Native weapons, threat avoidance, orders and Laura’s leg pursuit remain unchanged. The [coordination boundary](https://github.com/RonildoBraga/lauder/pull/203#issuecomment-7210709848) reserves the guard-planner change and focused tests for this branch; Claude’s drone targeting/firing and post-plan override remain separate.

**Verified source: `e764b305ba2ec8e1cc373188889436b37c6dc10c`.** The full `./scripts/check` passes: **13 declaration contracts, 31 offline release contracts, 52 Blender tests, seventeen sound fingerprints**, strict formatting, app build and hosted Swift Testing including **all fourteen headless routes** and the new native body-shot fixture. Native regressions retain the actual exposed eye and hull, block only the eye shot, and verify ordinary Miki/Tom damage through real geometry and weapon handling, including per-step damage accounting, draw/spin-up, cadence and ammunition. Actual wall and ally blockers produce zero shots. Direct-eye priority and safety/order/leader/lifecycle gates retain focused coverage.

The unchanged rendered Simulator routes pass with **zero retries and zero party-stop diagnostics**:

| Route | Completed steps | Duration | Peak injuries: Miki / Laura / Tom |
|---|---:|---:|---:|
| `companions` | 32/32 | 82.0 s | 0 / 0 / 1 |
| `retaliation` | 29/29 | 59.6 s | 0 / 0 / 0 |
| `touch-fight` | 52/52 | 57.5 s | 1 / 0 / 0 |

The touch route records **zero non-touch input frames**. These routes use ordinary shared inputs and native combat, without immunity, teleportation or a changed driver; their summaries do not prove that a particular hit used the fallback. The targeted native regressions establish that cause. Independent production review found no finding. A scratch three-way text merge with Claude’s PR #203 head `e788229` retains both `Intent.drone` and the new planner branch; this is not a combined drone playtest.

This increment merged in PR #205 as `4789ed0` and is delivered in [build 42](#build-42-testflight-preview); the earlier build 40 does not contain it. Phone controls, sustained performance and combat feel remain unverified for this change. Other enemy/companion ideas remain separate work.

## Build 40 TestFlight preview

The maintainer requested **“Go ahead and check CI and any review feedback on PR #202, address anything outstanding, then merge PR #198 followed by PR #202 and deploy the updated build to my phone using TestFlight.”** (chat, 27 November 2026; no public permalink). This authorises the reviewed stagger release. The separate enemy/companion intelligence request remains research/design work, not additional gameplay in this build. Fresh Lauder-specific discovery checked its own bundle-ID record and accepted/processing uploads, selected unused **0.1.0 (40)** and retained the existing tester/group baseline.

**Verified delivery:** Internal **0.1.0 (40)** is available to the existing Lauder TestFlight testers. PR #198 merged first as `4f0a780`. [Check 142](https://github.com/RonildoBraga/lauder/actions/runs/45942081684) passed on final reviewed package head `088d77cad95aa13dd41fa782ee02502d1ff054a3` at **2026-11-27 05:08:44 UTC**, with no outstanding review finding. PR #202 then merged as **`9b5ec531252c5800ba5cfd02fd294a172fe88426`**, closing issue #199. This exact frozen main/archive source has the same complete tree as the checked head and preserves the `4e114bb` gameplay with release metadata/documentation.

The release workflow reran the full `./scripts/check` successfully on `9b5ec53`: **13 declaration contracts, 31 offline release contracts, 52 Blender tests, seventeen sound fingerprints**, strict formatting, app build and hosted Swift Testing including **all fourteen headless routes**. The packaged Simulator build identifies **0.1.0 (40)** and passes `robot-parts` **35/35** and `touch-fight` **52/52**; the earlier three-route results below retain their actual source. The signed archive passed identity/version/build, configured-team signature and matching-dSYM verification. Independent pre/post-upload audits verified source/check-log binding, the unchanged archive fingerprint, internal export settings and all seventeen bundled sounds. The single API-authenticated upload succeeded with exit code 0 at **2026-11-27 05:18:21 UTC**.

At **2026-11-27 05:21:05 UTC**, fresh Apple readback confirmed **COMPLETE**, **zero errors**, **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired build and the expected identity. Every original intended internal group contains build 40; group/tester membership is unchanged and availability is verified. The **en-AU** testing notes were read back exactly at **2026-11-27 05:21:01 UTC**; independent inspection of their related-build API response joins them to build 40 and confirms the desired text.

Choose **TestFlight → Lauder → Update**. Physical installation, controls/multi-touch, audio/haptics, combat feel and sustained phone performance remain unverified for build 40. No tester invitation, uninstall, store-availability change or public App Store submission occurred. Task-owned temporary build output was removed after Xcode operations finished; the archive, symbols and full evidence remain retained privately.

## Leg-break stagger — in development

After reporting basic build 39 phone success, the maintainer accepted the proposed short leg-break stagger, distinct mechanical sound/body reaction and fresh full warning with **“Ok proceed”** (chat, 27 November 2026; no public permalink). [Issue #199](https://github.com/RonildoBraga/lauder/issues/199) records the bounded assignment. The [robot contract](robot-eye-legs-grenades.md#leg-break-stagger-follow-up) owns timing, recovery, physical alignment and lifecycle rules. This changes no scene, asset model or input binding.

Work is based on [PR #198](https://github.com/RonildoBraga/lauder/pull/198)’s documentation-only build 39 record, whose app/assets/tests/tooling match shipped main `2b35510`; that documentation PR subsequently merged as `4f0a780`. The new implementation and sound are not included in build 39. The initial implementation assignment did not authorise merge or upload; the later explicit [build 40 request](#build-40-testflight-preview) authorised the focused release, now merged in PR #202 and verified as available to the existing testers.

**Verified source: `4e114bb2171889bc4bec2394cf1b2e0fcae3636f`.** The full `./scripts/check` passes with Xcode 27.2 and an iPhone 17 / iOS 27 Simulator: **13 declaration contracts, 31 offline release contracts, 52 Blender tests, seventeen generated sound fingerprints**, strict Swift formatting, app build and hosted Swift Testing including **all fourteen headless routes**. Value and native-contact regressions cover admission, interrupted attacks, preserved recovery, normal pattern/reposition completion, fresh warnings, repeated breaks, resolved injuries, targeting, Pause/bypass/reset and physical alignment. Loaded-model regressions verify death preserves the current reaction height after zero, one, three and four leg losses.

All three final rendered Simulator routes pass with ordinary shared inputs, normal vulnerability, **zero retries and zero party-stop frames**:

| Route | Completed steps | Duration | Peak injuries: Miki / Laura / Tom |
|---|---:|---:|---:|
| `robot-parts` | 35/35 | 72.2 s | 2 / 0 / 0 |
| `first-fight` | 36/36 | 92.3 s | 2 / 0 / 1 |
| `touch-fight` | 52/52 | 56.5 s | 1 / 0 / 0 |

The `robot-parts` marks show a real first leg break at **1,230 HP**, a **0.600 s** opening and robot shot serial **11 → 11**, with no attack during the stagger. It returns to recovery, then begins a fresh Notice at **63.593 s** after the break at **59.909 s**. All three contribute; Tom’s **180** grenade damage remains included in the **1,500** applied total. Each route reaches native victory and Restart, restoring **1,500 HP**, all legs and hidden state. The touch route records **zero non-touch input frames**. Recordings, traces and full results are retained privately.

The pre-existing all-leg wreck settling limitation and the other recommendations in [issue #200](https://github.com/RonildoBraga/lauder/issues/200) remain separate follow-ups; preserving the current drop on death does not implement continued post-defeat settling. Physical audibility, controls, combat feel and sustained phone performance remain unverified for this stagger. Build 39’s basic phone report does not establish them, and Simulator timings are not phone-performance evidence. This implementation subsequently merged in PR #202 and is delivered in [build 40](#build-40-testflight-preview), closing issue #199; it remains absent from build 39.

## Build 39 TestFlight preview

The maintainer requested **“Go ahead and check CI and any review feedback on PR #197, then merge it and deploy the updated build to my phone using TestFlight.”** (chat, 27 November 2026; no public permalink). This authorises the reviewed locomotion merge and its internal TestFlight delivery, including necessary build metadata.

Fresh discovery through Lauder’s release command checked its own bundle-ID record, builds and accepted/processing uploads, selected unused **0.1.0 (39)** and retained the existing tester/group baseline. PR #197 included the unchanged `b6e0b83` gameplay together with the build-number change and preparation documentation.

**Verified delivery:** Internal **0.1.0 (39)** is available to the existing Lauder TestFlight testers.

[Check 137](https://github.com/RonildoBraga/lauder/actions/runs/45934817697) passed on final reviewed package head `d1735e3` at **2026-11-27 03:49:29 UTC**. PR #197 merged as **`2b35510d64675c6c8a3d0aa241f8e0eb49d0c293`**, with the same complete tree as that checked head; issue #196 is closed. This exact frozen main commit is the **0.1.0 (39)** archive source.

The release workflow reran the full `./scripts/check` successfully on `2b35510`: **13 declaration contracts, 31 offline release contracts, 52 Blender tests, sixteen sound fingerprints**, strict Swift formatting, app build and hosted Swift Testing including **all fourteen headless routes**. The signed Release archive passed identity/version/build, configured-team signature and matching-dSYM verification; its passed check receipt is bound to the source and full-log digest.

Independent pre- and post-upload artifact audits passed the source/check-log binding, identity/team/signature, matching dSYM, archive fingerprint and fixed internal export policy. The single API-authenticated upload succeeded with exit code 0 at **2026-11-27 03:57:03 UTC**.

At **2026-11-27 03:59:38 UTC**, fresh Apple readback confirmed upload **COMPLETE**, **zero errors**, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired build and the expected identity. Every original intended internal group contains build 39; group and tester membership are unchanged, and availability to those testers is verified. The **en-AU** testing notes were written and read back exactly at **2026-11-27 03:59:18 UTC**, matching the desired text.

Choose **TestFlight → Lauder → Update** for the phone comparison. The earlier build 38 report of “It worked” does not verify build 39’s locomotion, physical controls, multi-touch, audio/haptics, balance or sustained performance. No tester invitation, uninstall, store-availability change or public App Store submission occurred. Private archive, symbols and full verification evidence are retained.

### Subsequent phone feedback and leg-break follow-up

After the delivery checkpoint above, the maintainer reported basic phone success for build 39 and accepted the leg-break stagger proposal with **“Ok proceed”** (chat, 27 November 2026; no public permalink). This does not establish exhaustive controls, audio quality or measured phone performance. [Issue #199](https://github.com/RonildoBraga/lauder/issues/199) assigns the separate [stagger implementation and Simulator verification](#leg-break-stagger--in-development); it is not part of the delivered archive and adds no merge or TestFlight authorisation. The delivery proof above remains unchanged.

## Leg-loss locomotion — in development

After testing build 38, the maintainer said **“It worked”**, authorised merging PRs #193/#195, and requested **“When the robot lost a leg, its walking and spinning capabilitis needs to be compromised”** (chat, 27 November 2026; no public permalink). [Issue #196](https://github.com/RonildoBraga/lauder/issues/196) records this focused follow-up. The implementation retains the existing translation penalties, reduces physical body turns after each loss and slows the remaining feet’s steps. The [robot contract](robot-eye-legs-grenades.md#leg-loss-locomotion-follow-up) owns its starting tuning and preserved attack/geometry boundaries.

Gameplay implementation **`b6e0b83ba077e1b4f19d9d5a681851abdec5c7a1`** preceded build 39 packaging on `codex/robot-leg-locomotion`. Before that package was prepared, only the three unpublished implementation/documentation commits were rebased onto merged main `35945ff`: `b6e0b83` and actual full-check source `3c0cb6b` have the identical complete `apple` tree **`62f510e836485612f9da144d70922035a4ad997a`**, with no difference in app, assets, tests, Blender, scripts or CI content. The result records below retain their actual pre-rebase execution SHAs.

Independent review of the initial `aa9d0f5` implementation found no blocker. A fresh full `./scripts/check` **passes on `3c0cb6b`**: **13 declaration contracts, 31 offline release contracts, 52 Blender tests, sixteen sound fingerprints**, strict Swift formatting, app build and hosted Swift Testing including **all fourteen headless routes**. Native regressions cover progressive walking/turning impairment, exact zero/invalid-input stopping, grounded warning/firing, planted-foot reach, Pause and reset; the existing committed aim and real hit geometry retain their checks.

Fresh rendered iPhone 13 Pro Max / iOS 27.0 Simulator comparisons pass on preceding source **`aa9d0f5`**. The later `3c0cb6b` only prevents numerical facing drift when the requested turn factor is zero or invalid; normal positive-factor gameplay, assets, input and the gait are unchanged:

| Route | Duration | Normal / eye-critical damage | Grenade damage (included in normal) | Legs lost before victory | Retries / party-stop frames | Maximum labels | Body overlap |
|---|---:|---:|---:|---:|---:|---:|---:|
| `robot-parts` | 64.6 s | 330 / 1,170 | 180 | 1 | 0 / 0 | 6 | 2.3% |
| `touch-fight` | 57.4 s | 183 / 1,317 | 0 | 2 | 0 / 0 | 5 | 1.5% |

Both complete native victory and Restart, restoring health to **1,500** and lost legs to **zero**. The first completes 35/35 steps and records member damage **432 / 90 / 978** for Miki / Laura / Tom, with peak injuries **2 / 0 / 1**. The touch route completes 52/52 steps with **zero non-touch input frames**, member damage **1,155 / 180 / 165** and peak injuries **1 / 0 / 0**. Every member contributes. These rendered comparisons exercise one and two leg losses; the other loss counts are covered by rule/native tests rather than these recordings. The touch route does not throw a grenade, and sampled touch input is not physical multi-touch evidence. The routes ran on a separate Simulator alongside regression checks, so their pacing does not establish phone performance. Private recordings, traces and captures are retained.

The follow-up merged in [PR #197](https://github.com/RonildoBraga/lauder/pull/197) as `2b35510`, closing issue #196 after successful final-head CI and review checks. The [build 39 delivery](#build-39-testflight-preview) now makes the locomotion available to the existing testers after a fresh full archive-bound check, signed archive verification and Apple/notes readback. Build 38 remains the earlier phone comparison; its basic success report does not verify this new locomotion or establish exhaustive controls, sound/haptics, balance or sustained performance.

## Build 38 TestFlight preview

The maintainer requested **“Go ahead and check CI for PR #193, then deploy the updated build to my phone using TestFlight so I can test the new combat mechanics.”** (chat, 27 November 2026; no public permalink). This explicitly authorises an internal preview without merging PR #193 or claiming physical acceptance. [Check 123](https://github.com/RonildoBraga/lauder/actions/runs/45927652845) passed on exact `84d4576`; automatic Codex review completed without findings on its equivalent application/test source `303617b`.

The earlier build 33–37 stack is now merged into main. Its merged base `2532577` has exactly the tree of `a44537e`; recording that ancestry changed no files. The later main `07af9fd` changes only three status documents, incorporated in `a5fa434` without changing reviewed app, asset, test or tooling content. PR #193 remains unmerged. Exact app/archive source **`d08ae6f5aa3eb43baa2664f4279bfa09fd8d9b0c`** on `codex/testflight-robot-combat` adds only the discovered build number and preparation documentation, through [PR #195](https://github.com/RonildoBraga/lauder/pull/195). The subsequent delivery record does not change the archived application.

Fresh Apple discovery for Lauder's bundle ID checked builds and accepted/processing uploads, selected unused **0.1.0 (38)** and retained the existing tester/group baseline. The preview carries persistent eye criticals, independently detachable sword-damaged legs and Tom-only manual grenades; the [bounded contract](robot-eye-legs-grenades.md) owns the exact controls and starting tuning. All previous squad commands, actual cover and the quiet bypass remain intact.

**Verified delivery:** Internal **0.1.0 (38)** is available to the existing Lauder TestFlight testers.

- Independent delta and artifact reviews passed; automatic Codex review completed without findings on exact archive source `d08ae6f`. [Check 123](https://github.com/RonildoBraga/lauder/actions/runs/45927652845) passed on reviewed `84d4576`, and [Check 130](https://github.com/RonildoBraga/lauder/actions/runs/45929680594) passed on the synchronized feature head `a5fa434`. These hosted results are distinct from the fresh archive-bound check below.
- The release workflow reran the full `./scripts/check` on `d08ae6f`: **13 declaration contracts, 31 offline release contracts, 52 Blender tests, sixteen sound fingerprints**, strict formatting, app build and hosted Swift Testing including **all fourteen headless routes**. The preceding rendered comparisons remain evidence for the unchanged gameplay source.
- The signed Release archive's identity, version/build, configured team, code signature, matching dSYM and archive fingerprint verified. Archive/upload used the existing API key without requiring a saved-account session or connected phone.
- At **2026-11-27 02:51:04 UTC**, Apple confirmed upload **COMPLETE**, **zero errors**, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY** and an unexpired build. Every original intended group contains build 38; group and tester membership are unchanged.
- The **en-AU** test notes were written and read back exactly at **2026-11-27 02:50:49 UTC**. They cover eye criticals, repeated hits on one leg, Tom-only grenade controls/recharge/cover and preserved Attack/Defend.

Choose **TestFlight → Lauder → Update**; the pause screen identifies **0.1.0 (38)**. This establishes availability, not installation, physical multi-touch/VoiceOver/controller usability, sound/haptics, balance or sustained phone performance. PRs #193/#195 remain unmerged; main stays at the earlier merged baseline. No tester invitations, uninstall or public App Store submission occurred. Private archives, symbols and evidence are retained.

### Subsequent merge and phone feedback

On 27 November 2026, after the delivery checkpoint above, the maintainer reported **“It worked”** and authorised **“merge PR #193 and the TestFlight release PR #195, then update the git issues”** (chat; no public permalink). PR #193 merged as **`8ae7e1723337d776a7a857c532700ea8b55fd008`**, whose tree matches checked feature head `a5fa434`. After the dependency merge, ancestry-only commit `265f2df` preserved PR #195’s delivered tree while retargeting it to main. [Check 134](https://github.com/RonildoBraga/lauder/actions/runs/45931744507) passed on that exact head at **2026-11-27 03:22:28 UTC**; fresh review-thread and finding checks found no outstanding finding. PR #195 then merged as **`35945ff7fa5a66c3610d2418a463f6dd68bca9c2`**. Main now contains build 38’s app sources; no additional upload occurred. This is basic phone feedback, not exhaustive controls or measured performance. The separate [locomotion follow-up](#leg-loss-locomotion--in-development) is not in the delivered archive. The original delivery proof and its pre-merge checkpoint above remain unchanged.

## Crawler pack — in development

The maintainer asked for another new enemy, “Once it's merged, create another new enemy but check the git issues and comments to coordinate things with Codex”, then said “start building the crawlers now” (chat, 27 November 2026; no public permalink). Asked which enemy and where, they chose **“Crawler pack”** **“With the first guard”**.
- **The claim:** [issue #208](https://github.com/RonildoBraga/lauder/issues/208) records Claude's claim and the files it avoids.
- **The rules:** the [crawler contract](crawler-pack.md) holds the starting rules. Three crawlers get up once the guard's fight is engaged. Each walks round blockers to a member and winds up for 0.6 s, its line fixed from the start. It rams 3 m, hurting at most once, then recovers, exposed. Crawlers never wind up over the guard's attacks or two on one member, and they go down with the guard.
- **The model:** the [crawler model](../blender/assets/crawler/README.md) is simple shapes in the guard's colours.
- **The branch:** it is cut from the drones work at Codex's `c6e6cb8`. That work merged into main as #203 (`a71a9f9`, with the same tree).

**Checks, iPhone 13 Pro Max Simulator with iOS 27.0:**
- **Full check, `27e2723`:** `./scripts/check` passed. That covers contracts, release contracts, the Blender tests, the 17 sounds, formatting, the build and the whole Swift Testing suite.
- **`91d368e`, the drone and crawler warning fix:** the warning lifecycle, pack, crawler and drone suites pass, 28 tests in all. The new lifecycle test fails without the fix.
- **Rendered routes, `91d368e`:** **crawler-fight** passed 27/27 steps in 65.4 s, and **drone-fight** passed 23/23 in 70.7 s.
- **Frame time:** 16.7 ms mean and 16.8 ms p99 in the Simulator. That isn't phone performance.
- **Not checked:** phone readability, audibility, balance and sustained frame rate. Merging needs the baseline-iPhone check.

**After Codex's review**, `60b9878` fixes the three findings on PR #212: the dome's ram origin, rams sliding along walls, and pack warnings hidden by the guard's recovery text. The whole Swift suite passes, 590 tests, and each new test fails without its fix.

### Build 44 TestFlight preview

The maintainer answered “Yes, upload it” to Claude's question “Upload the crawlers to TestFlight as build 44 for a phone check?” (Claude session, 27 November 2026; no public permalink). That authorises this internal preview from the unmerged `claude/crawler-pack` branch. It does not authorise a merge. Discovery found builds up to 43 used, so the preview is **0.1.0 (44)**, committed on the branch in `d700791`.

**Delivered.**
- **Archive:** `apple/scripts/testflight archive --reviewed-preview` archived `claude/crawler-pack` at `d700791`. Before archiving, its own full `./scripts/check` passed on the frozen source. It then verified the signed archive, and the API-key upload succeeded once.
- **Apple:** at 08:30 UTC on 27 November 2026, Apple reported the build COMPLETE and VALID, internal only, in beta testing and unexpired. It is available to the existing internal testers, the internal group set and tester membership are unchanged, and the upload had no errors.
- **What was not done:** no tester was invited, no TestFlight test notes were written, and nothing was submitted to the public App Store. The archive and its symbols are kept privately.
- **The branch afterwards:** later commits change only documentation.
- **Phone check:** the maintainer played build 44 and answered “Feels right” to Claude's question “How do the crawlers play in build 44?” (Claude session, 27 November 2026; no public permalink).
  - **What it shows:** general success on the phone, not a measured check of each control, sound, balance or sustained frame rate.
  - **The merge:** it clears the baseline-iPhone gate that AGENTS.md sets for playable features. PR #212 merges under Claude's standing authorisation once its checks pass.

## Scout drones — in development

While Codex worked on the guard's leg stagger (#199), the maintainer asked for **“a different enemy”** and chose **“Scout drones”** **“With the first guard”** (chat, 27 November 2026; no public permalink). [Issue #201](https://github.com/RonildoBraga/lauder/issues/201) records Claude's claim and the files it avoids while #199 is active. The [drone contract](scout-drones.md) holds the starting rules: two drones circle the guard at 3 m, take turns to warn for 1 s and dive along a committed line with a three-round burst that hurts at most once, pass low enough for the sword, and fall with the guard. The [scout-drone model](../blender/assets/scout-drone/README.md) is simple shapes in the guard's colours.

**Checks, on `5f4f266`, iPhone 13 Pro Max Simulator with iOS 27.0:**
- **Full check:** `./scripts/check` passed: contracts, release, Blender and sound checks, strict formatting, the build and every Swift test.
- **Headless routes:** all fifteen pass, the fourteen guard-only routes and **drone-fight**.
- **Rendered drone-fight:** It passed in 69.4 s, 23/23 steps, with no retry; Laura took one hit. Miki downed both drones 9.4 s after the guard noticed the party, and the squad then dismantled the guard. Frame time averaged 16.8 ms (p99 16.8 ms, one frame of 185 ms), and the party update 1.5 ms. An earlier run on the preceding source also passed, in 70.2 s.
- **Rendered robot-parts:** on the preceding source it passed on the guard-only bridge (61.7 s, 35/35 steps), which shows the guard-only routes launch on the right level.
- **After #202 landed:** `main` was merged in as `b60f4b8`, and the full check passed on it. Codex's review then found that downed and cleared drones stopped moving once the fight ended. In `c204fb6` they keep falling and circling. The full check passed on it too. The rendered drone-fight passed again on it: 66.9 s, 23/23 steps, no retry, and Laura took one hit. Frame time averaged 16.7 ms (p99 16.8 ms, worst 62.4 ms), and the party update 1.5 ms.
- **Not checked:** these are Simulator results, not phone evidence. Controls, readability, audibility, balance, enjoyment and sustained phone performance are unchecked.

### Build 41 TestFlight preview

After the checks above, the maintainer answered “Yes, upload it” to Claude's question “Upload the drones to TestFlight for you to try?” (Claude session, 27 November 2026; no public permalink). That authorises this internal preview from the unmerged `claude/scout-drones` branch. It does not authorise a merge. Discovery found builds up to 40 used, so the preview is **0.1.0 (41)**. The branch commits that number, as the preview branches for builds 33–35 did.

**Delivered.**
- **Archive:** `apple/scripts/testflight archive --reviewed-preview` archived `claude/scout-drones` at `42d6669`. Before archiving, its own full `./scripts/check` passed on the frozen source. It then verified the signed archive, and the API-key upload succeeded once.
- **Apple:** at 05:57 UTC on 27 November 2026, Apple reported the build COMPLETE and VALID, internal only, in beta testing and unexpired. It is available to the existing internal testers, the internal group set and tester membership are unchanged, and the upload had no errors.
- **What was not done:** no tester was invited, no TestFlight test notes were written, and nothing was submitted to the public App Store. The archive and its symbols are kept privately.
- **The branch afterwards:** later commits change only documentation.
- **Phone check:** the maintainer played build 41 and answered “Feels right” to Claude's question “How do the drones play in build 41?” (Claude session, 27 November 2026; no public permalink).
  - **What it shows:** general success on the phone, not a measured check of each control, sound, balance or sustained frame rate.
  - **The merge:** it clears the baseline-iPhone gate that AGENTS.md sets for playable features. PR #203 merges under Claude's standing authorisation once its checks pass.

## Eye, legs and grenades — in development

The maintainer's build 37 playtest found ordinary hits dominant. They requested persistent eye criticals, repeated Laura sword contacts detaching individual legs and slowing the robot, and grenade throws. The task clarification selected **“Tom only; manual throws”** (chat, 27 November 2026; no public permalink). [Issue #192](https://github.com/RonildoBraga/lauder/issues/192) assigned the bounded revision based on `a44537e`; the [contract](robot-eye-legs-grenades.md) owns the rules and prototype tuning. That original implementation assignment did not authorise merge or release; the later authorisations and outcomes are recorded in the [build 38 record](#build-38-testflight-preview).

The source replaces the sensor/coupling/core gate with actual front-eye criticals and four independent sword-leg counters. It reuses the existing leg assemblies for bounded detachment and gait changes, without changing Blender assets or adding physics. Tom gets a manual grenade through shared input authority, a committed scenery-tested arc, one ordinary cover-tested blast result per enemy and an 8-second recharge that survives switching. Attack/Defend, hard orders, player leadership, warnings and the quiet bypass remain authoritative.

**Verified on source `303617b1b3f2c67d793f7c4cf6d5f8a1daebb03e`:** full `./scripts/check` passes: **13 declaration contracts, 31 offline release contracts, 52 Blender tests, sixteen sound fingerprints**, strict Swift formatting, app build and hosted Swift Testing including **all fourteen headless gameplay routes**. Native regressions verify repeated real eye criticals with all four guns; ordinary damage with all five damaging weapons; three contacts on one leg, independent later breaks and real removed volumes; movement penalties and measured grounded hull/muzzle/eye agreement; actual wall/ally/rear-body occlusion; companion authority and Defend; Tom-only grenade execution, one ordinary applied result per blast, scenery/falloff, shared recharge, Pause/reset, held contacts and pending-input ownership across substeps and switches. The initial full run passed 506/507 cases; its remaining driver-only expectation was updated for the new Laura-first demonstration before the successful complete rerun.

Independent reviews prompted fixes for oblique eye contacts, scripted party holds and a pending grenade crossing leaders; native regressions cover them. Automatic Codex review completed without findings on the same source. No Claude review of this new revision is claimed. Hosted checks for the latest documented tree are tracked in [PR #193](https://github.com/RonildoBraga/lauder/pull/193); documentation-only follow-ups retain the same application, assets, tests and tooling as `303617b`.

Fresh rendered iPhone 13 Pro Max / iOS 27.0 Simulator comparisons:

| Route | Duration | Normal / eye-critical damage | Grenade damage (included in normal) | Legs lost before victory | Retries / party-stop frames | Maximum labels | Body overlap |
|---|---:|---:|---:|---:|---:|---:|---:|
| `robot-parts` | 61.2 s | 438 / 1,062 | 180 | 2 | 0 / 0 | 8 | 0.5% |
| `touch-fight` | 57.2 s | 150 / 1,350 | 0 | 1 | 0 / 0 | 6 | 2.8% |

Both pass through native victory and Restart. Each total is exactly **1,500**, and every member contributes. The first route throws as Tom, pauses the actual flight, breaks legs through Laura's real sword and finishes with native squad support. Its member contributions are **576 / 210 / 714** for Miki / Laura / Tom. The touch-only route records **zero non-touch frames**, retains targeting, swaps, orders, Pause/status and Restart, and contributes **1,152 / 147 / 201**. Each records at most one injury to Miki and no injury to Laura/Tom. Restart restores health to 1,500 and legs lost to zero.

Inspected captures/video frames show the red eye, critical/ordinary numbers and an actual missing leg during a live fight. The early grenade mark is captured after Pause covers the scene, so that still alone does not demonstrate the projectile arc; the recording and native flight tests remain the evidence. Loaded-model tests verify complete detached assemblies, bounded props, restored geometry and real export/eye/muzzle measurements. The grenade control is covered through sampled UIKit callbacks, not physical fingers. The touch fight does not throw a grenade. The two rendered runs used a separate Simulator while the full regression suite ran; their frame times are not phone performance evidence.

**Limits and next gate:** [PR #193](https://github.com/RonildoBraga/lauder/pull/193) and release PR #195 are merged after the maintainer’s basic [build 38](#build-38-testflight-preview) phone success report. Exhaustive controls, multi-touch, audibility/haptics, enjoyment and sustained performance remain unverified. Navigation clearance stays conservative after a leg loss, debris does not collide, eye contact uses an analytical approximation, and the blast reuses an impact sound. The [locomotion follow-up](#leg-loss-locomotion--in-development) owns the new walking/turning feedback and its separate verification gate. The earlier records below retain their original sources and results.

## Build 37 TestFlight preview

The maintainer requested **“Send it to my phone for testing using the TestFlight”** (chat, 27 November 2026; no public permalink). This authorises an internal TestFlight preview of the latest reviewed changes, without merging the open stack into `main` or claiming physical acceptance. The release branch `codex/testflight-controls-audio` combines [PR #187](https://github.com/RonildoBraga/lauder/pull/187), [PR #188](https://github.com/RonildoBraga/lauder/pull/188) and [PR #189](https://github.com/RonildoBraga/lauder/pull/189). The source integration preserves their existing damage, squad authority, input release rules and native audio owners. Main remains unchanged.

Fresh Lauder-specific Apple discovery checked accepted/processing uploads and builds, identified **37** as unused, and preserved the existing tester/group baseline. Internal **0.1.0 (37)** is now available from exact app/archive source **`cce555acb5ca8502a5c3db5f5fcf5d33e56fdccb`**, recorded in [PR #191](https://github.com/RonildoBraga/lauder/pull/191). Build 36 remains the preceding delivered comparison; its results are historical evidence.

The combined source also addresses the final reviews on #187/#188: drawn order-menu items and clamped selection share geometry; release rechecks dialogue action visibility; hidden-HUD neutral guidance remains visible; projected robot width participates in the 30 pt exterior tap tolerance; an empty tap can release a wholly off-screen lock; and repeated impossible-range warnings are bounded while preserving initial quiet detection. The short hint names the visible Attack/Defend menu labels. The input contract is corrected and backlog provenance is quoted. The original-position reset remains authoritative within 30 pt; extreme-top holds still lack upward cancel travel. Touch picking uses a projected body envelope rather than exact mesh pixels.

**Verified on the exact archive source:** independent UI/backend cross-review and final fixture/document-delta review found no blocker. Automatic Codex review completed without findings; Claude was asked to review the combined source, with no reply at the delivery checkpoint. Focused regressions pass, including sampled UIKit callbacks, visible-label selection, release-time dialogue hiding, hidden-panel guidance, full-width/native-cover picking and unreachable-warning behaviour. These callbacks are not physical finger delivery. Full archive-bound `./scripts/check` passes: **13 declaration-contract tests, 31 offline release-contract tests, 52 Blender tests, sixteen sound fingerprints**, strict formatting, app build and hosted Swift Testing with **all thirteen headless routes**. [Exact-source GitHub Check 109](https://github.com/RonildoBraga/lauder/actions/runs/45919771945) passed.

Fresh rendered iPhone 13 Pro Max / iOS 27.0 Simulator `touch-fight`, `retaliation` and `weapons` routes passed in **63.8 / 61.2 / 65.5 s**, through native victory and Restart with **zero retries and party-stop diagnostics**. The touch route records **zero non-touch input frames**. Each damage total equals **1,500**; normal/weak-point totals are **888/612, 807/693 and 906/594**, with at most **7/6/5** simultaneous labels. Inspected captures show the short visible-choice hint and hidden Pause status panel on build 37. Body overlap persists in **1.7% / 2.0% / 12.4%** of recorded frames; these results do not establish permanent separation or phone frame rates.

The signed Release archive's identity, team, strict signature, matching dSYM and fingerprint passed verification. The single API-authenticated upload succeeded. Apple readback at **2026-11-27 01:13:21 UTC** confirmed **COMPLETE**, **zero upload errors**, **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired build and availability to the existing intended internal groups. Group and tester membership are unchanged. The **en-AU testing notes were written and read back exactly**. Private archives, symbols and evidence are retained; no main merge or public App Store submission occurred.

Update Lauder in TestFlight for the phone comparison. Installation, physical multi-touch/VoiceOver/controller usability, audio/haptics, combat balance, sustained phone performance and acceptance remain unverified for this source. A moving guard temporarily occupying a previously valid Go point remains an un-reproduced review observation; the collision boundary remains authoritative, without a promise of permanently clear dynamic destinations.

### Merged into main

On 27 November 2026 the maintainer said **“merge the stack once Codex fixes the review findings”** (Claude chat; no public permalink). Claude's review of `cce555a` [found each finding fixed](https://github.com/RonildoBraga/lauder/pull/191#issuecomment-7207912303). The pull requests then merged into `main` in order: [#166](https://github.com/RonildoBraga/lauder/pull/166) as `4708ef3`, [#167](https://github.com/RonildoBraga/lauder/pull/167) as `212ecf1`, [#169](https://github.com/RonildoBraga/lauder/pull/169) as `64ab95b`, [#170](https://github.com/RonildoBraga/lauder/pull/170) as `2d9074d`, [#172](https://github.com/RonildoBraga/lauder/pull/172) as `4f740c4`, [#173](https://github.com/RonildoBraga/lauder/pull/173) as `036d728`, [#175](https://github.com/RonildoBraga/lauder/pull/175) as `12c9db6`, [#184](https://github.com/RonildoBraga/lauder/pull/184) as `b90ac12`, [#185](https://github.com/RonildoBraga/lauder/pull/185) as `8a7844e`, [#187](https://github.com/RonildoBraga/lauder/pull/187) as `550517a`, [#188](https://github.com/RonildoBraga/lauder/pull/188) as `d302ff3`, [#189](https://github.com/RonildoBraga/lauder/pull/189) as `b9db6dc` and [#191](https://github.com/RonildoBraga/lauder/pull/191) as `2532577`.

Each squash has exactly the files of its pull request's head. Where a Codex branch first needed `main` recorded, a bookkeeping merge changed no file. #189 needed a real merge, which reused the resolution Codex had made in `040d81f` for build 37. `main`'s app sources are those of `cce555a`, and only status documents differ. `./scripts/check` passed on #189's merged tree before it landed. #191's head `a44537e` passed [check run 110](https://github.com/RonildoBraga/lauder/actions/runs/45921635509) with the tree that `main` then had.

## Touch parity — in development

**Historical source record:** the behaviour and measurements below describe `e2e9575` and its original review handoff. The later [build 37 preview](#build-37-testflight-preview) includes this work and the final targeting, drawn-menu and guidance corrections; the earlier empty-tap and edge-gesture descriptions are not its current contract.

Under the maintainer's assignment to address Claude's GitHub findings, [issue #186](https://github.com/RonildoBraga/lauder/issues/186) adds the missing touch targeting and discoverability on top of the [review fixes](#claude-review-follow-ups--in-development). The maintainer chose **“Short order hint (recommended)”** (chat; no public permalink). A noninteractive hint appears during a fight while Defend is active: hold open ground and slide upper-left for Attack or upper-right for Defend.

A quick ground tap selects the nearest eligible on-screen enemy body within 30 screen points, using the normal lock, aim, range and damage paths; tapping that selected body again releases it. Empty taps leave it alone. Holds retain the spatial order menu and original ground mark. There is no second aim stick or tap-to-fire. Explicit VoiceOver target/next/release and existing Go/Hold actions supplement the unchanged gameplay button layout. Fire is absent during dialogue; Pause exposes the existing status-panel choice. These defaults are implementation choices within the assigned audit, not additional quoted maintainer decisions. The [touch contract](touch-controls.md) and [lock-on record](decisions/0020-lock-on.md) own the exact rules.

**Verified on source `e2e9575`:** full `./scripts/check` passes on a dedicated iPhone 13 Pro Max / iOS 27.0 Simulator: 13 declaration-contract tests, 31 offline release tests, 52 Blender tests, eight sound fingerprints, strict formatting, app build and hosted Swift Testing including all thirteen headless routes. Focused capture/native-target/panel and inset-window regressions pass. An initial test-only missing-spawn fixture was corrected; the final check has no new Swift deprecation warning. Peer review found no source blocker, and automatic Codex review completed without findings on `98192ff`; subsequent changes modernise the test window and hold Debug capture marks, without changing gameplay.

The fresh rendered `touch-fight` route passes in **63.8 s** with **zero non-touch input frames**, zero retries and zero party-stop diagnostics. Accepted Go/Hold, both weapon swaps, a full leader cycle, target acquisition/release, real Fire/roll movement, native victory, actual panel visibility and Restart pass through shared input/session rules. Applied damage totals exactly **1,500**: Miki **768**, Laura **315**, Tom **417**; normal **888**, weak-point **612**, **75** contacts, at most **seven** labels. Inspected stills show the short hint while Defend is active, the lock ring and the status panel hidden on Pause. Initial rapidly advancing capture marks skipped those UI states; the final Debug route deliberately holds them long enough to capture. This route injects touch fields rather than physical UIKit fingers. Unit tests cover capture classification, final endpoints, delayed menu tasks, generation cancellation and accessibility dispatch; they do not establish real multi-touch or VoiceOver usability.

Brief existing body overlap remains (**1.77%** of recorded frames). Simulator pacing is not phone performance. At this source, extreme-top holds still lacked upward travel for stance/cancel gestures; physical controls, audibility, balance, sustained phone performance and acceptance remained unverified. At the handoff, [PR #188](https://github.com/RonildoBraga/lauder/pull/188) was unmerged and unuploaded, with build 36 the delivered preview. The subsequent [build 37 delivery](#build-37-testflight-preview) supersedes that availability checkpoint without establishing physical acceptance or merging the PR. For backlog retirement, the maintainer instructed **“Please resolve and close all git issues and wherever what is stale or outdated we should close. Also me mindful Claude is also working to resolve and close all git issues so you guys need to divide and conquer.”** ([relayed decision](https://github.com/RonildoBraga/lauder/issues/165#issuecomment-7206268433)). That authorises issue retirement with factual limitations; closing implementation tracking does not merge or authorise a new upload.

## Claude review follow-ups — in development

**Historical source record:** the rules and verification below describe `ae3519d`. The later [build 37 preview](#build-37-testflight-preview) delivers this work with the final touch-menu and tracking corrections; the source-specific results below remain unchanged.

On 27 November 2026 the maintainer asked **“Also please address the Claude comments on git issues”** (chat; no public permalink). This authorises the bounded corrections in [#176](https://github.com/RonildoBraga/lauder/issues/176)–[#182](https://github.com/RonildoBraga/lauder/issues/182), building on the delivered [build 36](#build-36-testflight-preview) source and its documentation. The already-addressed #180 contact/material fixes remain in build 36. The newer [touch-parity audit #186](https://github.com/RonildoBraga/lauder/issues/186) is a separate implementation follow-up. Neither review recommendations nor this source task authorise merging the open stack or another TestFlight upload.

- **Regroup:** an accepted Go or Hold replaces temporary Formation/Follow regrouping without changing Attack/Defend. A refused order leaves regrouping intact.
- **Destinations:** forward marks stop before a living guard’s hull; direct and snapped destinations, single sends and Both fallback require the same party/hull clearance as movement. An impossible touch point shows the existing refusal cross.
- **Tracking:** retaliation chooses recent visible attackers within the existing 12 m attack range, retaining 14 m sight/quiet detection. A still-visible fixed target beyond attack range returns to searching after the existing tracking warning, so another eligible target gets a fresh full warning. Committed shots retain their fixed point.
- **Touch order menu:** movement is measured from the original finger position, independent of clamped artwork. Returning inside the 30 pt centre resets to Both; the wider upward sector cancels, upper diagonals select stances and horizontal travel selects companions. Start far enough below the top edge for upward gestures; extreme-top presses retain this physical limitation.
- **Shared context:** the story bible restores occasional light combat and useful ordinary fire, separating proposed biographies from assigned prototype mechanics. CONTRIBUTING records `.local/worktrees/<name>/`. Seven old worktrees were relocated there with all 17,103 original file entries preserved; only three private archive-location fields changed, with original manifests and relocation receipts retained. Builds 33/34/35 retain matching archive fingerprints, dSYMs and signatures. No data or branches were deleted.

**Verified on source `ae3519d`:** the full `./scripts/check` passes, including all twelve retained headless routes. Focused before-source checks reproduce the order/regroup, hull-admission, guard-tracking and cancel-sector failures; focused after-fix suites pass. Fresh rendered `orders`, `companions` and `retaliation` routes pass in 322.1 s, 66.4 s and 70.5 s respectively, with no retry or party-stop diagnostic, through combat and Restart. Read-only peer review found no blocking correctness gap. Recordings, traces and regression result bundles remain in ignored local evidence. The touch-parity work additionally validates the final release position, rather than relying on the last move callback. These checks do not establish phone gestures, multi-touch, audibility, performance or acceptance. At this handoff [PR #187](https://github.com/RonildoBraga/lauder/pull/187) was unmerged and not uploaded, and build 36 remained delivered. The separately authorised [build 37 preview](#build-37-testflight-preview) subsequently delivered the integrated corrections; it does not merge the PR or establish physical acceptance.

## Weapon sounds — in development

[Issue #162](https://github.com/RonildoBraga/lauder/issues/162) gives the paired weapons their own sounds. In a Claude session on 27 November 2026, which has no public permalink, the maintainer said: “see if you can help and start resolving all the git issues”. The work is on `claude/weapon-sounds`, based on the build 36 source (`codex/testflight-guard-damage`, [PR #185](https://github.com/RonildoBraga/lauder/pull/185)).

- **Sounds:** `apple/scripts/make-sounds.py` now generates sixteen sounds instead of eight.
  - **Weapons:** the five damaging paired weapons each have a voice: long rifle, assault rifle, shotgun, sword swing and minigun round. The dome is the sixth paired weapon, with separate state cues below; the hostiles' rifle retains its own.
  - **Minigun:** it whines as it spins up.
  - **Tom's dome:** it has five: rising, running down with 1.5 s left, let go or dropped, run out, and recharged in his hands.
  - **Removed:** the old carbine, light-burst and close-scatter sounds, made for the weapons that [ADR 0021](decisions/0021-paired-weapons.md) replaced.
- **Events:** the fight reports when a minigun begins to spin up, for the leader and for companions. It reports each change of the dome once.
- **Vibration:** the leader feels each weapon, the spin-up, and the dome rising and breaking. The DualSense trigger profiles are unchanged.
- **Verification:** `./scripts/check` passed on an iOS 27 iPhone 17 Simulator:
  - 13 declaration-contract tests, 31 offline release-contract tests and 52 Blender tests;
  - the 16 generated sounds;
  - strict Swift formatting, the app build and Swift Testing.
  - **New tests** cover each sound's mapping, the spin-up heard once for each hold, and each change of the dome heard once.
  - A script measured each sound's length, loudness over time and pitch direction. None has been heard on a phone.
- **Not verified:** nobody has heard the sounds or felt the vibrations on a phone. That waits for the next agreed phone check, listed under [deferred phone and playtest checks](#deferred-phone-and-playtest-checks).

## Guard damage and feedback — in development

On 27 November 2026 the maintainer requested damage from every successful hit, with increased damage for the appropriate companion/weapon at an enemy weakness, white normal numbers, red weak-point numbers and restrained effective-hit feedback. They approved the shared-health proposal with **“Proceed with your recommendations”** (chat; no public permalink). [Issue #183](https://github.com/RonildoBraga/lauder/issues/183) records that explicit assignment. It authorises this bounded damage/feedback revision, including directly related contact and presentation findings in [issue #180](https://github.com/RonildoBraga/lauder/issues/180), without authorising merge or another TestFlight delivery.

The [damage contract](damage-feedback.md) owns the exact rules. Starting tuning is **1,500 shared guard health**, normal damage **48 / 5 / 45 / 30 / 3** for long rifle / assault rifle / shotgun / sword / minigun, and **×3** for the matching weapon at an exposed part. Real body, closed-part and unmatched hits cause normal damage; misses and scenery/ally contacts do not cause enemy damage. Values are playtest starting points rather than settled balance. Player and companion hits use the same math, with no additional actor-identity gate.

The sensor → coupling → core route becomes optional. Matched sensor/coupling hits retain persistent structural progress and recovery still supplies four-second core windows, but neither the part chain nor twelve core contacts is required for a kill. Zero health is the sole damage-based victory condition. This supersedes the mandatory-rule assertions in earlier preview records below, without rewriting what those sources actually tested or delivered.

After explicit Attack and engagement, companions prefer useful exposed matching parts and otherwise use safe ordinary fire with their native guns. Defend remains cease-fire and recall; hard Go/Hold, manual leadership, cover/spacing, ordinary weapon timing, the quiet bypass and lifecycle remain authoritative. The guard's existing warnings, precision/fan patterns and party injury/retry rules retain their owners. No random critical-chance system, signature ability, new enemy, scene or art is assigned.

Resolved applied-damage events supply one health bar and bounded noninteractive white/red numbers with a weak-point symbol, dark contrast and brief animation. Minigun and assault-rifle contacts aggregate over an initial **0.30 s** by enemy/attacker/weapon/effectiveness, preserving every applied amount without mixing normal and effective totals. Initial label lifetime is **0.8 s**, with at most **eight** visible labels. The existing shot presenter adds four reusable effective-hit glints; marker materials are cached. Pause/interruption/Retry/Restart must not replay stale numbers or duplicate strike sounds.

### Damage and feedback verification

On 27 November 2026, application/test/tooling source **`533f012`** passed the full `./scripts/check`: 13 declaration-contract tests, 31 offline release-contract tests, 52 Blender extension tests, eight generated sound fingerprints, strict Swift formatting, the app build and hosted Swift Testing, including all **twelve headless gameplay routes**. [GitHub Check run 98](https://github.com/RonildoBraga/lauder/actions/runs/45906054883) also passed on that source. No Swift source warnings remained. Read-only code and documentation reviews found no remaining blocker. Later documentation-only changes retain the same app, asset, test and tooling fingerprints.

Native rule/contact regressions verify positive ordinary, closed-part and unmatched damage; exact exposed bonuses; optional sensor/coupling progress and recurring core windows; all five damaging weapons reaching zero health without a part prerequisite; correct finite/overkill/reset behaviour; one applied result per contact; point-blank weak-point interior rejection; and sword-body reach, facing and solid-cover feedback. Those ordinary-solo tests isolate incoming damage to test outgoing rules. The encounter drivers explicitly order **Attack** and allow real companion support, so their completion demonstrates squad play with the ordinary injury/retry rules rather than solo survival. They use ordinary shared inputs, without injecting health, phase, weapon state or immunity.

Planner/native regressions verify safe ordinary companion attacks when a specialist opening is unavailable, persistent draw/reload through cached body-fire goals, actual damage, weak-point preference, hard Go/Hold priority, Defend cease-fire/recall, player ownership and quiet bypass. World/feedback regressions verify one captured damage/audio event batch, actual applied sums, projection height, rapid aggregation boundaries and separated categories, bounded labels, stable Reduce Motion placement, Pause freeze, background cancellation and Retry/Restart. The damage event does not duplicate impact audio or haptics. Marker materials are reused rather than recreated each frame.

Clean rendered iPhone 17 / iOS 27.0 Simulator runs on the same source:

| Route | Duration | Peak hits: Miki / Laura / Tom | Retries | Applied normal / weak-point damage | Frame p99 / max | Party update mean / p99 | Body overlap frames |
|---|---:|---:|---:|---:|---:|---:|---:|
| `damage-feedback` | 63.8 s | 2 / 0 / 0 | 0 | 1194 / 306 | 16.76 / 33.35 ms | 1.247 / 2.875 ms | 2.2% |
| `companions` | 71.8 s | 0 / 0 / 1 | 0 | 483 / 1017 | 16.81 / 220.23 ms | 1.246 / 3.811 ms | 2.7% |
| `weapons` | 65.5 s | 1 / 0 / 0 | 0 | 906 / 594 | 16.76 / 232.39 ms | 1.145 / 2.590 ms | 12.5% |
| `first-fight` | 84.9 s | 2 / 0 / 1 | 0 | 780 / 720 | 16.77 / 164.77 ms | 1.252 / 5.719 ms | 0.2% |
| `retaliation` | 62.3 s | 0 / 1 / 0 | 0 | 663 / 837 | 16.79 / 198.87 ms | 1.380 / 4.634 ms | 2.3% |

All five passed through native victory and Restart, with zero stuck-companion diagnostic frames. Every route's normal plus weak-point totals and member contributions equal exactly **1,500 health lost**. Each observed at most **five** simultaneous labels, within the cap of eight. In `damage-feedback`, six real assault-rifle contacts first removed **30 health** while the squad remained in Defend; the complete encounter total was **1,194 normal + 306 weak-point damage**. Miki / Laura / Tom contributed **795 / 540 / 165**. The rendered white grouped total and red **144** sensor hit with its accent are readable against the snow, and the compact health row/bar does not wrap. Restart restores health to 1,500 and cancels prior feedback. The Debug summary alone retains cumulative evidence across Restart; live labels and encounter state reset.

In `companions`, Miki stayed player-controlled while native companion weapons supplied the other contributions: **144 / 501 / 855** by Miki / Laura / Tom. Defend retained health and stopped companion ammo spend/fire during the three-second recall observation; later Attack resumed contributions. The observation records actual inward companion movement and an improved live gap, so a late leader roll does not invalidate an earlier return. Regressions reject a stationary follower even when the leader moves towards them; this corrects a driver measurement, not production AI or collision.

**Limits and next gate:** These are scripted Simulator observations, not settled combat balance or phone acceptance. Physical controls, multi-touch, warning audibility, phone readability, sustained performance and enjoyment remain unverified for this revision. Reduce Motion allocation is regression-tested; the recording uses normal motion. Moving bodies still overlap, reaching **12.5%** of frames in the paired-weapon route, and isolated rendered frames reached **232.39 ms**. This does not establish permanent companion separation or sustained 60 fps on the phone. Other findings in #176–179, including the [guard-tracking case in #178](https://github.com/RonildoBraga/lauder/issues/178), remain separate. Review [PR #184](https://github.com/RonildoBraga/lauder/pull/184), then use an agreed phone comparison to judge whether ordinary hits feel useful and weakness rewards justify repositioning/switching. The implementation task added no further scene, enemy, signature or art and did not authorise merge or release. The later explicit delivery request and verified [build 36 preview](#build-36-testflight-preview) supersede that delivery checkpoint; physical acceptance and merge remain separate.

## Bridge cover and spacing — in development

On 27 November 2026 the maintainer said **“Looks good. Go ahead and improve the cover and companion spacing on the bridge.”** This explicitly assigns the bounded [cover/spacing comparison](bridge-cover-spacing.md), recorded in [issue #174](https://github.com/RonildoBraga/lauder/issues/174), without authorising a merge or another TestFlight delivery.

Two simple approach shelters, `bridge-cover-west` and `bridge-cover-east`, accompany **1.2 m desired clearance between autonomous destinations**. The existing centre passage, east coupling approach and quiet west arch must remain usable. Reservations respect explicit Hold/Go anchors, the leader and other intended places; actual collision, rays, threat, weapon execution and the existing leash/recall bounds retain authority. Normal formations outside the fight, guard damage, alternating patterns, timings and weakpoint rules remain unchanged.

### Cover and spacing verification

On 27 November 2026, source **`60428d3`** passed `./scripts/check`: 13 declaration-contract tests, 31 offline release-contract tests, 52 Blender extension tests, eight generated sounds, strict Swift formatting, the app build and hosted Swift Testing, including all **eleven headless gameplay routes**. No Swift source warnings remained. Read-only source and documentation reviews found no outstanding blocker after replacing repeated tactical path construction with connected-region admission; the existing motor retains sole ownership of cached routes. Subsequent documentation records these results without changing application source, assets, tests or tooling.

Geometry tests verify separate roomy rear places, both real gun origins blocked at samples throughout native patrol/turning/bracing/precision/fan/recovery poses, traversable centre/east/quiet-west lanes and clearance around the guard's whole movement envelope. Visual bounds match the authored boxes. Planner/native regressions cover shared reservations, immediate occupied-goal invalidation, crowded firing steps, stable uncovered fallback, nearby shelter behind a forward-facing formation, progressive distant recall, explicit Go/Hold, switching, lifecycle, native role weapons and reset. Older fight drivers now peek through a real clear lane and roll on an observed commitment; hit/discharge tests observe actual native events rather than a transient activity label. No phase, damage or weapon state is injected into the ordinary-input routes.

Clean rendered iPhone 17 / iOS 27.0 Simulator runs on the same source:

| Route | Duration | Peak hits: Miki / Laura / Tom | Retries | Frame p99 / max | Party update mean / p99 | Body overlap frames |
|---|---:|---:|---:|---:|---:|---:|
| `cover-spacing` | 63.1 s | 0 / 0 / 1 | 0 | 16.75 / 33.37 ms | 1.264 / 4.088 ms | 1.9% |
| `companions` | 63.9 s | 0 / 1 / 1 | 0 | 17.05 / 216.50 ms | 1.363 / 4.751 ms | 2.7% |
| `first-fight` | 81.1 s | 1 / 0 / 1 | 0 | 16.76 / 220.08 ms | 1.385 / 5.581 ms | 0.0% |
| `retaliation` | 55.0 s | 0 / 0 / 0 | 0 | 16.80 / 230.74 ms | 1.297 / 3.903 ms | 0.7% |

All four passed through ordinary shared input, including native dismantling and Restart, with zero stuck-companion diagnostic frames. In `cover-spacing`, both followers arrived at their actual destinations by 52.90 s: Tom `[4.953, 10.346]` and Laura `[8.322, 10.422]`, with Miki `[6.439, 9.834]`. Their **3.37 m** separation and respective **1.57 / 1.97 m** leader distances satisfied the selected spacing/nearby-recall bounds. The real two-muzzle cover query stayed true for both bodies during a continuous **1.00 s** settled interval, and another **0.52 s** after Pause/Resume. Companion ammo/progress stayed unchanged throughout Defend. A later Attack completed the real core contribution while Miki remained player-controlled. Tom's earlier hit remained recorded; the route does not depend on immunity.

Visual inspection of the recordings confirms two independently occupied shelters and an open central lane. The headless opening/order routes retain quiet bypass, formations, hard orders, switching and reset. The cover route's continuous settled intervals are bounded observations, not a claim of permanent safety or spacing. Body overlap still occurred briefly during movement, reaching 2.7% of frames in one run, and three recordings include isolated long frames above 200 ms. Simulator timings do not establish sustained phone performance. Physical controls, warning audibility, phone readability, balance and enjoyment remain unverified for this change. [PR #175](https://github.com/RonildoBraga/lauder/pull/175) is the cover review handoff. At that checkpoint build 35 remained delivered, with no merge or new upload in the cover assignment. The later [build 36 preview](#build-36-testflight-preview) includes these changes without establishing phone acceptance.

## Guard retaliation — in development

The maintainer reported **“The Attack and Defend controls are working”**, then authorised the bounded recommendation with **“proceed”**. [Issue #171](https://github.com/RonildoBraga/lauder/issues/171) records that chat direction. The report confirms basic commands only; it is not every-input acceptance, sustained performance evidence or merge/release permission.

On `codex/guard-retaliation`, the engaged guard chooses a visible recent native attacker between cycles, otherwise acquiring the leader under the existing rules. A named HUD warning and one two-note cue identify the threatened member. Target identity stays fixed through warning, commitment, burst and recovery; the committed point stays fixed after commitment. The [retaliation contract](guard-retaliation.md) owns selection, flank fairness and lifecycle details. Damage, patterns, existing timing and weakpoint requirements remain unchanged, as do explicit Attack/Defend, orders and the west bypass. That earlier comparison did not include cover edits; the 27 November cover/spacing assignment above is separate.

### Retaliation verification

On 26 November 2026, the frozen application source passed `./scripts/check`: 13 declaration-contract tests, 31 release-contract tests, 52 Blender extension tests, eight generated sounds, strict Swift formatting, app build and hosted Swift Testing, including all ten headless gameplay routes. No Swift source warnings remained. Rule/native/world regressions cover actual discharges and sword contact rather than intentions, attack-memory expiry and deterministic ties, real visibility, quiet acquisition, target identity across switches and Defend, fixed committed rays, one warning per notice entry, Pause, bypass, Retry and Restart. Pending-warning tests reject cues after interruption or an ended burst while retaining real shot/impact history; Defend retains an already warned attack. Read-only implementation and feedback reviews found no remaining correctness blocker.

Clean rendered iPhone 17 / iOS 27.0 Simulator runs on the same application source, through ordinary shared input:

| Route | Duration | Peak hits: Miki / Laura / Tom | Retries | Frame p99 / max | Party update mean / p99 | Body overlap frames |
|---|---:|---:|---:|---:|---:|---:|
| `retaliation` | 54.2 s | 0 / 0 / 2 | 0 | 16.80 / 33.35 ms | 1.584 / 5.044 ms | 0.6% |
| `companions` | 55.2 s | 1 / 0 / 0 | 0 | 16.84 / 200.29 ms | 1.500 / 5.183 ms | 1.2% |
| `first-fight` | 80.4 s | 2 / 0 / 1 | 0 | 17.10 / 164.79 ms | 1.953 / 7.033 ms | 0.4% |

All three passed with Restart and zero stuck-companion diagnostic frames. The Debug runner now retains each member's peak injury count and counts retry transitions, including across cleared injury snapshots at victory/Restart. These are observed injuries under the ordinary three-hit retry rule, not injected damage or immunity. Simulator timings, including the recorded long frames, do not establish phone performance.

The new route keeps Tom under player control without Fire, allowing real Miki/Laura contributions to provoke retaliation. At 47.12 s the guard warned Laura; normal leader cycling, Defend and a real roll followed. Commitment at 49.04 s and recovery at 50.29 s both retained Laura and exactly `[4.7238855, 8.224512]` as the committed point. The five-round fan completed, then Attack resumed and native core fire dismantled the guard at 51.74 s. Tom's two hits show that Defend and switching do not cancel enemy fire or protect the rest of the party from crossfire. The independent `companions` route also retained the sensor/coupling/core sequence, cease-fire/recall and a later Laura-targeted cycle without taking control from Miki.

Visual inspection caught and corrected wrapping of a threatened companion's name: the three short name/pip groups now occupy their own row, with formation text below. The corrected full-panel warning is readable in the recording. Waveform/resource/event tests establish the generated two-note cue and its cancellation boundaries, not actual audibility; Simulator video has no audio. Phone readability, physical controls, sustained performance, balance and enjoyment remain unverified for this branch. A short scripted fight supplies only a small number of retaliation cycles; evaluate the comparison before changing cover, damage or timings. At that source-verification checkpoint, build 34 was the latest delivered preview and no new upload had occurred. The later authorised build 35 delivery below supersedes that delivery status; no merge occurred.

## Companion autonomy — in development

The maintainer reported build 33 **“It worked nice”**, then asked for independent companions and chose **“Companions can complete the weakpoint steps too”**. This authorises the [bounded companion contract](companion-autonomy.md), not a generic AI framework or new scene. All three characters still contribute through their actual native weapons; changing leader is available but no longer mandatory for every step.

The maintainer then clarified that companions should attack only after **Attack**, while **Defend** on the D-pad should make them seek cover and return. The squad now defaults to Defend. D-pad/arrow Up orders Attack; Down orders Defend, immediately revoking companion fire permission and clearing old position orders to recall them via nearby legal cover. Fire alone controls only the leader. The stance persists across leader switches; Retry/Restart returns to Defend. This correction has passed the checks below.

With Attack permission and an engaged guard, companions choose nearby legal positions/cover and avoid committed fire where possible, with an initial 8 m leader leash. Hold anchors and Go destinations otherwise override autonomous movement, and subsequently issued position orders do not arm attacks. Formation/Follow retains its existing meaning and temporary regroup without changing stance; retreat suppresses attacks. Actual rays, armour, weapon readiness/ammunition/cadence and turn rates remain authoritative; companions gain no teleportation, immunity, automatic shields or signatures.

### Explicit stance verification

On 26 November 2026, `./scripts/check` passed after the correction: 13 declaration-contract tests, 31 release-contract tests, 52 Blender extension tests, seven generated sounds, strict Swift formatting, the app build and hosted Swift Testing, including all nine headless gameplay routes. No Swift source warnings remained. Added coverage verifies default Defend despite real player engagement, no companion damage/ammo spend after Defend even with stale fire intentions, recall replacing Hold without cycling formation, player Fire remaining available, Attack restored only by command, local returning cover, command priority, touch cancellation, Pause/dialogue and stance reset on Retry/Restart. Read-only implementation and input reviews found no remaining correctness blocker.

Clean rendered iPhone 17 / iOS 27.0 Simulator runs, through shared input:

| Route | Duration | Warning frames | Frame p99 / max | Party update mean / p99 | Body overlap frames |
|---|---:|---:|---:|---:|---:|
| `companions` | 54.9 s | 0 | 16.74 / 50.75 ms | 1.440 / 4.921 ms | 0.0% |
| `first-fight` | 80.9 s | 0 | 16.72 / 33.34 ms | 1.941 / 7.054 ms | 0.7% |
| `weapons` | 62.2 s | 0 | 16.73 / 37.78 ms | 1.698 / 5.094 ms | 1.2% |

All three passed, including Restart. The new route explicitly ordered Attack, allowed the real sensor/coupling steps, issued Hold then Defend, observed three seconds with no companion damage or ammo spend while recalling, then issued Attack again and completed the core. Miki remained player-controlled. The observed state stayed Defend throughout the cease-fire and core damage stayed zero; the final accepted core count reached 12 only after the new Attack. The widest leader gaps were 3.44, 3.82 and 3.58 m respectively. The HUD showed the stance and Up/Down commands. A subsequent native Simulator UI check invoked the touch Formation control's exposed Squad Attack and Squad Defend actions and observed each HUD transition, ending in Defend.

These are Simulator results; brief overlaps and the recorded frame maxima remain limitations, and the controller-hint strip remains dense. The touch-menu selection/clamping and cancellation tests passed, but the UI check used its accessibility actions rather than a physical ground-menu gesture. No new physical controller, multi-touch, sustained phone performance or enjoyment is established. The [build 34 delivery](#build-34-testflight-preview) is verified below; physical acceptance and merge remain separate gates.

### Earlier autonomous-engagement verification

The first autonomy source, `14193d5`, passed these checks on 26 November 2026 before the explicit stance correction:

- `./scripts/check` passed on the final source: 13 declaration-contract tests, 31 offline release-contract tests, 52 Blender extension tests, seven generated sounds, strict Swift formatting, the shared app build and hosted Swift Testing suite. This includes 20 new companion tests and all nine headless gameplay routes, with no Swift source warnings in the final run.
- Pure planner and native/world tests cover role weapons, closed components, real contact/cover/ally rays, draw/cadence/magazines, facing, awareness and player-contact activation, quiet bypass, local routes/leash, cached-target invalidation, threat avoidance, order priority, leader authority and Pause. The nine headless gameplay routes passed in the integrated run.
- Read-only peer reviews found a formation-target feedback issue; separate fresh formation targets now prevent tactical targets feeding into the next base formation. Real sword contact activates support, and actual per-frame companion movement/turning drives spread. Re-review found no remaining correctness blocker.
- A second world regression kept Tom under ordinary player control without firing: Miki disabled the sensor and Laura breached the coupling, while Tom retained a full magazine and the core stayed undamaged. Thus each companion's native contribution is covered without making the selected leader automatic.

Rendered iPhone 17 / iOS 27.0 Simulator results, through ordinary shared input:

| Route | Duration | Warning frames | Frame p99 | Party update mean / p99 | Body overlap frames |
|---|---:|---:|---:|---:|---:|
| `companions` | 49.0 s | 0 | 17.29 ms | 1.171 / 3.085 ms | 0.0% |
| `first-fight` | 80.9 s | 0 | 16.73 ms | 1.417 / 3.493 ms | 0.7% |
| `weapons` | 58.4 s | 0 | 16.82 ms | 1.216 / 3.699 ms | 1.3% |

All three rendered routes passed, including Restart. In `companions`, Miki stayed under player control and supplied only the sensor shot; Laura breached the coupling and Tom supplied 12 accepted core rounds. The captured stage changed from sensor through coupling and reactor to complete, without another player Fire or leader switch. The widest leader gaps were 3.46, 4.10 and 3.23 m respectively. Short body overlaps on the other routes remain visible in the measurements. The runs use the ordinary roll defence, with no added immunity or teleportation. Frame maxima were 33.34, 180.37 and 33.33 ms, so the first-fight run includes an isolated hitch despite its low p99.

The new activity line is readable in the Simulator captures; the bottom controller-hint strip remains dense. These are Mac Simulator results, not sustained phone frame-pacing, controller/touch acceptance or a judgment of enjoyment. The AI remains limited to this guard, and the player must still supply the currently controlled character's role. At that earlier checkpoint, review and the next authorised phone/release were outstanding and build 33 was the delivered version; the later build 34 record below supersedes that delivery status.

## Strategic guard — in development

This section records the manual-control implementation delivered in build 33 below; its heading remains a stable link for earlier PRs. Companion autonomy is the newer assignment above.

The maintainer authorised an encounter that rewards manually directing all three existing characters. [Strategic guard](strategic-guard.md) records the branch's prototype rules: Miki's long rifle persistently disables the sensor, Laura's sword persistently breaches a side coupling, and Tom's minigun supplies 12 accepted reactor rounds across repeatable 4-second exposure windows opened by recovery. Ordinary armour damage and wrong-role weapons cannot skip those contributions. The guard alternates three precision rounds and a five-round fan cannon attack, with readable wind-ups and no exact red aim line. The west bypass stays open.

In delivered build 33, L1 / LB, Q and touch Next switch leader manually; followers follow or hold without automatic attacks. Tom's dome drops on a leader switch. That preview also contains the fixes for sword strikes through solid cover and ground markers hidden by baked tower shadows. Existing pawns, camera, scene, input authority and real shot geometry remain the basis of the experiment.

Verification on 26 November 2026:

- `./scripts/check` passed: declaration contracts and 13 contract tests, 28 offline release-contract tests, 52 Blender extension tests, seven generated sounds, strict Swift formatting, the app build and hosted Swift Testing suite. All eight headless gameplay routes passed through ordinary input.
- Contact tests cover assisted/manual/locked shots, every missing-role solo/pair, wrong weapons, real armour/cover, outside-hull side contact, elevated targets, persistent progress, missed windows, Pause, retry and reset. Continuous hull tests cover walking, rolling, sliding and safe overlap escape.
- Read-only peer review identified the hull-entry and low-cover elevation defects; both were addressed and re-reviewed with no remaining blocker.

Rendered iPhone 17 / iOS 27.0 Simulator results:

| Route | Duration | Companion warning frames | Frame p99 | Party update mean / p99 |
|---|---:|---:|---:|---:|
| `first-fight` | 81.0 s | 0 | 16.75 ms | 0.993 / 2.017 ms |
| `weapons` | 65.0 s | 0 | 16.89 ms | 1.006 / 2.249 ms |
| `lock-on` | 54.7 s | 0 | 16.76 ms | 1.010 / 2.006 ms |

All three routes passed, including the complete dismantling sequence and Restart. Captures show the front sensor, side coupling, closed/open core and countdown, both attack warnings, and ground markers above the tower shadows. These are Simulator measurements on the Mac, not phone performance results. Component spheres remain prototype targeting cues and the controller-hint strip remains dense.

### Build 33 TestFlight preview

Internal TestFlight **0.1.0 (33)** was delivered from `f67bd2c` through [PR #167](https://github.com/RonildoBraga/lauder/pull/167), using the explicit reviewed-preview path before merge. Its manual strategic guard builds on [PR #166](https://github.com/RonildoBraga/lauder/pull/166); followers in that build do not attack. The delivery record on PR #167 is the source for processing and existing-tester availability.

The maintainer reported **“It worked nice”** in chat. Record this as general phone success only: no individual controller/touch checklist, readability measurement or sustained frame-pacing capture was supplied. It is not merge permission. The reviewed preview does not establish that either PR has merged into `main`. Remaining phone-specific checks and any merge/release require their applicable gates; the newer autonomy branch has its own verification above.

### Build 34 TestFlight preview

On 26 November 2026 the maintainer explicitly requested delivery of the Attack/Defend controls through TestFlight. Internal **0.1.0 (34)** was archived and uploaded from clean reviewed-preview source **`7d0d5cadae82d5da2e03020629be27732169240a`** on `codex/testflight-squad-commands`, through [PR #170](https://github.com/RonildoBraga/lauder/pull/170). App code is exactly [PR #169](https://github.com/RonildoBraga/lauder/pull/169)'s `1cdbcb0`; the only archive-source difference is the committed Debug/Release build number 33 → 34. This delivery did not merge the open preview PRs.

- Discovered Lauder's own App Store Connect record by `com.ronildo.lauder` and checked accepted/processing uploads plus existing builds before selecting unused build 34; refreshed reservations before archive and upload.
- Independent review verified the exact metadata-only source change. Automated review completed on the exact archive source with no findings, and [GitHub Check passed](https://github.com/RonildoBraga/lauder/actions/runs/45745307506) for that same commit.
- The release workflow reran `./scripts/check` on that frozen tree: formatting, app build, hosted Swift Testing and all nine headless routes, 13 declaration-contract tests, 31 release-contract tests, 52 Blender extension tests and seven generated sounds. A successful receipt and log digest bind those checks to the archived commit. The preceding rendered Attack/Defend results remain recorded above; no app code changed afterward.
- Verified Release archive identity/version/build, selected signing team, code signature and matching dSYM. Archive and upload used the existing API key with provisioning updates, not a saved-account login. Signing material, credentials and full receipts remain private.
- Apple confirmed upload **COMPLETE**, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, unexpired. Every intended existing internal group contains the build; group set and tester membership are unchanged. The en-AU test notes were written and read back exactly.

The preview starts in Defend. D-pad Up permits companion attacks and weakpoint completion; Down stops their fire and recalls them via available cover. TestFlight availability is verified. The maintainer later reported **“The Attack and Defend controls are working”**: basic command feedback only, without an individual D-pad/touch checklist, sustained performance capture or balance judgement. No uninstall, additional testers, pricing change or public App Store submission occurred. At that build-34 checkpoint, retaliation had not been delivered; the subsequent build 35 record below covers its delivery. Build 33 remains the historical manual-control preview.

### Build 35 TestFlight preview

After viewing the reviewed Simulator result, the maintainer replied **“proceed”** to the recommendation to publish the retaliation version for a short TestFlight comparison. Internal **0.1.0 (35)** was archived and uploaded from clean reviewed-preview source **`8a9908a910ec065a534d45546bf6804e18971513`** on `codex/testflight-guard-retaliation`, through [PR #173](https://github.com/RonildoBraga/lauder/pull/173). App code is exactly [PR #172](https://github.com/RonildoBraga/lauder/pull/172)'s reviewed `251ee09`; the only archive-source difference is the committed Debug/Release build number 34 → 35. This delivery did not merge the open preview PRs or change cover, damage or timing.

- Discovered Lauder's own App Store Connect record by `com.ronildo.lauder` and checked accepted/processing uploads plus existing builds before selecting unused build 35; refreshed reservations before archive and upload.
- Independent review verified the exact metadata-only source change. Automated Codex review completed on the exact archive source with no findings, and [GitHub Check passed](https://github.com/RonildoBraga/lauder/actions/runs/45796142046) for that same commit.
- The release workflow reran `./scripts/check` on that frozen tree: formatting, app build, hosted Swift Testing and all ten headless routes, 13 declaration-contract tests, 31 release-contract tests, 52 Blender extension tests and eight generated sounds. A successful receipt and log digest bind those checks to the archived commit. The earlier rendered retaliation comparison remains recorded above; no gameplay code changed afterward.
- Verified Release archive identity/version/build, selected signing team, code signature and matching dSYM. The new warning sound is present in the archive. Archive and upload used the existing API key with provisioning updates, not a saved-account login. Signing material, credentials and full receipts remain private.
- Apple confirmed upload **COMPLETE** with no upload errors, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, unexpired. Every intended existing internal group contains the build; the internal group set and tester membership are unchanged. The en-AU test notes were written and read back exactly.

Build 35 is available to install from TestFlight. The notes ask whether the threatened character is obvious, Defend returns companions towards useful cover, and switching leaders/resuming Attack feels satisfying. Physical installation, warning audibility, phone readability/controls, sustained performance and enjoyment remain unverified. No uninstall, additional testers, pricing change or public App Store submission occurred. Cover/spacing changes follow this comparison and their own assignment.

### Build 36 TestFlight preview

On 27 November 2026 the maintainer asked **“Can you deploy to my phone using TestFlight so I can test it”** (chat; no public permalink). This separately authorised an internal preview of the reviewed guard-damage revision, not a merge or public App Store submission. Internal **0.1.0 (36)** was archived and uploaded from clean reviewed-preview source **`2db6130494002369222b4980b6aa46efa8b36d99`** on `codex/testflight-guard-damage`, through [PR #185](https://github.com/RonildoBraga/lauder/pull/185).

App code, assets, tests and tooling match [PR #184](https://github.com/RonildoBraga/lauder/pull/184)'s reviewed `e4d5f86`; the only source change is the committed Debug/Release build number **35 → 36**. This delivers the shared health and optional weakness rules, ordinary companion attacks and white/red feedback verified above, along with the preceding bridge cover/spacing and guard retaliation. Later delivery-documentation edits do not change the frozen archive source. The open preview PRs remain unmerged.

- Discovered Lauder's own App Store Connect record by `com.ronildo.lauder`, checked accepted/processing uploads and existing builds before selecting unused build 36, and refreshed reservations before archive and upload. Existing internal-group and tester membership supplied the unchanged delivery baseline.
- Independent review verified the exact two-field build-number change. Automated Codex review completed on the exact archive source with no findings; [GitHub Check run 100](https://github.com/RonildoBraga/lauder/actions/runs/45908158640) passed on that same commit.
- The release workflow reran `./scripts/check` on the frozen source: 13 declaration-contract tests, 31 offline release-contract tests, 52 Blender extension tests, eight generated sound fingerprints, strict Swift formatting, the app build and hosted Swift Testing, including all **twelve headless gameplay routes**. A successful receipt and log digest bind those checks to the archive. The five preceding rendered damage/companion/weapon/retaliation runs remain recorded above; the version-number change did not alter their gameplay source.
- Verified the Release archive's Lauder identity, version/build, selected signing team, code signature and matching dSYM. Archive and upload used the existing App Store Connect API key with provisioning updates, without relying on Xcode's saved-account session. Credentials, signing material, archive, symbols and full receipts remain private.
- At **2026-11-26 23:15:59 UTC**, Apple verification confirmed upload **COMPLETE** with **zero errors**, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY** and an unexpired build. Every intended existing internal group contains the build; the internal group set and tester membership are unchanged.
- The **en-AU** test notes were written and read back exactly at **2026-11-26 23:14:27 UTC**. They ask testers to compare ordinary hits and matching weak-point attacks, Attack/Defend, leader/weapon switching, cover recall, number/warning readability, Pause/Resume and Restart.

Build 36 is available by choosing **Update** for Lauder in TestFlight; the pause menu identifies **0.1.0 (36)**. Availability is verified, while physical installation, controller/touch behaviour, audibility, phone readability, combat balance, sustained performance and enjoyment remain unverified. The recorded companion overlaps and isolated Simulator frame spikes remain playtest questions, not resolved phone-performance claims. No uninstall, additional tester invitation, pricing/availability change or public App Store submission occurred. Merge and any further delivery keep their own gates.

## Structural preparation

The approved structural preparation is merged: [PR #125](https://github.com/RonildoBraga/lauder/pull/125) separates camera motion and bridge progression, clarifies encounter naming, splits combat values into cohesive files and adds narrow declaration checks with CI. [PR #126](https://github.com/RonildoBraga/lauder/pull/126) adds reproducible TestFlight tooling. [ADR 0018](decisions/0018-runtime-boundaries.md) records the boundaries. Those structural changes did not change gameplay or story.

## Purpose and scope

Use the retained bridge to decide what is enjoyable before expanding again. This cleanup preserves its existing opening, party movement, native weapons and input paths. It does not redesign the story or author a replacement core loop.

The story's foundations remain in the [story bible](story/story-bible.md). Exploration and salvage lead the intended game, with occasional combat; the current opening samples movement, one guard that can be fought or bypassed, and a crossing by all three from the start. The supply-case interaction and recruitment scenes are removed. Later narrative proposals are reference material, not playable content or assignments.

## The opening

The [walkthrough](gameplay-script.md#the-brooklyn-bridge-opening) follows Miki, Tom and Laura from the Brooklyn end to Manhattan:

1. Move, look, toggle Miki ↔ Tom and try the formations on the snowbound bridge, with Laura as AI support and all three together from the start. This is the two-leader pilot under verification.
2. Meet the C robot at the first tower. Fight using the tower as cover, or take the west arch to its safe exit. Each committed burst can cause at most one injury; a third injury retries that fight.
3. Cross the second tower together. Try Close/Spread/Column and move/hold orders, then gather at the Manhattan end.

Only the bridge is available. Pause has Resume, Restart, Vibration and Status panel with controller, keyboard or touch. Tom's manual grenade remains available through the shared inputs below. There is no alternate-scene selector, weapon bench, endless spawn, automatic combat-cover controls, signature, elevation or salvage-repair system.

## Input and interaction contract

| Intent | PS5 / Xbox | Touch | Keyboard |
|---|---|---|---|
| Move active character | Left stick | Bottom-left analog stick | WASD |
| Look around, advance dialogue or confirm menu | Cross / A | Look, Continue, or Restart while paused | E |
| Toggle Miki ↔ Tom; Laura remains AI support | L1 / LB | Next: name | Q |
| Change formation; call ordered companions back first | Triangle / Y | Formation / Follow | R |
| Permit companion attacks / cease fire and recall via cover | D-pad up / down | Hold on ground, then the drawn Attack / Defend choice | Up / down arrows |
| Send left / right member ahead | D-pad left / right | Hold on ground, then a name | Left / right arrows |
| Both go / both hold | No direct binding | Hold on ground, then Both / Hold | G / H |
| Tom throws one grenade while leading | Circle / B | Grenade (Tom only) | C |
| Use the active fighter's gun or Tom's dome; automatic reload | R2 / RT | Fire, with assisted aim | F |
| [Switch](decisions/0021-paired-weapons.md) to the other weapon | R1 / RB | Swap: weapon | T |
| Aim apart from movement | Right stick | Assisted aim | I, K, J, L |
| [Lock the aim](decisions/0020-lock-on.md) on a hostile, or move it to the next; two quick controller/keyboard presses let go | R3 / RS, a press of the right stick | Tap an enemy to select; tap it again to release; Fire accessibility actions target / next / let go | O |
| Dodge roll: the leader tumbles 3 m the way they move, or face, while hostile shots pass through | Square / X | Roll | Space |
| Pause / Resume | Options / Menu | Pause / Resume | Escape |
| Choose Resume, Restart, Vibration or Status panel while paused | Stick or D-pad up/down, then Cross / A | Resume, Restart, Vibration or Status panel | W/S or up/down, then E |
| Hide/show status panel | Pause, then Status panel | Pause, then Status panel: On/Off | Pause, then Status panel |

Touch is automatic without an extended controller. An attached controller is preferred unless **Use touch controls** is chosen; **Use controller** returns to it. Keyboard remains available. These sources share InputRules and session authority. Xbox uses the shared extended-gamepad path; hardware delivery remains unverified.

Touch taps select the visible whole-body envelope, using full height and navigation radius with a 30-point exterior allowance. An empty valid tap retains an on-screen or partly visible lock and releases an entirely off-screen one; assisted aim remains available without a lock. The [touch contract](touch-controls.md) describes the short-tap/hold distinction, shared drawn order-menu choices and edge limitations. Release guidance stays visible when the status panel is hidden.

Switching preserves positions and progress; held movement can continue on the new leader. Circle / B throws a grenade only while Tom leads. A weapon switch needs a fresh press, and each weapon keeps its magazine. Switch, formation and order commands consume a simultaneous action, roll or grenade request. Grenades need a fresh press and cannot queue during recharge. A roll needs a fresh press, fires nothing and waits 0.5 s after the last. A lock press needs a fresh press too; one within 0.3 s of the last lets go, and a lock also lets go once its hostile is down or more than 30 m away. Dialogue and Pause consume gameplay edges rather than queueing them. Pause, interruptions, reconnection and source changes require neutral input; every button, key and finger must release, including a finger resting at stick centre.

Formations and orders still need two companions, so a level that starts with fewer than three offers them once the others join; the bridge starts with all three. There is nothing on the bridge to search or help with, so Look only looks around.

## Verification and performance

### Bridge environment pass

On 23 November 2026 the maintainer assigned the bridge scene in Blender before implementing the robot. The [level source](../blender/levels/README.md) and its USDZ now contain faceted pointed arches, weathered stone bases, four local cable fans and two low off-route snow meshes. The complete scene has 2,724 triangles, six materials and 33 used object/material partitions. These counts fit the authoring budget; they do not establish GPU draw calls or phone performance.

For that environment pass, the Gameplay, Camera and Lights collections were compared against a pre-edit snapshot, with object transforms, dimensions, properties and gameplay mesh vertices unchanged. Its generated Swift layout was byte-for-byte unchanged. The subsequent camera B adoption below changes only the camera data in that layout. The robot, supply handoff, narrative, weapons and controls were outside the environment pass.

`./scripts/check` passed the source/release contracts, all 51 Blender tests, sound fingerprints, Swift formatting, the app build and hosted Swift Testing, including all eight headless routes. Scene regressions retain the exact mesh inventory, require each tower's cable fans to fade with it while the other tower stays opaque, and check that the snow drifts remain low, off-route and noncolliding. Source/export fingerprints and all 61 local links in the six changed Markdown documents were checked.

Rendered Simulator runs passed `first-fight` **23/23** and `opening` **56/56**, with no failures or companion warning frames. Screenshots were inspected at the first fight, recruitment and both sides of the second tower; the party remains visible. The opening recorded 16.7 ms mean frame time and 16.8 ms p99 on Simulator. Private captures and logs are retained locally. This is Simulator evidence for the environment pass with its original camera, not a phone performance check or a new TestFlight delivery.

### Camera B selection and robot modelling

On 23 November 2026 the maintainer selected **B**, the higher, wider framing, after reviewing matched Simulator captures and crossing clips. The bridge's Blender camera and generated layout use offset `[0, 56, 44]` and vertical field of view **22°**. The existing 70% combat/aim lens rule therefore reaches **15.4°**. Geometry, lighting, controls and encounter rules are preserved. The world-marker scale expectation changes from 2.13 to 2.56; the projected-size and actual entity-scale checks remain intact.

The comparison used scene source `5cfb064` with temporary neutral capture holds and an additional waypoint in the existing opening route. Both camera options completed **67/67** steps with no failures or companion warning frames. Matched leader positions differed by less than 3 cm. The candidate's standard check passed with its camera-specific marker-scale expectation updated. These comparison copies are not exact-head captures of the canonical adoption. Validation of the canonical source is recorded with the adoption PR; phone performance remains unverified.

The maintainer then assigned the first robot's Blender blockout and movement poses, using the earlier [dark armed concept](../art/robot/README.md). That assignment produced the study below; it did not approve the proposed combat rules, supply-case handoff or replacement encounter.

The retained first [robot source](../blender/assets/spider-bot/README.md) has 298 triangles, 17 rigid mesh parts, five matte materials and no textures. A diagonal-pair walk study, a stepped brace, separate gun recoil and recovery are authored as object-transform keyframes; frame 1 is the neutral source pose. These measurements describe the rejected study, not a budget or proportion target for a new design. The model is not in `SPAWNED` or the bridge's exported scene. Existing exports sample one frame, so these are Blender motion studies rather than runtime animation clips. Its reference-derived source and preview retain CC BY 4.0 attribution.

On the canonical camera-B source, `./scripts/check` passed source/release contracts, 51 Blender tests, sound fingerprints, formatting, the app build and hosted Swift Testing, including all eight headless routes. The rendered `opening` passed **56/56**, with zero failures and companion warning frames. The robot passed standalone intake with zero problems. Neutral, front, side, brace/recovery and camera-B scale renders were inspected, alongside a rendered walk study. Post-save Blender/privacy checks also passed. These are technical checks, not visual approval. The maintainer subsequently rejected the blockout's proportions. Camera B remains adopted; the rejected model and motion are retained as reference, with runtime integration and phone performance unverified.

### Concept C proportion study

The maintainer selected **C, Heavy walker**, for a Blender proportion study, then accepted its form after reviewing the renders. The source is `blender/assets/spider-bot-heavy/spider-bot-heavy.blend`, with its own [model README](../blender/assets/spider-bot-heavy/README.md). The initial static study had 2,428 triangles, 41 mesh parts, five matte materials and no textures or animation. Its exact vertex bounds measured 2.83 × 2.51 × 2.35 m, a provisional review scale rather than approved collision dimensions. Three-quarter, front, side, Miki-scale and camera-B Blender renders were inspected. Standalone intake reported zero problems; mesh inspection confirmed closed solids and flat feet on z = 0. The technical checks in the earlier section describe camera B and the rejected first model, not C. The standard `./scripts/check` also passed during the static C modelling pass, including the app build and Simulator tests; no application or runtime level data changed. Saved-file intake and geometry checks for that static pass are retained in its original PR and Git history. These are historical checks before the current motion and component-reuse work. The asset is not loaded by the game, and no new rendered Simulator route or phone run was performed for that static pass.

### Concept C Blender motion and shared parts

The maintainer accepted C's form and assigned Blender animations of walking, turning and shooting before placing the robot on the bridge. This authorises source motion studies and reusable linked components. The new source has 41 mesh Objects sharing 17 unique Mesh datablocks, with 2,428 evaluated triangles and five matte materials. Each leg uses the same six shared component meshes under independent joint pivots; paired gun, roof and antenna parts also share data. Neutral dimensions are about 3.00 × 2.53 × 2.35 m after opening the knees for articulation, still provisional. Walking, mirrored 90° step-turns and a planted brace/recoil/recovery are baked at 120 Hz in a 30-fps source timeline. The maintainer subsequently accepted the [30-second rendered reel](../blender/assets/spider-bot-heavy/motion-preview.mp4) and assigned runtime integration.

On the animated source, `./scripts/check` passed the contracts, 51 Blender tests, sounds, formatting, app build and hosted Simulator tests. Final independent saved-file inspection sampled 7,204 poses at 240 Hz: stance drift below 0.029 mm, foot tilt below 0.0053°, sole penetration below 0.012 mm and zero joint gaps. Neutral and mirrored-turn geometry/material symmetry, linked-data reuse, topology, contacts, muzzles, palette, intake and privacy checks pass. All 720 rendered movie frames decode. The model README records the timeline and tolerances. No runtime source, bridge export or rejected model changed; no new phone check, rendered Simulator route, release or bridge placement occurred. These source checks do not establish runtime clip compatibility, phone performance or motion approval.

The rest model's left and right assemblies must mirror exactly. Repeated legs and connectors must reuse identical linked mesh parts rather than separately maintained near-copies. Placement and pose may differ as the legs walk or turn; the geometry and matching joints must remain consistent. The maintainer reviewed these motion studies and assigned bridge integration; keep that shared component structure in the runtime asset.

**A, Armoured crawler**, is retained for a possible later variant with different gun types; no A modelling or new weapon work is assigned. **B, Low siege bot**, is unselected. Camera B remains unchanged. That authoring assignment did not implement runtime AI or firing. The subsequent bounded integration is recorded below; A and releases remain outside this task.

### C robot on the bridge

The maintainer assigned the first-shooter replacement after approving C's motion. Integration is implemented: a source-driven runtime robot, bounded east-side movement, honest twin-barrel rays, a finite warning/commit/burst/recovery cycle, and a west-side supply case with a verified bypass route. Internal first-fight beat and marker IDs retain `stranger` for continuity; player-facing content describes the guard and case. Tom's arrival marker moves closer to the case so the existing ambush can remain visible. Geometry blockers, camera B and lighting remain unchanged.

The model's named joint hierarchy and generated measurements are exported from Blender. Gameplay remains fixed-step Swift; presentation follows actual movement, turns, brace and gun state. The standard `./scripts/check` passed on a frozen runtime tree: 13 declaration-contract tests, 28 offline release tests, 52 Blender tests, seven sound fingerprints, Swift formatting, the app build and hosted Swift Testing. Source fingerprints remained unchanged through the rendered runs. Independent code review found no actionable issues.

Rendered Simulator checks passed with zero failures or companion warning frames:

| Route | Steps | Evidence |
|---|---:|---|
| `first-fight` | 35/35 | Patrol, tracking, commitment, burst, recovery, defeat and Restart; marks record six emitted shots across two bursts before defeat |
| `fight-retry` | 15/15 | Three mistakes, checkpoint restore and a successful second attempt |
| `opening` | 56/56 | Supply case, ambush, Tom and Laura recruitment, both towers, arrival and Restart |

Mean frame time was 16.7 ms in each Simulator run, with p99 between 16.8 and 17.1 ms. These are Simulator measurements, not baseline-phone evidence. The loaded USDZ tests verify grounded feet/joints, 3D barrel/ray agreement including yaw/pitch/recoil, and Pause/reset. Actual-guard motion regressions also verify planted feet stay reachable during combined translation and turning; the small fix uses a 1° stop-turn-advance gate and an earlier step trigger, rather than masking an unreachable foot through clamping. Private captures, summaries, hashes and logs are retained.

The initial integration task recorded no new phone or release evidence. Its frozen application and asset source was tested; the subsequent TestFlight delivery is recorded below.

The follow-up review for [PR #134](https://github.com/RonildoBraga/lauder/pull/134) checked combat, progression and the rig/export pipeline independently. It corrected stale human-shooter/body-search descriptions and clarified the existing injury policy: unresolved retreat preserves damage and ammunition; completed defeat or safe bypass recovers encounter-local injuries. An injured-bypass regression and a retreat-through-search-to-patrol regression verify that distinction. `./scripts/check` passed again, as did all 49 local links/anchors in the four changed Markdown documents. This follow-up changes tests, comments and documentation only; it adds no phone or rendered-performance claim.

**TestFlight integration, 23 November 2026:** The maintainer authorised integrating the reviewed work and delivering it through TestFlight. [PR #134](https://github.com/RonildoBraga/lauder/pull/134) incorporated #128–#133 as one squash because the repository allows squash merges only; the earlier drafts were closed as incorporated rather than individually merged. Integrated app/archive source `ea47e2b40d5fa4a4c4c16149e9755ac5475f9b7e` has the exact tree of reviewed release-preparation commit `26c5d99977290283b41e6a2a3ed93dfcabc17c4c`. Apple discovery selected unused **0.1.0 (29)**, and archive/upload rechecked accepted and processing uploads. The [delivery record](#testflight-delivery) confirms processing and unchanged tester access. Physical-phone behaviour and performance remain unverified.

### Pawns and dodge roll

On 25 November 2026 the maintainer chose simpler figures for the party from a [game-scale mock-up sheet](../art/party/README.md). The maintainer confirmed the pawn as mocked up, with one skin tone for all three and Snow for the white fur, accepted the [dodge roll](decisions/0019-dodge-roll.md)'s starting values, and said **“Start building”**. The decisions are relayed on [issue #142](https://github.com/RonildoBraga/lauder/issues/142).

- **Models:** Miki, Laura and Tom are rebuilt in Blender as the sheet's pawns. They have 216, 296 and 228 triangles, stand 1.535 to 1.635 m tall, and have no rig or textures. Each passes the model intake check and was exported with the registered exporter.
- **Motion:** `PawnGait` shows each step's resolved movement as a bob, a rock and a lean. `DodgeRoll` supplies the roll's movement and its tumble. The world's fixed step drives both, and both stay presentation apart from the roll's movement.
- **Checks:** `./scripts/check` passed:
  - 13 declaration-contract tests, 28 offline release tests, 52 Blender tests and seven sound fingerprints;
  - Swift formatting and the app build;
  - Swift Testing on an iOS 27 iPhone 17 simulator: 290 tests in 393 runs.

  New tests cover the walk, the roll's distance, tumble and direction, its cooldown, a roll ended by a leader switch or a scene, the dodge press and its release gate, shots passing through a rolling leader, and the pawn models' heights and facing.
- **Simulator:** the rendered routes passed with no failures or companion warning frames. Mean frame time was 16.7 ms and p99 16.8 ms, Simulator measurements only.

  | Route | Steps |
  |---|---:|
  | `first-fight` | 35/35 |
  | `opening` | 56/56 |

  Played by hand with touch on the iPhone 17 simulator:
  - **Roll from standing:** Roll tumbles Miki one full turn forward the way she faces, and she lands upright.
  - **Roll while moving:** with the stick already held to the side, she rolls that way and walks on.
  - **Walk:** her rock from side to side shows.
  - **Not exercised by hand:** Space. The Simulator tool's key presses are shorter than a frame, so the game never samples them held; the input tests cover the binding.
- **Review:** a second Claude review pass, by a separate agent and so not independent, found four defects. Each is fixed with a regression test:
  - a roll carried on into a scene that holds the party;
  - a leader switch skipped the cooldown;
  - a press that no fixed step took up survived a Pause;
  - the touch Roll button covered the conversation panel's lines.

  The two new GameWorld tests fail without their fix.
- **Phone:** in the [build 32 playtest](#build-32-playtest) the maintainer said the weapons and controls, the roll among them, feel right. Not yet verified: frame pacing, how the pawns read at their real size, the touch Roll button with a finger on the stick, and the guard fight's balance with a roll.

### Controls pass

On 26 November 2026, after reviewing a map of the controller's buttons, the maintainer asked for three changes in a Claude session, which has no public permalink:
- **“instead of using R1 and L1 to navigate through the characters, we should just use L1 and go in circles”**. L1 / LB is now the only leader switch. It goes round the party in the order that Next keeps on touch and Q on a keyboard: Miki, Tom, then Laura. Previous and its Z key are gone. This pass freed R1 / RB; the later paired-weapons pass below assigned it to Swap. The D-pad keeps its sides, so right sends whoever L1 would lead as.
- **“The circle button used for status panel, we should remove from the circle button and just make as a option in the pause menu.”** The pause menu has a fourth choice, **Status panel: Shown** or **Hidden**, which stays in the menu as Vibration does. Circle / B and the H key no longer hide the panel and are unassigned. Touch is unchanged: its pause screen has no such choice, and the panel always shows.
- **The [lock-on](decisions/0020-lock-on.md)**, quoted in its decision record. A press of the right stick locks the aim on a hostile, circled in red; the next press moves it on, and two quick presses let go.

Checks:
- **`./scripts/check` passed:**
  - 13 declaration-contract tests, 28 offline release tests, 52 Blender tests and seven sound fingerprints;
  - Swift formatting and the app build;
  - Swift Testing on an iOS 27 iPhone 17 simulator: 290 tests in 392 runs.

  New tests cover the lock press and its release gate, the first lock and going round clockwise, a quick second press letting go, letting go out of reach, the locked shot, the red ring's place and size, and Restart. A world test fights three guards: the stick aims left, the lock turns the leader right, and Fire downs the locked guard, not the one ahead. The pause menu's tests cover the Status panel choice.
- **Simulator:** the new `lock-on` route locks on the first-tower guard, fires until it is down and checks that the lock let go. Mean frame time was 16.7 ms and p99 16.8 ms, Simulator measurements only.

  | Route | Steps |
  |---|---:|
  | `lock-on` | 25/25 |
  | `first-fight` | 35/35 |

  The first rendered run showed no ring. The towers' baked shadows lie 3 cm over the snow and covered it, and the guard stands in the Brooklyn tower's shadow. The ring now stands above them, and the route's screenshot shows it round the guard.
- **Found on the way:** the assisted target's red disc and the companions' order rings are also drawn below those shadows, so a tower's shadow hides them. That predates this change and is left as it was.
- **Not exercised by hand:** a controller and the O key. The Simulator delivers no controller input, and its key presses are shorter than a frame, so the route drives the lock through the same input rules instead.
- **Phone:** in the [build 32 playtest](#build-32-playtest) the maintainer said the weapons and controls feel right. Not yet verified: frame pacing, how the ring reads at the phone's size, and the guard fight's balance with a lock.

### Three together

On 26 November 2026 the maintainer asked: **“I want to simplify the starting of the game so all the 3 companions will start together so no need to meet Tom and Laura later in the game”**. Asked what then happens to the scenes that introduced Tom and Laura, the maintainer chose **“Guard fight only”**. Both were said in a Claude session, which has no public permalink.

- **Start:** Miki, Tom and Laura start at the Brooklyn end, Tom and Laura in the Close formation's places behind Miki, Tom on the right and Laura on the left. Next, the formations and the orders work from the start.
- **Story:** the beats are the crossing, the first-tower guard and the Manhattan end. The supply case's search, the knife attacker's ambush with Tom's shot, Laura's rescue and the medical kit are gone, with their conversations. The closing exchange stays.
- **Removed with them:** the Search and Help actions, loot and the medical kit, so Look only looks around. The supply case stays as scenery, and its unused layout names go at the level's next export. The shared rounds stay until the weapons pass replaces them.
- **Checks:** `./scripts/check` passed: 13 declaration-contract tests, 28 offline release tests, 52 Blender tests, seven sound fingerprints, Swift formatting, the app build, and Swift Testing on an iOS 27 iPhone 17 simulator, 273 tests in 373 runs. Rewritten tests cover the three starting together in their Close places, the beats in order, a bypass leading on to Manhattan, a retry and Restart keeping the three together, and the closing exchange. The headless routes now run `bridge-walk`, `first-fight`, `fight-retry`, `opening`, `formations`, `orders` and `lock-on`; `ambush` and `laura` went with their scenes.
- **Phone:** played in the [build 32 playtest](#build-32-playtest). Not yet verified: frame pacing, and how the guard fight plays with the companions beside the leader from the start.

### Paired weapons

On 26 November 2026 the maintainer gave each character two weapons, and chose how the open points work. The request and choices are quoted in [ADR 0021](decisions/0021-paired-weapons.md).

- **Weapons:**
  - Miki: a long rifle and an assault rifle.
  - Laura: a shotgun and an energy sword that strikes close by and turns shots from in front of her.
  - Tom: a minigun that spins up, and a shield dome that stays up round him while Fire is held.
- **Switching:** R1 / RB, T or the touch **Swap** button brings the other weapon into hand, and each keeps its magazine.
- **Rounds:** none are counted beyond the magazine, and the status shows the weapon in hand.
- **Sounds:** at first each weapon borrowed the nearest existing sound. [Weapon sounds](#weapon-sounds--in-development) gives each its own.
- **Checks:** `./scripts/check` passed: 13 declaration-contract tests, 28 offline release tests, 52 Blender tests, seven sound fingerprints, Swift formatting, the app build, and Swift Testing on an iOS 27 iPhone 17 simulator, 283 tests in 395 runs. New tests cover the pairs and the switch keeping each magazine, the switch press, the long rifle's heavy hit, the assault rifle's rapid fire past a reload, the minigun's spin-up and slower walk, the dome stopping shots for everyone inside it and shots landing once it drops, its run-down and recharge, and the sword striking in front within reach and turning shots from in front only.
- **Simulator:** in the new `weapons` route Tom raises his dome against the guard's bursts and nobody is hurt, then switches to the minigun and brings the guard down. Its screenshot shows the dome round all three, with the status reading **Shield · Up**. Mean frame time was 16.7 ms and p99 16.8 ms, Simulator measurements only.

  | Route | Steps |
  |---|---:|
  | `weapons` | 28/28 |
  | `first-fight` | 35/35 |
- **Phone:** in the [build 32 playtest](#build-32-playtest) the maintainer said the weapons and controls feel right. Not yet verified: frame pacing, the touch Swap button, how the blade and the dome read at the phone's size, and the guard fight's balance, which the heavier hits change.

### Build 32 playtest

TestFlight 0.1.0 (32) was delivered on 26 November 2026 from the head of [PR #158](https://github.com/RonildoBraga/lauder/pull/158), `0a50613`, before any merge. It carries the pawns and dodge roll, the controls pass, the three starting together and the paired weapons. The [delivery record](https://github.com/RonildoBraga/lauder/pull/158#issuecomment-7176893712) gives Apple's confirmation.

Asked **“How do the weapons and controls feel on your phone?”**, the maintainer answered **“Feels right”**. That is the maintainer's judgement of the weapons and controls as played. No frame-pacing capture was taken, and the question did not cover the guard fight's balance or how the pawns read at their size.

All four pull requests then merged into `main` on 26 November 2026, in order: [#155](https://github.com/RonildoBraga/lauder/pull/155) as `c757cad`, [#156](https://github.com/RonildoBraga/lauder/pull/156) as `a8e7dc9`, [#157](https://github.com/RonildoBraga/lauder/pull/157) as `52fa921` and [#158](https://github.com/RonildoBraga/lauder/pull/158) as `135c2a4`. `main`'s app sources are those of `0a50613`; only the five documents that record the playtest differ. Main's check [passed](https://github.com/RonildoBraga/lauder/actions/runs/45720003568) on `135c2a4`.

### Historical architecture checks

Integrated source `7158f29a44738cfd0188292ef3839d0338bd7c73` has the exact tree of reviewed source `c01dd03f6532063c959f2da9fcd663b3f9d393f3`. On `c01dd03`, `./scripts/check` passed formatting, the shared app build and hosted Swift suite, including all eight retained headless routes and six new camera/progression regression tests, plus **13 declaration-contract tests**, **28 offline release-contract tests**, **51 Blender tests** and **seven generated sounds**. [GitHub Actions run 45002053969](https://github.com/RonildoBraga/lauder/actions/runs/45002053969) passed on that reviewed source. Source review completed with no outstanding findings.

At that historical source, the retained headless routes were `bridge-walk`, `first-fight`, `fight-retry`, `ambush`, `laura`, `opening`, `formations` and `orders`. The current merged baseline instead has eight: `bridge-walk`, `first-fight`, `fight-retry`, `opening`, `formations`, `orders`, `lock-on` and `weapons`. The strategic branch updates these existing routes for the dismantling fight; use `./apple/scripts/playtest --list` for the checked-out source.

Rendered Simulator checks on `b533e2ff8ee210eb030737293e47524ed008f47e` passed with no route failures or companion warning frames:

| Source | Route | Result |
|---|---|---:|
| `b533e2f` | `opening` | 56/56 |
| `b533e2f` | `orders` | 130/130 |

The app, Swift-test and Blender sources in those recordings are unchanged in integrated source `7158f29`; the recordings are not exact-head repository captures.

### TestFlight delivery

The source-bound standard check also passed on app/archive source `7158f29`. Its signed **0.1.0 (28)** Release archive passed bundle, signing-team, signature and matching-dSYM verification. At **2026-11-22 08:38:25 UTC**, Apple's read-only verification confirmed Lauder's identity, upload **COMPLETE** with **zero errors**, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired build and availability to the existing internal testers. Existing internal groups contain the build; group and tester membership are unchanged. Private archives, symbols and full processing evidence are preserved. Availability does not establish phone installation, physical behaviour, performance or enjoyment.

App/archive source `ea47e2b40d5fa4a4c4c16149e9755ac5475f9b7e`, integrated through [PR #134](https://github.com/RonildoBraga/lauder/pull/134), delivers the bridge environment, camera B and C robot in **0.1.0 (29)**. It matches the reviewed release tree and passed the source-bound standard check, signed archive identity/signature/team and matching-dSYM verification. At **2026-11-23 05:12:59 UTC**, Apple's read-only verification confirmed Lauder's identity, upload **COMPLETE** with **zero errors**, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired build and availability to the existing internal testers. Existing internal groups contain the build; group and tester membership are unchanged. Private archives, symbols and full evidence are preserved. TestFlight availability does not establish phone installation, physical behaviour, performance or enjoyment.

Build **0.1.0 (30)** was delivered on 25 November 2026 from the head of draft [PR #154](https://github.com/RonildoBraga/lauder/pull/154), `f80fa13`, before any merge, so that the maintainer could play its detailed Miki on the phone. Its [delivery record](https://github.com/RonildoBraga/lauder/pull/154#issuecomment-7154103454) is on that PR. The [pawns](#pawns-and-dodge-roll) replace that character route, so build 30's characters never reached `main`.

### Simulator and physical evidence

Simulator is the everyday validation environment. The script drives ordinary input through shared rules, saves screenshots/video and reports frame time, simulation cost, companion spacing and route failures. DEBUG instrumentation and route helpers are absent from Release builds. Test-only flat ranges and a narrow doorway fixture remain outside the app target because they exercise bridge weapons and navigation boundaries.

The target remains 60 fps on the baseline iPhone 13 Pro Max. Simulator measurements do not establish phone frame pacing, haptics, thermals, multi-touch, hardware input or enjoyment. The user deferred frequent phone checks; do not claim a new physical result without one.

### Deferred phone and playtest checks

- Verify the retained bridge's current controller/touch controls, release gates, Pause, interruption recovery and camera on a physical phone at the next agreed checkpoint.
- Measure representative Release frame pacing and sustained performance before making baseline-device claims.
- Check on the phone that the pawns read at their real size and that the walk and the dodge roll feel right. Include the touch Roll button pressed while a finger holds the stick, and Square / X on a controller.
- Listen on the phone to each weapon's sound, the minigun's spin-up and the dome's sounds, and feel their vibrations ([weapon sounds](#weapon-sounds--in-development)).
- Ask what is enjoyable and what should change before adding another scene or complex mechanic. TestFlight availability supplies no answer to that question.

### Historical delivery

Build **0.1.0 (27)** delivered the bridge-only reset ([PR #122](https://github.com/RonildoBraga/lauder/pull/122), [delivery record in PR #123](https://github.com/RonildoBraga/lauder/pull/123)) from app/archive source `de4d0db566a546217f3c3ca095cdf1b3944a21e3`, matching the exact tree of checked/reviewed `feabb43f10f3708bc6fef4f940f26c2d8b7b462d`. The standard check passed **255 Swift tests**, **51 Blender tests** and **seven generated sounds**; the signed archive passed bundle/team/signature/dSYM verification. At **2026-11-22 07:14:36 UTC**, Apple confirmed upload **COMPLETE** with **zero errors**, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired build and existing internal tester availability with membership unchanged. Earlier recording details and review history remain in the original PRs and Git history; private archives, symbols and full processing evidence are preserved.

Build **0.1.0 (26)**, source `25195e8`, was verified as processed and available before the reset. It contains the removed scenes; [ADR 0016](decisions/0016-combat-balance-and-readability.md) and Git history preserve its historical decisions and delivery evidence. Private archives, symbols and full processing evidence remain preserved.

## Combat balance and readability

The build 26 tuning and measurements in [ADR 0016](decisions/0016-combat-balance-and-readability.md) are historical. Native weapon handling, shot effects, ballistics and companion yielding still serve the bridge. The arena, extra weapons, tactical enemies and preparation displays are retired; their old measurements do not assign a new implementation pass.

## Combat design review gate

The preceding C first-tower prototype is implemented in the merged baseline, with its recorded source/Simulator checks. Builds 34–39 delivered explicit companion commands, bounded retaliation, useful ordinary damage, cover/spacing, touch/squad fixes, distinct weapon sounds, persistent eye criticals, detachable legs, Tom’s grenade and impaired locomotion. The latest [build 40 preview](#build-40-testflight-preview) adds the short leg-break stagger and fresh firing warning, with source/Simulator checks and verified existing-tester availability. Earlier basic phone success does not verify this revision. Source tests, Simulator success and TestFlight availability do not settle physical acceptance, balance, enjoyment or phone performance. The request for enemy/companion intelligence ideas remains research/design work; new scenes, A’s variant and further releases remain separate assignments.

The broader squad combat direction, [The Quiet Yard](encounters/the-quiet-yard.md) and later narrative plans remain reference rather than assignments. The removed S4 experiments stay retired.

## Outside the first playable

Additional playable scenes, general tactical combat AI beyond the assigned guard and its bounded companion revision, signature abilities, salvage-repair machinery, extra equipment, elevation, skill trees, health/hunger systems, multiplayer, crafting, branching dialogue, finished art, persistence, cloud services and App Store submission. The strategic guard does not assign those systems.

## Later hardening

Before persistence, define a versioned snapshot of session progress, inventory, stable member IDs and a safe group spawn. Keep entity graphs, routes and transient animation out of it. Use ordered atomic writes and explicit error handling; preserve an unreadable save until the player chooses Restart. Sustained physical-phone thermal and memory checks follow a loop worth keeping.
