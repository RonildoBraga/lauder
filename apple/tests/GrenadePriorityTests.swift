import Testing
import simd

@testable import Lauder

/// Rejected requests run the same native world, input and weapon path as an uninterrupted
/// control. No injected projectile, recharge, spin, shield or health state supplies the result.
@MainActor
struct GrenadePriorityTests {
  #if DEBUG
    @Test(arguments: [PartyMember.miki, .laura], Source.allCases)
    func anotherLeadersRejectedThrowKeepsFireAndAction(member: PartyMember, source: Source) throws {
      let trial = WorldTrial(leader: member)
      let control = WorldTrial(leader: member)
      for _ in 0..<90 {
        trial.frame(source.raw(fire: true))
        control.frame(source.raw(fire: true))
      }
      let loaded = trial.world.playtestSnapshot.weapon.loaded
      for frame in 0..<150 {
        let events = trial.frame(source.raw(fire: true, action: frame == 0, grenade: true))
        let expected = control.frame(source.raw(fire: true, action: frame == 0))
        expectSameWeapon(trial, control)
        #expect(events == expected)
      }
      #expect(trial.world.observation == trial.world.level.lookAround)
      #expect(trial.world.playtestSnapshot.weapon.loaded < loaded)
      #expect(!trial.world.playtestSnapshot.grenadeInFlight)
      #expect(trial.world.playtestSnapshot.grenadeCooldown == 0)
      #expect(trial.world.session.leader == member)
    }

    @Test
    func refusedFlightAndRechargeRequestsPreserveMinigunFireWithoutSpinningAgain() throws {
      let trial = WorldTrial(leader: .tom)
      let control = WorldTrial(leader: .tom)
      for world in [trial, control] {
        world.frame(.init(keyboardGrenade: true))
        for _ in 0..<84 { world.frame(.init(keyboardFire: true)) }
        try #require(world.world.playtestSnapshot.grenadeInFlight)
        try #require(world.world.playtestSnapshot.weapon.loaded < Weapon.minigun.capacity)
      }
      for whileFlying in [true, false] {
        if !whileFlying {
          for _ in 0..<240 where trial.world.playtestSnapshot.grenadeInFlight {
            trial.frame(.init(keyboardFire: true))
            control.frame(.init(keyboardFire: true))
          }
          try #require(!trial.world.playtestSnapshot.grenadeInFlight)
        }
        try #require(trial.world.playtestSnapshot.grenadeCooldown > 0)
        let loaded = trial.world.playtestSnapshot.weapon.loaded
        var shots = 0
        for frame in 0..<24 {
          let events = trial.frame(
            Source.keyboard.raw(fire: true, action: frame == 0, grenade: true))
          let expected = control.frame(Source.keyboard.raw(fire: true, action: frame == 0))
          expectSameWeapon(trial, control)
          #expect(events == expected)
          #expect(!events.contains { if case .spinUp = $0 { true } else { false } })
          shots +=
            events.filter { if case .fired(.minigun, _, true) = $0 { true } else { false } }.count
        }
        #expect(shots >= 2)
        #expect(loaded - trial.world.playtestSnapshot.weapon.loaded == shots)
        #expect(trial.world.observation == trial.world.level.lookAround)
        trial.frame(.init(keyboardFire: true))
        control.frame(.init(keyboardFire: true))
      }
    }

    @Test
    func refusedRequestsKeepTheRaisedDomeWithoutDownOrUpEvents() throws {
      let trial = WorldTrial(leader: .tom)
      let control = WorldTrial(leader: .tom)
      for world in [trial, control] {
        world.frame(.init(keyboardGrenade: true))
        world.frame(.init(keyboardSwap: true))
        for _ in 0..<12 { world.frame(.init(keyboardFire: true)) }
        try #require(world.world.playtestSnapshot.weapon.kind == .shieldDome)
        try #require(world.world.root.findEntity(named: "tom.shield-dome")?.isEnabled == true)
      }
      for frame in 0..<24 {
        let events = trial.frame(Source.keyboard.raw(fire: true, action: frame == 0, grenade: true))
        let expected = control.frame(Source.keyboard.raw(fire: true, action: frame == 0))
        expectSameWeapon(trial, control)
        #expect(events == expected)
        #expect(!events.contains { if case .dome = $0 { true } else { false } })
        #expect(trial.world.root.findEntity(named: "tom.shield-dome")?.isEnabled == true)
      }
      #expect(trial.world.observation == trial.world.level.lookAround)
    }

    @Test(arguments: Source.allCases)
    func anAcceptedSubstepThrowTakesFireAndActionAndCannotRepeatWhileHeld(source: Source) throws {
      let trial = WorldTrial(leader: .tom)
      for _ in 0..<90 { trial.frame(source.raw(fire: true)) }
      let loaded = trial.world.playtestSnapshot.weapon.loaded
      let opening = trial.world.observation
      let events = trial.frame(source.raw(fire: true, action: true, grenade: true), dt: 1 / 1000)
      #expect(events.isEmpty && !trial.world.playtestSnapshot.grenadeInFlight)
      #expect(trial.world.observation == opening)
      let launched = trial.frame(source.raw(fire: true, action: true, grenade: true), dt: 1 / 60)
      try #require(trial.world.playtestSnapshot.grenadeInFlight)
      #expect(!launched.contains { if case .fired = $0 { true } else { false } })
      #expect(trial.world.playtestSnapshot.weapon.loaded == loaded)
      #expect(trial.world.observation == opening)
      var previous = trial.world.playtestSnapshot.grenadeCooldown
      for _ in 0..<120 * 9 {
        trial.frame(source.raw(grenade: true))
        let current = trial.world.playtestSnapshot.grenadeCooldown
        #expect(current <= previous)
        previous = current
      }
      #expect(!trial.world.playtestSnapshot.grenadeInFlight && previous == 0)
      trial.frame()
      trial.frame(source.raw(grenade: true))
      #expect(trial.world.playtestSnapshot.grenadeInFlight)
    }

    @Test
    func aRejectedSubstepRequestCannotWaitForRechargeToFinish() throws {
      let trial = WorldTrial(leader: .tom)
      trial.frame(.init(keyboardGrenade: true))
      for _ in 0..<120 * 9 {
        let remaining = trial.world.playtestSnapshot.grenadeCooldown
        if remaining > 0 && remaining < 0.02 { break }
        trial.frame()
      }
      try #require(trial.world.playtestSnapshot.grenadeCooldown > 0)
      try #require(trial.world.playtestSnapshot.grenadeCooldown < 0.02)
      trial.frame(Source.keyboard.raw(fire: true, action: true, grenade: true), dt: 1 / 1000)
      #expect(trial.world.observation == trial.world.level.lookAround)
      trial.frame(Source.keyboard.raw(fire: true, grenade: true), dt: 1 / 30)
      #expect(trial.world.playtestSnapshot.grenadeCooldown == 0)
      #expect(!trial.world.playtestSnapshot.grenadeInFlight)
    }

    @Test
    func aRequestDuringARollKeepsOtherwiseValidActionAndCannotBankAThrow() throws {
      let trial = WorldTrial(leader: .tom)
      let control = WorldTrial(leader: .tom)
      for world in [trial, control] {
        world.frame(.init(keyboardDodge: true))
        world.frame()
        try #require(world.world.roll != nil)
      }
      for frame in 0..<120 {
        let events = trial.frame(Source.keyboard.raw(fire: true, action: frame == 0, grenade: true))
        let expected = control.frame(Source.keyboard.raw(fire: true, action: frame == 0))
        expectSameWeapon(trial, control)
        #expect(events == expected)
        #expect(!trial.world.playtestSnapshot.grenadeInFlight)
      }
      #expect(trial.world.roll == nil && trial.world.observation == trial.world.level.lookAround)
      #expect(trial.world.playtestSnapshot.grenadeCooldown == 0)
    }

    @Test
    func aScriptedHoldCannotBankARejectedRequestOrChangeTheExistingCombatGate() throws {
      var level = TestRange.practice
      level.encounters = [
        .init(
          beat: .stranger, start: .area(level.bounds), retryAt: nil, hostiles: [],
          cues: [(2, .say(speaker: "Tom", line: "Ready."))], holdsParty: true)
      ]
      let trial = WorldTrial(leader: .tom, level: level)
      let control = WorldTrial(leader: .tom, level: level)
      try #require(trial.world.session.inEncounter)
      var shots = 0
      for frame in 0..<120 * 3 {
        let events = trial.frame(Source.keyboard.raw(fire: true, action: frame == 0, grenade: true))
        let expected = control.frame(Source.keyboard.raw(fire: true, action: frame == 0))
        expectSameWeapon(trial, control)
        #expect(events == expected)
        #expect(!trial.world.playtestSnapshot.grenadeInFlight)
        shots +=
          events.filter { if case .fired(.minigun, _, true) = $0 { true } else { false } }.count
      }
      // Fire's fresh edge was consumed while the hold made combat unavailable. It cannot
      // draw a holstered weapon later until the player releases and presses again.
      #expect(!trial.world.session.inEncounter && shots == 0)
      trial.frame(.init(keyboardGrenade: true))
      control.frame()
      for _ in 0..<84 {
        let events = trial.frame(Source.keyboard.raw(fire: true, grenade: true))
        let expected = control.frame(.init(keyboardFire: true))
        expectSameWeapon(trial, control)
        #expect(events == expected)
        shots +=
          events.filter {
            if case .fired(.minigun, _, true) = $0 { true } else { false }
          }.count
      }
      #expect(shots > 0)
      #expect(trial.world.playtestSnapshot.grenadeCooldown == 0)
      trial.frame()
      trial.frame(.init(keyboardGrenade: true))
      #expect(trial.world.playtestSnapshot.grenadeInFlight)
    }

    private func expectSameWeapon(_ trial: WorldTrial, _ control: WorldTrial) {
      let actual = trial.world.playtestSnapshot.weapon
      let expected = control.world.playtestSnapshot.weapon
      #expect(actual.kind == expected.kind && actual.loaded == expected.loaded)
      #expect(actual.reloadRemaining == expected.reloadRemaining)
      #expect(
        actual.isDrawn == expected.isDrawn && actual.shieldRemaining == expected.shieldRemaining)
      #expect(
        trial.world.playtestSnapshot.grenadeCooldown
          == control.world.playtestSnapshot.grenadeCooldown)
    }

    @MainActor
    private final class WorldTrial {
      let world: GameWorld

      init(leader: PartyMember, level: Level = TestRange.practice) {
        world = GameWorld(level: level)
        for _ in 0..<3 { frame() }
        while world.session.leader != leader {
          frame(.init(keyboardSwitch: true))
          frame()
        }
        _ = world.takeCombatEvents()
      }

      @discardableResult
      func frame(_ raw: InputRules.Raw = .init(), dt: Float = 1 / 120) -> [CombatEvent] {
        let mode = world.session.mode
        world.update(with: world.controls.resolve(raw, mode: mode), sampledIn: mode, deltaTime: dt)
        return world.takeCombatEvents()
      }
    }
  #endif

  @Test
  func actualLaunchAlsoSuppressesSimultaneousNativeFire() throws {
    let level = TestRange.practice
    let session = GameSession(level: level)
    session.cycleLeader()
    let fight = EncounterSimulation(level: level)
    func step(throwing: Bool = false) {
      _ = fight.step(
        dt: 1 / 120, leader: level.spawn(.tom), facing: [0, -1], aiming: true,
        fireHeld: true, firePressed: true, figures: level.spawns, session: session,
        grenadePressed: throwing)
    }
    for _ in 0..<90 { step() }
    let loaded = fight.status(for: .tom).loaded
    try #require(loaded < Weapon.minigun.capacity && fight.canThrowGrenade(by: .tom))
    _ = fight.takeEvents()
    step(throwing: true)
    #expect(fight.grenade != nil && fight.shots.isEmpty)
    #expect(fight.status(for: .tom).loaded == loaded)
    #expect(!fight.canThrowGrenade(by: .tom))
    #expect(!fight.takeEvents().contains { if case .fired = $0 { true } else { false } })
  }

  enum Source: CaseIterable, Sendable {
    case keyboard, controller, touch

    func raw(fire: Bool = false, action: Bool = false, grenade: Bool = false) -> InputRules.Raw {
      var raw = InputRules.Raw()
      switch self {
      case .keyboard:
        raw.keyboardFire = fire
        raw.keyboardAction = action
        raw.keyboardGrenade = grenade
      case .controller:
        raw.controllerFire = fire
        raw.controllerAction = action
        raw.controllerGrenade = grenade
      case .touch:
        raw.touchFire = fire
        raw.touchAction = action
        raw.touchGrenade = grenade
      }
      return raw
    }
  }
}
