import RealityKit
import Testing
import simd

@testable import Lauder

@MainActor
struct DuelStageTests {
  @Test(arguments: [DuelAction.Kind.sweep, .thrust])
  func onlyTheEnemyCommittedWindupShowsItsOwnWarning(kind: DuelAction.Kind) throws {
    var duel = DuelSimulation(heroPosition: .zero, enemyPosition: [0, -1.7])
    let stage = DuelStage()
    let warning = try warningRoot(in: stage)
    #expect(!warning.isEnabled)
    #expect(wait(&duel) { $0.enemy.action?.kind == kind && $0.enemy.action?.phase == .windup })
    stage.present(duel, deltaTime: 0)
    let action = try #require(duel.enemy.action)
    let selected = try #require(warning.findEntity(named: name(for: kind)))
    let other = try #require(
      warning.findEntity(named: name(for: kind == .sweep ? .thrust : .sweep)))
    #expect(warning.isEnabled && selected.isEnabled && !other.isEnabled)
    #expect(
      simd_distance(warning.position, [duel.enemy.position.x, 0.004, duel.enemy.position.y])
        < 0.0001)
    #expect(
      simd_distance(
        warning.orientation.act([0, 0, -1]), [action.direction.x, 0, action.direction.y]) < 0.0001)

    let position = warning.position
    let orientation = warning.orientation
    let heroPosition = duel.hero.position
    for _ in 0..<12 {
      duel.step(.init(movement: [1, 0]), deltaTime: DuelSimulation.fixedStep)
      stage.present(duel, deltaTime: DuelSimulation.fixedStep)
    }
    #expect(duel.hero.position != heroPosition)
    #expect(duel.enemy.action?.direction == action.direction)
    #expect(warning.position == position && warning.orientation == orientation)

    #expect(wait(&duel) { $0.enemy.action?.phase == .active })
    stage.present(duel, deltaTime: 0)
    #expect(!warning.isEnabled && !selected.isEnabled && !other.isEnabled)
    #expect(wait(&duel) { $0.enemy.action?.phase == .recovery })
    stage.present(duel, deltaTime: 0)
    #expect(!warning.isEnabled)
  }

  @Test(arguments: [DuelAction.Kind.sweep, .thrust])
  func cachedGroundGeometryMatchesTheWholeActionContactEnvelope(kind: DuelAction.Kind) throws {
    let stage = DuelStage()
    let group = try #require(stage.root.findEntity(named: name(for: kind)))
    let fill = try #require(group.findEntity(named: "\(name(for: kind)).fill") as? ModelEntity)
    let mesh = try #require(fill.model?.mesh)
    let part = try #require(mesh.contents.models.first?.parts.first)
    let vertices = part.positions.elements
    let profile = DuelAction(kind: kind, direction: [0, -1]).profile
    let reach = try #require(vertices.map { simd_length($0) }.max())
    #expect(abs(reach - profile.reach - DuelArena.radius) < 0.0001)
    #expect(vertices.contains { simd_distance($0, [0, 0, -reach]) < 0.0001 })
    for point in vertices {
      let radius = simd_length(point)
      #expect(point.y == 0 && radius >= 0.5999, "feet and focus ring retain a clear central cutout")
      let angle = abs(atan2(point.x, -point.z))
      let contactLimit = profile.halfAngle + asin(DuelArena.radius / radius)
      #expect(angle <= contactLimit + 0.0001)
    }
    let outerBoundary = try #require(vertices.first { abs(simd_length($0) - reach) < 0.0001 })
    #expect(
      abs(
        abs(atan2(outerBoundary.x, -outerBoundary.z)) - profile.halfAngle
          - asin(DuelArena.radius / reach)) < 0.0001)
    for child in group.children {
      let model = try #require(child as? ModelEntity)
      let geometry = try #require(model.model?.mesh.contents.models.first?.parts.first)
      let points = geometry.positions.elements
      let triangles = try #require(geometry.triangleIndices?.elements)
      for index in stride(from: 0, to: triangles.count, by: 3) {
        let a = points[Int(triangles[index])]
        let b = points[Int(triangles[index + 1])]
        let c = points[Int(triangles[index + 2])]
        #expect(simd_cross(b - a, c - a).y > 0, "fill and outline face the overhead camera")
      }
    }

    var duel = DuelSimulation(heroPosition: .zero, enemyPosition: [0, -1.7])
    #expect(wait(&duel) { $0.enemy.action?.kind == kind && $0.enemy.action?.phase == .windup })
    for _ in 0..<30 { stage.present(duel, deltaTime: 0) }
    #expect(stage.root.findEntity(named: name(for: kind)) === group)
    #expect(fill.model?.mesh === mesh, "presentation reuses the prepared geometry")
  }

  @Test func interruptionHidesWarningsAndResumeOrResetPresentsCurrentRules() throws {
    var duel = DuelSimulation(heroPosition: .zero, enemyPosition: [0, -1.7])
    let stage = DuelStage()
    let warning = try warningRoot(in: stage)
    #expect(wait(&duel) { $0.enemy.action?.phase == .windup })
    stage.present(duel, deltaTime: 0)
    #expect(warning.isEnabled)
    let action = duel.enemy.action
    duel.interrupt()
    stage.stopFeedback()
    #expect(!warning.isEnabled && warning.children.allSatisfy { !$0.isEnabled })
    #expect(duel.enemy.action == action, "interruption does not erase the owed action")
    stage.present(duel, deltaTime: 0)
    #expect(warning.isEnabled, "resume restores the still-frozen wind-up")
    duel.reset()
    stage.present(duel, deltaTime: 0)
    #expect(!warning.isEnabled && warning.children.allSatisfy { !$0.isEnabled })
    #expect(wait(&duel, command: .neutral) { $0.outcome != .fighting })
    stage.present(duel, deltaTime: 0)
    #expect(!warning.isEnabled, "a finished duel cannot leave a stale preparation cue")
  }

  private func name(for kind: DuelAction.Kind) -> String {
    "duel.attack-warning.\(kind == .sweep ? "sweep" : "thrust")"
  }

  private func warningRoot(in stage: DuelStage) throws -> Entity {
    try #require(stage.root.findEntity(named: "duel.attack-warning"))
  }

  private func wait(
    _ duel: inout DuelSimulation, command: DuelCommand = .init(guardHeld: true),
    until condition: (DuelSimulation) -> Bool
  ) -> Bool {
    for _ in 0..<1800 {
      if condition(duel) { return true }
      duel.step(command, deltaTime: DuelSimulation.fixedStep)
    }
    return false
  }
}
