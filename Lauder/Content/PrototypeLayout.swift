import simd

enum PrototypeLayout {
  enum Surface {
    case concrete, shelter, depot, hazard
  }

  struct Box {
    let name: String
    let position: SIMD3<Float>
    let size: SIMD3<Float>
    let surface: Surface
  }

  enum InteractionID: String {
    case tomas = "relay.tomas"
    case transmitter = "relay.transmitter"
    case regulator = "depot.regulator"
  }

  struct PointOfInterest {
    let id: InteractionID
    let name: String
    let position: SIMD3<Float>
    let observation: String
  }

  static let spawn: SIMD3<Float> = [-8, 0, 3]
  static let cameraOffset: SIMD3<Float> = [5.25, 10, 8.4]
  static let characterHeight: Float = 1.7
  static let speed: Float = 2.6
  static let movementDeadZone: Float = 0.15
  static let interactionRadius: Float = 2.3

  static let tomasBodySize: SIMD3<Float> = [0.45, 1.3, 0.35]
  static let tomasBodyOffset: SIMD3<Float> = [0, 0.75, 0]
  static let tomasHeadRadius: Float = 0.18
  static let tomasHeadOffset: SIMD3<Float> = [0, 0.8, 0]
  static let tomasCollisionSize: SIMD3<Float> = [0.5, 1.5, 0.5]
  static let transmitterSize: SIMD3<Float> = [0.8, 1, 0.6]
  static let regulatorSize: SIMD3<Float> = [0.5, 0.5, 0.5]
  static let serviceMarkerSize: SIMD3<Float> = [1.2, 0.025, 0.12]
  static let serviceMarkerPositions: [SIMD3<Float>] = [[3.4, 0.02, -5.1], [3.4, 0.02, -3.9]]

  // Low walls preserve the elevated camera's view of Miki. The depot's front is
  // blocked; its west wall leaves a 1.8 m service opening around the corner.
  static let boxes: [Box] = [
    Box(name: "ground", position: [0, -0.15, 0], size: [28, 0.3, 20], surface: .concrete),
    Box(
      name: "south-boundary", position: [0, 0.45, 9.7], size: [28, 0.9, 0.6], surface: .concrete),
    Box(
      name: "north-boundary", position: [0, 0.45, -9.7], size: [28, 0.9, 0.6], surface: .concrete),
    Box(
      name: "west-boundary", position: [-13.7, 0.45, 0], size: [0.6, 0.9, 20], surface: .concrete),
    Box(
      name: "east-boundary", position: [13.7, 0.45, 0], size: [0.6, 0.9, 20], surface: .concrete),
    Box(name: "shelter-back", position: [-9, 0.5, 0], size: [7, 1, 0.35], surface: .shelter),
    Box(name: "shelter-side", position: [-12.3, 0.5, 2.5], size: [0.35, 1, 5], surface: .shelter),
    Box(name: "street-wreck", position: [-1.5, 0.4, 1], size: [2.5, 0.8, 1.2], surface: .hazard),
    Box(name: "fallen-panel", position: [1, 0.3, -2], size: [1.2, 0.6, 2.5], surface: .shelter),
    Box(name: "depot-back", position: [7, 0.55, -7], size: [6.4, 1.1, 0.35], surface: .depot),
    Box(name: "depot-east", position: [10, 0.55, -4], size: [0.35, 1.1, 6], surface: .depot),
    Box(
      name: "depot-west-back", position: [4, 0.55, -6.2], size: [0.35, 1.1, 1.6], surface: .depot),
    Box(
      name: "depot-west-front", position: [4, 0.55, -2.3], size: [0.35, 1.1, 2.6], surface: .depot),
    Box(name: "depot-front-west", position: [5, 0.55, -1], size: [2, 1.1, 0.35], surface: .depot),
    Box(name: "depot-front-east", position: [9, 0.55, -1], size: [2, 1.1, 0.35], surface: .depot),
    Box(
      name: "blocked-entrance", position: [7, 0.45, -0.7], size: [2.2, 0.9, 1], surface: .hazard),
  ]

  static let points: [PointOfInterest] = [
    PointOfInterest(
      id: .tomas, name: "Tomas", position: [-7, 0, 1.5],
      observation: "Tomas waits beside the shelter."
    ),
    PointOfInterest(
      id: .transmitter, name: "Transmitter", position: [-10, 0, 1.5],
      observation: "The transmitter needs a replacement part."
    ),
    PointOfInterest(
      id: .regulator, name: "Regulator", position: [7, 0, -4.5],
      observation: "A regulator sits among the depot equipment."
    ),
  ]
}
