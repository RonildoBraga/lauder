import RealityKit
import Testing
import simd

@testable import Lauder

@MainActor
struct CoverShieldTests {
  @Test(arguments: [SIMD2<Float>(0, -1), SIMD2(1, 0), SIMD2(0, 1), SIMD2(-1, 0)])
  func theCurvedFrontFacesCoverAndStaysOutsideItsWall(direction: SIMD2<Float>) throws {
    // A wall through the origin with the character at the movement system's contact limit.
    // Check both the original and the bridge camera's larger markers, and both colour pools.
    let level = BrooklynBridge.level
    let bridgeScale = SceneStyle.markerScale(
      cameraOffset: level.cameraOffset, fieldOfView: level.fieldOfView)
    for scale in [Float(1), bridgeScale] {
      let shield = CoverShield(style: SceneStyle(markerScale: scale))
      let anchor = -direction * (PartyBody.radius + PartyMotion.skin)
      for exposed in [false, true] {
        shield.show(at: anchor, toward: direction, exposed: exposed)
        let arc = try #require(
          shield.entity.findEntity(named: exposed ? "cover.exposed" : "cover.protected"))
        let segments = Array(arc.children)
        try #require(segments.count == 9)
        let middle = segments[4].position(relativeTo: nil)
        let first = segments[0].position(relativeTo: nil)
        let last = segments[8].position(relativeTo: nil)
        let endMidpoint = (first + last) / 2
        let bulge = SIMD2(middle.x - endMidpoint.x, middle.z - endMidpoint.z)
        #expect(simd_dot(bulge, direction) > 0, "the curved front points towards the shelter")

        for segment in segments {
          let bounds = segment.visualBounds(relativeTo: nil)
          for x in [bounds.min.x, bounds.max.x] {
            for z in [bounds.min.z, bounds.max.z] {
              #expect(
                simd_dot(SIMD2(x, z), direction) < 0,
                "every segment stays on the body's side of the wall plane")
            }
          }
        }
      }
    }
  }
}
