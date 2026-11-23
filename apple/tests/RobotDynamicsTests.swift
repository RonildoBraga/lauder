import Testing
import simd

@testable import Lauder

struct RobotDynamicsTests {
  @Test
  func theCriticalImpulseHasThePhysicalSpringResponse() {
    var spring = RobotDynamics(frequency: 2, damping: 1)
    spring.impulse([1, 0, 0])
    for frame in 1...60 {
      let time = Float(frame) / 60
      let value = spring.advance(to: .zero, dt: 1 / 60)
      #expect(abs(value.x - time * exp(-4 * .pi * time)) < 0.000001)
    }
  }

  @Test(arguments: [Float(0.2), 1, 2])
  func highFrequencyRemainsStableAcrossDampingRegimes(damping: Float) {
    var spring = RobotDynamics(frequency: 24, damping: damping, initialResponse: 1)
    let target = SIMD3<Float>(1, -2, 0.5)
    for _ in 0..<90 {
      let value = spring.advance(to: target, dt: 1 / 15)
      #expect(value.x.isFinite && value.y.isFinite && value.z.isFinite)
      #expect(simd_length(value) < 10)
    }
    #expect(simd_distance(spring.value, target) < 0.0001)
  }

  @Test
  func aLinearTargetIsIndependentOfFramePartition() {
    func result(hz: Int) -> RobotDynamics {
      var spring = RobotDynamics(frequency: 3, damping: 0.7, initialResponse: 0.6)
      for frame in 1...hz {
        let time = Float(frame) / Float(hz)
        spring.advance(to: [time * 0.3, -time, time * 0.2], dt: 1 / Float(hz))
      }
      return spring
    }
    let reference = result(hz: 120)
    for hz in [15, 30, 60] {
      let divided = result(hz: hz)
      #expect(simd_distance(divided.value, reference.value) < 0.00002)
      #expect(simd_distance(divided.velocity, reference.velocity) < 0.00002)
    }
  }

  @Test
  func initialResponseControlsAnticipationAndPauseDoesNotAccumulateInput() {
    var resist = RobotDynamics(frequency: 2, damping: 0.8, initialResponse: -1)
    var follow = RobotDynamics(frequency: 2, damping: 0.8)
    var anticipate = RobotDynamics(frequency: 2, damping: 0.8, initialResponse: 1)
    let target = SIMD3<Float>(repeating: 1)
    #expect(resist.advance(to: target, dt: 1 / 60).x < 0)
    #expect(anticipate.advance(to: target, dt: 1 / 60).x > follow.advance(to: target, dt: 1 / 60).x)
    let value = anticipate.value
    let velocity = anticipate.velocity
    for dt: Float in [0, -1, .nan, .infinity] {
      anticipate.advance(to: [-5, 8, 2], dt: dt)
      #expect(anticipate.value == value)
      #expect(anticipate.velocity == velocity)
    }
    anticipate.reset(to: target)
    #expect(anticipate.velocity == .zero)
    #expect(anticipate.advance(to: target, dt: 1 / 60) == target)
  }
}
