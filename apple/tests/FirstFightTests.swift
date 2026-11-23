import RealityKit
import Testing
import simd

@testable import Lauder

/// The first-tower C guard on the bridge. The session's rules, the Fire input and
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

  // MARK: - The robot in the world

  @Test
  func theGuardWaitsUnseenUntilMikiReachesTheFirstTower() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let robot = try #require(world.root.findEntity(named: "hostile.stranger"))
    #expect(!robot.isEnabled)
    walk(world, to: [6.5, 18])
    #expect(world.session.beat == .alone && !robot.isEnabled)
    walk(world, to: [6.5, 15])
    #expect(world.session.beat == .stranger && world.showsWeapon)
    #expect(run(world, upTo: 1) { robot.isEnabled })
    #expect(BrooklynBridge.stranger.attack == .robot && BrooklynBridge.stranger.loot == nil)
  }

  @Test
  func theGuardCanBeDisabledWithoutAnAuthoredHumanWarningShot() {
    let world = GameWorld(level: BrooklynBridge.level)
    walk(world, to: [6.5, 10])
    #expect(run(world, upTo: 6, fire: true) { world.session.defeated.contains("stranger") })
    #expect(run(world, upTo: 1) { !world.session.inEncounter })
    #expect(world.session.ammo <= 6 && world.session.ammo >= 0)
    #expect(world.session.hitsTaken == 0 && world.threat == nil)
    #expect(world.observation == "The guard robot is down.")
    let rounds = world.session.ammo
    run(world, upTo: 1, fire: true)
    #expect(world.session.ammo == rounds)
  }

  @Test
  func thePierCoversTheWestArchWhileTheGuardPatrols() {
    let world = GameWorld(level: BrooklynBridge.level)
    walk(world, to: [-6.5, 30])
    walk(world, to: [-4, 10])
    #expect(world.session.beat == .stranger && world.session.inEncounter)
    run(world, upTo: 8)
    #expect(world.session.hitsTaken == 0 && world.session.inEncounter)
    #expect(world.session.ammo == 12)
  }

  @Test
  func theWestExitSupportsAZeroAmmunitionBypassAndTheSameSupplies() {
    let world = GameWorld(level: BrooklynBridge.level)
    for _ in 0..<12 { #expect(world.session.spendRound()) }
    walk(world, to: [-6.5, 30])
    walk(world, to: [-6.5, -3])
    #expect(world.session.beat == .stranger && world.session.inEncounter)
    #expect(world.session.ammo == 0 && !world.isRetrying)
    walk(world, to: BrooklynBridge.supplyCasePosition)
    #expect(!world.session.inEncounter && world.session.beat == .stranger)
    #expect(!world.session.defeated.contains("stranger"))
    #expect(world.actionName == BrooklynBridge.searchStranger.name)
    world.performAction()
    #expect(world.session.beat == .ambush)
    #expect(run(world, upTo: 2) { world.session.medicalKits == 1 })
    #expect(world.session.ammo == 6 && world.session.searched == [BrooklynBridge.supplyCaseID])
    #expect(run(world, upTo: 5) { world.session.mode == .dialogue })
    #expect(world.session.hitsTaken == 0)
    #expect(world.session.defeated == ["attacker"])
    finishConversation(world)
    #expect(world.session.beat == .withTom && world.session.party == [.miki, .tom])
  }

  @Test
  func pauseFreezesTheGuardAndItsPendingAttack() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    walk(world, to: [6.5, 10])
    #expect(run(world, upTo: 5) { world.threat != nil })
    let body = try #require(world.root.findEntity(named: "hostile.stranger"))
    let at = body.position
    let rotation = body.orientation.vector
    let threat = world.threat
    let hits = world.session.hitsTaken
    pressPause(world)
    for _ in 0..<180 { world.update(with: .neutral, sampledIn: .paused, deltaTime: 1 / 60) }
    #expect(body.position == at && body.orientation.vector == rotation)
    #expect(world.threat == threat && world.session.hitsTaken == hits)
    pressPause(world)
    #expect(!world.isPaused)
    #expect(run(world, upTo: 5) { world.session.hitsTaken != hits })
  }

  @Test
  func threeBurstMistakesRetryFromTheExistingCheckpoint() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let entities = count(world.root)
    walk(world, to: [6.5, 10])
    #expect(run(world, upTo: 24) { world.isRetrying })
    #expect(world.session.hitsTaken == GameSession.hitsAllowed)
    #expect(run(world, upTo: 2) { !world.isRetrying })
    #expect(world.session.beat == .alone && world.session.hitsTaken == 0)
    #expect(world.session.ammo == 12 && world.session.defeated.isEmpty)
    #expect(!world.session.inEncounter)
    let retryAt = try #require(BrooklynBridge.strangerEncounter.retryAt)
    #expect(simd_distance(position(world, .miki), retryAt) < 0.01)
    #expect(world.root.findEntity(named: "hostile.stranger")?.isEnabled == false)
    #expect(count(world.root) == entities)
    walk(world, to: [6.5, 10])
    #expect(run(world, upTo: 6, fire: true) { world.session.defeated.contains("stranger") })
  }

  @Test
  func theCameraFollowsTheGuardThenSettlesAfterResolution() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let camera = try #require(world.root.findEntity(named: "camera"))
    let offset = BrooklynBridge.cameraOffset
    let lean = {
      simd_length(
        SIMD2(camera.position.x, camera.position.z) - position(world, .miki)
          - SIMD2(offset.x, offset.z))
    }
    walk(world, to: [6.5, 18])
    #expect(abs(lean()) < 0.01)
    walk(world, to: [6.5, 10])
    let robot = try #require(world.root.findEntity(named: "hostile.stranger"))
    #expect(
      run(world, upTo: 2) {
        let from = position(world, .miki)
        let towards = SIMD2(robot.position.x, robot.position.z) - from
        let expected = min(
          EncounterSimulation.cameraLeanLimit,
          simd_length(towards) * EncounterSimulation.cameraLeanShare)
        let actual =
          SIMD2(camera.position.x, camera.position.z) - from
          - SIMD2(offset.x, offset.z)
        return abs(simd_length(actual) - expected) < 0.08 && simd_length(actual) > 1
          && simd_dot(simd_normalize(actual), simd_normalize(towards)) > 0.99
      })
    #expect(lean() < EncounterSimulation.cameraLeanLimit + 0.01)
    #expect(run(world, upTo: 6, fire: true) { world.session.defeated.contains("stranger") })
    #expect(run(world, upTo: 3) { abs(lean()) < 0.05 })
  }

  @Test
  func restartClearsTheGuardAndPreservesLoadedEntities() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let entities = count(world.root)
    let body = try #require(world.root.findEntity(named: "hostile.stranger"))
    walk(world, to: [6.5, 10])
    run(world, upTo: 3)
    world.restart()
    #expect(world.session.beat == .alone && !world.session.inEncounter)
    #expect(world.session.ammo == 12 && world.session.defeated.isEmpty)
    #expect(world.session.searched.isEmpty && world.session.hitsTaken == 0)
    #expect(!world.weaponDrawn && world.threat == nil && !body.isEnabled)
    #expect(position(world, .miki) == BrooklynBridge.level.spawn(.miki))
    #expect(count(world.root) == entities)
  }
}
