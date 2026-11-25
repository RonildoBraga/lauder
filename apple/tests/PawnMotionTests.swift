import Testing
import simd

@testable import Lauder

/// The pawns' walk and the leader's dodge roll, which move only the figure (the visual
/// direction's pawns have no rig).
struct PawnMotionTests {
  @Test
  func aStandingPawnNeitherLeansNorLifts() {
    let gait = PawnGait()
    #expect(gait.lean(facing: [0, -1]) == .zero && gait.lift == 0)
  }

  @Test
  func walkingBobsOncePerStepAndLeansIntoTheMovement() {
    var gait = PawnGait()
    let dt: Float = 1 / 60
    var highest: Float = 0
    var lowest: Float = 1
    for frame in 0..<120 {
      gait.step(moved: [PartyBody.speed * dt, 0], dt: dt)
      // Measured once the shown speed has caught up with walking speed, after half a second.
      guard frame >= 30 else { continue }
      highest = max(highest, gait.lift)
      lowest = min(lowest, gait.lift)
    }
    #expect(abs(gait.pace - 1) < 0.01)
    #expect(highest > PawnGait.bobHeight * 0.9 && highest <= PawnGait.bobHeight + 0.0001)
    #expect(lowest < 0.01, "it comes down between steps")
    let lean = gait.lean(facing: [1, 0])
    #expect(lean.x > 0, "its top leans the way it walks")
    #expect(simd_length(lean) <= PawnGait.lean + PawnGait.waddle + 0.0001)
  }

  @Test
  func stoppingSettlesTheWalkAndAJumpResetsIt() {
    var gait = PawnGait()
    for _ in 0..<60 { gait.step(moved: [PartyBody.speed / 60, 0], dt: 1 / 60) }
    for _ in 0..<60 { gait.step(moved: .zero, dt: 1 / 60) }
    #expect(gait.pace == 0 && gait.lift == 0)
    for _ in 0..<60 { gait.step(moved: [PartyBody.speed / 60, 0], dt: 1 / 60) }
    gait.step(moved: [5, 0], dt: 1 / 60)
    #expect(gait.velocity == .zero && gait.phase == 0, "a retry puts it somewhere new")
  }

  @Test
  func aRollCoversItsDistanceTuckedAndEndsStandingUpright() {
    var roll = DodgeRoll(member: .miki, direction: [0, 2])
    var travelled = SIMD2<Float>.zero
    var tucked: Float = 1
    while !roll.isFinished {
      travelled += roll.advance(dt: 1 / 60)
      tucked = min(tucked, roll.pose(height: PartyBody.height).scale.y)
    }
    #expect(abs(simd_length(travelled) - DodgeRoll.distance) < 0.0001)
    #expect(abs(travelled.x) < 0.0001 && travelled.y > 0)
    #expect(abs(tucked - DodgeRoll.tuckedHeight) < 0.01)
    let end = roll.pose(height: PartyBody.height)
    #expect(simd_distance(end.scale, [1, 1, 1]) < 0.0001 && simd_length(end.offset) < 0.0001)
    // One whole turn brings it back upright.
    #expect(simd_distance(end.tilt.act([0, 1, 0]), [0, 1, 0]) < 0.0001)
  }
}

@MainActor
struct DodgeRollTests {
  /// Square, X, Space or Roll: the leader tumbles three metres the way they move, then waits a
  /// moment before the next roll; with nothing held, they roll the way they face.
  @Test
  func theLeaderRollsAheadThenWaitsBeforeRollingAgain() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let start = position(world, .miki)
    let ahead: SIMD2<Float> = [0, 1]
    world.advanceParty(movement: ahead, dodgePressed: true, deltaTime: 1 / 60)
    #expect(world.roll?.member == .miki)
    let firstWay = try #require(world.roll?.direction)
    var frames = 1
    while world.roll != nil, frames < 120 {
      // Pressing again mid-roll does nothing.
      world.advanceParty(movement: ahead, dodgePressed: true, deltaTime: 1 / 60)
      frames += 1
    }
    #expect(world.roll == nil)
    #expect(abs(simd_distance(position(world, .miki), start) - DodgeRoll.distance) < 0.05)
    #expect(Float(frames) / 60 < DodgeRoll.duration + 0.05)
    world.advanceParty(movement: .zero, dodgePressed: true, deltaTime: 1 / 60)
    #expect(world.roll == nil, "the next roll waits for the cooldown")
    for _ in 0..<(Int(DodgeRoll.cooldown * 60) + 2) {
      world.advanceParty(movement: .zero, deltaTime: 1 / 60)
    }
    world.advanceParty(movement: .zero, dodgePressed: true, deltaTime: 1 / 60)
    // She turned to face her first roll; with nothing held, the next goes the way she faces.
    let secondWay = try #require(world.roll?.direction, "with nothing held, she rolls")
    #expect(simd_dot(secondWay, firstWay) > 0.999)
    #expect(simd_dot(secondWay, world.facing(of: .miki)) > 0.999)
  }

  /// Switching leader ends a roll, and starts the cooldown as a finished roll does, so nobody
  /// stays untouchable by switching back and forth.
  @Test
  func switchingLeaderEndsARollAndStartsTheCooldown() {
    let world = GameWorld(level: BrooklynBridge.level)
    world.session.recruit(.laura)
    world.advanceParty(movement: .zero, dodgePressed: true, deltaTime: 1 / 60)
    #expect(world.roll?.member == .miki)
    world.session.cycleLeader()
    world.advanceParty(movement: .zero, deltaTime: 1 / 60)
    #expect(world.roll == nil, "the switch ends Miki's roll")
    world.session.cycleLeader()
    world.advanceParty(movement: .zero, dodgePressed: true, deltaTime: 1 / 60)
    #expect(world.roll == nil, "the next roll waits for the cooldown")
    for _ in 0..<(Int(DodgeRoll.cooldown * 60) + 2) {
      world.advanceParty(movement: .zero, deltaTime: 1 / 60)
    }
    world.advanceParty(movement: .zero, dodgePressed: true, deltaTime: 1 / 60)
    #expect(world.roll?.member == .miki)
  }
}
