import Testing
import simd

@testable import Lauder

/// An ordered or sheltered companion makes way before the leader reaches their body,
/// without losing the static place they should return to afterwards.
@MainActor
struct CompanionYieldTests {
  private let grid = NavigationGrid(level: TestYard.level)
  private let motion = PartyMotion(radius: PartyBody.radius, obstacles: TestYard.obstacles)
  private let spot = SIMD2<Float>(-5, 5)
  private let dt: Float = 1 / 120

  @Test(arguments: PartyMember.allCases)
  func aSettledCompanionYieldsBeforeTheApproachingLeaderCrowdsThem(member: PartyMember) {
    var motor = CompanionMotor(for: member)
    let leader = spot - SIMD2<Float>(0, 1)
    #expect(step(&motor, from: spot, leader: leader, velocity: .zero) == .zero)
    #expect(motor.isSettled)

    // One metre leaves both crowding and personal-space thresholds clear. The predicted
    // crossing, rather than an already overlapping body, must wake an immediate side step.
    let delta = step(&motor, from: spot, leader: leader, velocity: [0, PartyBody.speed])
    #expect(abs(delta.x) > 0 && abs(delta.y) < abs(delta.x))
    #expect(!motor.isSettled)
  }

  @Test(arguments: [SIMD2<Float>.zero, SIMD2<Float>(PartyBody.speed, 0)])
  func aStationaryOrPassingParallelLeaderDoesNotDisplaceTheCompanion(velocity: SIMD2<Float>) {
    var motor = CompanionMotor(for: .laura)
    let leader = spot - SIMD2<Float>(0, 1)
    _ = step(&motor, from: spot, leader: leader, velocity: .zero)
    #expect(motor.isSettled)
    #expect(step(&motor, from: spot, leader: leader, velocity: velocity) == .zero)
    #expect(motor.isSettled)
  }

  @Test
  func yieldingLeavesRoomForTheLeaderThenReturnsToTheSameOrderedSpot() {
    var motor = CompanionMotor(for: .tom)
    var companion = spot
    var leader = spot - SIMD2<Float>(0, 1.2)
    _ = step(&motor, from: companion, leader: leader, velocity: .zero)
    var nearest = Float.infinity
    var widestSideStep: Float = 0
    for frame in 0..<480 {
      let velocity = frame < 120 ? SIMD2<Float>(0, PartyBody.speed) : .zero
      leader += velocity * dt
      let requested = step(&motor, from: companion, leader: leader, velocity: velocity)
      let next = motion.resolve(start: companion, delta: requested)
      motor.absorb(next - companion, dt: dt)
      companion = next
      nearest = min(nearest, simd_distance(companion, leader))
      widestSideStep = max(widestSideStep, abs(companion.x - spot.x))
    }
    #expect(nearest >= 2 * PartyBody.radius, "Closest leader gap was \(nearest) m")
    #expect(widestSideStep > PartyBody.radius)
    #expect(simd_distance(companion, spot) <= CompanionMotor.settleDistance)
    #expect(motor.isSettled && !motor.cannotReach)
  }

  private func step(
    _ motor: inout CompanionMotor, from position: SIMD2<Float>, leader: SIMD2<Float>,
    velocity: SIMD2<Float>
  ) -> SIMD2<Float> {
    motor.step(
      from: position,
      context: .init(
        target: spot, leaderPosition: leader, leaderVelocity: velocity, others: [leader],
        speed: PartyBody.speed, dt: dt, targetMoves: false),
      grid: grid, isClear: { motion.canTraverse(from: $0, to: $1) })
  }
}
