import Testing
import simd

@testable import Lauder

/// Authored cover must offer actual shelter and usable lanes, without trapping the guard or
/// closing the quiet arch. Native movement and ballistic queries retain their authority.
@MainActor
struct BridgeCoverTests {
  private let rearSlots: [SIMD2<Float>] = [[4.35, 10.9], [8.65, 10.9]]

  @Test
  func theTwoSheltersAreSeparateRoomyAndReachableFromTheCloseSlots() throws {
    _ = try coverBoxes()
    let level = BrooklynBridge.level
    let grid = NavigationGrid(level: level)
    let motion = PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles)
    let leader: SIMD2<Float> = [6.5, 10]
    let closeSlots: [SIMD2<Float>] = [[5.6, 10.9], [7.4, 10.9]]
    #expect(simd_distance(rearSlots[0], rearSlots[1]) > 3)
    for (start, end) in zip(closeSlots, rearSlots) {
      #expect(grid.isWalkable(end) && grid.isRoomy(end), "a shelter is a place to settle")
      #expect(grid.region(at: end) == grid.region(at: leader))
      #expect(simd_distance(end, leader) < 2.6, "cover stays near the returning squad")
      #expect(motion.canTraverse(from: start, to: end))
      #expect(grid.route(from: [6.5, 19], to: end) != nil)
    }
  }

  @Test
  func bothRealMuzzlesAreBlockedDuringPatrolTurningBracingAndFire() throws {
    _ = try coverBoxes()
    let level = BrooklynBridge.level
    let rays = Ballistics(level: level)
    var robot = RobotGuard(home: BrooklynBridge.stranger.standAt, strategicPatterns: true)
    robot.reveal()
    robot.engage()
    let patrolFrames = 120 * 18
    let targets: [SIMD2<Float>] = [[6.5, 10], [11, 4], [7, -2]]
    var phases: [RobotGuard.Phase] = []
    var samples = 0
    for frame in 0..<(patrolFrames + 120 * 36) {
      let fighting = frame >= patrolFrames
      let target = targets[max(0, frame - patrolFrames) / (120 * 12)]
      let visible =
        fighting
        && rays.isClear(
          from: rays.point(robot.position, above: 1.52), to: rays.point(target))
      _ = robot.step(
        dt: 1 / 120, target: target, hasSight: visible, obstacles: level.obstacles,
        party: [], awareOfTarget: fighting)
      if !phases.contains(robot.phase) { phases.append(robot.phase) }
      if frame.isMultiple(of: 30) {
        samples += 1
        for slot in rearSlots {
          for gun in 0..<2 {
            #expect(
              !rays.isClear(from: robot.muzzle(gun: gun), to: rays.point(slot)),
              "gun \(gun) at \(robot.position) must meet real cover before \(slot)")
          }
        }
      }
    }
    #expect(samples > 200)
    for phase in [RobotGuard.Phase.patrol, .notice, .tracking, .committed, .burst, .recovering] {
      #expect(phases.contains(phase), "the test reached native \(phase) poses")
    }
    #expect(robot.shotSerial >= 8, "both ordinary burst patterns ran without state injection")
  }

  @Test
  func theCentreEastFlankAndQuietWestArchRemainTraversable() throws {
    _ = try coverBoxes()
    let level = BrooklynBridge.level
    let motion = PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles)
    let lanes: [(SIMD2<Float>, SIMD2<Float>)] = [
      ([6.5, 19], [6.5, 7]),
      ([11.2, 19], [11.2, -3]),
      ([-6.5, 30], [-6.5, -3]),
      ([-6.5, -3], [-8.5, -8]),
    ]
    for (start, end) in lanes {
      #expect(motion.canTraverse(from: start, to: end), "lane \(start) → \(end)")
    }
    #expect(try #require(BrooklynBridge.strangerEncounter.safeExit).contains([-8.5, -8]))
  }

  @Test
  func newCoverClearsTheWholeGuardFootprintAndItsEastSideApproach() throws {
    let covers = try coverBoxes()
    let level = BrooklynBridge.level
    let robot = RobotGuard(home: BrooklynBridge.stranger.standAt, strategicPatterns: true)
    let area = robot.guardArea
    let motion = PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles)
    for cover in covers {
      let box = cover.footprint
      let gap = simd_max(simd_max(box.minimum - area.maximum, area.minimum - box.maximum), .zero)
      #expect(simd_length(gap) > RobotModelGeometry.navigationRadius + PartyMotion.skin)
    }
    // The east lane can reach a sword stance beside every possible guard-area corner.
    // The native encounter tests still own actual coupling exposure and accepted contacts.
    for x in [area.minimum.x, area.maximum.x] {
      for z in [area.minimum.y, area.maximum.y] {
        let centre = SIMD2(x, z)
        let turn: SIMD2<Float> = [11.2, z]
        let side = centre + [2.65, 0]
        #expect(motion.canTraverse(from: [11.2, 10.9], to: turn))
        #expect(motion.canTraverse(from: turn, to: side))
        let end = GuardCollision.resolve(
          start: turn, delta: side - turn, centre: centre,
          radius: RobotModelGeometry.bodyRadius + PartyBody.radius)
        #expect(simd_distance(end, side) < 0.001, "approach stays outside the living hull")
      }
    }
    for slot in rearSlots {
      #expect(motion.canTraverse(from: slot, to: [11.2, 10.9]))
    }
  }

  private func coverBoxes() throws -> [Level.Box] {
    try ["bridge-cover-west", "bridge-cover-east"].map { name in
      try #require(BrooklynBridge.layout.boxes.first(where: { $0.name == name }))
    }
  }
}
