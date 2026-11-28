import RealityKit
import Testing
import simd

@testable import Lauder

@MainActor
struct CameraRigTests {
  @Test
  func theHeroFollowingViewProjectsBothSpawnedActorsAndTheirFeet() throws {
    let rig = CameraRig(
      offset: WorldCamera.offset, fieldOfView: WorldCamera.fieldOfView, over: DuelArena.heroSpawn)
    let view = rig.projection(aspect: 19.5 / 9)
    for point in [DuelArena.heroSpawn, DuelArena.enemySpawn] {
      let feet = try #require(view.screen(ofGround: point))
      let head = try #require(view.screen(ofWorld: [point.x, 1.85, point.y]))
      #expect(feet.x > 0.1 && feet.x < 0.9 && feet.y > 0.1 && feet.y < 0.9)
      #expect(head.x > 0.1 && head.x < 0.9 && head.y > 0.1 && head.y < 0.9)
      #expect(
        feet.y - head.y > 0.095,
        "the common-size comparison keeps spawned figures near 10% of viewport height")
    }
    #expect(rig.eye == rig.target + WorldCamera.offset)
  }

  @Test
  func comparisonPitchesKeepTheSameCharacterScaleAndDiagonalOrientation() throws {
    var heights: [Float] = []
    for pitch: Float in [30.5, 35, 40] {
      let offset = WorldCamera.offset(forPitch: pitch)
      let rig = CameraRig(offset: offset, fieldOfView: WorldCamera.fieldOfView, over: .zero)
      let view = rig.projection(aspect: 19.5 / 9)
      let feet = try #require(view.screen(ofGround: .zero))
      let head = try #require(view.screen(ofWorld: [0, 1.85, 0]))
      let height = feet.y - head.y
      heights.append(height)
      #expect(abs(height - 0.1010415) < 0.00001)
      let actualPitch = atan2(offset.y, simd_length(SIMD2(offset.x, offset.z))) * 180 / .pi
      #expect(abs(actualPitch - pitch) < 0.0001)
      #expect(offset.x == offset.z, "all three views retain a 45° diagonal orientation")
    }
    let largest = try #require(heights.max())
    let smallest = try #require(heights.min())
    #expect(largest - smallest < 0.00001)
    #expect(WorldCamera.offset(forPitch: .nan) == WorldCamera.offset(forPitch: 35))
  }

  @Test
  func theArenaAxesReadDiagonallyInsteadOfAsAHeadOnGrid() throws {
    let rig = CameraRig(
      offset: WorldCamera.offset, fieldOfView: WorldCamera.fieldOfView, over: .zero)
    let view = rig.projection(aspect: 19.5 / 9)
    let centre = try #require(view.screen(ofGround: .zero))
    let east = try #require(view.screen(ofGround: [1, 0]))
    let south = try #require(view.screen(ofGround: [0, 1]))
    #expect(east.x > centre.x && east.y > centre.y)
    #expect(south.x < centre.x && south.y > centre.y)
    #expect(abs(east.y - centre.y) > 0.02)
    #expect(abs(south.y - centre.y) > 0.02)
  }

  @Test(arguments: [
    SIMD2<Float>(1, 1), [3, 0], [0, 3], [6.6, 4.6], [-6.6, 4.6],
  ])
  func focusedNearAndOppositeCornerPairsFitTheSameLens(hero: SIMD2<Float>) throws {
    for pitch: Float in [30.5, 35, 40] {
      var rig = CameraRig(
        offset: WorldCamera.offset(forPitch: pitch), fieldOfView: WorldCamera.fieldOfView,
        over: DuelArena.heroSpawn)
      let enemy = -hero
      rig.reset(hero: hero, enemy: enemy, isFocused: true)
      let view = rig.projection(aspect: 19.5 / 9)
      for point in [hero, enemy] {
        for height: Float in [0, 1.85] {
          let screen = try #require(view.screen(ofWorld: [point.x, height, point.y]))
          #expect(screen.x > 0.01 && screen.x < 0.99, "\(pitch)° view")
          #expect(screen.y > 0.01 && screen.y < 0.99, "\(pitch)° view")
        }
      }
      #expect(rig.target == [0, 0.85, 0])
    }
  }

  @Test
  func followingIsSmoothAndIndependentOfFrameRate() {
    var atThirty = CameraRig(
      offset: WorldCamera.offset, fieldOfView: WorldCamera.fieldOfView, over: .zero)
    var atSixty = atThirty
    let hero: SIMD2<Float> = [5, 3]
    let enemy: SIMD2<Float> = [1, -1]
    atThirty.update(hero: hero, enemy: enemy, isFocused: true, deltaTime: 1 / 30)
    #expect(atThirty.target.x > 0 && atThirty.target.x < 3)
    #expect(atThirty.target.z > 0 && atThirty.target.z < 1)
    for _ in 1..<30 {
      atThirty.update(hero: hero, enemy: enemy, isFocused: true, deltaTime: 1 / 30)
    }
    for _ in 0..<60 {
      atSixty.update(hero: hero, enemy: enemy, isFocused: true, deltaTime: 1 / 60)
    }
    #expect(simd_distance(atThirty.target, atSixty.target) < 0.00001)
    #expect(simd_distance(atThirty.target, [3, 0.85, 1]) < 0.002)
    #expect(simd_distance(atThirty.eye - atThirty.target, WorldCamera.offset) < 0.00001)
  }

  @Test
  func resetSnapsToTheNewHeroOrFocusedPairWithoutResidualFollow() {
    var rig = CameraRig(
      offset: WorldCamera.offset, fieldOfView: WorldCamera.fieldOfView, over: [5, 4])
    rig.reset(hero: [2, 3], enemy: [-4, 1], isFocused: true)
    #expect(rig.target == [-1, 0.85, 2])
    rig.reset(hero: DuelArena.heroSpawn, enemy: DuelArena.enemySpawn, isFocused: false)
    let expected = SIMD3<Float>(DuelArena.heroSpawn.x, 0.85, DuelArena.heroSpawn.y)
    #expect(rig.target == expected)
    rig.update(
      hero: DuelArena.heroSpawn, enemy: DuelArena.enemySpawn, isFocused: false, deltaTime: 1 / 60)
    #expect(rig.target == expected)
  }

  @Test
  func invalidFrameTimesAndUsedPositionsDoNotPoisonTheCamera() {
    var rig = CameraRig(
      offset: WorldCamera.offset, fieldOfView: WorldCamera.fieldOfView, over: .zero)
    let expected = rig.target
    for delta: Float in [0, -1, .nan, .infinity] {
      rig.update(hero: [3, 2], enemy: [-1, 1], isFocused: true, deltaTime: delta)
      #expect(rig.target == expected)
    }
    rig.update(hero: [.nan, 2], enemy: .zero, isFocused: false, deltaTime: 1 / 60)
    rig.update(hero: [3, 2], enemy: [.infinity, 0], isFocused: true, deltaTime: 1 / 60)
    rig.reset(hero: [.infinity, 2], enemy: .zero, isFocused: false)
    rig.reset(hero: [3, 2], enemy: [.nan, 0], isFocused: true)
    #expect(rig.target == expected)
    rig.reset(hero: [3, 2], enemy: [.nan, .nan], isFocused: false)
    #expect(rig.target == [3, 0.85, 2], "free following does not consume the enemy position")
  }

  @Test
  func projectionAndCameraRelativeMovementShareTheSameFixedOrientation() throws {
    var rig = CameraRig(
      offset: WorldCamera.offset, fieldOfView: WorldCamera.fieldOfView, over: .zero)
    let forward = Movement.direction(for: [0, 1], cameraOffset: rig.offset)
    for focused in [false, true] {
      rig.update(hero: [4, 2], enemy: [-3, -1], isFocused: focused, deltaTime: 0.1)
      let view = rig.projection(aspect: 2)
      let ground = SIMD2<Float>(rig.target.x, rig.target.z)
      let centre = try #require(view.screen(ofGround: ground))
      let moved = try #require(view.screen(ofGround: ground + [forward.x, forward.z]))
      #expect(moved.y < centre.y)
      #expect(abs(moved.x - centre.x) < 0.0001)
    }
  }

  @Test
  func renderedCameraAndGroundProjectionUseTheSameTransformAndVerticalLens() throws {
    let camera = WorldCamera()
    let root = Entity()
    camera.attach(to: root)
    let entity = try #require(root.findEntity(named: "duel.camera") as? PerspectiveCamera)
    for shouldReset in [false, true] {
      if shouldReset {
        camera.reset(hero: [4, 3], enemy: [-2, -1], isFocused: true)
      } else {
        camera.update(hero: [4, 3], enemy: [-2, -1], isFocused: true, deltaTime: 0.1)
      }
      let view = camera.projection(aspect: 19.5 / 9)
      #expect(simd_distance(entity.position, view.eye) < 0.00001)
      let renderedForward = entity.orientation.act(SIMD3<Float>(0, 0, -1))
      #expect(simd_distance(renderedForward, simd_normalize(view.target - view.eye)) < 0.00001)
      #expect(entity.camera.fieldOfViewInDegrees == view.fieldOfView)
      #expect(entity.camera.fieldOfViewOrientation == .vertical)
    }
  }
}
