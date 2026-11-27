import Testing
import simd

@testable import Lauder

/// Native grenade execution uses ordinary session/input requests and real geometry. The range
/// isolates incoming party damage so outgoing blast, cooldown and reset rules can be measured.
@MainActor
struct GrenadeIntegrationTests {
  @Test
  func onlyThePlayerControlledTomThrowsAndLeaderChangesDoNotResetRecharge() throws {
    let range = Range()
    range.step(throwing: true)
    #expect(range.fight.grenade == nil && range.fight.grenadeCooldown == 0)
    range.session.cycleLeader()
    try #require(range.session.leader == .tom)
    range.step(throwing: true)
    let thrown = try #require(range.fight.grenade)
    #expect(thrown.thrower == .tom)
    let cooldown = range.fight.grenadeCooldown
    range.session.cycleLeader()
    range.step(throwing: true)
    #expect(range.fight.grenade?.thrower == .tom)
    #expect(range.fight.grenadeCooldown > 0 && range.fight.grenadeCooldown <= cooldown)
    #expect(range.fight.status(for: .tom).loaded == Weapon.minigun.capacity)
  }

  @Test
  func oneBlastUsesOneOrdinaryHealthChangeWithoutEyeOrLegBonuses() throws {
    let range = Range()
    range.session.cycleLeader()
    range.step(throwing: true)
    var hits: [DamageHit] = []
    var blasts = 0
    for _ in 0..<120 * 3 {
      range.step()
      blasts += range.fight.blasts.count
      hits += range.fight.takeEvents().compactMap {
        if case .damaged(let hit) = $0 { hit } else { nil }
      }
    }
    let hit = try #require(hits.count == 1 ? hits.first : nil)
    #expect(blasts == 1 && range.fight.grenade == nil)
    #expect(hit.attacker == .tom && hit.weapon == nil && hit.effectiveness == .normal)
    #expect(hit.amount > 0 && hit.amount <= Grenade.maximumDamage && !hit.brokeComponent)
    let state = try #require(range.fight.guardStrategies["guard"])
    #expect(state.health == GuardStrategy.maximumHealth - hit.amount)
    #expect(state.detachedLegs.isEmpty && state.swordHits.isEmpty)
    #expect(range.session.defeated.isEmpty)
  }

  @Test
  func committedLandingDoesNotFollowTheTargetAndRealTallCoverBlocksSplash() throws {
    let wall = Level.Box.box("wall", at: [0, 2, 3], size: [20, 4, 0.5])
    let range = Range(boxes: [wall])
    range.session.cycleLeader()
    // A manual heading still permits a throw when target assistance cannot see through cover.
    range.step(throwing: true, aiming: true)
    let landing = try #require(range.fight.grenade?.destination)
    var blasts = 0
    for _ in 0..<120 * 3 {
      range.step()
      if let grenade = range.fight.grenade { #expect(grenade.destination == landing) }
      blasts += range.fight.blasts.count
      #expect(!range.fight.takeEvents().contains { if case .damaged = $0 { true } else { false } })
    }
    #expect(blasts == 1)
    #expect(range.fight.guardStrategies["guard"]?.health == GuardStrategy.maximumHealth)
  }

  @Test
  func pauseFreezesFlightFuseAndRechargeAndResetClearsEverything() throws {
    let range = Range()
    range.session.cycleLeader()
    range.step(throwing: true)
    let position = try #require(range.fight.grenade?.position)
    let cooldown = range.fight.grenadeCooldown
    range.session.togglePause()
    for _ in 0..<240 { range.step(throwing: true) }
    #expect(range.fight.grenade?.position == position)
    #expect(range.fight.grenadeCooldown == cooldown && range.fight.blasts.isEmpty)
    range.session.togglePause()
    range.step()
    #expect(range.fight.grenade?.position != position)
    range.fight.reset()
    #expect(range.fight.grenade == nil && range.fight.grenadeCooldown == 0)
    #expect(range.fight.blasts.isEmpty && range.fight.takeEvents().isEmpty)
  }

  @Test
  func aSecondPressDuringRechargeCannotCreateOrQueueAnotherGrenade() {
    let range = Range()
    range.session.cycleLeader()
    range.step(throwing: true)
    var blasts = 0
    for _ in 0..<120 * 9 {
      range.step(throwing: range.fight.grenadeCooldown > 1)
      blasts += range.fight.blasts.count
    }
    #expect(blasts == 1 && range.fight.grenade == nil && range.fight.grenadeCooldown == 0)
    range.step(throwing: true)
    #expect(range.fight.grenade != nil && range.fight.grenadeCooldown > 0)
  }

  @Test
  func scriptedPartyHoldsRejectAndConsumeGrenadeRequests() {
    let range = Range(holdsParty: true)
    range.session.cycleLeader()
    for _ in 0..<240 { range.step(throwing: true) }
    #expect(range.fight.grenade == nil && range.fight.grenadeCooldown == 0)
    #expect(range.fight.blasts.isEmpty)
    #expect(range.fight.guardStrategies["guard"]?.health == GuardStrategy.maximumHealth)
  }

  #if DEBUG
    @Test
    func aSubstepGrenadeRequestCannotTransferFromAnotherLeaderOrSurviveSwitchingAway() {
      let world = GameWorld(level: TestRange.practice)
      world.advanceParty(movement: .zero, grenadePressed: true, deltaTime: 1 / 1000)
      world.session.cycleLeader()
      world.advanceParty(movement: .zero, deltaTime: 1 / 60)
      #expect(
        !world.playtestSnapshot.grenadeInFlight && world.playtestSnapshot.grenadeCooldown == 0)
      world.advanceParty(movement: .zero, grenadePressed: true, deltaTime: 1 / 1000)
      world.session.cycleLeader()
      world.advanceParty(movement: .zero, deltaTime: 1 / 1000)
      world.session.cycleLeader()
      world.session.cycleLeader()
      world.advanceParty(movement: .zero, deltaTime: 1 / 60)
      #expect(world.session.leader == .tom)
      #expect(
        !world.playtestSnapshot.grenadeInFlight && world.playtestSnapshot.grenadeCooldown == 0)
      world.advanceParty(movement: .zero, grenadePressed: true, deltaTime: 1 / 60)
      #expect(world.playtestSnapshot.grenadeInFlight && world.playtestSnapshot.grenadeCooldown > 0)
    }
  #endif

  @MainActor
  private final class Range {
    let fight: EncounterSimulation
    let session: GameSession
    let figures: [PartyMember: SIMD2<Float>] = [.miki: [-7, 7], .tom: [0, 6], .laura: [7, 7]]

    init(boxes: [Level.Box] = [], holdsParty: Bool = false) {
      let hostile = Level.Hostile(
        id: "guard", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
        attack: .robot, strategicGuard: true, range: 12)
      let encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-20, -20], maximum: [20, 20])),
        retryAt: nil, hostiles: [hostile], cues: [(0, .reveal("guard")), (0, .engage("guard"))],
        holdsParty: holdsParty)
      let level = Level(
        id: "grenade-range", ground: .box("floor", at: [0, -0.15, 0], size: [60, 0.3, 60]),
        boxes: boxes, triggers: [], encounters: [encounter], party: [.miki, .tom, .laura],
        spawns: figures, heading: [0, -1], cameraOffset: BrooklynBridge.cameraOffset,
        fieldOfView: 22, opening: "Range", objective: "Test", lookAround: "Test",
        restartNote: "Test")
      session = GameSession(level: level)
      fight = EncounterSimulation(level: level)
      _ = session.beginEncounter(.stranger)
      fight.begin(encounter)
      step()
      _ = fight.takeEvents()
    }

    func step(throwing: Bool = false, aiming: Bool = false) {
      _ = fight.step(
        dt: 1 / 120, leader: figures[session.leader] ?? .zero, facing: [0, -1], aiming: aiming,
        fireHeld: false, firePressed: false, figures: figures, session: session,
        grenadePressed: throwing, untouchable: Set(session.party))
    }
  }
}
