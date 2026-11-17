import simd

enum PrototypeLayout {
  enum Surface {
    case concrete, shelter, depot, hazard
  }

  enum BoxID: String, CaseIterable {
    case ground
    case southBoundary = "south-boundary"
    case northBoundary = "north-boundary"
    case westBoundary = "west-boundary"
    case eastBoundary = "east-boundary"
    case shelterBack = "shelter-back"
    case shelterSide = "shelter-side"
    case streetWreck = "street-wreck"
    case fallenPanel = "fallen-panel"
    case depotBack = "depot-back"
    case depotEast = "depot-east"
    case depotWestBack = "depot-west-back"
    case depotWestFront = "depot-west-front"
    case depotFrontWest = "depot-front-west"
    case depotFrontEast = "depot-front-east"
    case blockedEntrance = "blocked-entrance"

    var hasWallCap: Bool {
      switch self {
      case .southBoundary, .northBoundary, .westBoundary, .eastBoundary,
        .shelterBack, .shelterSide, .depotBack, .depotEast,
        .depotWestBack, .depotWestFront, .depotFrontWest, .depotFrontEast:
        true
      case .ground, .streetWreck, .fallenPanel, .blockedEntrance:
        false
      }
    }
  }

  struct Box {
    let id: BoxID
    let position: SIMD3<Float>
    let size: SIMD3<Float>
    let surface: Surface

    var name: String { id.rawValue }
  }

  enum InteractionID: String {
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
  static let characterRadius: Float = 0.26
  static let speed: Float = 2.6
  static let movementDeadZone: Float = 0.15
  static let interactionRadius: Float = 2.3

  static let transmitterSize: SIMD3<Float> = [0.8, 1, 0.6]
  static let regulatorSize: SIMD3<Float> = [0.5, 0.5, 0.5]
  static let serviceMarkerSize: SIMD3<Float> = [1.2, 0.025, 0.12]
  static let serviceMarkerPositions: [SIMD3<Float>] = [[3.4, 0.02, -5.1], [3.4, 0.02, -3.9]]

  static func spawn(for member: PartyMember) -> SIMD3<Float> {
    switch member {
    case .miki: spawn
    case .lara: spawn + [0, 0, 0.8]
    case .tomas: spawn + [0, 0, 1.6]
    }
  }

  // Low walls preserve the elevated camera's view of the party. The depot's front is
  // blocked; its west wall leaves a 1.8 m service opening around the corner.
  static let boxes: [Box] = [
    Box(id: .ground, position: [0, -0.15, 0], size: [28, 0.3, 20], surface: .concrete),
    Box(
      id: .southBoundary, position: [0, 0.45, 9.7], size: [28, 0.9, 0.6], surface: .concrete),
    Box(
      id: .northBoundary, position: [0, 0.45, -9.7], size: [28, 0.9, 0.6], surface: .concrete),
    Box(
      id: .westBoundary, position: [-13.7, 0.45, 0], size: [0.6, 0.9, 20], surface: .concrete),
    Box(
      id: .eastBoundary, position: [13.7, 0.45, 0], size: [0.6, 0.9, 20], surface: .concrete),
    Box(id: .shelterBack, position: [-9, 0.5, 0], size: [7, 1, 0.35], surface: .shelter),
    Box(id: .shelterSide, position: [-12.3, 0.5, 2.5], size: [0.35, 1, 5], surface: .shelter),
    Box(id: .streetWreck, position: [-1.5, 0.4, 1], size: [2.5, 0.8, 1.2], surface: .hazard),
    Box(id: .fallenPanel, position: [1, 0.3, -2], size: [1.2, 0.6, 2.5], surface: .shelter),
    Box(id: .depotBack, position: [7, 0.55, -7], size: [6.4, 1.1, 0.35], surface: .depot),
    Box(id: .depotEast, position: [10, 0.55, -4], size: [0.35, 1.1, 6], surface: .depot),
    Box(
      id: .depotWestBack, position: [4, 0.55, -6.2], size: [0.35, 1.1, 1.6], surface: .depot),
    Box(
      id: .depotWestFront, position: [4, 0.55, -2.3], size: [0.35, 1.1, 2.6], surface: .depot),
    Box(id: .depotFrontWest, position: [5, 0.55, -1], size: [2, 1.1, 0.35], surface: .depot),
    Box(id: .depotFrontEast, position: [9, 0.55, -1], size: [2, 1.1, 0.35], surface: .depot),
    Box(
      id: .blockedEntrance, position: [7, 0.45, -0.7], size: [2.2, 0.9, 1], surface: .hazard),
  ]

  static func box(_ id: BoxID) -> Box {
    let matches = boxes.filter { $0.id == id }
    precondition(matches.count == 1, "Layout must contain exactly one \(id.rawValue) box.")
    return matches[0]
  }

  static let points: [PointOfInterest] = [
    PointOfInterest(
      id: .transmitter, name: "Transmitter", position: [-10, 0, 1.5],
      observation: "The transmitter needs a replacement part."
    ),
    PointOfInterest(
      id: .regulator, name: "Regulator", position: [7, 0, -4.5],
      observation: "A regulator sits among the depot equipment."
    ),
  ]

  // The flat-floor footprint comes from the same dimensions as the visible scenery.
  // Ground, decorations and party members do not block horizontal movement.
  static let obstacles: [PartyMotion.Box] =
    boxes.filter { $0.id != .ground }.map {
      footprint(position: $0.position, size: $0.size)
    }
    + points.map {
      footprint(
        position: $0.position,
        size: $0.id == .transmitter ? transmitterSize : regulatorSize)
    }

  private static func footprint(position: SIMD3<Float>, size: SIMD3<Float>) -> PartyMotion.Box {
    let centre = SIMD2(position.x, position.z)
    let half = SIMD2(size.x, size.z) / 2
    return PartyMotion.Box(minimum: centre - half, maximum: centre + half)
  }
}
