import Testing
import simd

@testable import Lauder

struct CameraRigTests {
  @Test
  func switchingStartsAtTheCurrentViewThenResumesFollowingTheNewLeader() {
    var rig = CameraRig(offset: [0, 10, 12], fieldOfView: 20, over: .zero)
    let before = rig.target
    rig.switchLeader()
    rig.update(over: [10, 0], lean: .zero, close: false, deltaTime: 0)
    #expect(rig.target == before, "a switch does not teleport the camera")
    rig.update(over: [10, 0], lean: .zero, close: false, deltaTime: 0.125)
    #expect(abs(rig.target.x - 5) < 0.0001, "halfway through the switch")
    rig.update(over: [10, 0], lean: .zero, close: false, deltaTime: 0.125)
    #expect(abs(rig.target.x - 10) < 0.0001)
    rig.update(over: [11, 0], lean: .zero, close: false, deltaTime: 1 / 60)
    #expect(abs(rig.target.x - 11) < 0.0001, "the completed switch keeps following")
  }

  @Test
  func resetDropsTheOldSwitchLeanAndAimingLens() {
    let point = SIMD2<Float>(-7, 100)
    let offset = SIMD3<Float>(0, 10, 12)
    var rig = CameraRig(offset: offset, fieldOfView: 20, over: .zero)
    rig.update(over: [2, 3], lean: [3, 0], close: true, deltaTime: 0.15)
    rig.switchLeader()
    rig.update(over: [20, 30], lean: [3, 0], close: true, deltaTime: 0.1)
    #expect(rig.lens < 20)

    rig.reset(over: point)
    var fresh = CameraRig(offset: offset, fieldOfView: 20, over: point)
    #expect(rig.target == fresh.target && rig.eye == fresh.eye && rig.lens == fresh.lens)
    rig.update(over: point, lean: .zero, close: false, deltaTime: 1 / 60)
    fresh.update(over: point, lean: .zero, close: false, deltaTime: 1 / 60)
    #expect(
      rig.target == fresh.target && rig.lens == fresh.lens,
      "the interrupted transition cannot resume after Restart or retry")
  }
}
