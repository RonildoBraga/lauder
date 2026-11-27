import Testing
import simd

@testable import Lauder

/// Each traveller carries two weapons and switches between them (ADR 0021): Miki a long rifle
/// and an assault rifle, Laura a shotgun and an energy sword, Tom a minigun and a shield dome.
/// Rounds are not counted beyond each magazine.
@MainActor
struct PairedWeaponTests {
  private let dt: Float = 1 / 120

  // MARK: - The pairs and the switch

  @Test
  func eachTravellerCarriesTwoWeaponsAndStartsWithTheFirst() {
    #expect(Weapon.pair(for: .miki).map(\.kind) == [.longRifle, .assaultRifle])
    #expect(Weapon.pair(for: .laura).map(\.kind) == [.shotgun, .energySword])
    #expect(Weapon.pair(for: .tom).map(\.kind) == [.minigun, .shieldDome])
    let fight = EncounterSimulation(level: TestRange.practice)
    for member in PartyMember.allCases {
      #expect(fight.weapon(of: member).kind == Weapon.pair(for: member)[0].kind)
      #expect(fight.otherWeapon(of: member).kind == Weapon.pair(for: member)[1].kind)
    }
  }

  /// The switch brings the other weapon into hand, drawn after its own draw time if the first
  /// was drawn, and each keeps its magazine.
  @Test
  func theSwitchKeepsEachMagazine() throws {
    let level = range()
    let session = GameSession(level: level)
    let fight = EncounterSimulation(level: level)
    try begin(fight, session: session, level: level)
    var fired = 0
    for frame in 0..<(120 * 3) where fired < 2 {
      step(fight, session: session, level: level, fire: true, pressed: frame == 0)
      fired += partyShots(fight)
    }
    #expect(fired == 2 && fight.status(for: .miki).loaded == Weapon.longRifle.capacity - 2)
    fight.swapWeapon(for: .miki)
    #expect(fight.leaderWeapon.kind == .assaultRifle && fight.isDrawn)
    #expect(fight.status(for: .miki).loaded == Weapon.assaultRifle.capacity)
    fight.swapWeapon(for: .miki)
    #expect(fight.status(for: .miki).loaded == Weapon.longRifle.capacity - 2)
  }

  /// R1, RB, T or the touch Swap button reaches the world as one switch, and the status names
  /// the weapon in hand and offers the other.
  @Test
  func aSwitchPressChangesTheWeaponInHand() {
    let world = GameWorld(level: TestRange.practice)
    world.advanceParty(movement: .zero, deltaTime: 1 / 60)
    #expect(world.weaponStatus.hasPrefix("Long rifle") && world.otherWeaponName == "Assault rifle")
    var press = InputRules.Input.neutral
    press.swapPressed = true
    world.update(with: press, sampledIn: .exploring, deltaTime: 1 / 60)
    #expect(world.weaponStatus.hasPrefix("Assault rifle") && world.otherWeaponName == "Long rifle")
    #expect(world.weaponKind == .assaultRifle)
  }

  // MARK: - Miki

  @Test
  func theLongRifleDealsItsConfiguredDamagePerShot() throws {
    let level = range(hits: Weapon.longRifle.damage)
    let session = GameSession(level: level)
    let fight = EncounterSimulation(level: level)
    try begin(fight, session: session, level: level)
    var fired = 0
    for frame in 0..<240 where fired == 0 {
      step(fight, session: session, level: level, fire: true, pressed: frame == 0)
      fired += partyShots(fight)
    }
    #expect(fired == 1 && session.defeated == ["target"])
  }

  /// The assault rifle fires about ten rounds a second while Fire is held, and its magazine
  /// reloads by itself: a long fight never runs out.
  @Test
  func theAssaultRifleFiresRapidlyAndNeverRunsOut() throws {
    let level = range()
    let session = GameSession(level: level)
    let fight = EncounterSimulation(level: level)
    try begin(fight, session: session, level: level)
    fight.swapWeapon(for: .miki)
    var fired = 0
    var lines: [String] = []
    for frame in 0..<(120 * 7) {
      let outcome = step(fight, session: session, level: level, fire: true, pressed: frame == 0)
      fired += partyShots(fight)
      if let line = outcome.line { lines.append(line) }
      if frame == 120 + 36 { #expect(fired >= 9, "rapid fire after the draw") }
    }
    #expect(fired > Weapon.assaultRifle.capacity + 10, "it reloads and fires on")
    #expect(!lines.contains("Out of ammunition."))
  }

  // MARK: - Tom

  /// Once drawn, the minigun spins for half a second before its first shot, and Tom walks more
  /// slowly while it runs.
  @Test
  func theMinigunSpinsUpThenFiresWhileTomSlows() throws {
    let level = range()
    let session = GameSession(level: level)
    session.cycleLeader()
    let fight = EncounterSimulation(level: level)
    try begin(fight, session: session, level: level)
    for _ in 0..<120 { step(fight, session: session, level: level, aiming: true) }
    #expect(fight.isDrawn && fight.leaderWalking == 1)
    var firstShot: Int?
    for frame in 0..<120 {
      step(fight, session: session, level: level, fire: true)
      if firstShot == nil, partyShots(fight) > 0 { firstShot = frame }
    }
    let frame = try #require(firstShot)
    #expect(Float(frame) * dt >= Weapon.minigun.spinUp - 2 * dt)
    #expect(fight.leaderWalking == Weapon.minigun.walking)
  }

  /// The minigun's spin-up is heard once each time Fire is held, from Tom (#162).
  @Test
  func theMinigunsSpinUpIsHeardOncePerHold() {
    let level = range()
    let session = GameSession(level: level)
    session.cycleLeader()
    let fight = EncounterSimulation(level: level)
    for _ in 0..<120 { step(fight, session: session, level: level, aiming: true) }
    _ = fight.takeEvents()
    var heard: [CombatEvent] = []
    func listen() {
      heard += fight.takeEvents().filter { if case .spinUp = $0 { true } else { false } }
    }
    for _ in 0..<120 {
      step(fight, session: session, level: level, fire: true)
      listen()
    }
    #expect(heard == [.spinUp(at: level.spawn(.tom), byLeader: true)])
    for _ in 0..<12 {
      step(fight, session: session, level: level)
      listen()
    }
    for _ in 0..<12 {
      step(fight, session: session, level: level, fire: true)
      listen()
    }
    #expect(heard.count == 2, "a fresh hold spins it up again")
  }

  /// Each change of Tom's dome is heard once: raised, running down, run out while held,
  /// recharged in his hands, then raised and let go with charge left (#162).
  @Test
  func eachChangeOfTomsDomeIsHeardOnce() {
    let level = range()
    let session = GameSession(level: level)
    session.cycleLeader()
    let fight = EncounterSimulation(level: level)
    step(fight, session: session, level: level)
    fight.swapWeapon(for: .tom)
    _ = fight.takeEvents()
    var heard: [CombatEvent.DomeChange] = []
    func listen() {
      for case .dome(let change, _) in fight.takeEvents() { heard.append(change) }
    }
    for _ in 0..<Int((ShieldDome.duration + 0.5) * 120) {
      step(fight, session: session, level: level, fire: true)
      listen()
    }
    #expect(heard == [.raised, .fading, .collapsed])
    heard = []
    for _ in 0..<Int((ShieldDome.rechargeDelay + ShieldDome.rechargeTime + 0.5) * 120) {
      step(fight, session: session, level: level)
      listen()
    }
    #expect(heard == [.recharged])
    heard = []
    for _ in 0..<60 {
      step(fight, session: session, level: level, fire: true)
      listen()
    }
    step(fight, session: session, level: level)
    listen()
    #expect(heard == [.raised, .lowered])
  }

  /// Held, Tom's dome stops the shooter's shots for everyone inside it, Laura between Tom and
  /// the shooter included, while he walks slowly. Let go, the next shots get through.
  @Test
  func tomsDomeStopsShotsForEveryoneInsideIt() throws {
    let spawns: [PartyMember: SIMD2<Float>] = [.tom: [0, 3], .laura: [0, 1.6], .miki: [6, 3]]
    let level = range(shooter: true, spawns: spawns)
    let session = GameSession(level: level)
    session.cycleLeader()
    let fight = EncounterSimulation(level: level)
    try begin(fight, session: session, level: level)
    fight.swapWeapon(for: .tom)
    var stopped = 0
    for _ in 0..<(120 * 5) {
      step(fight, session: session, level: level, fire: true)
      stopped +=
        fight.takeEvents().filter { if case .struckBlock = $0 { true } else { false } }
        .count
    }
    #expect(fight.shieldIsUp && fight.leaderWalking == Weapon.shieldDome.walking)
    #expect(stopped > 0, "the shooter fired at the dome")
    #expect(session.hits(of: .tom) == 0 && session.hits(of: .laura) == 0)
    for _ in 0..<(120 * 8) where session.hits(of: .laura) == 0 {
      step(fight, session: session, level: level)
    }
    #expect(!fight.shieldIsUp && session.hits(of: .laura) > 0, "without the dome, shots land")
  }

  /// The dome lasts six seconds of holding, stays down until Fire is let go, then recharges.
  @Test
  func theDomeRunsDownThenRecharges() {
    var dome = ShieldDome()
    for _ in 0..<Int(ShieldDome.duration * 120) - 2 { dome.step(dt: dt, held: true) }
    #expect(dome.isUp)
    for _ in 0..<4 { dome.step(dt: dt, held: true) }
    #expect(!dome.isUp && dome.remaining == 0)
    for _ in 0..<240 { dome.step(dt: dt, held: true) }
    #expect(!dome.isUp, "held on, it stays down")
    for _ in 0..<Int((ShieldDome.rechargeDelay + ShieldDome.rechargeTime) * 120) + 4 {
      dome.step(dt: dt, held: false)
    }
    #expect(dome.remaining == ShieldDome.duration)
    dome.step(dt: dt, held: true)
    #expect(dome.isUp)
  }

  // MARK: - Laura

  /// A swing strikes the actual body within reach in front of her, while an equally close
  /// body behind her remains unharmed. The leg/navigation envelope alone is not a contact.
  @Test
  func theSwordStrikesInFrontWithinReach() throws {
    let spawns: [PartyMember: SIMD2<Float>] = [.laura: [0, 2], .miki: [-6, 6], .tom: [6, 6]]
    let ahead = robot("ahead", at: [0, -0.6], hits: Weapon.energySword.damage)
    let behind = robot("behind", at: [0, 4.6], hits: Weapon.energySword.damage)
    let level = range(hostiles: [ahead, behind], spawns: spawns)
    let session = GameSession(level: level)
    session.cycleLeader()
    session.cycleLeader()
    let fight = EncounterSimulation(level: level)
    try begin(fight, session: session, level: level)
    fight.swapWeapon(for: .laura)
    for target in [ahead, behind] {
      let gap = simd_distance(level.spawn(.laura), target.standAt)
      #expect(gap > RobotModelGeometry.bodyRadius + PartyBody.radius)
      #expect(gap < Weapon.energySword.range + RobotModelGeometry.bodyRadius)
    }
    var hits: [DamageHit] = []
    var swings = 0
    for frame in 0..<120 where swings == 0 {
      step(
        fight, session: session, level: level, fire: true, pressed: frame == 0, facing: [0, -1])
      for event in fight.takeEvents() {
        if case .fired(.energySword, _, true) = event { swings += 1 }
        if case .damaged(let hit) = event { hits.append(hit) }
      }
    }
    #expect(swings == 1)
    #expect(session.defeated == ["ahead"], "one genuine in-range swing hits only the front body")
    #expect(hits.count == 1)
    #expect(hits.first?.target == "ahead" && hits.first?.amount == Weapon.energySword.damage)
    #expect(hits.first?.attacker == .laura && hits.first?.effectiveness == .normal)
    #expect(session.remainingHealth(of: "behind", toughness: behind.hits) == behind.hits)
    #expect(fight.status(for: .laura).loaded == Weapon.energySword.capacity)
  }

  /// With the sword drawn, a shot from in front of Laura glances off it; facing away, it lands.
  @Test
  func theSwordTurnsShotsFromInFrontOnly() throws {
    let spawns: [PartyMember: SIMD2<Float>] = [.laura: [0, 2], .miki: [-6, 6], .tom: [6, 6]]
    let level = range(shooter: true, spawns: spawns)
    let session = GameSession(level: level)
    session.cycleLeader()
    session.cycleLeader()
    let fight = EncounterSimulation(level: level)
    try begin(fight, session: session, level: level)
    fight.swapWeapon(for: .laura)
    var stopped = 0
    for _ in 0..<(120 * 5) {
      step(fight, session: session, level: level, aiming: true, facing: [0, -1])
      stopped +=
        fight.takeEvents().filter { if case .struckBlock = $0 { true } else { false } }
        .count
    }
    #expect(fight.isDrawn && stopped > 0 && session.hits(of: .laura) == 0)
    for _ in 0..<(120 * 8) where session.hits(of: .laura) == 0 {
      step(fight, session: session, level: level, aiming: true, facing: [0, 1])
    }
    #expect(session.hits(of: .laura) > 0, "from behind, the shot lands")
  }

  // MARK: - Helpers

  private func begin(_ fight: EncounterSimulation, session: GameSession, level: Level) throws {
    let encounter = try #require(level.encounters.first)
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    step(fight, session: session, level: level)
  }

  @discardableResult
  private func step(
    _ fight: EncounterSimulation, session: GameSession, level: Level, fire: Bool = false,
    pressed: Bool = false, aiming: Bool = false, facing: SIMD2<Float>? = nil
  ) -> EncounterSimulation.Outcome {
    let leader = level.spawn(session.leader)
    let target = level.encounters[0].hostiles[0].standAt
    let towards = simd_length(target - leader) > 0.001 ? simd_normalize(target - leader) : [0, -1]
    return fight.step(
      dt: dt, leader: leader, facing: facing ?? towards, aiming: aiming || fire,
      fireHeld: fire, firePressed: pressed, figures: level.spawns, session: session)
  }

  private func partyShots(_ fight: EncounterSimulation) -> Int {
    fight.shots.filter { if case .party = $0.side { true } else { false } }.count
  }

  private func robot(_ id: String, at point: SIMD2<Float>, hits: Int = 3) -> Level.Hostile {
    Level.Hostile(
      id: id, name: id, hiddenAt: point, standAt: point, hits: hits, attack: .robot, range: 12)
  }

  /// An open range with one target in front of the party: a guard robot that is a target at
  /// once, or a shooter that keeps firing at the leader.
  private func range(
    hits: Int = 500, shooter: Bool = false, hostiles: [Level.Hostile]? = nil,
    spawns: [PartyMember: SIMD2<Float>] = [.miki: [0, 2], .tom: [-0.9, 2.9], .laura: [0.9, 2.9]]
  ) -> Level {
    let hostiles =
      hostiles
      ?? [
        shooter
          ? Level.Hostile(
            id: "target", name: "Shooter", hiddenAt: [0, -8], standAt: [0, -8], hits: hits,
            attack: .shoot,
            windUp: 0.3, recovery: 0.3, range: 14)
          : robot("target", at: [0, -8], hits: hits)
      ]
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(PartyMotion.Box(minimum: [-15, -15], maximum: [15, 15])),
      retryAt: spawns[.miki], hostiles: hostiles,
      cues: hostiles.flatMap {
        [(at: Float(0), cue: .reveal($0.id)), (at: 0, cue: .engage($0.id))]
      })
    return Level(
      id: "paired-weapon-range",
      ground: .box("ground", at: [0, -0.15, 0], size: [30, 0.3, 30]), boxes: [], triggers: [],
      encounters: [encounter], party: [.miki, .tom, .laura], spawns: spawns, heading: [0, -1],
      cameraOffset: TestYard.cameraOffset, fieldOfView: 42,
      opening: "A range.", objective: "Test.", lookAround: "Snow.", restartNote: "Restart.")
  }
}
