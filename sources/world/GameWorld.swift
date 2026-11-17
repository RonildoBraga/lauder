import Foundation
import Observation
import RealityKit
import simd

@MainActor
@Observable
final class GameWorld {
  /// Party movement advances in whole steps of this length inside the scene update.
  static let simulationStep: Float = 1 / 120

  let root = Entity()
  let controls = GameControls()
  let session = GameSession()
  private(set) var nearbyName: String?
  private(set) var observation = "Walk the party through the service passage, then return."
  private(set) var diagnostic: String?

  @ObservationIgnored private var bodies: [PartyMember: Entity] = [:]
  @ObservationIgnored private var visuals: [PartyMember: Entity] = [:]
  @ObservationIgnored private var markers: [PartyMember: Entity] = [:]
  @ObservationIgnored private let camera = PerspectiveCamera()
  @ObservationIgnored private let motion = PartyMotion(
    radius: PrototypeLayout.characterRadius, obstacles: PrototypeLayout.obstacles)
  @ObservationIgnored private let grid = NavigationGrid.prototype
  @ObservationIgnored private var route: RouteMemory
  @ObservationIgnored private var planner: SquadPlanner
  @ObservationIgnored private var motors: [PartyMember: CompanionMotor]
  @ObservationIgnored private var squadLeader: PartyMember
  @ObservationIgnored private var yaw: [PartyMember: Float] = [:]
  /// Where each companion is heading in the latest step. Tests read it.
  @ObservationIgnored private(set) var companionTargets: [PartyMember: SIMD2<Float>] = [:]
  @ObservationIgnored private var subscription: EventSubscription?
  @ObservationIgnored private var isPresented = false
  @ObservationIgnored private var isApplicationActive = false
  @ObservationIgnored private var skipNextStep = true
  @ObservationIgnored private var wasRunning = false
  @ObservationIgnored private var nearby: PrototypeLayout.PointOfInterest?
  @ObservationIgnored private var cameraTarget: SIMD3<Float>
  @ObservationIgnored private var cameraStart: SIMD3<Float>?
  @ObservationIgnored private var cameraElapsed: Float = 0
  @ObservationIgnored private var unsimulatedTime: Float = 0

  var isPaused: Bool { session.isPaused }

  init() {
    let members = PartyMember.allCases
    // A mismatch with the session's leader is reconciled on the first step.
    squadLeader = .miki
    let start = PrototypeLayout.spawn(for: squadLeader)
    route = RouteMemory(start: SIMD2(start.x, start.z))
    // Companions spawn behind the leader along +z, so the formation starts facing -z.
    planner = SquadPlanner(heading: [0, -1])
    motors = Dictionary(
      uniqueKeysWithValues: members.map {
        ($0, CompanionMotor(reactionDelay: CompanionMotor.reactionDelay(for: $0)))
      })
    cameraTarget = PrototypeLayout.spawn + [0, PrototypeLayout.characterHeight / 2 + 0.1, 0]
    root.name = "relay-district"
    let style = SceneStyle()
    for box in PrototypeLayout.boxes {
      let entity = ModelEntity(
        mesh: .generateBox(size: box.size),
        materials: [box.id == .ground ? style.ground : style.material(for: box.surface)]
      )
      entity.name = box.name
      entity.position = box.position
      root.addChild(entity)
    }
    addLandmarks(style: style)
    SceneDressing.add(to: root, style: style)
    style.addLighting(to: root)
    camera.camera.fieldOfViewInDegrees = 42
    root.addChild(camera)
    for member in members {
      let body = Entity()
      body.name = "party.\(member.rawValue)"
      body.position =
        PrototypeLayout.spawn(for: member) + [0, PrototypeLayout.characterHeight / 2, 0]
      let visual = style.partyMember(member)
      body.addChild(visual)
      let marker = ModelEntity(
        mesh: .generateCylinder(height: 0.015, radius: 0.34), materials: [style.warm])
      marker.position.y = -PrototypeLayout.characterHeight / 2 + 0.025
      marker.isEnabled = member == session.leader
      body.addChild(marker)
      bodies[member] = body
      visuals[member] = visual
      markers[member] = marker
      root.addChild(body)
    }
    updateCamera(deltaTime: 0)
    updateNearby()
  }

  func attach(_ subscription: EventSubscription) {
    self.subscription?.cancel()
    self.subscription = subscription
    isPresented = true
    updateActivity()
  }

  func setApplicationActive(_ active: Bool) {
    guard active != isApplicationActive else { return }
    isApplicationActive = active
    updateActivity()
  }

  func stop() {
    isPresented = false
    subscription?.cancel()
    subscription = nil
    updateActivity()
  }

  // The next active step observes the preceding collision-checked body positions.
  func step(deltaTime: TimeInterval) {
    MainActor.preconditionIsolated()
    guard isPresented, isApplicationActive else { return }
    let input = controls.sample(mode: session.mode)
    if input.pausePressed {
      session.togglePause()
      controls.requireNeutralInput()
    } else if input.switchPressed {
      session.cycleLeader()
      cameraStart = cameraTarget
      cameraElapsed = 0
      for member in PartyMember.allCases {
        markers[member]?.isEnabled = member == session.leader
      }
      updateNearby()
    }
    let running = !session.isPaused && controls.status == .ready && !controls.needsNeutralInput
    if running != wasRunning {
      wasRunning = running
      skipNextStep = true
    }
    guard running else { return }
    guard !skipNextStep else {
      // Time owed from before an interruption is not replayed afterwards.
      skipNextStep = false
      unsimulatedTime = 0
      return
    }
    advanceParty(movement: input.movement, deltaTime: Float(deltaTime))
    if input.actionPressed {
      observation =
        nearby?.observation
        ?? "The front entrance is blocked. The whole party can use the side passage."
    }
  }

  // Production spatial update, also exercised by deterministic route/soak tests.
  // Input availability, Pause and fresh-edge handling remain in step/InputRules.
  func advanceParty(movement: SIMD2<Float>, deltaTime: Float) {
    guard session.mode == .exploring, deltaTime.isFinite, deltaTime > 0 else { return }
    let elapsed = min(deltaTime, 1 / 30)
    // Equal steps keep party movement independent of the display's frame times (#28). The
    // remainder, always under one step, carries to the next frame.
    unsimulatedTime += elapsed
    while unsimulatedTime >= Self.simulationStep {
      unsimulatedTime -= Self.simulationStep
      simulateStep(movement: movement, dt: Self.simulationStep)
    }
    updateCamera(deltaTime: elapsed)
    updateNearby()
  }

  private func simulateStep(movement: SIMD2<Float>, dt: Float) {
    if squadLeader != session.leader { changeLeader() }
    let leader = session.leader
    guard let leaderBody = bodies[leader] else { return }
    let direction = Movement.direction(
      for: movement, cameraOffset: PrototypeLayout.cameraOffset)
    let leaderDelta = SIMD2(direction.x, direction.z) * PrototypeLayout.speed * dt
    let leaderStart = SIMD2(leaderBody.position.x, leaderBody.position.z)
    let leaderEnd = motion.resolve(start: leaderStart, delta: leaderDelta)
    place(leader, at: leaderEnd)
    if simd_length_squared(leaderDelta) > 0.000001 {
      setYaw(leader, atan2(-leaderDelta.x, -leaderDelta.y))
    }
    let leaderVelocity = (leaderEnd - leaderStart) / dt
    route.record(leaderEnd)

    // Companions choose their own routes to formation slots (ADR 0003); every movement is
    // still resolved against the authored footprints.
    let current = positions
    let isClear: (SIMD2<Float>, SIMD2<Float>) -> Bool = { [motion] from, to in
      motion.canTraverse(from: from, to: to)
    }
    let targets = planner.targets(
      for: SquadPlanner.Input(
        leader: leader, leaderPosition: leaderEnd, leaderVelocity: leaderVelocity,
        positions: current, route: route, dt: dt),
      grid: grid, isClear: isClear)
    companionTargets = targets
    for member in PartyMember.allCases where member != leader {
      guard let start = current[member], let target = targets[member],
        var motor = motors[member]
      else { continue }
      let context = CompanionMotor.Context(
        target: target, leaderPosition: leaderEnd, leaderVelocity: leaderVelocity,
        others: current.compactMap { $0.key == member ? nil : $0.value },
        speed: PrototypeLayout.speed, dt: dt)
      let delta = motor.step(from: start, context: context, grid: grid, isClear: isClear)
      let end = motion.resolve(start: start, delta: delta)
      motor.absorb(end - start, dt: dt)
      motors[member] = motor
      place(member, at: end)
      turn(member, moved: end - start, dt: dt)
    }
    let stuck = PartyMember.allCases.first { $0 != leader && motors[$0]?.cannotReach == true }
    let message = stuck.map { "\($0.displayName) can't reach you" }
    if diagnostic != message { diagnostic = message }
  }

  private func changeLeader() {
    let previous = squadLeader
    let leader = session.leader
    squadLeader = leader
    if let body = bodies[leader] { route.reset(to: SIMD2(body.position.x, body.position.z)) }
    planner.reset()
    for member in [previous, leader] {
      motors[member] = CompanionMotor(reactionDelay: CompanionMotor.reactionDelay(for: member))
    }
    for member in PartyMember.allCases {
      markers[member]?.isEnabled = member == leader
    }
  }

  private func place(_ member: PartyMember, at point: SIMD2<Float>) {
    bodies[member]?.position = [point.x, PrototypeLayout.characterHeight / 2, point.y]
  }

  /// Companions turn towards their movement, or to the formation's heading once settled, at a
  /// limited rate so they never snap round.
  private func turn(_ member: PartyMember, moved delta: SIMD2<Float>, dt: Float) {
    let wanted: Float
    if simd_length(delta) > 0.2 * dt {
      wanted = atan2(-delta.x, -delta.y)
    } else if motors[member]?.isSettled == true {
      wanted = atan2(-planner.heading.x, -planner.heading.y)
    } else {
      return
    }
    let current = yaw[member] ?? wanted
    let limit = 3 * Float.pi * dt
    let change = max(-limit, min(limit, (wanted - current).remainder(dividingBy: 2 * .pi)))
    setYaw(member, current + change)
  }

  private func setYaw(_ member: PartyMember, _ angle: Float) {
    yaw[member] = angle
    visuals[member]?.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])
  }

  private var positions: [PartyMember: SIMD2<Float>] {
    Dictionary(
      uniqueKeysWithValues: bodies.map { member, body in
        (member, SIMD2(body.position.x, body.position.z))
      })
  }

  private func updateActivity() {
    controls.setActive(isPresented && isApplicationActive)
    controls.requireNeutralInput()
    skipNextStep = true
  }

  private func updateCamera(deltaTime: Float) {
    guard let body = bodies[session.leader] else { return }
    let target = body.position + [0, 0.1, 0]
    if let start = cameraStart {
      cameraElapsed = min(0.25, cameraElapsed + deltaTime)
      let amount = cameraElapsed / 0.25
      let eased = amount * amount * (3 - 2 * amount)
      cameraTarget = start + (target - start) * eased
      if cameraElapsed >= 0.25 { cameraStart = nil }
    } else {
      cameraTarget = target
    }
    camera.look(
      at: cameraTarget, from: cameraTarget + PrototypeLayout.cameraOffset, relativeTo: nil)
  }

  private func updateNearby() {
    guard let player = bodies[session.leader] else { return }
    let position = player.position * [1, 0, 1]
    let closest = PrototypeLayout.points.min {
      simd_distance_squared($0.position, position) < simd_distance_squared($1.position, position)
    }
    let point = closest.flatMap {
      simd_distance($0.position, position) < PrototypeLayout.interactionRadius ? $0 : nil
    }
    if nearby?.id != point?.id {
      nearby = point
      nearbyName = point?.name
    }
  }

  private func addLandmarks(style: SceneStyle) {
    for point in PrototypeLayout.points {
      let entity = style.landmark(for: point)
      entity.name = point.id.rawValue
      root.addChild(entity)
    }
    for position in PrototypeLayout.serviceMarkerPositions {
      let marker = ModelEntity(
        mesh: .generateBox(size: PrototypeLayout.serviceMarkerSize), materials: [style.signal])
      marker.position = position
      root.addChild(marker)
    }
  }

}
