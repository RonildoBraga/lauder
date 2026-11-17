import RealityKit
import Testing
import simd

@testable import Lauder

@MainActor
struct PartySoakTests {
  @Test(arguments: [UInt64(0xC011_1DE0), 0xC011_1DE1, 0xC011_1DE2, 0xC011_1DE3])
  func authoredPartySurvivesMixedWallContactAndLeaderChanges(seed: UInt64) throws {
    let world = GameWorld()
    let members = PartyMember.allCases
    let bodies = try members.map { member in
      try #require(world.root.findEntity(named: "party.\(member.rawValue)"))
    }
    let bounds = authoredBounds()
    let motion = PartyMotion(
      radius: PrototypeLayout.characterRadius, obstacles: PrototypeLayout.obstacles)
    var random = Generator(state: seed)
    var segment = Segment(kind: .free, movement: .zero)
    var remaining = 0
    var coverage = [0, 0, 0]
    var switches = 0

    for frame in 0..<5_000 {
      if frame > 0 && frame % 211 == 0 {
        world.session.cycleLeader()
        if random.next(upperBound: 2) == 1 { world.session.cycleLeader() }
        switches += 1
      }
      let previous = bodies.map { SIMD2($0.position.x, $0.position.z) }
      let leader = previous[members.firstIndex(of: world.session.leader)!]
      if remaining == 0 {
        segment = nextSegment(random: &random, position: leader, bounds: bounds)
        remaining = 40 + random.next(upperBound: 141)
        coverage[segment.kind.rawValue] += 1
      }
      remaining -= 1
      let movement: SIMD2<Float>
      if let wall = segment.wall {
        movement = wallMovement(
          position: leader, bounds: bounds[wall], clockwise: segment.clockwise,
          angle: segment.angle)
      } else {
        movement = segment.movement
      }
      let dt = deltaTime(frame: frame, cadence: Int(seed % 4))
      world.advanceParty(movement: movement, deltaTime: dt)
      guard world.diagnostic == nil else {
        Issue.record("seed \(seed), frame \(frame): \(world.diagnostic ?? "unknown hold")")
        return
      }

      for (index, body) in bodies.enumerated() {
        let position = SIMD2(body.position.x, body.position.z)
        guard position.x.isFinite, position.y.isFinite, body.position.y.isFinite else {
          Issue.record("seed \(seed), frame \(frame), \(members[index]): nonfinite position")
          return
        }
        let travel = simd_distance(previous[index], position)
        // A carried fixed-step remainder can add at most one step to a frame, and a companion
        // may catch up at a little more than the leader's speed.
        let factor: Float =
          members[index] == world.session.leader ? 1 : CompanionMotor.catchUpFactor
        let maximum =
          PrototypeLayout.speed * factor * (min(dt, 1 / 30) + GameWorld.simulationStep) + 0.003
        guard travel <= maximum else {
          Issue.record(
            "seed \(seed), frame \(frame), \(members[index]): travel \(travel) exceeds \(maximum)")
          return
        }
        // This oracle is independent of PartyMotion's sweep and obstacle conversion.
        let clearance = bounds.reduce(Float.infinity) { min($0, $1.distance(to: position)) }
        // The 2 mm skin must survive, not only non-penetration; 5 µm allows Float rounding.
        guard clearance >= PrototypeLayout.characterRadius + PartyMotion.skin - 0.000005 else {
          Issue.record(
            "seed \(seed), frame \(frame), \(members[index]): inside the skin at \(position), clearance \(clearance)"
          )
          return
        }
        if frame % 125 == 0 {
          let canEscape = (0..<16).contains { direction in
            let angle = Float(direction) * 2 * .pi / 16
            let delta = SIMD2(cos(angle), sin(angle)) * 0.04
            return simd_distance(motion.resolve(start: position, delta: delta), position) > 0.00001
          }
          guard canEscape else {
            Issue.record(
              "seed \(seed), frame \(frame), \(members[index]): all 16 escape directions refused at \(position)"
            )
            return
          }
        }
      }
    }
    #expect(coverage.allSatisfy { $0 > 0 }, "seed \(seed): every heading family was exercised")
    #expect(switches > 0)
    #expect(world.diagnostic == nil)
  }

  private enum Heading: Int {
    case wall, free, keyboard
  }

  private struct Segment {
    let kind: Heading
    let movement: SIMD2<Float>
    var wall: Int?
    var clockwise = false
    var angle: Float = 0
  }

  private struct Bounds {
    let minimum: SIMD2<Float>
    let maximum: SIMD2<Float>

    init(position: SIMD3<Float>, size: SIMD3<Float>) {
      let centre = SIMD2(position.x, position.z)
      let halfSize = SIMD2(size.x, size.z) / 2
      minimum = centre - halfSize
      maximum = centre + halfSize
    }

    func nearest(to point: SIMD2<Float>) -> SIMD2<Float> {
      SIMD2(
        min(max(point.x, minimum.x), maximum.x),
        min(max(point.y, minimum.y), maximum.y))
    }

    func distance(to point: SIMD2<Float>) -> Float {
      simd_distance(point, nearest(to: point))
    }
  }

  private struct Generator {
    var state: UInt64

    mutating func next(upperBound: Int) -> Int {
      Int(next() % UInt64(upperBound))
    }

    mutating func unit() -> Float {
      Float(next() >> 40) / Float(1 << 24)
    }

    private mutating func next() -> UInt64 {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return state
    }
  }

  private func authoredBounds() -> [Bounds] {
    let scenery = PrototypeLayout.boxes.filter { $0.id != .ground }.map {
      Bounds(position: $0.position, size: $0.size)
    }
    let landmarks = PrototypeLayout.points.map { point in
      let size =
        point.id == .transmitter ? PrototypeLayout.transmitterSize : PrototypeLayout.regulatorSize
      return Bounds(position: point.position, size: size)
    }
    return scenery + landmarks
  }

  private func nextSegment(
    random: inout Generator, position: SIMD2<Float>, bounds: [Bounds]
  ) -> Segment {
    switch random.next(upperBound: 10) {
    case 0..<4:
      let wall = bounds.indices.min {
        bounds[$0].distance(to: position) < bounds[$1].distance(to: position)
      }!
      let angles: [Float] = [0.5, 2.5, 13]
      return Segment(
        kind: .wall, movement: .zero, wall: wall,
        clockwise: random.next(upperBound: 2) == 0,
        angle: angles[random.next(upperBound: angles.count)] * .pi / 180)
    case 4..<8:
      let angle = random.unit() * 2 * .pi
      let strength = 0.25 + random.unit() * 0.75
      return Segment(kind: .free, movement: SIMD2(cos(angle), sin(angle)) * strength)
    default:
      let headings: [SIMD2<Float>] = [
        [0, 1], [1, 1], [1, 0], [1, -1], [0, -1], [-1, -1], [-1, 0], [-1, 1],
      ]
      return Segment(
        kind: .keyboard, movement: headings[random.next(upperBound: headings.count)])
    }
  }

  private func wallMovement(
    position: SIMD2<Float>, bounds: Bounds, clockwise: Bool, angle: Float
  ) -> SIMD2<Float> {
    let offset = position - bounds.nearest(to: position)
    let distance = simd_length(offset)
    guard distance > 0 else { return .zero }
    let normal = offset / distance
    let direction: SIMD2<Float>
    if distance > PrototypeLayout.characterRadius + 0.015 {
      direction = -normal
    } else {
      let tangent = SIMD2(-normal.y, normal.x) * (clockwise ? 1 : -1)
      direction = tangent * cos(angle) - normal * sin(angle)
    }
    // Convert the authored wall's world heading back to the same screen-relative stick
    // coordinates consumed by GameWorld. No collision result is manufactured in the test.
    let offsetToCamera = SIMD2(PrototypeLayout.cameraOffset.x, PrototypeLayout.cameraOffset.z)
    let forward = -simd_normalize(offsetToCamera)
    let right = SIMD2(-forward.y, forward.x)
    return SIMD2(simd_dot(direction, right), simd_dot(direction, forward))
  }

  private func deltaTime(frame: Int, cadence: Int) -> Float {
    switch cadence {
    case 0: 1 / 60
    case 1: 1 / 120
    case 2: [Float(1) / 120, 1 / 60, 1 / 30, 1 / 75][frame % 4]
    default: [Float(1) / 30, 1 / 120, 1 / 90, 1 / 60, 1 / 120][frame % 5]
    }
  }
}
