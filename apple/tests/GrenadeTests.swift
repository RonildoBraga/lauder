import RealityKit
import Testing
import simd

@testable import Lauder

@MainActor
struct GrenadeTests {
  @Test
  func aFuseExpiresOnceWithoutAnImmediateHit() {
    var grenade = Grenade(id: 1, owner: "thrower", from: [0, -5], at: .zero)
    #expect(grenade.remaining == Grenade.fuse)
    let advanced1 = grenade.advance(dt: Grenade.fuse - 0.001)
    #expect(!advanced1)
    #expect(grenade.remaining > 0)
    let advanced2 = grenade.advance(dt: 0.002)
    #expect(advanced2)
    #expect(grenade.remaining == 0)
    let advanced3 = grenade.advance(dt: 1)
    #expect(!advanced3)
  }

  @Test
  func aLongStepStillDetonatesOnlyOnceAndInvalidTimeDoesNothing() {
    var grenade = Grenade(id: 1, owner: "thrower", from: .zero, at: [3, 4])
    for dt: Float in [0, -1, .nan, .infinity, -.infinity] {
      let advanced4 = grenade.advance(dt: dt)
      #expect(!advanced4)
      #expect(grenade.remaining == Grenade.fuse)
    }
    let advanced5 = grenade.advance(dt: 100)
    #expect(advanced5)
    let advanced6 = grenade.advance(dt: 100)
    #expect(!advanced6)
  }

  @Test
  func theLandingPointDoesNotHomeAndTheArcArrivesBeforeTheFuse() {
    var grenade = Grenade(id: 7, owner: "thrower", from: [0, -6], at: [4, 2])
    #expect(grenade.projectilePosition == [0, Grenade.launchHeight, -6])
    let advanced7 = grenade.advance(dt: Grenade.flightTime / 2)
    #expect(!advanced7)
    let middle = grenade.projectilePosition
    #expect(simd_distance(SIMD2(middle.x, middle.z), [2, -2]) < 0.001)
    #expect(middle.y > Grenade.launchHeight)
    let advanced8 = grenade.advance(dt: Grenade.flightTime / 2 + 0.001)
    #expect(!advanced8)
    let landed = grenade.projectilePosition
    #expect(simd_distance(landed, [4, Grenade.landingHeight, 2]) < 0.001)
    #expect(grenade.remaining > 1)
    let advanced9 = grenade.advance(dt: 0.5)
    #expect(!advanced9)
    #expect(grenade.projectilePosition == landed)
    #expect(grenade.position == [4, 2] && grenade.start == [0, -6])
  }

  @Test
  func everyPointInTheMarkedRadiusIsIncludedAndOutsideItIsNot() {
    let grenade = Grenade(id: 1, owner: "thrower", from: [0, -5], at: .zero)
    for point: SIMD2<Float> in [
      .zero, [Grenade.radius, 0], [-Grenade.radius, 0], [0, Grenade.radius], [0, -Grenade.radius],
    ] {
      #expect(grenade.contains(point))
    }
    #expect(!grenade.contains([Grenade.radius + 0.001, 0]))
    #expect(!grenade.contains([0, -Grenade.radius - 0.001]))
    #expect(!grenade.contains([.nan, 0]) && !grenade.contains([0, .infinity]))
  }

  @Test
  func readingAPausedGrenadeCannotAdvanceItsFuseOrFlight() {
    var grenade = Grenade(id: 1, owner: "thrower", from: [0, -5], at: .zero)
    _ = grenade.advance(dt: 0.2)
    let remaining = grenade.remaining
    let projectile = grenade.projectilePosition
    for _ in 0..<100 {
      _ = grenade.contains([1, 0])
      #expect(grenade.projectilePosition == projectile && grenade.remaining == remaining)
    }
  }

  @Test
  func theReusableMarkerShowsTheRealRadiusWithoutCameraScaling() throws {
    let marker = GrenadeMarker(style: SceneStyle(markerScale: 3))
    let entity = marker.entity
    let count = entity.children.count
    let warning = try #require(entity.findEntity(named: "grenade.warning"))
    let urgent = try #require(entity.findEntity(named: "grenade.urgent"))
    let countdown = try #require(entity.findEntity(named: "grenade.countdown"))
    let projectile = try #require(entity.findEntity(named: "grenade.projectile"))
    var grenade = Grenade(id: 1, owner: "thrower", from: [0, -5], at: [3, 4])
    marker.show(grenade)
    #expect(entity.isEnabled && entity.position == [3, 0, 4] && entity.scale == [1, 1, 1])
    let bounds = warning.visualBounds(relativeTo: entity)
    #expect(abs(bounds.extents.x - Grenade.radius * 2) < 0.001)
    #expect(abs(bounds.extents.z - Grenade.radius * 2) < 0.001)
    #expect(warning.isEnabled && !urgent.isEnabled)
    #expect(simd_distance(projectile.position(relativeTo: nil), grenade.projectilePosition) < 0.001)
    _ = grenade.advance(dt: 1.6)
    marker.show(grenade)
    #expect(countdown.scale.x < 0.5 && countdown.scale.x == countdown.scale.z)
    #expect(warning.isEnabled != urgent.isEnabled)
    marker.show(nil)
    #expect(!entity.isEnabled)
    marker.show(Grenade(id: 2, owner: "other", from: [4, -5], at: [-2, 1]))
    #expect(entity.isEnabled && entity.children.count == count && entity.position == [-2, 0, 1])
    _ = grenade.advance(dt: 10)
    marker.show(grenade)
    #expect(!entity.isEnabled)
  }
}
