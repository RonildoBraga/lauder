import Testing
import simd

@testable import Lauder

@Suite("Leader cover geometry")
struct LeaderCoverTests {
  private static let low = Level.Box.box("low", at: [0, 0.5, 0], size: [4, 1, 1])
  private static let tall = Level.Box.box("wall", at: [0, 1.5, 0], size: [4, 3, 1])
  private static let floor = PartyMotion.Box(minimum: [-10, -10], maximum: [10, 10])
  private static let towardWall: SIMD2<Float> = [0, -1]

  @Test
  func entersAndLeavesByBodyEdgeProximityWithoutMovingTheAnchor() throws {
    let cover = LeaderCover(boxes: [Self.low], ground: Self.floor)
    let boundary: SIMD2<Float> = [0, 0.5 + PartyBody.radius + LeaderCover.proximity]
    let shelter = try #require(cover.shelter(at: boundary, facing: Self.towardWall))
    #expect(shelter.boxID == "low" && shelter.normal == [0, 1] && shelter.isLow)
    #expect(cover.shelter(at: boundary + [0, 0.001], facing: Self.towardWall) == nil)
    #expect(cover.shelter(at: .zero, facing: Self.towardWall) == nil)
    #expect(cover.firingPoint(from: boundary, in: shelter, facing: Self.towardWall) == boundary)
    #expect(cover.firingPoint(from: [0, 4], in: shelter, facing: Self.towardWall) == nil)
  }

  @Test
  func theShoulderHeightBoundaryCountsAsTallCover() throws {
    let block = Level.Box.box("shoulder", at: [0, 0.625, 0], size: [4, 1.25, 1])
    let cover = LeaderCover(boxes: [block])
    let shelter = try #require(cover.shelter(at: [0, 1], facing: Self.towardWall))
    #expect(!shelter.isLow)
    #expect(cover.firingPoint(from: [0, 1], in: shelter, facing: Self.towardWall) == nil)
  }

  @Test
  func coverProtectsFromTheWallSideButNotAnOpenFlank() throws {
    let cover = LeaderCover(boxes: [Self.low])
    let body: SIMD2<Float> = [0, 1]
    let shelter = try #require(cover.shelter(at: body, facing: Self.towardWall))
    let concealed = cover.incomingBlockers(in: shelter, exposed: false)
    #expect(!LineOfSight.isClear(from: [0, -5], to: body, obstacles: concealed))
    #expect(LineOfSight.isClear(from: [5, 1], to: body, obstacles: concealed))
    let exposed = cover.incomingBlockers(in: shelter, exposed: true)
    #expect(LineOfSight.isClear(from: [0, -5], to: body, obstacles: exposed))
  }

  @Test
  func raisingAtALowBlockDoesNotRemoveTallCover() throws {
    let second = Level.Box.box("second", at: [0, 1.5, -3], size: [4, 3, 1])
    let cover = LeaderCover(boxes: [Self.low, second])
    let body: SIMD2<Float> = [0, 1]
    let shelter = try #require(cover.shelter(at: body, facing: Self.towardWall))
    let exposed = cover.incomingBlockers(in: shelter, exposed: true)
    #expect(exposed.count == 1)
    #expect(!LineOfSight.isClear(from: [0, -5], to: body, obstacles: exposed))
    #expect(cover.incomingBlockers(in: nil, exposed: true).count == 1)
  }

  @Test
  func standingAwayFromLowCoverDoesNotReceiveItsProtection() {
    let cover = LeaderCover(boxes: [Self.low])
    let standing: SIMD2<Float> = [0, 4]
    let shelter = cover.shelter(at: standing, facing: Self.towardWall)
    #expect(shelter == nil)
    for exposed in [false, true] {
      let blockers = cover.incomingBlockers(in: shelter, exposed: exposed)
      #expect(blockers.isEmpty)
      #expect(LineOfSight.isClear(from: [0, -5], to: standing, obstacles: blockers))
    }
  }

  @Test
  func aTallWallHasNoAngleInItsMiddleButCanBePeekedAtItsEnd() throws {
    let cover = LeaderCover(boxes: [Self.tall], ground: Self.floor)
    let middle: SIMD2<Float> = [0, 1]
    let middleShelter = try #require(cover.shelter(at: middle, facing: Self.towardWall))
    #expect(cover.firingPoint(from: middle, in: middleShelter, facing: Self.towardWall) == nil)
    let edge: SIMD2<Float> = [1.8, 1]
    let shelter = try #require(cover.shelter(at: edge, facing: Self.towardWall))
    let peek = try #require(cover.firingPoint(from: edge, in: shelter, facing: Self.towardWall))
    #expect(peek.x > 2 + PartyBody.radius && peek.y == edge.y)
    let blockers = cover.incomingBlockers(in: shelter, exposed: true)
    #expect(blockers.count == 1)
    #expect(LineOfSight.isClear(from: peek, to: peek + [0, -8], obstacles: blockers))
    #expect(!LineOfSight.isClear(from: edge, to: edge + [0, -8], obstacles: blockers))
    #expect(
      PartyMotion(radius: PartyBody.radius, obstacles: blockers).canTraverse(from: edge, to: peek))
  }

  @Test
  func firingAwayFromATallWallDoesNotInventASideStep() throws {
    let cover = LeaderCover(boxes: [Self.tall])
    let point: SIMD2<Float> = [0, 1]
    let shelter = try #require(cover.shelter(at: point, facing: Self.towardWall))
    #expect(cover.firingPoint(from: point, in: shelter, facing: [0, 1]) == point)
  }

  @Test
  func aPeekCannotPutTheBodyIntoAnotherBlock() throws {
    let obstruction = Level.Box.box("beside", at: [2.75, 1.5, 1], size: [0.6, 3, 1])
    let cover = LeaderCover(boxes: [Self.tall, obstruction], ground: Self.floor)
    let point: SIMD2<Float> = [1.8, 1]
    let shelter = try #require(cover.shelter(at: point, facing: Self.towardWall))
    #expect(shelter.boxID == "wall")
    #expect(cover.firingPoint(from: point, in: shelter, facing: Self.towardWall) == nil)
  }

  @Test
  func aPeekCannotLeaveTheGround() throws {
    let floor = PartyMotion.Box(minimum: [-10, -10], maximum: [2.45, 10])
    let cover = LeaderCover(boxes: [Self.tall], ground: floor)
    let point: SIMD2<Float> = [1.8, 1]
    let shelter = try #require(cover.shelter(at: point, facing: Self.towardWall))
    #expect(cover.firingPoint(from: point, in: shelter, facing: Self.towardWall) == nil)
  }

  @Test
  func invalidPointsNeverProduceCoverOrAPeek() throws {
    let cover = LeaderCover(boxes: [Self.tall])
    #expect(cover.shelter(at: [.nan, 1], facing: Self.towardWall) == nil)
    #expect(cover.shelter(at: [0, 1], facing: [.infinity, 0]) == nil)
    let shelter = try #require(cover.shelter(at: [1.8, 1], facing: Self.towardWall))
    #expect(cover.firingPoint(from: [1.8, 1], in: shelter, facing: .zero) == nil)
    #expect(cover.firingPoint(from: [.nan, 1], in: shelter, facing: Self.towardWall) == nil)
  }
}
