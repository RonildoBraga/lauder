import RealityKit
import Testing
import simd

@testable import Lauder

/// ADR 0006: the salvage yard, a greybox venue for the first salvage and exploration experiment,
/// where the trio recovers the right regulator to fix a transmitter. No step needs one member,
/// but each makes some step better.
@MainActor
struct SalvageYardTests {
  private let task = SalvageYard.salvage

  // MARK: - The venue

  @Test
  func theYardIsAGreyboxWithAShutDepotAndThreeCabinets() throws {
    let yard = SalvageYard.level
    #expect(yard.id == "salvage-yard" && yard.scene == nil && yard.encounters.isEmpty)
    #expect(yard.party == [.miki, .tom, .laura])
    #expect(yard.cameraOffset == BrooklynBridge.layout.camera.offset)
    #expect(yard.lights.map(\.name) == BrooklynBridge.layout.lights.map(\.name))
    // One cabinet of each kind.
    #expect(task.cabinets.map(\.contents) == [.otherModel, .live, .compatible])
    // Everything lies within the 19 m that the camera shows ahead of the entrance.
    let entrance = yard.spawn(.miki)
    func ahead(_ point: SIMD2<Float>) -> Float { simd_dot(point - entrance, yard.heading) }
    for box in yard.boxes + [task.gate] {
      #expect(ahead(box.footprint.minimum) < 19 && ahead(box.footprint.maximum) < 19, "\(box.name)")
    }
    // While the gate is shut, the depot's inside is out of reach; once it opens, it is not.
    let shut = NavigationGrid(level: yard, adding: [task.gate.footprint])
    let open = NavigationGrid(level: yard)
    let inside: SIMD2<Float> = [0, -8]
    #expect(shut.region(at: inside) != shut.region(at: entrance))
    #expect(open.region(at: inside) == open.region(at: entrance))
    // Every place to act is somewhere a body can stand: the latch and the panel outside the
    // gate, the cabinets' approaches inside, and the transmitter's at the entrance.
    let places = [task.latch, task.panel, task.transmitterApproach] + task.cabinets.map(\.approach)
    for area in places {
      let middle = (area.minimum + area.maximum) / 2
      let spot = open.nearestWalkable(to: middle, within: 1.5) { area.contains($0) }
      #expect(spot != nil, "\(middle)")
    }
    #expect(
      shut.region(at: (task.latch.minimum + task.latch.maximum) / 2) == shut.region(at: entrance))
  }

  // MARK: - The gate

  @Test
  func onlyLauraOrTomOpensTheGateAndOthersHearWhoCan() {
    let progress = SalvageProgress()
    #expect(progress.action(for: .laura, at: .latch, in: task) == .reachLatch)
    #expect(progress.action(for: .tom, at: .panel, in: task) == .shiftPanel)
    for (member, place) in [
      (PartyMember.miki, SalvageProgress.Place.latch), (.miki, .panel), (.tom, .latch),
      (.laura, .panel),
    ] {
      #expect(progress.action(for: member, at: place, in: task) == nil)
    }
    #expect(progress.hint(at: .latch) == "Laura could reach the latch.")
    #expect(progress.hint(at: .panel) == "Tom could shift the panel.")
    // In the yard, Miki at the latch hears who can, and the gate stays shut.
    let world = GameWorld(level: SalvageYard.level)
    walk(world, to: [-1.7, -3.2])
    #expect(world.actionName == nil)
    world.performAction()
    #expect(world.observation == "Laura could reach the latch." && !world.session.salvage.gateOpen)
    // Laura reaches the latch, and the gate opens for everyone.
    lead(.laura, in: world)
    walk(world, to: [-1.7, -3.2])
    #expect(world.actionName == "Reach the latch")
    world.performAction()
    #expect(world.observation == "Laura reaches the latch, and the gate swings open.")
    #expect(world.session.salvage.gateOpen && world.actionName == nil)
    #expect(world.root.findEntity(named: "gate")?.isEnabled == false)
    walk(world, to: [0, -6])
    #expect(simd_distance(position(world, .laura), [0, -6]) < 0.3)
  }

  // MARK: - The cabinets and the repair

  @Test
  func mikiTellsTheCabinetsApartWhileOthersSearchUnseen() {
    var progress = SalvageProgress()
    // Miki inspects each cabinet, and takes only the right regulator.
    #expect(
      progress.perform(.inspect("cabinet-west"), in: task)
        == "A regulator of a different model. It won't fit.")
    #expect(progress.action(for: .miki, at: .cabinet("cabinet-west"), in: task) == nil)
    #expect(
      progress.perform(.inspect("cabinet-middle"), in: task)
        == "Live: it still feeds the next shelter. Leave it connected.")
    #expect(progress.action(for: .miki, at: .cabinet("cabinet-middle"), in: task) == nil)
    #expect(
      progress.perform(.inspect("cabinet-east"), in: task)
        == "A compatible regulator, disconnected. Safe to take.")
    #expect(
      progress.action(for: .miki, at: .cabinet("cabinet-east"), in: task) == .take("cabinet-east"))
    #expect(progress.perform(.take("cabinet-east"), in: task) == "Miki takes the regulator.")
    #expect(progress.regulators == [.compatible])
    #expect(progress.action(for: .tom, at: .cabinet("cabinet-east"), in: task) == nil)
    // Anyone else searches without knowing: Tom takes the wrong model, and the live cabinet stays
    // shut, after which he is offered nothing there.
    var unseen = SalvageProgress()
    #expect(
      unseen.action(for: .tom, at: .cabinet("cabinet-west"), in: task) == .search("cabinet-west"))
    #expect(unseen.perform(.search("cabinet-west"), in: task) == "Found a regulator.")
    #expect(
      unseen.perform(.search("cabinet-middle"), in: task)
        == "Live: it still feeds the next shelter. Leave it connected.")
    #expect(unseen.action(for: .tom, at: .cabinet("cabinet-middle"), in: task) == nil)
    #expect(unseen.regulators == [.otherModel])
    // The wrong model does not fit, and stays in the bag; the right one finishes the repair.
    #expect(unseen.action(for: .laura, at: .transmitter, in: task) == .fit)
    #expect(unseen.perform(.fit, in: task) == "This regulator is a different model. It won't fit.")
    #expect(!unseen.repaired && unseen.regulators == [.otherModel])
    #expect(unseen.perform(.search("cabinet-east"), in: task) == "Found a regulator.")
    #expect(unseen.perform(.fit, in: task) == "The regulator fits, and the transmitter answers.")
    #expect(unseen.repaired && unseen.regulators == [.otherModel])
    #expect(unseen.action(for: .miki, at: .transmitter, in: task) == nil)
  }

  @Test
  func fittingTheRightRegulatorFinishesTheRepairAndRestartUndoesIt() throws {
    let world = GameWorld(level: SalvageYard.level)
    #expect(world.objective == "Fix the transmitter.")
    // Tom shifts the panel; Miki goes in, inspects the right cabinet and takes its regulator.
    lead(.tom, in: world)
    walk(world, to: [1.7, -3.2])
    world.performAction()
    #expect(world.session.salvage.gateOpen)
    lead(.miki, in: world)
    for point: SIMD2<Float> in [[0, -2], [0, -6], [3.5, -9.9]] { walk(world, to: point) }
    #expect(world.actionName == "Inspect")
    world.performAction()
    #expect(world.actionName == "Take the regulator")
    world.performAction()
    #expect(world.session.salvage.regulators == [.compatible])
    // Back at the transmitter, it fits.
    for point: SIMD2<Float> in [[0, -6], [0, -2], [-2, 5]] { walk(world, to: point) }
    #expect(world.actionName == "Fit the regulator")
    world.performAction()
    #expect(world.observation == "The regulator fits, and the transmitter answers.")
    #expect(world.objective == "The transmitter works. Restart to try again.")
    let transmitter = try #require(world.root.findEntity(named: "transmitter") as? ModelEntity)
    #expect(transmitter.model?.materials.first is UnlitMaterial)
    // Restart shuts the gate again and empties everything.
    world.restart()
    #expect(world.session.salvage == SalvageProgress() && world.objective == "Fix the transmitter.")
    #expect(world.root.findEntity(named: "gate")?.isEnabled == true)
    #expect(!(transmitter.model?.materials.first is UnlitMaterial))
    walk(world, to: [0, -6])
    #expect(position(world, .miki).y > -3.8)
  }

  // MARK: - Reaching it

  @Test
  func thePauseMenusThirdChoiceNamesTheNextLevel() {
    #expect(LevelCycle.next(after: BrooklynBridge.level).name == "Combat test")
    #expect(LevelCycle.next(after: CombatYard.level).name == "Salvage test")
    #expect(LevelCycle.next(after: CombatYard.level).level.id == SalvageYard.level.id)
    #expect(LevelCycle.next(after: SalvageYard.level).name == "Bridge")
    #expect(LevelCycle.next(after: TestYard.level).name == "Combat test")
  }

  // MARK: - Helpers

  /// Lead as `member`, cycling the party, and let the world take the change.
  private func lead(_ member: PartyMember, in world: GameWorld) {
    for _ in 0..<3 where world.session.leader != member { world.session.cycleLeader() }
    world.advanceParty(movement: .zero, deltaTime: 1 / 60)
  }
}
