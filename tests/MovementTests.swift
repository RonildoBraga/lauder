import Testing
import simd

@testable import Lauder

struct MovementTests {
  @Test
  func stickAxesFollowTheFixedCameraWithoutDiagonalSpeedBoost() {
    let offset: SIMD3<Float> = [0, 5, 5]
    #expect(Movement.direction(for: [1, 0], cameraOffset: offset) == [1, 0, 0])
    #expect(Movement.direction(for: [0, 1], cameraOffset: offset) == [0, 0, -1])
    let diagonal = Movement.direction(for: [1, 1], cameraOffset: offset)
    #expect(abs(simd_length(diagonal) - 1) < 0.0001)
    #expect(diagonal.x > 0 && diagonal.z < 0)
  }

  @Test
  func releasedNoisyAndInvalidInputCannotMoveTheCharacter() {
    let offset = RelayHouse.cameraOffset
    for input: SIMD2<Float> in [.zero, [0.05, -0.03], [.nan, 1], [1, .infinity]] {
      #expect(Movement.direction(for: input, cameraOffset: offset) == .zero)
    }
  }
}
