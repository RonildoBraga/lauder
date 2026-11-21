import RealityKit
import Testing
import simd

@testable import Lauder

/// ADR 0004, milestone M2: the stranger on the bridge. The session's rules, the Fire input and
/// the whole fight in the world, without rendering.
@MainActor
struct FirstFightTests {
  // MARK: - Session

  @Test
  func anEncounterBeginsOnceInOrderAndARetryReturnsToItsStart() {
    let session = GameSession(level: BrooklynBridge.level)
    #expect(session.ammo == 12)
    #expect(session.beat == .alone && !session.inEncounter)
    session.togglePause()
    #expect(!session.beginEncounter(.stranger))
    session.togglePause()
    #expect(session.beginEncounter(.stranger))
    #expect(!session.beginEncounter(.stranger))
    #expect(session.beat == .stranger && session.inEncounter)
    #expect(session.spendRound())
    #expect(!session.hit("stranger", toughness: 2))
    #expect(!session.takeHit())
    #expect(!session.takeHit())
    #expect(session.takeHit())
    session.retryEncounter()
    #expect(session.beat == .alone && !session.inEncounter)
    #expect(session.ammo == 12 && session.hitsTaken == 0 && session.defeated.isEmpty)
    // The second time, the hit dealt before the retry no longer counts.
    #expect(session.beginEncounter(.stranger))
    #expect(!session.takeHit())
    #expect(!session.hit("stranger", toughness: 2))
    #expect(session.hit("stranger", toughness: 2))
    #expect(!session.hit("stranger", toughness: 2))
    // Winning recovers the leader's hits; outside a fight nothing can hit her.
    session.endEncounter()
    #expect(session.defeated == ["stranger"] && session.hitsTaken == 0 && !session.inEncounter)
    #expect(!session.takeHit())
    session.restart()
    #expect(session.beat == .alone && session.defeated.isEmpty && session.ammo == 12)
  }

  @Test
  func roundsRunOut() {
    let session = GameSession(level: BrooklynBridge.level)
    for _ in 0..<12 { #expect(session.spendRound()) }
    #expect(!session.spendRound())
    #expect(session.ammo == 0)
  }

  // MARK: - Fire input

  @Test
  func fireIsAPressThenAHoldWhileExploring() {
    let open = InputRules.State(needsNeutralInput: false)
    let press = InputRules.resolve(
      InputRules.Raw(controllerFire: true), mode: .exploring, state: open)
    #expect(press.input.firePressed && press.input.fireHeld)
    let hold = InputRules.resolve(
      InputRules.Raw(keyboardFire: true), mode: .exploring, state: press.state)
    #expect(!hold.input.firePressed && hold.input.fireHeld)
    for mode in [GameSession.Mode.paused, .dialogue] {
      let consumed = InputRules.resolve(InputRules.Raw(touchFire: true), mode: mode, state: open)
      #expect(!consumed.input.firePressed && !consumed.input.fireHeld)
    }
    // A held Fire keeps the release gate closed, as every other control does.
    let gated = InputRules.resolve(
      InputRules.Raw(controllerFire: true), mode: .exploring, state: InputRules.State())
    #expect(gated.state.needsNeutralInput && !gated.input.fireHeld)
    #expect(InputRules.Raw(keyboardFire: true).hasKeyboardInput)
  }

  // MARK: - The fight in the world

  @Test
  func theStrangerWaitsUnseenUntilMikiComesNear() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let body = try #require(world.root.findEntity(named: "hostile.stranger"))
    #expect(!body.isEnabled)
    walk(world, to: [6.5, 18])
    #expect(world.session.beat == .alone && !body.isEnabled && !world.showsAmmo)
    walk(world, to: [6.5, 15])
    #expect(world.session.beat == .stranger && world.showsWeapon)
    #expect(run(world, upTo: 1) { world.observation == "Miki: “Friendly!”" })
    #expect(body.isEnabled)
  }

  @Test
  func mikiHoldsFireAtHimUntilHeOpensFire() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let marker = try #require(world.root.findEntity(named: "combat.target"))
    walk(world, to: [6.5, 15])
    // Until he fires, nobody knows he is hostile: aimed at him, Miki draws but holds her fire,
    // and he is not marked (ADR 0007).
    let atHim = stick(world, towards: BrooklynBridge.stranger.standAt - position(world, .miki))
    #expect(run(world, upTo: 4, fire: true, aim: atHim) { world.threat != nil })
    #expect(world.weaponDrawn && !marker.isEnabled)
    #expect(world.session.ammo == 12)
  }

  @Test
  func afterHisDeliberateMissTwoShotsPutHimDown() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let marker = try #require(world.root.findEntity(named: "combat.target"))
    walk(world, to: [6.5, 15])
    #expect(run(world, upTo: 4) { world.threat != nil })
    #expect(world.threat == "The stranger is aiming.")
    // His first shot goes wide on purpose, and the HUD says how to answer it.
    #expect(run(world, upTo: 2) { world.threat == nil })
    #expect(world.session.hitsTaken == 0)
    #expect(world.observation == BrooklynBridge.stranger.missLine)
    // Now he is a target: Fire draws and marks him, then two shots put him down.
    run(world, upTo: 0.2, fire: true)
    #expect(world.weaponDrawn && marker.isEnabled && world.session.ammo == 12)
    #expect(run(world, upTo: 2, fire: true) { !world.session.defeated.isEmpty })
    #expect(world.session.defeated == ["stranger"] && world.session.ammo == 10)
    #expect(world.observation == "The stranger is down.")
    #expect(!world.session.inEncounter && world.session.hitsTaken == 0 && world.threat == nil)
    // Down, he stays down: no target, and no more rounds spent.
    run(world, upTo: 1, fire: true)
    #expect(world.session.ammo == 10 && !marker.isEnabled)
    #expect(try #require(world.root.findEntity(named: "hostile.stranger")).isEnabled)
  }

  /// The bridge camera shows only about 19 m ahead of Miki, so during the fight it leans
  /// towards the stranger, and back once he is down.
  @Test
  func theCameraLeansTowardsHimWhileHeStands() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let camera = try #require(world.root.findEntity(named: "camera"))
    // How far the camera has moved from where it sits behind Miki.
    let offset = BrooklynBridge.cameraOffset
    let lean = {
      simd_length(
        SIMD2(camera.position.x, camera.position.z) - position(world, .miki)
          - SIMD2(offset.x, offset.z))
    }
    walk(world, to: [6.5, 18])
    #expect(abs(lean()) < 0.01)
    walk(world, to: [6.5, 15])
    #expect(run(world, upTo: 2) { lean() > EncounterStage.cameraLeanLimit - 0.1 })
    #expect(lean() < EncounterStage.cameraLeanLimit + 0.01)
    // Once he is down, it settles back behind her.
    #expect(run(world, upTo: 4) { world.threat != nil })
    #expect(run(world, upTo: 2) { world.threat == nil })
    #expect(run(world, upTo: 2, fire: true) { !world.session.defeated.isEmpty })
    #expect(run(world, upTo: 3) { abs(lean()) < 0.05 })
  }

  /// Through the west arch, the tower's pier stands between Miki and him.
  @Test
  func coverBehindThePierBlocksHisShots() {
    let world = GameWorld(level: BrooklynBridge.level)
    walk(world, to: [-6.5, 30])
    walk(world, to: [-4, 10])
    #expect(world.session.beat == .stranger)
    // He aims and fires three times: the deliberate miss, then twice into the pier.
    for _ in 0..<3 {
      #expect(run(world, upTo: 4) { world.threat != nil })
      #expect(run(world, upTo: 2) { world.threat == nil })
    }
    #expect(world.session.hitsTaken == 0 && world.session.inEncounter)
  }

  @Test
  func outOfRangeHisShotsFallShort() {
    let world = GameWorld(level: BrooklynBridge.level)
    walk(world, to: [6.5, 15])
    walk(world, to: [6.5, 30])
    let stranger = BrooklynBridge.stranger
    #expect(simd_distance(position(world, .miki), stranger.standAt) > stranger.range)
    for _ in 0..<2 {
      #expect(run(world, upTo: 4) { world.threat != nil })
      #expect(run(world, upTo: 2) { world.threat == nil })
    }
    #expect(world.session.hitsTaken == 0 && world.session.inEncounter)
  }

  @Test
  func pauseHoldsTheFight() {
    let world = GameWorld(level: BrooklynBridge.level)
    walk(world, to: [6.5, 15])
    #expect(run(world, upTo: 4) { world.threat != nil })
    pressPause(world)
    #expect(world.isPaused)
    for _ in 0..<(60 * 5) { world.update(with: .neutral, sampledIn: .paused, deltaTime: 1 / 60) }
    #expect(world.threat == "The stranger is aiming." && world.session.hitsTaken == 0)
    pressPause(world)
    #expect(!world.isPaused)
    // After Resume he finishes the same wind-up: still the deliberate miss.
    #expect(run(world, upTo: 2) { world.threat == nil })
    #expect(world.session.hitsTaken == 0)
  }

  @Test
  func theThirdHitStartsTheFightAgainWithNothingLost() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let entities = count(world.root)
    walk(world, to: [6.5, 15])
    let fired = world.session.firedTriggers
    #expect(run(world, upTo: 8) { world.session.hitsTaken == 1 })
    #expect(run(world, upTo: 8) { world.isRetrying })
    #expect(world.session.hitsTaken == GameSession.hitsAllowed)
    // The screen fades out; Pause holds the fade where it is.
    #expect(run(world, upTo: 1) { world.fade > 0.5 })
    let fade = world.fade
    pressPause(world)
    for _ in 0..<60 { world.update(with: .neutral, sampledIn: .paused, deltaTime: 1 / 60) }
    #expect(world.fade == fade && world.isRetrying)
    pressPause(world)
    #expect(run(world, upTo: 1.5) { !world.isRetrying })
    #expect(world.fade == 0 && world.observation == "Try again.")
    #expect(world.session.beat == .alone && world.session.hitsTaken == 0)
    #expect(world.session.ammo == 12 && world.session.defeated.isEmpty)
    #expect(!world.session.inEncounter && world.session.firedTriggers == fired)
    let retryAt = try #require(BrooklynBridge.strangerEncounter.retryAt)
    #expect(simd_distance(position(world, .miki), retryAt) < 0.01)
    #expect(try #require(world.root.findEntity(named: "hostile.stranger")).isEnabled == false)
    #expect(count(world.root) == entities)
    // Walking back in plays the fight again from its start, deliberate miss and all.
    walk(world, to: [6.5, 15])
    #expect(world.session.beat == .stranger)
    #expect(run(world, upTo: 4) { world.threat != nil })
    #expect(run(world, upTo: 2) { world.threat == nil })
    #expect(world.session.hitsTaken == 0)
    #expect(run(world, upTo: 2, fire: true) { world.session.defeated == ["stranger"] })
  }

  @Test
  func restartPutsTheFightBackWhereverItHadGot() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let entities = count(world.root)
    let body = try #require(world.root.findEntity(named: "hostile.stranger"))
    let camera = try #require(world.root.findEntity(named: "camera"))
    for retrying in [false, false, true] {
      walk(world, to: [6.5, 15])
      #expect(run(world, upTo: 4) { world.threat != nil })
      #expect(run(world, upTo: 2) { world.threat == nil })
      #expect(run(world, upTo: 1, fire: true) { world.session.ammo == 11 })
      #expect(run(world, upTo: 4) { world.session.hitsTaken == 1 })
      if retrying { #expect(run(world, upTo: 8) { world.isRetrying }) }
      world.restart()
      #expect(world.session.beat == .alone && !world.session.inEncounter)
      #expect(world.session.ammo == 12 && world.session.hitsTaken == 0)
      #expect(world.session.defeated.isEmpty && world.session.firedTriggers.isEmpty)
      #expect(!world.weaponDrawn && !world.showsAmmo && world.threat == nil)
      #expect(!world.isRetrying && world.fade == 0)
      #expect(world.observation == BrooklynBridge.level.opening)
      #expect(position(world, .miki) == BrooklynBridge.level.spawn(.miki))
      // The camera no longer leans towards the fight.
      let behind = camera.position.z - position(world, .miki).y
      #expect(abs(behind - BrooklynBridge.cameraOffset.z) < 0.001)
      #expect(!body.isEnabled)
      #expect(count(world.root) == entities)
    }
  }
}
