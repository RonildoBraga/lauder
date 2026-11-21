import RealityKit
import Testing
import simd

@testable import Lauder

/// ADR 0007: the right stick aims Miki's carbine apart from movement, a shot that hits nobody
/// flies on and strikes a wall, shots outside a fight spend no rounds, every shot shows a streak
/// and a flash, and the camera's lens narrows in a fight.
@MainActor
struct ShootingTests {
  // MARK: - Where a shot goes

  @Test
  func anAimedShotFliesWhereTheStickPointsAndStrikesTheFirstBlock() throws {
    let wall = PartyMotion.Box(minimum: [-1, -6], maximum: [1, -5])
    let struck = try #require(
      Aim.shot(
        from: .zero, aim: [0, -1], facing: [1, 0], range: 14, hostiles: [], blockers: [wall]))
    #expect(struck.strike == .scenery && simd_distance(struck.end, [0, -5]) < 0.001)
    // With nothing in the way, it flies to the end of its reach.
    let open = try #require(
      Aim.shot(
        from: .zero, aim: [1, 0], facing: [0, -1], range: 14, hostiles: [], blockers: [wall]))
    #expect(open.strike == .nothing && simd_distance(open.end, [14, 0]) < 0.001)
  }

  @Test
  func theHelpPicksAHostileOnlyNearWhereTheStickAims() {
    let near = Aim.Hostile(id: "near", position: [0.5, -8], isTarget: true)
    let wide = Aim.Hostile(id: "wide", position: [4, -6], isTarget: true)
    let ahead = Aim.shot(
      from: .zero, aim: [0, -1], facing: [0, -1], range: 14, hostiles: [near, wide], blockers: [])
    #expect(ahead?.strike == .body("near"))
    let away = Aim.shot(
      from: .zero, aim: [-1, 0], facing: [0, -1], range: 14, hostiles: [near, wide], blockers: [])
    #expect(away?.strike == .nothing)
  }

  @Test
  func withoutTheStickFireTakesTheAssistedTargetOrGoesStraightAhead() throws {
    let side = Aim.Hostile(id: "side", position: [6, 0], isTarget: true)
    let assisted = Aim.shot(
      from: .zero, aim: nil, facing: [0, -1], range: 14, hostiles: [side], blockers: [])
    #expect(assisted?.strike == .body("side"))
    let ahead = try #require(
      Aim.shot(from: .zero, aim: nil, facing: [0, -1], range: 14, hostiles: [], blockers: []))
    #expect(ahead.strike == .nothing && simd_distance(ahead.end, [0, -14]) < 0.001)
  }

  @Test
  func theLeaderNeverFiresFirstAtSomeoneWhoIsNotYetATarget() {
    let stranger = Aim.Hostile(id: "stranger", position: [0, -6], isTarget: false)
    for aim in [SIMD2<Float>(0, -1), nil] {
      #expect(
        Aim.shot(
          from: .zero, aim: aim, facing: [0, -1], range: 14, hostiles: [stranger], blockers: [])
          == nil)
    }
    // Behind a wall, or off the shot's line, he does not hold it.
    let wall = PartyMotion.Box(minimum: [-1, -4], maximum: [1, -3])
    let walled = Aim.shot(
      from: .zero, aim: [0, -1], facing: [0, -1], range: 14, hostiles: [stranger],
      blockers: [wall])
    #expect(walled?.strike == .scenery)
    let aside = Aim.shot(
      from: .zero, aim: [1, 0], facing: [0, -1], range: 14, hostiles: [stranger], blockers: [])
    #expect(aside?.strike == .nothing)
  }

  @Test
  func aShotFliesOverALowBlock() throws {
    let low = Level.Box.box("low", at: [0, 0.5, -5], size: [2, 1, 1])
    let tall = Level.Box.box("tall", at: [0, 1.1, -8], size: [2, 2.2, 1])
    let blockers = Aim.blockers([low, tall], above: EncounterStage.aimHeight)
    #expect(blockers.count == 1)
    let shot = try #require(
      Aim.shot(
        from: .zero, aim: [0, -1], facing: [0, -1], range: 14, hostiles: [],
        blockers: blockers))
    #expect(shot.strike == .scenery && simd_distance(shot.end, [0, -7.5]) < 0.001)
  }

  // MARK: - The right stick

  @Test
  func theRightStickAndIJKLAimApartFromMovement() {
    let open = InputRules.State(needsNeutralInput: false)
    let aimed = InputRules.resolve(
      InputRules.Raw(stick: [0, 1], aimStick: [1, 0]), mode: .exploring, state: open)
    #expect(aimed.input.aim == SIMD2<Float>(1, 0) && aimed.input.movement == [0, 1])
    // Inside the dead zone, it aims nowhere.
    let resting = InputRules.resolve(
      InputRules.Raw(aimStick: [0.1, 0]), mode: .exploring, state: open)
    #expect(resting.input.aim == nil)
    // I, K, J and L aim too, ahead of the stick.
    let keys = InputRules.resolve(
      InputRules.Raw(aimStick: [1, 0], aimUp: true), mode: .exploring, state: open)
    #expect(keys.input.aim == SIMD2<Float>(0, 1))
    // Paused or talking, nothing aims.
    for mode in [GameSession.Mode.paused, .dialogue] {
      let consumed = InputRules.resolve(
        InputRules.Raw(aimStick: [1, 0]), mode: mode, state: open)
      #expect(consumed.input.aim == nil)
    }
    // A held aim keeps the release gate closed, and counts as the controller's or keyboard's.
    let gated = InputRules.resolve(
      InputRules.Raw(aimStick: [1, 0]), mode: .exploring, state: InputRules.State())
    #expect(gated.state.needsNeutralInput && gated.input.aim == nil)
    #expect(InputRules.Raw(aimStick: [1, 0]).hasControllerInput)
    #expect(InputRules.Raw(aimLeft: true).hasKeyboardInput)
  }

  @Test
  func aimingTurnsMikiAndDrawsHerCarbineWhileSheWalksAnotherWay() {
    let world = GameWorld(level: SalvageYard.level)
    #expect(world.session.leader == .miki && world.showsWeapon && !world.weaponDrawn)
    let start = position(world, .miki)
    let up = stick(world, towards: [0, -1])
    let right = stick(world, towards: [1, 0])
    for _ in 0..<30 { world.advanceParty(movement: up, aim: right, deltaTime: 1 / 60) }
    // She walks up the screen while she faces her aim, to the right, with her carbine drawn.
    #expect(position(world, .miki).y < start.y - 0.5)
    #expect(simd_distance(world.facing(of: .miki), [1, 0]) < 0.01)
    #expect(world.weaponDrawn)
    // Once the stick lets go, she faces where she walks again.
    for _ in 0..<10 { world.advanceParty(movement: up, deltaTime: 1 / 60) }
    #expect(simd_distance(world.facing(of: .miki), [0, -1]) < 0.01)
  }

  @Test
  func onlyMikiAimsAndFires() {
    let world = GameWorld(level: SalvageYard.level)
    for _ in 0..<3 where world.session.leader != .tom { world.session.cycleLeader() }
    world.advanceParty(movement: .zero, deltaTime: 1 / 60)
    #expect(world.session.leader == .tom && !world.showsWeapon)
    let right = stick(world, towards: [1, 0])
    for _ in 0..<30 {
      world.advanceParty(movement: .zero, aim: right, fireHeld: true, deltaTime: 1 / 60)
    }
    #expect(!world.weaponDrawn && world.shotMarks == 0)
    #expect(world.cameraLens == SalvageYard.level.fieldOfView)
  }

  // MARK: - Shots and rounds

  @Test
  func shotsOutsideAFightStrikeWallsAndSpendNoRounds() {
    // The salvage yard has no fights and gives no rounds; Miki aims up at its shut gate.
    let world = GameWorld(level: SalvageYard.level)
    let up = stick(world, towards: [0, -1])
    run(world, upTo: 1.2, fire: true, aim: up)
    #expect(world.weaponDrawn && world.session.ammo == 0)
    #expect(world.shotMarks >= 2)
  }

  @Test
  func aShotInAFightSpendsARound() {
    // Miki aims up the combat yard at its wall.
    let world = GameWorld(level: CombatYard.level)
    let ammo = world.session.ammo
    let up = stick(world, towards: [0, -1])
    // Before the yard's fight, practice is free.
    run(world, upTo: 1.2, fire: true, aim: up)
    #expect(world.session.ammo == ammo && world.shotMarks > 0)
    // Inside it, every shot spends a round, even one that hits nobody.
    walk(world, to: [0, 0])
    #expect(world.session.inEncounter)
    run(world, upTo: 1, fire: true, aim: up)
    #expect(world.session.ammo < ammo)
  }

  // MARK: - The lens

  @Test
  func theLensNarrowsWhileAimingAndInAFightThenWidensAgain() {
    let world = GameWorld(level: CombatYard.level)
    let wide = CombatYard.level.fieldOfView
    #expect(world.cameraLens == wide)
    run(world, upTo: 1.5, aim: stick(world, towards: [1, 0]))
    #expect(abs(world.cameraLens - wide * GameWorld.fightLens) < 0.05)
    run(world, upTo: 1.5)
    #expect(abs(world.cameraLens - wide) < 0.05)
    // In the yard's fight it stays narrow without the stick, and the touch order's ground
    // follows it.
    walk(world, to: [0, 0])
    run(world, upTo: 1.5)
    #expect(world.session.inEncounter)
    #expect(abs(world.cameraLens - wide * GameWorld.fightLens) < 0.05)
    #expect(world.projection(aspect: 2).fieldOfView == world.cameraLens)
  }

  // MARK: - What a shot looks like

  @Test
  func aShotShowsAStreakAndFlashesAndAStrikeLeavesAMarkForAWhile() throws {
    let container = Entity()
    let effects = ShotEffects(style: SceneStyle(), in: container)
    effects.show(
      ShotPath(start: .zero, end: [0, -10], strike: .scenery), side: .party, height: 1.25)
    func shown(_ name: String) -> Int {
      container.children.filter { $0.name == name && $0.isEnabled }.count
    }
    #expect(shown("party.streak") == 1 && shown("party.flash") == 2)
    #expect(shown("shot.chip") == ShotEffects.chipsPerStrike && effects.marksShown == 1)
    // The streak flies on and goes, the flashes go out and the chips fall; the mark stays.
    effects.update(dt: 0.5)
    #expect(shown("party.streak") == 0 && shown("party.flash") == 0 && shown("shot.chip") == 0)
    #expect(effects.marksShown == 1)
    effects.update(dt: ShotEffects.markTime)
    #expect(effects.marksShown == 0 && shown("shot.mark") == 0)
    // A hostile's shot that hits someone flashes in the threat's colour, and leaves no mark.
    effects.show(
      ShotPath(start: .zero, end: [5, 0], strike: .body("miki")), side: .hostile, height: 1.25)
    #expect(shown("hostile.streak") == 1 && shown("hostile.flash") == 2 && shown("shot.mark") == 0)
    effects.clear()
    #expect(container.children.allSatisfy { !$0.isEnabled })
  }
}
