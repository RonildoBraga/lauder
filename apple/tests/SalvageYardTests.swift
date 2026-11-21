import RealityKit
import Testing
import UIKit
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
    let shown = yard.boxes + [task.gate, task.latchMark, task.panelMark] + task.aerial
    for box in shown {
      #expect(ahead(box.footprint.minimum) < 19 && ahead(box.footprint.maximum) < 19, "\(box.name)")
    }
    // While the gate is shut, the depot's inside is out of reach. Once it swings open, it stands
    // as a thin wall along the opening's west side, and the inside is in reach.
    let shut = NavigationGrid(level: yard, adding: [task.gate.footprint])
    let open = NavigationGrid(level: yard, adding: [task.openGate])
    let inside: SIMD2<Float> = [0, -8]
    #expect(shut.region(at: inside) != shut.region(at: entrance))
    #expect(open.region(at: inside) == open.region(at: entrance))
    let swung = task.openGate
    #expect(simd_distance((swung.minimum + swung.maximum) / 2, [-1, -5]) < 0.001)
    #expect(abs(swung.maximum.x - swung.minimum.x - 0.3) < 0.001)
    #expect(shut.isWalkable([-1, -5]) && !open.isWalkable([-1, -5]))
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
    // The transmitter's approach reaches well back towards the depot, so a leader arriving from
    // there can act before the transmitter hides them, and it is low enough to see them over.
    let body = task.transmitter.footprint
    #expect(body.minimum.y - task.transmitterApproach.minimum.y > 1.2)
    #expect(task.transmitter.size.y <= 1)
  }

  @Test
  func everyActionNameFitsTheTouchButton() {
    // "Reach the latch" and "Shift the panel" are the longest that show whole.
    let actions: [SalvageProgress.Action] = [
      .reachLatch, .shiftPanel, .inspect(""), .take(""), .search(""), .fit,
    ]
    for action in actions { #expect(action.name.count <= 15, "\(action.name)") }
    #expect(SalvageProgress.Action.take("").name == "Take regulator")
    #expect(SalvageProgress.Action.fit.name == "Fit regulator")
  }

  // MARK: - The gate

  @Test
  func onlyLauraOrTomOpensTheGateAndOthersHearWhoCan() throws {
    let progress = SalvageProgress.authored(for: task)
    #expect(progress.action(for: .laura, at: .latch) == .reachLatch)
    #expect(progress.action(for: .tom, at: .panel) == .shiftPanel)
    for (member, place) in [
      (PartyMember.miki, SalvageProgress.Place.latch), (.miki, .panel), (.tom, .latch),
      (.laura, .panel),
    ] {
      #expect(progress.action(for: member, at: place) == nil)
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
    #expect(world.session.salvage.hint(at: .latch) == nil)
    walk(world, to: [0, -6])
    #expect(simd_distance(position(world, .laura), [0, -6]) < 0.3)
    // Shifting the panel says the same of the gate.
    var other = SalvageProgress.authored(for: task)
    #expect(
      other.perform(.shiftPanel, by: .tom)
        == "Tom shifts the loose panel, and the gate swings open.")
  }

  // MARK: - The cabinets and the repair

  @Test
  func mikiTellsTheCabinetsApartWhileOthersSearchUnseen() {
    var progress = SalvageProgress.authored(for: task)
    // Miki inspects each cabinet. Once the party knows, nobody takes the wrong model or opens
    // the live cabinet, and the right regulator is anyone's to take.
    #expect(
      progress.perform(.inspect("cabinet-west"), by: .miki)
        == "A regulator of a different model. It won't fit.")
    #expect(
      progress.perform(.inspect("cabinet-middle"), by: .miki)
        == "Live: it still feeds the next shelter. Leave it connected.")
    #expect(
      progress.perform(.inspect("cabinet-east"), by: .miki)
        == "A compatible regulator, disconnected. Safe to take.")
    for member in PartyMember.allCases {
      #expect(progress.action(for: member, at: .cabinet("cabinet-west")) == nil)
      #expect(progress.action(for: member, at: .cabinet("cabinet-middle")) == nil)
      #expect(progress.action(for: member, at: .cabinet("cabinet-east")) == .take("cabinet-east"))
    }
    #expect(progress.perform(.take("cabinet-east"), by: .miki) == "Miki takes the regulator.")
    #expect(progress.regulators == [SalvageProgress.Regulator(model: .compatible, known: true)])
    #expect(progress.bag == "a regulator")
    #expect(progress.action(for: .tom, at: .cabinet("cabinet-east")) == nil)
    // Anyone else searches without knowing: Tom takes the wrong model, and the live cabinet stays
    // shut, after which nobody is offered anything there.
    var unseen = SalvageProgress.authored(for: task)
    #expect(unseen.bag == nil)
    #expect(
      unseen.action(for: .tom, at: .cabinet("cabinet-west")) == .search("cabinet-west"))
    #expect(
      unseen.perform(.search("cabinet-west"), by: .tom)
        == "Tom takes a regulator, but only Miki can tell its model.")
    #expect(
      unseen.perform(.search("cabinet-middle"), by: .laura)
        == "Live: it still feeds the next shelter. Leave it connected.")
    #expect(unseen.action(for: .tom, at: .cabinet("cabinet-middle")) == nil)
    #expect(unseen.regulators == [SalvageProgress.Regulator(model: .otherModel, known: false)])
    #expect(unseen.bag == "a regulator")
    // The wrong model does not fit, and trying it tells: the bag names it, Fit is no longer
    // offered, and Look at the transmitter says who could tell the models apart.
    #expect(unseen.action(for: .laura, at: .transmitter) == .fit)
    #expect(unseen.hint(at: .transmitter) == nil)
    #expect(
      unseen.perform(.fit, by: .laura) == "This regulator is a different model. It won't fit.")
    #expect(!unseen.repaired)
    #expect(unseen.regulators == [SalvageProgress.Regulator(model: .otherModel, known: true)])
    #expect(unseen.bag == "a regulator of a different model")
    #expect(unseen.action(for: .laura, at: .transmitter) == nil)
    #expect(
      unseen.hint(at: .transmitter) == "This regulator won't fit. Miki could tell the models apart."
    )
    // A regulator that might fit brings Fit back, and the right one finishes the repair.
    #expect(
      unseen.perform(.search("cabinet-east"), by: .laura)
        == "Laura takes a regulator, but only Miki can tell its model.")
    #expect(unseen.bag == "2 regulators, 1 of a different model")
    #expect(unseen.action(for: .tom, at: .transmitter) == .fit)
    #expect(unseen.perform(.fit, by: .tom) == "The regulator fits, and the transmitter answers.")
    #expect(unseen.repaired && unseen.regulators.map(\.model) == [.otherModel])
    #expect(unseen.action(for: .miki, at: .transmitter) == nil)
    #expect(unseen.hint(at: .transmitter) == nil)
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
    // This run dealt the right regulator to one of the three cabinets.
    let right = try #require(
      task.cabinets.first { world.session.salvage.contents[$0.id] == .compatible })
    for point in [[0, -2], [0, -6], middle(of: right.approach)] as [SIMD2<Float>] {
      walk(world, to: point)
    }
    #expect(world.actionName == "Inspect")
    world.performAction()
    #expect(world.actionName == "Take regulator")
    world.performAction()
    #expect(world.session.salvage.regulators.map(\.model) == [.compatible])
    // Back at the transmitter, coming from the depot, the prompt shows behind it already.
    for point: SIMD2<Float> in [[0, -6], [0, -2], [-3, 3.4]] { walk(world, to: point) }
    #expect(world.actionName == "Fit regulator")
    world.performAction()
    #expect(world.observation == "The regulator fits, and the transmitter answers.")
    #expect(world.objective == "The transmitter works. Restart to try again.")
    let transmitter = try #require(world.root.findEntity(named: "transmitter") as? ModelEntity)
    #expect(transmitter.model?.materials.first is UnlitMaterial)
    // Restart shuts the gate again and empties everything.
    world.restart()
    let fresh = world.session.salvage
    #expect(!fresh.gateOpen && !fresh.repaired && fresh.regulators.isEmpty && fresh.known.isEmpty)
    #expect(world.objective == "Fix the transmitter.")
    #expect(!(transmitter.model?.materials.first is UnlitMaterial))
    walk(world, to: [0, -6])
    #expect(position(world, .miki).y > -3.8)
  }

  @Test
  func theYardShowsWhereToGoAndWhatThePartyKnows() throws {
    let world = GameWorld(level: SalvageYard.level)
    let style = SceneStyle()
    let latch = world.root.findEntity(named: "latch")
    let panel = world.root.findEntity(named: "panel")
    let leaf = try #require(world.root.findEntity(named: "gate"))
    let hinge = try #require(world.root.findEntity(named: "gate.hinge"))
    // The gate stands out from the fence, the latch and the panel show as things to use, and
    // the transmitter wears faded teal under an ink aerial.
    #expect(rgb(of: leaf) == rgb(style.rust))
    #expect(rgb(of: leaf) != rgb(of: world.root.findEntity(named: "fence-south-west")))
    #expect(rgb(of: latch) == rgb(style.warm) && rgb(of: panel) == rgb(style.warm))
    #expect(rgb(of: world.root.findEntity(named: "transmitter")) == rgb(style.fadedTeal))
    #expect(rgb(of: world.root.findEntity(named: "aerial-mast")) == rgb(style.ink))
    #expect(rgb(of: world.root.findEntity(named: "aerial-arm")) == rgb(style.ink))
    // No cabinet shows a tag before anyone knows what it holds.
    for cabinet in task.cabinets {
      #expect(world.root.findEntity(named: "\(cabinet.id).tag")?.isEnabled == false)
    }
    // Tom opens the gate, which swings open over a moment and stays in sight; the latch and the
    // panel turn plain.
    lead(.tom, in: world)
    walk(world, to: [1.7, -3.2])
    world.performAction()
    world.advanceParty(movement: .zero, deltaTime: 1 / 60)
    #expect(hinge.orientation.angle > 0 && hinge.orientation.angle < .pi / 4)
    for _ in 0..<60 { world.advanceParty(movement: .zero, deltaTime: 1 / 60) }
    #expect(abs(hinge.orientation.angle - .pi / 2) < 0.01 && leaf.isEnabled)
    #expect(rgb(of: latch) == rgb(style.scenery) && rgb(of: panel) == rgb(style.scenery))
    // Miki inspects each cabinet, and each shows a tag: amber for the right regulator, stone for
    // the wrong model, and rust for the live equipment.
    lead(.miki, in: world)
    for point: SIMD2<Float> in [[0, -2], [0, -6]] { walk(world, to: point) }
    for cabinet in task.cabinets {
      walk(world, to: middle(of: cabinet.approach))
      world.performAction()
      let expected: any Material =
        switch world.session.salvage.contents[cabinet.id] {
        case .compatible: style.warm
        case .otherModel: style.stone
        case .live, nil: style.rust
        }
      let tag = world.root.findEntity(named: "\(cabinet.id).tag")
      #expect(tag?.isEnabled == true && rgb(of: tag) == rgb(expected), "\(cabinet.id)")
    }
    // Once its regulator is taken, the right cabinet shows emptied, in ink, without its tag.
    let right = try #require(
      task.cabinets.first { world.session.salvage.contents[$0.id] == .compatible })
    walk(world, to: middle(of: right.approach))
    world.performAction()
    #expect(world.root.findEntity(named: "\(right.id).tag")?.isEnabled == false)
    #expect(rgb(of: world.root.findEntity(named: right.box.name)) == rgb(style.ink))
    // Restart shuts the gate at once and shows the yard as it began.
    world.restart()
    #expect(hinge.orientation.angle < 0.001)
    #expect(rgb(of: latch) == rgb(style.warm))
    #expect(rgb(of: world.root.findEntity(named: right.box.name)) == rgb(style.scenery))
    for cabinet in task.cabinets {
      #expect(world.root.findEntity(named: "\(cabinet.id).tag")?.isEnabled == false)
    }
  }

  @Test
  func eachRunDealsTheCabinetsAfresh() {
    // Every run deals the same three contents, one to each cabinet, and over many runs the right
    // regulator turns up in more than one place, so only an inspection tells.
    let world = GameWorld(level: SalvageYard.level)
    var places: Set<String> = []
    for _ in 0..<30 {
      let contents = world.session.salvage.contents
      #expect(Set(contents.keys) == Set(task.cabinets.map(\.id)))
      #expect(contents.values.filter { $0 == .compatible }.count == 1)
      #expect(contents.values.filter { $0 == .otherModel }.count == 1)
      #expect(contents.values.filter { $0 == .live }.count == 1)
      places.formUnion(contents.filter { $0.value == .compatible }.keys)
      world.restart()
    }
    #expect(places.count > 1)
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

  private func middle(of area: PartyMotion.Box) -> SIMD2<Float> {
    (area.minimum + area.maximum) / 2
  }

  /// A block's colour, lit or unlit, as 8-bit red, green and blue.
  private func rgb(of entity: Entity?) -> [Int]? {
    (entity as? ModelEntity)?.model?.materials.first.flatMap(rgb)
  }

  private func rgb(_ material: any Material) -> [Int]? {
    guard
      let tint = (material as? SimpleMaterial)?.color.tint
        ?? (material as? UnlitMaterial)?.color.tint
    else { return nil }
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    tint.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return [red, green, blue].map { Int(($0 * 255).rounded()) }
  }
}
