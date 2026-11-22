import RealityKit
import Testing
import simd

@testable import Lauder

/// The relay run joins the existing salvage rules to a route with optional, bounded danger.
@MainActor
struct RelayRunTests {
  @Test(arguments: [PartyMember.laura, .tom])
  func eitherGateSpecialistCanFinishTheSafeJourneyWithoutAnyWeaponFiring(
    opener: PartyMember
  ) throws {
    let world = GameWorld(level: RelayRun.level)
    world.session.cycleFormation()
    let entities = count(world.root)
    let live = try collectRegulatorQuietly(in: world, opener: opener)
    #expect(!world.session.salvage.repaired)
    #expect(world.session.salvage.regulators.map(\.model) == [.compatible])
    #expect(world.session.salvage.known.contains(live))
    #expect(!world.session.salvage.emptied.contains(live))
    // This is a return journey through the district, not a remote repair from the depot.
    try quietWalk(world, through: [RelayRun.gateInside, RelayRun.gateOutside])
    try quietWalk(world, through: Array(RelayRun.safeRoute.reversed()))
    try quietWalk(world, through: [RelayRun.transmitterPoint])
    try gatherQuietly(world)
    #expect(world.actionName == "Fit regulator")
    world.performAction()
    #expect(world.session.salvage.repaired)
    #expect(world.session.mode == .dialogue)
    finishConversation(world)
    #expect(world.session.mode == .exploring)
    #expect(world.objective == RelayRun.salvage.doneObjective)
    #expect(world.compass == nil && world.session.salvage.regulators.isEmpty)
    #expect(!world.session.salvage.emptied.contains(live))
    try expectQuiet(world)

    world.restart()
    #expect(!world.session.salvage.repaired && !world.session.salvage.gateOpen)
    #expect(world.session.salvage.known.isEmpty && world.session.salvage.regulators.isEmpty)
    #expect(world.session.conversation == nil && world.session.beat == .alone)
    #expect(world.session.ammo == RelayRun.level.startingAmmo && count(world.root) == entities)
    #expect(world.objective == RelayRun.level.objective)
    #expect(world.compass != nil)
  }

  @Test
  func aCompanionCanTriggerTheGuardAndTheFightWaitsForThatCompanionToLeave() throws {
    var level = RelayRun.level
    // Observe movement and boundary rules without ordinary companion fire ending the fight.
    level.combat.companionWeapons = [:]
    let world = GameWorld(level: level)
    walk(world, to: [5, 1])
    try #require(!world.session.inEncounter)
    #expect(world.session.send(.tom, to: [5, -4]))
    try #require(run(world, upTo: 8) { world.session.inEncounter })
    #expect(!RelayRun.guardArea.contains(position(world, .miki)))
    #expect(RelayRun.guardArea.contains(position(world, .tom)))
    for _ in 0..<12 { world.advanceParty(movement: .zero, deltaTime: 1 / 60) }
    #expect(world.session.inEncounter)
    // Regroup recalls the inside companion; being outside as leader never granted him immunity.
    world.session.pressFormation()
    try #require(run(world, upTo: 8) { !world.session.inEncounter })
    #expect(world.session.party.allSatisfy { !RelayRun.guardArea.contains(position(world, $0)) })
    #expect(simd_distance(position(world, .miki), [5, 1]) < 0.3)
    #expect(world.fallBacks == 0 && world.session.defeated.isEmpty)
  }

  @Test
  func guardedWithdrawalPreservesTheCollectedPartAndAllowsReentryThenRestart() throws {
    var level = RelayRun.level
    level.combat.companionWeapons = [:]
    let world = GameWorld(level: level)
    _ = try collectRegulatorQuietly(in: world, opener: .tom)
    try quietWalk(world, through: [RelayRun.gateInside, RelayRun.gateOutside])
    try quietWalk(world, through: Array(RelayRun.safeRoute.reversed()))
    let salvage = world.session.salvage
    walk(world, to: [5, 1])
    walk(world, to: [5, -4])
    try #require(world.session.inEncounter)

    pressPause(world)
    let held = Dictionary(
      uniqueKeysWithValues: world.session.party.map { ($0, position(world, $0)) })
    let ammo = world.session.ammo
    let input = InputRules.Input(
      movement: [1, 1], actionPressed: true, pausePressed: false, switchPressed: true)
    for _ in 0..<90 { world.update(with: input, sampledIn: .paused, deltaTime: 1 / 60) }
    #expect(world.session.mode == .paused && world.session.ammo == ammo)
    #expect(world.session.salvage == salvage)
    for member in world.session.party { #expect(position(world, member) == held[member]) }
    pressPause(world)
    _ = world.controls.resolve(InputRules.Raw(), mode: .exploring)

    let rounds = world.session.ammo
    try #require(run(world, upTo: 1, fire: true) { world.session.ammo < rounds })
    let used = world.session.ammo
    world.session.pressFormation()
    walk(world, to: [5, 1])
    try #require(run(world, upTo: 8) { !world.session.inEncounter })
    #expect(world.session.salvage == salvage && world.session.ammo == used)
    #expect(world.session.beat == .alone && world.fallBacks == 0)
    #expect(simd_distance(position(world, .miki), [5, 1]) < 0.3)
    #expect(!world.weaponDrawn && world.threat == nil)
    walk(world, to: [5, -4])
    #expect(world.session.inEncounter && world.session.salvage == salvage)

    world.restart()
    #expect(!world.session.inEncounter && world.session.beat == .alone)
    #expect(world.session.salvage.regulators.isEmpty && world.session.salvage.known.isEmpty)
    #expect(!world.session.salvage.gateOpen && !world.session.salvage.repaired)
    #expect(world.session.ammo == level.startingAmmo && world.session.defeated.isEmpty)
    #expect(position(world, .miki) == level.spawn(.miki))
  }

  @Test
  func aGuardTargetsTheCompanionInsideItsBoundaryRatherThanTheNearerOutsideLeader() throws {
    let figures: [PartyMember: SIMD2<Float>] = [
      .miki: [0, -3.5], .tom: [0, 2], .laura: [5, 5],
    ]
    let level = guardRange(figures: figures, windUp: 0.2)
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    for _ in 0..<120 where session.hits(of: .tom) == 0 {
      step(fight, session: session, figures: figures)
    }
    #expect(session.hits(of: .tom) == 1)
    #expect(session.hits(of: .miki) == 0 && session.hits(of: .laura) == 0)

    // Merely keeping the fight active cannot make an outside figure an eligible victim.
    let outside: [PartyMember: SIMD2<Float>] = [
      .miki: [0, -3.5], .tom: [1, -3.5], .laura: [-1, -3.5],
    ]
    var shots = 0
    for _ in 0..<240 {
      step(fight, session: session, figures: outside)
      shots += fight.shots.filter { if case .hostile = $0.side { true } else { false } }.count
    }
    #expect(shots == 0 && !session.inEncounter && session.hits(of: .tom) == 0)
  }

  @Test
  func withdrawingKeepsAUsedMagazineAndPartialHostileDamage() throws {
    let figures: [PartyMember: SIMD2<Float>] = [
      .miki: [0, 1], .tom: [6, 5], .laura: [-6, 5],
    ]
    let level = guardRange(figures: figures)
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    var discharged = false
    for frame in 0..<120 where !discharged {
      step(fight, session: session, figures: figures, fire: true, pressed: frame == 0)
      discharged = fight.shots.contains {
        if case .party = $0.side { return $0.path.strike == .body("guard") }
        return false
      }
    }
    try #require(discharged)
    let before = fight.status(for: .miki)
    #expect(before.loaded == Weapon.carbine.capacity - 1 && session.ammo == 29)

    session.fallBack()
    fight.withdraw()
    #expect(fight.status(for: .miki).loaded == before.loaded)
    #expect(!fight.status(for: .miki).isDrawn && !fight.fightUnderWay)
    #expect(session.ammo == 29 && session.defeated.isEmpty && session.beat == .alone)
    try begin(fight, session: session, level: level)
    // One real shot already landed. Four more hits leave this six-hit guard standing.
    for _ in 0..<4 { #expect(!session.hit("guard", toughness: 6)) }
    #expect(session.hit("guard", toughness: 6))
  }

  @Test
  func withdrawingCannotRefillAnEmptyMagazineOrSkipItsReload() throws {
    let figures: [PartyMember: SIMD2<Float>] = [
      .miki: [0, 1], .tom: [6, 5], .laura: [-6, 5],
    ]
    let level = guardRange(figures: figures)
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    for frame in 0..<1800 where fight.status(for: .miki).reloadRemaining == 0 {
      // Fire across the range, away from the guard, to use the magazine without ending combat.
      step(
        fight, session: session, figures: figures, facing: [1, 0], fire: true,
        pressed: frame == 0)
    }
    let before = fight.status(for: .miki)
    try #require(before.loaded == 0 && before.reloadRemaining > 0)
    let rounds = session.ammo
    session.fallBack()
    fight.withdraw()
    #expect(fight.status(for: .miki).loaded == 0)
    #expect(fight.status(for: .miki).reloadRemaining == before.reloadRemaining)
    #expect(!fight.status(for: .miki).isDrawn && session.ammo == rounds)
    try begin(fight, session: session, level: level)
    step(fight, session: session, figures: figures)
    #expect(fight.status(for: .miki).loaded == 0)
    #expect(fight.status(for: .miki).reloadRemaining < before.reloadRemaining)
    #expect(fight.status(for: .miki).reloadRemaining > 0 && session.ammo == rounds)
  }

  // MARK: - Small production-fight fixture

  /// Take the real safe route, open the depot and inspect before taking only its compatible part.
  /// Every movement frame requires no encounter, damage, ammunition use or fired weapon.
  private func collectRegulatorQuietly(in world: GameWorld, opener: PartyMember) throws -> String {
    lead(opener, in: world)
    try quietWalk(world, through: RelayRun.safeRoute)
    try quietWalk(world, through: [opener == .laura ? RelayRun.latchPoint : RelayRun.panelPoint])
    world.performAction()
    try #require(world.session.salvage.gateOpen)
    try expectQuiet(world)
    lead(.miki, in: world)
    try quietWalk(world, through: [RelayRun.gateOutside, RelayRun.gateInside])
    let task = RelayRun.salvage
    let live = try #require(task.cabinets.first { world.session.salvage.contents[$0.id] == .live })
    let right = try #require(
      task.cabinets.first { world.session.salvage.contents[$0.id] == .compatible })
    try quietWalk(world, through: [middle(live.approach)])
    world.performAction()
    #expect(world.session.salvage.known.contains(live.id))
    #expect(!world.session.salvage.emptied.contains(live.id))
    try quietWalk(world, through: [middle(right.approach)])
    world.performAction()
    #expect(world.actionName == "Take regulator")
    world.performAction()
    try expectQuiet(world)
    #expect(world.session.salvage.emptied == [right.id])
    return live.id
  }

  private func quietWalk(_ world: GameWorld, through points: [SIMD2<Float>]) throws {
    for point in points {
      var reached = false
      for _ in 0..<(60 * 90) {
        let offset = point - position(world, world.session.leader)
        if simd_length(offset) < 0.15 {
          reached = true
          break
        }
        let strength = min(1, max(0.35, simd_length(offset)))
        world.advanceParty(movement: stick(world, towards: offset) * strength, deltaTime: 1 / 60)
        try expectQuiet(world)
      }
      try #require(reached, "The safe route did not reach \(point)")
    }
  }

  private func gatherQuietly(_ world: GameWorld) throws {
    for _ in 0..<300 {
      let leader = position(world, world.session.leader)
      if world.session.party.allSatisfy({ simd_distance(position(world, $0), leader) < 4 }) {
        return
      }
      world.advanceParty(movement: .zero, deltaTime: 1 / 60)
      try expectQuiet(world)
    }
    try #require(Bool(false), "The safe route did not bring the whole party back")
  }

  private func expectQuiet(_ world: GameWorld) throws {
    try #require(!world.session.inEncounter, "The safe route entered combat")
    try #require(world.session.ammo == world.level.startingAmmo)
    try #require(world.companionShots.isEmpty)
    try #require(world.session.party.allSatisfy { world.session.hits(of: $0) == 0 })
    try #require(world.diagnostic == nil)
    for event in world.takeCombatEvents() {
      if case .fired = event { try #require(Bool(false), "A weapon fired on the safe route") }
    }
  }

  private func lead(_ member: PartyMember, in world: GameWorld) {
    for _ in 0..<3 where world.session.leader != member { world.session.cycleLeader() }
    world.advanceParty(movement: .zero, deltaTime: 1 / 60)
  }

  private func middle(_ area: PartyMotion.Box) -> SIMD2<Float> {
    (area.minimum + area.maximum) / 2
  }

  private func guardRange(figures: [PartyMember: SIMD2<Float>], windUp: Float = 60) -> Level {
    let guardSpec = Level.Hostile(
      id: "guard", name: "The guard", hiddenAt: [0, -2], standAt: [0, -2], hits: 6,
      windUp: windUp, recovery: 0.5, range: 14,
      inView: true, targetsAnyone: true, targetFromWindUp: true)
    var encounter = Level.Encounter(
      beat: .stranger,
      start: .area(PartyMotion.Box(minimum: [-3, -3], maximum: [3, 3])),
      retryAt: figures[.miki], hostiles: [guardSpec], cues: [(0, .engage(guardSpec.id))])
    encounter.guardArea = PartyMotion.Box(minimum: [-3, -3], maximum: [3, 3])
    return Level(
      id: "relay-guard-range",
      ground: .box("ground", at: [0, -0.15, 0], size: [20, 0.3, 20]),
      boxes: [], interactions: [], triggers: [], encounters: [encounter], startingAmmo: 30,
      party: [.miki, .tom, .laura], spawns: figures, heading: [0, -1],
      cameraOffset: TestYard.cameraOffset, fieldOfView: 42, opening: "A guarded route.",
      objective: "Test the boundary.", lookAround: "A boundary.", restartNote: "Restart.",
      combat: Level.Combat(fallsBack: true))
  }

  private func begin(_ fight: FightSimulation, session: GameSession, level: Level) throws {
    let encounter = try #require(level.encounters.first)
    try #require(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
  }

  @discardableResult
  private func step(
    _ fight: FightSimulation, session: GameSession, figures: [PartyMember: SIMD2<Float>],
    facing: SIMD2<Float> = [0, -1], fire: Bool = false, pressed: Bool = false
  ) -> FightSimulation.Outcome {
    fight.step(
      dt: 1 / 120, leader: figures[session.leader]!, facing: facing, aiming: true,
      fireHeld: fire, firePressed: pressed, mayDisrupt: false, signaturePressed: false,
      figures: figures, session: session)
  }
}
