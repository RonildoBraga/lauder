import Foundation
import Observation
import RealityKit
import UIKit
import simd

@MainActor
@Observable
final class GameWorld {
  enum Status: Equatable {
    case loading, ready
    case failed(String)
  }

  let root = Entity()
  let controls = GameControls()
  private(set) var status = Status.loading
  private(set) var isPaused = false
  private(set) var nearbyName: String?
  private(set) var observation = "Find the service passage beside the blocked depot entrance."

  @ObservationIgnored private let player = Entity()
  @ObservationIgnored private let camera = PerspectiveCamera()
  @ObservationIgnored private var character: CharacterAsset?
  @ObservationIgnored private var playback: AnimationPlaybackController?
  @ObservationIgnored private var subscription: EventSubscription?
  @ObservationIgnored private var loadGeneration: UUID?
  @ObservationIgnored private var isPresented = false
  @ObservationIgnored private var isApplicationActive = false
  @ObservationIgnored private var skipNextStep = true
  @ObservationIgnored private var actionWasPressed = false
  @ObservationIgnored private var pauseWasPressed = false
  @ObservationIgnored private var isWalking = false
  @ObservationIgnored private var wasRunning = false
  @ObservationIgnored private var nearby: PrototypeLayout.PointOfInterest?

  init() {
    root.name = "relay-district"
    root.components.set(PhysicsSimulationComponent())
    for box in PrototypeLayout.boxes {
      let entity = ModelEntity(
        mesh: .generateBox(size: box.size),
        materials: [SimpleMaterial(color: color(for: box.surface), isMetallic: false)]
      )
      entity.name = box.name
      entity.position = box.position
      makeSolid(entity, size: box.size)
      root.addChild(entity)
    }
    addLandmarks()
    let light = DirectionalLight()
    light.light.intensity = 4000
    light.look(at: .zero, from: [3, 8, 5], relativeTo: nil)
    root.addChild(light)
    camera.camera.fieldOfViewInDegrees = 42
    root.addChild(camera)
    player.name = "miki"
    player.position = PrototypeLayout.spawn + [0, PrototypeLayout.characterHeight / 2, 0]
    player.components.set(
      CharacterControllerComponent(
        radius: 0.26, height: PrototypeLayout.characterHeight, stepLimit: 0.1)
    )
    root.addChild(player)
    updateCamera()
  }

  func attach(_ subscription: EventSubscription) {
    self.subscription?.cancel()
    self.subscription = subscription
    isPresented = true
    updateActivity()
  }

  func load() async {
    guard character == nil else {
      updateActivity()
      return
    }
    let generation = UUID()
    loadGeneration = generation
    status = .loading
    do {
      let asset = try await CharacterAsset.load()
      try Task.checkCancellation()
      guard loadGeneration == generation, isPresented else { return }
      asset.entity.position.y = -PrototypeLayout.characterHeight / 2
      player.addChild(asset.entity)
      character = asset
      status = .ready
      play(walking: false)
      updateActivity()
    } catch is CancellationError {
      // Leaving the view cancels its asset load.
    } catch {
      guard loadGeneration == generation else { return }
      status = .failed(error.localizedDescription)
    }
  }

  func setApplicationActive(_ active: Bool) {
    isApplicationActive = active
    updateActivity()
  }

  func setPaused(_ paused: Bool) {
    isPaused = paused
    updateActivity()
  }

  func stop() {
    isPresented = false
    loadGeneration = nil
    subscription?.cancel()
    subscription = nil
    updateActivity()
  }

  // Called synchronously by RealityKit's physics update, not RealityView.update.
  func step(deltaTime: TimeInterval) {
    MainActor.preconditionIsolated()
    guard isPresented, isApplicationActive, status == .ready else { return }
    let input = controls.sample()
    if input.pausePressed && !pauseWasPressed {
      setPaused(!isPaused)
    }
    pauseWasPressed = input.pausePressed
    synchronizePlayback()
    guard isRunning, let character else { return }
    guard !skipNextStep else {
      skipNextStep = false
      return
    }
    guard deltaTime.isFinite, deltaTime > 0 else { return }
    let dt = min(Float(deltaTime), 1 / 30)
    let direction = Movement.direction(
      for: input.movement, cameraOffset: PrototypeLayout.cameraOffset)
    let state = player.components[CharacterControllerStateComponent.self]
    let fallingSpeed: Float =
      state?.isOnGround == true ? -0.2 : max(-12, (state?.velocity.y ?? 0) - 9.8 * dt)
    let velocity = direction * PrototypeLayout.speed + [0, fallingSpeed, 0]
    player.moveCharacter(by: velocity * dt, deltaTime: dt, relativeTo: nil)

    let walking = simd_length_squared(direction) > 0.001
    if walking {
      character.entity.orientation = simd_quatf(
        angle: atan2(-direction.x, -direction.z), axis: [0, 1, 0]
      )
    }
    if walking != isWalking { play(walking: walking) }
    updateCamera()
    updateNearby()
    if input.actionPressed && !actionWasPressed {
      observation =
        nearby?.observation ?? "The depot's front entrance is blocked. Look for the side passage."
    }
    actionWasPressed = input.actionPressed
  }

  private var isRunning: Bool {
    isPresented && isApplicationActive && !isPaused && status == .ready
      && controls.status == .ready
  }

  private func updateActivity() {
    controls.setActive(isPresented && isApplicationActive && status == .ready)
    controls.setPaused(isPaused)
    actionWasPressed = false
    skipNextStep = true
    if !isPresented || !isApplicationActive {
      pauseWasPressed = false
    }
    synchronizePlayback()
  }

  private func synchronizePlayback() {
    let running = isRunning
    guard running != wasRunning else { return }
    wasRunning = running
    actionWasPressed = false
    skipNextStep = true
    if running {
      playback?.resume()
    } else {
      playback?.pause()
    }
  }

  private func play(walking: Bool) {
    guard let character else { return }
    playback?.stop()
    playback = character.animationEntity.playAnimation(
      (walking ? character.walk : character.idle).repeat(),
      transitionDuration: 0.12, startsPaused: !isRunning
    )
    isWalking = walking
  }

  private func updateCamera() {
    let target = player.position + [0, 0.1, 0]
    camera.look(at: target, from: target + PrototypeLayout.cameraOffset, relativeTo: nil)
  }

  private func updateNearby() {
    let closest = PrototypeLayout.points.min {
      simd_distance_squared($0.position, player.position * [1, 0, 1])
        < simd_distance_squared($1.position, player.position * [1, 0, 1])
    }
    let point = closest.flatMap {
      simd_distance($0.position, player.position * [1, 0, 1]) < PrototypeLayout.interactionRadius
        ? $0 : nil
    }
    if nearby?.id != point?.id {
      nearby = point
      nearbyName = point?.name
    }
  }

  private func addLandmarks() {
    for point in PrototypeLayout.points {
      let entity: ModelEntity
      if point.id == .tomas {
        entity = ModelEntity(
          mesh: .generateBox(size: PrototypeLayout.tomasBodySize),
          materials: [SimpleMaterial(color: .systemBrown, isMetallic: false)]
        )
        entity.position = point.position + PrototypeLayout.tomasBodyOffset
        let head = ModelEntity(
          mesh: .generateSphere(radius: PrototypeLayout.tomasHeadRadius),
          materials: [SimpleMaterial(color: .systemBrown, isMetallic: false)]
        )
        head.position = PrototypeLayout.tomasHeadOffset
        entity.addChild(head)
        makeSolid(entity, size: PrototypeLayout.tomasCollisionSize)
      } else {
        let size =
          point.id == .transmitter ? PrototypeLayout.transmitterSize : PrototypeLayout.regulatorSize
        entity = ModelEntity(
          mesh: .generateBox(size: size),
          materials: [SimpleMaterial(color: .systemCyan, isMetallic: true)]
        )
        entity.position = point.position + [0, size.y / 2, 0]
        makeSolid(entity, size: size)
      }
      entity.name = point.id.rawValue
      root.addChild(entity)
    }
    for position in PrototypeLayout.serviceMarkerPositions {
      let marker = ModelEntity(
        mesh: .generateBox(size: PrototypeLayout.serviceMarkerSize),
        materials: [UnlitMaterial(color: .systemCyan)]
      )
      marker.position = position
      root.addChild(marker)
    }
  }

  private func makeSolid(_ entity: Entity, size: SIMD3<Float>) {
    entity.components.set(CollisionComponent(shapes: [.generateBox(size: size)]))
    entity.components.set(PhysicsBodyComponent(massProperties: .default, mode: .static))
  }

  private func color(for surface: PrototypeLayout.Surface) -> UIColor {
    switch surface {
    case .concrete: UIColor(white: 0.24, alpha: 1)
    case .shelter: UIColor(red: 0.15, green: 0.29, blue: 0.31, alpha: 1)
    case .depot: UIColor(white: 0.4, alpha: 1)
    case .hazard: UIColor(red: 0.65, green: 0.36, blue: 0.12, alpha: 1)
    }
  }
}
