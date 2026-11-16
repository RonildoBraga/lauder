import Foundation
import Observation
import RealityKit
import simd

@MainActor
@Observable
final class GameWorld {
  static let obstacleGroup = CollisionGroup(rawValue: 1 << 4)
  private static let floorGroup = CollisionGroup(rawValue: 1 << 5)

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
  @ObservationIgnored private let bodyShape = ShapeResource.generateSphere(
    radius: PrototypeLayout.characterRadius)
  @ObservationIgnored private var trail: PartyTrail
  @ObservationIgnored private var subscription: EventSubscription?
  @ObservationIgnored private var isPresented = false
  @ObservationIgnored private var isApplicationActive = false
  @ObservationIgnored private var skipNextStep = true
  @ObservationIgnored private var wasRunning = false
  @ObservationIgnored private var nearby: PrototypeLayout.PointOfInterest?
  @ObservationIgnored private var cameraTarget: SIMD3<Float>
  @ObservationIgnored private var cameraStart: SIMD3<Float>?
  @ObservationIgnored private var cameraElapsed: Float = 0

  var isPaused: Bool { session.isPaused }

  init() {
    let members = PartyMember.allCases
    trail = PartyTrail(
      spawns: members.map {
        let position = PrototypeLayout.spawn(for: $0)
        return (member: $0, position: SIMD2(position.x, position.z))
      })
    cameraTarget = PrototypeLayout.spawn + [0, PrototypeLayout.characterHeight / 2 + 0.1, 0]
    root.name = "relay-district"
    root.components.set(PhysicsSimulationComponent())
    let style = SceneStyle()
    for box in PrototypeLayout.boxes {
      let entity = ModelEntity(
        mesh: .generateBox(size: box.size),
        materials: [box.id == .ground ? style.ground : style.material(for: box.surface)]
      )
      entity.name = box.name
      entity.position = box.position
      makeSolid(entity, size: box.size)
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
      skipNextStep = false
      return
    }
    guard deltaTime.isFinite, deltaTime > 0 else { return }
    let dt = min(Float(deltaTime), 1 / 30)
    let actual = positions
    trail.observe(positions: actual, deltaTime: dt)
    let direction = Movement.direction(
      for: input.movement, cameraOffset: PrototypeLayout.cameraOffset)
    let leaderDelta = SIMD2(direction.x, direction.z) * PrototypeLayout.speed * dt
    let deltas = trail.prepareStep(
      leader: session.leader, leaderDelta: leaderDelta,
      maximumFollowerDistance: PrototypeLayout.speed * dt)
    let message = trail.diagnostic.map { String(describing: $0) }
    if diagnostic != message { diagnostic = message }
    if !trail.holdsAllMovement {
      for member in PartyMember.allCases {
        guard let body = bodies[member] else { continue }
        let horizontal = deltas[member] ?? .zero
        let start = SIMD2(body.position.x, body.position.z)
        let resolved = PartyMotion.resolve(start: start, delta: horizontal) { [self] from, to in
          guard let scene = root.scene else {
            return PartyMotion.Hit(distance: 0, normal: .zero)
          }
          let height = PrototypeLayout.obstacleSweepHeight
          guard
            let hit = scene.convexCast(
              convexShape: bodyShape,
              fromPosition: [from.x, height, from.y],
              fromOrientation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
              toPosition: [to.x, height, to.y],
              toOrientation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
              query: .nearest, mask: Self.obstacleGroup, relativeTo: root
            ).first
          else { return nil }
          return PartyMotion.footprintHit(
            from: from, to: to, point: hit.position, normal: hit.normal,
            radius: PrototypeLayout.characterRadius)
        }
        body.position = [resolved.x, PrototypeLayout.characterHeight / 2, resolved.y]
        if simd_length_squared(horizontal) > 0.000001 {
          visuals[member]?.orientation = simd_quatf(
            angle: atan2(-horizontal.x, -horizontal.y), axis: [0, 1, 0])
        }
      }
    }
    updateCamera(deltaTime: dt)
    updateNearby()
    if input.actionPressed {
      observation =
        nearby?.observation
        ?? "The front entrance is blocked. The whole party can use the side passage."
    }
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
      let size =
        point.id == .transmitter ? PrototypeLayout.transmitterSize : PrototypeLayout.regulatorSize
      makeSolid(entity, size: size)
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

  private func makeSolid(_ entity: Entity, size: SIMD3<Float>) {
    entity.components.set(
      CollisionComponent(
        shapes: [.generateBox(size: size)],
        filter: CollisionFilter(
          group: entity.name == "ground" ? Self.floorGroup : Self.obstacleGroup, mask: .all)))
    entity.components.set(PhysicsBodyComponent(massProperties: .default, mode: .static))
  }
}
