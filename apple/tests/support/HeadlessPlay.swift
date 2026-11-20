import RealityKit
import Testing
import simd

@testable import Lauder

// Driving a world without rendering, as the world tests do: where the party stands, the stick
// that walks the leader somewhere, and frames of play until something happens.

/// Where a member's body stands on the ground; not a number when the world has no body for them.
@MainActor
func position(_ world: GameWorld, _ member: PartyMember) -> SIMD2<Float> {
  guard let body = world.root.findEntity(named: "party.\(member.rawValue)") else {
    return [.nan, .nan]
  }
  return SIMD2(body.position.x, body.position.z)
}

/// The full-tilt stick input that moves the leader along a direction on the ground, under the
/// world's camera.
@MainActor
func stick(_ world: GameWorld, towards direction: SIMD2<Float>) -> SIMD2<Float> {
  Movement.stick(towards: direction, cameraOffset: world.level.cameraOffset)
}

/// Steer the leader straight to a point, slowing for the last metre, and report each new line
/// the HUD shows. A conversation, or a scene that ends in one, stops the walk where it is.
@MainActor
func walk(_ world: GameWorld, to point: SIMD2<Float>, onLine: (String) -> Void = { _ in }) {
  var line = world.observation
  for _ in 0..<(60 * 120) where world.session.mode == .exploring {
    let offset = point - position(world, world.session.leader)
    if simd_length(offset) < 0.15 { return }
    let strength = min(1, max(0.35, simd_length(offset)))
    world.advanceParty(movement: stick(world, towards: offset) * strength, deltaTime: 1 / 60)
    if world.observation != line {
      line = world.observation
      onLine(line)
    }
  }
}

/// Steer the leader at full tilt through each point in turn, requiring that no companion warning
/// shows and that each point is reached within 30 seconds.
@MainActor
func walk(_ world: GameWorld, through points: [SIMD2<Float>], label: String = "walking") throws {
  var index = 0
  var frame = 0
  while index < points.count {
    let offset = points[index] - position(world, world.session.leader)
    if simd_length(offset) < 0.15 {
      index += 1
      continue
    }
    world.advanceParty(movement: stick(world, towards: offset), deltaTime: 1 / 60)
    frame += 1
    try #require(world.diagnostic == nil, "\(label), frame \(frame): \(world.diagnostic ?? "")")
    try #require(frame < 60 * 30, "\(label): the leader did not reach \(points[index])")
  }
}

/// Stand still for this long, requiring that no companion warning shows.
@MainActor
func wait(_ world: GameWorld, seconds: Float) throws {
  for frame in 0..<Int(seconds * 60) {
    world.advanceParty(movement: .zero, deltaTime: 1 / 60)
    try #require(world.diagnostic == nil, "waiting, frame \(frame)")
  }
}

/// Run the world until the condition holds, for at most the given time, and say whether it
/// held. Fire is pressed on the first frame and held throughout. An encounter's retry runs
/// through the frame update, as it does in play.
@MainActor
@discardableResult
func run(
  _ world: GameWorld, upTo seconds: Float, fire: Bool = false, until done: () -> Bool = { false }
) -> Bool {
  var pressed = fire
  for _ in 0..<Int(seconds * 60) {
    if done() { return true }
    if world.isRetrying {
      world.update(with: .neutral, sampledIn: world.session.mode, deltaTime: 1 / 60)
    } else {
      world.advanceParty(movement: .zero, fireHeld: fire, firePressed: pressed, deltaTime: 1 / 60)
      pressed = false
    }
  }
  return done()
}

/// One press of Pause or Resume, as the controls deliver it.
@MainActor
func pressPause(_ world: GameWorld) {
  let pause = InputRules.Input(
    movement: .zero, actionPressed: false, pausePressed: true, switchPressed: false)
  world.update(with: pause, sampledIn: world.session.mode, deltaTime: 1 / 60)
}

/// Press the action until the conversation ends, as its lines show one by one.
@MainActor
func finishConversation(_ world: GameWorld) {
  let press = InputRules.Input(
    movement: .zero, actionPressed: true, pausePressed: false, switchPressed: false)
  for _ in 0..<20 where world.session.mode == .dialogue {
    world.update(with: press, sampledIn: .dialogue, deltaTime: 1 / 60)
  }
}

/// How many entities there are in this one's tree, itself included.
@MainActor
func count(_ entity: Entity) -> Int {
  1 + entity.children.reduce(0) { $0 + count($1) }
}
