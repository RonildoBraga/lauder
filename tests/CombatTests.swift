import Testing
import simd

@testable import Lauder

/// The plain-Swift combat core (ADR 0004, M2): sight lines, assisted aim, the hostile's timing
/// and the encounter's cues.
@MainActor
struct CombatTests {
  private let box = PartyMotion.Box(minimum: [-1, -1], maximum: [1, 1])

  @Test
  func aLineIsBlockedOnlyByABoxItCrosses() {
    #expect(!LineOfSight.isClear(from: [-3, 0], to: [3, 0], obstacles: [box]))
    #expect(LineOfSight.isClear(from: [-3, 2], to: [3, 2], obstacles: [box]))
    #expect(LineOfSight.isClear(from: [-3, 0], to: [-1.5, 0], obstacles: [box]))
    let entry = LineOfSight.firstBlock(from: [-3, 0], to: [3, 0], obstacles: [box])
    #expect(abs((entry ?? 0) - 2 / 6) < 0.0001)
    // Along an axis, parallel to a face.
    #expect(!LineOfSight.isClear(from: [0, -3], to: [0, 3], obstacles: [box]))
    #expect(LineOfSight.isClear(from: [1.5, -3], to: [1.5, 3], obstacles: [box]))
  }

  /// On the bridge, the cars before the first tower give cover to both sides.
  @Test
  func carsBeforeTheFirstTowerGiveCoverBothWays() {
    let obstacles = BrooklynBridge.level.obstacles(passageOpen: false)
    let stranger = BrooklynBridge.stranger.standAt
    // In the open lane where the fight begins, each can see the other.
    #expect(LineOfSight.isClear(from: [6.5, 51], to: stranger, obstacles: obstacles))
    // Behind the car to Miki's left.
    #expect(!LineOfSight.isClear(from: [4.6, 51.5], to: stranger, obstacles: obstacles))
    // Off to the right, the car turned across the lane covers him.
    #expect(!LineOfSight.isClear(from: [10.5, 51], to: stranger, obstacles: obstacles))
    // He waits unseen behind that car.
    #expect(
      !LineOfSight.isClear(
        from: [6.5, 51], to: BrooklynBridge.stranger.hiddenAt, obstacles: obstacles)
    )
  }

  @Test
  func assistedAimPicksTheNearestVisibleHostileAhead() {
    let candidates = [
      Targeting.Candidate(id: "far", position: [0, -10]),
      Targeting.Candidate(id: "near", position: [0, -5]),
      Targeting.Candidate(id: "behind", position: [0, 3]),
      Targeting.Candidate(id: "beyond", position: [0, -30]),
    ]
    let all: (SIMD2<Float>, SIMD2<Float>) -> Bool = { _, _ in true }
    #expect(
      Targeting.target(
        from: .zero, facing: [0, -1], candidates: candidates, range: 24, isClear: all) == "near")
    // A hidden one is skipped.
    let notNear: (SIMD2<Float>, SIMD2<Float>) -> Bool = { _, to in to != [0, -5] }
    #expect(
      Targeting.target(
        from: .zero, facing: [0, -1], candidates: candidates, range: 24, isClear: notNear) == "far")
    // Facing away from all but one, that one is taken; with none ahead, the nearest anywhere.
    #expect(
      Targeting.target(
        from: .zero, facing: [0, 1], candidates: candidates, range: 24, isClear: all) == "behind")
    #expect(
      Targeting.target(
        from: .zero, facing: [1, 0], candidates: Array(candidates.prefix(2)), range: 24,
        isClear: all) == "near")
    #expect(
      Targeting.target(
        from: .zero, facing: [0, -1], candidates: [candidates[3]], range: 24, isClear: all) == nil)
  }

  @Test
  func theStrangerStepsOutWaitsThenAimsAndHisFirstShotMisses() {
    var stranger = HostileState(spec: BrooklynBridge.stranger)
    #expect(!stranger.isVisible && !stranger.isTargetable)
    #expect(stranger.step(dt: 1, canHit: true) == nil)
    stranger.reveal()
    #expect(stranger.isVisible)
    _ = run(&stranger, seconds: HostileState.stepOutTime + 0.05, canHit: true)
    #expect(stranger.phase == .waiting)
    #expect(simd_distance(stranger.position, BrooklynBridge.stranger.standAt) < 0.001)
    // Waiting, he never shoots: the moment Miki hesitates.
    #expect(run(&stranger, seconds: 5, canHit: true).isEmpty)
    #expect(!stranger.isTargetable)
    stranger.engage()
    let windUp = BrooklynBridge.stranger.windUp
    #expect(run(&stranger, seconds: windUp - 0.05, canHit: true).isEmpty)
    #expect(run(&stranger, seconds: 0.1, canHit: true) == [.miss])
    #expect(stranger.isTargetable)
    // After recovering and aiming again, a clear line hits and cover blocks.
    let cycle = BrooklynBridge.stranger.recovery + windUp
    #expect(run(&stranger, seconds: cycle, canHit: true) == [.hit])
    #expect(run(&stranger, seconds: cycle, canHit: false) == [.blocked])
    stranger.knockDown()
    #expect(run(&stranger, seconds: 10, canHit: true).isEmpty)
    #expect(!stranger.isTargetable)
  }

  @Test
  func engagedBeforeSteppingOutHeAimsAsSoonAsHeIsInPlace() {
    var stranger = HostileState(spec: BrooklynBridge.stranger)
    stranger.engage()
    stranger.reveal()
    _ = run(&stranger, seconds: HostileState.stepOutTime + 0.02, canHit: true)
    guard case .aiming = stranger.phase else {
      Issue.record("expected aiming, got \(stranger.phase)")
      return
    }
  }

  @Test
  func cuesPlayInTimeOrderOnce() {
    var director = StoryDirector()
    director.start(BrooklynBridge.strangerEncounter.cues)
    #expect(director.step(dt: 0.01).count == 1)
    #expect(director.step(dt: 0.5).isEmpty)
    #expect(director.step(dt: 0.2).count == 1)
    #expect(director.step(dt: 1).count == 1)
    #expect(!director.isPlaying)
    #expect(director.step(dt: 10).isEmpty)
    director.start(BrooklynBridge.strangerEncounter.cues)
    director.stop()
    #expect(director.step(dt: 10).isEmpty)
  }

  private func run(_ hostile: inout HostileState, seconds: Float, canHit: Bool)
    -> [HostileState.Shot]
  {
    var shots: [HostileState.Shot] = []
    let dt = GameWorld.simulationStep
    for _ in 0..<Int((seconds / dt).rounded()) {
      if let shot = hostile.step(dt: dt, canHit: canHit) { shots.append(shot) }
    }
    return shots
  }
}
