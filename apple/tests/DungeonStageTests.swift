import RealityKit
import Testing
import simd

@testable import Lauder

@MainActor
struct DungeonStageTests {
  @Test
  func dungeonVisualsRetainCollisionFootprintsWithDeliberateCutawayHeights() throws {
    let stage = DuelStage()
    for (index, wall) in DungeonLayout.walls.enumerated() {
      let entity = try #require(stage.root.findEntity(named: "dungeon.wall.\(index)"))
      let bounds = entity.visualBounds(relativeTo: stage.root)
      #expect(simd_distance(SIMD2(bounds.min.x, bounds.min.z), wall.bounds.minimum) < 0.0001)
      #expect(simd_distance(SIMD2(bounds.max.x, bounds.max.z), wall.bounds.maximum) < 0.0001)
      #expect(abs(bounds.min.y) < 0.0001 && abs(bounds.max.y - wall.height) < 0.0001)
    }
    for (index, floor) in DungeonLayout.floors.enumerated() {
      let entity = try #require(stage.root.findEntity(named: "dungeon.floor.\(index)"))
      let bounds = entity.visualBounds(relativeTo: stage.root)
      #expect(simd_distance(SIMD2(bounds.min.x, bounds.min.z), floor.minimum) < 0.0001)
      #expect(simd_distance(SIMD2(bounds.max.x, bounds.max.z), floor.maximum) < 0.0001)
      #expect(bounds.max.y <= 0 && bounds.max.y > -0.02)
    }
    #expect(stage.root.findEntity(named: "duel.blocker.0") == nil)
  }

  @Test
  func doorwayFramesAndReturnsDoNotHideTheCapturedFirstEncounterFeet() throws {
    let stage = DuelStage()
    var scenery: [ModelEntity] = []
    for entity in stage.root.children {
      if entity.name.hasPrefix("dungeon.wall"), let model = entity as? ModelEntity {
        scenery.append(model)
      } else if entity.name.hasPrefix("dungeon.doorway.") {
        #expect(entity.visualBounds(relativeTo: entity).max.y <= 0.26)
        scenery += entity.children.compactMap { $0 as? ModelEntity }
      }
    }
    #expect(DungeonLayout.walls.contains { $0.height >= 1.8 }, "rear walls retain enclosure")
    let rig = CameraRig(
      offset: WorldCamera.offset, fieldOfView: WorldCamera.fieldOfView, over: .zero,
      orthographicHeight: WorldCamera.orthographicHeight(forPitch: 35))
    let view = rig.projection(aspect: 19.5 / 9)
    // Actual hero locations in the first native focus/sweep captures that exposed the return-wall bug.
    for ground: SIMD2<Float> in [[0.1185, 1.2032], [0.7808, 0.8606]] {
      for height: Float in [0, 0.45, 1.05] {
        let point = SIMD3<Float>(ground.x, height, ground.y)
        let screen = try #require(view.screen(ofWorld: point))
        let ray = try #require(view.ray(atScreen: screen))
        let targetDistance = simd_dot(point - ray.origin, ray.direction)
        for model in scenery {
          let bounds = model.visualBounds(relativeTo: stage.root)
          if let entry = view.entry(along: ray, minimum: bounds.min, maximum: bounds.max) {
            #expect(entry >= targetDistance - 0.0001, "\(model.name) obscures \(point)")
          }
        }
      }
    }
  }

  @Test
  func distantRoomsDoNotExposeAHiddenOpponentOrItsFocusAndPreparation() throws {
    var run = DungeonRun()
    let stage = DuelStage()
    stage.present(run, deltaTime: 0)
    let enemy = try #require(stage.root.findEntity(named: "duel.enemy"))
    let focus = try #require(stage.root.findEntity(named: "duel.focus-ring"))
    let warning = try #require(stage.root.findEntity(named: "duel.attack-warning"))
    #expect(!enemy.isEnabled && !focus.isEnabled && !warning.isEnabled)
    for waypoint: SIMD2<Float> in [[0, 7], [0, 5.25], [3.25, 5.25], [3.25, 0.75]] {
      #expect(walk(&run, to: waypoint))
    }
    #expect(run.activeEncounter == nil && run.visibleEnemy != nil)
    stage.present(run, deltaTime: 0)
    #expect(enemy.isEnabled && !focus.isEnabled && !warning.isEnabled)
    #expect(walk(&run, to: DungeonLayout.firstEntry))
    run.step(.init(focusPressed: true), deltaTime: DuelSimulation.fixedStep)
    stage.present(run, deltaTime: 0)
    #expect(run.activeEncounter == 0 && run.isFocused)
    #expect(enemy.isEnabled && focus.isEnabled)
    run.restart()
    stage.resetMotion()
    stage.present(run, deltaTime: 0)
    #expect(!enemy.isEnabled && !focus.isEnabled && !warning.isEnabled)
  }

  @Test(arguments: [DuelAction.Kind.sweep, .thrust])
  func aSupplementaryEnvelopeIsOmittedWhenSceneryWouldMakeItMisleading(kind: DuelAction.Kind) {
    let stage = DuelStage()
    let action = DuelAction(kind: kind, direction: [1, 0])
    #expect(stage.preparationHasClearance(action: action, origin: [-2, -1.5], shortcutOpen: false))
    #expect(!stage.preparationHasClearance(action: action, origin: [1.2, -2], shortcutOpen: false))
    #expect(!stage.preparationHasClearance(action: action, origin: [20, 20], shortcutOpen: true))
  }

  @Test
  func fixedEnemySwordTracksTheAuthoritativeTipAcrossBothAttackPhases() throws {
    var duel = DuelSimulation(
      heroPosition: [-2, 0.3], enemyPosition: [-2, -1.5],
      obstacles: DungeonLayout.obstacles(shortcutOpen: false), enemyHome: [-2, -1.5])
    let stage = DuelStage()
    let actor = try #require(stage.root.findEntity(named: "duel.enemy"))
    let weapon = try #require(actor.findEntity(named: "enemy.weapon"))
    let blade = try #require(actor.findEntity(named: "enemy.blade") as? ModelEntity)
    let mesh = try #require(blade.model?.mesh)
    var phases: Set<String> = []
    for _ in 0..<1800 {
      duel.step(.init(guardHeld: true), deltaTime: DuelSimulation.fixedStep)
      guard let action = duel.enemy.action else { continue }
      let key = "\(action.kind)-\(action.phase)"
      guard phases.insert(key).inserted else { continue }
      stage.present(duel, deltaTime: DuelSimulation.fixedStep)
      let tip = weapon.convert(position: [0, 0, -1.7], to: actor)
      let expected =
        SIMD3<Float>(0, 1.08, 0)
        + simd_quatf(angle: action.bladeAngle, axis: [0, 1, 0]).act([0, 0, -action.bladeReach])
      #expect(simd_distance(tip, expected) < 0.0001)
      #expect(blade.model?.mesh === mesh, "thrust moves a fixed sword instead of stretching it")
      if phases.count == 6 { break }
    }
    #expect(phases.count == 6, "both sweep and thrust were sampled in preparation/contact/recovery")
  }

  private func walk(_ run: inout DungeonRun, to destination: SIMD2<Float>) -> Bool {
    for _ in 0..<900 {
      let remaining = destination - run.hero.position
      if simd_length(remaining) < 0.055 { return true }
      let movement = remaining / max(simd_length(remaining), 1)
      run.step(.init(movement: movement), deltaTime: 1 / 60)
      if run.outcome != .fighting { return false }
    }
    return false
  }
}
