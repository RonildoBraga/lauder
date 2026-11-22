import RealityKit
import Testing
import simd

@testable import Lauder

/// ADR 0005: the combat yard, a greybox venue for the first squad combat experiment that the
/// pause menu reaches, and the yard's own rules for a fight. The bridge keeps the opening's.
@MainActor
struct CombatYardTests {
  // MARK: - The venue

  @Test
  func theYardIsAGreyboxUnderTheBridgesCameraWithItsShootersOutOfSight() throws {
    let yard = CombatYard.level
    #expect(yard.id == "combat-yard" && yard.scene == nil)
    #expect(yard.party == [.miki, .tom, .laura])
    #expect(yard.cameraOffset == BrooklynBridge.layout.camera.offset)
    #expect(yard.fieldOfView == BrooklynBridge.layout.camera.fieldOfView)
    #expect(yard.lights.map(\.name) == BrooklynBridge.layout.lights.map(\.name))
    // One full-height wall, two party blocks and a low shelter for the cover shooter.
    #expect(yard.boxes.count == 4)
    #expect(yard.boxes.filter { $0.size.y > PartyBody.height }.count == 1)
    // Everything lies within the 19 m that the camera shows ahead of the entrance.
    let entrance = yard.spawn(.miki)
    func ahead(_ point: SIMD2<Float>) -> Float { simd_dot(point - entrance, yard.heading) }
    for box in yard.boxes {
      #expect(ahead(box.footprint.minimum) < 19 && ahead(box.footprint.maximum) < 19, "\(box.name)")
    }
    let obstacles = yard.obstacles
    for shooter in CombatYard.fight.hostiles {
      #expect(ahead(shooter.standAt) < 19, "\(shooter.id)")
      #expect(shooter.inView && shooter.targetsAnyone && shooter.targetFromWindUp)
      // In view beyond the wall, but out of everyone's clear sight at the start.
      for member in PartyMember.allCases {
        #expect(
          !LineOfSight.isClear(from: yard.spawn(member), to: shooter.standAt, obstacles: obstacles),
          "\(member.rawValue) sees \(shooter.id)")
      }
    }
    // Everyone starts clear of the scenery, in the Close formation behind Miki.
    func clearance(_ point: SIMD2<Float>, _ box: PartyMotion.Box) -> Float {
      simd_distance(point, simd_clamp(point, box.minimum, box.maximum))
    }
    for member in PartyMember.allCases {
      let spawn = yard.spawn(member)
      #expect(yard.bounds.contains(spawn))
      #expect(obstacles.allSatisfy { clearance(spawn, $0) >= PartyBody.radius + PartyMotion.skin })
    }
    #expect(simd_distance(yard.spawn(.laura), entrance + [-0.9, 0.9]) < 0.01)
    #expect(simd_distance(yard.spawn(.tom), entrance + [0.9, 0.9]) < 0.01)
    // Combat positioning is the yard's, and not the opening's.
    #expect(yard.combat.combatPositioning && !BrooklynBridge.level.combat.combatPositioning)
  }

  @Test
  func theYardStartsWithTheWholeTrioAndItsShootersInView() throws {
    let world = GameWorld(level: CombatYard.level)
    for member in PartyMember.allCases {
      #expect(try #require(world.root.findEntity(named: "party.\(member.rawValue)")).isEnabled)
    }
    for shooter in CombatYard.fight.hostiles {
      #expect(try #require(world.root.findEntity(named: "hostile.\(shooter.id)")).isEnabled)
    }
    #expect(world.session.nextLeader == .tom && world.session.formationsAvailable)
    #expect(world.objective == "Clear the yard." && world.session.ammo == 60)
    #expect(world.compass == nil)
  }

  // MARK: - The pause menu's third choice

  @Test
  func thePauseMenusThirdChoiceCyclesThroughTheLevels() throws {
    let game = Game()
    let bridge = game.world
    #expect(bridge.level.id == BrooklynBridge.level.id && bridge.otherLevel.name == "Combat test")
    #if DEBUG
      // A scripted playtest carries over to the new world.
      bridge.startPlaytest("combat-yard")
    #endif
    // So does a hidden status panel.
    press(InputRules.Raw(controllerPanel: true), in: bridge)
    #expect(bridge.panelHidden)
    choose(.otherLevel, in: bridge)
    let yard = game.world
    #expect(yard !== bridge && yard.level.id == CombatYard.level.id)
    #expect(yard.otherLevel.name == "Salvage test" && yard.panelHidden)
    #if DEBUG
      #expect(yard.playtest != nil && bridge.playtest == nil)
    #endif
    #expect(yard.session.mode == .exploring && yard.session.party == [.miki, .tom, .laura])
    #expect(yard.controls.needsNeutralInput)
    // Restart in the yard begins the yard again, in the same world.
    walk(yard, to: [0, 3])
    choose(.restart, in: yard)
    #expect(game.world === yard)
    #expect(position(yard, .miki) == CombatYard.level.spawn(.miki))
    // The third choice goes on to the salvage yard (ADR 0006), and from there the touch button
    // for it returns to a new run of the opening.
    choose(.otherLevel, in: yard)
    let salvage = game.world
    #expect(salvage !== yard && salvage.level.id == SalvageYard.level.id)
    #expect(salvage.otherLevel.name == "Relay mission")
    pressPause(salvage)
    salvage.update(
      with: InputRules.Input(
        movement: .zero, actionPressed: false, pausePressed: false, switchPressed: false,
        otherLevelPressed: true),
      sampledIn: .paused, deltaTime: 1 / 60)
    let relay = game.world
    #expect(relay.level.id == RelayRun.level.id && relay.otherLevel.name == "Bridge")
    choose(.otherLevel, in: relay)
    let opening = game.world
    #expect(
      opening !== salvage && opening !== bridge && opening.level.id == BrooklynBridge.level.id)
    #expect(opening.session.beat == .alone && opening.session.party == [.miki])
    #expect(position(opening, .miki) == BrooklynBridge.level.spawn(.miki))
  }

  // MARK: - The shooters

  @Test
  func shootersAimAtAnyoneInSightAndAreTargetsFromTheirFirstWindUp() {
    var shooter = HostileState(spec: CombatYard.rightShooter)
    #expect(shooter.isVisible && shooter.phase == .waiting && !shooter.isTargetable)
    shooter.engage()
    #expect(!shooter.isTargetable)
    _ = shooter.step(dt: CombatYard.rightShooter.reactionDelay + 0.001, canHit: true, toward: .zero)
    #expect(shooter.isTargetable)
    // Laura alone stands in the open, with Miki and Tom behind the wall.
    let world = GameWorld(
      level: range(
        spawns: [.miki: [-3.5, 2], .tom: [-4.5, 2.9], .laura: [3, 2]],
        shooters: [Shooter(id: "a", at: [0, -8])]))
    #expect(world.session.holdAll())
    #expect(run(world, upTo: 1) { world.threat == "Shooter A is aiming at Laura." })
    // A target from its first wind-up, it is answered before it shoots: Laura fires.
    #expect(run(world, upTo: 1.4) { world.companionShots[.laura, default: 0] > 0 })
    #expect(world.session.hits(of: .laura) == 0)
    // Its shot hits her, not the leader.
    #expect(run(world, upTo: 1.5) { world.session.hits(of: .laura) == 1 })
    #expect(world.session.hitsTaken == 0 && world.session.hits(of: .tom) == 0)
  }

  // MARK: - The companions' fire

  @Test
  func companionsNeverStartAFight() {
    // All three in the open; the shooter begins to aim four seconds into each fight.
    let world = GameWorld(
      level: range(
        spawns: [.miki: [3, 2], .tom: [3.9, 2.9], .laura: [2.1, 2.9]],
        shooters: [Shooter(id: "a", at: [0, -8], engageAt: 4)]))
    // Until it aims, nobody knows it is hostile, and nobody fires.
    #expect(!run(world, upTo: 3.5) { world.companionShots[.laura, default: 0] > 0 })
    // Its wind-up puts the fight under way, and Laura, in reach, fires by herself.
    #expect(run(world, upTo: 2) { world.companionShots[.laura, default: 0] > 0 })
    // Miki, nearest, takes three hits, and the party falls back.
    #expect(run(world, upTo: 10) { world.isRetrying })
    #expect(run(world, upTo: 1.5) { !world.isRetrying })
    // At the entrance the fight begins again at once. The shooter is still a target in Laura's
    // sight and reach, but until it aims again, or Miki fires, she holds her fire.
    let shots = world.companionShots[.laura, default: 0]
    #expect(!run(world, upTo: 2.5) { world.companionShots[.laura, default: 0] > shots })
    #expect(world.threat == nil)
    // Miki's first shot puts the fight under way again, before the shooter aims.
    #expect(run(world, upTo: 1.4, fire: true) { world.companionShots[.laura, default: 0] > shots })
    #expect(world.threat == nil)
  }

  // MARK: - Falling back

  @Test
  func aThirdHitOnAnyoneFallsThePartyBackAndTheShootersKeepTheirDamage() throws {
    // Miki in the open; the others hold behind the wall, out of the shooters' sight.
    let level = range(
      spawns: [.miki: [3, 2], .tom: [-5, 2.9], .laura: [-4, 2.9]],
      shooters: [
        Shooter(id: "a", at: [2, -6], hits: 1), Shooter(id: "b", at: [-0.5, -8], hits: 4),
      ]
    )
    let world = GameWorld(level: level)
    let entities = count(world.root)
    #expect(world.session.holdAll())
    // Miki puts the nearer one down, then hits the other twice and stops.
    #expect(run(world, upTo: 2, fire: true) { world.session.defeated == ["a"] })
    #expect(run(world, upTo: 2, fire: true) { world.session.ammo == 57 })
    // The other hits her three times.
    #expect(run(world, upTo: 9) { world.isRetrying })
    #expect(world.session.hitsTaken == GameSession.hitsAllowed)
    #expect(run(world, upTo: 1.5) { !world.isRetrying })
    // The whole party is back at the entrance, everyone's hits recovered and nobody holding.
    #expect(world.fallBacks == 1 && world.observation == "The party falls back to the entrance.")
    for member in PartyMember.allCases {
      #expect(simd_distance(position(world, member), level.spawn(member)) < 0.01)
      #expect(world.session.hits(of: member) == 0)
    }
    #expect(world.session.orders.isEmpty && !world.session.inEncounter)
    #expect(world.threat == nil && !world.weaponDrawn && count(world.root) == entities)
    // Nothing else is undone: the first stays down, the rounds stay spent, and the other waits.
    #expect(world.session.defeated == ["a"] && world.session.ammo == 57)
    #expect(try #require(world.root.findEntity(named: "hostile.b")).isEnabled)
    // It keeps the two hits dealt: two more rounds put it down.
    #expect(world.session.holdAll())
    #expect(run(world, upTo: 2, fire: true) { world.session.defeated.contains("b") })
    #expect(world.session.ammo == 55 && !world.session.inEncounter)
  }

  // MARK: - Disrupt

  @Test
  func disruptCancelsAWindUpOnlyWhileMikiLeads() {
    let world = GameWorld(
      level: range(
        spawns: [.miki: [3, 2], .tom: [-5, 2.9], .laura: [-4, 2.9]],
        shooters: [Shooter(id: "a", at: [0, -8])]))
    #expect(world.session.holdAll())
    #expect(run(world, upTo: 1) { world.signatureCue == "Miki can Disrupt" })
    #expect(world.showsSignature && world.threat == "Shooter A is aiming at Miki.")
    press(InputRules.Raw(controllerSignature: true), in: world)
    #expect(world.disrupts == 1 && world.threat == nil && world.signatureCue == nil)
    #expect(world.observation == "Shooter A's shot is disrupted.")
    // Its shot never comes: it recovers, then aims again.
    #expect(!run(world, upTo: 1.2) { world.threat != nil })
    #expect(world.session.hitsTaken == 0)
    #expect(run(world, upTo: 1) { world.threat != nil })
    // With Tom leading nobody can Disrupt: the press does nothing, and the shot hits Miki, who
    // holds where she stood.
    press(InputRules.Raw(controllerSwitch: true), in: world)
    #expect(world.session.leader == .tom && !world.showsSignature && world.signatureCue == nil)
    press(InputRules.Raw(keyboardSignature: true), in: world)
    #expect(world.disrupts == 1)
    #expect(run(world, upTo: 2) { world.session.hits(of: .miki) == 1 })
  }

  @Test
  func disruptNeedsTheWindUpInMikisReachAndSight() {
    // Out of her reach, 16 m away, and out of her sight, behind the wall.
    for miki: SIMD2<Float> in [[3, 8], [-3.5, 2]] {
      let world = GameWorld(
        level: range(
          spawns: [.miki: miki, .tom: [-5, 2.9], .laura: [-4, 2.9]],
          shooters: [Shooter(id: "a", at: [0, -8])]))
      #expect(world.session.holdAll())
      #expect(run(world, upTo: 1) { world.threat != nil })
      #expect(world.showsSignature && world.signatureCue == nil)
      press(InputRules.Raw(touchSignature: true), in: world)
      #expect(world.disrupts == 0 && world.threat != nil)
    }
  }

  // MARK: - The bridge keeps the opening's fights

  @Test
  func theBridgeKeepsTheOpeningsRules() {
    let rules = BrooklynBridge.level.combat
    #expect(rules.companionWeapons.isEmpty && !rules.fallsBack && !rules.disrupt)
    for hostile in BrooklynBridge.level.encounters.flatMap(\.hostiles) {
      #expect(!hostile.inView && !hostile.targetsAnyone && !hostile.targetFromWindUp)
    }
    // During the stranger's wind-up nobody can Disrupt, and a Signature press changes nothing:
    // his deliberate miss still comes, and only Miki is hit afterwards.
    let world = GameWorld(level: BrooklynBridge.level)
    walk(world, to: [6.5, 15])
    #expect(run(world, upTo: 4) { world.threat != nil })
    #expect(world.signatureCue == nil && !world.showsSignature && !world.showsEveryonesHits)
    press(InputRules.Raw(controllerSignature: true), in: world)
    #expect(world.disrupts == 0 && world.threat == "The stranger is aiming.")
    #expect(run(world, upTo: 2) { world.threat == nil })
    #expect(world.observation == BrooklynBridge.stranger.missLine)
    #expect(run(world, upTo: 4) { world.session.hitsTaken == 1 })
    #expect(world.companionShots.isEmpty)
  }

  @Test
  func previousLeadsAsTheMemberBeforeTheLeaderOnTheBridgeToo() {
    let yard = GameWorld(level: CombatYard.level)
    press(InputRules.Raw(controllerPrevious: true), in: yard)
    #expect(yard.session.leader == .laura)
    press(InputRules.Raw(keyboardPrevious: true), in: yard)
    #expect(yard.session.leader == .tom)
    let bridge = GameWorld(level: BrooklynBridge.level)
    press(InputRules.Raw(controllerPrevious: true), in: bridge)
    #expect(bridge.session.leader == .miki)
    bridge.session.recruit(.tom)
    press(InputRules.Raw(controllerPrevious: true), in: bridge)
    #expect(bridge.session.leader == .tom)
    // Paused, the press is consumed, not queued.
    pressPause(bridge)
    press(InputRules.Raw(keyboardPrevious: true), in: bridge)
    #expect(bridge.session.leader == .tom)
  }

  // MARK: - Cover

  @Test
  func aCompanionInCoverDucksWhileAimedAtAndStepsOutToFire() {
    // Laura holds in the open beside the wall's east end; Miki and Tom hold behind the wall.
    let hold: SIMD2<Float> = [-0.4, 0.6]
    let world = GameWorld(
      level: range(
        spawns: [.miki: [-3.5, 2], .tom: [-4.5, 2.9], .laura: hold],
        shooters: [Shooter(id: "a", at: [0, -8], hits: 6)], positioning: true))
    func isHidden(_ member: PartyMember) -> Bool {
      !LineOfSight.isClear(
        from: [0, -8], to: position(world, member), obstacles: world.level.obstacles)
    }
    #expect(!isHidden(.laura))
    #expect(world.session.holdAll())
    #expect(run(world, upTo: 1) { world.threat == "Shooter A is aiming at Laura." })
    // She goes into cover near where she holds, and the shot meets the wall.
    #expect(run(world, upTo: 2) { world.threat == nil })
    #expect(isHidden(.laura) && world.session.hits(of: .laura) == 0)
    #expect(simd_distance(position(world, .laura), hold) < CoverPlanner.reach(in: .close) + 0.3)
    // While it recovers she steps out and fires, and ducks again at each wind-up. It never hits
    // her, and her bursts alone put it down.
    #expect(run(world, upTo: 15) { world.session.defeated.contains("a") })
    #expect(world.companionShots[.laura, default: 0] >= 6)
    #expect(world.session.hits(of: .laura) == 0 && world.session.hitsTaken == 0)
    // The fight over, she goes back to where she holds.
    #expect(world.companionTargets[.laura] == hold)
  }

  @Test
  func aFormationPressInAFightRegroupsTheCompanions() {
    // Laura holds in the open, in the shooter's sight; Tom holds behind the wall near Miki.
    let world = GameWorld(
      level: range(
        spawns: [.miki: [-3.5, 2], .tom: [-4.5, 2.9], .laura: [3, 2]],
        shooters: [Shooter(id: "a", at: [0, -8])], positioning: true))
    #expect(world.session.holdAll())
    #expect(run(world, upTo: 3) { world.companionShots[.laura, default: 0] > 0 })
    press(InputRules.Raw(controllerFormation: true), in: world)
    // The orders clear and the formation stays: the companions regroup.
    #expect(world.session.regrouping && world.session.orders.isEmpty)
    #expect(world.session.squadState == "regrouping" && world.session.formation == .close)
    // They hold their fire until they are back in the formation, and then the regroup ends.
    let shots = world.companionShots[.laura, default: 0]
    #expect(run(world, upTo: 8) { !world.session.regrouping })
    #expect(world.companionShots[.laura, default: 0] == shots)
    #expect(simd_distance(position(world, .laura), position(world, .miki)) < 2.5)
  }

  // MARK: - Helpers

  /// One of a range's shooters, like the yard's, engaged `engageAt` seconds into the fight.
  private struct Shooter {
    let id: String
    let at: SIMD2<Float>
    var hits = 50
    var engageAt: Float = 0
  }

  /// A small range with the combat yard's rules, for focused checks: open snow 30 m across, a
  /// wall from x = -6 to x = -1 across z = -1, and the given shooters, each named "Shooter" and
  /// its id in capitals. The party is the yard's, and the fight begins at once wherever it is.
  /// Combat positioning is on only where a check asks, so the others see where orders put the
  /// companions.
  private func range(
    spawns: [PartyMember: SIMD2<Float>], shooters: [Shooter], positioning: Bool = false
  ) -> Level {
    let hostiles = shooters.map {
      Level.Hostile(
        id: $0.id, name: "Shooter \($0.id.uppercased())", hiddenAt: $0.at, standAt: $0.at,
        hits: $0.hits, windUp: 1.5, recovery: 1.4, range: 14, inView: true,
        targetsAnyone: true, targetFromWindUp: true)
    }
    let fight = Level.Encounter(
      beat: .stranger, start: .area(PartyMotion.Box(minimum: [-15, -15], maximum: [15, 15])),
      retryAt: spawns[.miki], hostiles: hostiles,
      cues: shooters.map { (at: $0.engageAt, cue: Level.Cue.engage($0.id)) })
    var rules = CombatYard.combat
    rules.combatPositioning = positioning
    return Level(
      id: "test-range",
      ground: Level.Box(name: "ground", position: [0, -0.15, 0], size: [30, 0.3, 30]),
      boxes: [Level.Box(name: "wall", position: [-3.5, 1.5, -1], size: [5, 3, 0.5])],
      interactions: [], triggers: [], encounters: [fight], startingAmmo: 60,
      party: [.miki, .tom, .laura], spawns: spawns, heading: [0, -1],
      cameraOffset: CombatYard.level.cameraOffset, fieldOfView: CombatYard.level.fieldOfView,
      opening: "A range.", objective: "Test.", lookAround: "Snow.", restartNote: "Restart.",
      combat: rules)
  }

  /// One press, as the controls deliver it through the world's own input rules and release
  /// gate: everything released first, so that the press is fresh.
  private func press(_ raw: InputRules.Raw, in world: GameWorld) {
    let mode = world.session.mode
    world.update(
      with: world.controls.resolve(InputRules.Raw(), mode: mode), sampledIn: mode,
      deltaTime: 1 / 60)
    world.update(
      with: world.controls.resolve(raw, mode: world.session.mode), sampledIn: world.session.mode,
      deltaTime: 1 / 60)
  }

  /// Pause, move to a choice in the pause menu and confirm it.
  private func choose(_ choice: GameSession.PauseChoice, in world: GameWorld) {
    pressPause(world)
    let down = InputRules.Input(
      movement: .zero, actionPressed: false, pausePressed: false, switchPressed: false,
      menuMove: 1)
    let index = GameSession.PauseChoice.allCases.firstIndex(of: choice) ?? 0
    for _ in 0..<index { world.update(with: down, sampledIn: .paused, deltaTime: 1 / 60) }
    let confirm = InputRules.Input(
      movement: .zero, actionPressed: true, pausePressed: false, switchPressed: false)
    world.update(with: confirm, sampledIn: .paused, deltaTime: 1 / 60)
  }
}
