import Testing
import simd

@testable import Lauder

@MainActor
struct GrenadeTests {
  @Test
  func aThrowCommitsItsOwnerAndCappedDestination() throws {
    let grenade = try #require(Grenade(from: [2, 1.25, 3], toward: [32, 3], by: .tom))
    #expect(grenade.thrower == .tom && grenade.position == [2, 1.25, 3])
    #expect(grenade.destination == [12, Grenade.clearance, 3])
    #expect(!grenade.hasLanded && !grenade.isFinished)
    #expect(simd_distance(SIMD2(grenade.destination.x, grenade.destination.z), [2, 3]) == 10)
  }

  @Test
  func invalidLaunchesAndTimeCannotCreateAProjectileOrAdvanceOne() throws {
    for start: SIMD3<Float> in [[.nan, 1, 0], [0, .infinity, 0], [0, -1, 0]] {
      #expect(Grenade(from: start, toward: .zero, by: .tom) == nil)
    }
    for target: SIMD2<Float> in [[.nan, 0], [.infinity, 0]] {
      #expect(Grenade(from: [0, 1.25, 0], toward: target, by: .tom) == nil)
    }
    var grenade = try #require(Grenade(from: [0, 1.25, 0], toward: [0, -8], by: .tom))
    for dt: Float in [0, -1, .nan, .infinity] {
      let result = grenade.step(dt: dt, trace: unobstructed)
      #expect(result == nil && grenade.position == grenade.start && !grenade.hasLanded)
    }
  }

  @Test
  func theArcLandsBeforeItsGroundedFuseAndExplodesExactlyOnce() throws {
    var grenade = try #require(Grenade(from: [0, 1.25, 0], toward: [0, -8], by: .tom))
    let midpoint = grenade.step(dt: Grenade.flightDuration / 2, trace: unobstructed)
    #expect(midpoint == nil && !grenade.hasLanded)
    #expect(grenade.position.y > 3 && abs(grenade.position.z + 4) < 0.001)
    let landing = grenade.step(dt: Grenade.flightDuration / 2 + 0.001, trace: unobstructed)
    #expect(landing == nil && grenade.hasLanded && !grenade.isFinished)
    #expect(simd_distance(grenade.position, grenade.destination) < 0.001)
    let beforeFuse = grenade.step(dt: Grenade.fuseDuration - 0.02, trace: unobstructed)
    #expect(beforeFuse == nil && !grenade.isFinished)
    let blast = grenade.step(dt: 0.02, trace: unobstructed)
    let point = try #require(blast)
    #expect(point == grenade.destination)
    #expect(grenade.isFinished)
    let repeated = grenade.step(dt: 5, trace: unobstructed)
    #expect(repeated == nil)
  }

  @Test
  func aLargeStepUsesShortRealCollisionSegmentsAndStillBlastsOnce() throws {
    var grenade = try #require(Grenade(from: [0, 1.25, 0], toward: [0, -8], by: .tom))
    var segments = 0
    var largest: Float = 0
    let blast = grenade.step(dt: .greatestFiniteMagnitude) { from, to in
      segments += 1
      largest = max(largest, simd_distance(from, to))
      return unobstructed(from, to)
    }
    let point = try #require(blast)
    #expect(point == grenade.destination)
    #expect(grenade.isFinished)
    #expect(segments >= 90 && segments <= 92 && largest < 0.2)
  }

  @Test(arguments: [Float(1), 6])
  func theSameArcClearsLowCoverButStopsOutsideATallWall(height: Float) throws {
    let wall = Level.Box.box("wall", at: [0, height / 2, -4], size: [8, height, 0.5])
    let ballistics = Ballistics(level: yard(boxes: [wall]))
    var grenade = try #require(Grenade(from: [0, 1.25, 0], toward: [0, -8], by: .tom))
    var blast: SIMD3<Float>?
    for _ in 0..<240 where blast == nil {
      blast = grenade.step(dt: 1 / 120) { from, to in
        ballistics.trace(
          from: from, direction: to - from, range: simd_distance(from, to), targets: [])
      }
    }
    let point = try #require(blast)
    if height == 1 {
      #expect(simd_distance(point, grenade.destination) < 0.001)
    } else {
      #expect(point.z > -3.75 && point.z < -3.6, "impact backs off outside the wall")
      #expect(ballistics.isClear(from: point, to: [0, point.y, 0]))
      #expect(!ballistics.isClear(from: point, to: [0, point.y, -8]))
    }
    #expect(point.y >= Grenade.clearance && grenade.isFinished)
  }

  @Test
  func anImpactStartsItsOwnFuseAndNeverMovesThroughTheObstacle() throws {
    var grenade = try #require(Grenade(from: [0, 1.25, 0], toward: [0, -8], by: .tom))
    let first = grenade.step(dt: 0.01) { from, to in
      Ballistics.Trace(start: from, end: (from + to) / 2, strike: .scenery)
    }
    let impact = grenade.position
    #expect(first == nil && grenade.hasLanded && !grenade.isFinished)
    #expect(
      impact == grenade.start,
      "a contact shorter than clearance keeps the exact previous free point")
    let waiting = grenade.step(dt: Grenade.fuseDuration - 0.02, trace: unobstructed)
    #expect(waiting == nil && grenade.position == impact)
    let blast = grenade.step(dt: 0.03, trace: unobstructed)
    #expect(blast == impact && grenade.isFinished)
  }

  @Test
  func invalidCollisionDataDiscardsTheProjectileWithoutProducingDamage() throws {
    var grenade = try #require(Grenade(from: [0, 1.25, 0], toward: [0, -8], by: .tom))
    let blast = grenade.step(dt: 1 / 120) { from, _ in
      Ballistics.Trace(start: from, end: [.nan, 0, 0], strike: .scenery)
    }
    #expect(blast == nil && grenade.isFinished)
    #expect(grenade.position.indices.allSatisfy { grenade.position[$0].isFinite })
    let repeated = grenade.step(dt: 5, trace: unobstructed)
    #expect(repeated == nil)
  }

  @Test(arguments: [(Float(0), 180), (1.5, 120), (3, 60), (3.001, 0)])
  func blastFalloffHasBoundedCentreAndEdgeDamage(distance: Float, expected: Int) {
    #expect(Grenade.damage(at: distance) == expected)
  }

  @Test
  func invalidBlastDistancesNeverDealDamage() {
    for distance: Float in [-1, .nan, .infinity] { #expect(Grenade.damage(at: distance) == 0) }
  }

  private func unobstructed(_ from: SIMD3<Float>, _ to: SIMD3<Float>) -> Ballistics.Trace {
    Ballistics.Trace(start: from, end: to, strike: .nothing)
  }

  private func yard(boxes: [Level.Box]) -> Level {
    Level(
      id: "grenade-test", ground: TestYard.ground, boxes: boxes, triggers: [], party: [.tom],
      spawns: [.miki: .zero, .laura: [-1, 1], .tom: [1, 1]], heading: [0, -1],
      cameraOffset: [0, 10, 10], fieldOfView: 42, opening: "A yard.", objective: "Explore.",
      lookAround: "Ground.", restartNote: "Restart.")
  }
}
