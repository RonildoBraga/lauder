import RealityKit
import Testing
import UIKit
import simd

@testable import Lauder

@MainActor
struct TestLoadoutTests {
  @Test
  func benchIsArenaOnlyAndCannotChangeAGunDuringLivePlay() {
    for level in [BrooklynBridge.level, RelayRun.level, SalvageYard.level] {
      let session = GameSession(level: level)
      session.togglePause()
      #expect(!session.availablePauseChoices.contains(.testWeapon))
      #expect(!session.cycleTestWeapon() && session.testWeaponTitle == nil)
      #expect(session.weapon(for: .miki).kind == .carbine)
    }
    let session = GameSession(level: CombatYard.level)
    #expect(session.availablePauseChoices[2] == .otherLevel)
    #expect(session.availablePauseChoices.last == .testWeapon)
    #expect(!session.cycleTestWeapon())
    #expect(session.weapon(for: .miki).kind == .carbine)
  }

  @Test
  func choicesBelongToEachMemberAndNeverCreateSharedAmmunition() {
    let session = GameSession(level: CombatYard.level)
    #expect(session.spendRound())
    let ammo = session.ammo
    session.togglePause()
    #expect(session.cycleTestWeapon())
    #expect(session.weapon(for: .miki).kind == .lightBurst)
    #expect(session.weapon(for: .laura).kind == .lightBurst)
    #expect(session.weapon(for: .tom).kind == .closeScatter)
    for _ in Weapon.testKinds { #expect(session.cycleTestWeapon()) }
    #expect(session.weapon(for: .miki).kind == .lightBurst && session.ammo == ammo)
    session.togglePause()
    session.cycleLeader()
    #expect(session.leader == .tom && session.weapon(for: .tom).kind == .closeScatter)
    session.restart()
    #expect(session.weapon(for: .miki).kind == .carbine)
    #expect(session.weapon(for: .tom).kind == .closeScatter)
  }

  @Test
  func touchSelectionUsesPausedAuthorityAndRequiresReleasedControlsBeforeFreshFire() {
    let world = GameWorld(level: CombatYard.level)
    press(.init(touchPause: true), in: world)
    #expect(world.isPaused)
    let ammo = world.session.ammo
    press(.init(touchTestWeapon: true), in: world)
    #expect(world.isPaused && world.controls.needsNeutralInput)
    #expect(world.session.weapon(for: .miki).kind == .lightBurst)
    #expect(world.weaponStatus.contains("Burst weapon") && world.weaponKind == nil)
    #expect(world.session.ammo == ammo && !world.weaponDrawn)

    // A held new-menu touch cannot be reinterpreted as a fresh selection or a Fire press.
    for _ in 0..<10 { update(world, .init(touchTestWeapon: true, touchFire: true)) }
    #expect(world.session.weapon(for: .miki).kind == .lightBurst)
    #expect(world.controls.needsNeutralInput && world.session.ammo == ammo)
    press(.init(touchPause: true), in: world)
    #expect(!world.isPaused)
    for _ in 0..<60 { update(world, .init(touchFire: true)) }
    #expect(!world.weaponDrawn)
    update(world, .init())
    for _ in 0..<60 { update(world, .init(touchFire: true)) }
    #expect(world.weaponDrawn && world.weaponKind == .lightBurst)
  }

  @Test
  func changingAGunReparentsItsPropAndRepeatedCyclesReuseTheSameEntity() throws {
    let session = GameSession(level: CombatYard.level)
    let fight = FightSimulation(level: CombatYard.level)
    let stage = EncounterStage(level: CombatYard.level, style: SceneStyle())
    let visual = Entity()
    let original = try #require(stage.weaponProps[.miki])
    visual.addChild(original)
    session.togglePause()
    for _ in 0..<Weapon.testKinds.count {
      let before = try #require(stage.weaponProps[.miki])
      #expect(session.cycleTestWeapon())
      fight.syncEquipment(session: session)
      stage.reset(fight)
      let after = try #require(stage.weaponProps[.miki])
      #expect(before.parent == nil && after.parent === visual)
      #expect(visual.children.count == 1)
      #expect(fight.status(for: .miki).loaded == session.weapon(for: .miki).capacity)
      #expect(fight.status(for: .miki).kind == session.weapon(for: .miki).kind)
    }
    #expect(stage.weaponProps[.miki] === original)
  }

  @Test(arguments: [568, 667, 740, 844, 926])
  func touchMenuShowsBenchOnlyWhenPausedInTheArena(width: Int) throws {
    let controls = GameControls()
    let view = TouchControls.Surface(controls: controls)
    view.frame = CGRect(x: 0, y: 0, width: CGFloat(width), height: 320)
    func show(_ mode: GameSession.Mode, title: String?) {
      view.update(
        actionTitle: "Look", nextLeaderName: "Tom", showsFire: true,
        showsSignature: false, showsFormation: true, formationTitle: "Formation",
        orderNames: ("Laura", "Tom"), otherLevelTitle: "Salvage test",
        vibrationTitle: "Vibration: On", mode: mode, generation: controls.touchGeneration,
        testWeaponTitle: title)
      view.layoutIfNeeded()
    }
    show(.paused, title: "Test weapon: SMG")
    let button = try #require(view.subviews.first { $0.accessibilityLabel == "Test weapon: SMG" })
    #expect(!button.isHidden && view.bounds.contains(button.frame))
    let sourceChoice = CGRect(x: view.bounds.width - 200, y: 0, width: 200, height: 136)
    #expect(!button.frame.intersects(sourceChoice))
    show(.exploring, title: "Test weapon: SMG")
    #expect(button.isHidden)
    show(.paused, title: nil)
    #expect(button.isHidden)
  }

  @Test
  func benchTapsAreLatchedOnceAndOldSourceGenerationsCannotReplayThem() {
    var touch = TouchInput()
    touch.setButton(.testWeapon, isPressed: true, generation: 0)
    touch.setButton(.testWeapon, isPressed: false, generation: 0)
    let first = touch.sample()
    let resolved = InputRules.resolve(first, mode: .paused, state: .init(needsNeutralInput: false))
    #expect(resolved.input.testWeaponPressed)
    #expect(
      !InputRules.resolve(touch.sample(), mode: .paused, state: resolved.state).input
        .testWeaponPressed)
    #expect(
      !InputRules.resolve(first, mode: .exploring, state: .init(needsNeutralInput: false)).input
        .testWeaponPressed)
    touch.cancel()
    touch.setButton(.testWeapon, isPressed: true, generation: 0)
    #expect(!touch.sample().touchTestWeapon)
  }

  private func press(_ raw: InputRules.Raw, in world: GameWorld) {
    update(world, .init())
    update(world, raw)
  }

  private func update(_ world: GameWorld, _ raw: InputRules.Raw) {
    let mode = world.session.mode
    world.update(with: world.controls.resolve(raw, mode: mode), sampledIn: mode, deltaTime: 1 / 60)
  }
}
